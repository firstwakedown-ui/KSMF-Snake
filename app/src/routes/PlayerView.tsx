import { useEffect, useRef, useState, type PointerEvent as RPointerEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { nearestPointOnLine, point, lineString, bbox as turfBbox } from '@turf/turf'
import { checkCollision as detectCollision, haversineM, trailLenM } from '../lib/collision'
import type { Feature, LineString } from 'geojson'
import { supabase } from '../lib/supabase'
import { getPlayer } from '../lib/session'
import type { PlayerSession } from '../lib/session'
import { BARRANDOV, BARRANDOV_BBOX, MAP_STYLE, emptyFC, lineFC, pointFC, setSourceData } from '../lib/geo'
import { startMarkerEl } from '../lib/startMarker'
import VersionBadge from './VersionBadge'
import TrailsImage from './TrailsImage'
import { colorFor, assignColors } from '../lib/players'

const DEFAULT_SNAP_TOLERANCE_M = 30
const COUNTDOWN_S = 10 // délka odpočtu po STARTu
const COLLISION_EPS_M = 4 // blíž než tolik k existující stopě = náraz
// |cos(úhlu)| ≥ tolik = pohyb rovnoběžně se stopou → náraz; menší = prokřížení (OK).
// Vysoko (0.9), protože poloha je snapnutá na osu ulice: skutečné „jetí podél" staré stopy = stejná ulice =
// dot ≈ 1, kdežto projetí (i šikmé) křižovatky = jiná ulice = nižší dot. Vyšší práh tak pustí i šikmé křižovatky.
const COLLISION_PARALLEL_COS = 0.9
const COLLISION_HOLD_MS = 300 // náraz musí trvat souvisle aspoň tolik (krátký záblesk z přeskoku snapu na uzlu nezabíjí)
const SELF_SKIP_M = 8 // posledních X m vlastní stopy se nepočítá (jsi na ní)
const IDLE_MOVE_M = 3 // posun menší než tolik se nepočítá jako pohyb (proti GPS šumu)
const RECOVER_RADIUS_M = 12 // po opuštění stopy se musíš vrátit do tolika m od jejího konce (kotvy)
const RUN_TICK_MS = 80 // perioda auto-pohybu v „Run Hra" módu (joystick)
const TRAIL_MIN_M = 1.5 // body stopy hustěji než tolik se neukládají (proti záplavě bodů při auto-pohybu)
const RUN_DEFAULTS = { walk: 3.6, run: 7.5, sprint: 12.0, range: 200 } // fallback, než dorazí nastavení plánu (3× zrychleno)

type GameInfo = {
  game_id: string
  plan_id: string
  plan_name: string | null
  snap_tolerance_m: number
  status: string
  started_at: string | null
  start_lng: number | null
  start_lat: number | null
  start_label: string | null
  sim: boolean
  run_mode: boolean
  idle_timeout_s: number | null
  outside_timeout_s: number | null
  walk_speed_mps: number | null
  run_speed_mps: number | null
  sprint_speed_mps: number | null
  sprint_range_m: number | null
}
type Phase = 'loading' | 'none' | 'waiting' | 'countdown' | 'live' | 'ended'
type Result = { player_id: string; nickname: string; place: number | null; alive: boolean; trail: [number, number][] | null }
type Other = { nick: string; color: string; trail: [number, number][]; pos: [number, number] | null; lastSeen: number; eliminated?: boolean }

// Engine fáze 1+2: start/odpočet + živé stopy všech hráčů (klient + Supabase Realtime).
export default function PlayerView() {
  const mapRef = useRef<maplibregl.Map | null>(null)
  const mapReadyRef = useRef(false)
  const edgesRef = useRef<Feature<LineString>[]>([])
  const trailRef = useRef<[number, number][]>([])
  const tolRef = useRef<number>(DEFAULT_SNAP_TOLERANCE_M)
  const playerRef = useRef<PlayerSession | null>(getPlayer())
  const gameRef = useRef<GameInfo | null>(null)
  const initedRef = useRef(false)
  const hadMatchRef = useRef(false)
  const liveRef = useRef(false)
  const channelRef = useRef<ReturnType<NonNullable<typeof supabase>['channel']> | null>(null)
  const othersRef = useRef<Map<string, Other>>(new Map())
  const colorMapRef = useRef<Map<string, string>>(new Map())
  const ownColorRef = useRef<string>('#58a6ff')
  const eliminatedRef = useRef(false)
  const simRef = useRef(false)
  const processRef = useRef<(raw: [number, number], acc?: number) => void>()
  const lastMoveRef = useRef(0)
  const lastMovePosRef = useRef<[number, number] | null>(null)
  const idleMsRef = useRef(30000)
  const outsideMsRef = useRef(30000)
  const outsideSinceRef = useRef(0)
  const recoveryRef = useRef(false)
  const anchorRef = useRef<[number, number] | null>(null)
  const onStreetRef = useRef(false)
  const wasLiveRef = useRef(false)
  const lastSnappedRef = useRef<[number, number] | null>(null)
  const collisionSinceRef = useRef(0) // od kdy souvisle trvá podmínka nárazu (debounce)
  const settingsGameRef = useRef<string | null>(null) // pro které game_id už máme načtené nastavení
  // „Run Hra" mód (joystick + rychlosti + stamina).
  const runRef = useRef(false)
  const walkMpsRef = useRef(RUN_DEFAULTS.walk)
  const runMpsRef = useRef(RUN_DEFAULTS.run)
  const sprintMpsRef = useRef(RUN_DEFAULTS.sprint)
  const sprintRangeRef = useRef(RUN_DEFAULTS.range)
  const simRawRef = useRef<[number, number] | null>(null) // „volná" poloha (před snapnutím) pro auto-pohyb
  const headingRef = useRef<{ x: number; y: number } | null>(null) // směr z joysticku (null = stojím)
  const runSpeedRef = useRef<'walk' | 'run' | 'sprint'>('run')
  const staminaRef = useRef(1) // 0..1 zbývající dosah sprintu
  const keysRef = useRef<Set<string>>(new Set())
  const joyRef = useRef<HTMLDivElement | null>(null)
  const joyActiveRef = useRef(false)

  const [accuracy, setAccuracy] = useState<number | null>(null)
  const [snap, setSnap] = useState<number | null>(null)
  const [onStreet, setOnStreet] = useState(false)
  const [streets, setStreets] = useState<number | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [wakeOn, setWakeOn] = useState(false)
  const [phase, setPhase] = useState<Phase>('loading')
  const [countdown, setCountdown] = useState(COUNTDOWN_S)
  const [others, setOthers] = useState(0)
  const [eliminatedReason, setEliminatedReason] = useState<string | null>(null)
  const [watching, setWatching] = useState(false)
  const [sim, setSim] = useState(false)
  const [simAllowed, setSimAllowed] = useState(false)
  const [navDist, setNavDist] = useState<number | null>(null)
  const [outsideLeft, setOutsideLeft] = useState<number | null>(null)
  const [trailLen, setTrailLen] = useState(0)
  const [roster, setRoster] = useState<{ id: string; nick: string; color: string }[]>([])
  const [legendOpen, setLegendOpen] = useState(false)
  const [results, setResults] = useState<Result[]>([])
  const [runMode, setRunMode] = useState(false)
  const [runSpeed, setRunSpeed] = useState<'walk' | 'run' | 'sprint'>('run')
  const [stamina, setStamina] = useState(100)
  const [knob, setKnob] = useState<{ x: number; y: number }>({ x: 0, y: 0 })
  const resultsFetchedRef = useRef(false)
  const trailSavedRef = useRef(false)
  const trailRestoredRef = useRef(false)
  const nav = useNavigate()

  const toggleSim = () => {
    if (!simAllowed) return
    simRef.current = !simRef.current
    setSim(simRef.current)
  }

  // --- Run Hra: ovládání rychlosti + joystick ---
  const setSpeed = (s: 'walk' | 'run' | 'sprint') => { runSpeedRef.current = s; setRunSpeed(s) }
  const updateJoy = (clientX: number, clientY: number) => {
    const el = joyRef.current
    if (!el) return
    const r = el.getBoundingClientRect()
    const cx = r.left + r.width / 2, cy = r.top + r.height / 2
    const dx = clientX - cx, dy = clientY - cy
    const max = r.width / 2
    const len = Math.hypot(dx, dy) || 1
    const cl = Math.min(len, max)
    setKnob({ x: (dx / len) * cl, y: (dy / len) * cl })
    if (len < max * 0.18) headingRef.current = null // mrtvá zóna uprostřed = stojím
    else headingRef.current = { x: dx / len, y: -(dy / len) } // obrazovkové y dolů = na jih
  }
  const onJoyDown = (e: RPointerEvent<HTMLDivElement>) => {
    joyActiveRef.current = true
    e.currentTarget.setPointerCapture(e.pointerId)
    updateJoy(e.clientX, e.clientY)
  }
  const onJoyMove = (e: RPointerEvent<HTMLDivElement>) => { if (joyActiveRef.current) updateJoy(e.clientX, e.clientY) }
  const onJoyUp = () => { joyActiveRef.current = false; headingRef.current = null; setKnob({ x: 0, y: 0 }) }

  useEffect(() => {
    if (!playerRef.current) nav('/', { replace: true })
  }, [nav])

  // --- Inicializace mapy + vrstvy ---
  useEffect(() => {
    const map = new maplibregl.Map({ container: 'map', style: MAP_STYLE, center: BARRANDOV, zoom: 15 })
    mapRef.current = map

    map.on('load', () => {
      map.addSource('streets', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'streets-line', type: 'line', source: 'streets', paint: { 'line-color': '#f59e0b', 'line-width': 3, 'line-opacity': 0.8 } })
      // Navigační čára k vlastnímu startu (před startem hry).
      map.addSource('nav', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'nav-line', type: 'line', source: 'nav', paint: { 'line-color': '#3fb950', 'line-width': 3, 'line-dasharray': [2, 1.5] } })
      // Stopy ostatních hráčů (barevné).
      map.addSource('others-trails', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'others-trails-line', type: 'line', source: 'others-trails', paint: { 'line-color': ['get', 'color'], 'line-width': 4, 'line-opacity': 0.9 } })
      // Vlastní stopa.
      map.addSource('trail', { type: 'geojson', data: lineFC([]) })
      map.addLayer({ id: 'trail-line', type: 'line', source: 'trail', paint: { 'line-color': '#58a6ff', 'line-width': 5 } })
      // Ostatní hráči – tečka + jméno.
      map.addSource('others-pos', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'others-pos-circle', type: 'circle', source: 'others-pos', paint: { 'circle-radius': 6, 'circle-color': ['get', 'color'], 'circle-stroke-color': '#fff', 'circle-stroke-width': 2 } })
      map.addLayer({ id: 'others-pos-label', type: 'symbol', source: 'others-pos', layout: { 'text-field': ['get', 'nick'], 'text-size': 11, 'text-offset': [0, 1.2], 'text-allow-overlap': true }, paint: { 'text-color': '#ffffff', 'text-halo-color': '#0d1117', 'text-halo-width': 1.5 } })
      // Run mód: spojnice „skutečná poloha → bod na ulici" (ať vidíš, kam tě snap přichytil).
      map.addSource('rawlink', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'rawlink-line', type: 'line', source: 'rawlink', paint: { 'line-color': '#ffffff', 'line-width': 1.5, 'line-dasharray': [1, 1], 'line-opacity': 0.8 } })
      // Vlastní poloha (zelená na ulici, červená mimo) = snapnutý bod (počítá se do hry).
      map.addSource('pos', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'pos-circle', type: 'circle', source: 'pos', paint: { 'circle-radius': 7, 'circle-color': ['case', ['get', 'on'], '#3fb950', '#f85149'], 'circle-stroke-color': '#ffffff', 'circle-stroke-width': 2 } })
      // Run mód: tvoje SKUTEČNÁ (nesnapnutá) poloha = bílý kroužek s černým obrysem (vizuální pomoc).
      map.addSource('rawpos', { type: 'geojson', data: emptyFC() })
      map.addLayer({ id: 'rawpos-ring-outline', type: 'circle', source: 'rawpos', paint: { 'circle-radius': 10, 'circle-color': 'rgba(0,0,0,0)', 'circle-stroke-color': '#000000', 'circle-stroke-width': 4 } })
      map.addLayer({ id: 'rawpos-ring', type: 'circle', source: 'rawpos', paint: { 'circle-radius': 9, 'circle-color': 'rgba(255,255,255,0.12)', 'circle-stroke-color': '#ffffff', 'circle-stroke-width': 2.5 } })

      // Simulační mód: klik do mapy = poloha hráče (test od stolu, bez GPS).
      map.on('click', (e) => {
        if (simRef.current) processRef.current?.([e.lngLat.lng, e.lngLat.lat])
      })

      mapReadyRef.current = true
      map.fitBounds(BARRANDOV_BBOX, { padding: 40, duration: 0 })
    })

    return () => {
      if (channelRef.current) supabase?.removeChannel(channelRef.current)
      map.remove()
    }
  }, [])

  // --- Načtení ulic + startů dané mapy (jednou) ---
  const loadStreets = async (matchId: string) => {
    const map = mapRef.current!
    try {
      const { data, error: e } = await supabase!.from('street_edges').select('id,name,geom,enabled').eq('match_id', matchId).eq('enabled', true)
      if (e) throw e
      const rows = data ?? []
      edgesRef.current = rows.map((r: any) => lineString(r.geom.coordinates, { name: r.name, id: r.id }))
      const fc = {
        type: 'FeatureCollection' as const,
        features: rows.map((r: any) => ({ type: 'Feature' as const, geometry: r.geom, properties: { name: r.name } })),
      }
      setSourceData(map, 'streets', fc)
      setStreets(rows.length)
      const { data: sp } = await supabase!.from('start_points').select('id,label,geom').eq('match_id', matchId)
      for (const r of sp ?? []) {
        new maplibregl.Marker({ element: startMarkerEl(r.label ?? '') }).setLngLat(r.geom.coordinates as [number, number]).addTo(map)
      }
      if (rows.length) {
        const [w, s, e2, n] = turfBbox(fc)
        map.fitBounds([[w, s], [e2, n]], { padding: 40, duration: 0 })
      }
    } catch (e: any) {
      setError(`Graf ulic: ${e.message ?? e}`)
    }
  }

  // --- Realtime kanál: vysílání vlastní pozice + příjem ostatních ---
  const setupChannel = (gameId: string) => {
    if (channelRef.current || !supabase) return
    const ch = supabase.channel(`game-${gameId}`, { config: { broadcast: { self: false } } })
    ch.on('broadcast', { event: 'pos' }, ({ payload }: any) => {
      const me = playerRef.current?.id
      if (!payload?.id || payload.id === me) return
      let o = othersRef.current.get(payload.id)
      if (!o) {
        o = { nick: payload.nick ?? '?', color: colorFor(payload.id), trail: [], pos: null, lastSeen: 0 }
        othersRef.current.set(payload.id, o)
      }
      o.pos = payload.pos
      o.lastSeen = Date.now()
      if (payload.live && payload.pos && !o.eliminated) {
        const t = o.trail
        const last = t[t.length - 1]
        if (!last || last[0] !== payload.pos[0] || last[1] !== payload.pos[1]) t.push(payload.pos)
      }
      renderOthers()
    })
    ch.on('broadcast', { event: 'eliminated' }, ({ payload }: any) => {
      if (!payload?.id || payload.id === playerRef.current?.id) return
      let o = othersRef.current.get(payload.id)
      if (!o) {
        o = { nick: payload.nick ?? '?', color: colorFor(payload.id), trail: [], pos: null, lastSeen: 0 }
        othersRef.current.set(payload.id, o)
      }
      o.eliminated = true
      o.lastSeen = Date.now()
      if (Array.isArray(payload.trail) && payload.trail.length >= 2) o.trail = payload.trail // finální obsazená stopa
      renderOthers()
    })
    ch.subscribe()
    channelRef.current = ch
  }
  const sendPos = (pos: [number, number]) => {
    const p = playerRef.current
    if (!channelRef.current || !p || eliminatedRef.current) return
    channelRef.current.send({ type: 'broadcast', event: 'pos', payload: { id: p.id, nick: p.nickname, pos, live: liveRef.current && onStreetRef.current } })
  }

  const getColor = (id: string) => colorMapRef.current.get(id) ?? colorFor(id)

  const renderOthers = () => {
    const map = mapRef.current
    if (!map) return
    const trails: Feature[] = []
    const poss: Feature[] = []
    othersRef.current.forEach((o, id) => {
      const color = getColor(id)
      if (o.trail.length >= 2) trails.push({ type: 'Feature', geometry: { type: 'LineString', coordinates: o.trail }, properties: { color } })
      if (o.pos) poss.push({ type: 'Feature', geometry: { type: 'Point', coordinates: o.pos }, properties: { color, nick: o.nick } })
    })
    setSourceData(map, 'others-trails', { type: 'FeatureCollection', features: trails })
    setSourceData(map, 'others-pos', { type: 'FeatureCollection', features: poss })
    setOthers(othersRef.current.size)
  }

  // Barvy hráčů z aktuálního seznamu účastníků (zaručeně různé); vlastní stopa dostane svou barvu.
  const loadRoster = async (gameId: string) => {
    if (!supabase) return
    const { data } = await supabase.rpc('game_roster', { p_game: gameId })
    const rows = (data ?? []) as any[]
    colorMapRef.current = assignColors(rows.map((r) => r.player_id))
    setRoster(rows.map((r) => ({ id: r.player_id, nick: r.nickname, color: colorMapRef.current.get(r.player_id) ?? '#888' })))
    const myId = playerRef.current?.id
    const myColor = (myId && colorMapRef.current.get(myId)) || '#58a6ff'
    if (myColor !== ownColorRef.current) {
      ownColorRef.current = myColor
      if (mapReadyRef.current) mapRef.current?.setPaintProperty('trail-line', 'line-color', myColor)
    }
    renderOthers()
  }

  // Vlastní stopa bez posledních ~SELF_SKIP_M metrů (na těch zrovna stojíš).
  const ownCheckTrail = (): [number, number][] => {
    const t = trailRef.current
    if (t.length < 2) return []
    let acc = 0
    let cut = -1
    for (let i = t.length - 1; i > 0; i--) {
      acc += haversineM(t[i], t[i - 1])
      if (acc >= SELF_SKIP_M) { cut = i - 1; break }
    }
    return cut >= 1 ? t.slice(0, cut + 1) : []
  }

  // Uloží finální stopu hráče do DB (pro obrázek tras ve výsledcích).
  const saveTrail = async () => {
    const p = playerRef.current
    const g = gameRef.current
    if (!p || !g || !supabase || trailSavedRef.current || trailRef.current.length < 2) return
    trailSavedRef.current = true
    await supabase.from('game_players').update({ trail: trailRef.current }).eq('game_id', g.game_id).eq('player_id', p.id)
  }

  // Vyřazení: přestaň trackovat/vysílat, zmraz stopu, oznam ostatním (vícekrát kvůli spolehlivosti).
  const eliminate = (reason: string) => {
    if (eliminatedRef.current) return
    eliminatedRef.current = true
    setEliminatedReason(reason)
    // Zmrazená stopa zůstane vykreslená (je to obsazená cesta i pro ostatní).
    setSourceData(mapRef.current, 'trail', lineFC(trailRef.current))
    const p = playerRef.current
    const g = gameRef.current
    if (p && channelRef.current) {
      const payload = { id: p.id, nick: p.nickname, trail: trailRef.current }
      const send = () => channelRef.current?.send({ type: 'broadcast', event: 'eliminated', payload })
      send()
      setTimeout(send, 500)
      setTimeout(send, 1500)
    }
    if (p && g && supabase) supabase.rpc('eliminate_player', { p_game: g.game_id, p_player: p.id }).then(() => {})
    saveTrail()
  }

  // --- Sledování stavu hry (poll) + odpočet (tick) ---
  useEffect(() => {
    const poll = async () => {
      const player = playerRef.current
      if (!player || !supabase) return
      const { data } = await supabase.rpc('current_game', { p_player: player.id })
      const m = (Array.isArray(data) ? data[0] : data) as GameInfo | undefined
      if (!m?.game_id) {
        // Hra skončila (nebo nejsem v žádné) → ukaž výsledky.
        if (hadMatchRef.current && gameRef.current) {
          if (!resultsFetchedRef.current) {
            resultsFetchedRef.current = true
            await saveTrail() // ulož svou stopu (přeživší i vyřazený) před načtením výsledků
            const { data: res } = await supabase.rpc('game_results', { p_game: gameRef.current.game_id })
            setResults((res ?? []) as Result[])
            setPhase('ended')
            gameRef.current = null // zastav tick, ať nepřepisuje fázi zpět na „live" (jinak výsledek jen problikne)
          }
        } else if (!hadMatchRef.current) setPhase('none')
        return
      }
      hadMatchRef.current = true
      gameRef.current = m
      setSimAllowed(!!m.sim)
      if (runRef.current !== !!m.run_mode) { runRef.current = !!m.run_mode; setRunMode(runRef.current) }
      // Nastavení je SNAPSHOT konkrétní hry (current_game ho vrací) → načti při každé nové hře.
      if (settingsGameRef.current !== m.game_id) {
        settingsGameRef.current = m.game_id
        if (m.idle_timeout_s) idleMsRef.current = m.idle_timeout_s * 1000
        if (m.outside_timeout_s) outsideMsRef.current = m.outside_timeout_s * 1000
        if (m.walk_speed_mps) walkMpsRef.current = Number(m.walk_speed_mps)
        if (m.run_speed_mps) runMpsRef.current = Number(m.run_speed_mps)
        if (m.sprint_speed_mps) sprintMpsRef.current = Number(m.sprint_speed_mps)
        if (m.sprint_range_m) sprintRangeRef.current = Number(m.sprint_range_m)
      }
      // Self-heal: jsem lokálně vyřazen, ale server to ještě neví → nahlas znovu (auto-ukončení hry).
      if (eliminatedRef.current && m.status === 'running' && (m as any).alive) {
        supabase.rpc('eliminate_player', { p_game: m.game_id, p_player: player.id }).then(() => {})
      }
      if (m.snap_tolerance_m) tolRef.current = m.snap_tolerance_m
      if (!initedRef.current && mapReadyRef.current) {
        initedRef.current = true
        loadStreets(m.plan_id)
        setupChannel(m.game_id)
        // Obnova po refreshi: načti svou uloženou stopu + stav vyřazení (ať nepřijdeš o historii / nehraješ znovu).
        if (!trailRestoredRef.current) {
          trailRestoredRef.current = true
          const { data: me } = await supabase.from('game_players').select('trail,alive').eq('game_id', m.game_id).eq('player_id', player.id).single()
          if (me?.trail && Array.isArray(me.trail) && me.trail.length) {
            trailRef.current = me.trail as [number, number][]
            anchorRef.current = trailRef.current[trailRef.current.length - 1]
            setSourceData(mapRef.current, 'trail', lineFC(trailRef.current))
            setTrailLen(trailLenM(trailRef.current))
          }
          if (me && (me as any).alive === false) { eliminatedRef.current = true; setEliminatedReason('Už jsi v této hře vypadl.') }
        }
      }
      loadRoster(m.game_id)
    }
    const tick = () => {
      const m = gameRef.current
      if (!m) return
      if (m.status === 'lobby' || !m.started_at) {
        liveRef.current = false
        wasLiveRef.current = false
        setPhase('waiting')
        return
      }
      const elapsed = (Date.now() - new Date(m.started_at).getTime()) / 1000
      if (elapsed < COUNTDOWN_S) {
        liveRef.current = false
        wasLiveRef.current = false
        setPhase('countdown')
        setCountdown(Math.max(1, Math.ceil(COUNTDOWN_S - elapsed)))
        return
      }
      // běh
      if (!wasLiveRef.current) {
        wasLiveRef.current = true
        lastMoveRef.current = Date.now()
        lastMovePosRef.current = null
        outsideSinceRef.current = 0
        collisionSinceRef.current = 0
        recoveryRef.current = false
        anchorRef.current = null
      }
      liveRef.current = true
      setPhase('live')
      setTrailLen(trailLenM(trailRef.current)) // živá délka trasy
      // Nečinnost > limit (FR-08) → vyřazení.
      if (!eliminatedRef.current && lastMoveRef.current && Date.now() - lastMoveRef.current > idleMsRef.current) {
        eliminate('Stál jsi na místě moc dlouho (nečinnost).')
      }
      // Mimo ulici > limit (FR-11/12) → vyřazení; jinak ukaž odpočet.
      if (!eliminatedRef.current && outsideSinceRef.current) {
        const left = Math.ceil((outsideMsRef.current - (Date.now() - outsideSinceRef.current)) / 1000)
        if (left <= 0) { eliminate('Nevrátil ses na konec své stopy včas.'); setOutsideLeft(null) }
        else setOutsideLeft(left)
      } else setOutsideLeft(null)
    }
    poll()
    const pollId = setInterval(poll, 1500)
    const tickId = setInterval(tick, 300)
    // Heartbeat: opakovaně vysílej poslední polohu, ať tě admin/ostatní vidí i když zrovna stojíš
    // nebo se připojí ke kanálu později (broadcast je jinak jednorázový).
    const hbId = setInterval(() => {
      const p = playerRef.current
      if (eliminatedRef.current) {
        // Vyřazený drží svou obsazenou stopu i pro ostatní/admina (i při pozdním připojení).
        if (channelRef.current && p) channelRef.current.send({ type: 'broadcast', event: 'eliminated', payload: { id: p.id, nick: p.nickname, trail: trailRef.current } })
        return
      }
      if (lastSnappedRef.current) sendPos(lastSnappedRef.current)
      // Průběžně ukládej stopu do DB (ať je v obrázku i když hru ukončí admin).
      if (liveRef.current && p && gameRef.current && supabase && trailRef.current.length >= 2) {
        supabase.from('game_players').update({ trail: trailRef.current }).eq('game_id', gameRef.current.game_id).eq('player_id', p.id).then(() => {})
      }
    }, 2000)
    // Úklid „zmizelých" ostatních.
    const pruneId = setInterval(() => {
      const now = Date.now()
      let changed = false
      othersRef.current.forEach((o, id) => {
        if (!o.eliminated && now - o.lastSeen > 6000) { othersRef.current.delete(id); changed = true }
      })
      if (changed) renderOthers()
    }, 3000)
    return () => { clearInterval(pollId); clearInterval(tickId); clearInterval(pruneId); clearInterval(hbId) }
  }, [nav])

  // --- Screen Wake Lock ---
  useEffect(() => {
    let lock: WakeLockSentinel | null = null
    const request = async () => {
      try { lock = (await navigator.wakeLock?.request('screen')) ?? null; setWakeOn(!!lock) } catch { setWakeOn(false) }
    }
    request()
    const onVisible = () => document.visibilityState === 'visible' && request()
    document.addEventListener('visibilitychange', onVisible)
    return () => { document.removeEventListener('visibilitychange', onVisible); lock?.release().catch(() => {}) }
  }, [])

  // Zpracování jedné polohy (sdílí GPS i simulační klik).
  const processPosition = (raw: [number, number], acc?: number) => {
    if (acc != null) setAccuracy(acc)
    let snapped = raw
    let distM: number | null = null
    let on = false
    const edges = edgesRef.current
    if (edges.length) {
      const p = point(raw)
      let bestDist = Infinity
      let bestCoord: [number, number] | null = null
      for (const e of edges) {
        const sn = nearestPointOnLine(e, p)
        const d = sn.properties.dist as number
        if (d < bestDist) { bestDist = d; bestCoord = sn.geometry.coordinates as [number, number] }
      }
      distM = bestDist * 1000
      on = distM <= tolRef.current
      if (bestCoord && on) snapped = bestCoord
    }
    onStreetRef.current = on
    setSnap(distM)
    setOnStreet(on)

    const map = mapRef.current
    if (liveRef.current && !eliminatedRef.current) {
      // Nečinnost: posun větší než IDLE_MOVE_M resetuje časovač (FR-08; i během návratu na stopu).
      if (!lastMovePosRef.current || haversineM(snapped, lastMovePosRef.current) > IDLE_MOVE_M) {
        lastMovePosRef.current = snapped
        lastMoveRef.current = Date.now()
      }
      // Jsem zpět na konci své stopy (kotvě)? (když ještě není kotva, stačí být na ulici)
      const nearAnchor = on && (!anchorRef.current || haversineM(snapped, anchorRef.current) <= RECOVER_RADIUS_M)
      if (recoveryRef.current) {
        // Opustil jsem stopu → musím se vrátit přesně na její konec, ne na jinou ulici.
        if (nearAnchor) { recoveryRef.current = false; outsideSinceRef.current = 0 }
        // dokud nejsem u kotvy, stopa neroste a běží časovač (outsideSinceRef už nastaven)
      }
      if (!recoveryRef.current) {
        if (on) {
          // Normální hra na ulici: zkontroluj náraz a prodluž stopu.
          // (Slepé uličky/pasti řeší kolize – U-otočka → náraz do vlastní stopy; explicitní „uvíznutí"
          //  dělalo falešné poplachy na křižovatkách kvůli nepřesnému obsazení hran, proto vypnuto.)
          const otherTrails: [number, number][][] = []
          othersRef.current.forEach((o) => { if (o.trail.length >= 2) otherTrails.push(o.trail) })
          // Směr pohybu počítej z OKAMŽITÉ předchozí polohy (max 1 tik zpět), ne z posledního bodu stopy –
          // ten může být kvůli „gate"/přeskoku snapu na křižovatce mimo směr a kolmé prokřížení by se
          // chybně vyhodnotilo jako jízda podél stopy (FR-07: projetí křižovatky musí být povolené).
          const prevPos = lastSnappedRef.current ?? (trailRef.current.length ? trailRef.current[trailRef.current.length - 1] : null)
          // Debounce: krátký záblesk (přeskok snapu na uzlu) nezabíjí – náraz musí trvat ≥ COLLISION_HOLD_MS.
          if (detectCollision(snapped, prevPos, ownCheckTrail(), otherTrails, { epsM: COLLISION_EPS_M, parallelCos: COLLISION_PARALLEL_COS })) {
            if (!collisionSinceRef.current) collisionSinceRef.current = Date.now()
            if (Date.now() - collisionSinceRef.current >= COLLISION_HOLD_MS) eliminate('Narazil jsi do stopy.')
          } else {
            collisionSinceRef.current = 0
          }
          if (!eliminatedRef.current) {
            // Bod přidej jen po posunu ≥ TRAIL_MIN_M (auto-pohyb jinak generuje stovky bodů/s).
            const lastT = trailRef.current[trailRef.current.length - 1]
            if (!lastT || haversineM(snapped, lastT) >= TRAIL_MIN_M) {
              trailRef.current.push(snapped)
              setSourceData(map, 'trail', lineFC(trailRef.current))
            }
            anchorRef.current = snapped // konec stopy se posouvá s tebou
            outsideSinceRef.current = 0
          }
        } else {
          // Opustil jsem ulici → recovery: stopa zamrzne na kotvě, spustí se časovač.
          recoveryRef.current = true
          if (!outsideSinceRef.current) outsideSinceRef.current = Date.now()
        }
      }
    }
    setSourceData(map, 'pos', pointFC(snapped, on))
    // Run mód: ukaž skutečnou (nesnapnutou) polohu jako kroužek + spojnici k bodu na ulici.
    if (runRef.current) {
      setSourceData(map, 'rawpos', pointFC(raw, on))
      setSourceData(map, 'rawlink', haversineM(raw, snapped) > 2 ? lineFC([raw, snapped]) : emptyFC())
    }

    // Navigace ke svému startu (než hra začne): čára + vzdálenost.
    const g = gameRef.current
    if (g && g.start_lng != null && g.start_lat != null && !liveRef.current && !eliminatedRef.current) {
      const start: [number, number] = [g.start_lng, g.start_lat]
      setNavDist(Math.round(haversineM(snapped, start)))
      setSourceData(map, 'nav', lineFC([snapped, start]))
    } else {
      setNavDist(null)
      setSourceData(map, 'nav', emptyFC())
    }

    lastSnappedRef.current = snapped
    sendPos(snapped)
  }
  processRef.current = processPosition

  // --- GPS sledování (~2 Hz) → processPosition (v simulačním módu vypnuté) ---
  useEffect(() => {
    if (!('geolocation' in navigator)) { setError('Tento prohlížeč nepodporuje geolokaci.'); return }
    let last = 0
    const id = navigator.geolocation.watchPosition(
      (pos) => {
        if (simRef.current || runRef.current) return
        const now = pos.timestamp
        if (now - last < 450) return
        last = now
        processRef.current?.([pos.coords.longitude, pos.coords.latitude], pos.coords.accuracy)
      },
      (err) => setError(`GPS chyba: ${err.message}`),
      { enableHighAccuracy: true, maximumAge: 0, timeout: 10000 },
    )
    return () => navigator.geolocation.clearWatch(id)
  }, [])

  // --- Run Hra mód: auto-pohyb řízený joystickem/klávesnicí (~12 Hz) ---
  useEffect(() => {
    const id = setInterval(() => {
      if (!runRef.current || eliminatedRef.current) return
      const dt = RUN_TICK_MS / 1000
      // Iniciální poloha = VŽDY tvůj vybraný start (Run mód GPS vůbec nepoužívá – ani brzký GPS fix
      // nesmí hodit hráče mimo mapu; proto preferuj start, ne lastSnapped).
      if (!simRawRef.current) {
        const g = gameRef.current
        const start: [number, number] | null = g && g.start_lng != null && g.start_lat != null ? [g.start_lng, g.start_lat] : null
        const init0 = start ?? lastSnappedRef.current
        if (!init0) return // počkej, až známe svůj start
        simRawRef.current = init0
        processRef.current?.(init0)
        return
      }
      // Před startem hry stojíš na svém startu a nehýbeš se (čeká se, až admin spustí).
      if (!liveRef.current) return
      // Směr: klávesnice (WASD/šipky) má přednost, jinak joystick.
      const k = keysRef.current
      let kx = 0, ky = 0
      if (k.has('a') || k.has('arrowleft')) kx -= 1
      if (k.has('d') || k.has('arrowright')) kx += 1
      if (k.has('w') || k.has('arrowup')) ky += 1
      if (k.has('s') || k.has('arrowdown')) ky -= 1
      let h = headingRef.current
      if (kx || ky) { const l = Math.hypot(kx, ky); h = { x: kx / l, y: ky / l } }
      if (!h) return // joystick puštěný = stojíš (po limitu tě vyřadí nečinnost)
      // Rychlost + stamina: sprint čerpá dosah ~sprint_range_m, dobíjení 3× déle a jen při chůzi.
      const tFull = Math.max(1, sprintRangeRef.current / Math.max(0.1, sprintMpsRef.current))
      let mode = runSpeedRef.current
      if (mode === 'sprint') {
        staminaRef.current = Math.max(0, staminaRef.current - dt / tFull)
        if (staminaRef.current <= 0) mode = 'run' // vyčerpáno → spadne na běh
      } else if (mode === 'walk') {
        staminaRef.current = Math.min(1, staminaRef.current + dt / (3 * tFull))
      }
      setStamina(Math.round(staminaRef.current * 100))
      const mps = mode === 'walk' ? walkMpsRef.current : mode === 'run' ? runMpsRef.current : sprintMpsRef.current
      const [lng, lat] = simRawRef.current
      const dM = mps * dt
      const next: [number, number] = [
        lng + (h.x * dM) / (111320 * Math.cos((lat * Math.PI) / 180)),
        lat + (h.y * dM) / 111320,
      ]
      simRawRef.current = next
      processRef.current?.(next)
    }, RUN_TICK_MS)
    return () => clearInterval(id)
  }, [])

  // Klávesnice pro Run mód (testování od stolu): WASD/šipky = směr, 1/2/3 = rychlost.
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (!runRef.current) return
      const key = e.key.toLowerCase()
      if (key === '1') setSpeed('walk')
      else if (key === '2') setSpeed('run')
      else if (key === '3') setSpeed('sprint')
      else if (['w', 'a', 's', 'd', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright'].includes(key)) {
        keysRef.current.add(key); e.preventDefault()
      }
    }
    const up = (e: KeyboardEvent) => { keysRef.current.delete(e.key.toLowerCase()) }
    window.addEventListener('keydown', down)
    window.addEventListener('keyup', up)
    return () => { window.removeEventListener('keydown', down); window.removeEventListener('keyup', up) }
  }, [])

  return (
    <>
      <div id="map" />
      <VersionBadge />

      <div className="hud">
        {phase === 'live' && <span className="pill dist">📏 trasa: {trailLen} m</span>}
        <span><b>AchtungDieKM</b></span>
        <span className="pill">přesnost: {accuracy ? `${Math.round(accuracy)} m` : '—'}</span>
        <span className="pill">ulice: {streets ?? '…'}</span>
        <span className={`pill ${onStreet ? 'ok' : 'warn'}`}>na ulici: {onStreet ? 'ano' : 'ne'}</span>
        <span className="pill">odchylka: {snap != null ? `${Math.round(snap)} m` : '—'}</span>
        <span className="pill">hráči: {others + 1}</span>
        <span className={`pill ${wakeOn ? 'ok' : 'warn'}`}>obrazovka: {wakeOn ? 'držena' : 'ne'}</span>
        {simAllowed && <button className={`pill mode ${sim ? 'active' : ''}`} onClick={toggleSim}>🧪 sim</button>}
        <Link className="pill link" to="/lobby">← lobby</Link>
        {error && <span className="pill warn">{error}</span>}
      </div>

      {/* Zoom +/- (hodí se na mobilu) */}
      <div className="zoom-ctrl">
        <button onClick={() => mapRef.current?.zoomIn()} aria-label="Přiblížit">+</button>
        <button onClick={() => mapRef.current?.zoomOut()} aria-label="Oddálit">−</button>
      </div>

      {/* Legenda (rozbalovací) */}
      <button className="legend-toggle" onClick={() => setLegendOpen((v) => !v)}>{legendOpen ? '✕ Legenda' : '📖 Legenda'}</button>
      {legendOpen && (
        <div className="legend-panel">
          <div className="legend-row"><span className="leg-dot" style={{ background: '#3fb950' }} /> tvoje poloha (na ulici)</div>
          <div className="legend-row"><span className="leg-dot" style={{ background: '#f85149' }} /> tvoje poloha (mimo ulici)</div>
          <div className="legend-row"><span className="leg-line" /> projetá stopa</div>
          <div className="legend-row">🚩 startovní bod</div>
          {runMode && <div className="legend-sep">Run hra</div>}
          {runMode && <div className="legend-row"><span className="leg-ring" /> tvoje skutečná poloha (kroužek)</div>}
          {runMode && <div className="legend-row">⌨️ PC – pohyb: <b>WASD</b> / šipky · rychlost: <b>1</b> chůze · <b>2</b> běh · <b>3</b> sprint</div>}
          {roster.length > 0 && <div className="legend-sep">Hráči a barvy</div>}
          {roster.map((p) => (
            <div className="legend-row" key={p.id}><span className="leg-dot" style={{ background: p.color }} /> {p.nick}{p.id === playerRef.current?.id ? ' (ty)' : ''}</div>
          ))}
        </div>
      )}

      {sim && <div className="sim-hint">Simulační mód: klikáním do mapy posouváš svoji polohu (test bez GPS).</div>}

      {/* Run Hra: joystick + rychlosti (až po startu – do té doby stojíš na svém startu). */}
      {runMode && !eliminatedReason && phase === 'live' && (
        <>
          <div
            className="run-joy"
            ref={joyRef}
            onPointerDown={onJoyDown}
            onPointerMove={onJoyMove}
            onPointerUp={onJoyUp}
            onPointerCancel={onJoyUp}
          >
            <div className="run-knob" style={{ transform: `translate(${knob.x}px, ${knob.y}px)` }} />
          </div>
          <div className="run-speeds">
            <div className="run-stamina"><span style={{ width: `${stamina}%` }} /></div>
            <div className="run-speed-btns">
              <button className={runSpeed === 'walk' ? 'active' : ''} onClick={() => setSpeed('walk')} title="chůze (klávesa 1) – dobíjí staminu">🚶<small>1</small></button>
              <button className={runSpeed === 'run' ? 'active' : ''} onClick={() => setSpeed('run')} title="běh (klávesa 2)">🏃<small>2</small></button>
              <button className={runSpeed === 'sprint' ? 'active' : ''} onClick={() => setSpeed('sprint')} disabled={stamina <= 0} title="sprint (klávesa 3) – čerpá staminu">⚡<small>3</small></button>
            </div>
          </div>
        </>
      )}

      {outsideLeft != null && phase === 'live' && (
        <div className="outside-warn">⚠️ Vrať se na <b>konec své stopy</b>! Vypadneš za {outsideLeft}s</div>
      )}

      {/* Čekání: banner (mapa zůstává vidět kvůli navigaci ke startu). */}
      {phase === 'waiting' && (
        <div className="wait-banner">
          {runMode ? (
            <>🚩 Jsi na startu <b>{gameRef.current?.start_label ?? ''}</b> · čeká se, až admin spustí hru</>
          ) : (
            <>🚩 Jdi na svůj start <b>{gameRef.current?.start_label ?? ''}</b>
              {navDist != null ? ` — ${navDist} m` : ''} · čeká se, až admin spustí hru</>
          )}
        </div>
      )}

      {(phase === 'countdown' || phase === 'none') && (
        <div className="game-overlay">
          {phase === 'none' && (
            <div className="game-card">
              <h1>Nejsi v žádné hře</h1>
              <Link className="big-btn" to="/lobby">Do lobby →</Link>
            </div>
          )}
          {phase === 'countdown' && (
            <div className="game-card">
              <div className="safety">⚠️ Pohybuj se opatrně, sleduj provoz a okolí. Hraješ na vlastní zodpovědnost.</div>
              <div className="countdown">{countdown}</div>
              <p>Připrav se… start!</p>
            </div>
          )}
        </div>
      )}

      {eliminatedReason && !watching && phase !== 'none' && phase !== 'ended' && (
        <div className="game-overlay">
          <div className="game-card">
            <h1>💥 Vypadl jsi!</h1>
            <p>{eliminatedReason}</p>
            <button className="big-btn" onClick={() => setWatching(true)}>Sledovat dál</button>
            <Link className="big-btn" style={{ background: '#21262d' }} to="/lobby">Do lobby →</Link>
          </div>
        </div>
      )}

      {phase === 'ended' && (() => {
        const myPlace = results.find((r) => r.player_id === playerRef.current?.id)?.place ?? null
        const won = myPlace === 1
        return (
          <div className="game-overlay">
            <div className="game-card">
              <h1>{won ? '🏆 Vyhrál jsi!' : 'Konec hry'}</h1>
              {myPlace != null && <p>{won ? 'Zůstal jsi poslední – gratulace!' : `Skončil jsi na ${myPlace}. místě.`}</p>}
              <TrailsImage
                width={380}
                height={300}
                streets={edgesRef.current.map((e) => (e.geometry as any).coordinates as [number, number][])}
                players={results.map((r) => ({ nickname: r.nickname, color: getColor(r.player_id), trail: r.trail ?? [] }))}
              />
              <ol className="results">
                {results.map((r) => (
                  <li key={r.player_id} className={r.player_id === playerRef.current?.id ? 'me' : ''}>
                    <span className="place">{r.place ?? '—'}.</span> {r.nickname}{r.place === 1 ? ' 🏆' : ''} <span className="muted">· {trailLenM(r.trail)} m</span>
                  </li>
                ))}
              </ol>
              <Link className="big-btn" to="/lobby">Do lobby →</Link>
            </div>
          </div>
        )
      })()}
    </>
  )
}
