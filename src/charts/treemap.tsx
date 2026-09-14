import { TreeMap } from '@nivo/treemap'
import type { ChartDefinition } from '../core/types'
import { asHierarchy } from './helpers'
import { formatOptions, formatterFrom, legendOption } from './common'

/**
 * 矩形树图：用面积表达占比，比饼图能容纳更多层级和分类。
 */
const treemap: ChartDefinition = {
  id: 'treemap',
  name: '矩形树图',
  englishName: 'TreeMap',
  category: 'hierarchy',
  description: '用矩形面积表达占比，支持多层嵌套，适合看大盘构成。',
  dataShape: `三种写法：
1) 嵌套：{ "name": "总计", "children": [{ "name": "华东", "value": 300 }] }
2) 平铺：[{ "name": "华东", "value": 300 }]（会自动套一个根节点）
3) 路径：[{ "path": "线上/华东/上海", "value": 120 }]（用 / 自动建树）`,
  nivoPackage: '@nivo/treemap',
  variants: ['squarify 方形', 'sliceDice 切片'],
  aliases: ['树图', '矩形树图', 'treemap', '占比方块'],
  options: [
    { key: 'tile', type: 'string', description: '切分算法', default: 'squarify', values: ['squarify', 'slice', 'dice', 'sliceDice', 'binary'] },
    { key: 'innerPadding', type: 'number', description: '子节点内边距', default: 3 },
    { key: 'outerPadding', type: 'number', description: '根节点外边距', default: 4 },
    { key: 'labelSkipSize', type: 'number', description: '小于该面积的矩形不显示标签', default: 26 },
    { key: 'root', type: 'string', description: '自动生成根节点时的名字', default: '总计' },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: {
      name: '总收入',
      children: [
        {
          name: '线上',
          children: [
            { name: '华东', value: 320 },
            { name: '华北', value: 240 },
            { name: '华南', value: 180 },
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
      <TreeMap
        data={data as never}
        identity="name"
        value="value"
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{ top: 12, right: 12, bottom: 12, left: 12 }}
        tile={ctx.options.tile ?? 'squarify'}
        innerPadding={ctx.options.innerPadding ?? 3}
        outerPadding={ctx.options.outerPadding ?? 4}
        labelSkipSize={ctx.options.labelSkipSize ?? 26}
        label={
          ((node: { data?: { name?: string }; id?: string; value?: number }) =>
            `${node.data?.name ?? node.id ?? ''}  ${format(node.value ?? 0)}`) as never
        }
        labelTextColor="#ffffff"
        // 父节点是浅色系 tint，固定白字看不清，跟随底色加深更稳
        parentLabelTextColor={{ from: 'color', modifiers: [['darker', 3.2]] }}
        borderColor={{ from: 'color', modifiers: [['darker', 0.6]] }}
        valueFormat={format}
        animate={false}
        role="img"
        ariaLabel="矩形树图"
      />
    )
  },
}

export default treemap
