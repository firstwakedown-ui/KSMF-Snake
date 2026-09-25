import { createClient } from '@supabase/supabase-js'

// Klient pro Supabase. Hodnoty se berou z .env (VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY).
// anon key je veřejný (určený do frontendu) – přístup hlídají RLS politiky v DB.
const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase =
  url && anonKey ? createClient(url, anonKey) : null

if (!supabase) {
  // Prototyp #1 (mapa + GPS) běží i bez Supabase – napojení doplníme v dalším kroku.
  console.warn('[supabase] Chybí VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY – běžím bez backendu.')
}
