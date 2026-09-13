import { Stream } from '@nivo/stream'
import type { ChartDefinition } from '../core/types'
import { asRows, inferIndexKeys } from './helpers'
import { axisLegendOptions, formatOptions, formatterFrom, keysLegend, legendOption, topMargin } from './common'

/**
 * 堆叠面积图：同时看「总量变化」和「内部结构变化」。
 * 适合渠道构成、成本拆解这类占比随时间漂移的场景。
 */
const stream: ChartDefinition = {
  id: 'stream',
  name: '堆叠面积图',
  englishName: 'Stream',
  category: 'trend',
  description: '按时间堆叠多个系列，一眼看出总量走势与结构占比的变化。',
  dataShape: `数组，每行一个时间点，每列一个系列（数值）：
[
  { "month": "1月", "自然搜索": 320, "社交媒体": 180 },
  { "month": "2月", "自然搜索": 345, "社交媒体": 205 }
]
除第一个字符串字段外，其余数值字段都会被当成堆叠系列。`,
  nivoPackage: '@nivo/stream',
  variants: ['stacked 堆叠', 'expand 百分比堆叠'],
  aliases: ['堆叠面积图', '面积图', 'stacked area', 'areachart'],
  options: [
    {
      key: 'offsetType',
      type: 'string',
      description: '堆叠方式，expand 表示百分比堆叠',
      default: 'none',
      values: ['none', 'expand', 'silhouette', 'wiggle'],
    },
    { key: 'indexBy', type: 'string', description: '时间/分类字段名' },
    { key: 'keys', type: 'array', description: '参与堆叠的数值字段，逗号分隔' },
    { key: 'fillOpacity', type: 'number', description: '填充不透明度', default: 0.88 },
    legendOption,
    ...axisLegendOptions,
    ...formatOptions,
  ],
  example: {
    data: [
      { month: '1月', 自然搜索: 320, 社交媒体: 180, 直接访问: 140 },
      { month: '2月', 自然搜索: 345, 社交媒体: 205, 直接访问: 152 },
      { month: '3月', 自然搜索: 372, 社交媒体: 236, 直接访问: 168 },
      { month: '4月', 自然搜索: 410, 社交媒体: 268, 直接访问: 175 },
      { month: '5月', 自然搜索: 448, 社交媒体: 305, 直接访问: 192 },
    ],
    options: { yLegend: '访问量（万次）', xLegend: '2025 年' },
  },
  render: (ctx) => {
    const rows = asRows(ctx.data, 'stream')
    const { indexBy, keys } = inferIndexKeys(rows, {
      indexBy: ctx.options.indexBy,
      keys: ctx.options.keys,
    })
    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false

    // stream 只认数值列，且列顺序即堆叠顺序
    const data = rows.map((row) => {
      const out: Record<string, number> = {}
      for (const key of keys) out[key] = Number(row[key] ?? 0)
      return out
    })

    return (
      <Stream
        data={data}
        keys={keys}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{
          top: topMargin(legend),
          right: 26,
          bottom: ctx.options.xLegend ? 62 : 46,
          left: ctx.options.yLegend ? 78 : 64,
        }}
        offsetType={ctx.options.offsetType ?? 'none'}
        curve="monotoneX"
        fillOpacity={ctx.options.fillOpacity ?? 0.88}
        borderWidth={0}
        enableGridX={false}
        valueFormat={format}
        axisTop={null}
        axisRight={null}
        axisBottom={{
          tickSize: 0,
          tickPadding: 12,
          legend: ctx.options.xLegend,
          legendPosition: 'middle',
          legendOffset: 44,
          format: (index) => String(rows[Number(index)]?.[indexBy] ?? index),
        }}
        axisLeft={{
          tickSize: 0,
          tickPadding: 12,
          legend: ctx.options.yLegend,
          legendPosition: 'middle',
          legendOffset: -64,
          format,
        }}
        legends={keysLegend(legend, keys)}
        animate={false}
        role="img"
        ariaLabel="堆叠面积图"
      />
    )
  },
}

export default stream
