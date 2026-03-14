;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Ecosystem position for rescript-vite
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
  (version "1.0")
  (name "rescript-vite")
  (type "library")
  (purpose "Definitive Vite plugin for ReScript — zero-config, all pain points solved")

  (position-in-ecosystem
    (category "build-tooling")
    (subcategory "vite-plugins")
    (unique-value
      ("Zero-config PascalCase resolution for Linux")
      ("Auto rescript.json detection")
      ("HMR without .resi files")
      ("Build artifact watcher loop prevention")
      ("Optional BoJ ssg-mcp integration")))

  (related-projects
    (project "idaptik" (relationship "consumer") (description "Primary dogfood project — 542 .res files"))
    (project "dotmatrix-fileprinter" (relationship "consumer") (description "Tauri 2 + ReScript + Vite"))
    (project "boj-server" (relationship "integration") (description "ssg-mcp cartridge for build orchestration"))
    (project "panll" (relationship "potential-consumer") (description "Custom TEA framework, may use Vite"))
    (project "rsr-template-repo" (relationship "sibling-standard") (description "Template should recommend rescript-vite")))

  (what-this-is
    ("A Vite plugin that makes ReScript a first-class citizen in the Vite ecosystem"))

  (what-this-is-not
    ("A standalone build tool — it extends Vite, not replaces it")))
