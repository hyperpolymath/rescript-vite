# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-16

### Added

- **Language adapter protocol** (`LanguageAdapter.res`) — Pluggable interface for adding language support. Each adapter implements `detect`, `readConfig`, `build`, `watch`, `parseDiagnostics`, and `resolveImport`. Adapters compose: exclude packages and artifact patterns merge across all active adapters.
- **ReScript adapter** (`RescriptAdapter.res`) — Wraps existing `RescriptCompiler` and `RescriptConfig` modules into the adapter protocol. PascalCase resolution included.
- **AffineScript adapter** (`AffineScriptAdapter.res`) — Bridges the AffineScript OCaml compiler into Vite. Handles `.as` files, parses OCaml-style and structured error formats, supports dune-based watch mode.
- **Multi-language HMR** — `handleHotUpdate` routes files to the correct adapter by extension. Each adapter has independent diagnostics and build state.
- **Multi-language resolveId** — Tries ReScript PascalCase resolution first, then falls through to adapter-specific `resolveImport`.
- **Multi-adapter build orchestration** — `buildStart` launches all adapter compilers in parallel (serve mode) or sequentially with Promise.all (build mode).
- **`makeWithAdapters` export** — Convenience entry point for multi-language projects.
- **`adapters` option** — Pass additional `LanguageAdapter.t` instances to the plugin constructor.
- **Per-adapter state** — Each active adapter maintains its own `config`, `watchHandle`, `diagnostics`, and `lastBuildSuccess`.
- **Merged Vite configuration** — `allExcludePackages` and `allArtifactPatterns` helpers deduplicate across all active adapters.
- **CLAUDE.md** — Project-specific AI instructions for Claude Code.
- **Language adapter tests** (`language_adapter_test.js`) — 16 tests covering adapter protocol, detection, composition, and AffineScript diagnostic parsing.

### Changed

- Plugin renamed conceptually from "Vite plugin for ReScript" to "Language evangeliser Vite plugin" — backward compatible, zero-config ReScript still works identically.
- Internal state restructured: `pluginState` now has `activeAdapters: array<adapterState>` alongside legacy ReScript fields.
- `config` hook now merges exclude packages and artifact patterns from all active adapters.
- `configResolved` re-detects adapters with the actual project root.
- `buildEnd` reports diagnostics summary per adapter.
- `closeBundle` stops all adapter watch processes.
- Version bumped to 1.0.0.
- Package exports expanded: `./adapter`, `./adapter/rescript`, `./adapter/affinescript`.
- Keywords updated: `affinescript`, `language-adapter`, `multi-language`, `panll`.

### Fixed

- All template placeholders resolved in Justfile (was `{{PROJECT_NAME}}`, `{{AUTHOR}}`, etc.).
- All template placeholders resolved in `.devcontainer/devcontainer.json`.
- ROADMAP.adoc rewritten from template boilerplate to actual project milestones.
- Justfile build/test/lint/fmt/deps recipes now use actual Deno commands instead of TODO comments.
- Removed `PLACEHOLDERS.md` (template cruft from RSR scaffold).

## [0.2.0] - 2026-03-14

### Added

- **RescriptConfig module** — Auto-reads `rescript.json` or `bsconfig.json` to detect suffix (`.res.js` / `.res.mjs`), module format (`esmodule` / `commonjs`), in-source mode, source directories, and dependencies. Zero manual configuration needed.
- **PascalCase module resolution** (`resolveId` hook) — Fixes the #1 Linux pain point where ReScript emits lowercase imports but files are PascalCase on disk. Tries `.res.js` and `.res.mjs` suffixes automatically.
- **Auto `optimizeDeps` exclusion** (`config` hook) — Excludes `@rescript/core`, `@rescript/runtime`, `@rescript/react`, and `rescript` from Vite's dependency pre-bundling, which breaks on their subpath exports.
- **Build artifact watcher ignore** (`config` hook) — Ignores `.ast`, `.cmj`, `.cmi`, `.cmt`, and `lib/bs/`, `lib/es6/`, `lib/js/`, `lib/ocaml/` directories to prevent spurious reload loops.
- **Rewatch support** — Auto-detects the `rewatch` binary (ReScript 12+) and uses `rewatch watch`/`rewatch build` when available. Falls back to `rescript build -w`.
- **ANSI color forwarding** — Sets `NINJA_ANSI_FORCED=1` in compiler process environment and via `configureServer` hook for colored ReScript compiler output in the terminal.
- **In-source: false path remapping** — Correctly maps `.res` files to their compiled output in `lib/es6/` or `lib/js/` for out-of-source compilation mode.
- **Configurable suffix** — Auto-detected from `rescript.json` or overridden via `suffix` option.
- **Toggleable features** — `autoOptimizeDeps`, `autoResolve`, `autoIgnoreArtifacts` options (all default `true`).
- **`buildCommand` export** — Extracted and exported from RescriptCompiler for testability.
- **New test suite**: `rescript_config_test.js` (10 tests for auto-detection).
- **Expanded tests**: 8 new `buildCommand` tests, 8 new plugin hook tests. Total: 68 tests across 5 suites.

### Changed

- Plugin now uses `config`, `configureServer`, and `resolveId` Vite hooks in addition to existing `configResolved`, `buildStart`, `handleHotUpdate`, `buildEnd`, `closeBundle`.
- `ViteTypes.res` expanded with `fileWatcher`, `resolveIdResult`, and new hook type signatures.
- `RescriptCompiler.config` type now includes `useRewatch: bool` field.
- Version bumped to 0.2.0.

### Fixed

- Removed `lib/ocaml/` build artifacts from git tracking (21 files).
- Updated `.gitignore` to ignore ReScript 12+ build artifacts (`lib/ocaml/`, `*.ast`, `*.cmi`, `*.cmt`, `*.cmj`, `lib/rescript.lock`, Vite timestamp artifacts).
- Updated `.gitattributes` to cover `.js`, `.mjs`, `.idr`, `.zig` file types.
- Removed unused `userConfigPartial` type from `ViteTypes.res`.

## [0.1.0] - 2026-03-09

### Added

- Initial release with core Vite plugin functionality.
- Automatic ReScript compiler spawning (build + watch modes).
- HMR for `.res` files via `.res.js` output tracking.
- Error overlay integration — pushes compiler diagnostics to Vite's overlay.
- Diagnostic parsing — parses ReScript compiler output including ANSI escape codes.
- Deno-compatible — auto-detects runtime and adjusts compiler invocation.
- BoJ ssg-mcp build orchestration — optional delegation to BoJ server.
- panic-attack SARIF compatibility — diagnostic format maps to weak-point scanning.
- Written entirely in ReScript (dogfooding).
