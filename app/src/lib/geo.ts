// Sdílené konstanty a GeoJSON helpery pro hráče i admina.
import type maplibregl from 'maplibre-gl'
import type { Feature, Point as GjPoint } from 'geojson'

// Střed Prahy–Barrandova – výchozí pohled mapy (MVP).
export const BARRANDOV: [number, number] = [14.37035, 50.02915]
// Hrací oblast (bbox grafu) – mapu na ni naroamujeme, ať je vidět celá síť ulic.
export const BARRANDOV_BBOX: [[number, number], [number, number]] = [
  [14.3625, 50.0248],
  [14.3782, 50.0335],
]
// Mapový styl (OpenFreeMap, bez klíče).
export const MAP_STYLE = 'https://tiles.openfreemap.org/styles/liberty'

// Verze aplikace (odpovídá etapě deníku) – zobrazená v rohu. Bumpovat při větších změnách.
export const APP_VERSION = 'v2.8.8-snake'

// Zapíše data do GeoJSON zdroje mapy (centralizuje opakovaný `as GeoJSONSource` cast).
// Bezpečné i když mapa/zdroj ještě neexistují (no-op).
export function setSourceData(
  map: maplibregl.Map | null | undefined,
  id: string,
  data: Parameters<maplibregl.GeoJSONSource['setData']>[0],
) {
  ;(map?.getSource(id) as maplibregl.GeoJSONSource | undefined)?.setData(data)
}

// --- Pomocné GeoJSON ---
export function emptyFC() {
  return { type: 'FeatureCollection' as const, features: [] }
}
export function lineFC(coords: [number, number][]) {
  return {
    type: 'FeatureCollection' as const,
    features: [
      { type: 'Feature' as const, geometry: { type: 'LineString' as const, coordinates: coords }, properties: {} },
    ],
  }
}
export function pointFC(coord: [number, number], on: boolean) {
  return {
    type: 'FeatureCollection' as const,
    features: [
      { type: 'Feature' as const, geometry: { type: 'Point' as const, coordinates: coord }, properties: { on } },
    ],
  }
}
// Sada bodů s popiskem (startovní body).
export function pointsFC(items: { id: string; label: string; coord: [number, number] }[]) {
  return {
    type: 'FeatureCollection' as const,
    features: items.map(
      (it): Feature<GjPoint> => ({
        type: 'Feature',
        geometry: { type: 'Point', coordinates: it.coord },
        properties: { id: it.id, label: it.label },
      }),
    ),
  }
}
