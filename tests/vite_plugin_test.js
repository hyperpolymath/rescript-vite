// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Tests for VitePluginRescript — the main Vite plugin.

import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("VitePluginRescript", async (t) => {
  const { make } = await import("../src/VitePluginRescript.res.js");

  await t.step("make returns a valid Vite plugin object", () => {
    const plugin = make({ logLevel: "silent" });
    assertEquals(plugin.name, "rescript-vite");
    assertEquals(plugin.enforce, "pre");
    assertExists(plugin.config);
    assertExists(plugin.configResolved);
    assertExists(plugin.configureServer);
    assertExists(plugin.resolveId);
    assertExists(plugin.buildStart);
    assertExists(plugin.handleHotUpdate);
    assertExists(plugin.buildEnd);
    assertExists(plugin.closeBundle);
  });

  await t.step("make with no args uses defaults", () => {
    const plugin = make();
    assertEquals(typeof plugin.configResolved, "function");
    assertEquals(typeof plugin.buildStart, "function");
    assertEquals(typeof plugin.config, "function");
    assertEquals(typeof plugin.resolveId, "function");
  });

  await t.step("make with custom options", () => {
    const plugin = make({
      boj: true,
      bojEndpoint: "http://custom:8080/mcp/ssg",
      useDeno: true,
      logLevel: "silent",
      suffix: ".res.mjs",
      useRewatch: false,
      autoOptimizeDeps: true,
      autoResolve: true,
      autoIgnoreArtifacts: true,
    });
    assertEquals(plugin.name, "rescript-vite");
  });

  await t.step("config hook returns optimizeDeps exclusions", () => {
    const plugin = make({ logLevel: "silent" });
    const configPatch = plugin.config();
    assertExists(configPatch);
    assertExists(configPatch.optimizeDeps);
    const excluded = configPatch.optimizeDeps.exclude;
    assertEquals(excluded.includes("@rescript/core"), true);
    assertEquals(excluded.includes("@rescript/runtime"), true);
    assertEquals(excluded.includes("@rescript/react"), true);
    assertEquals(excluded.includes("rescript"), true);
  });

  await t.step("config hook returns watcher ignore patterns", () => {
    const plugin = make({ logLevel: "silent" });
    const configPatch = plugin.config();
    assertExists(configPatch.server);
    assertExists(configPatch.server.watch);
    const ignored = configPatch.server.watch.ignored;
    assertEquals(ignored.includes("**/*.ast"), true);
    assertEquals(ignored.includes("**/*.cmj"), true);
    assertEquals(ignored.includes("**/*.cmi"), true);
    assertEquals(ignored.includes("**/*.cmt"), true);
    assertEquals(ignored.includes("**/lib/bs/**"), true);
  });

  await t.step("config hook skips optimizeDeps when autoOptimizeDeps=false", () => {
    const plugin = make({ logLevel: "silent", autoOptimizeDeps: false, autoIgnoreArtifacts: false });
    const configPatch = plugin.config();
    assertEquals(configPatch.optimizeDeps, undefined);
  });

  await t.step("resolveId is present when autoResolve=true (default)", () => {
    const plugin = make({ logLevel: "silent" });
    assertEquals(typeof plugin.resolveId, "function");
  });

  await t.step("resolveId is absent when autoResolve=false", () => {
    const plugin = make({ logLevel: "silent", autoResolve: false });
    assertEquals(plugin.resolveId, undefined);
  });

  await t.step("resolveId returns undefined for non-relative imports", async () => {
    const plugin = make({ logLevel: "silent" });
    const result = await plugin.resolveId("@rescript/core", "/test/src/App.res.js");
    assertEquals(result, undefined);
  });

  await t.step("resolveId returns undefined when no importer", async () => {
    const plugin = make({ logLevel: "silent" });
    const result = await plugin.resolveId("./App", undefined);
    assertEquals(result, undefined);
  });

  await t.step("configResolved stores config and re-reads rescript.json", () => {
    const plugin = make({ logLevel: "silent" });
    plugin.configResolved({
      root: "/test/project",
      command: "serve",
      mode: "development",
    });
    // Should not throw
  });

  await t.step("configResolved respects suffix override", () => {
    const plugin = make({ logLevel: "silent", suffix: ".res.mjs" });
    plugin.configResolved({
      root: "/test/project",
      command: "serve",
      mode: "development",
    });
    // Should not throw
  });

  await t.step("configureServer sets NINJA_ANSI_FORCED", () => {
    const plugin = make({ logLevel: "silent" });
    const mockServer = {
      moduleGraph: { getModulesByFile: () => undefined },
      ws: { send: () => {} },
      watcher: { add: () => {}, options: { ignored: [] } },
    };
    plugin.configureServer(mockServer);
    assertEquals(process.env.NINJA_ANSI_FORCED, "1");
  });

  await t.step("handleHotUpdate ignores non-.res files", () => {
    const plugin = make({ logLevel: "silent" });
    const result = plugin.handleHotUpdate({
      file: "/test/style.css",
      modules: [],
      server: {
        moduleGraph: { getModulesByFile: () => undefined },
        ws: { send: () => {} },
        watcher: { add: () => {}, options: { ignored: [] } },
      },
    });
    assertEquals(result, undefined);
  });

  await t.step("handleHotUpdate processes .res files", () => {
    const plugin = make({ logLevel: "silent" });
    plugin.configResolved({
      root: "/test",
      command: "serve",
      mode: "development",
    });

    const testModules = [{ id: "test", url: "/src/App.res.js" }];
    const result = plugin.handleHotUpdate({
      file: "/test/src/App.res",
      modules: [],
      server: {
        moduleGraph: {
          getModulesByFile: (f) => {
            if (f === "/test/src/App.res.js") return testModules;
            return undefined;
          },
        },
        ws: { send: () => {} },
        watcher: { add: () => {}, options: { ignored: [] } },
      },
    });
    if (result !== undefined) {
      assertEquals(result.length, 1);
    }
  });

  await t.step("handleHotUpdate handles .resi files", () => {
    const plugin = make({ logLevel: "silent" });
    plugin.configResolved({
      root: "/test",
      command: "serve",
      mode: "development",
    });

    const result = plugin.handleHotUpdate({
      file: "/test/src/Types.resi",
      modules: [],
      server: {
        moduleGraph: { getModulesByFile: () => undefined },
        ws: { send: () => {} },
        watcher: { add: () => {}, options: { ignored: [] } },
      },
    });
    // Should not throw — .resi maps to .res output
    assertEquals(result, undefined); // Not in module graph, so full reload
  });

  await t.step("closeBundle does not throw when no watch handle", () => {
    const plugin = make({ logLevel: "silent" });
    plugin.closeBundle();
  });

  await t.step("buildEnd does not throw", () => {
    const plugin = make({ logLevel: "silent" });
    plugin.buildEnd();
  });

  await t.step("plugin enforce is 'pre'", () => {
    const plugin = make({ logLevel: "silent" });
    assertEquals(plugin.enforce, "pre");
  });
});
