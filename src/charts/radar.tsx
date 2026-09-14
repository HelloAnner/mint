import { Radar } from '@nivo/radar'
import type { ChartDefinition } from '../core/types'
import { asRows, inferIndexKeys } from './helpers'
import { axisLegendOptions, formatOptions, formatterFrom, keysLegend, legendOption } from './common'

/**
 * 雷达图：多个维度的能力/评分对照。
 * 维度建议控制在 3~8 个，太多会糊成一团。
 */
const radar: ChartDefinition = {
  id: 'radar',
  name: '雷达图',
  englishName: 'Radar',
  category: 'comparison',
  description: '在多个维度上同时比较若干对象，适合能力评估、产品对标。',
  dataShape: `数组，每行一个维度：
[
  { "dimension": "性能", "本产品": 82, "竞品A": 68 },
  { "dimension": "易用性", "本产品": 74, "竞品A": 88 }
]
除维度字段外的数值字段都会被当成一个比较对象。`,
  nivoPackage: '@nivo/radar',
  variants: ['filled 填充', 'outline 描边'],
  aliases: ['雷达', '蜘蛛图', 'spider', '能力图'],
  options: [
    { key: 'indexBy', type: 'string', description: '维度字段名' },
    { key: 'keys', type: 'array', description: '比较对象字段，逗号分隔' },
    { key: 'fillOpacity', type: 'number', description: '填充不透明度，0 为纯描边', default: 0.15 },
    { key: 'gridLevels', type: 'number', description: '网格层数', default: 5 },
    legendOption,
    ...axisLegendOptions,
    ...formatOptions,
  ],
  example: {
    data: [
      { dimension: '性能', 本产品: 82, 竞品A: 68 },
      { dimension: '易用性', 本产品: 74, 竞品A: 88 },
      { dimension: '价格', 本产品: 65, 竞品A: 72 },
      { dimension: '生态', 本产品: 90, 竞品A: 60 },
      { dimension: '服务', 本产品: 78, 竞品A: 70 },
    ],
    options: { fillOpacity: 0.15 },
  },
  render: (ctx) => {
    const rows = asRows(ctx.data, 'radar')
    const { indexBy, keys } = inferIndexKeys(rows, {
      indexBy: ctx.options.indexBy,
      keys: ctx.options.keys,
    })
    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false

    return (
      <Radar
        data={rows}
        keys={keys}
        indexBy={indexBy}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{ top: 30, right: 90, bottom: legend ? 80 : 40, left: 90 }}
        gridLevels={ctx.options.gridLevels ?? 5}
        gridShape="circular"
        fillOpacity={ctx.options.fillOpacity ?? 0.15}
        borderWidth={2}
        dotSize={8}
        dotBorderWidth={2}
        dotBorderColor={{ from: 'color' }}
        valueFormat={format}
        legends={
          legend
            ? [
                {
                  data: keys.map((key, i) => ({
                    id: key,
                    label: key,
                    color: ctx.colors[i % ctx.colors.length]!,
                  })),
                  anchor: 'bottom',
                  direction: 'row',
                  // nivo 的图例按外层画布定位，translateY 过大会把图例推到画布外
                  translateY: 24,
                  itemWidth: 88,
                  itemHeight: 18,
                  itemsSpacing: 12,
                  symbolSize: 9,
                  symbolShape: 'circle',
                },
              ]
            : []
        }
        animate={false}
        role="img"
        ariaLabel="雷达图"
      />
    )
  },
}

export default radar
