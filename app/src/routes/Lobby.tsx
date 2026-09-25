import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { getPlayer, clearPlayer } from '../lib/session'
import StartPicker from './StartPicker'
import VersionBadge from './VersionBadge'
import TrailsImage from './TrailsImage'
import Spectate from '../admin/Spectate'
import InstallHint from './InstallHint'
import { trailLenM } from '../lib/collision'
import { loadGameResults, type ResultRow } from '../lib/results'

type LobbyGame = { game_id: string; plan_id: string; plan_name: string | null; capacity: number; joined: number; mine: boolean; my_start: string | null; status: string; alive: boolean | null }

export default function Lobby() {
  const nav = useNavigate()
  const player = getPlayer()
  const [games, setGames] = useState<LobbyGame[]>([])
  const [myGames, setMyGames] = useState<{ game_id: string; plan_id: string; plan_name: string | null; place: number | null; finished_at: string | null }[]>([])
  const [picking, setPicking] = useState<LobbyGame | null>(null)
  const [spectate, setSpectate] = useState<LobbyGame | null>(null)
  const [resultsModal, setResultsModal] = useState<{ name: string; rows: ResultRow[]; streets: [number, number][][] } | null>(null)
  const [err, setErr] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!player) nav('/', { replace: true })
  }, [player, nav])

  const load = async () => {
    if (!player || !supabase) return
    const { data, error } = await supabase.rpc('lobby_games', { p_player: player.id })
    if (error) setErr(error.message)
    else { setGames((data ?? []) as LobbyGame[]); setErr(null) }
    const { data: mg } = await supabase.rpc('my_finished_games', { p_player: player.id })
    setMyGames((mg ?? []) as any[])
    setLoading(false)
  }
  const openResults = async (g: { game_id: string; plan_id: string; plan_name: string | null }) => {
    const { rows, streets } = await loadGameResults(g.game_id, g.plan_id)
    setResultsModal({ name: g.plan_name ?? 'Hra', rows, streets })
  }
  useEffect(() => {
    load()
    const t = setInterval(load, 4000)
    return () => clearInterval(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const joinWithStart = async (gameId: string, startId: string) => {
    const { error } = await supabase!.rpc('join_game', { p_game: gameId, p_player: player!.id, p_start: startId })
    if (error) { setErr(error.message); return }
    setPicking(null)
    await load()
  }
  const leave = async (g: LobbyGame) => {
    const { error } = await supabase!.rpc('leave_game', { p_game: g.game_id, p_player: player!.id })
    if (error) { setErr(error.message); return }
    await load()
  }
  const logout = () => { clearPlayer(); nav('/', { replace: true }) }

  if (!player) return null

  return (
    <div className="lobby">
      <div className="lobby-header">
        <h1>Lobby</h1>
        <span className="muted">{player.nickname}</span>
        <a className="pill link" href="/manual-hrac.pdf" target="_blank" rel="noopener">📄 Manuál (PDF)</a>
        <button className="ghost" onClick={logout}>Odhlásit</button>
      </div>

      {err && <div className="manage-status err">{err}</div>}
      {loading && <p className="muted">Načítám…</p>}
      {!loading && games.length === 0 && (
        <p className="muted">Žádná hra zatím není otevřená. Počkej, až admin založí hru.</p>
      )}

      <div className="lobby-list">
        {games.map((g) => {
          const full = g.joined >= g.capacity
          return (
            <div key={g.game_id} className="lobby-card">
              <div className="lobby-card-main">
                <b>{g.plan_name ?? 'Mapa'}</b>
                <span className="muted">
                  {g.joined}/{g.capacity} hráčů{g.mine ? ` · tvůj start: ${g.my_start ?? '?'}` : ''}
                  {g.status === 'running' ? ' · 🟢 běží' : ''}
                </span>
              </div>
              {g.mine && g.status === 'running' && g.alive === false ? (
                // Vyřazený z běžící hry → může ji už jen sledovat.
                <button onClick={() => setSpectate(g)}>👁️ Sledovat</button>
              ) : g.mine ? (
                <div className="lobby-actions">
                  <button onClick={() => nav('/play')}>{g.status === 'running' ? 'Vstoupit do hry →' : 'Do hry →'}</button>
                  <button className="ghost" onClick={() => leave(g)}>Odpojit</button>
                </div>
              ) : (
                <div className="lobby-actions">
                  {g.status === 'lobby' && <button disabled={full} onClick={() => setPicking(g)}>{full ? 'Plno' : 'Vybrat start'}</button>}
                  <button className="ghost" onClick={() => setSpectate(g)}>👁️ Jen sledovat</button>
                </div>
              )}
            </div>
          )
        })}
      </div>

      {myGames.length > 0 && (
        <div className="my-games">
          <h2>Tvoje odehrané hry</h2>
          <ul className="row-list">
            {myGames.map((g) => (
              <li key={g.game_id}>
                <span>{g.plan_name ?? '—'} <span className="muted">· {g.place ? g.place + '. místo' : '—'}{g.finished_at ? ' · ' + new Date(g.finished_at).toLocaleDateString('cs-CZ') : ''}</span></span>
                <button onClick={() => openResults(g)}>Výsledky</button>
              </li>
            ))}
          </ul>
        </div>
      )}

      {picking && (
        <StartPicker
          gameId={picking.game_id}
          planId={picking.plan_id}
          onJoin={(s) => joinWithStart(picking.game_id, s)}
          onCancel={() => setPicking(null)}
        />
      )}

      {spectate && (
        <Spectate
          gameId={spectate.game_id}
          planId={spectate.plan_id}
          status={spectate.status}
          readOnly
          onClose={() => setSpectate(null)}
        />
      )}

      {resultsModal && (
        <div className="modal" onClick={() => setResultsModal(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <h2>Výsledky — {resultsModal.name}</h2>
            <TrailsImage streets={resultsModal.streets} players={resultsModal.rows} width={320} height={240} />
            <ol className="results">
              {resultsModal.rows.map((r, i) => (
                <li key={i}><span className="place">{r.place ?? '—'}.</span> <span style={{ color: r.color }}>●</span> {r.nickname}{r.place === 1 ? ' 🏆' : ''} <span className="muted">· {trailLenM(r.trail)} m</span></li>
              ))}
            </ol>
            <button onClick={() => setResultsModal(null)}>Zavřít</button>
          </div>
        </div>
      )}

      <InstallHint />
      <VersionBadge />
    </div>
  )
}
