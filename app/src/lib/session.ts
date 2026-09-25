// Jednoduchá session bez Supabase Auth: hráč v localStorage, admin odemčení v sessionStorage.
export type PlayerSession = { id: string; nickname: string }

const PLAYER_KEY = 'adk_player'
const ADMIN_KEY = 'adk_admin_ok'

export function getPlayer(): PlayerSession | null {
  try {
    const s = localStorage.getItem(PLAYER_KEY)
    return s ? (JSON.parse(s) as PlayerSession) : null
  } catch {
    return null
  }
}
export function setPlayer(p: PlayerSession) {
  localStorage.setItem(PLAYER_KEY, JSON.stringify(p))
}
export function clearPlayer() {
  localStorage.removeItem(PLAYER_KEY)
}

export function isAdminUnlocked(): boolean {
  return sessionStorage.getItem(ADMIN_KEY) === '1'
}
export function setAdminUnlocked() {
  sessionStorage.setItem(ADMIN_KEY, '1')
}
export function clearAdminUnlocked() {
  sessionStorage.removeItem(ADMIN_KEY)
}
