import type { OptionSpec } from '../core/types'
import { makeFormatter, type FormatPreset } from '../core/format'
import { STYLE } from '../core/style'

export const legendOption: OptionSpec = {
  key: 'legend',
  type: 'boolean',
  description: '是否显示图例',
  default: true,
}

export const formatOptions: OptionSpec[] = [
  {
    key: 'valueFormat',
    type: 'string',
    description: '数值格式化方式',
    default: 'number',
    values: ['number', 'percent', 'compact'],
  },
  { key: 'decimals', type: 'number', description: '小数位数，省略则用千分位整数' },
  { key: 'valuePrefix', type: 'string', description: '数值前缀，如 ¥' },
  { key: 'valueSuffix', type: 'string', description: '数值后缀，如 万' },
]

export const axisLegendOptions: OptionSpec[] = [
  { key: 'xLegend', type: 'string', description: 'X 轴标题' },
  { key: 'yLegend', type: 'string', description: 'Y 轴标题' },
]

export function formatterFrom(options: Record<string, unknown>) {
  return makeFormatter({
    preset: (options.valueFormat as FormatPreset) ?? 'number',
    decimals: options.decimals as number | undefined,
    prefix: (options.valuePrefix as string) ?? '',
    suffix: (options.valueSuffix as string) ?? '',
  })
}

/** 图例在上方时给图表留出的顶部边距。 */
export function topMargin(hasLegend: boolean, base = 18): number {
  return hasLegend ? 46 : base
}

export function bottomMargin(hasLegend: boolean): number {
  return hasLegend ? 62 : 40
}

/**
 * 按最长标签估算图例项宽度。
 * 固定 itemWidth 会让长中文标签溢出槽位、和相邻项压叠，这里按字符宽度自适应。
 * CJK 约 13px/字，ASCII 约 7.5px/字，再加上符号与左右留白。
 */
export function legendItemWidth(labels: readonly string[]): number {
  const textWidth = (label: string) => {
    let width = 0
    for (const ch of label) width += /[\u2E80-\uFFFF]/.test(ch) ? 13 : 7.5
    return width
  }
  const max = labels.reduce((acc, label) => Math.max(acc, textWidth(label)), 0)
  return Math.ceil(Math.max(64, max + 34))
}

/**
 * 折线/散点类图表的图例。
 * 显式给出 data，避免 nivo 按字母序重排，导致图例顺序和系列顺序不一致。
 */
export function seriesLegend(
  series: readonly { id: string }[],
  colors: readonly string[],
  hasLegend: boolean,
) {
  if (!hasLegend) return []
  return [
    {
      data: series.map((s, i) => ({
        id: s.id,
        label: s.id,
        color: colors[i % colors.length]!,
      })),
      anchor: 'top-left' as const,
      direction: 'row' as const,
      translateY: -40,
      itemWidth: legendItemWidth(series.map((s) => s.id)),
      itemHeight: STYLE.legend.itemHeight,
      itemsSpacing: STYLE.legend.itemsSpacing,
      symbolSize: STYLE.legend.symbolSize,
      symbolShape: 'circle' as const,
    },
  ]
}

/** 由 keys 生成图例（柱状/面积等以 key 为系列的图表）。 */
export function keysLegend(hasLegend: boolean, keys: readonly string[] = []) {
  if (!hasLegend) return []
  return [
    {
      dataFrom: 'keys' as const,
      anchor: 'top-right' as const,
      direction: 'row' as const,
      translateY: -40,
      itemWidth: legendItemWidth(keys),
      itemHeight: STYLE.legend.itemHeight,
      itemsSpacing: STYLE.legend.itemsSpacing,
      symbolSize: STYLE.legend.symbolSize,
      symbolShape: 'circle' as const,
    },
  ]
}
