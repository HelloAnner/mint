import type { PartialTheme } from '@nivo/theming'

export type ThemeMode = 'light' | 'dark'

export interface Palette {
  id: string
  name: string
  description: string
  colors: readonly string[]
}

/**
 * 调色板。每个都控制在 8 色以内且明度分布均匀，保证同屏多系列仍然可区分，
 * 打印成灰度后也能拉开层次。
 */
export const PALETTES: readonly Palette[] = [
  {
    id: 'mint',
    name: '薄荷',
    description: '青绿主色，清爽、适合增长与产品类数据',
    colors: ['#0d9488', '#14b8a6', '#38bdf8', '#6366f1', '#a855f7', '#f59e0b', '#f43f5e', '#64748b'],
  },
  {
    id: 'indigo',
    name: '靛蓝',
    description: '偏商务的蓝紫主色，适合报告与汇报',
    colors: ['#4f46e5', '#6366f1', '#818cf8', '#0ea5e9', '#22d3ee', '#f59e0b', '#f43f5e', '#94a3b8'],
  },
  {
    id: 'sunset',
    name: '日落',
    description: '暖色渐变，适合营销与创意主题',
    colors: ['#f97316', '#f59e0b', '#f43f5e', '#ec4899', '#a855f7', '#6366f1', '#0ea5e9', '#84cc16'],
  },
  {
    id: 'ocean',
    name: '海洋',
    description: '冷色系，适合流量、渠道与地理数据',
    colors: ['#0369a1', '#0284c7', '#0ea5e9', '#38bdf8', '#22d3ee', '#14b8a6', '#6366f1', '#94a3b8'],
  },
  {
    id: 'forest',
    name: '森林',
    description: '自然绿色系，适合生态、健康与可持续主题',
    colors: ['#166534', '#15803d', '#22c55e', '#84cc16', '#eab308', '#14b8a6', '#0ea5e9', '#78716c'],
  },
  {
    id: 'candy',
    name: '糖果',
    description: '高饱和糖果色，适合面向大众的轻量内容',
    colors: ['#ec4899', '#8b5cf6', '#3b82f6', '#06b6d4', '#10b981', '#f59e0b', '#ef4444', '#a3a3a3'],
  },
  {
    id: 'mono',
    name: '单色',
    description: '同色系灰阶，适合黑白印刷或极简报告',
    colors: ['#0f172a', '#334155', '#475569', '#64748b', '#94a3b8', '#cbd5e1', '#e2e8f0', '#f1f5f9'],
  },
]

export const DEFAULT_PALETTE = 'mint'

export function getPalette(id?: string): Palette {
  const found = PALETTES.find((p) => p.id === id)
  return found ?? PALETTES[0]
}

interface ModeTokens {
  background: string
  foreground: string
  muted: string
  axisLine: string
  gridLine: string
  tickText: string
  domainLine: string
}

const MODES: Record<ThemeMode, ModeTokens> = {
  light: {
    background: '#ffffff',
    foreground: '#0f172a',
    muted: '#64748b',
    axisLine: '#dbe3ec',
    gridLine: '#eef2f7',
    tickText: '#7c8aa0',
    domainLine: '#dbe3ec',
  },
  dark: {
    background: '#0f172a',
    foreground: '#f1f5f9',
    muted: '#94a3b8',
    axisLine: '#334155',
    gridLine: '#1e293b',
    tickText: '#94a3b8',
    domainLine: '#334155',
  },
}

function clamp255(value: number): number {
  return Math.max(0, Math.min(255, Math.round(value)))
}

/** 在 sRGB 空间把颜色与白色按比例混合。amount=0 为白色，1 为原色。 */
export function tint(hex: string, amount: number): string {
  const normalized = hex.replace('#', '')
  const full = normalized.length === 3 ? normalized.split('').map((c) => c + c).join('') : normalized
  const r = parseInt(full.slice(0, 2), 16)
  const g = parseInt(full.slice(2, 4), 16)
  const b = parseInt(full.slice(4, 6), 16)
  const mix = (c: number) => clamp255(255 - (255 - c) * amount)
  return `#${[mix(r), mix(g), mix(b)].map((c) => c.toString(16).padStart(2, '0')).join('')}`
}

/** 由主色生成由浅到深的同色阶梯，用于热力图、日历图这类顺序色阶。 */
export function tintRamp(color: string, steps = 5): string[] {
  return Array.from({ length: steps }, (_, i) => tint(color, 0.18 + (i / (steps - 1)) * 0.82))
}

export function getModeTokens(mode: ThemeMode): ModeTokens {
  return MODES[mode] ?? MODES.light
}

/** 构造 nivo 主题：统一的网格、坐标轴、图例与标签样式。 */
export function buildTheme(mode: ThemeMode, fontFamily: string): PartialTheme {
  const t = getModeTokens(mode)
  return {
    background: 'transparent',
    text: {
      fontFamily,
      fontSize: 13,
      fill: t.foreground,
    },
    axis: {
      domain: { line: { stroke: t.domainLine, strokeWidth: 1 } },
      legend: { text: { fontSize: 13, fontWeight: 600, fill: t.muted } },
      ticks: {
        line: { stroke: t.domainLine, strokeWidth: 1 },
        text: { fontSize: 12, fill: t.tickText },
      },
    },
    grid: {
      line: { stroke: t.gridLine, strokeWidth: 1, strokeDasharray: '4 4' },
    },
    legends: { text: { fontSize: 12.5, fill: t.muted } },
    labels: { text: { fontSize: 11, fontWeight: 700, fill: mode === 'dark' ? '#0f172a' : '#ffffff' } },
    crosshair: { line: { stroke: t.muted, strokeWidth: 1, strokeDasharray: '4 4' } },
    tooltip: {
      container: {
        background: mode === 'dark' ? '#f8fafc' : '#0f172a',
        color: mode === 'dark' ? '#0f172a' : '#f8fafc',
        fontSize: 12,
        borderRadius: '8px',
        padding: '8px 12px',
      },
    },
    annotations: {
      text: { fontSize: 12, fill: t.muted },
      link: { stroke: t.axisLine, strokeWidth: 1 },
      outline: { fill: 'none', stroke: t.axisLine, strokeWidth: 1 },
    },
  }
}
