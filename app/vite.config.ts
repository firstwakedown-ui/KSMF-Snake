import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

// PWA: instalovatelná appka, service worker pro offline shell.
export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      injectRegister: null, // registrujeme ručně v main.tsx (kvůli periodické kontrole aktualizací)
      includeAssets: ['apple-touch-icon.png', 'favicon.png', 'logo.gif', 'manual-hrac.pdf', 'manual-admin.pdf'],
      workbox: {
        clientsClaim: true,
        skipWaiting: true,
        cleanupOutdatedCaches: true,
        // Jinak SW vrací na každou navigaci index.html → otevření /…​.pdf zobrazí appku místo PDF.
        navigateFallbackDenylist: [/\.pdf$/],
        globPatterns: ['**/*.{js,css,html,ico,png,svg,webp,woff,woff2,pdf}'],
      },
      manifest: {
        name: 'AchtungDieKM',
        short_name: 'AchtungKM',
        description: 'Lokační hra v reálném městě – had na ulicích.',
        lang: 'cs',
        theme_color: '#0d1117',
        background_color: '#0d1117',
        display: 'standalone',
        orientation: 'portrait',
        categories: ['games', 'sports'],
        icons: [
          { src: 'pwa-192x192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
          { src: 'pwa-512x512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
          { src: 'pwa-maskable-512x512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
    }),
  ],
})
