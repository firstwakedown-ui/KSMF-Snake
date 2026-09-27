import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { bbox as turfBbox } from '@turf/turf'
import { supabase } from '../lib/supabase'
import { BARRANDOV, BARRANDOV_BBOX, MAP_STYLE, emptyFC, lineFC, pointsFC, setSourceData } from '../lib/geo'
import VersionBadge from './VersionBadge'
import { fetchStreetsInPolygon } from '../lib/overpass'
import { startMarkerEl } from '../lib/startMarker'
import AdminLogin, { isAdminUnlocked } from '../admin/AdminLogin'
import Spectate from '../admin/Spectate'
import TrailsImage from './TrailsImage'
import { loadGameResults, type ResultRow } from '../lib/results'

type Section = 'plans' | 'manage'
type Mode = 'area' | 'streets' | 'connect' | 'respawns' | 'berries'

type Match = {
  id: string
  name: string | null
  area: any | null // GeoJSON Polygon | null
  is_active: boolean
  ready: boolean
  footpaths_enabled: boolean
  idle_timeout_s: number
  outside_timeout_s: number
  snap_tolerance_m: number
  walk_speed_mps: number
  run_speed_mps: number
  sprint_speed_mps: number
  sprint_range_m: number
  snake_initial_length_m: number
  strawberry_growth_m: number
  game_duration_s: number
  snake_speed_mps: number
  strawberry_spawn_min_s: number
  strawberry_spawn_max_s: number
  strawberry_active_percent: number
  strawberry_initial_percent: number
  max_lead_m: number
  respawn_countdown_s: number
  self_collision_grace_m: number
}
type Plan = { id: string; name: string | null; is_active: boolean }
type Code = { id: string; code: string; active: boolean }
type Account = { id: string; nickname: string; created_at: string }
type Game = { game_id: string; game_name: string; plan_id: string; plan_name: string | null; status: string; capacity: number; joined: number; sim: boolean; run_mode: boolean; remaining_s: number | null }
type GameMode = 'realtime' | 'sim' | 'run'
type FinishedGame = { game_id: string; game_name: string; plan_id: string; plan_name: string | null; players: number; started_at: string | null; finished_at: string | null }
type ReadyPlan = { id: string; name: string | null; starts: number }
type Edge = { id: number; name: string | null; enabled: boolean; is_foot: boolean; geom: any }
type Start = { id: string; label: string; coord: [number, number] }
type MapPoint = { id: string; label: string; coord: [number, number] }

const MATCH_COLS = 'id,name,area,is_active,ready,footpaths_enabled,idle_timeout_s,outside_timeout_s,snap_tolerance_m,walk_speed_mps,run_speed_mps,sprint_speed_mps,sprint_range_m,snake_initial_length_m,strawberry_growth_m,game_duration_s,snake_speed_mps,strawberry_spawn_min_s,strawberry_spawn_max_s,strawberry_active_percent,strawberry_initial_percent,max_lead_m,respawn_countdown_s,self_collision_grace_m'

const MODE_LABEL: Record<Mode, string> = {
  area: 'Oblast',
  streets: 'Ulice',
  connect: 'Spojnice',
  respawns: 'Respawny',
  berries: 'Jahůdky',
}
const MODE_HINT: Record<Mode, string> = {
  area: 'Klikáním obkresli území (min. 3 body), pak „Najít ulice v oblasti". Ulice uvnitř = oranžové, okolí = šedé.',
  streets: 'Klik na cestu (silnice oranžová / chodník žlutý) ji zařadí/vyřadí ze hry. Šedá = mimo hru, hráč ji nevidí.',
  connect: 'Ruční spojnice: klikni 1. a 2. bod → vznikne rovná čára (cesta navíc). Opakuj pro další.',
  respawns: 'Klik do mapy = nový respawn · táhni bod = přesuň · dvojklik = smazat.',
  berries: 'Klik do mapy = nový skrytý jahůdkový bod · dvojklik na bod = smazat.',
}

export default function AdminView() {
  const [unlocked, setUnlocked] = useState(isAdminUnlocked())
  if (!unlocked) return <AdminLogin onUnlock={() => setUnlocked(true)} />
  return <AdminBoard />
}

function AdminBoard() {
  const mapRef = useRef<maplibregl.Map | null>(null)
  const modeRef = useRef<Mode>('area')
  const matchRef = useRef<Match | null>(null)
  const edgesRef = useRef<Edge[]>([])
  const startsRef = useRef<Start[]>([])
  const areaDraftRef = useRef<[number, number][]>([])
  const startMarkersRef = useRef<maplibregl.Marker[]>([])
  const berryMarkersRef = useRef<maplibregl.Marker[]>([])
  const berriesRef = useRef<MapPoint[]>([])
  const connectFirstRef = useRef<[number, number] | null>(null)
  const connectMarkerRef = useRef<maplibregl.Marker | null>(null)

  const [section, setSection] = useState<Section>('manage')
  const [mode, setMode] = useState<Mode>('area')
  const [plans, setPlans] = useState<Plan[]>([])
  const [codes, setCodes] = useState<Code[]>([])
  const [accounts, setAccounts] = useState<Account[]>([])
  const [games, setGames] = useState<Game[]>([])
  const [finished, setFinished] = useState<FinishedGame[]>([])
  const [readyPlans, setReadyPlans] = useState<ReadyPlan[]>([])
  const [newGamePlan, setNewGamePlan] = useState('')
  const [newGameName, setNewGameName] = useState('')
  const [newGameCap, setNewGameCap] = useState(5)
  const [newGameMode, setNewGameMode] = useState<GameMode>('realtime')
  const [spectate, setSpectate] = useState<Game | null>(null)
  const [resultsModal, setResultsModal] = useState<{ name: string; rows: ResultRow[]; streets: [number, number][][] } | null>(null)
  const [match, setMatch] = useState<Match | null>(null)
  const [edgeCount, setEdgeCount] = useState<{ on: number; off: number }>({ on: 0, off: 0 })
  const [startCount, setStartCount] = useState(0)
  const [berryPointCount, setBerryPointCount] = useState(0)
  const [draftLen, setDraftLen] = useState(0)
  const [hasArea, setHasArea] = useState(false)
  const [busy, setBusy] = useState(false)
  const [footEnabled, setFootEnabled] = useState(true)
  const [connectAsFoot, setConnectAsFoot] = useState(false)
  const [status, setStatus] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [idle, setIdle] = useState(30)
  const [outside, setOutside] = useState(30)
  const [tol, setTol] = useState(30)
  const [walkMps, setWalkMps] = useState(3.6)
  const [runMps, setRunMps] = useState(7.5)
  const [sprintMps, setSprintMps] = useState(12.0)
  const [sprintRange, setSprintRange] = useState(200)
  const [snakeLength, setSnakeLength] = useState(10)
  const [berryGrowth, setBerryGrowth] = useState(10)
  const [gameMinutes, setGameMinutes] = useState(15)
  const [snakeKmh, setSnakeKmh] = useState(3)
  const [berryMin, setBerryMin] = useState(10)
  const [berryMax, setBerryMax] = useState(60)
  const [berryActivePercent, setBerryActivePercent] = useState(100)
  const [berryInitialPercent, setBerryInitialPercent] = useState(33)
  const [maxLead, setMaxLead] = useState(100)
  const [respawnSeconds, setRespawnSeconds] = useState(3)
  const [selfCollisionGrace, setSelfCollisionGrace] = useState(10)

  const setModeBoth = (m: Mode) => {
    if (modeRef.current === 'connect' && m !== 'connect') clearConnectPending()
    modeRef.current = m
    setMode(m)
    setStatus(MODE_HINT[m])
  }
  const clearConnectPending = () => {
    connectFirstRef.current = null
    connectMarkerRef.current?.remove()
    connectMarkerRef.current = null
  }

  // --- Inicializace mapy + vrstvy ---
  useEffect(() => {
    if (!supabase) {
      setError('Bez Supabase (.env) – admin nemůže nic načíst ani uložit.')
      return
    }
    const map = new maplibregl.Map({ container: 'map', style: MAP_STYLE, center: BARRANDOV, zoom: 15 })
    mapRef.current = map

    map.on('load', () => {
      // Oblast (uložený polygon).
      map.addSource('area', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'area-fill', type: 'fill', source: 'area', paint: { 'fill-color': '#58a6ff', 'fill-opacity': 0.12 } })
      map.addLayer({ id: 'area-line', type: 'line', source: 'area', paint: { 'line-color': '#58a6ff', 'line-width': 2 } })
      // Rozkreslená oblast (draft).
      map.addSource('area-draft', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'area-draft-line', type: 'line', source: 'area-draft', paint: { 'line-color': '#58a6ff', 'line-width': 2, 'line-dasharray': [2, 1] } })
      map.addSource('area-draft-pts', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'area-draft-circle', type: 'circle', source: 'area-draft-pts', paint: { 'circle-radius': 5, 'circle-color': '#58a6ff', 'circle-stroke-color': '#fff', 'circle-stroke-width': 2 } })
      // Ulice: v plánu = oranžová (chodník světlejší), mimo plán = šedá.
      map.addSource('streets', { type: 'geojson', data: emptyFC() })
      map.addLayer({
        id: 'streets-line',
        type: 'line',
        source: 'streets',
        paint: {
          // Chodník vždy žlutý (admin s ním pracuje nehledě na přepínač), silnice oranžová,
          // individuálně vyřazená (enabled=false) šedá. Ztlumení = není zrovna „v plánu".
          'line-color': [
            'case',
            ['!', ['get', 'enabled']], '#6e7681',
            ['get', 'is_foot'], '#fbbf24',
            '#f59e0b',
          ],
          'line-width': 4,
          'line-opacity': ['case', ['get', 'inplay'], 0.85, 0.4],
        },
      })
      // (Startovní body jsou HTML markery – řeší syncStartMarkers.)

      map.on('click', onMapClick)
      map.on('mousemove', (e) => {
        const m = modeRef.current
        if (m === 'area' || m === 'connect' || m === 'respawns' || m === 'berries') {
          map.getCanvas().style.cursor = 'crosshair'
        } else if (m === 'streets') {
          const hit = map.queryRenderedFeatures(e.point, { layers: ['streets-line'] }).length > 0
          map.getCanvas().style.cursor = hit ? 'pointer' : ''
        } else {
          map.getCanvas().style.cursor = ''
        }
      })

      init()
      map.fitBounds(BARRANDOV_BBOX, { padding: 40, duration: 0 })
    })

    return () => map.remove()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // --- Start: načti plány, vyber editovaný (aktivní/první), případně založ první ---
  const init = async () => {
    try {
      loadCodes()
      loadAccounts()
      loadGames()
      let list = await loadPlans()
      if (!list.length) {
        const { data: ins, error: e } = await supabase!.from('matches').insert({ name: 'Plán 1', is_active: true }).select(MATCH_COLS).single()
        if (e) throw e
        await loadPlans()
        await loadPlanData((ins as Match).id)
      } else {
        const editing = list.find((p) => p.is_active) ?? list[0]
        await loadPlanData(editing.id)
      }
    } catch (e: any) {
      setError(`Načtení: ${e.message ?? e}`)
    }
  }

  const loadPlans = async (): Promise<Plan[]> => {
    const { data, error: e } = await supabase!.from('matches').select('id,name,is_active').order('created_at', { ascending: true })
    if (e) throw e
    const list = (data ?? []) as Plan[]
    setPlans(list)
    return list
  }

  // --- Přístupové kódy (registrace hráčů) ---
  const loadCodes = async () => {
    const { data } = await supabase!.from('access_codes').select('id,code,active').order('created_at', { ascending: false })
    setCodes((data ?? []) as Code[])
  }
  const genCode = async () => {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' // bez matoucích 0/O/1/I
    let code = ''
    for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)]
    const { error: e } = await supabase!.from('access_codes').insert({ code })
    if (e) { setError(`Kód: ${e.message}`); return }
    await loadCodes()
    setStatus(`Nový kód: ${code} — řekni ho hráčům.`)
  }
  const toggleCode = async (c: Code) => {
    const { error: e } = await supabase!.from('access_codes').update({ active: !c.active }).eq('id', c.id)
    if (e) { setError(`Kód: ${e.message}`); return }
    await loadCodes()
  }
  const copyCode = async (code: string) => {
    try {
      await navigator.clipboard.writeText(code)
    } catch {
      // Fallback pro prohlížeče bez Clipboard API.
      const ta = document.createElement('textarea')
      ta.value = code
      document.body.appendChild(ta)
      ta.select()
      try { document.execCommand('copy') } catch {}
      document.body.removeChild(ta)
    }
    setStatus(`Kód ${code} zkopírován do schránky.`)
  }
  const deleteCode = async (c: Code) => {
    if (!window.confirm(`Smazat přístupový kód ${c.code}?`)) return
    const { error: e } = await supabase!.from('access_codes').delete().eq('id', c.id)
    if (e) { setError(`Kód: ${e.message}`); return }
    await loadCodes()
    setStatus(`Kód ${c.code} smazán.`)
  }

  // --- Hráči (účty) ---
  const loadAccounts = async () => {
    const { data } = await supabase!.from('players').select('id,nickname,created_at').order('created_at', { ascending: true })
    setAccounts((data ?? []) as Account[])
  }
  const deleteAccount = async (a: Account) => {
    if (!window.confirm(`Smazat hráče „${a.nickname}"? Bude se muset zaregistrovat znovu.`)) return
    const { error: e } = await supabase!.from('players').delete().eq('id', a.id)
    if (e) { setError(`Hráč: ${e.message}`); return }
    await loadAccounts()
    setStatus(`Hráč „${a.nickname}" smazán.`)
  }

  // Načte data jednoho plánu (oblast, ulice, starty, nastavení) a vykreslí.
  const loadPlanData = async (planId: string) => {
    const { data: m, error: e1 } = await supabase!.from('matches').select(MATCH_COLS).eq('id', planId).single()
    if (e1) throw e1
    const mt = m as Match
    matchRef.current = mt
    setMatch(mt)
    setIdle(mt.idle_timeout_s)
    setOutside(mt.outside_timeout_s)
    setTol(mt.snap_tolerance_m)
    setWalkMps(Number(mt.walk_speed_mps))
    setRunMps(Number(mt.run_speed_mps))
    setSprintMps(Number(mt.sprint_speed_mps))
    setSprintRange(mt.sprint_range_m)
    setSnakeLength(Number(mt.snake_initial_length_m))
    setBerryGrowth(Number(mt.strawberry_growth_m))
    setGameMinutes(Math.round(mt.game_duration_s / 60))
    setSnakeKmh(Math.round(Number(mt.snake_speed_mps) * 36) / 10)
    setBerryMin(mt.strawberry_spawn_min_s)
    setBerryMax(mt.strawberry_spawn_max_s)
    setBerryActivePercent(mt.strawberry_active_percent ?? 100)
    setBerryInitialPercent(mt.strawberry_initial_percent ?? 33)
    setMaxLead(Number(mt.max_lead_m))
    setRespawnSeconds(mt.respawn_countdown_s)
    setSelfCollisionGrace(Number(mt.self_collision_grace_m ?? 10))
    setFootEnabled(mt.footpaths_enabled)
    applyArea(mt.area)
    areaDraftRef.current = []
    refreshDraft()
    clearConnectPending()

    const { data: edges, error: e3 } = await supabase!.from('street_edges').select('id,name,enabled,is_foot,geom').eq('match_id', planId)
    if (e3) throw e3
    edgesRef.current = (edges ?? []) as Edge[]
    refreshStreets()

    const { data: sp, error: e4 } = await supabase!.from('respawn_points').select('id,label,geom').eq('match_id', planId)
    if (e4) throw e4
    startsRef.current = (sp ?? []).map((r: any) => ({ id: r.id, label: r.label ?? '', coord: r.geom.coordinates as [number, number] }))
    refreshStarts()
    const { data: bp, error: e5 } = await supabase!.from('strawberry_points').select('id,geom').eq('match_id', planId)
    if (e5) throw e5
    berriesRef.current = (bp ?? []).map((r: any, i) => ({ id: r.id, label: `J${i + 1}`, coord: r.geom.coordinates as [number, number] }))
    setBerryPointCount(berriesRef.current.length)
    refreshBerries()

    fitToData()
  }

  // Naroamuje mapu podle dat (ulice nebo oblast) – funguje kdekoli, ne jen Barrandov.
  const fitToData = () => {
    const map = mapRef.current
    if (!map) return
    const feats = edgesRef.current.map((ed) => ({ type: 'Feature' as const, geometry: ed.geom, properties: {} }))
    const mt = matchRef.current
    if (mt?.area?.coordinates) feats.push({ type: 'Feature', geometry: mt.area, properties: {} })
    if (!feats.length) {
      map.fitBounds(BARRANDOV_BBOX, { padding: 40, duration: 0 })
      return
    }
    const [w, s, e, n] = turfBbox({ type: 'FeatureCollection', features: feats })
    map.fitBounds([[w, s], [e, n]], { padding: 40, duration: 0 })
  }

  // "V plánu pro hru" = hrana je zapnutá (enabled). Platí stejně pro silnice i chodníky –
  // o zařazení rozhoduje per-hrana, ne globální přepínač.
  const isInPlay = (ed: Edge) => ed.enabled

  // --- Vykreslení vrstev z refs ---
  const refreshStreets = () => {
    const fc = {
      type: 'FeatureCollection' as const,
      features: edgesRef.current.map((ed) => ({
        type: 'Feature' as const,
        geometry: ed.geom,
        properties: { id: ed.id, name: ed.name, enabled: ed.enabled, is_foot: ed.is_foot, inplay: isInPlay(ed) },
      })),
    }
    setSourceData(mapRef.current, 'streets', fc)
    const on = edgesRef.current.filter(isInPlay).length
    setEdgeCount({ on, off: edgesRef.current.length - on })
  }
  // Startovní body jako HTML markery (drag = přesun, dvojklik = smazat).
  const syncStartMarkers = () => {
    const map = mapRef.current
    if (!map) return
    startMarkersRef.current.forEach((mk) => mk.remove())
    startMarkersRef.current = []
    for (const s of startsRef.current) {
      const el = startMarkerEl(s.label)
      const mk = new maplibregl.Marker({ element: el, draggable: true }).setLngLat(s.coord).addTo(map)
      mk.on('dragend', async () => {
        const ll = mk.getLngLat()
        s.coord = [ll.lng, ll.lat]
        const { error: err } = await supabase!.rpc('move_respawn_point', { p_id: s.id, p_lng: ll.lng, p_lat: ll.lat })
        if (err) setError(`Přesun startu: ${err.message}`)
        else setStatus(`Start ${s.label} přesunut.`)
      })
      el.addEventListener('dblclick', (ev) => {
        ev.stopPropagation()
        removeStart(s.id)
      })
      startMarkersRef.current.push(mk)
    }
  }
  const refreshStarts = () => {
    syncStartMarkers()
    setStartCount(startsRef.current.length)
  }
  const refreshBerries = () => {
    const map = mapRef.current
    if (!map) return
    berryMarkersRef.current.forEach((m) => m.remove())
    berryMarkersRef.current = berriesRef.current.map((b) => {
      const el = document.createElement('div')
      el.textContent = '🍓'; el.style.fontSize = '22px'; el.style.cursor = 'pointer'
      el.title = `${b.label} – skrytý spawn jahůdky`
      el.addEventListener('dblclick', async (ev) => { ev.stopPropagation(); await removeBerry(b.id) })
      return new maplibregl.Marker({ element: el }).setLngLat(b.coord).addTo(map)
    })
  }
  const refreshDraft = () => {
    const pts = areaDraftRef.current
    setSourceData(mapRef.current, 'area-draft', pts.length >= 2 ? lineFC(pts) : emptyFC())
    setSourceData(mapRef.current, 'area-draft-pts', pointsFC(pts.map((c, i) => ({ id: String(i), label: '', coord: c }))))
    setDraftLen(pts.length)
  }
  const applyArea = (area: any | null) => {
    const data = area && area.coordinates ? { type: 'Feature' as const, geometry: area, properties: {} } : emptyFC()
    setSourceData(mapRef.current, 'area', data as any)
    setHasArea(!!(area && area.coordinates))
  }

  // --- Klik na mapu (podle režimu) ---
  const onMapClick = async (e: maplibregl.MapMouseEvent) => {
    const map = mapRef.current!
    const m = modeRef.current
    if (m === 'streets') {
      const f = map.queryRenderedFeatures(e.point, { layers: ['streets-line'] })[0]
      if (!f) return
      const id = f.properties?.id as number
      const ed = edgesRef.current.find((x) => x.id === id)
      if (!ed) return
      const next = !ed.enabled
      ed.enabled = next
      refreshStreets()
      const { error: err } = await supabase!.from('street_edges').update({ enabled: next }).eq('id', id)
      if (err) {
        ed.enabled = !next
        refreshStreets()
        setError(`Uložení ulice: ${err.message}`)
      } else {
        setStatus(`Ulice „${ed.name ?? '—'}" ${next ? 'vrácena do plánu' : 'vyřazena'}.`)
      }
    } else if (m === 'area') {
      areaDraftRef.current.push([e.lngLat.lng, e.lngLat.lat])
      refreshDraft()
    } else if (m === 'connect') {
      await onConnectClick(map, [e.lngLat.lng, e.lngLat.lat])
    } else if (m === 'respawns') {
      // Klik blízko existujícího startu nepřidává nový (mazání = dvojklik na praporek).
      const near = startsRef.current.some((s) => {
        const sp = map.project(s.coord)
        return (sp.x - e.point.x) ** 2 + (sp.y - e.point.y) ** 2 < 24 * 24
      })
      if (near) return
      await addStart(e.lngLat.lng, e.lngLat.lat)
    } else if (m === 'berries') {
      const near = berriesRef.current.some((b) => { const p = map.project(b.coord); return (p.x-e.point.x)**2+(p.y-e.point.y)**2 < 24*24 })
      if (!near) await addBerry(e.lngLat.lng, e.lngLat.lat)
    }
  }

  const onConnectClick = async (map: maplibregl.Map, pt: [number, number]) => {
    if (!connectFirstRef.current) {
      connectFirstRef.current = pt
      connectMarkerRef.current = new maplibregl.Marker({ color: '#58a6ff' }).setLngLat(pt).addTo(map)
      setStatus('Klikni druhý bod spojnice.')
      return
    }
    const a = connectFirstRef.current
    const mid = matchRef.current!.id
    const asFoot = connectAsFoot
    const { data, error: err } = await supabase!.rpc('add_manual_edge', { p_match: mid, p_a_lng: a[0], p_a_lat: a[1], p_b_lng: pt[0], p_b_lat: pt[1], p_is_foot: asFoot })
    if (err) {
      setError(`Spojnice: ${err.message}`)
    } else {
      edgesRef.current.push({ id: data as number, name: null, enabled: true, is_foot: asFoot, geom: { type: 'LineString', coordinates: [a, pt] } })
      refreshStreets()
      setStatus(`Ruční ${asFoot ? 'chodník' : 'spojnice'} přidán. Klikni další dva body, nebo přepni režim.`)
    }
    clearConnectPending()
  }

  const startNum = (l: string) => parseInt(l.replace(/\D/g, ''), 10) || 0
  const addStart = async (lng: number, lat: number) => {
    const mt = matchRef.current
    if (!mt) return
    const maxN = startsRef.current.reduce((m, s) => Math.max(m, startNum(s.label)), 0)
    const label = `R${maxN + 1}`
    const { data, error: err } = await supabase!.rpc('add_respawn_point', { p_match: mt.id, p_label: label, p_lng: lng, p_lat: lat })
    if (err) {
      setError(`Přidání startu: ${err.message}`)
      return
    }
    startsRef.current.push({ id: data as string, label, coord: [lng, lat] })
    refreshStarts()
    setStatus(`Start ${label} přidán.`)
  }
  const removeStart = async (id: string) => {
    const { error: err } = await supabase!.rpc('remove_respawn_point', { p_id: id })
    if (err) {
      setError(`Mazání startu: ${err.message}`)
      return
    }
    startsRef.current = startsRef.current.filter((s) => s.id !== id)
    // Přečíslovat zbývající starty na S1..Sn (podle pořadí).
    const ordered = [...startsRef.current].sort((a, b) => startNum(a.label) - startNum(b.label))
    for (let i = 0; i < ordered.length; i++) {
      const want = `R${i + 1}`
      if (ordered[i].label !== want) {
        ordered[i].label = want
      }
    }
    startsRef.current = ordered
    refreshStarts()
    setStatus('Startovní bod smazán a přečíslováno.')
  }
  const clearStarts = async () => {
    if (!startsRef.current.length) return
    if (!window.confirm('Smazat všechny startovní body tohoto plánu?')) return
    const { error: err } = await supabase!.rpc('clear_respawn_points', { p_match: matchRef.current!.id })
    if (err) {
      setError(`Mazání startů: ${err.message}`)
      return
    }
    startsRef.current = []
    refreshStarts()
    setStatus('Všechny starty smazány.')
  }
  const addBerry = async (lng: number, lat: number) => {
    const mt = matchRef.current; if (!mt) return
    const { data, error: err } = await supabase!.rpc('add_strawberry_point', { p_match: mt.id, p_lng: lng, p_lat: lat })
    if (err) { setError(`Jahůdkový bod: ${err.message}`); return }
    berriesRef.current.push({ id: data as string, label: `J${berriesRef.current.length + 1}`, coord: [lng, lat] }); setBerryPointCount(berriesRef.current.length); refreshBerries(); setStatus('Jahůdkový bod přidán.')
  }
  const removeBerry = async (id: string) => {
    const { error: err } = await supabase!.rpc('remove_strawberry_point', { p_id: id })
    if (err) { setError(`Mazání jahůdkového bodu: ${err.message}`); return }
    berriesRef.current = berriesRef.current.filter((b) => b.id !== id); setBerryPointCount(berriesRef.current.length); refreshBerries(); setStatus('Jahůdkový bod smazán.')
  }
  const clearBerries = async () => {
    const mt = matchRef.current
    if (!mt || !berriesRef.current.length) return
    if (!window.confirm(`Smazat všech ${berriesRef.current.length} jahůdkových bodů z plánu „${mt.name ?? ''}"?`)) return
    const { error: err } = await supabase!.from('strawberry_points').delete().eq('match_id', mt.id)
    if (err) { setError(`Mazání jahůdkových bodů: ${err.message}`); return }
    berriesRef.current = []
    setBerryPointCount(0)
    refreshBerries()
    setStatus('Všechny jahůdkové body z plánu byly smazány.')
  }

  // --- Chodníky: HROMADNÉ zapnutí/vypnutí všech chodníků (jen pohodlí; jednotlivě jdou klikat v Ulicích) ---
  const toggleFootpaths = async (val: boolean) => {
    const mt = matchRef.current
    if (!mt) return
    const footCount = edgesRef.current.filter((e) => e.is_foot).length
    if (!footCount) {
      setError('V plánu nejsou žádné chodníky – nejdřív „Doplnit chodníky" v režimu Oblast.')
      return
    }
    edgesRef.current.forEach((e) => { if (e.is_foot) e.enabled = val })
    setFootEnabled(val)
    matchRef.current = { ...mt, footpaths_enabled: val }
    setMatch(matchRef.current)
    refreshStreets()
    const { error: err } = await supabase!.from('street_edges').update({ enabled: val }).eq('match_id', mt.id).eq('is_foot', true)
    if (err) {
      setError(`Chodníky: ${err.message}`)
      return
    }
    await supabase!.from('matches').update({ footpaths_enabled: val }).eq('id', mt.id)
    setStatus(val ? `Všech ${footCount} chodníků zapnuto do hry.` : `Všech ${footCount} chodníků vypnuto (jednotlivě je dál zapínáš klikáním).`)
  }

  // Rozdělit cesty v průsečících (noding) – úseky mezi křižovatkami pak jdou zapínat/vypínat zvlášť.
  const splitEdges = async () => {
    const mt = matchRef.current
    if (!mt) return
    if (!edgesRef.current.length) {
      setError('V plánu nejsou žádné cesty k rozdělení.')
      return
    }
    if (!window.confirm('Rozdělit cesty v křižovatkách? Každá cesta se rozseká tam, kde ji kříží jiná – úseky pak jdou zapínat/vypínat zvlášť.')) return
    setBusy(true)
    setStatus('Rozděluji cesty v křižovatkách…')
    try {
      const { data, error: e } = await supabase!.rpc('split_match_edges', { p_match: mt.id })
      if (e) throw e
      const { data: edges, error: e3 } = await supabase!.from('street_edges').select('id,name,enabled,is_foot,geom').eq('match_id', mt.id)
      if (e3) throw e3
      edgesRef.current = (edges ?? []) as Edge[]
      refreshStreets()
      setStatus(`Hotovo: ${data} úseků. Klikáním teď zapínáš/vypínáš jednotlivé úseky.`)
    } catch (e: any) {
      setError(`Rozdělení: ${e.message ?? e}`)
    } finally {
      setBusy(false)
    }
  }

  // --- Oblast: najít ulice v OSM / znovu načíst / zrušit kreslení / vymazat obsah plánu ---
  // Společné jádro: stáhne ulice+chodníky pro polygon a uloží je do plánu (nahradí stávající).
  const runStreetFetch = async (poly: [number, number][], saveArea: boolean) => {
    setError(null)
    setBusy(true)
    setStatus('Hledám ulice + chodníky v OSM (Overpass)…')
    try {
      const streets = await fetchStreetsInPolygon(poly)
      if (!streets.length) {
        setStatus('V této oblasti se nenašly žádné ulice. Zkus jiné/větší území.')
        setBusy(false)
        return
      }
      const mid = matchRef.current!.id
      if (saveArea) {
        const ring = [...poly, poly[0]]
        const polygon = { type: 'Polygon', coordinates: [ring] }
        const { error: ea } = await supabase!.rpc('set_match_area', { p_match: mid, p_geojson: polygon })
        if (ea) throw ea
        applyArea(polygon)
        areaDraftRef.current = []
        refreshDraft()
      }
      const { error: es } = await supabase!.rpc('set_area_streets', { p_match: mid, p_streets: streets })
      if (es) throw es
      // Auto-rozdělení v křižovatkách (úseky pak jdou upravovat jednotlivě).
      await supabase!.rpc('split_match_edges', { p_match: mid })

      const { data: edges, error: e3 } = await supabase!.from('street_edges').select('id,name,enabled,is_foot,geom').eq('match_id', mid)
      if (e3) throw e3
      edgesRef.current = (edges ?? []) as Edge[]
      refreshStreets()
      fitToData()
      const drive = streets.filter((s) => !s.is_foot).length
      setStatus(`Hotovo: ${streets.length} cest (${drive} silnic, ${streets.length - drive} chodníků). Přepni na „Ulice" a uprav.`)
    } catch (e: any) {
      setError(`Hledání ulic: ${e.message ?? e}`)
    } finally {
      setBusy(false)
    }
  }
  const findStreets = async () => {
    const pts = areaDraftRef.current
    if (pts.length < 3) {
      setError('Oblast potřebuje aspoň 3 vrcholy.')
      return
    }
    await runStreetFetch(pts, true)
  }
  // Znovu načíst z ULOŽENÉ oblasti plánu (bez překreslování) – např. aby se doplnily chodníky.
  const reloadStreets = async () => {
    const area = matchRef.current?.area
    if (!area?.coordinates) {
      setError('Tento plán nemá uloženou oblast – nakresli ji v režimu Oblast.')
      return
    }
    if (!window.confirm('Znovu načíst ulice + chodníky z OSM pro uloženou oblast? Přepíše to ruční úpravy ulic a ruční spojnice tohoto plánu.')) return
    const ring = (area.coordinates[0] as [number, number][])
    await runStreetFetch(ring, false)
  }
  // Nedestruktivně doplní chodníky do plánu (silnice a ruční spojnice nechá být).
  const addFootpaths = async () => {
    const area = matchRef.current?.area
    if (!area?.coordinates) {
      setError('Tento plán nemá uloženou oblast – nakresli ji v režimu Oblast.')
      return
    }
    setError(null)
    setBusy(true)
    setStatus('Stahuji chodníky z OSM…')
    try {
      const all = await fetchStreetsInPolygon(area.coordinates[0] as [number, number][])
      const foot = all.filter((s) => s.is_foot)
      if (!foot.length) {
        setStatus('V oblasti se nenašly žádné chodníky mezi domy.')
        setBusy(false)
        return
      }
      const mid = matchRef.current!.id
      const { error: e } = await supabase!.rpc('add_area_footpaths', { p_match: mid, p_streets: foot })
      if (e) throw e
      // Auto-rozdělení v křižovatkách (i nové chodníky se rozsekají v křížení).
      await supabase!.rpc('split_match_edges', { p_match: mid })
      // Ať jsou hned vidět, zapni chodníky v plánu.
      if (!matchRef.current!.footpaths_enabled) {
        await supabase!.from('matches').update({ footpaths_enabled: true }).eq('id', mid)
        matchRef.current = { ...matchRef.current!, footpaths_enabled: true }
        setMatch(matchRef.current)
        setFootEnabled(true)
      }
      const { data: edges, error: e3 } = await supabase!.from('street_edges').select('id,name,enabled,is_foot,geom').eq('match_id', mid)
      if (e3) throw e3
      edgesRef.current = (edges ?? []) as Edge[]
      refreshStreets()
      setStatus(`Doplněno ${foot.length} chodníků (žluté). Přepínačem je zap./vyp. pro hru.`)
    } catch (e: any) {
      setError(`Doplnění chodníků: ${e.message ?? e}`)
    } finally {
      setBusy(false)
    }
  }
  const cancelDraft = () => {
    areaDraftRef.current = []
    refreshDraft()
    setStatus('Kreslení zrušeno.')
  }
  const clearPlan = async () => {
    if (!window.confirm('Smazat obsah tohoto plánu (ulice + oblast + starty)?')) return
    setBusy(true)
    try {
      const { error: err } = await supabase!.rpc('clear_match_plan', { p_match: matchRef.current!.id })
      if (err) throw err
      edgesRef.current = []
      startsRef.current = []
      areaDraftRef.current = []
      refreshStreets()
      refreshStarts()
      refreshDraft()
      applyArea(null)
      setStatus('Obsah plánu smazán. Nakresli novou oblast a najdi ulice.')
    } catch (e: any) {
      setError(`Mazání plánu: ${e.message ?? e}`)
    } finally {
      setBusy(false)
    }
  }

  // --- Plány: výběr / nový / přejmenovat / smazat / aktivní pro hru ---
  const selectPlan = async (id: string) => {
    if (id === matchRef.current?.id) return
    try {
      await loadPlanData(id)
      const p = plans.find((x) => x.id === id)
      setStatus(`Edituješ plán „${p?.name ?? id.slice(0, 8)}".`)
    } catch (e: any) {
      setError(`Přepnutí plánu: ${e.message ?? e}`)
    }
  }
  const newPlan = async () => {
    const name = window.prompt('Název nového plánu:', `Plán ${plans.length + 1}`)
    if (name == null) return
    try {
      const { data: ins, error: e } = await supabase!.from('matches').insert({ name: name.trim() || `Plán ${plans.length + 1}` }).select(MATCH_COLS).single()
      if (e) throw e
      await loadPlans()
      await loadPlanData((ins as Match).id)
      setStatus(`Nový plán „${(ins as Match).name}". Přepni na „Oblast" a nakresli území.`)
    } catch (e: any) {
      setError(`Nový plán: ${e.message ?? e}`)
    }
  }
  const renamePlan = async () => {
    const mt = matchRef.current
    if (!mt) return
    const name = window.prompt('Přejmenovat plán:', mt.name ?? '')
    if (name == null) return
    try {
      const { error: e } = await supabase!.from('matches').update({ name: name.trim() }).eq('id', mt.id)
      if (e) throw e
      matchRef.current = { ...mt, name: name.trim() }
      setMatch(matchRef.current)
      await loadPlans()
      setStatus('Plán přejmenován.')
    } catch (e: any) {
      setError(`Přejmenování: ${e.message ?? e}`)
    }
  }
  const deletePlan = async () => {
    const mt = matchRef.current
    if (!mt) return
    if (!window.confirm(`Smazat celý plán „${mt.name ?? ''}" včetně ulic a startů?`)) return
    try {
      const { error: e } = await supabase!.from('matches').delete().eq('id', mt.id)
      if (e) throw e
      const list = await loadPlans()
      if (list.length) {
        await loadPlanData((list.find((p) => p.is_active) ?? list[0]).id)
      } else {
        const { data: ins } = await supabase!.from('matches').insert({ name: 'Plán 1', is_active: true }).select(MATCH_COLS).single()
        await loadPlans()
        if (ins) await loadPlanData((ins as Match).id)
      }
      setStatus('Plán smazán.')
    } catch (e: any) {
      setError(`Mazání plánu: ${e.message ?? e}`)
    }
  }
  // --- Hry (instance plánů) ---
  const loadGames = async () => {
    const { data } = await supabase!.rpc('active_games')
    setGames((data ?? []) as Game[])
    const { data: f } = await supabase!.rpc('finished_games')
    setFinished((f ?? []) as FinishedGame[])
    const { data: rp } = await supabase!.rpc('ready_plans')
    setReadyPlans((rp ?? []) as ReadyPlan[])
  }
  const duplicatePlan = async () => {
    const mt = matchRef.current
    if (!mt) return
    const name = window.prompt('Název kopie plánu:', `${mt.name ?? 'Plán'} – kopie`)
    if (name == null) return
    setBusy(true)
    try {
      const { data: newId, error: e } = await supabase!.rpc('duplicate_match_plan', { p_match: mt.id, p_name: name })
      if (e) throw e
      await loadPlans()
      await loadPlanData(newId as string)
      setStatus(`Plán zduplikován jako „${name.trim() || `${mt.name ?? 'Plán'} – kopie`}". Před použitím jej zkontroluj a označ „připravit ke hře".`)
    } catch (e: any) {
      setError(`Duplikování plánu: ${e.message ?? e}`)
    } finally {
      setBusy(false)
    }
  }
  useEffect(() => {
    if (section !== 'manage') return
    const timer = setInterval(loadGames, 1000)
    return () => clearInterval(timer)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [section])
  const toggleReady = async (val: boolean) => {
    const mt = matchRef.current
    if (!mt) return
    const { error: e } = await supabase!.from('matches').update({ ready: val }).eq('id', mt.id)
    if (e) { setError(`Připravenost: ${e.message}`); return }
    matchRef.current = { ...mt, ready: val }
    setMatch(matchRef.current)
    setStatus(val ? `Plán „${mt.name ?? ''}" je připraven ke hře.` : `Plán „${mt.name ?? ''}" stažen z her.`)
  }
  const createGame = async () => {
    if (!newGamePlan) { setError('Vyber plán.'); return }
    const { error: e } = await supabase!.rpc('create_game', {
      p_plan: newGamePlan, p_capacity: newGameCap,
      p_sim: newGameMode === 'sim', p_run: newGameMode === 'run', p_name: newGameName,
    })
    if (e) { setError(`Nová hra: ${e.message}`); return }
    await loadGames()
    setNewGameName('')
    const modeLabel = newGameMode === 'sim' ? ' (simulace – klikání)' : newGameMode === 'run' ? ' (Run hra – joystick)' : ''
    setStatus(`Hra založena a je v lobby${modeLabel} – hráči se můžou připojit.`)
  }
  const runGame = async (g: Game) => {
    if (g.joined === 0) { setError('Ke hře není připojený žádný hráč – počkej, až se někdo připojí.'); return }
    const { error: e } = await supabase!.rpc('run_game', { p_game: g.game_id })
    if (e) { setError(`Start: ${e.message}`); return }
    await loadGames()
    setStatus(`Hra spuštěna – hráčům běží odpočet.`)
  }
  const finishGame = async (g: Game) => {
    if (!window.confirm('Ukončit hru? Hráči se vrátí do lobby, hra půjde do historie.')) return
    const { error: e } = await supabase!.rpc('finish_game', { p_game: g.game_id })
    if (e) { setError(`Konec: ${e.message}`); return }
    await loadGames()
    setStatus('Hra ukončena (v historii).')
  }
  const showResults = async (g: FinishedGame) => {
    const { rows, streets } = await loadGameResults(g.game_id, g.plan_id)
    setResultsModal({ name: g.game_name || g.plan_name || 'Hra', rows, streets })
  }
  const deleteGame = async (gameId: string, msg: string) => {
    if (!window.confirm(msg)) return
    const { error: e } = await supabase!.rpc('delete_game', { p_game: gameId })
    if (e) { setError(`Smazání hry: ${e.message}`); return }
    await loadGames()
    setStatus('Hra smazána.')
  }
  const goManage = () => {
    setSection('manage')
    loadGames()
    loadAccounts()
    loadCodes()
  }

  // --- Nastavení (časovače + tolerance) ---
  const saveSettings = async () => {
    const mt = matchRef.current
    if (!mt) return
    const patch = {
      idle_timeout_s: idle, outside_timeout_s: outside, snap_tolerance_m: tol,
      walk_speed_mps: walkMps, run_speed_mps: runMps, sprint_speed_mps: sprintMps, sprint_range_m: sprintRange,
      snake_initial_length_m: snakeLength, strawberry_growth_m: berryGrowth, game_duration_s: gameMinutes * 60,
      snake_speed_mps: snakeKmh / 3.6, strawberry_spawn_min_s: berryMin, strawberry_spawn_max_s: berryMax,
      max_lead_m: maxLead, respawn_countdown_s: respawnSeconds,
      self_collision_grace_m: selfCollisionGrace,
    }
    const { error: err } = await supabase!.from('matches').update(patch).eq('id', mt.id)
    if (err) {
      setError(`Uložení nastavení: ${err.message}`)
      return
    }
    const { error: berryErr } = await supabase!.rpc('save_strawberry_settings', {
      p_match: mt.id,
      p_active_percent: berryActivePercent,
      p_initial_percent: berryInitialPercent,
    })
    if (berryErr) {
      setError(`Uložení nastavení jahůdek: ${berryErr.message}`)
      return
    }
    const { data: saved, error: verifyErr } = await supabase!.from('matches').select(MATCH_COLS).eq('id', mt.id).single()
    if (verifyErr || !saved) {
      setError(`Nastavení bylo uloženo, ale nepodařilo se ověřit jeho hodnoty: ${verifyErr?.message ?? 'plán nenalezen'}`)
      return
    }
    const verified = saved as Match
    matchRef.current = verified
    setMatch(verified)
    setBerryActivePercent(verified.strawberry_active_percent)
    setBerryInitialPercent(verified.strawberry_initial_percent)
    setStatus(`Nastavení skutečně uloženo: start ${verified.strawberry_initial_percent} %, maximum ${verified.strawberry_active_percent} %.`)
  }

  return (
    <>
      <div id="map" />
      <VersionBadge />

      {/* SEKCE 1 — Plány (mapa) */}
      {section === 'plans' && (
        <>
          <div className="hud admin-hud">
            <div className="seg">
              <button className="active">🗺️ Plány</button>
              <button onClick={goManage}>⚙️ Správa</button>
            </div>
            <select className="pill plan-select" value={match?.id ?? ''} onChange={(e) => selectPlan(e.target.value)}>
              {plans.map((p) => (
                <option key={p.id} value={p.id}>{(p.is_active ? '★ ' : '') + (p.name ?? p.id.slice(0, 8))}</option>
              ))}
            </select>
            <button className="pill mode" onClick={newPlan}>+ Plán</button>
            <button className="pill mode" onClick={renamePlan} disabled={!match}>Přejmenovat</button>
            <button className="pill mode" onClick={duplicatePlan} disabled={!match || busy}>Duplikovat</button>
            <button className="pill mode" onClick={deletePlan} disabled={!match}>Smazat</button>
            <button className={`pill mode ${match?.ready ? 'active' : ''}`} onClick={() => toggleReady(!match?.ready)} disabled={!match}>{match?.ready ? '✓ ke hře' : 'připravit ke hře'}</button>
            {(Object.keys(MODE_LABEL) as Mode[]).map((m) => (
              <button key={m} className={`pill mode ${mode === m ? 'active' : ''}`} onClick={() => setModeBoth(m)}>{MODE_LABEL[m]}</button>
            ))}
            <span className="pill">cesty: {edgeCount.on}✓ / {edgeCount.off}✕</span>
            <span className="pill">starty: {startCount}</span>
            <span className="pill">jahůdkové body: {berryPointCount}</span>
            {error && <span className="pill warn">{error}</span>}
          </div>

          <div className="admin-panel">
            <div className="admin-panel-hint">{status ?? MODE_HINT[mode]}</div>

            {mode === 'area' && (
          <div className="admin-actions">
            <button onClick={findStreets} disabled={draftLen < 3 || busy}>{busy ? 'Hledám…' : `Najít ulice v oblasti (${draftLen})`}</button>
            <button onClick={reloadStreets} disabled={busy || !hasArea}>Znovu načíst</button>
            <button onClick={addFootpaths} disabled={busy || !hasArea}>Doplnit chodníky</button>
            <button onClick={cancelDraft} disabled={draftLen === 0 || busy}>Zrušit kreslení</button>
            <button onClick={clearPlan} disabled={busy || (!hasArea && edgesRef.current.length === 0)}>Vymazat obsah plánu</button>
          </div>
        )}

        {mode === 'streets' && (
          <div className="admin-actions">
            <button onClick={splitEdges} disabled={busy}>Rozdělit v křižovatkách</button>
            <label className="admin-check">
              <input type="checkbox" checked={footEnabled} onChange={(e) => toggleFootpaths(e.target.checked)} />
              chodníky hromadně zap/vyp
            </label>
            <span className="admin-panel-hint">Klik na kteroukoli cestu (silnice i chodník) ji zařadí/vyřadí ze hry. Šedá = mimo hru.</span>
          </div>
        )}

        {mode === 'connect' && (
          <div className="admin-actions">
            <span className="admin-panel-hint">Kreslit jako:</span>
            <label className="admin-check"><input type="radio" name="ckind" checked={!connectAsFoot} onChange={() => setConnectAsFoot(false)} /> silnice</label>
            <label className="admin-check"><input type="radio" name="ckind" checked={connectAsFoot} onChange={() => setConnectAsFoot(true)} /> chodník</label>
          </div>
        )}

            {mode === 'respawns' && (
              <div className="admin-actions">
                <button onClick={clearStarts} disabled={startCount === 0}>Smazat respawny</button>
                <span className="admin-panel-hint">{startCount} respawnů · táhni = přesuň · dvojklik = smazat</span>
              </div>
            )}
            {mode === 'berries' && <div className="admin-actions"><button onClick={clearBerries} disabled={berryPointCount === 0}>Smazat jahůdky</button><span className="admin-panel-hint">{berryPointCount} bodů · prázdné body hráči neuvidí · dvojklik = smazat</span></div>}
          </div>
        </>
      )}

      {/* SEKCE 2 — Správa (bez mapy, karty) */}
      {section === 'manage' && (
        <div className="admin-manage">
          <div className="manage-header">
            <div className="seg">
              <button onClick={() => setSection('plans')}>🗺️ Plány</button>
              <button className="active">⚙️ Správa</button>
            </div>
            <span className="manage-title"><b>KSMF Snake</b> · správa</span>
            <Link className="pill link" to="/">hra →</Link>
          </div>

          {(status || error) && (
            <div className={`manage-status ${error ? 'err' : ''}`}>{error ?? status}</div>
          )}

          <div className="manage-cards">
            <section className="card">
              <h2>Příručky (PDF)</h2>
              <p className="muted">Ke stažení a rozeslání testerům. Hráčskou příručku najdou hráči i v lobby.</p>
              <div className="row-actions">
                <a className="pill link" href="/manual-hrac.pdf" target="_blank" rel="noopener">📄 Příručka pro hráče</a>
                <a className="pill link" href="/manual-admin.pdf" target="_blank" rel="noopener">📄 Příručka pro admina</a>
              </div>
            </section>

            <section className="card">
              <h2>Nastavení zápasu</h2>
              <p className="muted">Plán: {match?.name ?? '—'}</p>
              <p className="muted">Tyto hodnoty se <b>uloží do každé nově založené hry</b> (snapshot) – stejná mapa tak může jet jednou pomalu, jednou rychle. Změna se nepromítne do už založených her.</p>
              <div className="card-row"><label>Výchozí délka hada (m)</label><input type="number" min={1} value={snakeLength} onChange={(e) => setSnakeLength(+e.target.value)} /></div>
              <div className="card-row"><label>Prodloužení za jahůdku (m)</label><input type="number" min={1} value={berryGrowth} onChange={(e) => setBerryGrowth(+e.target.value)} /></div>
              <div className="card-row"><label>Délka hry (min)</label><input type="number" min={1} value={gameMinutes} onChange={(e) => setGameMinutes(+e.target.value)} /></div>
              <div className="card-row"><label>Rychlost hada (km/h)</label><input type="number" min={0.5} step={0.1} value={snakeKmh} onChange={(e) => setSnakeKmh(+e.target.value)} /></div>
              <div className="card-row"><label>Jahůdka nejdříve (s)</label><input type="number" min={1} value={berryMin} onChange={(e) => setBerryMin(+e.target.value)} /></div>
              <div className="card-row"><label>Jahůdka nejpozději (s)</label><input type="number" min={berryMin} value={berryMax} onChange={(e) => setBerryMax(+e.target.value)} /></div>
              <div className="card-row"><label>Maximum aktivních jahůdek (%)</label><input type="number" min={1} max={100} value={berryActivePercent} onChange={(e) => setBerryActivePercent(Math.max(1, Math.min(100, +e.target.value)))} /></div>
              <div className="card-row"><label>Jahůdky aktivní při startu (%)</label><input type="number" min={0} max={100} value={berryInitialPercent} onChange={(e) => setBerryInitialPercent(Math.max(0, Math.min(100, +e.target.value)))} /></div>
              <p className="muted">Při {berryPointCount} bodech může být současně aktivních nejvýše {Math.ceil(berryPointCount * berryActivePercent / 100)}.</p>
              <p className="muted">Na začátku hry se aktivuje {Math.ceil(berryPointCount * berryInitialPercent / 100)} jahůdek. Průběžný maximální limit platí až pro jejich další obnovování.</p>
              <div className="card-row"><label>Maximální náskok (m)</label><input type="number" min={5} value={maxLead} onChange={(e) => setMaxLead(+e.target.value)} /></div>
              <div className="card-row"><label>Respawn odpočet (s)</label><input type="number" min={0} value={respawnSeconds} onChange={(e) => setRespawnSeconds(+e.target.value)} /></div>
              <div className="card-row"><label>Bezpečná délka za hlavou (m)</label><input type="number" min={0} step={1} value={selfCollisionGrace} onChange={(e) => setSelfCollisionGrace(Math.max(0, +e.target.value))} /></div>
              <div className="card-row"><label>Nečinnost (s) <span className="tip" title="Po kolika sekundách bez pohybu hráč vypadne (stojí na místě). Default 30 s.">ⓘ</span></label><input type="number" min={5} value={idle} onChange={(e) => setIdle(+e.target.value)} /></div>
              <div className="card-row"><label>Mimo ulici – limit (s) <span className="tip" title="Když hráč opustí ulici (svou stopu), kolik sekund má na návrat na konec stopy, než vypadne. Default 30 s.">ⓘ</span></label><input type="number" min={3} value={outside} onChange={(e) => setOutside(+e.target.value)} /></div>
              <div className="card-row"><label>Tolerance snap (m) <span className="tip" title="Do kolika metrů od osy ulice se poloha přichytí na ulici a počítá se jako na ulici. Větší = benevolentnější GPS. Default 30 m.">ⓘ</span></label><input type="number" min={5} value={tol} onChange={(e) => setTol(+e.target.value)} /></div>
              <p className="muted" style={{ marginTop: 4 }}>Run hra (joystick) – rychlosti</p>
              <div className="card-row"><label>Chůze (m/s) <span className="tip" title="Rychlost chůze 🚶 v Run hře. Při chůzi se dobíjí stamina. Default 3,6 m/s.">ⓘ</span></label><input type="number" min={0.3} step={0.1} value={walkMps} onChange={(e) => setWalkMps(+e.target.value)} /></div>
              <div className="card-row"><label>Běh (m/s) <span className="tip" title="Rychlost běhu 🏃 v Run hře. Default 7,5 m/s.">ⓘ</span></label><input type="number" min={0.5} step={0.1} value={runMps} onChange={(e) => setRunMps(+e.target.value)} /></div>
              <div className="card-row"><label>Sprint (m/s) <span className="tip" title="Rychlost sprintu ⚡ v Run hře. Sprint čerpá staminu. Default 12 m/s.">ⓘ</span></label><input type="number" min={0.5} step={0.1} value={sprintMps} onChange={(e) => setSprintMps(+e.target.value)} /></div>
              <div className="card-row"><label>Dosah sprintu (m) <span className="tip" title="Kolik metrů vydrží sprint na plnou staminu. Dobití trvá 3× déle a jen při chůzi. Default 200 m.">ⓘ</span></label><input type="number" min={20} step={10} value={sprintRange} onChange={(e) => setSprintRange(+e.target.value)} /></div>
              <button onClick={saveSettings}>Uložit nastavení</button>
            </section>

            <section className="card">
              <h2>Hry</h2>
              <p className="muted">Založ hru z plánu připraveného ke hře a zadej počet hráčů (≤ počet startů).</p>
              <div className="gameform">
                <input value={newGameName} onChange={(e) => setNewGameName(e.target.value)} placeholder="Název hry" maxLength={80} />
                <select value={newGamePlan} onChange={(e) => setNewGamePlan(e.target.value)}>
                  <option value="">— vyber plán —</option>
                  {readyPlans.map((p) => (
                    <option key={p.id} value={p.id}>{p.name ?? p.id.slice(0, 8)} ({p.starts} startů)</option>
                  ))}
                </select>
                <input type="number" min={1} value={newGameCap} onChange={(e) => setNewGameCap(+e.target.value)} style={{ width: 64 }} title="počet hráčů" />
                <select value={newGameMode} onChange={(e) => setNewGameMode(e.target.value as GameMode)} title="režim hry">
                  <option value="realtime">Realtime (GPS)</option>
                  <option value="sim">Simulace (klikání)</option>
                  <option value="run">Run hra (joystick)</option>
                </select>
                <button onClick={createGame}>+ Nová hra</button>
              </div>
              {readyPlans.length === 0 && <p className="muted">Žádný plán není „připraven ke hře" (zapni to v sekci Plány).</p>}
              <ul className="row-list">
                {games.map((g) => (
                  <li key={g.game_id}>
                    <span>
                      <b>{g.game_name}</b> {g.sim && <span title="simulace (klikání)">🧪</span>}{g.run_mode && <span title="Run hra (joystick)">🏃</span>}{' '}
                      <span className="muted">· mapa {g.plan_name ?? '—'} · {g.joined}/{g.capacity} · {g.status === 'lobby' ? 'v lobby' : `zbývá ${Math.floor((g.remaining_s ?? 0) / 60)}:${String((g.remaining_s ?? 0) % 60).padStart(2, '0')}`} · #{g.game_id.slice(0, 4)}</span>
                    </span>
                    <span className="row-actions">
                      <button className="ghost" onClick={() => setSpectate(g)}>Sleduj</button>
                      {g.status === 'lobby' && <button onClick={() => runGame(g)}>Spustit</button>}
                      {g.status === 'lobby' && <button className="danger" onClick={() => deleteGame(g.game_id, 'Smazat tuhle hru z lobby?')}>Smazat</button>}
                      {g.status === 'running' && <button className="danger" onClick={() => finishGame(g)}>Ukončit</button>}
                    </span>
                  </li>
                ))}
                {games.length === 0 && <li className="muted">Žádná aktivní hra.</li>}
              </ul>
            </section>

            <section className="card wide">
              <h2>Dokončené hry ({finished.length})</h2>
              <p className="muted">Historie odehraných her (později proklik na PDF výstup).</p>
              <ul className="row-list scroll">
                {finished.map((g) => (
                  <li key={g.game_id}>
                    <span><b>{g.game_name}</b> <span className="muted">· mapa {g.plan_name ?? '—'} · {g.players} hráčů{g.finished_at ? ' · ' + new Date(g.finished_at).toLocaleString('cs-CZ') : ''}</span></span>
                    <span className="row-actions">
                      <button onClick={() => showResults(g)}>Výsledky</button>
                      <button className="danger" onClick={() => deleteGame(g.game_id, 'Smazat tuhle hru z historie?')}>smazat</button>
                    </span>
                  </li>
                ))}
                {finished.length === 0 && <li className="muted">Zatím žádná dokončená hra.</li>}
              </ul>
            </section>

            <section className="card">
              <h2>Přístup — kódy</h2>
              <p className="muted">Kód řekni hráčům pro registraci; deaktivuj, až nemá platit.</p>
              <button onClick={genCode}>+ Nový kód</button>
              <ul className="row-list">
                {codes.map((c) => (
                  <li key={c.id}>
                    <b className={c.active ? 'ok' : 'muted'} style={{ letterSpacing: 1 }}>{c.code}</b>
                    <span className="row-actions">
                      <button onClick={() => copyCode(c.code)}>kopírovat</button>
                      <button onClick={() => toggleCode(c)}>{c.active ? 'deaktivovat' : 'aktivovat'}</button>
                      <button className="danger" onClick={() => deleteCode(c)}>smazat</button>
                    </span>
                  </li>
                ))}
                {codes.length === 0 && <li className="muted">Zatím žádný kód.</li>}
              </ul>
            </section>

            <section className="card wide">
              <h2>Hráči — účty ({accounts.length})</h2>
              <p className="muted">Smazaný hráč je zapomenut a musí se zaregistrovat znovu.</p>
              <ul className="row-list scroll">
                {accounts.map((a) => (
                  <li key={a.id}>
                    <span>{a.nickname}</span>
                    <button className="danger" onClick={() => deleteAccount(a)}>smazat</button>
                  </li>
                ))}
                {accounts.length === 0 && <li className="muted">Zatím žádný registrovaný hráč.</li>}
              </ul>
            </section>
          </div>
        </div>
      )}

      {spectate && (
        <Spectate
          gameId={spectate.game_id}
          planId={spectate.plan_id}
          status={spectate.status}
          onClose={() => { setSpectate(null); loadGames() }}
          onChanged={loadGames}
        />
      )}

      {resultsModal && (
        <div className="modal" onClick={() => setResultsModal(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <h2>Výsledky — {resultsModal.name}</h2>
            <TrailsImage streets={resultsModal.streets} players={resultsModal.rows} width={380} height={300} />
            <table className="snake-results"><thead><tr><th>Hráč</th><th>Max. délka</th><th>Jahůdky</th><th>Výbuchy soupeřů</th></tr></thead><tbody>
              {resultsModal.rows.map((r, i) => <tr key={i}><td><span style={{ color: r.color }}>●</span> {r.nickname}</td><td>{Math.round(r.maxLength)} m</td><td>{r.strawberries}</td><td>{r.explosions}</td></tr>)}
            </tbody></table>
            <button onClick={() => setResultsModal(null)}>Zavřít</button>
          </div>
        </div>
      )}
    </>
  )
}
