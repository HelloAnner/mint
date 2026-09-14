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

    // 节点 id 换成 ASCII 别名再交给 nivo：中文 id 会被 nivo 用做渐变 id，
    // 而 React 会对 fill="url(#中文)" 做 URL 编码，导致引用失配、流变成灰色。
    // 原名保留在 label 上，图里看到的仍然是中文。
    const ascii = new Map(data.nodes.map((node, i) => [String(node.id), `n${i}`]))
    const nodes = data.nodes.map((node) => ({
      id: ascii.get(String(node.id))!,
      label: String(node.id),
    }))

    // nivo 按 nodes 的出现顺序分配调色板颜色，这里用同一套映射给每条流
    // 标注 startColor / endColor，让流呈现「来源色 → 目标色」的渐变。
    const nodeColor = new Map(data.nodes.map((node, i) => [String(node.id), ctx.colors[i % ctx.colors.length]!]))
    const links = data.links.map((link) => {
      const source = String(link.source)
      const target = String(link.target)
      return {
        source: ascii.get(source)!,
        target: ascii.get(target)!,
        value: link.value,
        startColor: nodeColor.get(source),
        endColor: nodeColor.get(target),
      }
    })

    // 亮色背景用 multiply 让流与底色交融；暗色背景下 multiply 会把流吞掉，
    // 换成 screen 才能显出来。
    const bgHex = ctx.background.replace('#', '')
    const luminance =
      (parseInt(bgHex.slice(0, 2), 16) * 0.299 +
        parseInt(bgHex.slice(2, 4), 16) * 0.587 +
        parseInt(bgHex.slice(4, 6), 16) * 0.114) /
      255

    return (
      <Sankey
        data={{ nodes, links } as never}
        label={((node: { label?: string; id: string }) => node.label ?? node.id) as never}
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
        linkOpacity={ctx.options.linkOpacity ?? 0.3}
        linkBlendMode={luminance < 0.5 ? 'screen' : 'multiply'}
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
