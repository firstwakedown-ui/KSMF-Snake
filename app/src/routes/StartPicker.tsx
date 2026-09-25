import { useEffect, useRef, useState } from 'react'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { supabase } from '../lib/supabase'
import { MAP_STYLE, BARRANDOV } from '../lib/geo'

type Pick = { start_id: string; label: string | null; lng: number | null; lat: number | null; taken: boolean; taken_by: string | null }

// Mini-mapa pro výběr startu: zelené = volné (klikni), červené = obsazené. Pod mapou i seznam (jistota).
export default function StartPicker({ gameId, planId, onJoin, onCancel }: {
  gameId: string; planId: string; onJoin: (startId: string) => void; onCancel: () => void
}) {
  const onJoinRef = useRef(onJoin)
  onJoinRef.current = onJoin
  const [rows, setRows] = useState<Pick[]>([])

  useEffect(() => {
    const map = new maplibregl.Map({ container: 'pick-map', style: MAP_STYLE, center: BARRANDOV, zoom: 15, attributionControl: false })
    let markers: maplibregl.Marker[] = []
    map.on('load', async () => {
      setTimeout(() => map.resize(), 60)
      // Ulice plánu (kontext).
      const { data: edges } = await supabase!.from('street_edges').select('geom').eq('match_id', planId).eq('enabled', true)
      const sfeats = (edges ?? []).map((r: any) => ({ type: 'Feature' as const, geometry: r.geom, properties: {} }))
      map.addSource('streets', { type: 'geojson', data: { type: 'FeatureCollection', features: sfeats } as any })
      map.addLayer({ id: 'streets-line', type: 'line', source: 'streets', paint: { 'line-color': '#f59e0b', 'line-width': 3, 'line-opacity': 0.7 } })

      // Starty jako HTML markery.
      const { data: st } = await supabase!.rpc('game_starts', { p_game: gameId })
      const pr = (st ?? []) as Pick[]
      setRows(pr)
      const pts: [number, number][] = []
      for (const s of pr) {
        if (s.lng == null || s.lat == null) continue
        pts.push([s.lng, s.lat])
        const el = document.createElement('div')
        el.className = 'pick-start' + (s.taken ? ' taken' : '')
        el.textContent = s.label ?? '?'
        el.title = s.taken ? `obsadil ${s.taken_by ?? '?'}` : 'volný – klikni'
        if (!s.taken) el.addEventListener('click', () => onJoinRef.current(s.start_id))
        markers.push(new maplibregl.Marker({ element: el }).setLngLat([s.lng, s.lat]).addTo(map))
      }
      // Přibliž na starty (ať jsou pěkně vidět).
      if (pts.length === 1) {
        map.easeTo({ center: pts[0], zoom: 16, duration: 0 })
      } else if (pts.length > 1) {
        const b = pts.reduce((bb, p) => bb.extend(p), new maplibregl.LngLatBounds(pts[0], pts[0]))
        map.fitBounds(b, { padding: 80, maxZoom: 17, duration: 0 })
      }
    })
    return () => { markers.forEach((m) => m.remove()); map.remove() }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <div className="pick">
      <div className="pick-head">
        <span>Vyber si start — <span className="ok">zelené</span> jsou volné</span>
        <button className="ghost" onClick={onCancel}>zpět</button>
      </div>
      <div id="pick-map" className="pick-map" />
      <div className="pick-list">
        {rows.map((s) => (
          <button key={s.start_id} disabled={s.taken} onClick={() => onJoin(s.start_id)} title={s.taken ? `obsadil ${s.taken_by ?? '?'}` : ''}>
            {s.label ?? '?'}{s.taken ? ' ✕' : ''}
          </button>
        ))}
        {rows.length === 0 && <span className="muted">Načítám starty…</span>}
      </div>
    </div>
  )
}
