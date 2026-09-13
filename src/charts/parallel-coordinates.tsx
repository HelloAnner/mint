import { ParallelCoordinates } from '@nivo/parallel-coordinates'
import type { ChartDefinition } from '../core/types'
import { asRows } from './helpers'
import { formatOptions, formatterFrom, legendOption } from './common'
import { fail } from '../core/errors'

/**
 * 平行坐标图：多个数值维度并排，用折线表示每条记录，看多维度的聚类与异常。
 */
const parallelCoordinates: ChartDefinition = {
  id: 'parallel-coordinates',
  name: '平行坐标图',
  englishName: 'ParallelCoordinates',
  category: 'relation',
  description: '把多个数值维度并排放置，每个对象一条折线，观察多维聚类与离群。',
  dataShape: `每一行一条记录，所有数值字段自动作为维度：
[
  { "name": "城市A", "房价": 82, "通勤": 34, "绿化": 61 },
  { "name": "城市B", "房价": 65, "通勤": 48, "绿化": 73 }
]
可用 variables 选项指定参与绘制的维度，逗号分隔。`,
  nivoPackage: '@nivo/parallel-coordinates',
  variants: ['parallel 平行坐标'],
  aliases: ['平行坐标', 'parallel', '多维图'],
  options: [
    { key: 'variables', type: 'array', description: '参与绘制的字段，逗号分隔；省略则用全部数值字段' },
    { key: 'lineWidth', type: 'number', description: '线宽', default: 2 },
    { key: 'opacity', type: 'number', description: '线条不透明度', default: 0.55 },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { name: '城市A', 房价: 82, 通勤: 34, 绿化: 61, 教育: 78 },
      { name: '城市B', 房价: 65, 通勤: 48, 绿化: 73, 教育: 66 },
      { name: '城市C', 房价: 91, 通勤: 26, 绿化: 44, 教育: 88 },
      { name: '城市D', 房价: 48, 通勤: 62, 绿化: 82, 教育: 57 },
    ],
  },
  render: (ctx) => {
    const rows = asRows(ctx.data, 'parallel-coordinates')
    const first = rows[0]!
    const numericFields = Object.keys(first).filter((k) => typeof first[k] === 'number')

    // --set variables=a,b 传入的是字符串，这里统一成数组
    const rawVariables = ctx.options.variables
    const variableIds =
      typeof rawVariables === 'string'
        ? rawVariables.split(',').map((s) => s.trim()).filter(Boolean)
        : Array.isArray(rawVariables) && rawVariables.length > 0
          ? (rawVariables as unknown[]).map(String)
          : numericFields

    // nivo 的 variables 需要 id（轴标识）和 value（取数字段）两个属性：
    // 只给 key 会让轴的 point scale 域变成 [undefined…]，所有轴塌到同一位置、
    // 数据也取不到值，最终渲染出一张空白图（只有一根竖线）。
    const variables = variableIds.map((id) => ({ id, value: id, label: id }))

    if (variables.length < 2) {
      fail(
        'INVALID_DATA',
        'parallel-coordinates 至少需要 2 个数值维度',
        '例如 [{ "name": "A", "房价": 82, "通勤": 34 }]',
      )
    }

    return (
      <ParallelCoordinates
        data={rows as never}
        variables={variables as never}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{ top: 40, right: 50, bottom: 40, left: 50 }}
        layout="horizontal"
        lineWidth={ctx.options.lineWidth ?? 2}
        lineOpacity={ctx.options.opacity ?? 0.55}
        animate={false}
        role="img"
        ariaLabel="平行坐标图"
      />
    )
  },
}

export default parallelCoordinates
