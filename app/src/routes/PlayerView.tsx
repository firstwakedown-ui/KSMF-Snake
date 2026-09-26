import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { bbox as turfBbox } from '@turf/turf'
import type { Feature } from 'geojson'
import { supabase } from '../lib/supabase'
import { getPlayer, type PlayerSession } from '../lib/session'
import { assignColors } from '../lib/players'
import { BARRANDOV, BARRANDOV_BBOX, MAP_STYLE, emptyFC, pointFC, setSourceData } from '../lib/geo'
import VersionBadge from './VersionBadge'

const START_COUNTDOWN_S = 10
type Coord = [number, number]
type Phase = 'loading' | 'none' | 'waiting' | 'countdown' | 'live' | 'respawn' | 'ended'
type GameInfo = { game_id: string; plan_id: string; plan_name: string | null; status: string; started_at: string | null; sim: boolean; run_mode: boolean; game_duration_s?: number; max_lead_m?: number }
type WorldRow = { player_id: string; nickname: string; active: boolean; body: { coordinates: Coord[] } | null; head: { coordinates: Coord } | null; current_length_m: number; max_length_m: number; strawberries_eaten: number; opponent_explosions: number }
type RespawnPoint = { id: string; label: string; geom: { coordinates: Coord } }

const fc = (features: Feature[]) => ({ type: 'FeatureCollection' as const, features })
const lineFeature = (coordinates: Coord[], properties: Record<string, unknown> = {}): Feature => ({ type: 'Feature', geometry: { type: 'LineString', coordinates }, properties })
const pointFeature = (coordinates: Coord, properties: Record<string, unknown> = {}): Feature => ({ type: 'Feature', geometry: { type: 'Point', coordinates }, properties })

export default function PlayerView() {
  const nav = useNavigate()
  const playerRef = useRef<PlayerSession | null>(getPlayer())
  const gameRef = useRef<GameInfo | null>(null)
  const mapRef = useRef<maplibregl.Map | null>(null)
  const readyRef = useRef(false)
  const posRef = useRef<Coord | null>(null)
  const selectedRespawnRef = useRef<string | null>(null)
  const colorsRef = useRef(new Map<string, string>())
  const simRef = useRef(false)
  const positionChannelRef = useRef<ReturnType<NonNullable<typeof supabase>['channel']> | null>(null)
  const positionChannelGameRef = useRef('')
  const phaseRef = useRef<Phase>('loading')
  const [phase, setPhaseState] = useState<Phase>('loading')
  const setPhase = (p: Phase) => { phaseRef.current = p; setPhaseState(p) }
  const [countdown, setCountdown] = useState(START_COUNTDOWN_S)
  const [remaining, setRemaining] = useState<number | null>(null)
  const [lead, setLead] = useState(0)
  const [length, setLength] = useState(10)
  const [berries, setBerries] = useState(0)
  const [activeBerries, setActiveBerries] = useState(0)
  const [berryPointCount, setBerryPointCount] = useState(0)
  const [kills, setKills] = useState(0)
  const [, setRespawns] = useState<RespawnPoint[]>([])
  const respawnsRef = useRef<RespawnPoint[]>([])
  const respawnMarkersRef = useRef<maplibregl.Marker[]>([])
  const berryMarkersRef = useRef<maplibregl.Marker[]>([])
  const [respawnMessage, setRespawnMessage] = useState('Vyber si respawn bod a dojdi k němu.')
  const [explosion, setExplosion] = useState<string | null>(null)
  const [results, setResults] = useState<WorldRow[]>([])
  const [sim, setSim] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => { if (!playerRef.current) nav('/', { replace: true }) }, [nav])

  const renderRespawns = () => {
    const map = mapRef.current
    if (!map) return
    setSourceData(map, 'respawns', fc(respawnsRef.current.map((r) => pointFeature(r.geom.coordinates, { id: r.id, label: r.label, selected: selectedRespawnRef.current === r.id }))))
    respawnMarkersRef.current.forEach((marker) => marker.remove())
    respawnMarkersRef.current = respawnsRef.current.map((r) => {
      const selected = selectedRespawnRef.current === r.id
      const el = document.createElement('button')
      el.type = 'button'
      el.textContent = `↻ ${r.label}`
      el.title = `Respawn ${r.label}`
      Object.assign(el.style, { background: selected ? '#3fb950' : '#1769aa', color: '#fff', border: '2px solid #fff', borderRadius: '16px', padding: '5px 8px', fontWeight: '700', boxShadow: '0 1px 5px #0008', cursor: phaseRef.current === 'respawn' ? 'pointer' : 'default', whiteSpace: 'nowrap' })
      el.addEventListener('click', (event) => {
        event.preventDefault(); event.stopPropagation()
        if (phaseRef.current !== 'respawn') return
        selectedRespawnRef.current = r.id
        renderRespawns()
      })
      return new maplibregl.Marker({ element: el, anchor: 'bottom' }).setLngLat(r.geom.coordinates).addTo(map)
    })
  }

  const renderBerries = (fruit: { point_id: string; lng: number; lat: number }[]) => {
    const map = mapRef.current
    if (!map) return
    berryMarkersRef.current.forEach((marker) => marker.remove())
    berryMarkersRef.current = fruit.map((berry) => {
      const el = document.createElement('div')
      el.textContent = '🍓'
      el.title = 'Jahůdka - sebere ji hlava hada'
      Object.assign(el.style, { fontSize: '28px', lineHeight: '30px', filter: 'drop-shadow(0 1px 2px #000)', pointerEvents: 'none' })
      return new maplibregl.Marker({ element: el, anchor: 'bottom' }).setLngLat([berry.lng, berry.lat]).addTo(map)
    })
  }

  useEffect(() => {
    const map = new maplibregl.Map({ container: 'map', style: MAP_STYLE, center: BARRANDOV, zoom: 15 })
    mapRef.current = map
    map.on('load', () => {
      map.addSource('streets', { type: 'geojson', data: emptyFC() }); map.addLayer({ id: 'streets-line', type: 'line', source: 'streets', paint: { 'line-color': '#57606a', 'line-width': 3, 'line-opacity': .65 } })
      map.addSource('future', { type: 'geojson', data: emptyFC() }); map.addLayer({ id: 'future-line', type: 'line', source: 'future', paint: { 'line-color': '#fff', 'line-width': 3, 'line-dasharray': [2, 1], 'line-opacity': .65 } })
      // Tělo je nad budoucí trasou: hráč tak vždy spolehlivě rozezná skutečnou překážku.
      map.addSource('bodies', { type: 'geojson', data: emptyFC() }); map.addLayer({ id: 'bodies-line', type: 'line', source: 'bodies', paint: { 'line-color': ['get', 'color'], 'line-width': 7, 'line-opacity': .92 } })
      map.addSource('my-body', { type: 'geojson', data: emptyFC() }); map.addLayer({ id: 'my-body-line', type: 'line', source: 'my-body', paint: { 'line-color': ['get', 'color'], 'line-width': 10, 'line-opacity': 1, 'line-blur': .25 } })
      map.addSource('heads', { type: 'geojson', data: emptyFC() }); map.addLayer({ id: 'heads-circle', type: 'circle', source: 'heads', paint: { 'circle-radius': 8, 'circle-color': ['get', 'color'], 'circle-stroke-color': '#fff', 'circle-stroke-width': 2 } }); map.addLayer({ id: 'heads-label', type: 'symbol', source: 'heads', layout: { 'text-field': ['get', 'nick'], 'text-size': 11, 'text-offset': [0, 1.4] }, paint: { 'text-color': '#fff', 'text-halo-color': '#0d1117', 'text-halo-width': 2 } })
      map.addSource('berries', { type: 'geojson', data: emptyFC() }); map.addLayer({ id: 'berries-circle', type: 'circle', source: 'berries', paint: { 'circle-radius': 9, 'circle-color': '#ff375f', 'circle-stroke-color': '#7a001b', 'circle-stroke-width': 2 } }); map.addLayer({ id: 'berries-label', type: 'symbol', source: 'berries', layout: { 'text-field': '🍓', 'text-size': 17, 'text-allow-overlap': true } })
      map.addSource('respawns', { type: 'geojson', data: emptyFC() }); map.addLayer({ id: 'respawns-circle', type: 'circle', source: 'respawns', paint: { 'circle-radius': 12, 'circle-color': ['case', ['get', 'selected'], '#3fb950', '#1f6feb'], 'circle-stroke-color': '#fff', 'circle-stroke-width': 2 } }); map.addLayer({ id: 'respawns-label', type: 'symbol', source: 'respawns', layout: { 'text-field': ['get', 'label'], 'text-size': 12 }, paint: { 'text-color': '#fff' } })
      map.addSource('player', { type: 'geojson', data: emptyFC() }); map.addLayer({ id: 'player-circle', type: 'circle', source: 'player', paint: { 'circle-radius': 6, 'circle-color': '#fff', 'circle-stroke-color': '#111', 'circle-stroke-width': 2 } })
      map.on('click', (e) => {
        if (simRef.current) { posRef.current = [e.lngLat.lng, e.lngLat.lat]; setSourceData(map, 'player', pointFC(posRef.current, true)) }
        if (phaseRef.current === 'respawn') { const hit = map.queryRenderedFeatures(e.point, { layers: ['respawns-circle'] })[0]; if (hit?.properties?.id) { selectedRespawnRef.current = hit.properties.id; renderRespawns() } }
      })
      readyRef.current = true; map.fitBounds(BARRANDOV_BBOX, { padding: 40, duration: 0 })
    })
    return () => { respawnMarkersRef.current.forEach((marker) => marker.remove()); berryMarkersRef.current.forEach((marker) => marker.remove()); map.remove() }
  }, [])

  const loadMap = async (planId: string) => {
    const [{ data }, { data: respawns }, { data: berryPoints }] = await Promise.all([
      supabase!.from('street_edges').select('geom').eq('match_id', planId).eq('enabled', true),
      supabase!.from('respawn_points').select('id,label,geom').eq('match_id', planId),
      supabase!.from('strawberry_points').select('id').eq('match_id', planId),
    ])
    const features = (data ?? []).map((r: any) => ({ type: 'Feature' as const, geometry: r.geom, properties: {} }))
    setSourceData(mapRef.current, 'streets', fc(features))
    respawnsRef.current = (respawns ?? []) as RespawnPoint[]
    setRespawns(respawnsRef.current)
    renderRespawns()
    setBerryPointCount((berryPoints ?? []).length)
    if (features.length) { const [w, s, e, n] = turfBbox(fc(features)); mapRef.current?.fitBounds([[w, s], [e, n]], { padding: 40, duration: 0 }) }
  }

  const refreshWorld = async () => {
    const g = gameRef.current, me = playerRef.current
    if (!g || !me || !supabase || !readyRef.current) return
    const [{ data: world }, fruitResult, { data: mine }] = await Promise.all([
      supabase.rpc('snake_world', { p_game: g.game_id }), supabase.rpc('active_strawberries', { p_game: g.game_id }),
      supabase.from('snake_states').select('route,head_pos,active,current_length_m,strawberries_eaten,opponent_explosions').eq('game_id', g.game_id).eq('player_id', me.id).maybeSingle(),
    ])
    const rows = (world ?? []) as WorldRow[]; colorsRef.current = assignColors(rows.map((r) => r.player_id))
    const bodies = rows.filter((r) => r.active && r.body?.coordinates?.length)
    setSourceData(mapRef.current, 'bodies', fc(bodies.map((r) => lineFeature(r.body!.coordinates, { color: colorsRef.current.get(r.player_id) ?? '#888' }))))
    const mineBody = bodies.find((r) => r.player_id === me.id)
    setSourceData(mapRef.current, 'my-body', mineBody ? fc([lineFeature(mineBody.body!.coordinates, { color: colorsRef.current.get(me.id) ?? '#3fb950' })]) : emptyFC())
    setSourceData(mapRef.current, 'heads', fc(rows.filter((r) => r.active && r.head?.coordinates).map((r) => pointFeature(r.head!.coordinates, { color: colorsRef.current.get(r.player_id) ?? '#888', nick: r.nickname }))))
    if (fruitResult.error) setError(`Jahůdky: ${fruitResult.error.message}`)
    const fruit = fruitResult.data ?? []
    setActiveBerries(fruit.length)
    setSourceData(mapRef.current, 'berries', fc(fruit.map((b: any) => pointFeature([b.lng, b.lat], { id: b.point_id }))))
    renderBerries(fruit)
    if (!mine) return
    setLength(Number(mine.current_length_m ?? 10)); setBerries(mine.strawberries_eaten ?? 0); setKills(mine.opponent_explosions ?? 0)
    const route = mine.route?.coordinates as Coord[] | undefined, head = mine.head_pos?.coordinates as Coord | undefined
    setSourceData(mapRef.current, 'future', route?.length && head ? fc([lineFeature(route)]) : emptyFC())
    if (!mine.active && phaseRef.current !== 'ended') setPhase('respawn')
  }

  const finish = async (gameId: string) => { const { data } = await supabase!.rpc('snake_world', { p_game: gameId }); setResults((data ?? []) as WorldRow[]); setPhase('ended') }

  useEffect(() => {
    let initializedGame = ''
    const poll = async () => {
      const me = playerRef.current; if (!me || !supabase) return
      const { data } = await supabase.rpc('current_game', { p_player: me.id }); const g = (Array.isArray(data) ? data[0] : data) as GameInfo | undefined
      if (!g?.game_id) { if (gameRef.current) await finish(gameRef.current.game_id); else setPhase('none'); return }
      gameRef.current = g
      if (initializedGame !== g.game_id && readyRef.current) { initializedGame = g.game_id; await loadMap(g.plan_id) }
      // Režim simulace určuje admin při založení hry. Hráč ho proto nemusí zapínat ručně.
      if (initializedGame === g.game_id) {
        simRef.current = Boolean(g.sim)
        setSim(Boolean(g.sim))
      }
      if (g.status === 'lobby' || !g.started_at) { setPhase('waiting'); return }
      const elapsed = (Date.now() - new Date(g.started_at).getTime()) / 1000
      if (elapsed < START_COUNTDOWN_S) { setPhase('countdown'); setCountdown(Math.max(1, Math.ceil(START_COUNTDOWN_S - elapsed))); setRemaining(Number(g.game_duration_s ?? 900)); return }
      const left = Math.max(0, Number(g.game_duration_s ?? 900) - Math.max(0, elapsed - START_COUNTDOWN_S)); setRemaining(Math.ceil(left))
      if (left <= 0) { await finish(g.game_id); return }
      if (phaseRef.current !== 'respawn') setPhase('live'); await refreshWorld()
    }
    poll(); const id = setInterval(poll, 1000); return () => clearInterval(id)
  }, [])

  // Před startem ani v simulaci ještě neběží snake_tick, proto adminovi pravidelně
  // vysíláme skutečnou/kliknutou polohu přímo do stejného kanálu jako živá mapa.
  useEffect(() => {
    const publish = async () => {
      const game = gameRef.current
      const me = playerRef.current
      const pos = posRef.current
      if (!game || !me || !pos || !supabase) return
      if (positionChannelGameRef.current !== game.game_id) {
        if (positionChannelRef.current) await supabase.removeChannel(positionChannelRef.current)
        const channel = supabase.channel(`game-${game.game_id}`)
        channel.subscribe()
        positionChannelRef.current = channel
        positionChannelGameRef.current = game.game_id
      }
      await positionChannelRef.current?.send({
        type: 'broadcast', event: 'pos',
        payload: { id: me.id, nick: me.nickname, pos, live: game.status === 'running' },
      })
    }
    const id = window.setInterval(() => { void publish() }, 1000)
    return () => {
      window.clearInterval(id)
      if (positionChannelRef.current) void supabase?.removeChannel(positionChannelRef.current)
      positionChannelRef.current = null
      positionChannelGameRef.current = ''
    }
  }, [])

  useEffect(() => {
    if (!('geolocation' in navigator)) { setError('Tento prohlížeč nepodporuje GPS.'); return }
    const id = navigator.geolocation.watchPosition((p) => { if (!simRef.current) posRef.current = [p.coords.longitude, p.coords.latitude]; if (posRef.current) setSourceData(mapRef.current, 'player', pointFC(posRef.current, true)) }, (e) => setError(`GPS: ${e.message}`), { enableHighAccuracy: true, maximumAge: 0, timeout: 10000 })
    return () => navigator.geolocation.clearWatch(id)
  }, [])

  useEffect(() => {
    const tick = async () => {
      const g = gameRef.current, me = playerRef.current, pos = posRef.current; if (!g || !me || !pos || !supabase || !['live', 'respawn'].includes(phaseRef.current)) return
      if (phaseRef.current === 'respawn') {
        if (!respawnsRef.current.length) { const { data } = await supabase.from('respawn_points').select('id,label,geom').eq('match_id', g.plan_id); respawnsRef.current = (data ?? []) as RespawnPoint[]; setRespawns(respawnsRef.current); renderRespawns() }
        const pointId = selectedRespawnRef.current; if (!pointId) return
        const { data, error: e } = await supabase.rpc('snake_respawn', { p_game: g.game_id, p_player: me.id, p_point: pointId, p_lng: pos[0], p_lat: pos[1] }); if (e) { setError(e.message); return }
        if (data?.status === 'approaching') setRespawnMessage(`Dojdi k vybranému bodu — ${data.distance_m} m`)
        if (data?.status === 'countdown') setRespawnMessage(`Vracíš se do hry — ${data.seconds}`)
        if (data?.status === 'live') { selectedRespawnRef.current = null; renderRespawns(); setExplosion(null); setPhase('live') }
        return
      }
      const { data, error: e } = await supabase.rpc('snake_tick', { p_game: g.game_id, p_player: me.id, p_lng: pos[0], p_lat: pos[1] }); if (e) { setError(e.message); return }
      if (data?.status === 'exploded') { const labels: Record<string, string> = { too_far: 'Utekl jsi hadovi příliš daleko.', caught: 'Had tě dohnal.', self_collision: 'Narazil jsi do vlastního těla.', collision: 'Narazil jsi do soupeřova hada.' }; setExplosion(labels[data.reason] ?? 'Had vybuchl.'); setRespawnMessage('Vyber si respawn bod a dojdi k němu.'); setPhase('respawn') }
      else if (data?.status === 'ended') await finish(g.game_id)
      else { setLead(Math.round(Number(data?.lead_m ?? 0))); setLength(Number(data?.length_m ?? 10)) }
      await refreshWorld()
    }
    const id = setInterval(tick, 500); return () => clearInterval(id)
  }, [])

  const fmtTime = (s: number | null) => s == null ? '—' : `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
  return <><div id="map" /><VersionBadge />
    <div className="hud"><span><b>KSMF Snake</b></span>{phase !== 'waiting' && <span className="pill">⏱ {fmtTime(remaining)}</span>}{phase === 'live' && <><span className="pill">🐍 {Math.round(length)} m</span><span className={`pill ${lead > 80 ? 'warn' : ''}`}>náskok {lead} m</span><span className="pill">🍓 {berries}</span><span className={`pill ${activeBerries === 0 && berryPointCount > 0 ? 'warn' : ''}`}>jahůdky na mapě {activeBerries}/{berryPointCount}</span><span className="pill">💥 {kills}</span></>}{sim && <span className="pill active">Simulace: klikni do mapy</span>}<Link className="pill link" to="/lobby">← lobby</Link>{error && <span className="pill warn">{error}</span>}</div>
    <div className="zoom-ctrl"><button onClick={() => mapRef.current?.zoomIn()}>+</button><button onClick={() => mapRef.current?.zoomOut()}>−</button></div>
    {phase === 'waiting' && <div className="wait-banner">Můžeš začít kdekoliv v herní oblasti. Čeká se na spuštění hry.</div>}
    {phase === 'respawn' && <div className="wait-banner">💥 {explosion} {respawnMessage}</div>}
    {(phase === 'none' || phase === 'countdown' || phase === 'ended') && <div className="game-overlay"><div className="game-card">
      {phase === 'none' && <><h1>Nejsi v žádné hře</h1><Link className="big-btn" to="/lobby">Do lobby →</Link></>}
      {phase === 'countdown' && <><div className="safety">⚠️ Sleduj provoz a své okolí.</div><div className="countdown">{countdown}</div><p>Připrav se…</p></>}
      {phase === 'ended' && <><h1>Konec hry</h1><table className="snake-results"><thead><tr><th>Hráč</th><th>Max. délka</th><th>Jahůdky</th><th>Výbuchy soupeřů</th></tr></thead><tbody>{results.map((r) => <tr key={r.player_id}><td>{r.nickname}</td><td>{Math.round(Number(r.max_length_m))} m</td><td>{r.strawberries_eaten}</td><td>{r.opponent_explosions}</td></tr>)}</tbody></table><Link className="big-btn" to="/lobby">Do lobby →</Link></>}
    </div></div>}
  </>
}
