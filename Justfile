# SPDX-License-Identifier: PMPL-1.0-or-later
# Justfile for rescript-vite project
# https://just.systems

set shell := ["bash", "-c"]
set export := true

# Default recipe
@default:
  just --list

# Initialize project (Guix/Nix optional)
@init:
  echo "Installing dependencies..."
  npm install
  echo "✓ Project initialized"

# Start development server
@dev:
  echo "Starting development server..."
  npm run dev

# Build for production
@build:
  echo "Building for production..."
  npm run build

# Run all tests
@test:
  echo "Running tests..."
  npm test

# Run tests with UI
@test-ui:
  echo "Running tests with UI..."
  npm run test:ui

# Format code
@fmt:
  echo "Formatting code..."
  npm run fmt
  echo "✓ Code formatted"

# Type check and lint
@check:
  echo "Type checking and linting..."
  npm run check
  echo "✓ Type check passed"

# Compile ReScript only
@rescript:
  echo "Compiling ReScript..."
  npm run rescript:build
  echo "✓ ReScript compiled"

# Watch ReScript compilation
@rescript-watch:
  echo "Watching ReScript files..."
  npm run rescript:watch

# Run pre-commit checks
@pre-commit:
  echo "Running pre-commit checks..."
  just fmt
  just check
  just test
  echo "✓ Pre-commit checks passed"

# Clean build artifacts
@clean:
  echo "Cleaning build artifacts..."
  rm -rf dist/ .rescript node_modules/
  echo "✓ Cleaned"

# Install dependencies
@install:
  echo "Installing dependencies..."
  npm install

# Audit dependencies
@audit:
  echo "Auditing dependencies..."
  npm audit
  npm audit fix

# View build size
@size:
  echo "Build size analysis..."
  npm run build
  du -h dist/

# Create a new ReScript component
new-component component:
  #!/bin/bash
  FILE="src/rescript/{{ component }}.res"
  if [ -f "$FILE" ]; then
    echo "File already exists: $FILE"
    exit 1
  fi
  cat > "$FILE" << 'EOF'
// SPDX-License-Identifier: PMPL-1.0-or-later
// {{ component }} component

@react.component
let make = () => {
  <div>
    {React.string("{{ component }}")}
  </div>
}
EOF
  echo "Created: $FILE"

# Bump version
bump-version version:
  #!/bin/bash
  if ! [[ {{ version }} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Use semver (e.g., 1.0.0)"
    exit 1
  fi
  npm version {{ version }} --no-git-tag-v
  echo "✓ Version bumped to {{ version }}"

# Scaffolding new projects
scaffold template='spa' name='my-app':
  #!/bin/bash
  echo "Scaffolding rescript-vite project..."
  ./scripts/scaffold.sh --template {{template}} --name {{name}}

scaffold-spa name='my-app':
  @just scaffold spa {{name}}

scaffold-ssg name='my-blog':
  @just scaffold ssg {{name}}

scaffold-lib name='my-components':
  @just scaffold lib {{name}}

scaffold-realtime name='my-chat':
  @just scaffold realtime {{name}}

# Help
@help:
  echo "rescript-vite Justfile"
  echo ""
  echo "Common recipes:"
  echo "  just dev         - Start development server"
  echo "  just build       - Build for production"
  echo "  just test        - Run tests"
  echo "  just fmt         - Format code"
  echo "  just check       - Type check and lint"
  echo "  just pre-commit  - Run all checks before commit"
  echo ""
  echo "Setup:"
  echo "  just init        - Initialize project"
  echo "  just install     - Install dependencies"
  echo ""
  echo "Development:"
  echo "  just rescript    - Compile ReScript"
  echo "  just rescript-watch - Watch ReScript files"
  echo "  just size        - Analyze build size"
  echo ""
  echo "Scaffolding new projects:"
  echo "  just scaffold-spa name=my-app          - Create SPA (single-page app)"
  echo "  just scaffold-ssg name=my-blog         - Create SSG (static site)"
  echo "  just scaffold-lib name=my-components   - Create component library"
  echo "  just scaffold-realtime name=my-chat    - Create real-time app"
  echo ""
  echo "Maintenance:"
  echo "  just clean       - Remove build artifacts"
  echo "  just audit       - Audit dependencies"
