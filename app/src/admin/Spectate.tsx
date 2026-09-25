import { useEffect, useRef, useState } from 'react'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { bbox as turfBbox } from '@turf/turf'
import { supabase } from '../lib/supabase'
import { MAP_STYLE, BARRANDOV, BARRANDOV_BBOX, emptyFC, setSourceData } from '../lib/geo'
import { startMarkerEl } from '../lib/startMarker'
import { assignColors, colorFor } from '../lib/players'
import { haversineM, trailLenM } from '../lib/collision'
import type { Feature } from 'geojson'

const AT_START_M = 25 // do tolik metrů od svého startu = „na startu"

type RosterRow = { player_id: string; nickname: string; start_lng: number | null; start_lat: number | null; start_label: string | null }
type P = { nick: string; trail: [number, number][]; pos: [number, number] | null; lastSeen: number; eliminated?: boolean }

export default function Spectate({ gameId, planId, status: status0, onClose, onChanged, readOnly }: {
  gameId: string; planId: string; status: string; onClose: () => void; onChanged?: () => void; readOnly?: boolean
}) {
  const mapRef = useRef<maplibregl.Map | null>(null)
  const playersRef = useRef<Map<string, P>>(new Map())
  const markersRef = useRef<Map<string, maplibregl.Marker>>(new Map())
  const colorRef = useRef<Map<string, string>>(new Map())
  const channelRef = useRef<ReturnType<NonNullable<typeof supabase>['channel']> | null>(null)
  const [roster, setRoster] = useState<RosterRow[]>([])
  const [status, setStatus] = useState(status0)
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
      map.fitBounds(BARRANDOV_BBOX, { padding: 30, duration: 0 })
      loadAll(map)
    })
    // Sleduj stav hry (divák uvidí přechod lobby → běží → skončila).
    const statusPoll = setInterval(async () => {
      const { data } = await supabase!.from('games').select('status').eq('id', gameId).single()
      if (data?.status) setStatus(data.status)
    }, 3000)
    return () => { clearInterval(statusPoll); if (channelRef.current) supabase?.removeChannel(channelRef.current); map.remove() }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const loadAll = async (map: maplibregl.Map) => {
    setTimeout(() => map.resize(), 60)
    // Ulice plánu.
    const { data: edges } = await supabase!.from('street_edges').select('geom,enabled').eq('match_id', planId).eq('enabled', true)
    const fc = { type: 'FeatureCollection' as const, features: (edges ?? []).map((r: any) => ({ type: 'Feature' as const, geometry: r.geom, properties: {} })) }
    setSourceData(map, 'streets', fc as any)
    if (fc.features.length) { const [w, s, e, n] = turfBbox(fc as any); map.fitBounds([[w, s], [e, n]], { padding: 30, duration: 0 }) }
    // Všechny startovní body plánu (praporky) – ať admin vidí rozmístění i bez připojených.
    const { data: sp } = await supabase!.from('start_points').select('label,geom').eq('match_id', planId)
    for (const s of sp ?? []) {
      new maplibregl.Marker({ element: startMarkerEl((s as any).label ?? '') }).setLngLat((s as any).geom.coordinates).addTo(map)
    }
    // Roster (pro barvy a kontrolu „kdo je na startu").
    const { data: r } = await supabase!.rpc('game_roster', { p_game: gameId })
    const rows = (r ?? []) as RosterRow[]
    setRoster(rows)
    colorRef.current = assignColors(rows.map((x) => x.player_id))
    // Načti už uložené stopy (à 2 s na server) → divák vidí celou stopu od začátku, ne jen od připojení.
    const { data: saved } = await supabase!.from('game_players').select('player_id, trail').eq('game_id', gameId)
    for (const s of (saved ?? []) as any[]) {
      if (Array.isArray(s.trail) && s.trail.length) {
        const nick = rows.find((x) => x.player_id === s.player_id)?.nickname ?? '?'
        playersRef.current.set(s.player_id, { nick, trail: s.trail, pos: s.trail[s.trail.length - 1], lastSeen: 0 })
      }
    }
    renderPlayers()
    // Realtime příjem poloh.
    const ch = supabase!.channel(`game-${gameId}`)
    ch.on('broadcast', { event: 'pos' }, ({ payload }: any) => {
      if (!payload?.id) return
      let p = playersRef.current.get(payload.id)
      if (!p) { p = { nick: payload.nick ?? '?', trail: [], pos: null, lastSeen: 0 }; playersRef.current.set(payload.id, p) }
      p.pos = payload.pos; p.lastSeen = Date.now()
      if (payload.live && payload.pos && !p.eliminated) {
        const last = p.trail[p.trail.length - 1]
        if (!last || last[0] !== payload.pos[0] || last[1] !== payload.pos[1]) p.trail.push(payload.pos)
      }
      renderPlayers()
    })
    ch.on('broadcast', { event: 'eliminated' }, ({ payload }: any) => {
      const p = playersRef.current.get(payload?.id)
      if (p) { p.eliminated = true; if (Array.isArray(payload.trail)) p.trail = payload.trail; renderPlayers() }
    })
    ch.subscribe()
    channelRef.current = ch
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
      }
    })
    setSourceData(map, 'ptrails', { type: 'FeatureCollection', features: trails })
    force((n) => n + 1) // překresli seznam (stav „na startu")
  }

  // Je hráč u svého startu?
  const atStart = (x: RosterRow): boolean | null => {
    const p = playersRef.current.get(x.player_id)
    if (!p?.pos || x.start_lng == null || x.start_lat == null) return null
    return haversineM(p.pos, [x.start_lng, x.start_lat]) <= AT_START_M
  }

  const start = async () => {
    const notReady = roster.filter((x) => atStart(x) !== true).map((x) => x.nickname)
    if (notReady.length && !window.confirm(`Na startu ještě není: ${notReady.join(', ')}.\nOpravdu spustit hru?`)) return
    const { error } = await supabase!.rpc('run_game', { p_game: gameId })
    if (error) return
    setStatus('running')
    onChanged?.()
  }

  return (
    <div className="spectate">
      <div className="spectate-bar">
        <b>{readOnly ? '👁️ Divák' : 'Sleduj hru'}</b>
        <span className="muted">{status === 'lobby' ? 'čeká v lobby' : status === 'finished' ? 'skončila' : 'běží'}</span>
        {status === 'lobby' && !readOnly && <button onClick={start}>Spustit hru</button>}
        <button className="ghost" onClick={onClose}>Zavřít</button>
      </div>
      <div id="spectate-map" className="spectate-map" />
      <div className="zoom-ctrl">
        <button onClick={() => mapRef.current?.zoomIn()} aria-label="Přiblížit">+</button>
        <button onClick={() => mapRef.current?.zoomOut()} aria-label="Oddálit">−</button>
      </div>
      <div className="spectate-roster">
        {roster.map((x) => {
          const a = atStart(x)
          return (
            <span key={x.player_id} className={`pill ${a === true ? 'ok' : a === false ? 'warn' : ''}`}>
              {x.nickname} {a === true ? '✓ na startu' : a === false ? '✗ nedošel' : '· ?'}
            </span>
          )
        })}
        {roster.length === 0 && <span className="muted">Zatím nikdo připojený.</span>}
      </div>
    </div>
  )
}
