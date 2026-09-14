import type { ChartDefinition } from '../core/types'
import { fail } from '../core/errors'
import { isPlainObject } from './helpers'
import {
  arrowPoints,
  bezierMid,
  ellipsize,
  isDarkBackground,
  midpoint,
  round,
  textWidth,
  type Point,
} from './diagram-utils'

/* ─────────────────────────── 数据归一化 ─────────────────────────── */

interface ArchNode {
  id: string
  label: string
  description?: string
}

interface ArchLayer {
  name: string
  nodes: ArchNode[]
}

interface ArchEdge {
  from: string
  to: string
  label?: string
}

export interface ArchitectureDiagram {
  layers: ArchLayer[]
  edges: ArchEdge[]
}

const CHART = 'architecture'

function shapeHint(): string {
  return '推荐写法：{ "layers": [{ "name": "接入层", "nodes": [{ "id": "gateway", "label": "API 网关" }] }], "edges": [{ "from": "web", "to": "gateway", "label": "HTTPS" }] }'
}

function readNode(raw: unknown, where: string): ArchNode {
  if (typeof raw === 'string' || typeof raw === 'number') {
    const text = String(raw)
    return { id: text, label: text }
  }
  if (isPlainObject(raw)) {
    const rawId = raw.id ?? raw.name ?? raw.label
    if (rawId === undefined) {
      fail('INVALID_DATA', `${where} 缺少 id（也可以用 name / label）`, shapeHint())
    }
    const id = String(rawId)
    const description = raw.description ?? raw.desc ?? raw.detail ?? raw.note
    return {
      id,
      label: String(raw.label ?? raw.name ?? id),
      description: description === undefined || description === null ? undefined : String(description),
    }
  }
  fail('INVALID_DATA', `${where} 必须是字符串或对象`, shapeHint())
}

function readLayerNodes(layer: Record<string, unknown>, where: string): unknown {
  const nodes = layer.nodes ?? layer.items ?? layer.children
  if (nodes === undefined) fail('INVALID_DATA', `${where} 缺少 nodes`, shapeHint())
  return nodes
}

/**
 * 解析架构图数据，兼容三种常见写法：
 * - { layers: [{ name, nodes }], edges }
 * - { layers: { 接入层: [...], 服务层: [...] }, edges }
 * - { nodes: [{ id, layer }], edges }  （按 layer / group 字段自动分层，顺序取首次出现）
 */
export function normalizeArchitecture(data: unknown): ArchitectureDiagram {
  if (!isPlainObject(data)) {
    fail('INVALID_DATA', `${CHART} 需要对象数据，收到 ${typeof data}`, shapeHint())
  }

  const layers: ArchLayer[] = []

  const pushLayer = (name: string, rawNodes: unknown, where: string) => {
    if (!Array.isArray(rawNodes)) {
      fail('INVALID_DATA', `${where} 的 nodes 必须是数组`, shapeHint())
    }
    const nodes = rawNodes.map((node, i) => readNode(node, `${where} 第 ${i + 1} 个节点`))
    if (nodes.length > 0) layers.push({ name, nodes })
  }

  if (Array.isArray(data.layers)) {
    data.layers.forEach((layer, i) => {
      if (!isPlainObject(layer)) {
        fail('INVALID_DATA', `layers 第 ${i + 1} 项必须是对象`, '形如 { "name": "接入层", "nodes": [...] }')
      }
      const name = String(layer.name ?? layer.title ?? layer.label ?? `层级 ${i + 1}`)
      pushLayer(name, readLayerNodes(layer, `layers 第 ${i + 1} 项`), `layers 第 ${i + 1} 项`)
    })
  } else if (isPlainObject(data.layers)) {
    for (const [name, rawNodes] of Object.entries(data.layers)) {
      pushLayer(name, rawNodes, `layer「${name}」`)
    }
  }

  if (layers.length === 0 && Array.isArray(data.nodes)) {
    const order: string[] = []
    const grouped = new Map<string, ArchNode[]>()
    data.nodes.forEach((raw, i) => {
      const node = readNode(raw, `第 ${i + 1} 个节点`)
      const group = isPlainObject(raw) ? String(raw.layer ?? raw.group ?? raw.tier ?? '默认') : '默认'
      if (!grouped.has(group)) {
        grouped.set(group, [])
        order.push(group)
      }
      grouped.get(group)!.push(node)
    })
    for (const name of order) layers.push({ name, nodes: grouped.get(name)! })
  }

  if (layers.length === 0) {
    fail('INVALID_DATA', '架构图没有解析出任何节点', shapeHint())
  }

  const nodesById = new Map<string, ArchNode>()
  for (const layer of layers) {
    for (const node of layer.nodes) {
      if (nodesById.has(node.id)) {
        fail('INVALID_DATA', `节点 id 重复：${node.id}`, '每个节点需要一个唯一 id')
      }
      nodesById.set(node.id, node)
    }
  }

  const rawEdges = data.edges ?? data.links ?? []
  if (!Array.isArray(rawEdges)) {
    fail('INVALID_DATA', 'edges 必须是数组', '形如 [{ "from": "web", "to": "gateway", "label": "HTTPS" }]')
  }

  const edges: ArchEdge[] = rawEdges.map((raw, i) => {
    if (!isPlainObject(raw)) fail('INVALID_DATA', `第 ${i + 1} 条连线必须是对象`, shapeHint())
    const from = raw.from ?? raw.source ?? raw.start
    const to = raw.to ?? raw.target ?? raw.end
    if (from === undefined || to === undefined) {
      fail('INVALID_DATA', `第 ${i + 1} 条连线缺少 from / to`, '形如 { "from": "web", "to": "gateway" }')
    }
    const edge: ArchEdge = {
      from: String(from),
      to: String(to),
      label: raw.label === undefined || raw.label === null ? undefined : String(raw.label),
    }
    for (const [key, id] of [['from', edge.from], ['to', edge.to]] as const) {
      if (!nodesById.has(id)) {
        fail(
          'INVALID_DATA',
          `第 ${i + 1} 条连线的 ${key}「${id}」不是已定义的节点`,
          `可用节点：${[...nodesById.keys()].join('、')}`,
        )
      }
    }
    return edge
  })

  return { layers, edges }
}

/* ─────────────────────────── 排版度量 ─────────────────────────── */

interface NodeBox {
  node: ArchNode
  layer: number
  x: number
  y: number
  width: number
  height: number
  label: string
  description?: string
}

interface LayerBox {
  name: string
  index: number
  x: number
  y: number
  width: number
  height: number
}

interface Layout {
  nodes: Map<string, NodeBox>
  layers: LayerBox[]
  width: number
  height: number
}

export type Direction = 'vertical' | 'horizontal'
export type EdgeStyle = 'curve' | 'straight' | 'elbow'

interface LayoutConfig {
  direction: Direction
  showLayers: boolean
  showDescriptions: boolean
  nodeGap: number
  layerGap: number
  minNodeWidth: number
  maxNodeWidth: number
  labelSize: number
  descriptionSize: number
}

const NODE = { padX: 18, padY: 12, descGap: 4, lineRatio: 1.28 }
const BAND = { padX: 16, padTop: 12, padBottom: 14 }
const LAYER_TITLE = { size: 12.5, gap: 10 }

function measureNode(node: ArchNode, cfg: LayoutConfig) {
  const maxText = Math.max(40, cfg.maxNodeWidth - NODE.padX * 2)
  const label = ellipsize(node.label, maxText, cfg.labelSize)
  const description =
    cfg.showDescriptions && node.description
      ? ellipsize(node.description, maxText, cfg.descriptionSize)
      : undefined
  const textW = Math.max(
    textWidth(label, cfg.labelSize),
    description ? textWidth(description, cfg.descriptionSize) : 0,
  )
  const minWidth = Math.min(cfg.minNodeWidth, cfg.maxNodeWidth)
  const width = Math.round(Math.min(cfg.maxNodeWidth, Math.max(minWidth, textW + NODE.padX * 2)))
  const height = Math.round(
    cfg.labelSize * NODE.lineRatio +
      (description ? NODE.descGap + cfg.descriptionSize * NODE.lineRatio : 0) +
      NODE.padY * 2,
  )
  return { width, height, label, description }
}

function sum(values: number[]): number {
  return values.reduce((acc, value) => acc + value, 0)
}

function layoutDiagram(diagram: ArchitectureDiagram, cfg: LayoutConfig): Layout {
  const titleHeight = cfg.showLayers ? LAYER_TITLE.size + LAYER_TITLE.gap : 0
  const nodes = new Map<string, NodeBox>()
  const layers: LayerBox[] = []

  // 每层的方块尺寸只量一次，布局与绘制共用
  const measured = diagram.layers.map((layer) =>
    layer.nodes.map((node) => ({ node, size: measureNode(node, cfg) })),
  )

  if (cfg.direction === 'vertical') {
    // 层是横向的带子：宽度取最宽的一层
    let contentWidth = 240
    for (const row of measured) {
      const rowWidth = sum(row.map((item) => item.size.width)) + cfg.nodeGap * Math.max(0, row.length - 1)
      contentWidth = Math.max(contentWidth, rowWidth + BAND.padX * 2)
    }
    contentWidth = Math.round(contentWidth)

    let top = 0
    measured.forEach((row, layerIndex) => {
      const maxHeight = Math.max(...row.map((item) => item.size.height))
      const bandHeight = Math.round(BAND.padTop + titleHeight + maxHeight + BAND.padBottom)
      layers.push({
        name: diagram.layers[layerIndex]!.name,
        index: layerIndex,
        x: 0,
        y: top,
        width: contentWidth,
        height: bandHeight,
      })

      const rowWidth = sum(row.map((item) => item.size.width)) + cfg.nodeGap * Math.max(0, row.length - 1)
      const nodeTop = top + BAND.padTop + titleHeight
      let left = (contentWidth - rowWidth) / 2
      for (const item of row) {
        nodes.set(item.node.id, {
          node: item.node,
          layer: layerIndex,
          x: Math.round(left),
          y: Math.round(nodeTop + (maxHeight - item.size.height) / 2),
          width: item.size.width,
          height: item.size.height,
          label: item.size.label,
          description: item.size.description,
        })
        left += item.size.width + cfg.nodeGap
      }
      top += bandHeight + cfg.layerGap
    })

    return { nodes, layers, width: contentWidth, height: Math.round(Math.max(1, top - cfg.layerGap)) }
  }

  // 层是纵向的柱子：高度取最高的一层
  let contentHeight = 200
  for (const column of measured) {
    const columnHeight = sum(column.map((item) => item.size.height)) + cfg.nodeGap * Math.max(0, column.length - 1)
    contentHeight = Math.max(contentHeight, columnHeight + BAND.padTop + BAND.padBottom + titleHeight)
  }
  contentHeight = Math.round(contentHeight)

  let cursor = 0
  measured.forEach((column, layerIndex) => {
    const maxWidth = Math.max(...column.map((item) => item.size.width))
    const bandWidth = Math.round(BAND.padX * 2 + maxWidth)
    layers.push({
      name: diagram.layers[layerIndex]!.name,
      index: layerIndex,
      x: cursor,
      y: 0,
      width: bandWidth,
      height: contentHeight,
    })

    const columnHeight = sum(column.map((item) => item.size.height)) + cfg.nodeGap * Math.max(0, column.length - 1)
    const areaTop = BAND.padTop + titleHeight
    const areaHeight = contentHeight - areaTop - BAND.padBottom
    let top = areaTop + (areaHeight - columnHeight) / 2
    for (const item of column) {
      nodes.set(item.node.id, {
        node: item.node,
        layer: layerIndex,
        x: Math.round(cursor + BAND.padX + (maxWidth - item.size.width) / 2),
        y: Math.round(top),
        width: item.size.width,
        height: item.size.height,
        label: item.size.label,
        description: item.size.description,
      })
      top += item.size.height + cfg.nodeGap
    }
    cursor += bandWidth + cfg.layerGap
  })

  return { nodes, layers, width: Math.round(Math.max(1, cursor - cfg.layerGap)), height: contentHeight }
}

/* ─────────────────────────── 连线几何 ─────────────────────────── */

function centerOf(box: NodeBox): Point {
  return { x: box.x + box.width / 2, y: box.y + box.height / 2 }
}

/** 锚点：优先从「前进方向」的那条边进出，同层则走左右（横向布局走上下）。 */
function anchors(a: NodeBox, b: NodeBox, direction: Direction): { from: Point; to: Point } {
  const ca = centerOf(a)
  const cb = centerOf(b)

  if (direction === 'vertical') {
    if (a.layer === b.layer) {
      return cb.x >= ca.x
        ? { from: { x: a.x + a.width, y: ca.y }, to: { x: b.x, y: cb.y } }
        : { from: { x: a.x, y: ca.y }, to: { x: b.x + b.width, y: cb.y } }
    }
    return cb.y > ca.y
      ? { from: { x: ca.x, y: a.y + a.height }, to: { x: cb.x, y: b.y } }
      : { from: { x: ca.x, y: a.y }, to: { x: cb.x, y: b.y + b.height } }
  }

  if (a.layer === b.layer) {
    return cb.y >= ca.y
      ? { from: { x: ca.x, y: a.y + a.height }, to: { x: cb.x, y: b.y } }
      : { from: { x: ca.x, y: a.y }, to: { x: cb.x, y: b.y + b.height } }
  }
  return cb.x > ca.x
    ? { from: { x: a.x + a.width, y: ca.y }, to: { x: b.x, y: cb.y } }
    : { from: { x: a.x, y: ca.y }, to: { x: b.x + b.width, y: cb.y } }
}

/** 同层两块之间是否夹着第三个方块：夹着就不能直连，需要绕行。 */
function sameLayerBlocked(layout: Layout, a: NodeBox, b: NodeBox, direction: Direction): boolean {
  const others = [...layout.nodes.values()].filter(
    (box) => box.layer === a.layer && box.node.id !== a.node.id && box.node.id !== b.node.id,
  )
  if (others.length === 0) return false
  if (direction === 'vertical') {
    const [left, right] = a.x <= b.x ? [a, b] : [b, a]
    const start = left.x + left.width
    return others.some((box) => box.x + box.width > start && box.x < right.x)
  }
  const [top, bottom] = a.y <= b.y ? [a, b] : [b, a]
  const start = top.y + top.height
  return others.some((box) => box.y + box.height > start && box.y < bottom.y)
}

interface EdgeGeometry {
  d: string
  arrow: string
  label: Point
}

function edgeGeometry(
  a: NodeBox,
  b: NodeBox,
  direction: Direction,
  style: EdgeStyle,
  arrowSize: number,
  detour: number,
): EdgeGeometry {
  // 自环：从方块顶部绕一圈回到自己
  if (a.node.id === b.node.id) {
    const cx = a.x + a.width / 2
    const top = a.y
    const spread = Math.min(a.width * 0.26, 44)
    const rise = 34
    const d = `M ${round(cx - spread)} ${round(top)} C ${round(cx - spread * 1.5)} ${round(top - rise)}, ${round(cx + spread * 1.5)} ${round(top - rise)}, ${round(cx + spread)} ${round(top)}`
    return {
      d,
      arrow: arrowPoints({ x: cx + spread, y: top }, { x: -spread * 0.5, y: rise }, arrowSize),
      label: { x: cx, y: top - rise + 4 },
    }
  }

  // 同层却隔着别的方块：直连会从中间那个方块身上穿过去，改为从下侧（横向布局则右侧）绕行
  if (detour > 0) {
    const vertical = direction === 'vertical'
    const from = vertical
      ? { x: a.x + a.width / 2, y: a.y + a.height }
      : { x: a.x + a.width, y: a.y + a.height / 2 }
    const to = vertical
      ? { x: b.x + b.width / 2, y: b.y + b.height }
      : { x: b.x + b.width, y: b.y + b.height / 2 }
    const outward = vertical ? detour : detour
    const c1 = vertical ? { x: from.x, y: from.y + outward } : { x: from.x + outward, y: from.y }
    const c2 = vertical ? { x: to.x, y: to.y + outward } : { x: to.x + outward, y: to.y }
    const corner1 = vertical ? { x: from.x, y: from.y + outward } : { x: from.x + outward, y: from.y }
    const corner2 = vertical ? { x: to.x, y: to.y + outward } : { x: to.x + outward, y: to.y }
    if (style === 'straight') {
      return {
        d: `M ${round(from.x)} ${round(from.y)} L ${round(to.x)} ${round(to.y)}`,
        arrow: arrowPoints(to, { x: to.x - from.x, y: to.y - from.y }, arrowSize),
        label: midpoint(from, to),
      }
    }
    if (style === 'elbow') {
      return {
        d: `M ${round(from.x)} ${round(from.y)} L ${round(corner1.x)} ${round(corner1.y)} L ${round(corner2.x)} ${round(corner2.y)} L ${round(to.x)} ${round(to.y)}`,
        arrow: arrowPoints(to, { x: to.x - corner2.x, y: to.y - corner2.y }, arrowSize),
        label: vertical ? { x: (from.x + to.x) / 2, y: from.y + outward } : { x: from.x + outward, y: (from.y + to.y) / 2 },
      }
    }
    return {
      d: `M ${round(from.x)} ${round(from.y)} C ${round(c1.x)} ${round(c1.y)}, ${round(c2.x)} ${round(c2.y)}, ${round(to.x)} ${round(to.y)}`,
      arrow: arrowPoints(to, { x: to.x - c2.x, y: to.y - c2.y }, arrowSize),
      label: bezierMid(from, c1, c2, to),
    }
  }

  const { from, to } = anchors(a, b, direction)
  const dx = to.x - from.x
  const dy = to.y - from.y
  const travelsVertically = Math.abs(dy) >= Math.abs(dx)

  if (style === 'straight') {
    return {
      d: `M ${round(from.x)} ${round(from.y)} L ${round(to.x)} ${round(to.y)}`,
      arrow: arrowPoints(to, { x: dx, y: dy }, arrowSize),
      label: midpoint(from, to),
    }
  }

  if (style === 'elbow') {
    if (travelsVertically) {
      if (Math.abs(dx) < 0.5) {
        return {
          d: `M ${round(from.x)} ${round(from.y)} L ${round(to.x)} ${round(to.y)}`,
          arrow: arrowPoints(to, { x: 0, y: dy }, arrowSize),
          label: midpoint(from, to),
        }
      }
      const midY = (from.y + to.y) / 2
      return {
        d: `M ${round(from.x)} ${round(from.y)} L ${round(from.x)} ${round(midY)} L ${round(to.x)} ${round(midY)} L ${round(to.x)} ${round(to.y)}`,
        arrow: arrowPoints(to, { x: 0, y: dy }, arrowSize),
        label: { x: (from.x + to.x) / 2, y: midY },
      }
    }
    if (Math.abs(dy) < 0.5) {
      return {
        d: `M ${round(from.x)} ${round(from.y)} L ${round(to.x)} ${round(to.y)}`,
        arrow: arrowPoints(to, { x: dx, y: 0 }, arrowSize),
        label: midpoint(from, to),
      }
    }
    const midX = (from.x + to.x) / 2
    return {
      d: `M ${round(from.x)} ${round(from.y)} L ${round(midX)} ${round(from.y)} L ${round(midX)} ${round(to.y)} L ${round(to.x)} ${round(to.y)}`,
      arrow: arrowPoints(to, { x: dx, y: 0 }, arrowSize),
      label: { x: midX, y: (from.y + to.y) / 2 },
    }
  }

  // curve：控制点沿主方向拉开，得到平滑的 S 形
  const c1 = travelsVertically ? { x: from.x, y: from.y + dy / 2 } : { x: from.x + dx / 2, y: from.y }
  const c2 = travelsVertically ? { x: to.x, y: to.y - dy / 2 } : { x: to.x - dx / 2, y: to.y }
  return {
    d: `M ${round(from.x)} ${round(from.y)} C ${round(c1.x)} ${round(c1.y)}, ${round(c2.x)} ${round(c2.y)}, ${round(to.x)} ${round(to.y)}`,
    arrow: arrowPoints(to, { x: to.x - c2.x, y: to.y - c2.y }, arrowSize),
    label: bezierMid(from, c1, c2, to),
  }
}

/* ─────────────────────────── 主题适配 ─────────────────────────── */

/* ─────────────────────────── 图表定义 ─────────────────────────── */

/**
 * 架构图：把系统拆成若干层，每层若干方块，方块之间用带箭头的连线表示调用关系。
 * 与其它图表不同，这张图由 mint 自绘 SVG —— nivo 没有分层方块布局。
 */
const architecture: ChartDefinition = {
  id: 'architecture',
  name: '架构图',
  englishName: 'Architecture Diagram',
  category: 'relation',
  description: '把系统画成分层方块图：层是横向的带子，方块是组件，箭头表示组件之间的调用或依赖。',
  dataShape: `{
  "layers": [
    { "name": "客户端", "nodes": [{ "id": "web", "label": "Web 控制台", "description": "React SPA" }] },
    { "name": "接入层", "nodes": [{ "id": "gateway", "label": "API 网关" }] }
  ],
  "edges": [{ "from": "web", "to": "gateway", "label": "HTTPS" }]
}
nodes 里的每一项可以是字符串（id 即名称）或对象；对象支持 label 显示名、description 小字说明。
layers 也可以写成 { "接入层": [...], "服务层": [...] }；
或者省略 layers，直接给 nodes，用每个节点的 layer / group 字段自动分层。
edges 支持 from/to（也可写 source/target），label 是连线上的小标签。`,
  variants: ['vertical 纵向分层', 'horizontal 横向分层'],
  aliases: ['架构图', '系统架构图', '架构', 'architecture', 'arch', 'topology', '拓扑图', '部署图'],
  options: [
    { key: 'direction', type: 'string', description: '分层方向：纵向从上到下，横向从左到右', default: 'vertical', values: ['vertical', 'horizontal'] },
    { key: 'edgeStyle', type: 'string', description: '连线样式', default: 'curve', values: ['curve', 'straight', 'elbow'] },
    { key: 'showLayers', type: 'boolean', description: '是否显示层名的底衬色带', default: true },
    { key: 'showDescriptions', type: 'boolean', description: '是否显示方块里的小字说明', default: true },
    { key: 'edgeLabels', type: 'boolean', description: '是否显示连线上的标签', default: true },
    { key: 'nodeGap', type: 'number', description: '同一层内方块的间距', default: 26 },
    { key: 'layerGap', type: 'number', description: '层与层之间的间距', default: 36 },
    { key: 'detourGap', type: 'number', description: '同层连线需要绕过中间方块时向外绕行的距离，0 表示不绕行', default: 30 },
    { key: 'minNodeWidth', type: 'number', description: '方块最小宽度', default: 128 },
    { key: 'maxNodeWidth', type: 'number', description: '方块最大宽度，超出用省略号截断', default: 260 },
    { key: 'labelSize', type: 'number', description: '方块主标题字号', default: 15 },
    { key: 'descriptionSize', type: 'number', description: '方块说明文字号', default: 12 },
    { key: 'edgeLabelSize', type: 'number', description: '连线标签字号', default: 11 },
    { key: 'lineWidth', type: 'number', description: '连线粗细', default: 1.6 },
    { key: 'cornerRadius', type: 'number', description: '方块圆角半径', default: 10 },
  ],
  example: {
    data: {
      layers: [
        {
          name: '客户端',
          nodes: [
            { id: 'web', label: 'Web 控制台', description: 'React SPA' },
            { id: 'mobile', label: '移动 App', description: 'iOS / Android' },
            { id: 'sdk', label: '开放 SDK' },
          ],
        },
        {
          name: '接入层',
          nodes: [
            { id: 'cdn', label: 'CDN', description: '静态资源' },
            { id: 'gateway', label: 'API 网关', description: '鉴权 · 限流' },
          ],
        },
        {
          name: '服务层',
          nodes: [
            { id: 'user', label: '用户服务' },
            { id: 'order', label: '订单服务' },
            { id: 'report', label: '报表服务' },
            { id: 'worker', label: '异步任务' },
          ],
        },
        {
          name: '数据层',
          nodes: [
            { id: 'pg', label: 'PostgreSQL', description: '主库' },
            { id: 'redis', label: 'Redis', description: '缓存' },
            { id: 'mq', label: 'Kafka', description: '消息队列' },
            { id: 'olap', label: 'ClickHouse', description: '分析库' },
          ],
        },
      ],
      edges: [
        { from: 'web', to: 'cdn' },
        { from: 'mobile', to: 'gateway' },
        { from: 'sdk', to: 'gateway', label: 'HTTPS' },
        { from: 'cdn', to: 'gateway' },
        { from: 'gateway', to: 'user', label: 'gRPC' },
        { from: 'gateway', to: 'order' },
        { from: 'gateway', to: 'report' },
        { from: 'order', to: 'worker', label: '事件' },
        { from: 'user', to: 'pg' },
        { from: 'order', to: 'pg' },
        { from: 'user', to: 'redis' },
        { from: 'order', to: 'mq' },
        { from: 'worker', to: 'mq' },
        { from: 'report', to: 'olap' },
      ],
    },
    options: { direction: 'vertical', edgeStyle: 'curve' },
  },
  render: (ctx) => {
    const diagram = normalizeArchitecture(ctx.data)
    const options = ctx.options as Record<string, unknown>

    const number = (key: string, fallback: number) => {
      const value = options[key]
      return typeof value === 'number' && Number.isFinite(value) ? value : fallback
    }

    const direction: Direction = options.direction === 'horizontal' ? 'horizontal' : 'vertical'
    const edgeStyle: EdgeStyle =
      options.edgeStyle === 'straight' || options.edgeStyle === 'elbow' ? options.edgeStyle : 'curve'

    const cfg: LayoutConfig = {
      direction,
      showLayers: options.showLayers !== false,
      showDescriptions: options.showDescriptions !== false,
      nodeGap: number('nodeGap', 26),
      layerGap: number('layerGap', 36),
      minNodeWidth: number('minNodeWidth', 128),
      maxNodeWidth: number('maxNodeWidth', 260),
      labelSize: number('labelSize', 15),
      descriptionSize: number('descriptionSize', 12),
    }

    const labelSize = cfg.labelSize
    const descriptionSize = cfg.descriptionSize
    const edgeLabelSize = number('edgeLabelSize', 11)
    const lineWidth = number('lineWidth', 1.6)
    const detourGap = Math.max(0, number('detourGap', 30))
    const cornerRadius = number('cornerRadius', 10)
    const arrowSize = Math.max(7, lineWidth * 4.6)

    const layout = layoutDiagram(diagram, cfg)

    // 内容装不下时整体等比缩小，绝不裁切
    const scale = Math.min(1, ctx.width / layout.width, ctx.height / layout.height)
    const offsetX = (ctx.width - layout.width * scale) / 2
    const offsetY = (ctx.height - layout.height * scale) / 2

    const colorOf = (index: number) => ctx.colors[index % ctx.colors.length]!
    const dark = isDarkBackground(ctx.background)
    const fillOpacity = dark ? 0.22 : 0.13
    const bandOpacity = dark ? 0.07 : 0.04

    const edges = diagram.edges.map((edge, i) => {
      const from = layout.nodes.get(edge.from)!
      const to = layout.nodes.get(edge.to)!
      const detour =
        detourGap > 0 && from !== to && sameLayerBlocked(layout, from, to, direction) ? detourGap : 0
      const geo = edgeGeometry(from, to, direction, edgeStyle, arrowSize, detour)
      const labelWidth = edge.label ? textWidth(edge.label, edgeLabelSize) + 14 : 0
      const labelHeight = edgeLabelSize + 10
      return (
        <g key={`edge-${i}`}>
          <path
            d={geo.d}
            fill="none"
            stroke={ctx.muted}
            strokeWidth={lineWidth}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <polygon points={geo.arrow} fill={ctx.muted} />
          {edge.label && options.edgeLabels !== false ? (
            <g>
              <rect
                x={round(geo.label.x - labelWidth / 2)}
                y={round(geo.label.y - labelHeight / 2)}
                width={round(labelWidth)}
                height={round(labelHeight)}
                rx={5}
                fill={ctx.background}
              />
              <text
                x={round(geo.label.x)}
                y={round(geo.label.y + edgeLabelSize * 0.36)}
                textAnchor="middle"
                fontFamily={ctx.fontFamily}
                fontSize={edgeLabelSize}
                fill={ctx.muted}
              >
                {edge.label}
              </text>
            </g>
          ) : null}
        </g>
      )
    })

    const layerBoxes = layout.layers.map((layer) => {
      const color = colorOf(layer.index)
      return (
        <g key={`layer-${layer.index}`}>
          <rect
            x={layer.x}
            y={layer.y}
            width={layer.width}
            height={layer.height}
            rx={14}
            fill={color}
            fillOpacity={bandOpacity}
            stroke={color}
            strokeOpacity={dark ? 0.28 : 0.2}
            strokeWidth={1}
          />
          {cfg.showLayers ? (
            <text
              x={direction === 'vertical' ? layer.x + BAND.padX : layer.x + layer.width / 2}
              y={layer.y + BAND.padTop + LAYER_TITLE.size}
              textAnchor={direction === 'vertical' ? 'start' : 'middle'}
              fontFamily={ctx.fontFamily}
              fontSize={LAYER_TITLE.size}
              fontWeight={700}
              letterSpacing={1}
              fill={color}
            >
              {layer.name}
            </text>
          ) : null}
        </g>
      )
    })

    const nodeBoxes = [...layout.nodes.values()].map((box) => {
      const color = colorOf(box.layer)
      const labelLine = labelSize * NODE.lineRatio
      const contentHeight =
        labelLine + (box.description ? NODE.descGap + descriptionSize * NODE.lineRatio : 0)
      const contentTop = box.y + (box.height - contentHeight) / 2
      const labelBaseline = contentTop + labelSize
      const descriptionBaseline = labelBaseline + NODE.descGap + descriptionSize
      return (
        <g key={`node-${box.node.id}`}>
          <rect
            x={box.x}
            y={box.y}
            width={box.width}
            height={box.height}
            rx={cornerRadius}
            fill={color}
            fillOpacity={fillOpacity}
            stroke={color}
            strokeWidth={1.4}
          />
          <text
            x={round(box.x + box.width / 2)}
            y={round(labelBaseline)}
            textAnchor="middle"
            fontFamily={ctx.fontFamily}
            fontSize={labelSize}
            fontWeight={600}
            fill={ctx.foreground}
          >
            {box.label}
          </text>
          {box.description ? (
            <text
              x={round(box.x + box.width / 2)}
              y={round(descriptionBaseline)}
              textAnchor="middle"
              fontFamily={ctx.fontFamily}
              fontSize={descriptionSize}
              fill={ctx.muted}
            >
              {box.description}
            </text>
          ) : null}
        </g>
      )
    })

    return (
      <svg
        width={ctx.width}
        height={ctx.height}
        viewBox={`0 0 ${ctx.width} ${ctx.height}`}
        role="img"
        aria-label="架构图"
      >
        <g transform={`translate(${round(offsetX)}, ${round(offsetY)}) scale(${round(scale * 1000) / 1000})`}>
          {layerBoxes}
          {edges}
          {nodeBoxes}
        </g>
      </svg>
    )
  },
}

export default architecture
