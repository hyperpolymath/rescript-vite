// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// RescriptAdapter.res — ReScript language adapter.
//
// Wraps the existing RescriptCompiler and RescriptConfig modules into the
// LanguageAdapter protocol. This is the primary adapter — rescript-vite was
// built for ReScript and this adapter represents the full-featured path.

@module("node:fs") external existsSync: string => bool = "existsSync"
@module("node:path") external joinPath: (string, string) => string = "join"

/// Convert RescriptCompiler.severity to the adapter's severity tag
let convertSeverity = (sev: RescriptCompiler.severity): [#error | #warning | #info] => {
  switch sev {
  | Error => #error
  | Warning => #warning
  }
}

/// Convert RescriptCompiler.diagnostic to LanguageAdapter.diagnostic
let convertDiagnostic = (d: RescriptCompiler.diagnostic): LanguageAdapter.diagnostic => {
  file: d.file,
  line: d.line,
  column: d.column,
  endLine: d.endLine,
  endColumn: d.endColumn,
  severity: convertSeverity(d.severity),
  message: d.message,
  language: "rescript",
}

/// Convert RescriptConfig.rescriptConfig to LanguageAdapter.languageConfig
let convertConfig = (c: RescriptConfig.rescriptConfig): LanguageAdapter.languageConfig => {
  language: "rescript",
  name: c.name,
  suffix: c.suffix,
  sources: c.sources,
  inSource: c.packageSpec.inSource,
  moduleFormat: c.packageSpec.moduleFormat,
  configPath: c.configPath,
  dependencies: c.dependencies,
}

/// The ReScript language adapter.
///
/// This wraps RescriptCompiler, RescriptConfig, and the PascalCase resolver
/// from VitePluginRescript into a single adapter record.
let make = (): LanguageAdapter.t => {
  id: "rescript",
  displayName: "ReScript",
  extensions: [".res", ".resi"],

  detect: root => {
    let rescriptJson = joinPath(root, "rescript.json")
    let bsconfig = joinPath(root, "bsconfig.json")
    if existsSync(rescriptJson) {
      Some(rescriptJson)
    } else if existsSync(bsconfig) {
      Some(bsconfig)
    } else {
      None
    }
  },

  readConfig: root => {
    convertConfig(RescriptConfig.read(root))
  },

  defaultConfig: convertConfig(RescriptConfig.defaultRescriptConfig),

  getOutputPath: (config, resFile) => {
    // Convert back to RescriptConfig format for the existing function
    let rescriptConfig: RescriptConfig.rescriptConfig = {
      name: config.name,
      suffix: config.suffix,
      packageSpec: {
        moduleFormat: config.moduleFormat,
        inSource: config.inSource,
      },
      sources: config.sources,
      dependencies: config.dependencies,
      configPath: config.configPath,
    }
    RescriptConfig.getOutputPath(rescriptConfig, resFile)
  },

  build: (root, _config) => {
    let compilerConfig = RescriptCompiler.defaultConfig(root)
    RescriptCompiler.build(compilerConfig)->Promise.thenResolve(result => {
      let r: LanguageAdapter.buildResult = {
        success: result.success,
        diagnostics: result.diagnostics->Array.map(convertDiagnostic),
        changedFiles: result.changedFiles,
        durationMs: result.durationMs,
      }
      r
    })
  },

  watch: (root, _config) => {
    let compilerConfig = RescriptCompiler.defaultConfig(root)
    let handle = RescriptCompiler.watch(compilerConfig)
    let adapterHandle: LanguageAdapter.watchHandle = {
      stop: () => RescriptCompiler.stop(handle),
      stopped: false,
    }
    adapterHandle
  },

  parseDiagnostics: output => {
    RescriptCompiler.parseDiagnostics(output)->Array.map(convertDiagnostic)
  },

  resolveImport: (source, importer, config) => {
    // Reuse the PascalCase resolver from VitePluginRescript
    VitePluginRescript.tryPascalCaseResolve(source, importer, config.suffix)
  },

  excludePackages: [
    "@rescript/core",
    "@rescript/runtime",
    "@rescript/react",
    "rescript",
  ],

  artifactIgnorePatterns: [
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
  ],
}
