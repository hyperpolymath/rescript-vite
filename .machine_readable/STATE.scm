;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for rescript-vite
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.2.0")
    (schema-version "1.0")
    (created "2026-03-09")
    (updated "2026-03-14")
    (project "rescript-vite")
    (repo "github.com/hyperpolymath/rescript-vite"))

  (project-context
    (name "rescript-vite")
    (purpose "Vite plugin for first-class ReScript support — solves all known pain points")
    (completion-percentage 90))

  (current-position
    (phase "implementation")
    (maturity "alpha"))

  (route-to-mvp
    (milestone "Initial setup (RSR template)" (completion 100))
    (milestone "Core compiler bridge" (completion 100))
    (milestone "Diagnostic parsing + error overlay" (completion 100))
    (milestone "HMR for .res files" (completion 100))
    (milestone "BoJ ssg-mcp integration" (completion 100))
    (milestone "rescript.json auto-detection" (completion 100))
    (milestone "PascalCase module resolution" (completion 100))
    (milestone "Auto optimizeDeps exclusion" (completion 100))
    (milestone "Build artifact watcher ignore" (completion 100))
    (milestone "Rewatch support" (completion 100))
    (milestone "ANSI color forwarding" (completion 100))
    (milestone "In-source: false path remapping" (completion 100))
    (milestone "Test suite (68 tests)" (completion 100))
    (milestone "npm publish" (completion 0))
    (milestone "Real-world integration testing" (completion 50)))

  (stats
    (source-files 5)
    (test-files 5)
    (test-count 68))

  (blockers-and-issues)

  (critical-next-actions
    (action "Test with idaptik live repo")
    (action "Test with lithoglyph/glyphbase/ui")
    (action "Publish to npm/Deno JSR")
    (action "Add to rsr-template-repo as recommended Vite plugin")))
