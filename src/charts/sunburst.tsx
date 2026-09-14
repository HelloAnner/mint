import { Sunburst } from '@nivo/sunburst'
import type { ChartDefinition } from '../core/types'
import { asHierarchy } from './helpers'
import { formatOptions, formatterFrom, legendOption } from './common'

/**
 * 旭日图：环形分层，看层级结构和每一层的占比。
 */
const sunburst: ChartDefinition = {
  id: 'sunburst',
  name: '旭日图',
  englishName: 'Sunburst',
  category: 'hierarchy',
  description: '用同心环表达多层级的构成，从内到外逐层展开。',
  dataShape: `与矩形树图一致，同为层级结构：
{ "name": "总计", "children": [{ "name": "线上", "children": [{ "name": "华东", "value": 320 }] }] }
也接受 [{ "name": "华东", "value": 320 }] 或 [{ "path": "线上/华东", "value": 120 }]。`,
  nivoPackage: '@nivo/sunburst',
  variants: ['sunburst 旭日'],
  aliases: ['旭日图', 'sunburst', '环形层级'],
  options: [
    { key: 'cornerRadius', type: 'number', description: '扇区圆角', default: 3 },
    { key: 'borderWidth', type: 'number', description: '扇区描边宽度', default: 1 },
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
      <Sunburst
        data={data as never}
        id="name"
        value="value"
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{ top: 12, right: 12, bottom: 12, left: 12 }}
        cornerRadius={ctx.options.cornerRadius ?? 3}
        borderWidth={ctx.options.borderWidth ?? 1}
        borderColor={{ from: 'color', modifiers: [['darker', 0.5]] }}
        enableArcLabels
        arcLabel={((node: { id: string | number; data?: { name?: string } }) => node.data?.name ?? String(node.id)) as never}
        arcLabelsSkipAngle={12}
        valueFormat={format}
        animate={false}
        role="img"
      />
    )
  },
}

export default sunburst
