import { Calendar } from '@nivo/calendar'
import type { ChartDefinition } from '../core/types'
import { fail } from '../core/errors'
import { asRows, isPlainObject } from './helpers'
import { formatOptions, formatterFrom, legendOption } from './common'
import { tintRamp } from '../core/palettes'

interface DayDatum {
  day: string
  value: number
}

/** 把各种常见写法归一化成 [{ day, value }]。 */
function toDays(data: unknown): DayDatum[] {
  if (Array.isArray(data)) {
    const rows = asRows(data, 'calendar')
    return rows.map((row, i) => {
      const day = row.day ?? row.date ?? row.x
      const value = row.value ?? row.count ?? row.y
      if (typeof day !== 'string' || typeof value !== 'number') {
        fail(
          'INVALID_DATA',
          `calendar 的第 ${i + 1} 行需要字符串型 day（YYYY-MM-DD）和数值型 value`,
        )
      }
      return { day, value }
    })
  }

  if (isPlainObject(data)) {
    const entries = Object.entries(data).filter(([, v]) => typeof v === 'number') as [string, number][]
    if (entries.length > 0) return entries.map(([day, value]) => ({ day, value }))
  }

  fail('INVALID_DATA', 'calendar 需要 [{ day: "2025-01-01", value: 3 }] 或 { "2025-01-01": 3 }')
}

/** 生成一年带周节律的示例数据，让日历图不至于空着。 */
function buildYearExample(): DayDatum[] {
  const out: DayDatum[] = []
  const start = Date.UTC(2025, 0, 1)
  for (let i = 0; i < 365; i++) {
    const date = new Date(start + i * 86400000)
    const weekday = date.getUTCDay()
    const weekend = weekday === 0 || weekday === 6
    const seasonal = Math.sin((i / 365) * Math.PI * 2 - 1.2) * 16 + 26
    const wobble = ((i * 7919) % 13) - 6
    const value = Math.max(0, Math.round(seasonal + wobble + (weekend ? -12 : 6)))
    if (value > 0) out.push({ day: date.toISOString().slice(0, 10), value })
  }
  return out
}

/**
 * 日历热力图：看一年里的活跃度与节律，GitHub 贡献图同款。
 */
const calendar: ChartDefinition = {
  id: 'calendar',
  name: '日历热力图',
  englishName: 'Calendar',
  category: 'distribution',
  description: '按天着色，展示一整年的活跃度分布与周期性节律。',
  dataShape: `[{ "day": "2025-01-01", "value": 12 }]，也接受 { "2025-01-01": 12 }
from / to 可省略，会按数据里的最早/最晚日期自动确定范围。`,
  nivoPackage: '@nivo/calendar',
  variants: ['calendar 日历'],
  aliases: ['日历图', '日历热力', '贡献图', 'calendar', 'github图'],
  options: [
    { key: 'from', type: 'string', description: '起始日期 YYYY-MM-DD' },
    { key: 'to', type: 'string', description: '结束日期 YYYY-MM-DD' },
    { key: 'direction', type: 'string', description: '排列方向', default: 'horizontal', values: ['horizontal', 'vertical'] },
    { key: 'emptyColor', type: 'string', description: '无数据日期的底色', default: '#f1f5f9' },
    { key: 'yearLegend', type: 'boolean', description: '是否显示年份标签', default: true },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: buildYearExample(),
  },
  render: (ctx) => {
    const days = toDays(ctx.data)
    const sorted = [...days].sort((a, b) => a.day.localeCompare(b.day))
    const from = (ctx.options.from as string) ?? sorted[0]!.day
    const to = (ctx.options.to as string) ?? sorted[sorted.length - 1]!.day
    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false

    return (
      <Calendar
        data={days}
        from={from}
        to={to}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={tintRamp(ctx.colors[0]!, 5)}
        margin={{ top: 16, right: 26, bottom: 46, left: 40 }}
        direction={ctx.options.direction === 'vertical' ? 'vertical' : 'horizontal'}
        emptyColor={(ctx.options.emptyColor as string) ?? '#f1f5f9'}
        dayBorderWidth={2}
        dayBorderColor={(ctx.options.emptyColor as string) ?? '#f1f5f9'}
        monthBorderWidth={0}
        monthLegendOffset={10}
        yearLegendOffset={ctx.options.yearLegend === false ? 0 : 12}
        valueFormat={format}
        legends={
          legend
            ? [
                {
                  anchor: 'bottom-right',
                  direction: 'row',
                  translateY: 34,
                  itemCount: 4,
                  itemWidth: 36,
                  itemHeight: 32,
                  itemsSpacing: 8,
                  itemDirection: 'right-to-left',
                  symbolSize: 20,
                  symbolShape: 'square',
                },
              ]
            : []
        }
      />
    )
  },
}

export default calendar
