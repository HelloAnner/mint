/**
 * 自绘图表（架构图 / 流程图 / 时序图等）共用的几何与排版小工具。
 * 全部不依赖 React，方便单测与复用。
 */

export interface Point {
  x: number
  y: number
}

export function round(value: number): number {
  return Math.round(value * 10) / 10
}

/**
 * 按字符宽度估算文本宽度：CJK 约 1em/字，ASCII 约 0.56em/字，
 * 和 common.ts 里 legendItemWidth 的口径一致。
 */
export function textWidth(text: string, fontSize: number): number {
  let width = 0
  for (const ch of text) {
    if (/[\u2E80-\uFFFF]/.test(ch)) width += fontSize
    else if (ch === ' ') width += fontSize * 0.3
    else width += fontSize * 0.56
  }
  return width
}

export function ellipsize(text: string, maxWidth: number, fontSize: number): string {
  if (textWidth(text, fontSize) <= maxWidth) return text
  let out = ''
  for (const ch of text) {
    if (textWidth(out + ch + '…', fontSize) > maxWidth) break
    out += ch
  }
  return out === '' ? '…' : out + '…'
}

/** 由背景色亮度判断深浅主题。 */
export function isDarkBackground(color: string): boolean {
  const hex = color.replace('#', '')
  const full = hex.length === 3 ? hex.split('').map((c) => c + c).join('') : hex
  if (full.length < 6) return false
  const r = parseInt(full.slice(0, 2), 16)
  const g = parseInt(full.slice(2, 4), 16)
  const b = parseInt(full.slice(4, 6), 16)
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255 < 0.5
}

/**
 * 箭头直接用多边形画，不用 <marker>：resvg 对 marker 的支持有边界，
 * 自算三角形可以保证光栅化结果和浏览器里一致。
 */
export function arrowPoints(tip: Point, dir: Point, size: number): string {
  const length = Math.hypot(dir.x, dir.y) || 1
  const ux = dir.x / length
  const uy = dir.y / length
  const baseX = tip.x - ux * size
  const baseY = tip.y - uy * size
  const half = size * 0.46
  const nx = -uy * half
  const ny = ux * half
  return `${round(tip.x)},${round(tip.y)} ${round(baseX + nx)},${round(baseY + ny)} ${round(baseX - nx)},${round(baseY - ny)}`
}

/** 开口箭头（两条短线组成 V），时序图里表示返回消息。 */
export function openArrowPoints(tip: Point, dir: Point, size: number): string {
  const length = Math.hypot(dir.x, dir.y) || 1
  const ux = dir.x / length
  const uy = dir.y / length
  const nx = -uy
  const ny = ux
  const backX = tip.x - ux * size
  const backY = tip.y - uy * size
  const wing = size * 0.62
  return [
    `${round(tip.x - ux * 0 + nx * wing)},${round(tip.y + ny * wing)}`,
    `${round(backX)},${round(backY)}`,
    `${round(tip.x - nx * wing)},${round(tip.y - ny * wing)}`,
  ].join(' ')
}

export function midpoint(a: Point, b: Point): Point {
  return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }
}

/** 三次贝塞尔在 t=0.5 处的点，用来把标签压在曲线正中间。 */
export function bezierMid(p0: Point, p1: Point, p2: Point, p3: Point): Point {
  return {
    x: (p0.x + 3 * p1.x + 3 * p2.x + p3.x) / 8,
    y: (p0.y + 3 * p1.y + 3 * p2.y + p3.y) / 8,
  }
}
