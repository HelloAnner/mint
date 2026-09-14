import { fail } from './errors'

/** 画布留白与标题排版参数（单位：px，针对最终图像的逻辑尺寸） */
export const LAYOUT = {
  padX: 40,
  padTop: 36,
  padBottom: 34,
  titleSize: 26,
  titleLine: 34,
  subtitleSize: 14,
  subtitleLine: 20,
  titleSubtitleGap: 7,
  headerGap: 22,
  footnoteSize: 12,
  footnoteLine: 18,
  footnoteGap: 14,
  minChartHeight: 80,
} as const

export function escapeXml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
}

/**
 * nivo 的 SvgWrapper 会在最外层包一个 div，resvg 需要以 <svg> 为根节点，
 * 因此这里把内部片段摘出来。
 */
export function extractInnerSvg(markup: string): string {
  const start = markup.indexOf('<svg')
  const end = markup.lastIndexOf('</svg>')
  if (start === -1 || end === -1) {
    fail('RENDER_FAILED', '图表没有渲染出 SVG 根节点', '这通常是图表数据为空或结构不符合要求导致的')
  }
  const openTagEnd = markup.indexOf('>', start)
  return markup.slice(openTagEnd + 1, end)
}

/**
 * nivo 的桑基流等手写 fill="url("#id")"，React 序列化后引号变成 &quot;，
 * resvg 解析不了带引号的 url() 引用（会退化成黑色填充），这里统一还原。
 */
export function unwrapQuotedUrlFills(svg: string): string {
  return svg.replace(/url\(&quot;#([^&]+?)&quot;\)/g, 'url(#$1)')
}

export interface ChartArea {
  innerWidth: number
  innerHeight: number
  headerHeight: number
  footerHeight: number
}

export function computeChartArea(input: {
  width: number
  height: number
  hasTitle: boolean
  hasSubtitle: boolean
  hasFootnote: boolean
}): ChartArea {
  const L = LAYOUT
  let header = 0
  if (input.hasTitle) header += L.titleLine
  if (input.hasSubtitle) header += (input.hasTitle ? L.titleSubtitleGap : 0) + L.subtitleLine
  if (header > 0) header += L.headerGap

  const footer = input.hasFootnote ? L.footnoteGap + L.footnoteLine : 0

  const innerWidth = Math.round(input.width - L.padX * 2)
  const innerHeight = Math.round(input.height - L.padTop - L.padBottom - header - footer)

  if (innerWidth < 120 || innerHeight < L.minChartHeight) {
    fail(
      'CANVAS_TOO_SMALL',
      `画布太小，图表区域仅 ${innerWidth}×${innerHeight}px`,
      '用 --width / --height 增大画布，或去掉标题留出更多空间',
    )
  }

  return { innerWidth, innerHeight, headerHeight: header, footerHeight: footer }
}

export interface FrameInput extends ChartArea {
  innerSvg: string
  width: number
  height: number
  title?: string
  subtitle?: string
  footnote?: string
  background: string
  foreground: string
  muted: string
  fontFamily: string
  /** 外框圆角，0 表示直角 */
  radius?: number
  /** 是否描边 */
  border?: string
}

/** 把图表 SVG 嵌进一张带标题、副标题与脚注的卡片里，输出最终 SVG。 */
export function frameChart(input: FrameInput): string {
  const L = LAYOUT
  const { width, height, background, foreground, muted, fontFamily } = input
  const radius = input.radius ?? 0

  const parts: string[] = []

  parts.push(
    `<rect x="0" y="0" width="${width}" height="${height}" rx="${radius}" ry="${radius}" fill="${background}"/>`,
  )
  if (input.border) {
    parts.push(
      `<rect x="0.5" y="0.5" width="${width - 1}" height="${height - 1}" rx="${radius}" ry="${radius}" fill="none" stroke="${input.border}" stroke-width="1"/>`,
    )
  }

  let cursor = L.padTop

  if (input.title) {
    cursor += L.titleSize
    parts.push(
      `<text x="${L.padX}" y="${cursor}" font-family="${escapeXml(fontFamily)}" font-size="${L.titleSize}" font-weight="700" letter-spacing="-0.015em" fill="${foreground}">${escapeXml(input.title)}</text>`,
    )
    cursor += L.titleLine - L.titleSize
  }

  if (input.subtitle) {
    if (input.title) cursor += L.titleSubtitleGap
    cursor += L.subtitleSize
    parts.push(
      `<text x="${L.padX}" y="${cursor}" font-family="${escapeXml(fontFamily)}" font-size="${L.subtitleSize}" font-weight="400" fill="${muted}">${escapeXml(input.subtitle)}</text>`,
    )
    cursor += L.subtitleLine - L.subtitleSize
  }

  const chartTop = L.padTop + input.headerHeight
  parts.push(
    `<g transform="translate(${L.padX}, ${chartTop})">${input.innerSvg}</g>`,
  )

  if (input.footnote) {
    const footnoteY = height - L.padBottom - L.footnoteLine + L.footnoteSize
    parts.push(
      `<text x="${L.padX}" y="${footnoteY}" font-family="${escapeXml(fontFamily)}" font-size="${L.footnoteSize}" font-weight="400" fill="${muted}">${escapeXml(input.footnote)}</text>`,
    )
  }

  return [
    `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">`,
    parts.join(''),
    '</svg>',
  ].join('')
}
