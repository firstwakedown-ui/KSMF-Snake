// Kolizní logika hry (klientská, fáze 3a).
// Stopy jsou přichycené na osu ulice → kolize = BLÍZKOST k existující stopě (ne jen křížení),
// takže „projetým úsekem už nikdo neprojede". Výjimka: u uzlu (křižovatka) se smí prokřížit.
export type LngLat = [number, number]

const R = 6371000 // m

export function haversineM(a: LngLat, b: LngLat): number {
  const toRad = Math.PI / 180
  const dLat = (b[1] - a[1]) * toRad
  const dLng = (b[0] - a[0]) * toRad
  const lat1 = a[1] * toRad
  const lat2 = b[1] * toRad
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(x)))
}

// Délka stopy v metrech (součet vzdáleností mezi body).
export function trailLenM(trail: LngLat[] | null | undefined): number {
  if (!trail || trail.length < 2) return 0
  let d = 0
  for (let i = 1; i < trail.length; i++) d += haversineM(trail[i - 1], trail[i])
  return Math.round(d)
}

// Lokální převod na metry kolem počátku (equirektangulární, pro malé vzdálenosti přesné).
function toXY(p: LngLat, origin: LngLat): [number, number] {
  const toRad = Math.PI / 180
  return [(p[0] - origin[0]) * toRad * R * Math.cos(origin[1] * toRad), (p[1] - origin[1]) * toRad * R]
}

function segDist2D(px: number, py: number, ax: number, ay: number, bx: number, by: number): number {
  const dx = bx - ax, dy = by - ay
  const len2 = dx * dx + dy * dy
  let t = len2 > 0 ? ((px - ax) * dx + (py - ay) * dy) / len2 : 0
  t = Math.max(0, Math.min(1, t))
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy))
}

export type CollisionOpts = { epsM: number; parallelCos: number }

// Nejbližší vzdálenost bodu od lomené čáry + směr (jednotkový) nejbližšího segmentu (lokální metry).
function nearestSeg(p: LngLat, trail: LngLat[]): { dist: number; dirx: number; diry: number } {
  if (trail.length < 2) return { dist: Infinity, dirx: 0, diry: 0 }
  let best = Infinity, bdx = 0, bdy = 0
  let prev = toXY(trail[0], p)
  for (let i = 1; i < trail.length; i++) {
    const cur = toXY(trail[i], p)
    const d = segDist2D(0, 0, prev[0], prev[1], cur[0], cur[1])
    if (d < best) {
      best = d
      const dx = cur[0] - prev[0], dy = cur[1] - prev[1]
      const len = Math.hypot(dx, dy) || 1
      bdx = dx / len; bdy = dy / len
    }
    prev = cur
  }
  return { dist: best, dirx: bdx, diry: bdy }
}

// Vrátí true = náraz (vyřazení). Blízkost ke stopě + směr pohybu ROVNOBĚŽNÝ se stopou = vjetí/couvání do stopy.
// KOLMÝ směr (prokřížení na křižovatce) se NEpočítá jako náraz (FR-07). Tím odpadá závislost na „okolí uzlu".
export function checkCollision(
  pos: LngLat,
  prevPos: LngLat | null,
  ownTrailToCheck: LngLat[],
  otherTrails: LngLat[][],
  opts: CollisionOpts,
): boolean {
  if (!prevPos) return false
  // Směr pohybu (lokální metry, equirektangulárně).
  const hx0 = (pos[0] - prevPos[0]) * Math.cos((pos[1] * Math.PI) / 180)
  const hy0 = pos[1] - prevPos[1]
  const hlen = Math.hypot(hx0, hy0)
  if (hlen < 1e-9) return false // bez pohybu nevyhodnocujeme
  const hx = hx0 / hlen, hy = hy0 / hlen
  const hit = (trail: LngLat[]): boolean => {
    const r = nearestSeg(pos, trail)
    if (r.dist >= opts.epsM) return false
    const dot = Math.abs(hx * r.dirx + hy * r.diry) // 1 = rovnoběžně, 0 = kolmo
    return dot >= opts.parallelCos
  }
  for (const t of otherTrails) if (hit(t)) return true
  return hit(ownTrailToCheck)
}
