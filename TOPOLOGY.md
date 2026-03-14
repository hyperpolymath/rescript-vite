<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- TOPOLOGY.md — rescript-vite architecture map and completion dashboard -->
<!-- Last updated: 2026-03-14 -->

# rescript-vite — Project Topology

## System Architecture

```
                     ┌─────────────────────────────────────────────┐
                     │              USER'S PROJECT                 │
                     │   vite.config.js:                           │
                     │     plugins: [rescriptPlugin()]             │
                     └──────────────────┬──────────────────────────┘
                                        │
                     ┌──────────────────▼──────────────────────────┐
                     │           RESCRIPT-VITE PLUGIN               │
                     │                                              │
                     │  ┌─────────────┐  ┌──────────────────────┐  │
                     │  │ config()    │  │ resolveId()          │  │
                     │  │ Auto-setup  │  │ PascalCase resolver  │  │
                     │  │ optimizeDeps│  │ Linux case-fix       │  │
                     │  │ watcher ign │  │ .res.js/.res.mjs     │  │
                     │  └──────┬──────┘  └──────────┬───────────┘  │
                     │         │                    │               │
                     │  ┌──────▼──────┐  ┌──────────▼───────────┐  │
                     │  │ buildStart()│  │ handleHotUpdate()    │  │
                     │  │ Spawn       │  │ .res -> .res.js map  │  │
                     │  │ compiler    │  │ HMR module lookup    │  │
                     │  │ (build/     │  │ Error overlay push   │  │
                     │  │  watch/     │  │ Diagnostic clear     │  │
                     │  │  rewatch)   │  └──────────────────────┘  │
                     │  └──────┬──────┘                             │
                     └─────────│───────────────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
    ┌─────────▼──────┐ ┌──────▼───────┐ ┌──────▼───────┐
    │ RescriptConfig │ │ Rescript     │ │ BojBridge    │
    │                │ │ Compiler     │ │ (optional)   │
    │ Read           │ │              │ │              │
    │ rescript.json  │ │ Spawn child  │ │ JSON-RPC 2.0 │
    │ Auto-detect:   │ │ process      │ │ to ssg-mcp   │
    │ - suffix       │ │ Parse diags  │ │ cartridge    │
    │ - format       │ │ Track files  │ │ Build cache  │
    │ - in-source    │ │ Rewatch      │ │ Telemetry    │
    │ - sources      │ │ support      │ │ Fallback     │
    └────────────────┘ └──────────────┘ └──────────────┘
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
  optimizeDeps exclusion           ██████████ 100%    @rescript/core, runtime, react
  PascalCase module resolution     ██████████ 100%    resolveId hook, Linux fix
  Build artifact watcher ignore    ██████████ 100%    .ast/.cmj/.cmi/.cmt/lib/
  ANSI color forwarding            ██████████ 100%    NINJA_ANSI_FORCED=1
  In-source: false path remapping  ██████████ 100%    lib/es6/ -> src/ mapping

OPTIONAL INTEGRATIONS
  BoJ ssg-mcp build orchestration  ██████████ 100%    JSON-RPC, probe, fallback
  panic-attack SARIF compat        ██████████ 100%    Diagnostic format mapping

TESTING
  Vite plugin tests                ██████████ 100%    19 tests
  Compiler tests                   ██████████ 100%    20 tests
  Config auto-detect tests         ██████████ 100%    10 tests
  BoJ bridge tests                 ██████████ 100%    9 tests
  panic-attack tests               ██████████ 100%    10 tests

PUBLISHING
  npm publish                      ░░░░░░░░░░  0%    Not yet published
  Deno JSR publish                 ░░░░░░░░░░  0%    Not yet published
  Real-world integration test      █████░░░░░ 50%    Used in idaptik (manual)

─────────────────────────────────────────────────────────────────────────────
OVERALL:                           █████████░ 90%    Core complete, publishing pending
```

## Key Dependencies

```
rescript.json ──► RescriptConfig ──► VitePluginRescript ──► Vite Pipeline
                                          │
                  RescriptCompiler ────────┤  (child process)
                                          │
                  BojBridge ──────────────┘  (optional JSON-RPC)
```

## Update Protocol

This file is maintained by both humans and AI agents. When updating:

1. **After completing a component**: Change its bar and percentage
2. **After adding a component**: Add a new row in the appropriate section
3. **After architectural changes**: Update the ASCII diagram
4. **Date**: Update the `Last updated` comment at the top of this file

Progress bars use: `█` (filled) and `░` (empty), 10 characters wide.
Percentages: 0%, 10%, 20%, ... 100% (in 10% increments).
