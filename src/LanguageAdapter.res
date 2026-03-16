// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// LanguageAdapter.res — Pluggable language adapter protocol.
//
// Defines the interface that all language adapters must implement.
// Each adapter teaches the plugin how to:
//   - Detect whether a project uses the language
//   - Read language-specific configuration
//   - Build/compile source files
//   - Parse compiler diagnostics
//   - Resolve module imports
//   - Map source files to compiled output
//
// Current adapters:
//   - ReScript  (primary, built-in)
//   - AffineScript (secondary, OCaml compiler bridge)
//
// The adapter protocol is designed so that:
//   1. rescript-vite remains the ReScript-first plugin
//   2. AffineScript support lives alongside as a secondary adapter
//   3. Future adapters (Gleam, Elixir, Idris2) can plug in
//   4. AffineScript can eventually split into affinescript-vite
//   5. The adapter protocol becomes part of PanLL's language panel system

/// Source file extensions this adapter handles (e.g., [".res", ".resi"])
type fileExtensions = array<string>

/// Compiler diagnostic from any language
type diagnostic = {
  file: string,
  line: int,
  column: int,
  endLine: int,
  endColumn: int,
  severity: [#error | #warning | #info],
  message: string,
  /// Which language produced this diagnostic
  language: string,
}

/// Result of a build invocation
type buildResult = {
  success: bool,
  diagnostics: array<diagnostic>,
  changedFiles: array<string>,
  durationMs: float,
}

/// Configuration detected from a language's config file
type languageConfig = {
  /// Language identifier (e.g., "rescript", "affinescript")
  language: string,
  /// Project name from config file
  name: string,
  /// Output suffix (e.g., ".res.js", ".as.wasm")
  suffix: string,
  /// Source directories
  sources: array<string>,
  /// Whether compiled output lives alongside source files
  inSource: bool,
  /// Module format (e.g., "esmodule", "commonjs", "wasm")
  moduleFormat: string,
  /// Path to the config file that was read
  configPath: string,
  /// Dependencies declared in config
  dependencies: array<string>,
}

/// A watch handle for a running compiler process
type watchHandle = {
  /// Stop the watch process
  stop: unit => unit,
  /// Whether the process has been stopped
  mutable stopped: bool,
}

/// The language adapter interface.
///
/// Each adapter is a record of functions — not a class or module functor.
/// This keeps things simple and allows adapters to be composed, overridden,
/// or hot-swapped at runtime (useful for PanLL panel integration).
type t = {
  /// Unique language identifier (e.g., "rescript", "affinescript")
  id: string,

  /// Human-readable language name (e.g., "ReScript", "AffineScript")
  displayName: string,

  /// File extensions this adapter handles (e.g., [".res", ".resi"])
  extensions: fileExtensions,

  /// Detect whether a project root contains this language.
  /// Returns the path to the config file if found, None otherwise.
  detect: string => option<string>,

  /// Read the language-specific config from a project root.
  readConfig: string => languageConfig,

  /// Default config when no config file is found.
  defaultConfig: languageConfig,

  /// Get the compiled output path for a source file.
  getOutputPath: (languageConfig, string) => string,

  /// Build the project (one-shot). Returns a promise of the build result.
  build: (string, languageConfig) => promise<buildResult>,

  /// Start a watch-mode compiler. Returns a handle to stop it.
  watch: (string, languageConfig) => watchHandle,

  /// Parse compiler output into diagnostics.
  parseDiagnostics: string => array<diagnostic>,

  /// Resolve a module import (e.g., PascalCase fix for ReScript).
  /// Returns Some(resolvedPath) if the adapter can resolve it, None otherwise.
  resolveImport: (string, string, languageConfig) => option<string>,

  /// Packages to exclude from Vite's dependency pre-bundling.
  excludePackages: array<string>,

  /// Glob patterns for build artifacts to ignore in Vite's watcher.
  artifactIgnorePatterns: array<string>,
}

/// Find the first adapter that detects a project at the given root.
let detectLanguage = (adapters: array<t>, root: string): option<(t, string)> => {
  let result = ref(None)
  let i = ref(0)
  while i.contents < Array.length(adapters) && Option.isNone(result.contents) {
    let adapter = adapters->Array.getUnsafe(i.contents)
    switch adapter.detect(root) {
    | Some(configPath) => result := Some((adapter, configPath))
    | None => ()
    }
    i := i.contents + 1
  }
  result.contents
}

/// Find all adapters that detect projects at the given root.
/// Useful for multi-language projects (e.g., ReScript + AffineScript).
let detectAllLanguages = (adapters: array<t>, root: string): array<(t, string)> => {
  adapters->Array.filterMap(adapter => {
    switch adapter.detect(root) {
    | Some(configPath) => Some((adapter, configPath))
    | None => None
    }
  })
}

/// Merge exclude packages from multiple adapters (deduplicates).
let mergeExcludePackages = (adapters: array<t>): array<string> => {
  let seen: Dict.t<bool> = Dict.make()
  let result: array<string> = []
  Array.forEach(adapters, adapter => {
    Array.forEach(adapter.excludePackages, pkg => {
      if !(Dict.get(seen, pkg)->Option.getOr(false)) {
        Dict.set(seen, pkg, true)
        Array.push(result, pkg)->ignore
      }
    })
  })
  result
}

/// Merge artifact ignore patterns from multiple adapters (deduplicates).
let mergeArtifactPatterns = (adapters: array<t>): array<string> => {
  let seen: Dict.t<bool> = Dict.make()
  let result: array<string> = []
  Array.forEach(adapters, adapter => {
    Array.forEach(adapter.artifactIgnorePatterns, pat => {
      if !(Dict.get(seen, pat)->Option.getOr(false)) {
        Dict.set(seen, pat, true)
        Array.push(result, pat)->ignore
      }
    })
  })
  result
}
