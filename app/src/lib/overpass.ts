// Živé vyhledání ulic v nakreslené oblasti z OpenStreetMap přes Overpass API.
// Overpass podporuje CORS → voláme přímo z prohlížeče. Drivová síť (osy silnic, ne chodníky).
import { booleanIntersects, lineString, polygon as turfPolygon } from '@turf/turf'

export type FetchedStreet = {
  name: string | null
  enabled: boolean // true = uvnitř oblasti (v plánu), false = okolní kontext (zašedlé)
  is_foot: boolean // true = pěší cesta (chodník mezi domy), false = silnice
  geom: { type: 'LineString'; coordinates: [number, number][] }
}

// Veřejné Overpass instance (zkoušíme postupně, kdyby jedna nestíhala/byla blokovaná).
const ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.openstreetmap.fr/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
]

// Drivová síť (osy silnic; jedna čára na ulici).
const DRIVE_RE = '^(trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|road)(_link)?$'
// Pěší cesty mezi domy (footway/path/pedestrian/steps) – pro hustší síť.
const FOOT_RE = '^(footway|path|pedestrian|steps)$'

// bbox [west, south, east, north] z polygonu, mírně rozšířený (kontext okolních ulic).
function paddedBBox(poly: [number, number][]): [number, number, number, number] {
  let west = Infinity, south = Infinity, east = -Infinity, north = -Infinity
  for (const [lng, lat] of poly) {
    if (lng < west) west = lng
    if (lng > east) east = lng
    if (lat < south) south = lat
    if (lat > north) north = lat
  }
  const padX = (east - west) * 0.12 || 0.001
  const padY = (north - south) * 0.12 || 0.001
  return [west - padX, south - padY, east + padX, north + padY]
}

const FOOT_TEST = new RegExp(FOOT_RE)

// Vždy stáhne silnice i samostatné chodníky (mezi domy). Chodníky podél silnic
// (footway=sidewalk/crossing) vyloučí, aby se nezdvojovaly s ulicemi.
// Příznak is_foot necháme na klientovi – aktivaci/deaktivaci chodníků řeší přepínač v plánu.
export async function fetchStreetsInPolygon(poly: [number, number][]): Promise<FetchedStreet[]> {
  const [west, south, east, north] = paddedBBox(poly)
  const bbox = `${south},${west},${north},${east}`
  const query = `[out:json][timeout:25];
(
  way["highway"~"${DRIVE_RE}"](${bbox});
  way["highway"~"${FOOT_RE}"]["footway"!="sidewalk"]["footway"!="crossing"](${bbox});
);
out geom;`

  const json = await runOverpass(query)
  // Polygon pro klasifikaci uvnitř/okolí (uzavřený prstenec).
  const ring: [number, number][] = [...poly, poly[0]]
  const areaPoly = turfPolygon([ring])

  const out: FetchedStreet[] = []
  for (const el of json.elements ?? []) {
    if (el.type !== 'way' || !el.geometry) continue
    const coords = el.geometry.map((g: any) => [g.lon, g.lat] as [number, number])
    if (coords.length < 2) continue
    let inside = false
    try {
      inside = booleanIntersects(lineString(coords), areaPoly)
    } catch {
      inside = false
    }
    out.push({
      name: el.tags?.name ?? null,
      enabled: inside,
      is_foot: FOOT_TEST.test(el.tags?.highway ?? ''),
      geom: { type: 'LineString', coordinates: coords },
    })
  }
  return out
}

async function runOverpass(query: string): Promise<any> {
  let lastErr: any = null
  for (const url of ENDPOINTS) {
    try {
      const ctrl = new AbortController()
      const t = setTimeout(() => ctrl.abort(), 30000)
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'data=' + encodeURIComponent(query),
        signal: ctrl.signal,
      })
      clearTimeout(t)
      if (!res.ok) throw new Error(`Overpass ${res.status}`)
      return await res.json()
    } catch (e) {
      lastErr = e
    }
  }
  throw new Error(`Overpass nedostupný: ${lastErr?.message ?? lastErr}`)
}
