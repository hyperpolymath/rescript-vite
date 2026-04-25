// SPDX-License-Identifier: PMPL-1.0-or-later
// Vite entry point - bridges ReScript output with browser DOM

import React from 'react'
import ReactDOM from 'react-dom/client'
import App from '@rescript/App.res.js'
import './style.css'

// Mount ReScript app into the DOM
ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
