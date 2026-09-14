import { tint } from './palettes'

/**
 * mint 的统一视觉规范 —— 现代、克制、可读。
 *
 * 这里集中所有图表共用的「造型参数」，改一处即可全局换风格：
 * - 网格只留极浅的实线，不再用虚线抢注意力；
 * - 数值轴刻度收敛到 5 条左右，标签更淡、更小；
 * - 面积用「主色 → 透明」的竖向渐变，避免整块色块压住图；
 * - 柱子、扇区、数据点统一圆角与描边。
 */
export const STYLE = {
  /** 数值轴最多保留几条刻度。nivo 默认会铺 5~11 条，容易把轴塞满 */
  tickCount: 5,
  tickPadding: 12,
  legend: {
    symbolSize: 9,
    itemHeight: 20,
    itemsSpacing: 16,
  },
  bar: {
    radius: 6,
    padding: 0.3,
    innerPadding: 4,
  },
  line: {
    width: 3,
    pointSize: 7,
    activeWidth: 4.5,
  },
  scatter: {
    size: 10,
  },
  pie: {
    padAngle: 1.2,
    cornerRadius: 6,
    activeOffset: 6,
  },
} as const

/** 面积渐变顶部的最大不透明度，底部淡出到 0 */
const AREA_TOP_OPACITY = 0.3

export interface AreaGradientColor {
  offset: number
  color: string
  opacity: number
}

export interface AreaGradientDef {
  id: string
  type: 'linearGradient'
  colors: AreaGradientColor[]
  /** 渐变方向（0~1 坐标），缺省为自上而下的竖向渐变 */
  x1?: number
  y1?: number
  x2?: number
  y2?: number
}

export interface AreaGradientFill {
  match: { id: string }
  id: string
}

/**
 * 为柱状图的每个 key 生成一条同色系渐变：顶部（横向柱为左端）略亮，
 * 落回主色。比纯色柱多一层光泽感，又不会喧宾夺主。
 *
 * nivo 的 fill 按 key 匹配，defs / fill 结构与 areaGradients 一致。
 */
export function barGradients(
  keys: readonly string[],
  colors: readonly string[],
  horizontal = false,
): { defs: AreaGradientDef[]; fill: AreaGradientFill[] } {
  const gradId = (i: number) => `mint-bar-${i}`
  return {
    defs: keys.map((_, i) => ({
      id: gradId(i),
      type: 'linearGradient' as const,
      colors: [
        { offset: 0, color: tint(colors[i % colors.length]!, 0.3), opacity: 1 },
        { offset: 100, color: colors[i % colors.length]!, opacity: 1 },
      ],
      // 横向柱状图把渐变转成左 → 右
      ...(horizontal ? { x1: 0, y1: 0, x2: 1, y2: 0 } : {}),
    })),
    fill: keys.map((id, i) => ({ match: { id }, id: gradId(i) })),
  }
}

/**
 * 为每个系列生成一条竖向渐变（系列色 → 透明）。
 *
 * 折线/面积图用它替代整块纯色填充：靠近折线处稍显，往下迅速淡出，
 * 既保留了量级的暗示，又不会把网格和下层系列压没。
 */
export function areaGradients(
  seriesIds: readonly string[],
  colors: readonly string[],
): { defs: AreaGradientDef[]; fill: AreaGradientFill[] } {
  const gradId = (i: number) => `mint-area-${i}`
  return {
    defs: seriesIds.map((_, i) => ({
      id: gradId(i),
      type: 'linearGradient' as const,
      colors: [
        { offset: 0, color: colors[i % colors.length]!, opacity: AREA_TOP_OPACITY },
        { offset: 100, color: colors[i % colors.length]!, opacity: 0 },
      ],
    })),
    fill: seriesIds.map((id, i) => ({ match: { id }, id: gradId(i) })),
  }
}
