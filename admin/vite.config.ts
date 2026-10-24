import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// In development the API is proxied, so the admin panel and API share an origin (no CORS, no hard-coded host).
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': { target: process.env.API_URL ?? 'http://localhost:5080', changeOrigin: true },
      '/health': { target: process.env.API_URL ?? 'http://localhost:5080', changeOrigin: true },
    },
  },
})
