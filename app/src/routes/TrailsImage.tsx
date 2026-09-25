import { useState } from 'react'
import { createPortal } from 'react-dom'

type LL = [number, number]

// Statický obrázek tras (SVG) – ulice šedě, stopy hráčů barevně. Bez mapy (žádné GL problémy).
// Klik na obrázek → zvětšení přes celou obrazovku (lupička).
export default function TrailsImage({ streets, players, width = 320, height = 240 }: {
  streets: LL[][]
  players: { nickname: string; color: string; trail: LL[] }[]
  width?: number
  height?: number
}) {
  const [zoomed, setZoomed] = useState(false)

  const all: LL[] = [...streets.flat(), ...players.flatMap((p) => p.trail || [])]
  if (all.length < 2) return <div className="muted" style={{ padding: 12 }}>Žádné trasy k zobrazení.</div>

  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
  for (const [x, y] of all) {
    if (x < minX) minX = x; if (x > maxX) maxX = x
    if (y < minY) minY = y; if (y > maxY) maxY = y
  }
  const pad = 10
  const latRad = ((minY + maxY) / 2) * Math.PI / 180
  const spanX = (maxX - minX) * Math.cos(latRad)
  const spanY = (maxY - minY)
  const s = Math.min((width - 2 * pad) / (spanX || 1e-9), (height - 2 * pad) / (spanY || 1e-9))
  const w = spanX * s, h = spanY * s
  const ox = (width - w) / 2, oy = (height - h) / 2
  const proj = ([x, y]: LL): [number, number] => [
    ox + (x - minX) * Math.cos(latRad) * s,
    oy + (maxY - y) * s, // sever nahoru
  ]
  const toPath = (coords: LL[]) =>
    coords.map((c, i) => { const [px, py] = proj(c); return (i ? 'L' : 'M') + px.toFixed(1) + ' ' + py.toFixed(1) }).join(' ')

  const svg = (
    <svg className="trails-svg" width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
      <rect x={0} y={0} width={width} height={height} fill="#eef2f6" rx={8} />
      {streets.map((st, i) => st.length >= 2 && <path key={'s' + i} d={toPath(st)} stroke="#c2cad3" strokeWidth={1.5} fill="none" />)}
      {players.map((p, i) => (p.trail?.length ?? 0) >= 2 && (
        <path key={'p' + i} d={toPath(p.trail)} stroke={p.color} strokeWidth={3.5} fill="none" strokeLinejoin="round" strokeLinecap="round" />
      ))}
    </svg>
  )

  return (
    <>
      <div className="trails-thumb" title="Klikni pro zvětšení" onClick={() => setZoomed(true)}>{svg}</div>
      {/* Portal do <body> – uniká containing-blocku modalu (backdrop-filter) → skutečný fullscreen. */}
      {zoomed && createPortal(
        <div className="img-zoom" onClick={() => setZoomed(false)}>
          <div className="img-zoom-box">{svg}</div>
          <div className="img-zoom-hint">Klikni pro zavření</div>
        </div>,
        document.body,
      )}
    </>
  )
}
