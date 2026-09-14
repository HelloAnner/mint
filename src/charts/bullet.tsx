import { Bullet } from '@nivo/bullet'
import type { ChartDefinition } from '../core/types'
import { asRows } from './helpers'
import { formatOptions, legendOption } from './common'
import { fail } from '../core/errors'

/**
 * 子弹图：一根条同时表达「实际值 vs 目标值 vs 区间」，比仪表盘更适合横向罗列。
 */
const bullet: ChartDefinition = {
  id: 'bullet',
  name: '子弹图',
  englishName: 'Bullet',
  category: 'comparison',
  description: '一根横条里同时呈现实际值、目标值与达成区间，适合 KPI 罗列。',
  dataShape: `[
  {
    "id": "营收",
    "title": "营收",
    "ranges": [150, 200, 260],
    "measures": [187],
    "markers": [200]
  }
]
ranges 是背景区间（由小到大），measures 是实际值，markers 是目标值。`,
  nivoPackage: '@nivo/bullet',
  variants: ['bullet 子弹'],
  aliases: ['子弹图', 'bullet', 'kpi图', '目标对比'],
  options: [
    { key: 'titleAlign', type: 'string', description: '标题对齐', default: 'end', values: ['start', 'middle', 'end'] },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { id: 'revenue', title: '营收', ranges: [150, 200, 260], measures: [187], markers: [200] },
      { id: 'users', title: '新增用户', ranges: [80, 120, 170], measures: [142], markers: [150] },
      { id: 'retention', title: '留存率', ranges: [40, 55, 70], measures: [62], markers: [65] },
    ],
  },
  render: (ctx) => {
    const rows = asRows(ctx.data, 'bullet')
    for (const [i, row] of rows.entries()) {
      if (!Array.isArray(row.ranges)) {
        fail('INVALID_DATA', `bullet 的第 ${i + 1} 项缺少 ranges 数组`, 'ranges 由小到大，例如 [150, 200, 260]')
      }
    }
    return (
      <Bullet
        data={rows as never}
        width={ctx.width}
        height={ctx.height}
        // Bullet 的标题沿用主题里的 labels 文本色，而该色是为「柱子上白字」准备的，
        // 这里单独覆盖成前景色，否则白底白字看不见。
        theme={{ ...ctx.theme, labels: { text: { ...ctx.theme.labels?.text, fill: ctx.foreground } } }}
        rangeColors={['#eef2f7', '#e2e8f0', '#cbd5e1']}
        measureColors={[ctx.colors[0]!]}
        markerColors={[ctx.colors[3] ?? ctx.colors[0]!]}
        margin={{ top: 24, right: 60, bottom: 34, left: 120 }}
        titleAlign={(ctx.options.titleAlign as never) ?? 'end'}
        // 标题默认右对齐、收在条左侧的留白里；贴着条起点画会压进彩色条，
        // 深色字在深底色上完全看不清
        titleOffsetX={-12}
        spacing={18}
        animate={false}
        role="img"
      />
    )
  },
}

export default bullet
