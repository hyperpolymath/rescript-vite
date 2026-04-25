# rescript-vite Scripts

<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->

## scaffold.sh

Create a new rescript-vite project with a chosen template.

### Usage

```bash
./scripts/scaffold.sh --template <type> --name <project-name>
```

### Options

- `--template <type>` — Project template (required)
  - `spa` — Single-page application (default)
  - `ssg` — Static site generator
  - `lib` — Component library
  - `realtime` — Real-time application

- `--name <name>` — Project directory name (required)

- `--author <name>` — Author name (optional, defaults to git config)

- `--email <email>` — Author email (optional, defaults to git config)

- `-h, --help` — Show help message

### Examples

#### Create a single-page app

```bash
./scripts/scaffold.sh --template spa --name my-app
cd my-app
npm install
npm run dev
```

#### Create a component library

```bash
./scripts/scaffold.sh --template lib --name my-components
cd my-components
npm install
npm run build
```

#### Create a static blog

```bash
./scripts/scaffold.sh --template ssg --name my-blog
cd my-blog
npm install
npm run build
```

#### Create a real-time chat app

```bash
./scripts/scaffold.sh --template realtime --name my-chat
cd my-chat
npm install
npm run dev
```

### Using with Just

The scaffolder is integrated with the Justfile:

```bash
just scaffold-spa my-app          # Create SPA
just scaffold-ssg my-blog         # Create SSG
just scaffold-lib my-components   # Create component library
just scaffold-realtime my-chat    # Create real-time app
```

### What Gets Created

The scaffolder creates a complete project structure with:

- ✅ `package.json` with dependencies configured
- ✅ `rescript.json` with compiler settings
- ✅ `vite.config.js` for bundling
- ✅ `index.html` entry point
- ✅ `src/rescript/App.res` starter component
- ✅ `src/js/main.jsx` Vite entry point
- ✅ `src/js/style.css` global styles
- ✅ `.gitignore` for version control
- ✅ `.editorconfig` for editor consistency
- ✅ `.well-known/project.json` project metadata
- ✅ Template-specific directories and files
- ✅ Initialized git repository

### Template Specifics

#### SPA (Single-Page Application)

- Creates `src/rescript/pages/` for page components
- Creates `src/rescript/components/` for reusable components
- Creates `src/rescript/hooks/` for custom hooks
- Best for: Dashboards, web apps, interactive sites

#### SSG (Static Site Generator)

- Creates `content/posts/` for blog posts
- Creates `content/pages/` for static pages
- Sample markdown file included
- Best for: Blogs, documentation, marketing sites

#### LIB (Component Library)

- Creates `src/rescript/index.res` as barrel export
- Includes sample Button component
- Configured for npm publishing
- Best for: Reusable UI components, design systems

#### Realtime (Real-Time Application)

- Creates `src/rescript/state/` for state management
- Creates `src/rescript/websocket/` for WebSocket integration
- Includes reducer pattern example
- Best for: Chat apps, collaboration, live updates

### Troubleshooting

**"Command not found: ./scripts/scaffold.sh"**

Make sure you're in the rescript-vite root directory (where this file is located).

**"Permission denied"**

The script needs execute permissions:

```bash
chmod +x scripts/scaffold.sh
```

**"Directory already exists"**

The scaffold will not overwrite existing directories. Choose a different name.

**Git config not found**

If `--author` and `--email` are not provided, the script reads from `git config`. Set them first:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

---

For questions or issues, see the main [README.adoc](../README.adoc).
