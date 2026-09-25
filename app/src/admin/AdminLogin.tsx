import { useState } from 'react'
import { Link } from 'react-router-dom'
import { setAdminUnlocked } from '../lib/session'

// Jednoduchá brána admina: sdílené heslo z env (VITE_ADMIN_PASSWORD).
// ⚠️ DOČASNÉ: heslo je v klientském buildu (uzavřená skupina, prototyp).
//    Ostré přihlášení (Supabase Auth – PIN na e-mail, FR-20) doplníme později. Viz TODO.
const ADMIN_PASSWORD = import.meta.env.VITE_ADMIN_PASSWORD as string | undefined

export { isAdminUnlocked } from '../lib/session'

export default function AdminLogin({ onUnlock }: { onUnlock: () => void }) {
  const [pwd, setPwd] = useState('')
  const [err, setErr] = useState<string | null>(null)

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!ADMIN_PASSWORD) {
      setErr('Admin heslo není nastavené (VITE_ADMIN_PASSWORD v .env).')
      return
    }
    if (pwd === ADMIN_PASSWORD) {
      setAdminUnlocked()
      onUnlock()
    } else {
      setErr('Špatné heslo.')
    }
  }

  return (
    <div className="admin-login glass">
      <form className="admin-login-card" onSubmit={submit}>
        <h1>AchtungDieKM — Admin</h1>
        <p>Správa hracího území. Zadej admin heslo.</p>
        <input
          type="password"
          value={pwd}
          onChange={(e) => setPwd(e.target.value)}
          placeholder="Admin heslo"
          autoFocus
        />
        <button type="submit">Vstoupit</button>
        {err && <p className="admin-err">{err}</p>}
        <Link className="admin-back" to="/">← zpět do hry</Link>
      </form>
    </div>
  )
}
