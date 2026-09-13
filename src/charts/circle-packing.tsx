import { CirclePacking } from '@nivo/circle-packing'
import type { ChartDefinition } from '../core/types'
import { asHierarchy } from './helpers'
import { formatOptions, formatterFrom, legendOption } from './common'

/**
 * 圆形打包图：用圆面积表达占比，观感比矩形树图更柔和，适合放在封面或摘要里。
 */
const circlePacking: ChartDefinition = {
  id: 'circle-packing',
  name: '圆形打包图',
  englishName: 'CirclePacking',
  category: 'hierarchy',
  description: '用嵌套圆的面积表达层级占比，视觉柔和，适合摘要与封面。',
  dataShape: `与矩形树图一致：
{ "name": "总计", "children": [{ "name": "华东", "value": 320 }] }
也接受 [{ "name": "华东", "value": 320 }] 或 [{ "path": "线上/华东", "value": 120 }]。`,
  nivoPackage: '@nivo/circle-packing',
  variants: ['packed 打包'],
  aliases: ['圆打包', '气泡图', '气泡树', 'bubble tree'],
  options: [
    { key: 'padding', type: 'number', description: '圆之间的间距', default: 4 },
    { key: 'labelSkipRadius', type: 'number', description: '半径小于该值的圆不显示标签', default: 12 },
    { key: 'root', type: 'string', description: '自动生成根节点时的名字', default: '总计' },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { name: '搜索广告', value: 348 },
      { name: '社交媒体', value: 266 },
      { name: '合作推荐', value: 184 },
      { name: '内容营销', value: 143 },
      { name: '线下活动', value: 82 },
    ],
    options: { root: '获客渠道' },
  },
  render: (ctx) => {
    const data = asHierarchy(ctx.data, { root: ctx.options.root as string })
    const format = formatterFrom(ctx.options)

    return (
      <CirclePacking
        data={data as never}
        id="name"
        value="value"
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{ top: 12, right: 12, bottom: 12, left: 12 }}
        padding={ctx.options.padding ?? 4}
        labelsSkipRadius={ctx.options.labelSkipRadius ?? 12}
        labelTextColor={{ from: 'color', modifiers: [['brighter', 3]] }}
        borderWidth={1}
        borderColor={{ from: 'color', modifiers: [['darker', 0.5]] }}
        valueFormat={format}
        animate={false}
        role="img"
      />
    )
  },
}

export default circlePacking
