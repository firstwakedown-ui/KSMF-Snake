import { createClient } from '@supabase/supabase-js'

// Klient pro Supabase. Hodnoty se berou z .env (VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY).
// anon key je veřejný (určený do frontendu) – přístup hlídají RLS politiky v DB.
const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

const sessionHeadersFetch: typeof fetch = (input, init = {}) => {
  let playerToken: string | null = null
  let adminToken: string | null = null
  try {
    const player = JSON.parse(localStorage.getItem('adk_player') ?? 'null')
    playerToken = player?.token ?? null
    adminToken = sessionStorage.getItem('ksmf_admin_token')
  } catch {}
  const headers = new Headers(init.headers)
  if (playerToken) headers.set('x-player-token', playerToken)
  if (adminToken) headers.set('x-admin-token', adminToken)
  return fetch(input, { ...init, headers })
}

export const supabase = url && anonKey
  ? createClient(url, anonKey, { global: { fetch: sessionHeadersFetch } })
  : null

if (!supabase) {
  // Prototyp #1 (mapa + GPS) běží i bez Supabase – napojení doplníme v dalším kroku.
  console.warn('[supabase] Chybí VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY – běžím bez backendu.')
}
