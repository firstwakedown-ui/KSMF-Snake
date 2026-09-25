// Vytvoří DOM element pro startovní bod (HTML marker nad mapou – vlaječka s číslem).
export function startMarkerEl(label: string): HTMLDivElement {
  const el = document.createElement('div')
  el.className = 'start-marker'
  const flag = document.createElement('span')
  flag.className = 'start-flag'
  flag.textContent = '🚩'
  const num = document.createElement('span')
  num.className = 'start-num'
  num.textContent = label || ''
  el.append(flag, num)
  return el
}
