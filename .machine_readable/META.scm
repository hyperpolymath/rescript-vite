;; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - Meta-level information for rescript-vite
;; Media-Type: application/meta+scheme

(meta
  (metadata
    (version "0.2.0")
    (last-updated "2026-03-14"))

  (project-info
    (type "library")
    (languages ("rescript" "javascript"))
    (license "PMPL-1.0-or-later")
    (author "Jonathan D.A. Jewell (hyperpolymath)"))

  (architecture-decisions
    (adr
      (id "ADR-001")
      (title "Write plugin in ReScript (not JS/TS)")
      (status "accepted")
      (date "2026-03-09")
      (decision "Dogfood our own language. Compiles to clean JS that Vite consumes."))
    (adr
      (id "ADR-002")
      (title "Auto-detect rescript.json settings")
      (status "accepted")
      (date "2026-03-14")
      (decision "Zero-config by default. Read suffix, module format, in-source from rescript.json."))
    (adr
      (id "ADR-003")
      (title "PascalCase resolver built into plugin")
      (status "accepted")
      (date "2026-03-14")
      (decision "Linux case-sensitivity is the #1 pain point. Bake it in."))
    (adr
      (id "ADR-004")
      (title "All features on by default, toggleable off")
      (status "accepted")
      (date "2026-03-14")
      (decision "Solve problems without asking. Users can disable individually."))
    (adr
      (id "ADR-005")
      (title "Optional BoJ integration via probe")
      (status "accepted")
      (date "2026-03-09")
      (decision "BoJ ssg-mcp cartridge provides build caching. Probe on startup, fall back if unavailable.")))

  (development-practices
    (build-tool "deno")
    (container-runtime "podman")
    (ci-platform "github-actions")
    (package-manager "deno")
    (versioning "SemVer")
    (documentation "AsciiDoc"))

  (design-rationale
    (summary "This plugin exists because the ReScript+Vite story was functional but fragile — HMR required .resi files, PascalCase resolution was per-project, optimizeDeps exclusion was manual. rescript-vite solves all of these with zero configuration.")))
