// Načtení výsledků jedné hry pro modální okno (pořadí + barvy + stopy + ulice plánu).
// Sdílené lobby i adminem – ať se logika (a typy) neopakují na třech místech.
import { supabase } from './supabase'
import { assignColors } from './players'

export type ResultRow = { nickname: string; place: number | null; color: string; trail: [number, number][] }
export type GameResults = { rows: ResultRow[]; streets: [number, number][][] }

export async function loadGameResults(gameId: string, planId: string): Promise<GameResults> {
  if (!supabase) return { rows: [], streets: [] }
  const { data } = await supabase.rpc('game_results', { p_game: gameId })
  const raw = (data ?? []) as any[]
  const colors = assignColors(raw.map((r) => r.player_id))
  const rows: ResultRow[] = raw.map((r) => ({
    nickname: r.nickname,
    place: r.place,
    color: colors.get(r.player_id) ?? '#888',
    trail: r.trail ?? [],
  }))
  const { data: edges } = await supabase.from('street_edges').select('geom').eq('match_id', planId).eq('enabled', true)
  const streets = (edges ?? []).map((r: any) => r.geom.coordinates as [number, number][])
  return { rows, streets }
}
