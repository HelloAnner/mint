import { Bar } from '@nivo/bar'
import type { ChartDefinition } from '../core/types'
import { asRows, inferIndexKeys } from './helpers'
import {
  axisLegendOptions,
  formatOptions,
  formatterFrom,
  keysLegend,
  legendOption,
  topMargin,
} from './common'

/**
 * 柱状图：最适合「类别之间的数值比较」。
 * 支持分组、堆叠与横向三种形态，是报告里出场率最高的图表。
 */
const bar: ChartDefinition = {
  id: 'bar',
  name: '柱状图',
  englishName: 'Bar',
  category: 'comparison',
  description: '比较不同类别或不同分组的数值大小，可分组、可堆叠、可横向。',
  dataShape: `数组，每行一条记录：分类字段 + 若干数值字段
[
  { "quarter": "Q1", "华东": 128, "华北": 96 },
  { "quarter": "Q2", "华东": 152, "华北": 108 }
]
不传 keys 时会自动把数值字段识别为系列，第一个字符串字段识别为分类轴。`,
  nivoPackage: '@nivo/bar',
  variants: ['grouped 分组', 'stacked 堆叠', 'horizontal 横向'],
  aliases: ['column', '柱状图', '条形图', '直方图', 'columns'],
  options: [
    { key: 'groupMode', type: 'string', description: '分组方式', default: 'grouped', values: ['grouped', 'stacked'] },
    { key: 'layout', type: 'string', description: '方向', default: 'vertical', values: ['vertical', 'horizontal'] },
    { key: 'indexBy', type: 'string', description: '分类轴字段名' },
    { key: 'keys', type: 'array', description: '参与绘制的数值字段，逗号分隔' },
    { key: 'borderRadius', type: 'number', description: '柱子的圆角半径', default: 4 },
    { key: 'valueLabel', type: 'boolean', description: '是否在柱子上直接标数值', default: true },
    legendOption,
    ...axisLegendOptions,
    ...formatOptions,
  ],
  example: {
    data: [
      { quarter: 'Q1', 华东: 128, 华北: 96, 华南: 74 },
      { quarter: 'Q2', 华东: 152, 华北: 108, 华南: 88 },
      { quarter: 'Q3', 华东: 141, 华北: 124, 华南: 103 },
      { quarter: 'Q4', 华东: 187, 华北: 139, 华南: 121 },
    ],
    options: { groupMode: 'grouped', yLegend: '营收（百万元）', xLegend: '2025 财年' },
  },
  render: (ctx) => {
    const rows = asRows(ctx.data, 'bar')
    const { indexBy, keys } = inferIndexKeys(rows, {
      indexBy: ctx.options.indexBy,
      keys: ctx.options.keys,
    })
    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false
    const horizontal = ctx.options.layout === 'horizontal'

    return (
      <Bar
        data={rows as never}
        keys={keys}
        indexBy={indexBy}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{
          top: topMargin(legend),
          right: 26,
          bottom: ctx.options.xLegend || horizontal ? 62 : 46,
          left: horizontal ? 90 : ctx.options.yLegend ? 74 : 58,
        }}
        groupMode={ctx.options.groupMode ?? 'grouped'}
        layout={horizontal ? 'horizontal' : 'vertical'}
        valueScale={{ type: 'linear' }}
        indexScale={{ type: 'band', round: true }}
        padding={0.28}
        innerPadding={4}
        borderRadius={ctx.options.borderRadius ?? 4}
        enableGridX={horizontal}
        enableGridY={!horizontal}
        enableLabel={ctx.options.valueLabel !== false}
        labelSkipWidth={18}
        labelSkipHeight={14}
        valueFormat={format}
        axisTop={null}
        axisRight={null}
        axisBottom={{
          tickSize: 0,
          tickPadding: 12,
          legend: ctx.options.xLegend,
          legendPosition: 'middle',
          legendOffset: 44,
          format: horizontal ? format : undefined,
        }}
        axisLeft={{
          tickSize: 0,
          tickPadding: 12,
          legend: ctx.options.yLegend,
          legendPosition: 'middle',
          legendOffset: horizontal ? -76 : -58,
          format: horizontal ? undefined : format,
        }}
        legends={keysLegend(legend)}
        animate={false}
        role="img"
        ariaLabel="柱状图"
      />
    )
  },
}

export default bar
