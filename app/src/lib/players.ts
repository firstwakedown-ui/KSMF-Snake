// Barvy hráčů. Paleta pro 5–10 hráčů (NFR-01); přidělení podle seřazeného seznamu
// účastníků zápasu → každý klient přidělí stejně a barvy jsou zaručeně různé.
// První 4 jasné a rozlišitelné: modrá, červená, zelená, černá. Pak další pro 5–10 hráčů.
const PALETTE = [
  '#1f6feb', '#e5484d', '#2ea043', '#111111',
  '#a371f7', '#e3b341', '#ff7b72', '#56d4dd', '#ff9bce', '#bdf583', '#ffa657', '#79c0ff',
]

// Mapa id -> barva podle seřazeného seznamu id (deterministicky, distinct).
export function assignColors(ids: string[]): Map<string, string> {
  const sorted = [...ids].sort()
  const m = new Map<string, string>()
  sorted.forEach((id, i) => m.set(id, PALETTE[i % PALETTE.length]))
  return m
}

// Fallback, než dorazí seznam (hash id do palety).
export function colorFor(id: string): string {
  let h = 0
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) >>> 0
  return PALETTE[h % PALETTE.length]
}
