// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// VitePluginRescript.res — Vite plugin for first-class ReScript support.
//
// This plugin solves EVERY known pain point for ReScript + Vite:
//
//   1. Automatic ReScript compiler spawning (build + watch + rewatch)
//   2. HMR for .res files via compiled output tracking
//   3. Error overlay integration (diagnostics -> Vite overlay)
//   4. PascalCase module resolution (Linux case-sensitivity fix)
//   5. Auto optimizeDeps exclusion (@rescript/core, @rescript/runtime)
//   6. Build artifact watcher ignore (.ast, .cmj, .cmi, .cmt)
//   7. rescript.json auto-detection (suffix, module format, in-source)
//   8. @rescript/core alias resolution for monorepos + Deno
//   9. ANSI color forwarding (NINJA_ANSI_FORCED=1)
//  10. In-source: false path remapping (lib/es6/ -> src/)
//  11. Deno-compatible (auto-detects runtime)
//  12. Optional BoJ ssg-mcp build orchestration
//
// Usage in vite.config.js:
//   import rescriptPlugin from "rescript-vite"
//   export default { plugins: [rescriptPlugin()] }
//
// Usage with options:
//   import { make } from "rescript-vite"
//   export default { plugins: [make({ boj: true, logLevel: "verbose" })] }

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
}

/// Internal plugin state
type pluginState = {
  mutable config: option<ViteTypes.resolvedConfig>,
  mutable watchHandle: option<RescriptCompiler.watchHandle>,
  mutable bojBridge: option<BojBridge.t>,
  mutable pendingHmrFiles: array<string>,
  mutable lastBuildSuccess: bool,
  mutable diagnostics: array<RescriptCompiler.diagnostic>,
  mutable rescriptConfig: RescriptConfig.rescriptConfig,
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
  // Check if rewatch binary exists in node_modules
  let rewatchPath = joinPath3(root, "node_modules", ".bin/rewatch")
  existsSync(rewatchPath)
}

/// Send diagnostics to the Vite error overlay
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

/// Create the Vite plugin
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
  })

  let logLevel = opts.logLevel->Option.getOr("info")
  let useDeno = opts.useDeno->Option.getOr(isDeno())
  let wantAutoOptimize = opts.autoOptimizeDeps->Option.getOr(true)
  let wantAutoResolve = opts.autoResolve->Option.getOr(true)
  let wantAutoIgnore = opts.autoIgnoreArtifacts->Option.getOr(true)

  let state: pluginState = {
    config: None,
    watchHandle: None,
    bojBridge: None,
    pendingHmrFiles: [],
    lastBuildSuccess: true,
    diagnostics: [],
    rescriptConfig: RescriptConfig.defaultRescriptConfig,
  }

  {
    name: "rescript-vite",
    enforce: Some("pre"),

    // --- config hook: auto-configure Vite for ReScript ---
    // This runs before Vite resolves the config, so we can inject defaults.
    config: Some(() => {
      // Read rescript.json early (before configResolved, which gives us root)
      // We use "." as fallback — config hook runs before root is resolved
      let rescriptCfg = RescriptConfig.read(".")
      state.rescriptConfig = rescriptCfg

      if rescriptCfg.configPath !== "" {
        logInfo(logLevel, `Detected ${rescriptCfg.configPath} (suffix: ${rescriptCfg.suffix}, format: ${rescriptCfg.packageSpec.moduleFormat}, in-source: ${rescriptCfg.packageSpec.inSource ? "true" : "false"})`)
      }

      // Build the partial config object
      // We use %raw because Vite's config merge is deeply permissive
      let configPatch: JSON.t = if wantAutoOptimize || wantAutoIgnore {
        %raw(`(function() {
          var cfg = {};

          // Auto-exclude @rescript/* from dependency pre-bundling
          if (wantAutoOptimize) {
            cfg.optimizeDeps = {
              exclude: ["@rescript/core", "@rescript/runtime", "@rescript/react", "rescript"]
            };
          }

          // Auto-ignore build artifacts in file watcher
          if (wantAutoIgnore) {
            cfg.server = cfg.server || {};
            cfg.server.watch = cfg.server.watch || {};
            cfg.server.watch.ignored = [
              "**/*.ast", "**/*.cmj", "**/*.cmi", "**/*.cmt",
              "**/lib/bs/**", "**/lib/es6/**", "**/lib/js/**",
              "**/lib/ocaml/**", "**/.merlin", "**/.bsb.lock"
            ];
          }

          // Set NINJA_ANSI_FORCED for colored compiler output
          cfg.define = cfg.define || {};

          return cfg;
        })()`)
      } else {
        %raw(`({})`)
      }

      configPatch
    }),

    configResolved: Some(resolvedConfig => {
      state.config = Some(resolvedConfig)

      // Re-read rescript.json with the actual root
      let rescriptCfg = RescriptConfig.read(resolvedConfig.root)
      state.rescriptConfig = rescriptCfg

      // Apply suffix override if provided
      switch opts.suffix {
      | Some(s) => state.rescriptConfig = {...state.rescriptConfig, suffix: s}
      | None => ()
      }

      logInfo(logLevel, `Project root: ${resolvedConfig.root}`)
      logInfo(logLevel, `Mode: ${resolvedConfig.command} (${resolvedConfig.mode})`)
      logInfo(logLevel, `ReScript suffix: ${state.rescriptConfig.suffix}`)
      if !state.rescriptConfig.packageSpec.inSource {
        logInfo(logLevel, `Out-of-source mode: compiled output in lib/${state.rescriptConfig.packageSpec.moduleFormat === "esmodule" ? "es6" : "js"}/`)
      }
    }),

    // --- configureServer: add watcher patterns and set env ---
    configureServer: Some(_server => {
      // Set NINJA_ANSI_FORCED for colored ReScript compiler output in terminal
      %raw(`process.env.NINJA_ANSI_FORCED = "1"`)
    }),

    // --- resolveId: PascalCase module resolution ---
    // ReScript emits lowercase imports but files are PascalCase on disk.
    // On case-sensitive filesystems (Linux), this breaks. We fix it here.
    resolveId: if wantAutoResolve {
      Some(async (source, importer) => {
        switch importer {
        | None => None
        | Some(imp) => {
            let suffix = state.rescriptConfig.suffix
            switch tryPascalCaseResolve(source, imp, suffix) {
            | Some(resolved) => Some({ViteTypes.id: resolved})
            | None => None
            }
          }
        }
      })
    } else {
      None
    },

    buildStart: Some(async () => {
      let root = switch state.config {
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

      // --- Detect rewatch ---
      let useRewatch = opts.useRewatch->Option.getOr(hasRewatch(root))

      // --- Compiler ---
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

      let config = switch state.config {
      | Some(c) => c
      | None => {root: ".", command: "build", mode: "production"}
      }

      if config.command === "serve" {
        // Dev mode — start watch
        logInfo(logLevel, useRewatch ? "Starting rewatch..." : "Starting ReScript compiler in watch mode...")
        let handle = RescriptCompiler.watch(compilerConfig)
        state.watchHandle = Some(handle)
        logOk(logLevel, useRewatch ? "Rewatch active" : "ReScript watch mode active")
      } else {
        // Production build — one-shot
        logInfo(logLevel, "Running ReScript build...")

        switch state.bojBridge {
        | Some(bridge) => {
            // Delegate to BoJ
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
      }
    }),

    handleHotUpdate: Some(ctx => {
      let file = ctx.file

      // Only handle .res file changes
      if file->String.endsWith(".res") || file->String.endsWith(".resi") {
        logInfo(logLevel, `File changed: ${file}`)

        // The compiler watch process handles recompilation.
        // We need to find the corresponding compiled module in Vite's module graph.
        let suffix = state.rescriptConfig.suffix
        let jsFile = if state.rescriptConfig.packageSpec.inSource {
          // In-source: App.res -> App.res.js (suffix replaces nothing, appended)
          let base = if file->String.endsWith(".resi") {
            // Interface files don't produce output — look for the .res file's output
            file->String.replace(".resi", suffix)
          } else {
            file->String.replace(".res", suffix)
          }
          base
        } else {
          // Out-of-source: need to map src/App.res -> lib/es6/src/App.res.js
          let root = switch state.config {
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
            // Clear any previous error overlay if build succeeded
            if state.lastBuildSuccess {
              clearOverlay(ctx.server)
            }

            // Send diagnostics to overlay if there are errors
            let errors = state.diagnostics->Array.filter(d => d.severity === Error)
            if Array.length(errors) > 0 {
              switch Array.get(errors, 0) {
              | Some(err) => sendOverlayError(ctx.server, err)
              | None => ()
              }
            }

            // Clear accumulated diagnostics for next cycle
            state.diagnostics = []

            // Return affected modules for HMR
            Some(mods)
          }
        | _ => {
            // Module not in graph yet — trigger full reload
            logInfo(logLevel, `Full reload for ${file} (not in module graph)`)
            None
          }
        }
      } else {
        // Not a ReScript file — let other plugins handle it
        None
      }
    }),

    buildEnd: Some(() => {
      // Report final diagnostics summary
      let errorCount = state.diagnostics->Array.filter(d => d.severity === Error)->Array.length
      let warnCount = state.diagnostics->Array.filter(d => d.severity === Warning)->Array.length
      if errorCount > 0 {
        logErr(logLevel, `${Int.toString(errorCount)} errors, ${Int.toString(warnCount)} warnings`)
      } else if warnCount > 0 {
        logWarn(logLevel, `${Int.toString(warnCount)} warnings`)
      } else {
        logOk(logLevel, "No issues")
      }
    }),

    closeBundle: Some(() => {
      // Stop the watch-mode compiler
      switch state.watchHandle {
      | Some(handle) => {
          RescriptCompiler.stop(handle)
          logInfo(logLevel, "ReScript watch mode stopped")
        }
      | None => ()
      }

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

/// Default export — create plugin with default options
let default = make(~options=None)
