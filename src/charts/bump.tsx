import { Bump, AreaBump } from '@nivo/bump'
import type { ChartDefinition } from '../core/types'
import { asSeries } from './helpers'
import { axisLegendOptions, formatOptions, formatterFrom, legendOption, topMargin } from './common'

/**
 * 排名变化图：看「谁在什么时候超过了谁」。
 * y 轴是名次（1 为最高），因此 y 值要传排名数字。
 */
const bump: ChartDefinition = {
  id: 'bump',
  name: '排名变化图',
  englishName: 'Bump',
  category: 'trend',
  description: '用交叉的线条展示多个对象在名次上的此消彼长，比折线更适合看排名。',
  dataShape: `每个系列一组「时间 → 名次」的点：
[
  { "id": "产品A", "data": [{ "x": "1月", "y": 3 }, { "x": "2月", "y": 2 }] },
  { "id": "产品B", "data": [{ "x": "1月", "y": 1 }, { "x": "2月", "y": 4 }] }
]
y 是名次，数字越小越靠上。`,
  nivoPackage: '@nivo/bump',
  variants: ['bump 折线排名', 'area-bump 面积排名'],
  aliases: ['排名图', 'bump', '名次变化', 'ranking'],
  options: [
    { key: 'variant', type: 'string', description: '形态', default: 'bump', values: ['bump', 'area'] },
    { key: 'pointSize', type: 'number', description: '数据点大小', default: 8 },
    { key: 'xLegend', type: 'string', description: 'X 轴标题' },
    { key: 'yLegend', type: 'string', description: 'Y 轴标题' },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { id: '产品A', data: [{ x: '1月', y: 3 }, { x: '2月', y: 2 }, { x: '3月', y: 1 }, { x: '4月', y: 1 }] },
      { id: '产品B', data: [{ x: '1月', y: 1 }, { x: '2月', y: 1 }, { x: '3月', y: 3 }, { x: '4月', y: 4 }] },
      { id: '产品C', data: [{ x: '1月', y: 2 }, { x: '2月', y: 3 }, { x: '3月', y: 2 }, { x: '4月', y: 2 }] },
      { id: '产品D', data: [{ x: '1月', y: 4 }, { x: '2月', y: 4 }, { x: '3月', y: 4 }, { x: '4月', y: 3 }] },
    ],
    options: { variant: 'bump' },
  },
  render: (ctx) => {
    const series = asSeries(ctx.data, 'bump')
    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false
    const margin = {
      top: topMargin(legend),
      right: 90,
      bottom: ctx.options.xLegend ? 62 : 46,
      left: ctx.options.yLegend ? 74 : 58,
    }

    if (ctx.options.variant === 'area') {
      return (
        <AreaBump
          data={series as never}
          width={ctx.width}
          height={ctx.height}
          theme={ctx.theme}
          colors={ctx.colors}
          margin={margin}
          spacing={8}
          blendMode="normal"
          axisBottom={{
            tickSize: 0,
            tickPadding: 12,
            legend: ctx.options.xLegend,
            legendPosition: 'middle',
            legendOffset: 44,
          }}
          animate={false}
          role="img"
        />
      )
    }

    return (
      <Bump
        data={series as never}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={margin}
        pointSize={ctx.options.pointSize ?? 8}
        pointBorderWidth={2}
        pointBorderColor={{ from: 'serieColor' }}
        activePointSize={14}
        activeLineWidth={4}
        inactivePointSize={0}
        inactiveLineWidth={2}
        enableGridX={false}
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
        animate={false}
        role="img"
      />
    )
  },
}

export default bump
