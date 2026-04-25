// SPDX-License-Identifier: PMPL-1.0-or-later
// Vite configuration for rescript-vite projects
// This file configures bundling, HMR, and development server behavior.

import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import path from 'path'

export default defineConfig({
  plugins: [react()],

  server: {
    port: 5173,
    strictPort: false,
    // HMR configuration for development
    hmr: {
      protocol: 'ws',
      host: 'localhost',
      port: 5173,
    },
  },

  build: {
    // Output directory for production builds
    outDir: 'dist/vite',

    // Rollup options for optimising bundle
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor': ['react', 'react-dom'],
        },
      },
    },

    // Enable source maps for debugging
    sourcemap: true,

    // Minification settings
    minify: 'terser',
  },

  resolve: {
    // ReScript compiled output directory
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@rescript': path.resolve(__dirname, './dist/rescript'),
    },
  },
})
