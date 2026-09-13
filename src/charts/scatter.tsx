import { ScatterPlot } from '@nivo/scatterplot'
import type { ChartDefinition } from '../core/types'
import { asSeries, isPlainObject } from './helpers'
import { axisLegendOptions, formatOptions, formatterFrom, legendOption, seriesLegend, topMargin } from './common'

/**
 * 散点图 / 气泡图：看两个（或三个）变量之间的关系与离群点。
 */
const scatter: ChartDefinition = {
  id: 'scatter',
  name: '散点图',
  englishName: 'Scatter',
  category: 'relation',
  description: '观察两个数值变量之间的相关性、聚集与离群点，可扩展成气泡图。',
  dataShape: `数组，每个系列一组点：
[
  { "id": "A 组", "data": [{ "x": 12, "y": 34 }, { "x": 20, "y": 41 }] }
]
气泡图时给每个点加 size 字段：[{ "x": 12, "y": 34, "size": 8 }]。
也支持扁平记录 [{ "x": 12, "y": 34, "group": "A 组" }]。`,
  nivoPackage: '@nivo/scatterplot',
  variants: ['points 散点', 'bubble 气泡'],
  aliases: ['散点', '气泡图', 'bubble', '相关性'],
  options: [
    { key: 'pointSize', type: 'number', description: '点大小', default: 9 },
    { key: 'seriesBy', type: 'string', description: '扁平记录下用于分组的字段名' },
    { key: 'xLegend', type: 'string', description: 'X 轴标题' },
    { key: 'yLegend', type: 'string', description: 'Y 轴标题' },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { id: '华东', data: [{ x: 12, y: 34 }, { x: 18, y: 42 }, { x: 25, y: 51 }, { x: 31, y: 58 }] },
      { id: '华南', data: [{ x: 9, y: 22 }, { x: 15, y: 30 }, { x: 22, y: 36 }, { x: 28, y: 49 }] },
    ],
    options: { xLegend: '投放金额（万元）', yLegend: '新增用户（千人）' },
  },
  render: (ctx) => {
    // 已经是 nivo 原生系列结构时原样透传，避免丢掉 size 等附加字段
    const raw = ctx.data
    const native =
      Array.isArray(raw) &&
      raw.length > 0 &&
      raw.every((d) => isPlainObject(d) && Array.isArray((d as Record<string, unknown>).data))

    const series = native
      ? (raw as { id: string; data: unknown[] }[]).map((s, i) => ({
          id: String(s.id ?? `系列 ${i + 1}`),
          data: s.data as { x: number; y: number; size?: number }[],
        }))
      : asSeries(raw, 'scatter', { seriesBy: ctx.options.seriesBy })

    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false

    return (
      <ScatterPlot
        data={series as never}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{
          top: topMargin(legend),
          right: 26,
          bottom: ctx.options.xLegend ? 62 : 46,
          left: ctx.options.yLegend ? 74 : 58,
        }}
        xScale={{ type: 'linear', min: 'auto', max: 'auto' }}
        yScale={{ type: 'linear', min: 'auto', max: 'auto' }}
        nodeSize={ctx.options.pointSize ?? 9}
        enableGridX
        enableGridY
        axisTop={null}
        axisRight={null}
        axisBottom={{
          tickSize: 0,
          tickPadding: 12,
          legend: ctx.options.xLegend,
          legendPosition: 'middle',
          legendOffset: 44,
        }}
        axisLeft={{
          tickSize: 0,
          tickPadding: 12,
          legend: ctx.options.yLegend,
          legendPosition: 'middle',
          legendOffset: -58,
          format,
        }}
        legends={seriesLegend(series, ctx.colors, legend)}
        animate={false}
        role="img"
        ariaLabel="散点图"
      />
    )
  },
}

export default scatter
