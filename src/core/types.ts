import type { ReactElement } from 'react'
import type { PartialTheme } from '@nivo/theming'

export type ChartCategory =
  | 'comparison'
  | 'trend'
  | 'composition'
  | 'distribution'
  | 'hierarchy'
  | 'flow'
  | 'relation'

export const CATEGORY_LABELS: Record<ChartCategory, string> = {
  comparison: '比较',
  trend: '趋势',
  composition: '构成',
  distribution: '分布',
  hierarchy: '层级',
  flow: '流向',
  relation: '关系',
}

export type OptionType = 'string' | 'number' | 'boolean' | 'array' | 'object'

/** 图表可选项的描述，用于生成文档与做基础校验 */
export interface OptionSpec {
  key: string
  type: OptionType
  description: string
  default?: unknown
  values?: readonly (string | number)[]
}

/** 传给每个图表 render 函数的上下文 */
export interface RenderContext<O = Record<string, unknown>> {
  /** 归一化后的数据 */
  data: unknown
  /** 合并默认值后的图表选项 */
  options: O
  /** 绘图区宽度（不含页边距） */
  width: number
  /** 绘图区高度（不含页边距） */
  height: number
  /** nivo 主题 */
  theme: PartialTheme
  /** 调色板 */
  colors: string[]
  /** 字体族名 */
  fontFamily: string
  /** 主题对应的前景色 */
  foreground: string
  /** 主题对应的次要文字色 */
  muted: string
}

export interface ChartDefinition<O = any> {
  /** 命令里使用的 id，如 bar */
  id: string
  /** 中文名 */
  name: string
  /** 英文名 */
  englishName: string
  category: ChartCategory
  /** 一句话说明 */
  description: string
  /** 数据结构说明，给人和 AI 看 */
  dataShape: string
  /** nivo 包名 */
  nivoPackage: string
  /** 变体说明，如 grouped / stacked */
  variants?: readonly string[]
  /** 别名，便于模糊匹配 */
  aliases?: readonly string[]
  options?: readonly OptionSpec[]
  example: {
    data: unknown
    options?: Record<string, unknown>
  }
  render: (ctx: RenderContext<O>) => ReactElement
}
