import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Login from './routes/Login'
import Lobby from './routes/Lobby'
import PlayerView from './routes/PlayerView'
import AdminView from './routes/AdminView'
import Info from './routes/Info'
import './index.css'
import { registerSW } from 'virtual:pwa-register'

// Zachyť instalační prompt co nejdřív (před mountem Reactu), ať o něj nepřijdeme
// kvůli načasování. InstallHint si ho pak vyzvedne přes window.__adkInstallPrompt.
;(window as any).__adkInstallPrompt = null
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault()
  ;(window as any).__adkInstallPrompt = e
  window.dispatchEvent(new Event('adk-installable'))
})

// Service worker s periodickou kontrolou aktualizací (každých 30 s) + auto-reload na novou verzi.
registerSW({
  immediate: true,
  onRegisteredSW(_swUrl, r) {
    if (r) setInterval(() => { if (!r.installing && navigator.onLine) r.update() }, 30000)
  },
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Login />} />
        <Route path="/lobby" element={<Lobby />} />
        <Route path="/play" element={<PlayerView />} />
        <Route path="/admin" element={<AdminView />} />
        <Route path="/info" element={<Info />} />
      </Routes>
    </BrowserRouter>
  </React.StrictMode>,
)
