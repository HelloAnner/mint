import { fail } from './errors'
import { DEFAULT_PALETTE, PALETTES, type ThemeMode } from './palettes'
import type { ChartDefinition, OptionSpec } from './types'

export type OutputFormat = 'png' | 'svg' | 'both'

export interface MintSpec {
  chart: string
  data: unknown
  title?: string
  subtitle?: string
  footnote?: string
  width: number
  height: number
  scale: number
  theme: ThemeMode
  palette: string
  format: OutputFormat
  font?: string
  options: Record<string, unknown>
}

export const SPEC_DEFAULTS = {
  width: 1280,
  height: 760,
  scale: 2,
  theme: 'light' as ThemeMode,
  palette: DEFAULT_PALETTE,
  format: 'png' as OutputFormat,
}

function asNumber(value: unknown, fallback: number, field: string): number {
  if (value === undefined || value === null || value === '') return fallback
  const n = typeof value === 'number' ? value : Number(value)
  if (!Number.isFinite(n)) {
    fail('INVALID_SPEC', `${field} 必须是数字，收到 ${JSON.stringify(value)}`)
  }
  return n
}

function asTheme(value: unknown): ThemeMode {
  if (value === undefined || value === null) return SPEC_DEFAULTS.theme
  if (value === 'light' || value === 'dark') return value
  fail('INVALID_SPEC', `theme 只能是 light 或 dark，收到 ${JSON.stringify(value)}`)
}

function asFormat(value: unknown): OutputFormat {
  if (value === undefined || value === null) return SPEC_DEFAULTS.format
  if (value === 'png' || value === 'svg' || value === 'both') return value
  fail('INVALID_SPEC', `format 只能是 png / svg / both，收到 ${JSON.stringify(value)}`)
}

function asPalette(value: unknown): string {
  if (value === undefined || value === null || value === '') return SPEC_DEFAULTS.palette
  const id = String(value)
  if (!PALETTES.some((p) => p.id === id)) {
    fail('INVALID_SPEC', `未知调色板：${id}`, `可选：${PALETTES.map((p) => p.id).join(', ')}`)
  }
  return id
}

/** 图表选项的默认值，来自 ChartDefinition.options。 */
export function optionDefaults(definition: ChartDefinition): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  for (const spec of definition.options ?? []) {
    if (spec.default !== undefined) out[spec.key] = spec.default
  }
  return out
}

/** 把数据生硬地转成期望类型，做尽可能友好的容错。 */
function coerceOption(value: unknown, spec: OptionSpec): unknown {
  switch (spec.type) {
    case 'number':
      if (typeof value === 'number') return value
      if (typeof value === 'string' && value.trim() !== '' && Number.isFinite(Number(value))) return Number(value)
      return value
    case 'boolean':
      if (typeof value === 'boolean') return value
      if (value === 'true') return true
      if (value === 'false') return false
      return value
    case 'array':
      if (Array.isArray(value)) return value
      if (typeof value === 'string') return value.split(',').map((s) => s.trim()).filter(Boolean)
      return value
    default:
      return value
  }
}

/** 校验并补全选项。未知键直接透传给图表，方便用 nivo 原生能力兜底。 */
export function normalizeOptions(
  definition: ChartDefinition,
  raw: Record<string, unknown> | undefined,
): Record<string, unknown> {
  const merged = { ...optionDefaults(definition), ...(raw ?? {}) }
  for (const spec of definition.options ?? []) {
    if (merged[spec.key] !== undefined) {
      merged[spec.key] = coerceOption(merged[spec.key], spec)
    }
  }
  return merged
}

export function normalizeSpec(raw: Record<string, unknown>): Omit<MintSpec, 'chart'> & { chart: string } {
  if (!raw || typeof raw !== 'object') {
    fail('INVALID_SPEC', 'spec 必须是一个 JSON 对象')
  }
  const chart = raw.chart
  if (typeof chart !== 'string' || chart.trim() === '') {
    fail('INVALID_SPEC', 'spec 缺少 chart 字段', '用 mint list 查看所有可用的图表 id')
  }

  if (raw.data === undefined) {
    fail('INVALID_SPEC', 'spec 缺少 data 字段', `用 mint info ${chart} 查看该图表需要的数据结构`)
  }

  return {
    chart: chart.trim(),
    data: raw.data,
    title: typeof raw.title === 'string' ? raw.title : undefined,
    subtitle: typeof raw.subtitle === 'string' ? raw.subtitle : undefined,
    footnote: typeof raw.footnote === 'string' ? raw.footnote : undefined,
    width: Math.round(asNumber(raw.width, SPEC_DEFAULTS.width, 'width')),
    height: Math.round(asNumber(raw.height, SPEC_DEFAULTS.height, 'height')),
    scale: asNumber(raw.scale, SPEC_DEFAULTS.scale, 'scale'),
    theme: asTheme(raw.theme),
    palette: asPalette(raw.palette),
    format: asFormat(raw.format),
    font: typeof raw.font === 'string' ? raw.font : undefined,
    options: (raw.options as Record<string, unknown>) ?? {},
  }
}

export function assertPositive(value: number, field: string): void {
  if (!(value > 0)) fail('INVALID_SPEC', `${field} 必须大于 0`)
}
