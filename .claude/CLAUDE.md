# rescript-vite — Project Instructions

## What This Is

A language evangeliser Vite plugin. ReScript is the primary language; AffineScript is secondary. The plugin uses a pluggable language adapter protocol that will eventually support any language and integrate into PanLL's workspace layer.

## Architecture

```
VitePluginRescript.res  — Main plugin (Vite hooks, adapter orchestration)
LanguageAdapter.res     — Adapter protocol (interface all languages implement)
RescriptAdapter.res     — ReScript adapter (wraps RescriptCompiler + RescriptConfig)
AffineScriptAdapter.res — AffineScript adapter (OCaml compiler bridge)
RescriptCompiler.res    — ReScript child process bridge
RescriptConfig.res      — rescript.json/bsconfig.json parser
BojBridge.res           — Optional BoJ build orchestration (JSON-RPC)
ViteTypes.res           — Vite API type bindings (minimal)
```

## Build & Test

```bash
just build          # Compile .res -> .res.js via deno
just test           # Run all tests (deno test)
just test-smoke     # Verify plugin module loads
just clean          # Clean ReScript build artifacts
```

## Language Rules

- **ALL source code is ReScript** — no TypeScript, no raw JavaScript files in src/
- `%raw()` is acceptable for Vite API interop and child process FFI
- Tests are JavaScript (Deno test runner) because they test compiled output
- `Obj.magic` is acceptable ONLY for Vite's deeply dynamic config objects

## Key Patterns

- **Zero-config default**: `plugins: [rescriptPlugin()]` must work with no options
- **Backward compatible**: Adding adapters must not change existing ReScript-only behaviour
- **Graceful fallback**: BoJ integration probes and falls back to direct compiler
- **Per-adapter state**: Each adapter has its own diagnostics, config, watch handle
- **Merged Vite config**: excludePackages and artifactIgnorePatterns merge across adapters

## File Extension Mapping

| Extension | Handler | Output |
|-----------|---------|--------|
| `.res`, `.resi` | ReScript (built-in) | `.res.js` / `.res.mjs` |
| `.as` | AffineScript adapter | `.as.js` / `.as.wasm` |

## Testing

68+ tests across test files in `tests/`. Run with `deno test --no-check --allow-all tests/`.

Test files:
- `vite_plugin_test.js` — Plugin hooks and config
- `rescript_compiler_test.js` — Diagnostic parsing, command generation
- `rescript_config_test.js` — Config auto-detection
- `boj_bridge_test.js` — BoJ JSON-RPC bridge
- `panic_attack_test.js` — SARIF compatibility
- `language_adapter_test.js` — Adapter protocol and AffineScript adapter

## Adapter Protocol

To add a new language, create a file implementing `LanguageAdapter.t`:
- `id` — unique string (e.g., "gleam")
- `extensions` — file extensions (e.g., [".gleam"])
- `detect(root)` — return config path if language is present
- `readConfig(root)` — parse language config
- `build(root, config)` — one-shot compile
- `watch(root, config)` — start watch mode, return stop handle
- `parseDiagnostics(output)` — parse compiler output
- `resolveImport(source, importer, config)` — fix imports if needed

## Future Direction

This plugin will integrate into PanLL as the language development panel. The adapter protocol will become the standard way PanLL discovers and manages language toolchains. AffineScript will eventually split into its own `affinescript-vite` package, leaving this as the ReScript-focused plugin with a shared adapter protocol.

## Do Not

- Add TypeScript files
- Use npm/bun (Deno only)
- Break zero-config ReScript usage
- Add Obj.magic outside of Vite API interop
- Use believe_me, assert_total, or other unsafe patterns
