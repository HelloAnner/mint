import { renderToStaticMarkup } from 'react-dom/server'
import type { ReactElement } from 'react'
import { buildTheme, getModeTokens, getPalette, type ThemeMode } from './palettes'
import { resolveFont, type FontChoice } from './fonts'
import { computeChartArea, extractInnerSvg, frameChart, unwrapQuotedUrlFills } from './frame'
import { rasterize } from './raster'
import { normalizeOptions, type OutputFormat } from './spec'
import type { ChartDefinition } from './types'

export interface RenderRequest {
  definition: ChartDefinition
  data: unknown
  options?: Record<string, unknown>
  title?: string
  subtitle?: string
  footnote?: string
  /** 最终图像的逻辑宽度（含留白与标题） */
  width: number
  height: number
  /** 输出倍数 */
  scale: number
  theme: ThemeMode
  palette: string
  format: OutputFormat
  font?: string
  /** 是否画一圈外描边 */
  border?: boolean
}

export interface RenderResult {
  svg: string
  png?: Uint8Array
  /** 逻辑尺寸 */
  width: number
  height: number
  /** 实际像素尺寸 */
  pixelWidth: number
  pixelHeight: number
  font: FontChoice
  chartWidth: number
  chartHeight: number
}

/**
 * React 19 下 nivo 内部会抛出与 ref、key 相关的告警，与渲染正确性无关，
 * 但会污染 CLI 输出，因此默认静音（MINT_DEBUG=1 时保留）。
 */
function renderToSvg(element: ReactElement): string {
  const debug = process.env.MINT_DEBUG === '1'
  const originalError = console.error
  const originalWarn = console.warn
  if (!debug) {
    console.error = () => {}
    console.warn = () => {}
  }
  try {
    return renderToStaticMarkup(element)
  } finally {
    console.error = originalError
    console.warn = originalWarn
  }
}

export async function renderChart(request: RenderRequest): Promise<RenderResult> {
  const { definition, data, width, height, scale, theme, format } = request

  const font = resolveFont(request.font)
  const palette = getPalette(request.palette)
  const tokens = getModeTokens(theme)
  const nivoTheme = buildTheme(theme, font.family)

  const area = computeChartArea({
    width,
    height,
    hasTitle: Boolean(request.title),
    hasSubtitle: Boolean(request.subtitle),
    hasFootnote: Boolean(request.footnote),
  })

  const options = normalizeOptions(definition, request.options)

  const element = definition.render({
    data,
    options,
    width: area.innerWidth,
    height: area.innerHeight,
    theme: nivoTheme,
    colors: [...palette.colors],
    fontFamily: font.family,
    background: tokens.background,
    foreground: tokens.foreground,
    muted: tokens.muted,
  })

  const markup = renderToSvg(element)
  const innerSvg = extractInnerSvg(markup)

  const svg = unwrapQuotedUrlFills(
    frameChart({
      ...area,
      innerSvg,
      width,
      height,
      title: request.title,
      subtitle: request.subtitle,
      footnote: request.footnote,
      background: tokens.background,
      foreground: tokens.foreground,
      muted: tokens.muted,
      fontFamily: font.family,
      border: request.border ? tokens.axisLine : undefined,
    }),
  )

  let png: Uint8Array | undefined
  if (format === 'png' || format === 'both') {
    png = await rasterize(svg, { scale, background: tokens.background, font })
  }

  return {
    svg,
    png,
    width,
    height,
    pixelWidth: Math.round(width * scale),
    pixelHeight: Math.round(height * scale),
    font,
    chartWidth: area.innerWidth,
    chartHeight: area.innerHeight,
  }
}
