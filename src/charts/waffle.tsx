import { Waffle } from '@nivo/waffle'
import type { ChartDefinition } from '../core/types'
import { asPairs } from './helpers'
import { formatOptions, formatterFrom, legendOption } from './common'

/**
 * 华夫图：用一格一单位的方式把比例"数"出来，比饼图更直观地传达量级差异。
 */
const waffle: ChartDefinition = {
  id: 'waffle',
  name: '华夫图',
  englishName: 'Waffle',
  category: 'composition',
  description: '用等量方格表示比例，比饼图更容易读出"几比几"的量级感。',
  dataShape: `[{ "id": "已完成", "label": "已完成", "value": 68 }]
value 是"格数"的权重，total 是格子总数（默认取权重之和，上限 100）。`,
  nivoPackage: '@nivo/waffle',
  variants: ['waffle 华夫'],
  aliases: ['华夫图', '方格图', 'waffle', '点阵图'],
  options: [
    { key: 'rows', type: 'number', description: '行数，省略则自动推导' },
    { key: 'columns', type: 'number', description: '列数，省略则自动推导' },
    { key: 'total', type: 'number', description: '格子总数，省略则取权重之和（上限 100）' },
    { key: 'fillDirection', type: 'string', description: '填充方向', default: 'top', values: ['top', 'right', 'bottom', 'left'] },
    { key: 'emptyColor', type: 'string', description: '空格子的颜色', default: '#f1f5f9' },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { id: '已完成', label: '已完成', value: 62 },
      { id: '进行中', label: '进行中', value: 23 },
      { id: '未开始', label: '未开始', value: 15 },
    ],
    options: { rows: 10, columns: 10, total: 100 },
  },
  render: (ctx) => {
    const data = asPairs(ctx.data, 'waffle')
    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false

    const sum = data.reduce((acc, d) => acc + d.value, 0)
    const total = Math.min((ctx.options.total as number) ?? Math.max(1, Math.round(sum)), 100)
    const columns = (ctx.options.columns as number) ?? Math.max(1, Math.ceil(Math.sqrt(total)))
    const rows = (ctx.options.rows as number) ?? Math.max(1, Math.ceil(total / columns))

    return (
      <Waffle
        data={data}
        total={total}
        rows={rows}
        columns={columns}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{ top: 20, right: 30, bottom: legend ? 66 : 24, left: 30 }}
        fillDirection={(ctx.options.fillDirection as never) ?? 'top'}
        padding={2}
        emptyColor={(ctx.options.emptyColor as string) ?? '#f1f5f9'}
        borderWidth={0}
        valueFormat={format}
        legends={
          legend
            ? [
                {
                  anchor: 'bottom',
                  direction: 'row',
                  translateY: 52,
                  itemWidth: 88,
                  itemHeight: 18,
                  itemsSpacing: 12,
                  symbolSize: 12,
                  symbolShape: 'square',
                },
              ]
            : []
        }
        animate={false}
        role="img"
        ariaLabel="华夫图"
      />
    )
  },
}

export default waffle
