import { HeatMap } from '@nivo/heatmap'
import type { ChartDefinition } from '../core/types'
import { asRows, isPlainObject } from './helpers'
import { axisLegendOptions, formatOptions, formatterFrom, legendOption, topMargin } from './common'
import { fail } from '../core/errors'
import { tint } from '../core/palettes'

interface Cell {
  x: string
  y: number
}

/**
 * 热力图：用颜色深浅表达二维矩阵的强度。
 * 适合时段 × 星期、渠道 × 地区这类交叉分析。
 */
const heatmap: ChartDefinition = {
  id: 'heatmap',
  name: '热力图',
  englishName: 'HeatMap',
  category: 'distribution',
  description: '用颜色深浅表现两个维度交叉后的数值强度，快速定位高低分布。',
  dataShape: `两种写法：
1) 行 × 列矩阵：
[
  { "id": "周一", "data": [{ "x": "上午", "y": 12 }, { "x": "下午", "y": 20 }] },
  { "id": "周二", "data": [{ "x": "上午", "y": 15 }, { "x": "下午", "y": 25 }] }
]
2) 长表 [{ "row": "周一", "col": "上午", "value": 12 }]，会自动转成矩阵。`,
  nivoPackage: '@nivo/heatmap',
  variants: ['matrix 热力', 'heat strip'],
  aliases: ['热力', '热力图', '矩阵图', 'heat map'],
  options: [
    { key: 'rowBy', type: 'string', description: '长表模式下的行字段名', default: 'row' },
    { key: 'colBy', type: 'string', description: '长表模式下的列字段名', default: 'col' },
    { key: 'valueBy', type: 'string', description: '长表模式下的数值字段名', default: 'value' },
    { key: 'cellBorder', type: 'boolean', description: '是否显示单元格白边', default: true },
    { key: 'valueLabel', type: 'boolean', description: '是否在格子里标数值', default: false },
    { key: 'xLegend', type: 'string', description: 'X 轴标题' },
    { key: 'yLegend', type: 'string', description: 'Y 轴标题' },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { id: '周一', data: [{ x: '上午', y: 12 }, { x: '下午', y: 20 }, { x: '晚间', y: 34 }] },
      { id: '周二', data: [{ x: '上午', y: 15 }, { x: '下午', y: 25 }, { x: '晚间', y: 41 }] },
      { id: '周三', data: [{ x: '上午', y: 9 }, { x: '下午', y: 18 }, { x: '晚间', y: 29 }] },
      { id: '周四', data: [{ x: '上午', y: 21 }, { x: '下午', y: 30 }, { x: '晚间', y: 45 }] },
      { id: '周五', data: [{ x: '上午', y: 26 }, { x: '下午', y: 38 }, { x: '晚间', y: 52 }] },
    ],
    options: { valueLabel: true },
  },
  render: (ctx) => {
    const raw = ctx.data
    const native =
      Array.isArray(raw) &&
      raw.length > 0 &&
      raw.every((d) => isPlainObject(d) && Array.isArray((d as Record<string, unknown>).data))

    let rows: { id: string; data: Cell[] }[]

    if (native) {
      rows = (raw as { id: string; data: Cell[] }[]).map((r) => ({ id: String(r.id), data: r.data }))
    } else {
      const flat = asRows(raw, 'heatmap')
      const rowBy = (ctx.options.rowBy as string) ?? 'row'
      const colBy = (ctx.options.colBy as string) ?? 'col'
      const valueBy = (ctx.options.valueBy as string) ?? 'value'

      const groups = new Map<string, Cell[]>()
      for (const [i, record] of flat.entries()) {
        const rowId = record[rowBy]
        const colId = record[colBy]
        const value = record[valueBy]
        if (rowId === undefined || colId === undefined || typeof value !== 'number') {
          fail(
            'INVALID_DATA',
            `heatmap 的长表第 ${i + 1} 行需要 ${rowBy} / ${colBy} / 数值型 ${valueBy}`,
            '例如 { "row": "周一", "col": "上午", "value": 12 }',
          )
        }
        const key = String(rowId)
        if (!groups.has(key)) groups.set(key, [])
        groups.get(key)!.push({ x: String(colId), y: value })
      }
      rows = [...groups.entries()].map(([id, data]) => ({ id, data }))
    }

    if (rows.length === 0) fail('INVALID_DATA', 'heatmap 的数据为空')

    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false

    return (
      <HeatMap
        data={rows}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={{
          type: 'sequential',
          colors: [tint(ctx.colors[0]!, 0.08), ctx.colors[0]!],
          minValue: undefined as never,
          maxValue: undefined as never,
        }}
        margin={{
          top: topMargin(legend),
          right: 26,
          bottom: ctx.options.xLegend ? 62 : 48,
          left: ctx.options.yLegend ? 84 : 68,
        }}
        valueFormat={format}
        borderWidth={ctx.options.cellBorder === false ? 0 : 1}
        borderColor={{ from: 'color', modifiers: [['darker', 0.4]] }}
        enableLabels={ctx.options.valueLabel === true}
        labelTextColor={{ from: 'color', modifiers: [['darker', 2.6]] }}
        axisTop={{
          tickSize: 0,
          tickPadding: 10,
          legend: ctx.options.xLegend,
          legendPosition: 'middle',
        }}
        axisRight={null}
        axisBottom={{
          tickSize: 0,
          tickPadding: 10,
          legend: ctx.options.xLegend,
          legendPosition: 'middle',
          legendOffset: 40,
        }}
        axisLeft={{
          tickSize: 0,
          tickPadding: 10,
          legend: ctx.options.yLegend,
          legendPosition: 'middle',
          legendOffset: -68,
        }}
        animate={false}
        role="img"
        ariaLabel="热力图"
      />
    )
  },
}

export default heatmap
