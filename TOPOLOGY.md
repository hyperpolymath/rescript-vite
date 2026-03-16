<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- TOPOLOGY.md — rescript-vite architecture map and completion dashboard -->
<!-- Last updated: 2026-03-16 -->

# rescript-vite — Project Topology

## System Architecture

```
                     ┌─────────────────────────────────────────────┐
                     │              USER'S PROJECT                 │
                     │   vite.config.js:                           │
                     │     plugins: [rescriptPlugin()]             │
                     │     // or: makeWithAdapters({               │
                     │     //   adapters: [affinescriptAdapter()]  │
                     │     // })                                   │
                     └──────────────────┬──────────────────────────┘
                                        │
                     ┌──────────────────▼──────────────────────────┐
                     │           RESCRIPT-VITE PLUGIN               │
                     │                                              │
                     │  ┌─────────────┐  ┌──────────────────────┐  │
                     │  │ config()    │  │ resolveId()          │  │
                     │  │ Merge all   │  │ Try ReScript pascal  │  │
                     │  │ adapter     │  │ Then try each adapter│  │
                     │  │ excludes &  │  │ resolveImport()      │  │
                     │  │ ignores     │  └──────────┬───────────┘  │
                     │  └──────┬──────┘             │               │
                     │         │                    │               │
                     │  ┌──────▼──────┐  ┌──────────▼───────────┐  │
                     │  │ buildStart()│  │ handleHotUpdate()    │  │
                     │  │ Start all   │  │ Find adapter by ext  │  │
                     │  │ compilers   │  │ Map to compiled      │  │
                     │  │ (ReScript + │  │ output, HMR/overlay  │  │
                     │  │  adapters)  │  └──────────────────────┘  │
                     │  └──────┬──────┘                             │
                     └─────────│───────────────────────────────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
  ┌──────────────┐   ┌──────────────────┐   ┌──────────────────┐
  │LanguageAdapter│   │ ReScript         │   │ AffineScript     │
  │  Protocol     │   │ (built-in)       │   │ Adapter          │
  │               │   │                  │   │                  │
  │ detect()      │   │ RescriptConfig   │   │ OCaml compiler   │
  │ readConfig()  │   │ RescriptCompiler │   │ dune build       │
  │ build()       │   │ PascalCase fix   │   │ .as -> .as.js    │
  │ watch()       │   │ .res -> .res.js  │   │ WASM codegen     │
  │ parseDiags()  │   └──────────────────┘   └──────────────────┘
  │ resolveImport │
  └──────┬────────┘
         │
         ▼
  ┌──────────────┐
  │ BojBridge    │
  │ (optional)   │
  │ JSON-RPC 2.0 │
  │ ssg-mcp      │
  └──────────────┘
```

## Module Dependency Graph

```
VitePluginRescript ──► LanguageAdapter (protocol types)
        │         ──► RescriptConfig (config detection)
        │         ──► RescriptCompiler (child process)
        │         ──► BojBridge (optional orchestration)
        │         ──► ViteTypes (Vite API bindings)
        │
RescriptAdapter ───► RescriptConfig
                ──► RescriptCompiler
                ──► VitePluginRescript (tryPascalCaseResolve)
                ──► LanguageAdapter (implements protocol)

AffineScriptAdapter ──► LanguageAdapter (implements protocol)
                    ──► node:child_process (compiler bridge)
```

## Completion Dashboard

```
COMPONENT                          STATUS              NOTES
─────────────────────────────────  ──────────────────  ─────────────────────────────────
CORE PLUGIN
  Compiler bridge (build/watch)    ██████████ 100%    spawn + stream + parse
  Rewatch support                  ██████████ 100%    auto-detect, native commands
  Diagnostic parsing               ██████████ 100%    error/warning, ANSI strip
  Error overlay integration        ██████████ 100%    push/clear via Vite WS
  HMR for .res files               ██████████ 100%    module graph lookup
  Deno compatibility               ██████████ 100%    auto-detect runtime

AUTO-CONFIGURATION
  rescript.json auto-detection     ██████████ 100%    suffix, format, in-source
  optimizeDeps exclusion           ██████████ 100%    merged across all adapters
  PascalCase module resolution     ██████████ 100%    resolveId hook, Linux fix
  Build artifact watcher ignore    ██████████ 100%    merged across all adapters
  ANSI color forwarding            ██████████ 100%    NINJA_ANSI_FORCED=1
  In-source: false path remapping  ██████████ 100%    lib/es6/ -> src/ mapping

LANGUAGE ADAPTER SYSTEM
  LanguageAdapter protocol         ██████████ 100%    pluggable interface
  RescriptAdapter                  ██████████ 100%    wraps existing modules
  AffineScriptAdapter              ██████████ 100%    OCaml compiler bridge
  Multi-adapter detection          ██████████ 100%    detectLanguage/detectAll
  Merged config (excludes/ignores) ██████████ 100%    deduplication
  Per-adapter HMR                  ██████████ 100%    extension-based routing

OPTIONAL INTEGRATIONS
  BoJ ssg-mcp build orchestration  ██████████ 100%    JSON-RPC, probe, fallback
  panic-attack SARIF compat        ██████████ 100%    Diagnostic format mapping

TESTING
  Vite plugin tests                ██████████ 100%    19 tests
  Compiler tests                   ██████████ 100%    20 tests
  Config auto-detect tests         ██████████ 100%    10 tests
  BoJ bridge tests                 ██████████ 100%    9 tests
  panic-attack tests               ██████████ 100%    10 tests
  Language adapter tests           ██████████ 100%    16 tests

PUBLISHING
  npm publish                      ░░░░░░░░░░  0%    Not yet published
  Deno JSR publish                 ░░░░░░░░░░  0%    Not yet published
  Real-world integration test      █████░░░░░ 50%    Used in idaptik (manual)

─────────────────────────────────────────────────────────────────────────────
OVERALL:                           █████████░ 95%    v1.0.0 — publishing pending
```

## Update Protocol

This file is maintained by both humans and AI agents. When updating:

1. **After completing a component**: Change its bar and percentage
2. **After adding a component**: Add a new row in the appropriate section
3. **After architectural changes**: Update the ASCII diagram
4. **Date**: Update the `Last updated` comment at the top of this file

Progress bars use: `█` (filled) and `░` (empty), 10 characters wide.
Percentages: 0%, 10%, 20%, ... 100% (in 10% increments).
