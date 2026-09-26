import { useEffect, useRef, useState } from 'react'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { bbox as turfBbox } from '@turf/turf'
import { supabase } from '../lib/supabase'
import { MAP_STYLE, BARRANDOV, emptyFC, setSourceData } from '../lib/geo'
import { assignColors, colorFor } from '../lib/players'
import { trailLenM } from '../lib/collision'
import type { Feature } from 'geojson'

type RosterRow = { player_id: string; nickname: string }
type P = { nick: string; trail: [number, number][]; pos: [number, number] | null; lastSeen: number; eliminated?: boolean }
type SnakeWorldRow = { player_id: string; nickname: string; active: boolean; body: { coordinates: [number, number][] } | null; head: { coordinates: [number, number] } | null }

export default function Spectate({ gameId, planId, status: status0, onClose, onChanged, readOnly }: {
  gameId: string; planId: string; status: string; onClose: () => void; onChanged?: () => void; readOnly?: boolean
}) {
  const mapRef = useRef<maplibregl.Map | null>(null)
  const playersRef = useRef<Map<string, P>>(new Map())
  const markersRef = useRef<Map<string, maplibregl.Marker>>(new Map())
  const planMarkersRef = useRef<maplibregl.Marker[]>([])
  const activeBerryMarkersRef = useRef<maplibregl.Marker[]>([])
  const colorRef = useRef<Map<string, string>>(new Map())
  const channelRef = useRef<ReturnType<NonNullable<typeof supabase>['channel']> | null>(null)
  const statusRef = useRef(status0)
  const [roster, setRoster] = useState<RosterRow[]>([])
  const [status, setStatus] = useState(status0)
  const [remaining, setRemaining] = useState<number | null>(null)
  const [mapReady, setMapReady] = useState(false)
  const [, force] = useState(0)

  useEffect(() => {
    const map = new maplibregl.Map({ container: 'spectate-map', style: MAP_STYLE, center: BARRANDOV, zoom: 15 })
    mapRef.current = map
    map.on('load', () => {
      map.addSource('streets', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'streets-line', type: 'line', source: 'streets', paint: { 'line-color': '#f59e0b', 'line-width': 3, 'line-opacity': 0.8 } })
      map.addSource('ptrails', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'ptrails-line', type: 'line', source: 'ptrails', paint: { 'line-color': ['get', 'color'], 'line-width': 4, 'line-opacity': 0.9 } })
      map.addSource('ppos', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'ppos-circle', type: 'circle', source: 'ppos', paint: { 'circle-radius': 7, 'circle-color': ['get', 'color'], 'circle-stroke-color': '#fff', 'circle-stroke-width': 2 } })
      map.addLayer({ id: 'ppos-label', type: 'symbol', source: 'ppos', layout: { 'text-field': ['get', 'nick'], 'text-size': 11, 'text-offset': [0, 1.2], 'text-allow-overlap': true }, paint: { 'text-color': '#fff', 'text-halo-color': '#0d1117', 'text-halo-width': 1.5 } })
      loadAll(map)
    })
    // Stejný serverový odpočet jako v adminském seznamu. RPC zároveň
    // autoritativně dokončí hru, jakmile čas vyprší.
    const refreshStatus = async () => {
      const { data } = await supabase!.rpc('active_games')
      const game = (data ?? []).find((row: any) => row.game_id === gameId)
      if (game) {
        statusRef.current = game.status
        setStatus(game.status)
        setRemaining(game.status === 'running' ? Number(game.remaining_s ?? 0) : null)
      } else {
        statusRef.current = 'finished'
        setStatus('finished')
        setRemaining(null)
        activeBerryMarkersRef.current.forEach((marker) => marker.remove())
        activeBerryMarkersRef.current = []
      }
    }
    void refreshStatus()
    const statusPoll = setInterval(refreshStatus, 1000)
    const worldPoll = setInterval(() => { void refreshSnakeWorld(); void refreshActiveBerries() }, 750)
    return () => { clearInterval(statusPoll); clearInterval(worldPoll); if (channelRef.current) supabase?.removeChannel(channelRef.current); planMarkersRef.current.forEach((marker) => marker.remove()); activeBerryMarkersRef.current.forEach((marker) => marker.remove()); map.remove() }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const loadAll = async (map: maplibregl.Map) => {
    setTimeout(() => map.resize(), 60)
    // Ulice plánu.
    const { data: edges } = await supabase!.from('street_edges').select('geom,enabled').eq('match_id', planId).eq('enabled', true)
    const fc = { type: 'FeatureCollection' as const, features: (edges ?? []).map((r: any) => ({ type: 'Feature' as const, geometry: r.geom, properties: {} })) }
    setSourceData(map, 'streets', fc as any)
    if (fc.features.length) { const [w, s, e, n] = turfBbox(fc as any); map.fitBounds([[w, s], [e, n]], { padding: 30, duration: 0 }) }
    setMapReady(true)
    // Admin vždy vidí všechny herní body - i skryté možné pozice jahůdek.
    const [{ data: respawns }, { data: berryPoints }] = await Promise.all([
      supabase!.from('respawn_points').select('label,geom').eq('match_id', planId),
      supabase!.from('strawberry_points').select('geom').eq('match_id', planId),
    ])
    planMarkersRef.current.forEach((marker) => marker.remove())
    planMarkersRef.current = []
    for (const point of respawns ?? []) {
      const el = document.createElement('div')
      el.textContent = '↻'
      el.title = 'Respawn bod'
      Object.assign(el.style, { background: '#1769aa', color: '#fff', border: '2px solid #fff', borderRadius: '16px', padding: '5px 8px', fontWeight: '700', boxShadow: '0 1px 5px #0008', whiteSpace: 'nowrap' })
      planMarkersRef.current.push(new maplibregl.Marker({ element: el, anchor: 'bottom' }).setLngLat((point as any).geom.coordinates).addTo(map))
    }
    for (const point of berryPoints ?? []) {
      const el = document.createElement('div')
      el.textContent = '🍓'
      el.title = 'Možný spawn jahůdky'
      Object.assign(el.style, { fontSize: '24px', lineHeight: '26px', filter: 'grayscale(1) drop-shadow(0 1px 2px #000)', opacity: '0.9' })
      planMarkersRef.current.push(new maplibregl.Marker({ element: el, anchor: 'center' }).setLngLat((point as any).geom.coordinates).addTo(map))
    }
    // Roster určuje barvy a jména. Ve Snake už nejsou povinné startovní body.
    const { data: r } = await supabase!.rpc('game_roster', { p_game: gameId })
    const rows = (r ?? []) as RosterRow[]
    setRoster(rows)
    colorRef.current = assignColors(rows.map((x) => x.player_id))
    await Promise.all([refreshSnakeWorld(), refreshActiveBerries()])
    renderPlayers()
    // Realtime příjem fyzické/kliknuté polohy slouží hlavně před startem.
    // Během hry se tělo i hlava berou autoritativně ze snake_world.
    const ch = supabase!.channel(`game-${gameId}`)
    ch.on('broadcast', { event: 'pos' }, ({ payload }: any) => {
      if (!payload?.id) return
      // Za běhu je jedinou autoritativní zobrazovanou polohou hlava hada.
      // GPS/klikací poloha hráče by jinak přehazovala marker tam a zpět.
      if (statusRef.current === 'running') return
      let p = playersRef.current.get(payload.id)
      if (!p) { p = { nick: payload.nick ?? '?', trail: [], pos: null, lastSeen: 0 }; playersRef.current.set(payload.id, p) }
      p.pos = payload.pos; p.lastSeen = Date.now()
      renderPlayers()
    })
    ch.on('broadcast', { event: 'eliminated' }, ({ payload }: any) => {
      const p = playersRef.current.get(payload?.id)
      if (p) { p.eliminated = true; p.trail = []; renderPlayers() }
    })
    ch.subscribe()
    channelRef.current = ch
  }

  const refreshActiveBerries = async () => {
    if (!supabase || !mapRef.current) return
    const { data } = await supabase.rpc('active_strawberries', { p_game: gameId })
    activeBerryMarkersRef.current.forEach((marker) => marker.remove())
    activeBerryMarkersRef.current = (data ?? []).map((berry: any) => {
      const el = document.createElement('div')
      el.textContent = '🍓'
      el.title = 'Aktivní jahůdka – vidí ji hráči'
      Object.assign(el.style, { fontSize: '28px', lineHeight: '30px', filter: 'drop-shadow(0 1px 2px #000)', pointerEvents: 'none' })
      return new maplibregl.Marker({ element: el, anchor: 'center' }).setLngLat([berry.lng, berry.lat]).addTo(mapRef.current!)
    })
  }

  const refreshSnakeWorld = async () => {
    if (!supabase || !mapRef.current) return
    const { data } = await supabase.rpc('snake_world', { p_game: gameId })
    for (const row of (data ?? []) as SnakeWorldRow[]) {
      let player = playersRef.current.get(row.player_id)
      if (!player) {
        player = { nick: row.nickname, trail: [], pos: null, lastSeen: 0 }
        playersRef.current.set(row.player_id, player)
      }
      player.nick = row.nickname
      player.eliminated = !row.active
      player.trail = row.active && row.body?.coordinates?.length ? row.body.coordinates : []
      player.pos = row.active && row.head?.coordinates ? row.head.coordinates : null
    }
    renderPlayers()
  }

  const renderPlayers = () => {
    const map = mapRef.current
    if (!map) return
    const trails: Feature[] = []
    playersRef.current.forEach((p, id) => {
      const color = colorRef.current.get(id) ?? colorFor(id)
      if (p.trail.length >= 2) trails.push({ type: 'Feature', geometry: { type: 'LineString', coordinates: p.trail }, properties: { color } })
      // Tečka hráče = HTML marker (spolehlivě viditelná i v overlay mapě).
      if (p.pos) {
        let mk = markersRef.current.get(id)
        if (!mk) {
          const el = document.createElement('div')
          el.className = 'pmark'
          mk = new maplibregl.Marker({ element: el }).setLngLat(p.pos).addTo(map)
          markersRef.current.set(id, mk)
        }
        const el = mk.getElement()
        el.style.background = color
        el.textContent = `${p.nick} · ${trailLenM(p.trail)} m`
        el.style.opacity = p.eliminated ? '0.55' : '1'
        mk.setLngLat(p.pos)
      } else {
        markersRef.current.get(id)?.remove()
        markersRef.current.delete(id)
      }
    })
    setSourceData(map, 'ptrails', { type: 'FeatureCollection', features: trails })
    force((n) => n + 1)
  }

  const start = async () => {
    const { error } = await supabase!.rpc('run_game', { p_game: gameId })
    if (error) return
    statusRef.current = 'running'
    setStatus('running')
    onChanged?.()
  }

  const finish = async () => {
    if (!window.confirm('Opravdu ukončit tuto hru? Hráči uvidí výsledky a hra přejde do historie.')) return
    const { error } = await supabase!.rpc('finish_game', { p_game: gameId })
    if (error) return
    statusRef.current = 'finished'
    setStatus('finished')
    onChanged?.()
  }

  const fmtTime = (seconds: number) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`

  return (
    <div className="spectate">
      <div className="spectate-bar">
        <b>{readOnly ? '👁️ Divák' : 'Sleduj hru'}</b>
        <span className="muted">{status === 'lobby' ? 'čeká v lobby' : status === 'finished' ? 'skončila' : `běží · zbývá ${fmtTime(remaining ?? 0)}`}</span>
        {status === 'lobby' && !readOnly && <button onClick={start}>Spustit hru</button>}
        {status === 'running' && !readOnly && <button className="danger" onClick={finish}>Ukončit hru</button>}
        <button className="ghost" onClick={onClose}>Zavřít</button>
      </div>
      <div id="spectate-map" className="spectate-map" style={{ opacity: mapReady ? 1 : 0 }} />
      <div className="zoom-ctrl">
        <button onClick={() => mapRef.current?.zoomIn()} aria-label="Přiblížit">+</button>
        <button onClick={() => mapRef.current?.zoomOut()} aria-label="Oddálit">−</button>
      </div>
      <div className="spectate-roster">
        {roster.map((x) => {
          const hasPosition = Boolean(playersRef.current.get(x.player_id)?.pos)
          return (
            <span key={x.player_id} className={`pill ${hasPosition ? 'ok' : 'warn'}`}>
              {x.nickname} {hasPosition ? '● poloha přijata' : '· čeká na polohu'}
            </span>
          )
        })}
        {roster.length === 0 && <span className="muted">Zatím nikdo připojený.</span>}
      </div>
    </div>
  )
}
