import { Marimekko } from '@nivo/marimekko'
import type { ChartDefinition } from '../core/types'
import { asRows, isPlainObject } from './helpers'
import { axisLegendOptions, formatOptions, formatterFrom, legendOption, topMargin } from './common'
import { fail } from '../core/errors'

/**
 * 马赛克图：宽度表示组间占比、高度表示组内占比，一张图同时读两级结构。
 */
const marimekko: ChartDefinition = {
  id: 'marimekko',
  name: '马赛克图',
  englishName: 'Marimekko',
  category: 'composition',
  description: '条形宽度表示组间占比、堆叠高度表示组内构成，一张图看两层比例。',
  dataShape: `[
  {
    "id": "华东",
    "value": 320,
    "新客": 120,
    "老客": 200
  },
  { "id": "华南", "value": 180, "新客": 90, "老客": 90 }
]
value 决定该组的宽度，其余数值字段构成组内的堆叠，会自动识别为 dimensions。`,
  nivoPackage: '@nivo/marimekko',
  variants: ['marimekko 马赛克'],
  aliases: ['马赛克图', 'marimekko', 'mosiac'],
  options: [
    { key: 'idBy', type: 'string', description: '分组字段名', default: 'id' },
    { key: 'valueBy', type: 'string', description: '决定宽度的字段名', default: 'value' },
    { key: 'dimensions', type: 'array', description: '组内堆叠字段，逗号分隔；省略则自动识别' },
    { key: 'innerPadding', type: 'number', description: '组内间距', default: 2 },
    { key: 'outerPadding', type: 'number', description: '组间间距', default: 6 },
    { key: 'xLegend', type: 'string', description: 'X 轴标题' },
    { key: 'yLegend', type: 'string', description: 'Y 轴标题' },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { id: '华东', value: 320, 新客: 120, 老客: 200 },
      { id: '华北', value: 240, 新客: 110, 老客: 130 },
      { id: '华南', value: 180, 新客: 90, 老客: 90 },
      { id: '西南', value: 96, 新客: 58, 老客: 38 },
    ],
    options: { yLegend: '组内构成', xLegend: '区域规模' },
  },
  render: (ctx) => {
    const rows = asRows(ctx.data, 'marimekko')
    const idBy = (ctx.options.idBy as string) ?? 'id'
    const valueBy = (ctx.options.valueBy as string) ?? 'value'

    let dimensions: string[]
    if (Array.isArray(ctx.options.dimensions) && ctx.options.dimensions.length > 0) {
      dimensions = (ctx.options.dimensions as unknown[]).map(String)
    } else {
      const first = rows[0]!
      dimensions = Object.keys(first).filter(
        (k) => k !== idBy && k !== valueBy && typeof first[k] === 'number',
      )
    }

    if (dimensions.length === 0) {
      fail(
        'INVALID_DATA',
        'marimekko 找不到组内构成字段',
        `除 ${idBy} / ${valueBy} 之外还需要至少一个数值字段，例如 { "id": "华东", "value": 320, "新客": 120 }`,
      )
    }

    const data = rows.map((row) => {
      if (!isPlainObject(row)) fail('INVALID_DATA', 'marimekko 的每一行都必须是对象')
      return row
    })

    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false

    return (
      <Marimekko
        data={data as never}
        id={idBy}
        value={valueBy}
        dimensions={dimensions.map((id) => ({ id, value: id })) as never}
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
        layout="vertical"
        offset="none"
        innerPadding={ctx.options.innerPadding ?? 2}
        outerPadding={ctx.options.outerPadding ?? 6}
        enableGridX
        enableGridY={false}
        valueFormat={format}
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
        legends={[]}
        animate={false}
        role="img"
      />
    )
  },
}

export default marimekko
