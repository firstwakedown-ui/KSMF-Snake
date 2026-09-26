import { useEffect, useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { getPlayer, setPlayer, setAdminToken } from '../lib/session'
import VersionBadge from './VersionBadge'
import InstallHint from './InstallHint'

export default function Login() {
  const nav = useNavigate()
  const [tab, setTab] = useState<'player' | 'admin'>('player')
  // Hráč
  const [nick, setNick] = useState('')
  const [pwd, setPwd] = useState('')
  const [code, setCode] = useState('')
  // Admin
  const [adminPwd, setAdminPwd] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  // Už přihlášený hráč → rovnou do lobby.
  useEffect(() => {
    if (getPlayer()) nav('/lobby', { replace: true })
  }, [nav])

  const submitPlayer = async (e: React.FormEvent) => {
    e.preventDefault()
    setErr(null)
    if (!supabase) {
      setErr('Chybí Supabase (.env).')
      return
    }
    if (!nick.trim() || !pwd) {
      setErr('Vyplň přezdívku i heslo.')
      return
    }
    setBusy(true)
    try {
      // Kód vyplněn = registrace nového hráče; prázdný = přihlášení existujícího.
      const rpc = code.trim() ? 'register_player' : 'login_player'
      const args = code.trim()
        ? { p_nickname: nick.trim(), p_password: pwd, p_code: code.trim() }
        : { p_nickname: nick.trim(), p_password: pwd }
      const { data, error } = await supabase.rpc(rpc, args)
      if (error) throw error
      const row = Array.isArray(data) ? data[0] : data
      if (!row?.id) throw new Error('Přihlášení se nezdařilo.')
      setPlayer({ id: row.id, nickname: row.nickname, token: row.token })
      nav('/lobby', { replace: true })
    } catch (e: any) {
      setErr(e.message ?? String(e))
    } finally {
      setBusy(false)
    }
  }

  const submitAdmin = async (e: React.FormEvent) => {
    e.preventDefault()
    setErr(null)
    if (!supabase) return
    const { data, error } = await supabase.rpc('login_admin', { p_password: adminPwd })
    if (error || !data) { setErr(error?.message ?? 'Špatné admin heslo.'); return }
    setAdminToken(String(data)); nav('/admin', { replace: true })
  }

  return (
    <div className="admin-login glass">
      <div className="admin-login-card">
        <img src="/logo.gif" alt="KSMF Snake" className="auth-logo" />
        <div className="auth-tabs">
          <button className={`pill mode ${tab === 'player' ? 'active' : ''}`} onClick={() => { setTab('player'); setErr(null) }}>Hráč</button>
          <button className={`pill mode ${tab === 'admin' ? 'active' : ''}`} onClick={() => { setTab('admin'); setErr(null) }}>Admin</button>
        </div>

        {tab === 'player' ? (
          <form onSubmit={submitPlayer} className="auth-form">
            <p>Přihlas se přezdívkou a heslem. <b>Nový hráč?</b> Vyplň i přístupový kód od admina.</p>
            <input value={nick} onChange={(e) => setNick(e.target.value)} placeholder="Přezdívka" autoFocus />
            <input type="password" value={pwd} onChange={(e) => setPwd(e.target.value)} placeholder="Heslo" />
            <input value={code} onChange={(e) => setCode(e.target.value)} placeholder="Přístupový kód (jen registrace)" />
            <button type="submit" disabled={busy}>{busy ? '…' : code.trim() ? 'Zaregistrovat a vstoupit' : 'Přihlásit se'}</button>
          </form>
        ) : (
          <form onSubmit={submitAdmin} className="auth-form">
            <p>Správa map a hry. Zadej admin heslo.</p>
            <input type="password" value={adminPwd} onChange={(e) => setAdminPwd(e.target.value)} placeholder="Admin heslo" autoFocus />
            <button type="submit">Vstoupit jako admin</button>
          </form>
        )}

        {err && <p className="admin-err">{err}</p>}
        <Link className="info-link" to="/info">ⓘ O aplikaci & deník vývoje</Link>
      </div>
      <InstallHint />
      <VersionBadge />
    </div>
  )
}
