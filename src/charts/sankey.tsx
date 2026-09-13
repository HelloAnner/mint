import { Sankey } from '@nivo/sankey'
import type { ChartDefinition } from '../core/types'
import { asGraph } from './helpers'
import { formatOptions, formatterFrom, legendOption } from './common'

/**
 * 桑基图：看流量在节点之间的分配与损耗，宽度即数量。
 */
const sankey: ChartDefinition = {
  id: 'sankey',
  name: '桑基图',
  englishName: 'Sankey',
  category: 'flow',
  description: '用带宽表示流向的规模，展示来源到去向的分配路径。',
  dataShape: `{
  "nodes": [{ "id": "搜索" }, { "id": "注册" }, { "id": "付费" }],
  "links": [{ "source": "搜索", "target": "注册", "value": 320 }]
}
nodes 可以省略，会从 links 的 source/target 自动推导。
source/target 也支持写成 from/to，value 支持写成 weight。`,
  nivoPackage: '@nivo/sankey',
  variants: ['horizontal 横向', 'vertical 纵向'],
  aliases: ['桑基图', 'sankey', '流向图', '流量图'],
  options: [
    { key: 'layout', type: 'string', description: '布局方向', default: 'horizontal', values: ['horizontal', 'vertical'] },
    { key: 'nodeThickness', type: 'number', description: '节点条厚度', default: 16 },
    { key: 'nodeSpacing', type: 'number', description: '节点间距', default: 18 },
    { key: 'linkOpacity', type: 'number', description: '连线透明度', default: 0.28 },
    { key: 'gradient', type: 'boolean', description: '连线是否使用渐变', default: true },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: {
      nodes: [
        { id: '搜索广告' }, { id: '社交媒体' }, { id: '自然流量' },
        { id: '注册' }, { id: '未转化' }, { id: '付费' },
      ],
      links: [
        { source: '搜索广告', target: '注册', value: 320 },
        { source: '社交媒体', target: '注册', value: 210 },
        { source: '自然流量', target: '注册', value: 180 },
        { source: '搜索广告', target: '未转化', value: 140 },
        { source: '社交媒体', target: '未转化', value: 165 },
        { source: '自然流量', target: '未转化', value: 95 },
        { source: '注册', target: '付费', value: 246 },
      ],
    },
  },
  render: (ctx) => {
    const data = asGraph(ctx.data, 'sankey')
    const format = formatterFrom(ctx.options)

    return (
      <Sankey
        data={data as never}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{ top: 20, right: 130, bottom: 20, left: 130 }}
        layout={ctx.options.layout === 'vertical' ? 'vertical' : 'horizontal'}
        nodeThickness={ctx.options.nodeThickness ?? 16}
        nodeSpacing={ctx.options.nodeSpacing ?? 18}
        nodeOpacity={1}
        nodeBorderWidth={0}
        linkOpacity={ctx.options.linkOpacity ?? 0.28}
        enableLinkGradient={ctx.options.gradient !== false}
        labelPosition="outside"
        labelPadding={14}
        valueFormat={format}
        animate={false}
        role="img"
        ariaLabel="桑基图"
      />
    )
  },
}

export default sankey
