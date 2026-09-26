import { useState } from 'react'
import { Link } from 'react-router-dom'
import { setAdminToken } from '../lib/session'
import { supabase } from '../lib/supabase'

export { isAdminUnlocked } from '../lib/session'

export default function AdminLogin({ onUnlock }: { onUnlock: () => void }) {
  const [pwd, setPwd] = useState('')
  const [err, setErr] = useState<string | null>(null)

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!supabase) return
    const { data, error } = await supabase.rpc('login_admin', { p_password: pwd })
    if (error || !data) { setErr(error?.message ?? 'Špatné heslo.'); return }
    setAdminToken(String(data)); onUnlock()
  }

  return (
    <div className="admin-login glass">
      <form className="admin-login-card" onSubmit={submit}>
        <h1>KSMF Snake — Admin</h1>
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
