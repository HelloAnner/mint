import { Icicle } from '@nivo/icicle'
import type { ChartDefinition } from '../core/types'
import { asHierarchy } from './helpers'
import { formatOptions, formatterFrom, legendOption } from './common'

/**
 * 冰柱图：用宽高比表达层级占比，比旭日图更适合带文字标签。
 */
const icicle: ChartDefinition = {
  id: 'icicle',
  name: '冰柱图',
  englishName: 'Icicle',
  category: 'hierarchy',
  description: '横向分层的矩形层级图，每层代表一级，宽度代表占比。',
  dataShape: `与矩形树图一致：
{ "name": "总计", "children": [{ "name": "线上", "children": [{ "name": "华东", "value": 320 }] }] }`,
  nivoPackage: '@nivo/icicle',
  variants: ['vertical 纵向', 'horizontal 横向'],
  aliases: ['冰柱图', 'icicle', '层级条形'],
  options: [
    { key: 'orientation', type: 'string', description: '展开方向', default: 'vertical', values: ['vertical', 'horizontal'] },
    { key: 'borderWidth', type: 'number', description: '矩形描边宽度', default: 1 },
    { key: 'labelSkipWidth', type: 'number', description: '过窄的矩形不显示标签', default: 24 },
    { key: 'root', type: 'string', description: '自动生成根节点时的名字', default: '总计' },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: {
      name: '总计',
      children: [
        {
          name: '线上',
          children: [
            { name: '华东', value: 320 },
            { name: '华北', value: 240 },
          ],
        },
        {
          name: '线下',
          children: [
            { name: '门店', value: 210 },
            { name: '经销', value: 150 },
          ],
        },
      ],
    },
  },
  render: (ctx) => {
    const data = asHierarchy(ctx.data, { root: ctx.options.root as string })
    const format = formatterFrom(ctx.options)

    return (
      <Icicle
        data={data as never}
        identity="name"
        value="value"
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{ top: 12, right: 12, bottom: 12, left: 12 }}
        orientation={ctx.options.orientation === 'horizontal' ? 'right' : 'top'}
        borderWidth={ctx.options.borderWidth ?? 1}
        borderColor={{ from: 'color', modifiers: [['darker', 0.6]] }}
        enableLabels
        label={(node: { id: string; data?: { name?: string } }) => node.data?.name ?? node.id}
        labelSkipWidth={ctx.options.labelSkipWidth ?? 24}
        labelSkipHeight={12}
        labelTextColor={{ from: 'color', modifiers: [['brighter', 3]] }}
        valueFormat={format}
        animate={false}
        role="img"
        ariaLabel="冰柱图"
      />
    )
  },
}

export default icicle
