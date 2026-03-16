// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// VitePluginRescript.res — Language evangeliser Vite plugin.
//
// Originally built as the definitive ReScript+Vite plugin, now generalised
// into a multi-language adapter system. ReScript remains the primary language
// with zero-config support. Additional languages (AffineScript, etc.) plug in
// via the LanguageAdapter protocol.
//
// This plugin solves EVERY known pain point for language+Vite integration:
//
//   1. Automatic compiler spawning (build + watch + rewatch)
//   2. HMR for source files via compiled output tracking
//   3. Error overlay integration (diagnostics -> Vite overlay)
//   4. Module resolution fixes (PascalCase for ReScript, etc.)
//   5. Auto optimizeDeps exclusion (per-language package lists)
//   6. Build artifact watcher ignore (per-language patterns)
//   7. Config file auto-detection (rescript.json, affinescript.opam, etc.)
//   8. ANSI color forwarding (NINJA_ANSI_FORCED=1)
//   9. In-source/out-of-source path remapping
//  10. Deno-compatible (auto-detects runtime)
//  11. Optional BoJ ssg-mcp build orchestration
//  12. Multi-language support via pluggable adapters
//
// Usage in vite.config.js:
//   import rescriptPlugin from "rescript-vite"
//   export default { plugins: [rescriptPlugin()] }
//
// Usage with options:
//   import { make } from "rescript-vite"
//   export default { plugins: [make({ boj: true, logLevel: "verbose" })] }
//
// Usage with additional language adapters:
//   import { makeWithAdapters } from "rescript-vite"
//   import { make as affinescriptAdapter } from "rescript-vite/adapter/affinescript"
//   export default { plugins: [makeWithAdapters({ adapters: [affinescriptAdapter()] })] }

/// Plugin options
type options = {
  /// Enable BoJ ssg-mcp integration (default: false, auto-probes)
  boj: option<bool>,
  /// BoJ endpoint (default: http://localhost:7077/mcp/ssg)
  bojEndpoint: option<string>,
  /// Use Deno to run rescript (default: auto-detect)
  useDeno: option<bool>,
  /// Path to rescript binary
  rescriptBin: option<string>,
  /// Extra compiler flags
  compilerFlags: option<array<string>>,
  /// Log level: "silent" | "info" | "verbose"
  logLevel: option<string>,
  /// Output suffix override (default: auto-detect from rescript.json)
  suffix: option<string>,
  /// Use rewatch instead of rescript build -w (default: auto-detect)
  useRewatch: option<bool>,
  /// Auto-configure optimizeDeps to exclude @rescript/* packages (default: true)
  autoOptimizeDeps: option<bool>,
  /// Auto-resolve PascalCase module imports on case-sensitive filesystems (default: true)
  autoResolve: option<bool>,
  /// Auto-ignore build artifacts in Vite watcher (default: true)
  autoIgnoreArtifacts: option<bool>,
  /// Additional language adapters beyond the built-in ReScript adapter.
  /// Each adapter teaches the plugin how to handle a different language.
  /// The ReScript adapter is always included; these are additive.
  adapters: option<array<LanguageAdapter.t>>,
}

/// Per-adapter runtime state (one per active language)
type adapterState = {
  adapter: LanguageAdapter.t,
  mutable config: LanguageAdapter.languageConfig,
  mutable watchHandle: option<LanguageAdapter.watchHandle>,
  mutable diagnostics: array<LanguageAdapter.diagnostic>,
  mutable lastBuildSuccess: bool,
}

/// Internal plugin state
type pluginState = {
  mutable viteConfig: option<ViteTypes.resolvedConfig>,
  mutable bojBridge: option<BojBridge.t>,
  mutable pendingHmrFiles: array<string>,
  /// Active language adapters with their runtime state
  mutable activeAdapters: array<adapterState>,
  /// Legacy ReScript-specific state (for backward compat with direct compiler config)
  mutable rescriptConfig: RescriptConfig.rescriptConfig,
  mutable watchHandle: option<RescriptCompiler.watchHandle>,
  mutable diagnostics: array<RescriptCompiler.diagnostic>,
  mutable lastBuildSuccess: bool,
}

// --- Filesystem helpers ---

@module("node:path") external resolve: (string, string) => string = "resolve"
@module("node:path") external relative: (string, string) => string = "relative"
@module("node:path") external dirname: string => string = "dirname"
@module("node:path") external basename: string => string = "basename"
@module("node:path") external joinPath: (string, string) => string = "join"
@module("node:path") external joinPath3: (string, string, string) => string = "join"
@module("node:fs") external existsSync: string => bool = "existsSync"

// --- Logging ---

let log = (level: string, prefix: string, msg: string): unit => {
  if level !== "silent" {
    Console.log(`[rescript-vite] ${prefix} ${msg}`)
  }
}

let logInfo = (level: string, msg: string) => log(level, "\x1b[36mi\x1b[0m", msg)
let logOk = (level: string, msg: string) => log(level, "\x1b[32m+\x1b[0m", msg)
let logWarn = (level: string, msg: string) => log(level, "\x1b[33m!\x1b[0m", msg)
let logErr = (level: string, msg: string) => log(level, "\x1b[31mx\x1b[0m", msg)

// --- Deno detection ---

let isDeno = (): bool => {
  %raw(`typeof Deno !== "undefined"`)
}

// --- Rewatch detection ---

let hasRewatch = (root: string): bool => {
  let rewatchPath = joinPath3(root, "node_modules", ".bin/rewatch")
  existsSync(rewatchPath)
}

/// Send diagnostics to the Vite error overlay (works with both legacy and adapter diagnostics)
let sendOverlayErrorFromAdapter = (server: ViteTypes.viteDevServer, diagnostic: LanguageAdapter.diagnostic): unit => {
  let payload: JSON.t = Obj.magic({
    "type": "error",
    "err": {
      "message": diagnostic.message,
      "stack": "",
      "id": diagnostic.file,
      "frame": `${diagnostic.file}:${Int.toString(diagnostic.line)}:${Int.toString(diagnostic.column)}`,
      "plugin": "rescript-vite",
      "loc": {
        "file": diagnostic.file,
        "line": diagnostic.line,
        "column": diagnostic.column,
      },
    },
  })
  server.ws.send(payload)
}

/// Send diagnostics to the Vite error overlay (legacy ReScript diagnostic format)
let sendOverlayError = (server: ViteTypes.viteDevServer, diagnostic: RescriptCompiler.diagnostic): unit => {
  let payload: JSON.t = Obj.magic({
    "type": "error",
    "err": {
      "message": diagnostic.message,
      "stack": "",
      "id": diagnostic.file,
      "frame": `${diagnostic.file}:${Int.toString(diagnostic.line)}:${Int.toString(diagnostic.column)}`,
      "plugin": "rescript-vite",
      "loc": {
        "file": diagnostic.file,
        "line": diagnostic.line,
        "column": diagnostic.column,
      },
    },
  })
  server.ws.send(payload)
}

/// Clear the error overlay
let clearOverlay = (server: ViteTypes.viteDevServer): unit => {
  let payload: JSON.t = Obj.magic({"type": "update", "updates": []})
  server.ws.send(payload)
}

/// Build artifact glob patterns that should be ignored by Vite's watcher.
/// These are ReScript compiler intermediates that cause spurious reloads.
let artifactIgnorePatterns: array<string> = [
  "**/*.ast",
  "**/*.cmj",
  "**/*.cmi",
  "**/*.cmt",
  "**/lib/bs/**",
  "**/lib/es6/**",
  "**/lib/js/**",
  "**/lib/ocaml/**",
  "**/.merlin",
  "**/.bsb.lock",
]

/// Packages that must be excluded from Vite's dependency pre-bundling.
/// These use subpath exports or ESM patterns that break esbuild.
let rescriptExcludePackages: array<string> = [
  "@rescript/core",
  "@rescript/runtime",
  "@rescript/react",
  "rescript",
]

/// Try PascalCase variant of a module import path.
/// ReScript emits imports like "./app/getEngine" but the actual files are
/// "GetEngine.res.mjs" — on case-sensitive filesystems (Linux) this breaks.
let tryPascalCaseResolve = (source: string, importer: string, suffix: string): option<string> => {
  if !(source->String.startsWith(".")) {
    None
  } else {
    let dir = dirname(importer)
    let base = basename(source)

    // Try PascalCase first letter
    let firstChar = base->String.charAt(0)->String.toUpperCase
    let rest = base->String.sliceToEnd(~start=1)
    let pascalBase = firstChar ++ rest

    // Try with the configured suffix (e.g., .res.js or .res.mjs)
    let candidate = joinPath3(dir, dirname(source), pascalBase ++ suffix)
    if existsSync(candidate) {
      Some(candidate)
    } else {
      // Also try without the leading dot in the suffix for .mjs case
      let altSuffix = if suffix === ".res.js" {
        ".res.mjs"
      } else if suffix === ".res.mjs" {
        ".res.js"
      } else {
        suffix
      }
      let altCandidate = joinPath3(dir, dirname(source), pascalBase ++ altSuffix)
      if existsSync(altCandidate) {
        Some(altCandidate)
      } else {
        // Try the base name directly with suffix (sometimes import is already correct case)
        let directCandidate = joinPath3(dir, dirname(source), base ++ suffix)
        if existsSync(directCandidate) {
          Some(directCandidate)
        } else {
          None
        }
      }
    }
  }
}

/// Check if a file extension matches any active adapter
let findAdapterForFile = (state: pluginState, file: string): option<adapterState> => {
  state.activeAdapters->Array.find(as_ => {
    as_.adapter.extensions->Array.some(ext => file->String.endsWith(ext))
  })
}

/// Collect all exclude packages from active adapters
let allExcludePackages = (state: pluginState): array<string> => {
  let result: array<string> = []
  let seen: Dict.t<bool> = Dict.make()
  // Always include ReScript packages
  Array.forEach(rescriptExcludePackages, pkg => {
    Dict.set(seen, pkg, true)
    Array.push(result, pkg)->ignore
  })
  // Add packages from additional adapters
  Array.forEach(state.activeAdapters, as_ => {
    Array.forEach(as_.adapter.excludePackages, pkg => {
      if !(Dict.get(seen, pkg)->Option.getOr(false)) {
        Dict.set(seen, pkg, true)
        Array.push(result, pkg)->ignore
      }
    })
  })
  result
}

/// Collect all artifact ignore patterns from active adapters
let allArtifactPatterns = (state: pluginState): array<string> => {
  let result: array<string> = []
  let seen: Dict.t<bool> = Dict.make()
  // Always include ReScript patterns
  Array.forEach(artifactIgnorePatterns, pat => {
    Dict.set(seen, pat, true)
    Array.push(result, pat)->ignore
  })
  // Add patterns from additional adapters
  Array.forEach(state.activeAdapters, as_ => {
    Array.forEach(as_.adapter.artifactIgnorePatterns, pat => {
      if !(Dict.get(seen, pat)->Option.getOr(false)) {
        Dict.set(seen, pat, true)
        Array.push(result, pat)->ignore
      }
    })
  })
  result
}

/// Create the Vite plugin with the standard ReScript-first configuration.
///
/// This is the primary entry point. The ReScript compiler integration is
/// built-in. Additional language adapters can be passed via options.adapters.
let make = (~options: option<options>=None): ViteTypes.plugin => {
  let opts: options = options->Option.getOr({
    boj: None,
    bojEndpoint: None,
    useDeno: None,
    rescriptBin: None,
    compilerFlags: None,
    logLevel: None,
    suffix: None,
    useRewatch: None,
    autoOptimizeDeps: None,
    autoResolve: None,
    autoIgnoreArtifacts: None,
    adapters: None,
  })

  let logLevel = opts.logLevel->Option.getOr("info")
  let useDeno = opts.useDeno->Option.getOr(isDeno())
  let wantAutoOptimize = opts.autoOptimizeDeps->Option.getOr(true)
  let wantAutoResolve = opts.autoResolve->Option.getOr(true)
  let wantAutoIgnore = opts.autoIgnoreArtifacts->Option.getOr(true)
  let extraAdapters = opts.adapters->Option.getOr([])

  let state: pluginState = {
    viteConfig: None,
    bojBridge: None,
    pendingHmrFiles: [],
    activeAdapters: [],
    rescriptConfig: RescriptConfig.defaultRescriptConfig,
    watchHandle: None,
    diagnostics: [],
    lastBuildSuccess: true,
  }

  {
    name: "rescript-vite",
    enforce: Some("pre"),

    // --- config hook: auto-configure Vite for all active languages ---
    config: Some(() => {
      // Read rescript.json early (before configResolved, which gives us root)
      let rescriptCfg = RescriptConfig.read(".")
      state.rescriptConfig = rescriptCfg

      if rescriptCfg.configPath !== "" {
        logInfo(logLevel, `Detected ${rescriptCfg.configPath} (suffix: ${rescriptCfg.suffix}, format: ${rescriptCfg.packageSpec.moduleFormat}, in-source: ${rescriptCfg.packageSpec.inSource ? "true" : "false"})`)
      }

      // Detect additional language adapters
      Array.forEach(extraAdapters, adapter => {
        switch adapter.detect(".") {
        | Some(configPath) => {
            let config = adapter.readConfig(".")
            Array.push(state.activeAdapters, {
              adapter,
              config,
              watchHandle: None,
              diagnostics: [],
              lastBuildSuccess: true,
            })->ignore
            logInfo(logLevel, `Detected ${adapter.displayName} (${configPath})`)
          }
        | None =>
          if logLevel === "verbose" {
            logInfo(logLevel, `${adapter.displayName} not detected in project`)
          }
        }
      })

      // Build the partial config object using merged adapter data
      let excludePkgs = allExcludePackages(state)
      let ignorePats = allArtifactPatterns(state)

      let buildConfigPatch: (bool, bool, array<string>, array<string>) => JSON.t = %raw(`
        function(autoOptimize, autoIgnore, pkgs, pats) {
          var cfg = {};
          if (autoOptimize) {
            cfg.optimizeDeps = { exclude: pkgs };
          }
          if (autoIgnore) {
            cfg.server = cfg.server || {};
            cfg.server.watch = cfg.server.watch || {};
            cfg.server.watch.ignored = pats;
          }
          cfg.define = cfg.define || {};
          return cfg;
        }
      `)

      let configPatch: JSON.t = if wantAutoOptimize || wantAutoIgnore {
        buildConfigPatch(wantAutoOptimize, wantAutoIgnore, excludePkgs, ignorePats)
      } else {
        %raw(`({})`)
      }

      configPatch
    }),

    configResolved: Some(resolvedConfig => {
      state.viteConfig = Some(resolvedConfig)

      // Re-read rescript.json with the actual root
      let rescriptCfg = RescriptConfig.read(resolvedConfig.root)
      state.rescriptConfig = rescriptCfg

      // Apply suffix override if provided
      switch opts.suffix {
      | Some(s) => state.rescriptConfig = {...state.rescriptConfig, suffix: s}
      | None => ()
      }

      // Re-detect additional adapters with actual root
      state.activeAdapters = []
      Array.forEach(extraAdapters, adapter => {
        switch adapter.detect(resolvedConfig.root) {
        | Some(_configPath) => {
            let config = adapter.readConfig(resolvedConfig.root)
            Array.push(state.activeAdapters, {
              adapter,
              config,
              watchHandle: None,
              diagnostics: [],
              lastBuildSuccess: true,
            })->ignore
          }
        | None => ()
        }
      })

      logInfo(logLevel, `Project root: ${resolvedConfig.root}`)
      logInfo(logLevel, `Mode: ${resolvedConfig.command} (${resolvedConfig.mode})`)
      logInfo(logLevel, `ReScript suffix: ${state.rescriptConfig.suffix}`)
      if !state.rescriptConfig.packageSpec.inSource {
        logInfo(logLevel, `Out-of-source mode: compiled output in lib/${state.rescriptConfig.packageSpec.moduleFormat === "esmodule" ? "es6" : "js"}/`)
      }
      if Array.length(state.activeAdapters) > 0 {
        let names = state.activeAdapters->Array.map(as_ => as_.adapter.displayName)->Array.join(", ")
        logInfo(logLevel, `Additional languages: ${names}`)
      }
    }),

    // --- configureServer: set env for compiler output ---
    configureServer: Some(_server => {
      %raw(`process.env.NINJA_ANSI_FORCED = "1"`)
    }),

    // --- resolveId: multi-language module resolution ---
    resolveId: if wantAutoResolve {
      Some(async (source, importer) => {
        switch importer {
        | None => None
        | Some(imp) => {
            // Try ReScript PascalCase resolution first
            let suffix = state.rescriptConfig.suffix
            switch tryPascalCaseResolve(source, imp, suffix) {
            | Some(resolved) => Some({ViteTypes.id: resolved})
            | None => {
                // Try additional adapters
                let result = ref(None)
                let i = ref(0)
                while i.contents < Array.length(state.activeAdapters) && Option.isNone(result.contents) {
                  let as_ = state.activeAdapters->Array.getUnsafe(i.contents)
                  switch as_.adapter.resolveImport(source, imp, as_.config) {
                  | Some(resolved) => result := Some(Some({ViteTypes.id: resolved}))
                  | None => ()
                  }
                  i := i.contents + 1
                }
                result.contents->Option.getOr(None)
              }
            }
          }
        }
      })
    } else {
      None
    },

    buildStart: Some(async () => {
      let root = switch state.viteConfig {
      | Some(c) => c.root
      | None => "."
      }

      // --- BoJ probe ---
      let wantBoj = opts.boj->Option.getOr(false)
      if wantBoj {
        let bridge = BojBridge.make(
          ~endpoint=opts.bojEndpoint->Option.getOr(BojBridge.defaultEndpoint),
        )
        let connected = await BojBridge.probe(bridge)
        if connected {
          state.bojBridge = Some(bridge)
          logOk(logLevel, "BoJ ssg-mcp connected -- build orchestration delegated")
        } else {
          logWarn(logLevel, "BoJ not available -- falling back to direct compiler")
        }
      }

      // --- ReScript compiler (primary, always active) ---
      let useRewatch = opts.useRewatch->Option.getOr(hasRewatch(root))

      let compilerConfig = {
        ...RescriptCompiler.defaultConfig(root),
        useDeno,
        rescriptBin: opts.rescriptBin,
        compilerFlags: opts.compilerFlags->Option.getOr([]),
        useRewatch,
        onDiagnostic: Some(d => {
          Array.push(state.diagnostics, d)->ignore
          let sevStr = switch d.severity {
          | Error => "error"
          | Warning => "warning"
          }
          if sevStr === "error" {
            logErr(logLevel, `${d.file}:${Int.toString(d.line)} -- ${d.message}`)
            state.lastBuildSuccess = false
          } else if logLevel === "verbose" {
            logWarn(logLevel, `${d.file}:${Int.toString(d.line)} -- ${d.message}`)
          }
        }),
        onFileChanged: Some(file => {
          Array.push(state.pendingHmrFiles, file)->ignore
        }),
      }

      let config = switch state.viteConfig {
      | Some(c) => c
      | None => {root: ".", command: "build", mode: "production"}
      }

      if config.command === "serve" {
        // Dev mode — start ReScript watch
        logInfo(logLevel, useRewatch ? "Starting rewatch..." : "Starting ReScript compiler in watch mode...")
        let handle = RescriptCompiler.watch(compilerConfig)
        state.watchHandle = Some(handle)
        logOk(logLevel, useRewatch ? "Rewatch active" : "ReScript watch mode active")

        // Start additional adapter watch processes
        Array.forEach(state.activeAdapters, as_ => {
          logInfo(logLevel, `Starting ${as_.adapter.displayName} watch mode...`)
          let handle = as_.adapter.watch(root, as_.config)
          as_.watchHandle = Some(handle)
          logOk(logLevel, `${as_.adapter.displayName} watch mode active`)
        })
      } else {
        // Production build — one-shot
        logInfo(logLevel, "Running ReScript build...")

        switch state.bojBridge {
        | Some(bridge) => {
            let result = await BojBridge.requestBuild(bridge, {
              projectRoot: root,
              targets: ["client"],
              incremental: false,
              changedFiles: [],
              compilerFlags: opts.compilerFlags->Option.getOr([]),
            })
            switch result {
            | Some(r) => {
                state.lastBuildSuccess = r.success
                if r.success {
                  logOk(logLevel, `BoJ build complete (${Float.toString(r.durationMs)}ms, ${Int.toString(r.cacheHits)} cache hits)`)
                } else {
                  logErr(logLevel, `BoJ build failed (${Int.toString(r.diagnosticCount)} errors)`)
                }
              }
            | None => {
                logWarn(logLevel, "BoJ build request failed -- falling back to direct compiler")
                let result = await RescriptCompiler.build(compilerConfig)
                state.lastBuildSuccess = result.success
                if result.success {
                  logOk(logLevel, `Build complete (${Float.toString(result.durationMs)}ms)`)
                } else {
                  logErr(logLevel, `Build failed (${Int.toString(Array.length(result.diagnostics))} errors)`)
                }
              }
            }
          }
        | None => {
            let result = await RescriptCompiler.build(compilerConfig)
            state.lastBuildSuccess = result.success
            if result.success {
              logOk(logLevel, `Build complete (${Float.toString(result.durationMs)}ms)`)
            } else {
              logErr(logLevel, `Build failed (${Int.toString(Array.length(result.diagnostics))} errors)`)
            }
          }
        }

        // Build additional adapter languages
        let adapterPromises = state.activeAdapters->Array.map(async as_ => {
          logInfo(logLevel, `Running ${as_.adapter.displayName} build...`)
          let result = await as_.adapter.build(root, as_.config)
          as_.lastBuildSuccess = result.success
          as_.diagnostics = result.diagnostics
          if result.success {
            logOk(logLevel, `${as_.adapter.displayName} build complete (${Float.toString(result.durationMs)}ms)`)
          } else {
            logErr(logLevel, `${as_.adapter.displayName} build failed (${Int.toString(Array.length(result.diagnostics))} errors)`)
          }
        })

        // Await all adapter builds
        let _ = await Promise.all(adapterPromises)
      }
    }),

    handleHotUpdate: Some(ctx => {
      let file = ctx.file

      // Check if this file belongs to an additional adapter
      let adapterMatch = findAdapterForFile(state, file)

      switch adapterMatch {
      | Some(as_) => {
          // Handle via adapter
          logInfo(logLevel, `[${as_.adapter.displayName}] File changed: ${file}`)
          let jsFile = as_.adapter.getOutputPath(as_.config, file)

          let modules = ctx.server.moduleGraph.getModulesByFile(jsFile)
          switch modules {
          | Some(mods) if Array.length(mods) > 0 => {
              if as_.lastBuildSuccess {
                clearOverlay(ctx.server)
              }
              let errors = as_.diagnostics->Array.filter(d => d.severity === #error)
              if Array.length(errors) > 0 {
                switch Array.get(errors, 0) {
                | Some(err) => sendOverlayErrorFromAdapter(ctx.server, err)
                | None => ()
                }
              }
              as_.diagnostics = []
              Some(mods)
            }
          | _ => {
              logInfo(logLevel, `Full reload for ${file} (not in module graph)`)
              None
            }
          }
        }
      | None => {
          // Handle ReScript files (legacy path, always active)
          if file->String.endsWith(".res") || file->String.endsWith(".resi") {
            logInfo(logLevel, `File changed: ${file}`)

            let suffix = state.rescriptConfig.suffix
            let jsFile = if state.rescriptConfig.packageSpec.inSource {
              let base = if file->String.endsWith(".resi") {
                file->String.replace(".resi", suffix)
              } else {
                file->String.replace(".res", suffix)
              }
              base
            } else {
              let root = switch state.viteConfig {
              | Some(c) => c.root
              | None => "."
              }
              let rel = relative(root, file)
              let outputPath = RescriptConfig.getOutputPath(state.rescriptConfig, rel)
              resolve(root, outputPath)
            }

            let modules = ctx.server.moduleGraph.getModulesByFile(jsFile)

            switch modules {
            | Some(mods) if Array.length(mods) > 0 => {
                if state.lastBuildSuccess {
                  clearOverlay(ctx.server)
                }
                let errors = state.diagnostics->Array.filter(d => d.severity === Error)
                if Array.length(errors) > 0 {
                  switch Array.get(errors, 0) {
                  | Some(err) => sendOverlayError(ctx.server, err)
                  | None => ()
                  }
                }
                state.diagnostics = []
                Some(mods)
              }
            | _ => {
                logInfo(logLevel, `Full reload for ${file} (not in module graph)`)
                None
              }
            }
          } else {
            None
          }
        }
      }
    }),

    buildEnd: Some(() => {
      // Report ReScript diagnostics summary
      let errorCount = state.diagnostics->Array.filter(d => d.severity === Error)->Array.length
      let warnCount = state.diagnostics->Array.filter(d => d.severity === Warning)->Array.length
      if errorCount > 0 {
        logErr(logLevel, `${Int.toString(errorCount)} errors, ${Int.toString(warnCount)} warnings`)
      } else if warnCount > 0 {
        logWarn(logLevel, `${Int.toString(warnCount)} warnings`)
      } else {
        logOk(logLevel, "No issues")
      }

      // Report additional adapter diagnostics
      Array.forEach(state.activeAdapters, as_ => {
        let eCount = as_.diagnostics->Array.filter(d => d.severity === #error)->Array.length
        let wCount = as_.diagnostics->Array.filter(d => d.severity === #warning)->Array.length
        if eCount > 0 {
          logErr(logLevel, `[${as_.adapter.displayName}] ${Int.toString(eCount)} errors, ${Int.toString(wCount)} warnings`)
        } else if wCount > 0 {
          logWarn(logLevel, `[${as_.adapter.displayName}] ${Int.toString(wCount)} warnings`)
        }
      })
    }),

    closeBundle: Some(() => {
      // Stop ReScript watch-mode compiler
      switch state.watchHandle {
      | Some(handle) => {
          RescriptCompiler.stop(handle)
          logInfo(logLevel, "ReScript watch mode stopped")
        }
      | None => ()
      }

      // Stop additional adapter watch processes
      Array.forEach(state.activeAdapters, as_ => {
        switch as_.watchHandle {
        | Some(handle) => {
            handle.stop()
            handle.stopped = true
            logInfo(logLevel, `${as_.adapter.displayName} watch mode stopped`)
          }
        | None => ()
        }
      })

      // Disconnect BoJ
      switch state.bojBridge {
      | Some(bridge) => {
          BojBridge.disconnect(bridge)
          logInfo(logLevel, "BoJ disconnected")
        }
      | None => ()
      }
    }),
  }
}

/// Convenience alias for make with adapters — same as make but named for clarity.
///
/// Usage:
///   import { makeWithAdapters } from "rescript-vite"
///   import { make as affinescriptAdapter } from "rescript-vite/adapter/affinescript"
///   export default { plugins: [makeWithAdapters({ adapters: [affinescriptAdapter()] })] }
let makeWithAdapters = make

/// Default export — create plugin with default options (ReScript only)
let default = make(~options=None)
