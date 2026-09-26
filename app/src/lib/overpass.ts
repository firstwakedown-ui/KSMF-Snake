// Živé vyhledání ulic v nakreslené oblasti z OpenStreetMap přes Overpass API.
// Overpass podporuje CORS → voláme přímo z prohlížeče. Drivová síť (osy silnic, ne chodníky).
import { booleanIntersects, lineString, polygon as turfPolygon } from '@turf/turf'

export type FetchedStreet = {
  name: string | null
  enabled: boolean // true = uvnitř oblasti (v plánu), false = okolní kontext (zašedlé)
  is_foot: boolean // true = pěší cesta (chodník mezi domy), false = silnice
  geom: { type: 'LineString'; coordinates: [number, number][] }
}

// Přímá záloha pro lokální vývoj. V produkci dotaz obsluhuje /api/overpass,
// protože veřejné instance bývají přetížené a některé omezují požadavky z prohlížeče.
const ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
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

  const json = await runOverpass(query, bbox)
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

async function fetchWithTimeout(url: string, timeoutMs: number): Promise<Response> {
  const ctrl = new AbortController()
  const timer = window.setTimeout(() => ctrl.abort(), timeoutMs)
  try {
    return await fetch(url, { headers: { Accept: 'application/json' }, signal: ctrl.signal })
  } finally {
    window.clearTimeout(timer)
  }
}

async function runOverpass(query: string, bbox: string): Promise<any> {
  // Vlastní Vercel funkce zkouší více poskytovatelů a neposílá klientům cizí CORS požadavky.
  try {
    const res = await fetchWithTimeout(`/api/overpass?bbox=${encodeURIComponent(bbox)}`, 35000)
    if (!res.ok) throw new Error(`služba odpověděla ${res.status}`)
    return await res.json()
  } catch {
    // Záloha zachovává funkčnost při lokálním vývoji i při dočasném problému funkce.
  }

  const errors: string[] = []
  for (const url of ENDPOINTS) {
    try {
      const res = await fetchWithTimeout(`${url}?data=${encodeURIComponent(query)}`, 20000)
      if (!res.ok) throw new Error(`Overpass ${res.status}`)
      return await res.json()
    } catch (e: any) {
      errors.push(e?.name === 'AbortError' ? 'vypršel časový limit' : (e?.message ?? String(e)))
    }
  }
  throw new Error(`Mapová služba je dočasně přetížená (${errors.join(', ')}). Zkus hledání znovu za chvíli.`)
}
