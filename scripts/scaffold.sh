#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# rescript-vite project scaffolder
# Usage: ./scripts/scaffold.sh --template spa --name my-app

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
TEMPLATE="spa"
PROJECT_NAME=""
AUTHOR="$(git config user.name || echo 'Developer')"
EMAIL="$(git config user.email || echo 'dev@example.com')"

# Help text
show_help() {
  cat << EOF
${BLUE}rescript-vite Project Scaffolder${NC}

Usage: ./scripts/scaffold.sh [OPTIONS]

Options:
  --template <type>   Project template (default: spa)
                     Available: spa, ssg, lib, realtime
  --name <name>       Project directory name (required)
  --author <name>     Author name (default: git config)
  --email <email>     Author email (default: git config)
  -h, --help          Show this help message

Examples:
  ./scripts/scaffold.sh --template spa --name my-app
  ./scripts/scaffold.sh --template lib --name my-components

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --template)
      TEMPLATE="$2"
      shift 2
      ;;
    --name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --author)
      AUTHOR="$2"
      shift 2
      ;;
    --email)
      EMAIL="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

# Validate inputs
if [[ -z "$PROJECT_NAME" ]]; then
  echo -e "${RED}Error: --name is required${NC}"
  show_help
  exit 1
fi

if [[ -d "$PROJECT_NAME" ]]; then
  echo -e "${RED}Error: Directory '$PROJECT_NAME' already exists${NC}"
  exit 1
fi

# Validate template
case "$TEMPLATE" in
  spa|ssg|lib|realtime) ;;
  *)
    echo -e "${RED}Error: Unknown template '$TEMPLATE'${NC}"
    echo "Available templates: spa, ssg, lib, realtime"
    exit 1
    ;;
esac

echo -e "${GREEN}Scaffolding rescript-vite project...${NC}"
echo -e "  Template: ${BLUE}$TEMPLATE${NC}"
echo -e "  Name: ${BLUE}$PROJECT_NAME${NC}"
echo -e "  Author: ${BLUE}$AUTHOR <$EMAIL>${NC}"
echo ""

# Create directory
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Initialize git
git init
git config user.name "$AUTHOR"
git config user.email "$EMAIL"

# Create directory structure
mkdir -p src/rescript src/js src/assets/images src/assets/fonts
mkdir -p tests/unit tests/integration docs examples
mkdir -p .github/workflows .devcontainer .well-known

# Copy common files from rescript-vite template
echo -e "${BLUE}Creating common files...${NC}"

# Create .gitignore
cat > .gitignore << 'EOF'
# ReScript
.rescript
/dist
/lib/es6
/lib/es6_global

# Vite
/node_modules
/.vite

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode
.idea
*.swp

# OS
.DS_Store
Thumbs.db
EOF

# Create package.json
cat > package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "0.1.0",
  "description": "A ReScript + Vite project",
  "type": "module",
  "scripts": {
    "dev": "concurrently \"npm run rescript:watch\" \"vite\"",
    "build": "npm run rescript:build && vite build",
    "rescript:build": "rescript build",
    "rescript:watch": "rescript build -w",
    "preview": "vite preview",
    "test": "vitest",
    "test:ui": "vitest --ui",
    "fmt": "rescript format && prettier --write \"src/**/*.{js,jsx,ts,tsx}\"",
    "check": "rescript && eslint src/"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.0",
    "concurrently": "^8.2.0",
    "eslint": "^8.54.0",
    "prettier": "^3.1.0",
    "rescript": "^11.0.0",
    "vite": "^5.0.0",
    "vitest": "^1.0.0"
  },
  "authors": [
    "$AUTHOR <$EMAIL>"
  ],
  "license": "PMPL-1.0-or-later"
}
EOF

# Create rescript.json
cat > rescript.json << 'EOF'
{
  "version": "11.0.0",
  "sources": [
    {
      "dir": "src/rescript",
      "subdirs": true
    }
  ],
  "package-specs": {
    "module": "es6",
    "in-source": false
  },
  "suffix": ".res.js",
  "namespace": true,
  "refmt": 3
}
EOF

# Create vite.config.js
cat > vite.config.js << 'EOF'
// SPDX-License-Identifier: PMPL-1.0-or-later
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    strictPort: false,
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
EOF

# Create index.html
cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>ReScript + Vite App</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/js/main.jsx"></script>
  </body>
</html>
EOF

# Create src/rescript/App.res
cat > src/rescript/App.res << 'EOF'
// SPDX-License-Identifier: PMPL-1.0-or-later
@react.component
let make = () => {
  <div className="app">
    <h1> {"Welcome to ReScript + Vite" |> React.string} </h1>
    <p> {"Edit src/rescript/App.res and save to test HMR." |> React.string} </p>
  </div>
}
EOF

# Create src/js/main.jsx
cat > src/js/main.jsx << 'EOF'
// SPDX-License-Identifier: PMPL-1.0-or-later
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from '@rescript/App.res.js'
import './style.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
EOF

# Create src/js/style.css
cat > src/js/style.css << 'EOF'
/* SPDX-License-Identifier: PMPL-1.0-or-later */
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: #f5f5f5;
  color: #333;
  line-height: 1.6;
}

.app {
  max-width: 1200px;
  margin: 0 auto;
  padding: 40px 20px;
}

h1 {
  color: #0ea5e9;
  margin-bottom: 10px;
}

p {
  color: #666;
}
EOF

# Create .editorconfig
cat > .editorconfig << 'EOF'
root = true

[*]
charset = utf-8
end_of_line = lf
indent_size = 2
indent_style = space
insert_final_newline = true
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false
EOF

# Create .well-known/project.json
cat > .well-known/project.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "0.1.0",
  "template": "$TEMPLATE",
  "license": "PMPL-1.0-or-later",
  "author": "$AUTHOR",
  "email": "$EMAIL"
}
EOF

# Create template-specific files
echo -e "${BLUE}Setting up ${TEMPLATE} template...${NC}"

case "$TEMPLATE" in
  spa)
    # Single-page application
    mkdir -p src/rescript/pages src/rescript/components src/rescript/hooks

    cat > src/rescript/pages/Home.res << 'EOF'
// SPDX-License-Identifier: PMPL-1.0-or-later
@react.component
let make = () => {
  <div className="page">
    <h2> {"Home" |> React.string} </h2>
    <p> {"Welcome to your single-page application." |> React.string} </p>
  </div>
}
EOF
    ;;

  ssg)
    # Static site generator
    mkdir -p content/posts content/pages

    cat > content/posts/welcome.md << 'EOF'
---
title: Welcome to rescript-vite
date: 2026-04-25
slug: welcome
---

This is your first blog post. Edit this file in Markdown.

## Getting Started

1. Create posts in `content/posts/`
2. Build with `npm run build`
3. Deploy the `dist/` folder

EOF
    ;;

  lib)
    # Component library
    cat > src/rescript/index.res << 'EOF'
// SPDX-License-Identifier: PMPL-1.0-or-later
// Export all public components

@react.component
let button = (~label: string, ~onClick=?) => {
  <button ?onClick>
    {label |> React.string}
  </button>
}
EOF
    ;;

  realtime)
    # Real-time application
    mkdir -p src/rescript/websocket src/rescript/state

    cat > src/rescript/state/reducer.res << 'EOF'
// SPDX-License-Identifier: PMPL-1.0-or-later
type state = {
  messages: array<string>,
  connected: bool,
}

type action =
  | AddMessage(string)
  | SetConnected(bool)

let reducer = (state: state, action: action): state => {
  switch action {
  | AddMessage(msg) => {...state, messages: Array.concat(state.messages, [msg])}
  | SetConnected(connected) => {...state, connected}
  }
}
EOF
    ;;
esac

# Initialize git repo
echo -e "${BLUE}Initializing git repository...${NC}"
git add .
git commit -m "chore: scaffold rescript-vite $TEMPLATE project

Generated by rescript-vite scaffolder

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"

echo ""
echo -e "${GREEN}✓ Project created successfully!${NC}"
echo ""
echo "Next steps:"
echo -e "  1. ${BLUE}cd $PROJECT_NAME${NC}"
echo -e "  2. ${BLUE}npm install${NC}"
echo -e "  3. ${BLUE}npm run dev${NC}"
echo ""
echo "Happy coding! 🚀"
