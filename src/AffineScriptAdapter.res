// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// AffineScriptAdapter.res — AffineScript language adapter.
//
// Bridges the AffineScript compiler (OCaml-based, at nextgen-languages/affinescript)
// into the LanguageAdapter protocol. AffineScript compiles to WebAssembly and
// JavaScript, making it a natural fit for Vite's bundling pipeline.
//
// AffineScript features:
//   - Affine types (Rust-style ownership without GC)
//   - Dependent types (compile-time size verification)
//   - Row polymorphism (extensible records)
//   - Extensible effects (tracked side effects)
//   - WASM code generation (production)
//   - Julia code generation (batch processing)
//   - js_of_ocaml playground bundle (browser)
//
// This adapter handles the .as file extension and bridges to the OCaml-based
// compiler via child process. It detects projects by looking for affinescript.opam
// or a dune-project with affinescript references.

@module("node:fs") external existsSync: string => bool = "existsSync"
@module("node:fs") external readFileSync: (string, string) => string = "readFileSync"
@module("node:path") external joinPath: (string, string) => string = "join"
@module("node:path") external joinPath3: (string, string, string) => string = "join"
@module("node:path") external dirname: string => string = "dirname"
@module("node:path") external basename: string => string = "basename"

// Child process FFI (shared with RescriptCompiler)
type childProcess
type readable

@module("node:child_process")
external spawn: (string, array<string>, {..}) => childProcess = "spawn"

@send external kill: childProcess => unit = "kill"
@get external stdout: childProcess => readable = "stdout"
@get external stderr: childProcess => readable = "stderr"

let onProcessData: (readable, string => unit) => unit = %raw(`
  function(stream, cb) { stream.on("data", function(d) { cb(String(d)); }); }
`)

let onProcessClose: (childProcess, int => unit) => unit = %raw(`
  function(proc, cb) { proc.on("close", cb); }
`)

@val external performanceNow: unit => float = "performance.now"

/// Default AffineScript config when no opam/dune config is found
let defaultConfig: LanguageAdapter.languageConfig = {
  language: "affinescript",
  name: "unknown",
  suffix: ".as.js",
  sources: ["src", "lib", "examples"],
  inSource: true,
  moduleFormat: "esmodule",
  configPath: "",
  dependencies: [],
}

/// Strip ANSI escape codes
let stripAnsi = (s: string): string => s->String.replaceRegExp(%re("/\x1b\[[0-9;]*m/g"), "")

/// Parse AffineScript compiler diagnostics.
///
/// AffineScript error format (OCaml-style):
///   File "src/main.as", line 42, characters 10-55:
///   Error: This expression has type String but expected Int
///
/// Also handles the structured error format from the error_formatter:
///   [Error] src/main.as:42:10 - Type mismatch: expected Int, got String
let parseDiagnostics = (output: string): array<LanguageAdapter.diagnostic> => {
  let lines = output->String.split("\n")
  let diagnostics: array<LanguageAdapter.diagnostic> = []
  let i = ref(0)

  while i.contents < Array.length(lines) {
    let line = lines->Array.getUnsafe(i.contents)
    let clean = stripAnsi(line)

    // Try OCaml-style: File "path", line N, characters C1-C2:
    let ocamlMatch: option<(string, int, int, int)> = %raw(`
      (function(s) {
        var m = s.match(/File "([^"]+)", line (\d+), characters (\d+)-(\d+)/);
        if (!m) return undefined;
        return [m[1], parseInt(m[2], 10), parseInt(m[3], 10), parseInt(m[4], 10)];
      })(clean)
    `)

    switch ocamlMatch {
    | Some((file, lineNum, col, endCol)) => {
        // Next line(s) contain the severity and message
        let sev = ref(#error)
        let msgLines: array<string> = []
        let j = ref(i.contents + 1)
        let done = ref(false)

        while j.contents < Array.length(lines) && !done.contents {
          let msgLine = stripAnsi(lines->Array.getUnsafe(j.contents))
          if msgLine->String.startsWith("File ") || msgLine->String.trim->String.length === 0 && Array.length(msgLines) > 0 {
            done := true
          } else {
            if msgLine->String.includes("Warning") {
              sev := #warning
            }
            let trimmed = msgLine->String.trim
            if trimmed->String.length > 0 {
              // Strip leading "Error: " or "Warning N: " prefix
              let cleaned = trimmed
                ->String.replaceRegExp(%re("/^Error:\s*/"), "")
                ->String.replaceRegExp(%re("/^Warning \d+:\s*/"), "")
              Array.push(msgLines, cleaned)->ignore
            }
            j := j.contents + 1
          }
        }

        Array.push(diagnostics, {
          file,
          line: lineNum,
          column: col,
          endLine: lineNum,
          endColumn: endCol,
          severity: sev.contents,
          message: Array.join(msgLines, "\n"),
          language: "affinescript",
        })->ignore
        i := j.contents
      }
    | None => {
        // Try structured format: [Error] path:line:col - message
        let structMatch: option<(string, string, int, int)> = %raw(`
          (function(s) {
            var m = s.match(/\[(Error|Warning|Info)\]\s+(.+?):(\d+):(\d+)/);
            if (!m) return undefined;
            return [m[1].toLowerCase(), m[2], parseInt(m[3], 10), parseInt(m[4], 10)];
          })(clean)
        `)

        switch structMatch {
        | Some((sevStr, file, lineNum, col)) => {
            let sev: [#error | #warning | #info] = switch sevStr {
            | "warning" => #warning
            | "info" => #info
            | _ => #error
            }
            // Extract message after the " - " separator
            let msg = switch clean->String.split(" - ")->Array.get(1) {
            | Some(m) => m
            | None => clean
            }
            Array.push(diagnostics, {
              file,
              line: lineNum,
              column: col,
              endLine: lineNum,
              endColumn: col,
              severity: sev,
              message: msg,
              language: "affinescript",
            })->ignore
            i := i.contents + 1
          }
        | None => i := i.contents + 1
        }
      }
    }
  }

  diagnostics
}

/// Detect whether a project root contains AffineScript source files.
///
/// Detection strategy (in priority order):
///   1. affinescript.opam — definitive: this IS an AffineScript project
///   2. .build/affinescript.opam — some projects put opam in .build/
///   3. dune-project with affinescript reference
///   4. Any .as files in src/ or lib/ directories
let detect = (root: string): option<string> => {
  let opamPath = joinPath(root, "affinescript.opam")
  let buildOpamPath = joinPath3(root, ".build", "affinescript.opam")
  let dunePath = joinPath(root, "dune-project")

  if existsSync(opamPath) {
    Some(opamPath)
  } else if existsSync(buildOpamPath) {
    Some(buildOpamPath)
  } else if existsSync(dunePath) {
    // Check if dune-project references affinescript
    try {
      let content = readFileSync(dunePath, "utf-8")
      if content->String.includes("affinescript") {
        Some(dunePath)
      } else {
        None
      }
    } catch {
    | _ => None
    }
  } else {
    None
  }
}

/// Read AffineScript project config.
///
/// AffineScript uses opam for package metadata and dune for build config.
/// We extract what we can from affinescript.opam and scan for source dirs.
let readConfig = (root: string): LanguageAdapter.languageConfig => {
  let opamPath = joinPath(root, "affinescript.opam")
  let buildOpamPath = joinPath3(root, ".build", "affinescript.opam")

  let configPath = if existsSync(opamPath) {
    opamPath
  } else if existsSync(buildOpamPath) {
    buildOpamPath
  } else {
    ""
  }

  if configPath === "" {
    defaultConfig
  } else {
    try {
      let content = readFileSync(configPath, "utf-8")

      // Extract name from opam: name: "affinescript"
      let name: string = %raw(`
        (function(c) {
          var m = c.match(/name:\s*"([^"]+)"/);
          return m ? m[1] : "affinescript";
        })(content)
      `)

      // Detect source directories
      let sources: array<string> = []
      if existsSync(joinPath(root, "lib")) {
        Array.push(sources, "lib")->ignore
      }
      if existsSync(joinPath(root, "bin")) {
        Array.push(sources, "bin")->ignore
      }
      if existsSync(joinPath(root, "examples")) {
        Array.push(sources, "examples")->ignore
      }
      if existsSync(joinPath(root, "src")) {
        Array.push(sources, "src")->ignore
      }
      if Array.length(sources) === 0 {
        Array.push(sources, "lib")->ignore
      }

      {
        language: "affinescript",
        name,
        suffix: ".as.js",
        sources,
        inSource: true,
        moduleFormat: "esmodule",
        configPath,
        dependencies: [],
      }
    } catch {
    | _ => defaultConfig
    }
  }
}

/// Get the compiled output path for a .as source file.
///
/// AffineScript has multiple compilation targets:
///   - .as.js  — JavaScript output (via js_of_ocaml or interpreter)
///   - .as.wasm — WebAssembly binary (via codegen.ml)
///   - .as.jl  — Julia output (via Julia codegen)
///
/// For Vite integration, we use .as.js as the default suffix since
/// Vite's bundler works with JS/WASM modules.
let getOutputPath = (_config: LanguageAdapter.languageConfig, asFile: string): string => {
  // In-source: lib/ast.as -> lib/ast.as.js
  asFile ++ ".js"
}

/// Build an AffineScript project.
///
/// Uses `dune exec affinescript -- build` to compile .as files.
/// Falls back to direct `affinescript build` if not in a dune project.
let build = (root: string, _config: LanguageAdapter.languageConfig): promise<LanguageAdapter.buildResult> => {
  Promise.make((resolve, _reject) => {
    let startTime = performanceNow()
    let outputBuf = ref("")
    let errorBuf = ref("")

    // Determine build command
    let (cmd, args) = if existsSync(joinPath(root, "dune-project")) {
      ("dune", ["exec", "affinescript", "--", "build"])
    } else {
      ("affinescript", ["build"])
    }

    let proc = spawn(cmd, args, {"cwd": root, "shell": true})

    onProcessData(proc->stdout, chunk => {
      outputBuf := outputBuf.contents ++ chunk
    })
    onProcessData(proc->stderr, chunk => {
      errorBuf := errorBuf.contents ++ chunk
    })

    onProcessClose(proc, code => {
      let allOutput = outputBuf.contents ++ errorBuf.contents
      let diagnostics = parseDiagnostics(allOutput)
      let duration = performanceNow() -. startTime

      let result: LanguageAdapter.buildResult = {
        success: code === 0,
        diagnostics,
        changedFiles: [],
        durationMs: duration,
      }
      resolve(result)
    })
  })
}

/// Start AffineScript in watch mode.
///
/// AffineScript doesn't have a native watch mode yet, so we use
/// a polling approach via dune's watch mechanism.
let watch = (root: string, _config: LanguageAdapter.languageConfig): LanguageAdapter.watchHandle => {
  let (cmd, args) = if existsSync(joinPath(root, "dune-project")) {
    ("dune", ["build", "--watch"])
  } else {
    // Fallback: no watch mode available, just do a single build
    ("affinescript", ["build"])
  }

  let proc = spawn(cmd, args, {"cwd": root, "shell": true})

  {
    stop: () => proc->kill,
    stopped: false,
  }
}

/// Resolve AffineScript module imports.
///
/// AffineScript uses snake_case module names that map directly to filenames,
/// so resolution is simpler than ReScript's PascalCase issue.
/// Returns None — AffineScript doesn't need import rewriting for Vite.
let resolveImport = (_source: string, _importer: string, _config: LanguageAdapter.languageConfig): option<string> => {
  None
}

/// The AffineScript language adapter.
let make = (): LanguageAdapter.t => {
  id: "affinescript",
  displayName: "AffineScript",
  extensions: [".as"],
  detect,
  readConfig,
  defaultConfig,
  getOutputPath,
  build,
  watch,
  parseDiagnostics,
  resolveImport,

  excludePackages: [
    // AffineScript's OCaml dependencies are not in node_modules
    // so there's nothing to exclude from Vite's pre-bundling.
    // When WASM output is used, the .wasm files are served directly.
  ],

  artifactIgnorePatterns: [
    // OCaml/dune build artifacts
    "**/_build/**",
    "**/.merlin",
    "**/*.cmi",
    "**/*.cmo",
    "**/*.cmx",
    "**/*.cmt",
    "**/*.cmti",
    "**/*.o",
    "**/*.a",
    // AffineScript intermediate files
    "**/*.as.wasm",
    "**/*.as.jl",
  ],
}
