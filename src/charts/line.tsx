import { Line } from '@nivo/line'
import type { ChartDefinition } from '../core/types'
import { asSeries } from './helpers'
import { STYLE, areaGradients } from '../core/style'
import {
  axisLegendOptions,
  formatOptions,
  formatterFrom,
  legendOption,
  seriesLegend,
  topMargin,
} from './common'

/**
 * 折线图：看趋势与拐点。
 * 打开 area 开关即可变成面积图，适合强调累计量级。
 */
const line: ChartDefinition = {
  id: 'line',
  name: '折线图',
  englishName: 'Line',
  category: 'trend',
  description: '展示一个量随时间或有序维度的变化趋势，支持多系列对比与面积填充。',
  dataShape: `推荐用「系列」结构：
[
  { "id": "Web",   "data": [{ "x": "1月", "y": 42 }, { "x": "2月", "y": 51 }] },
  { "id": "App",   "data": [{ "x": "1月", "y": 30 }, { "x": "2月", "y": 38 }] }
]
也支持扁平记录 [{ "x": "1月", "y": 42, "channel": "Web" }]，
会按第一个字符串字段（或 seriesBy 指定字段）自动分组。`,
  nivoPackage: '@nivo/line',
  variants: ['line 折线', 'area 面积', 'step 阶梯'],
  aliases: ['折线', '趋势图', 'trend', 'area', '面积图'],
  options: [
    {
      key: 'curve',
      type: 'string',
      description: '曲线插值方式',
      default: 'monotoneX',
      values: ['linear', 'monotoneX', 'natural', 'step', 'stepAfter', 'basis', 'cardinal'],
    },
    { key: 'area', type: 'boolean', description: '是否填充面积（面积图）', default: false },
    { key: 'points', type: 'boolean', description: '是否显示数据点', default: false },
    { key: 'lineWidth', type: 'number', description: '线宽', default: 3 },
    { key: 'seriesBy', type: 'string', description: '扁平记录下用于分组的字段名' },
    { key: 'xBy', type: 'string', description: 'X 字段名，默认 x' },
    { key: 'yBy', type: 'string', description: 'Y 字段名，默认 y' },
    { key: 'xLegend', type: 'string', description: 'X 轴标题' },
    { key: 'yLegend', type: 'string', description: 'Y 轴标题' },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { id: 'Web', data: [{ x: '1月', y: 42 }, { x: '2月', y: 51 }, { x: '3月', y: 68 }, { x: '4月', y: 74 }] },
      { id: 'App', data: [{ x: '1月', y: 30 }, { x: '2月', y: 38 }, { x: '3月', y: 52 }, { x: '4月', y: 61 }] },
    ],
    options: { area: true, yLegend: 'DAU（万）' },
  },
  render: (ctx) => {
    const series = asSeries(ctx.data, 'line', {
      seriesBy: ctx.options.seriesBy,
      xBy: ctx.options.xBy,
      yBy: ctx.options.yBy,
    })
    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false
    const withArea = ctx.options.area === true
    const gradient = areaGradients(
      series.map((s) => s.id),
      ctx.colors,
    )

    return (
      <Line
        data={series}
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
        xScale={{ type: 'point' }}
        yScale={{ type: 'linear', min: 0, max: 'auto' }}
        curve={ctx.options.curve ?? 'monotoneX'}
        lineWidth={ctx.options.lineWidth ?? STYLE.line.width}
        enableArea={withArea}
        areaOpacity={withArea ? 1 : 0}
        // 渐变填充：贴着折线稍显、往下淡出，比整块色块轻
        defs={withArea ? (gradient.defs as never) : []}
        fill={withArea ? (gradient.fill as never) : []}
        enablePoints={ctx.options.points === true}
        pointSize={STYLE.line.pointSize}
        pointColor={{ from: 'serieColor' }}
        pointBorderWidth={2}
        pointBorderColor={ctx.background}
        enableGridX={false}
        enableSlices="x"
        useMesh
        axisTop={null}
        axisRight={null}
        axisBottom={{
          tickSize: 0,
          tickPadding: STYLE.tickPadding,
          legend: ctx.options.xLegend,
          legendPosition: 'middle',
          legendOffset: 44,
        }}
        axisLeft={{
          tickSize: 0,
          tickPadding: STYLE.tickPadding,
          tickValues: STYLE.tickCount,
          legend: ctx.options.yLegend,
          legendPosition: 'middle',
          legendOffset: -58,
          format,
        }}
        legends={seriesLegend(series, ctx.colors, legend)}
        animate={false}
        role="img"
        ariaLabel="折线图"
      />
    )
  },
}

export default line
