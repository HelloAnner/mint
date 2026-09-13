import { CHARTS } from '../charts'
import { fail } from './errors'
import type { ChartDefinition } from './types'

const byId = new Map<string, ChartDefinition>()
for (const chart of CHARTS) {
  byId.set(chart.id, chart)
}

/** 修正常见别名 → 正式 id */
const aliasIndex = new Map<string, string>()
for (const chart of CHARTS) {
  aliasIndex.set(chart.id.toLowerCase(), chart.id)
  for (const alias of chart.aliases ?? []) {
    aliasIndex.set(alias.toLowerCase(), chart.id)
  }
}

export function allCharts(): readonly ChartDefinition[] {
  return CHARTS
}

export function chartById(id: string): ChartDefinition | undefined {
  return byId.get(id) ?? byId.get(aliasIndex.get(id.toLowerCase()) ?? '')
}

export function requireChart(id: string): ChartDefinition {
  const chart = chartById(id)
  if (!chart) {
    const available = CHARTS.map((c) => c.id).join(', ')
    fail('UNKNOWN_CHART', `没有名为「${id}」的图表`, `可用图表：${available}。用 mint list 查看详情`)
  }
  return chart
}

/** 近似匹配，用于拼错时的友好提示。 */
export function suggestChart(id: string): string[] {
  const target = id.toLowerCase()
  return CHARTS.map((c) => c.id)
    .filter((candidate) => {
      if (candidate.includes(target) || target.includes(candidate)) return true
      const aliases = aliasIndex
      return [...aliases.keys()].some((a) => a.includes(target) && aliases.get(a) === candidate)
    })
    .slice(0, 5)
}
