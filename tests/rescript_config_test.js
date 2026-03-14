// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Tests for RescriptConfig — rescript.json auto-detection and parsing.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  read,
  defaultRescriptConfig,
  getOutputPath,
} from "../src/RescriptConfig.res.js";

Deno.test("RescriptConfig", async (t) => {
  // --- defaultRescriptConfig ---

  await t.step("defaultRescriptConfig has sensible defaults", () => {
    assertEquals(defaultRescriptConfig.suffix, ".res.js");
    assertEquals(defaultRescriptConfig.packageSpec.moduleFormat, "esmodule");
    assertEquals(defaultRescriptConfig.packageSpec.inSource, true);
    assertEquals(defaultRescriptConfig.sources.length, 1);
    assertEquals(defaultRescriptConfig.sources[0], "src");
    assertEquals(defaultRescriptConfig.configPath, "");
  });

  // --- read ---

  await t.step("read returns defaults for non-existent directory", () => {
    const config = read("/nonexistent/path/that/does/not/exist");
    assertEquals(config.suffix, ".res.js");
    assertEquals(config.packageSpec.moduleFormat, "esmodule");
    assertEquals(config.packageSpec.inSource, true);
    assertEquals(config.configPath, "");
  });

  await t.step("read finds rescript.json in the plugin's own directory", () => {
    // The rescript-vite project itself has a rescript.json
    const config = read(".");
    assertEquals(config.name, "rescript-vite");
    assertEquals(config.suffix, ".res.js");
    assertEquals(config.configPath.endsWith("rescript.json"), true);
  });

  await t.step("read parses dependencies", () => {
    const config = read(".");
    assertEquals(config.dependencies.includes("@rescript/core"), true);
  });

  await t.step("read parses sources", () => {
    const config = read(".");
    assertEquals(config.sources.includes("src"), true);
  });

  // --- getOutputPath ---

  await t.step("getOutputPath in-source mode appends suffix", () => {
    const config = {
      ...defaultRescriptConfig,
      suffix: ".res.js",
      packageSpec: { moduleFormat: "esmodule", inSource: true },
    };
    const result = getOutputPath(config, "src/App.res");
    assertEquals(result, "src/App.res.js");
  });

  await t.step("getOutputPath in-source mode with .res.mjs suffix", () => {
    const config = {
      ...defaultRescriptConfig,
      suffix: ".res.mjs",
      packageSpec: { moduleFormat: "esmodule", inSource: true },
    };
    const result = getOutputPath(config, "src/App.res");
    assertEquals(result, "src/App.res.mjs");
  });

  await t.step("getOutputPath out-of-source esmodule", () => {
    const config = {
      ...defaultRescriptConfig,
      suffix: ".res.js",
      packageSpec: { moduleFormat: "esmodule", inSource: false },
    };
    const result = getOutputPath(config, "src/App.res");
    assertEquals(result, "lib/es6/src/App.res.js");
  });

  await t.step("getOutputPath out-of-source commonjs", () => {
    const config = {
      ...defaultRescriptConfig,
      suffix: ".res.js",
      packageSpec: { moduleFormat: "commonjs", inSource: false },
    };
    const result = getOutputPath(config, "src/App.res");
    assertEquals(result, "lib/js/src/App.res.js");
  });

  await t.step("getOutputPath handles nested paths", () => {
    const config = {
      ...defaultRescriptConfig,
      suffix: ".res.js",
      packageSpec: { moduleFormat: "esmodule", inSource: true },
    };
    const result = getOutputPath(config, "src/app/utils/Helper.res");
    assertEquals(result, "src/app/utils/Helper.res.js");
  });
});
