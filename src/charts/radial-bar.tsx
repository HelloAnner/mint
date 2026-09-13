import { RadialBar } from '@nivo/radial-bar'
import type { ChartDefinition } from '../core/types'
import { asSeries } from './helpers'
import { formatOptions, formatterFrom, legendOption, seriesLegend } from './common'

/**
 * 径向条形图：把条形弯成圆弧，适合在有限宽度里放很多类别。
 */
const radialBar: ChartDefinition = {
  id: 'radial-bar',
  name: '径向条形图',
  englishName: 'RadialBar',
  category: 'comparison',
  description: '把条形沿圆周排布，省横向空间，适合类别很多的排名对比。',
  dataShape: `每个环一个系列：
[
  { "id": "华东", "data": [{ "x": "Q1", "y": 128 }, { "x": "Q2", "y": 152 }] }
]
也支持 { "华东": [128, 152] } 配合 labels 选项。`,
  nivoPackage: '@nivo/radial-bar',
  variants: ['circular 环形'],
  aliases: ['径向条形图', '圆形条形', 'radial bar', '环形柱状'],
  options: [
    { key: 'innerRadius', type: 'number', description: '内半径比例', default: 0.3 },
    { key: 'padAngle', type: 'number', description: '扇形间隔', default: 0.6 },
    { key: 'cornerRadius', type: 'number', description: '圆角', default: 3 },
    { key: 'tracks', type: 'boolean', description: '是否显示底轨', default: true },
    { key: 'tracksColor', type: 'string', description: '底轨颜色', default: '#f1f5f9' },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { id: '华东', data: [{ x: 'Q1', y: 128 }, { x: 'Q2', y: 152 }, { x: 'Q3', y: 141 }, { x: 'Q4', y: 187 }] },
      { id: '华北', data: [{ x: 'Q1', y: 96 }, { x: 'Q2', y: 108 }, { x: 'Q3', y: 124 }, { x: 'Q4', y: 139 }] },
      { id: '华南', data: [{ x: 'Q1', y: 74 }, { x: 'Q2', y: 88 }, { x: 'Q3', y: 103 }, { x: 'Q4', y: 121 }] },
    ],
  },
  render: (ctx) => {
    const series = asSeries(ctx.data, 'radial-bar')
    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false

    return (
      <RadialBar
        data={series as never}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{ top: 24, right: 40, bottom: legend ? 66 : 24, left: 40 }}
        innerRadius={ctx.options.innerRadius ?? 0.3}
        padAngle={ctx.options.padAngle ?? 0.6}
        cornerRadius={ctx.options.cornerRadius ?? 3}
        valueFormat={format}
        enableTracks={ctx.options.tracks !== false}
        tracksColor={(ctx.options.tracksColor as string) ?? '#f1f5f9'}
        enableRadialGrid
        enableCircularGrid
        enableLabels={false}
        legends={seriesLegend(series, ctx.colors, legend)}
        animate={false}
        role="img"
        ariaLabel="径向条形图"
      />
    )
  },
}

export default radialBar
