const ENDPOINTS = [
  'https://overpass.private.coffee/api/interpreter',
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
]

const DRIVE_RE = '^(trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|road)(_link)?$'
const FOOT_RE = '^(footway|path|pedestrian|steps)$'

function parseBbox(value) {
  const parts = String(value ?? '').split(',').map(Number)
  if (parts.length !== 4 || parts.some((n) => !Number.isFinite(n))) return null
  const [south, west, north, east] = parts
  if (south < -90 || north > 90 || west < -180 || east > 180 || south >= north || west >= east) return null
  // Ochrana veřejného proxy: herní plán smí pokrýt nejvýše přibližně 25 km².
  if ((north - south) * (east - west) > 0.003) return null
  return parts.join(',')
}

async function requestEndpoint(url, query) {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), 28000)
  try {
    const response = await fetch(`${url}?data=${encodeURIComponent(query)}`, {
      headers: {
        Accept: 'application/json',
        'User-Agent': 'KSMF-Snake/2.0 (https://ksmfsnake.vercel.app)',
      },
      signal: ctrl.signal,
    })
    if (!response.ok) throw new Error(`${response.status}`)
    return await response.json()
  } finally {
    clearTimeout(timer)
  }
}

export default async function handler(request, response) {
  if (request.method !== 'GET') return response.status(405).json({ error: 'Method not allowed' })

  const bbox = parseBbox(request.query.bbox)
  if (!bbox) return response.status(400).json({ error: 'Neplatná nebo příliš velká oblast.' })

  const query = `[out:json][timeout:25];
(
  way["highway"~"${DRIVE_RE}"](${bbox});
  way["highway"~"${FOOT_RE}"]["footway"!="sidewalk"]["footway"!="crossing"](${bbox});
);
out geom;`

  try {
    const data = await Promise.any(ENDPOINTS.map((url) => requestEndpoint(url, query)))
    response.setHeader('Cache-Control', 's-maxage=300, stale-while-revalidate=3600')
    return response.status(200).json(data)
  } catch {
    return response.status(503).json({ error: 'Veřejné mapové servery jsou dočasně přetížené.' })
  }
}
