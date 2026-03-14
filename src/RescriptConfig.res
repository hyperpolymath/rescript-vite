// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// RescriptConfig.res — Auto-detect project settings from rescript.json.
//
// Reads the rescript.json (or bsconfig.json fallback) to determine:
//   - Output suffix (.res.js vs .res.mjs)
//   - Module format (esmodule vs commonjs)
//   - In-source compilation (true/false)
//   - Source directories
//   - Package name and dependencies

/// Parsed rescript.json configuration (subset we need)
type packageSpec = {
  /// Module format: "esmodule" | "commonjs" (or legacy "es6" | "es6-global")
  moduleFormat: string,
  /// Whether compiled output lives alongside source files
  inSource: bool,
}

type rescriptConfig = {
  /// Package name from rescript.json
  name: string,
  /// Output suffix (e.g., ".res.js", ".res.mjs", ".bs.js")
  suffix: string,
  /// Package spec (module format + in-source)
  packageSpec: packageSpec,
  /// Source directories
  sources: array<string>,
  /// Dependencies listed in rescript.json
  dependencies: array<string>,
  /// Path to the rescript.json file that was read
  configPath: string,
}

/// Default configuration when no rescript.json is found
let defaultRescriptConfig: rescriptConfig = {
  name: "unknown",
  suffix: ".res.js",
  packageSpec: {
    moduleFormat: "esmodule",
    inSource: true,
  },
  sources: ["src"],
  dependencies: ["@rescript/core"],
  configPath: "",
}

// --- Filesystem FFI ---

@module("node:fs") external readFileSync: (string, string) => string = "readFileSync"
@module("node:fs") external existsSync: string => bool = "existsSync"
@module("node:path") external joinPath: (string, string) => string = "join"

/// Parse a sources entry — rescript.json supports both string and object forms
let parseSources: JSON.t => array<string> = %raw(`
  function(sources) {
    if (!sources) return ["src"];
    if (typeof sources === "string") return [sources];
    if (Array.isArray(sources)) {
      return sources.map(function(s) {
        if (typeof s === "string") return s;
        if (s && s.dir) return s.dir;
        return "src";
      });
    }
    if (sources.dir) return [sources.dir];
    return ["src"];
  }
`)

/// Parse package-specs entry — supports string, object, or array forms
let parsePackageSpec: JSON.t => packageSpec = %raw(`
  function(specs) {
    var defaultSpec = { moduleFormat: "esmodule", inSource: true };
    if (!specs) return defaultSpec;
    // Single string: "esmodule" or "commonjs"
    if (typeof specs === "string") return { moduleFormat: specs, inSource: true };
    // Array of specs — take the first
    var spec = Array.isArray(specs) ? specs[0] : specs;
    if (!spec) return defaultSpec;
    if (typeof spec === "string") return { moduleFormat: spec, inSource: true };
    var fmt = spec.module || spec["module"] || "esmodule";
    // Normalise legacy format names
    if (fmt === "es6" || fmt === "es6-global") fmt = "esmodule";
    var inSrc = spec["in-source"];
    return {
      moduleFormat: fmt,
      inSource: inSrc !== undefined ? !!inSrc : true
    };
  }
`)

/// Parse dependencies array
let parseDeps: JSON.t => array<string> = %raw(`
  function(deps) {
    if (!deps) return [];
    if (Array.isArray(deps)) return deps.filter(function(d) { return typeof d === "string"; });
    return [];
  }
`)

/// Read and parse rescript.json or bsconfig.json from a project root.
/// Returns the parsed config, or the default if neither file exists.
let read = (projectRoot: string): rescriptConfig => {
  let rescriptJsonPath = joinPath(projectRoot, "rescript.json")
  let bsconfigPath = joinPath(projectRoot, "bsconfig.json")

  let configPath = if existsSync(rescriptJsonPath) {
    Some(rescriptJsonPath)
  } else if existsSync(bsconfigPath) {
    Some(bsconfigPath)
  } else {
    None
  }

  switch configPath {
  | None => defaultRescriptConfig
  | Some(path) => {
      try {
        let content = readFileSync(path, "utf-8")
        let json = JSON.parseExn(content)

        switch JSON.Classify.classify(json) {
        | Object(obj) => {
            let name = switch Dict.get(obj, "name") {
            | Some(v) =>
              switch JSON.Classify.classify(v) {
              | String(s) => s
              | _ => "unknown"
              }
            | None => "unknown"
            }

            let suffix = switch Dict.get(obj, "suffix") {
            | Some(v) =>
              switch JSON.Classify.classify(v) {
              | String(s) => s
              | _ => ".res.js"
              }
            | None => ".res.js"
            }

            let packageSpec = switch Dict.get(obj, "package-specs") {
            | Some(v) => parsePackageSpec(v)
            | None => defaultRescriptConfig.packageSpec
            }

            let sources = switch Dict.get(obj, "sources") {
            | Some(v) => parseSources(v)
            | None => ["src"]
            }

            // rescript.json uses "dependencies", bsconfig.json uses "bs-dependencies"
            let dependencies = switch Dict.get(obj, "dependencies") {
            | Some(v) => parseDeps(v)
            | None =>
              switch Dict.get(obj, "bs-dependencies") {
              | Some(v) => parseDeps(v)
              | None => []
              }
            }

            {
              name,
              suffix,
              packageSpec,
              sources,
              dependencies,
              configPath: path,
            }
          }
        | _ => {...defaultRescriptConfig, configPath: path}
        }
      } catch {
      | _ => defaultRescriptConfig
      }
    }
  }
}

/// Get the compiled output file path for a given .res source file.
/// Handles both in-source (file.res.js alongside file.res) and
/// out-of-source (lib/es6/src/file.res.js) compilation modes.
let getOutputPath = (config: rescriptConfig, resFile: string): string => {
  if config.packageSpec.inSource {
    // In-source: output sits next to the .res file
    // src/App.res -> src/App.res.js
    resFile ++ config.suffix->String.replace(".res", "")
  } else {
    // Out-of-source: output goes to lib/<format>/
    let subdir = switch config.packageSpec.moduleFormat {
    | "esmodule" => "es6"
    | "commonjs" => "js"
    | other => other
    }
    // src/App.res -> lib/es6/src/App.res.js
    "lib/" ++ subdir ++ "/" ++ resFile ++ config.suffix->String.replace(".res", "")
  }
}
