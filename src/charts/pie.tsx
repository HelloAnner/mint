import { Pie } from '@nivo/pie'
import type { ChartDefinition } from '../core/types'
import { asPairs } from './helpers'
import { formatOptions, formatterFrom, legendOption } from './common'

/**
 * 环形图 / 饼图：看构成占比。
 * 分类超过 6 个时建议改用柱状图或树图，饼图会难以辨读。
 */
const pie: ChartDefinition = {
  id: 'pie',
  name: '环形图 / 饼图',
  englishName: 'Pie',
  category: 'composition',
  description: '展示各部分占整体的比例，环形模式可在中心放一个总量指标。',
  dataShape: `支持三种写法：
1) [{ "id": "搜索", "label": "搜索广告", "value": 348 }]
2) { "搜索": 348, "社交": 266 }
3) [["搜索", 348], ["社交", 266]]`,
  nivoPackage: '@nivo/pie',
  variants: ['donut 环形', 'pie 实心饼'],
  aliases: ['饼图', '环形图', 'donut', '甜甜圈', '占比图'],
  options: [
    { key: 'donut', type: 'boolean', description: '是否为环形（中空）', default: true },
    { key: 'innerRadius', type: 'number', description: '内半径比例 0~1，donut 打开时生效', default: 0.62 },
    { key: 'padAngle', type: 'number', description: '扇区间隔角度', default: 1.6 },
    { key: 'cornerRadius', type: 'number', description: '扇区圆角', default: 6 },
    { key: 'linkLabels', type: 'boolean', description: '是否显示外圈引导线与标签', default: true },
    { key: 'sortByValue', type: 'boolean', description: '是否按数值从大到小排序', default: true },
    legendOption,
    ...formatOptions,
  ],
  example: {
    data: [
      { id: 'search', label: '搜索广告', value: 348 },
      { id: 'social', label: '社交媒体', value: 266 },
      { id: 'referral', label: '合作推荐', value: 184 },
      { id: 'content', label: '内容营销', value: 143 },
      { id: 'offline', label: '线下活动', value: 82 },
    ],
    options: { donut: true },
  },
  render: (ctx) => {
    let data = asPairs(ctx.data, 'pie')
    if (ctx.options.sortByValue !== false) {
      data = [...data].sort((a, b) => b.value - a.value)
    }
    const format = formatterFrom(ctx.options)
    const legend = ctx.options.legend !== false
    const showLinks = ctx.options.linkLabels !== false

    return (
      <Pie
        data={data}
        width={ctx.width}
        height={ctx.height}
        theme={ctx.theme}
        colors={ctx.colors}
        margin={{ top: 20, right: showLinks ? 110 : 24, bottom: legend ? 54 : 20, left: showLinks ? 110 : 24 }}
        innerRadius={ctx.options.donut === false ? 0 : (ctx.options.innerRadius ?? 0.62)}
        padAngle={ctx.options.padAngle ?? 1.6}
        cornerRadius={ctx.options.cornerRadius ?? 6}
        activeOuterRadiusOffset={8}
        borderWidth={0}
        enableArcLinkLabels={showLinks}
        arcLinkLabel="label"
        arcLinkLabelsSkipAngle={8}
        arcLinkLabelsThickness={1.5}
        arcLinkLabelsColor={{ from: 'color' }}
        arcLinkLabelsTextColor={ctx.muted}
        arcLinkLabelsDiagonalLength={14}
        arcLinkLabelsStraightLength={14}
        enableArcLabels={false}
        valueFormat={format}
        legends={
          legend
            ? [
                {
                  anchor: 'bottom',
                  direction: 'row',
                  translateY: 42,
                  itemWidth: 92,
                  itemHeight: 18,
                  itemsSpacing: 10,
                  symbolSize: 9,
                  symbolShape: 'circle',
                },
              ]
            : []
        }
        animate={false}
        role="img"
      />
    )
  },
}

export default pie
