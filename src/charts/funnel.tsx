import { Funnel } from '@nivo/funnel'
import type { ChartDefinition } from '../core/types'
import { asPairs } from './helpers'
import { formatOptions, formatterFrom, legendOption } from './common'

/**
 * 漏斗图：看逐级转化与流失，转化率分析的标准图。
 */
const funnel: ChartDefinition = {
  id: 'funnel',
  name: '漏斗图',
  englishName: 'Funnel',
  category: 'flow',
  description: '展示多级流程中每一步的留存与流失，适合转化率分析。',
  dataShape: `按流程顺序排列：
[
  { "id": "访问", "label": "访问", "value": 12000 },
  { "id": "注册", "label": "注册", "value": 4800 },
  { "id": "下单", "label": "下单", "value": 1900 }
]
也支持 { "访问": 12000, "注册": 4800 } 或 [["访问", 12000], ["注册", 4800]]。`,
  nivoPackage: '@nivo/funnel',
  variants: ['funnel 漏斗'],
  aliases: ['漏斗', '转化', 'funnel', '转化率'],
  options: [
    { key: 'spacing', type: 'number', description: '层与层的间距', default: 4 },
    { key: 'shapeBlending', type: 'number', description: '形状融合程度 0~1', default: 0.66 },
    { key: 'valueLabel', type: 'boolean', description: '是否显示数值', default: true },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { id: 'visit', label: '访问落地页', value: 12000 },
      { id: 'signup', label: '注册账号', value: 4800 },
      { id: 'active', label: '完成激活', value: 2600 },
      { id: 'order', label: '首次下单', value: 1900 },
      { id: 'repeat', label: '复购', value: 860 },
    ],
  },
  render: (ctx) => {
    const data = asPairs(ctx.data, 'funnel')
    const format = formatterFrom(ctx.options)
    const showValue = ctx.options.valueLabel !== false

    // nivo 自带的 labels 层只会画数值，这里换成「阶段名 + 数值」两层文字：
    // 阶段名常驻，数值只在层高够时叠在下面，避免窄层里两行挤爆。
    interface FunnelPartLike {
      data: { id: string | number; label?: string }
      x: number
      y: number
      width: number
      height: number
      formattedValue: string | number
      labelColor: string
    }
    const labelsLayer = (({ parts }: { parts: FunnelPartLike[] }) => (
      <g>
        {parts.map((part) => (
          <g key={String(part.data.id)} transform={`translate(${part.x}, ${part.y})`}>
            <text
              y={showValue && part.height >= 46 ? -7 : 0}
              textAnchor="middle"
              dominantBaseline="central"
              fontFamily={ctx.fontFamily}
              fontSize={13}
              fontWeight={600}
              fill={part.labelColor}
            >
              {part.data.label ?? String(part.data.id)}
            </text>
            {showValue && part.height >= 46 ? (
              <text
                y={11}
                textAnchor="middle"
                dominantBaseline="central"
                fontFamily={ctx.fontFamily}
                fontSize={11.5}
                fill={part.labelColor}
                opacity={0.85}
              >
                {part.formattedValue}
              </text>
            ) : null}
          </g>
        ))}
      </g>
    )) as never

    return (
      <Funnel
        data={data}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{ top: 24, right: 120, bottom: 24, left: 120 }}
        spacing={ctx.options.spacing ?? 4}
        shapeBlending={ctx.options.shapeBlending ?? 0.66}
        borderWidth={0}
        layers={['separators', 'parts', labelsLayer]}
        labelColor={{ from: 'color', modifiers: [['brighter', 3]] }}
        valueFormat={format}
        animate={false}
        role="img"
        ariaLabel="漏斗图"
      />
    )
  },
}

export default funnel
