import type { ReactNode } from 'react'
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

type FlowShape = 'rect' | 'round' | 'stadium' | 'diamond'

interface FlowNode {
  id: string
  label: string
  shape: FlowShape
}

interface FlowEdge {
  from: string
  to: string
  label?: string
}

interface FlowGraph {
  nodes: FlowNode[]
  edges: FlowEdge[]
}

const CHART = 'flowchart'

const SHAPE_ALIASES: Record<string, FlowShape> = {
  rect: 'rect',
  box: 'rect',
  process: 'rect',
  round: 'round',
  rounded: 'round',
  stadium: 'stadium',
  pill: 'stadium',
  start: 'stadium',
  end: 'stadium',
  terminator: 'stadium',
  diamond: 'diamond',
  decision: 'diamond',
  condition: 'diamond',
  branch: 'diamond',
}

function shapeHint(): string {
  return '推荐写法：{ "nodes": [{ "id": "start", "label": "开始", "shape": "stadium" }], "edges": [{ "from": "start", "to": "check", "label": "是" }] }'
}

function readShape(raw: unknown): FlowShape {
  if (raw === undefined || raw === null) return 'rect'
  const shape = SHAPE_ALIASES[String(raw).toLowerCase()]
  if (!shape) {
    fail('INVALID_DATA', `不支持的节点形状「${String(raw)}」`, '可用：rect（默认）/ round / stadium（开始结束）/ diamond（判断）')
  }
  return shape
}

function readNode(raw: unknown, where: string): FlowNode {
  if (typeof raw === 'string' || typeof raw === 'number') {
    const text = String(raw)
    return { id: text, label: text, shape: 'rect' }
  }
  if (isPlainObject(raw)) {
    const rawId = raw.id ?? raw.name ?? raw.label
    if (rawId === undefined) {
      fail('INVALID_DATA', `${where} 缺少 id（也可以用 name / label）`, shapeHint())
    }
    const id = String(rawId)
    return {
      id,
      label: String(raw.label ?? raw.name ?? id),
      shape: readShape(raw.shape ?? raw.type),
    }
  }
  fail('INVALID_DATA', `${where} 必须是字符串或对象`, shapeHint())
}

export function normalizeFlowchart(data: unknown): FlowGraph {
  if (!isPlainObject(data)) {
    fail('INVALID_DATA', `${CHART} 需要对象数据，收到 ${typeof data}`, shapeHint())
  }
  if (!Array.isArray(data.nodes) || data.nodes.length === 0) {
    fail('INVALID_DATA', `${CHART} 需要非空的 nodes 数组`, shapeHint())
  }

  const nodes = data.nodes.map((raw, i) => readNode(raw, `nodes 第 ${i + 1} 项`))
  const nodesById = new Map<string, FlowNode>()
  for (const node of nodes) {
    if (nodesById.has(node.id)) {
      fail('INVALID_DATA', `节点 id 重复：${node.id}`, '每个节点需要一个唯一 id')
    }
    nodesById.set(node.id, node)
  }

  const rawEdges = data.edges ?? data.links ?? []
  if (!Array.isArray(rawEdges)) {
    fail('INVALID_DATA', 'edges 必须是数组', '形如 [{ "from": "a", "to": "b", "label": "是" }]')
  }
  const edges: FlowEdge[] = rawEdges.map((raw, i) => {
    if (!isPlainObject(raw)) fail('INVALID_DATA', `第 ${i + 1} 条连线必须是对象`, shapeHint())
    const from = raw.from ?? raw.source ?? raw.start
    const to = raw.to ?? raw.target ?? raw.end
    if (from === undefined || to === undefined) {
      fail('INVALID_DATA', `第 ${i + 1} 条连线缺少 from / to`, '形如 { "from": "a", "to": "b" }')
    }
    const edge: FlowEdge = {
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

  return { nodes, edges }
}

/* ─────────────────────────── 分层布局 ─────────────────────────── */

interface NodeBox {
  node: FlowNode
  layer: number
  order: number
  x: number
  y: number
  width: number
  height: number
  label: string
}

type Direction = 'vertical' | 'horizontal'
type EdgeStyle = 'curve' | 'straight' | 'elbow'

interface LayoutConfig {
  direction: Direction
  nodeGap: number
  layerGap: number
  minNodeWidth: number
  maxNodeWidth: number
  labelSize: number
}

const NODE = { padX: 20, padY: 13, lineRatio: 1.4 }
const DIAMOND = { padX: 58, padY: 30 }

function measureNode(node: FlowNode, cfg: LayoutConfig) {
  const maxText = Math.max(40, cfg.maxNodeWidth - NODE.padX * 2)
  const label = ellipsize(node.label, maxText, cfg.labelSize)
  const textW = textWidth(label, cfg.labelSize)
  if (node.shape === 'diamond') {
    // 菱形中线最窄，文字区要比矩形多留出一截
    const width = Math.round(Math.min(cfg.maxNodeWidth + 40, Math.max(140, textW + DIAMOND.padX * 2)))
    const height = Math.round(Math.max(84, cfg.labelSize * NODE.lineRatio + DIAMOND.padY * 2))
    return { width, height, label }
  }
  const width = Math.round(
    Math.min(cfg.maxNodeWidth, Math.max(cfg.minNodeWidth, textW + NODE.padX * 2)),
  )
  const height = Math.round(cfg.labelSize * NODE.lineRatio + NODE.padY * 2)
  return { width, height, label }
}

/**
 * 计算每个节点所在层：在 DAG 上取最长路径。
 * 成环的边（回流边）不参与分层，画的时候绕外侧通道走。
 */
function computeLayers(graph: FlowGraph): { layerOf: Map<string, number>; backEdges: Set<number> } {
  const ids = graph.nodes.map((n) => n.id)
  const indexOf = new Map(ids.map((id, i) => [id, i]))
  const outgoing = new Map<number, number[]>(ids.map((_, i) => [i, []]))
  const incoming = new Map<number, number[]>(ids.map((_, i) => [i, []]))

  graph.edges.forEach((edge, edgeIndex) => {
    const from = indexOf.get(edge.from)!
    const to = indexOf.get(edge.to)!
    outgoing.get(from)!.push(to)
    incoming.get(to)!.push(from)
    void edgeIndex
  })

  // 找环上的边：DFS，指向栈上节点的边即为回流边
  const backEdges = new Set<number>()
  const state = new Array<number>(ids.length).fill(0) // 0 未访问 1 栈上 2 完成
  const visit = (u: number): void => {
    state[u] = 1
    for (const v of outgoing.get(u)!) {
      if (state[v] === 1) {
        const edgeIndex = graph.edges.findIndex((e) => e.from === ids[u] && e.to === ids[v])
        if (edgeIndex >= 0) backEdges.add(edgeIndex)
      } else if (state[v] === 0) {
        visit(v)
      }
    }
    state[u] = 2
  }
  for (let i = 0; i < ids.length; i++) {
    if (state[i] === 0) visit(i)
  }

  // Kahn 拓扑 + 最长路径；回流边不参与
  const degree = new Map<number, number>()
  for (let i = 0; i < ids.length; i++) degree.set(i, 0)
  graph.edges.forEach((edge, edgeIndex) => {
    if (backEdges.has(edgeIndex)) return
    const to = indexOf.get(edge.to)!
    degree.set(to, degree.get(to)! + 1)
  })
  const layerOf = new Map<number, number>(ids.map((_, i) => [i, 0]))
  const queue: number[] = []
  for (let i = 0; i < ids.length; i++) {
    if (degree.get(i) === 0) queue.push(i)
  }
  const dagOutgoing = new Map<number, number[]>(ids.map((_, i) => [i, []]))
  graph.edges.forEach((edge, edgeIndex) => {
    if (backEdges.has(edgeIndex)) return
    dagOutgoing.get(indexOf.get(edge.from)!)!.push(indexOf.get(edge.to)!)
  })
  while (queue.length > 0) {
    const u = queue.shift()!
    for (const v of dagOutgoing.get(u)!) {
      layerOf.set(v, Math.max(layerOf.get(v)!, layerOf.get(u)! + 1))
      degree.set(v, degree.get(v)! - 1)
      if (degree.get(v) === 0) queue.push(v)
    }
  }

  return {
    layerOf: new Map(ids.map((id, i) => [id, layerOf.get(i)!])),
    backEdges,
  }
}

/** 层内排序：按前驱/后继的平均位置做几次重心排序，减少交叉。 */
function orderWithinLayers(graph: FlowGraph, layerOf: Map<string, number>, count: number): Map<string, number> {
  const ids = graph.nodes.map((n) => n.id)
  const byLayer = new Map<number, string[]>()
  for (const id of ids) {
    const layer = layerOf.get(id)!
    if (!byLayer.has(layer)) byLayer.set(layer, [])
    byLayer.get(layer)!.push(id)
  }

  const orderOf = new Map<string, number>()
  for (const members of byLayer.values()) {
    members.forEach((id, i) => orderOf.set(id, i))
  }

  const neighbors = (id: string, dir: 'pred' | 'succ') => {
    const out: string[] = []
    for (const e of graph.edges) {
      if (dir === 'pred' && e.to === id) out.push(e.from)
      if (dir === 'succ' && e.from === id) out.push(e.to)
    }
    return out
  }

  const layers = [...byLayer.keys()].sort((a, b) => a - b)
  for (let pass = 0; pass < 4; pass++) {
    const sequence = pass % 2 === 0 ? layers : [...layers].reverse()
    for (const layer of sequence) {
      const members = byLayer.get(layer)!
      const dir = pass % 2 === 0 ? 'pred' : 'succ'
      const scored = members.map((id) => {
        const ns = neighbors(id, dir).filter((n) => layerOf.get(n)! !== layer)
        const avg = ns.length > 0 ? ns.reduce((acc, n) => acc + orderOf.get(n)!, 0) / ns.length : orderOf.get(id)!
        return { id, avg }
      })
      scored.sort((a, b) => a.avg - b.avg)
      scored.forEach((s, i) => orderOf.set(s.id, i))
    }
  }

  return orderOf
}

function layoutGraph(graph: FlowGraph, cfg: LayoutConfig, vertical: boolean) {
  const { layerOf, backEdges } = computeLayers(graph)
  const orderOf = orderWithinLayers(graph, layerOf, graph.nodes.length)

  const measured = new Map<string, { width: number; height: number; label: string }>()
  for (const node of graph.nodes) {
    measured.set(node.id, measureNode(node, cfg))
  }

  const layers = new Map<number, string[]>()
  for (const node of graph.nodes) {
    const layer = layerOf.get(node.id)!
    if (!layers.has(layer)) layers.set(layer, [])
    layers.get(layer)!.push(node.id)
  }
  for (const members of layers.values()) {
    members.sort((a, b) => orderOf.get(a)! - orderOf.get(b)!)
  }
  const layerIndexes = [...layers.keys()].sort((a, b) => a - b)

  // 主轴（层的推进方向）每条位置 = 该层最大尺寸 + 间距
  const layerBreadth = new Map<number, number>()
  for (const index of layerIndexes) {
    const breadth = Math.max(
      ...layers.get(index)!.map((id) => {
        const m = measured.get(id)!
        return vertical ? m.height : m.width
      }),
    )
    layerBreadth.set(index, breadth)
  }

  const crossSizes = new Map<string, number>()
  for (const node of graph.nodes) {
    const m = measured.get(node.id)!
    crossSizes.set(node.id, vertical ? m.width : m.height)
  }

  const layerOffset = new Map<number, number>()
  let cursor = 0
  for (const index of layerIndexes) {
    layerOffset.set(index, cursor)
    cursor += layerBreadth.get(index)! + cfg.layerGap
  }
  const mainTotal = cursor - cfg.layerGap

  // 交叉轴：内容最宽的一层决定整体宽度
  let crossTotal = 0
  for (const index of layerIndexes) {
    const members = layers.get(index)!
    const span =
      members.reduce((acc, id) => acc + crossSizes.get(id)!, 0) + cfg.nodeGap * Math.max(0, members.length - 1)
    crossTotal = Math.max(crossTotal, span)
  }

  const boxes = new Map<string, NodeBox>()
  for (const index of layerIndexes) {
    const members = layers.get(index)!
    const span =
      members.reduce((acc, id) => acc + crossSizes.get(id)!, 0) + cfg.nodeGap * Math.max(0, members.length - 1)
    let crossCursor = (crossTotal - span) / 2
    const layerMainBreadth = Math.max(
      ...members.map((id) => {
        const m = measured.get(id)!
        return vertical ? m.height : m.width
      }),
    )
    const mainStart = layerOffset.get(index)! + (layerBreadth.get(index)! - layerMainBreadth) / 2
    for (const [i, id] of members.entries()) {
      const node = graph.nodes.find((n) => n.id === id)!
      const m = measured.get(id)!
      const main = mainStart
      const cross = crossCursor
      boxes.set(id, {
        node,
        layer: index,
        order: i,
        x: vertical ? cross : main,
        y: vertical ? main : cross,
        width: m.width,
        height: m.height,
        label: m.label,
      })
      crossCursor += crossSizes.get(id)! + cfg.nodeGap
    }
  }

  return { boxes, layerIndexes, backEdges, mainTotal, crossTotal }
}

/* ─────────────────────────── 连线几何 ─────────────────────────── */

interface EdgeGeometry {
  d: string
  arrow: string
  label: Point
}

function centerOf(box: NodeBox): Point {
  return { x: box.x + box.width / 2, y: box.y + box.height / 2 }
}

function edgeGeometry(
  a: NodeBox,
  b: NodeBox,
  vertical: boolean,
  style: EdgeStyle,
  arrowSize: number,
  channelX: number,
): EdgeGeometry {
  const ca = centerOf(a)
  const cb = centerOf(b)

  // 自环：从节点一侧绕个小圈回来
  if (a.node.id === b.node.id) {
    const side = vertical ? a.x + a.width : a.y + a.height
    if (vertical) {
      const spread = Math.min(a.height * 0.4, 40)
      const out = 42
      const d = `M ${round(side)} ${round(ca.y - spread)} C ${round(side + out)} ${round(ca.y - spread)}, ${round(side + out)} ${round(ca.y + spread)}, ${round(side)} ${round(ca.y + spread)}`
      return {
        d,
        arrow: arrowPoints({ x: side, y: ca.y + spread }, { x: -out * 0.4, y: spread }, arrowSize),
        label: { x: side + out + 12, y: ca.y },
      }
    }
    const spread = Math.min(a.width * 0.4, 40)
    const out = 42
    const d = `M ${round(ca.x - spread)} ${round(side)} C ${round(ca.x - spread)} ${round(side + out)}, ${round(ca.x + spread)} ${round(side + out)}, ${round(ca.x + spread)} ${round(side)}`
    return {
      d,
      arrow: arrowPoints({ x: ca.x + spread, y: side }, { x: -spread, y: -out * 0.4 }, arrowSize),
      label: { x: ca.x, y: side + out + 12 },
    }
  }

  // 回流边（向上 / 向左）：走最外侧的平行通道，避免横穿中间的节点
  const backward = vertical ? cb.y < ca.y : cb.x < ca.x
  if (backward) {
    if (vertical) {
      const from = { x: a.x + a.width / 2, y: a.y }
      const to = { x: b.x + b.width / 2, y: b.y + b.height }
      const channel = channelX
      const d = `M ${round(from.x)} ${round(from.y)} L ${round(from.x)} ${round(channel)} L ${round(to.x)} ${round(channel)} L ${round(to.x)} ${round(to.y)}`
      return {
        d,
        arrow: arrowPoints(to, { x: 0, y: 1 }, arrowSize),
        label: { x: (from.x + to.x) / 2, y: channel },
      }
    }
    const from = { x: a.x, y: a.y + a.height / 2 }
    const to = { x: b.x + b.width, y: b.y + b.height / 2 }
    const channel = channelX
    const d = `M ${round(from.x)} ${round(from.y)} L ${round(channel)} ${round(from.y)} L ${round(channel)} ${round(to.y)} L ${round(to.x)} ${round(to.y)}`
    return {
      d,
      arrow: arrowPoints(to, { x: 1, y: 0 }, arrowSize),
      label: { x: channel, y: (from.y + to.y) / 2 },
    }
  }

  // 正向边：按象限选锚点
  const { from, to } = vertical
    ? cb.y >= ca.y
      ? { from: { x: ca.x, y: a.y + a.height }, to: { x: cb.x, y: b.y } }
      : { from: { x: ca.x, y: a.y }, to: { x: cb.x, y: b.y + b.height } }
    : cb.x >= ca.x
      ? { from: { x: a.x + a.width, y: ca.y }, to: { x: b.x, y: cb.y } }
      : { from: { x: a.x, y: ca.y }, to: { x: b.x + b.width, y: cb.y } }

  const dx = to.x - from.x
  const dy = to.y - from.y
  const travelsVertically = vertical ? Math.abs(dy) >= Math.abs(dx) : Math.abs(dx) >= Math.abs(dy)

  if (style === 'straight') {
    return {
      d: `M ${round(from.x)} ${round(from.y)} L ${round(to.x)} ${round(to.y)}`,
      arrow: arrowPoints(to, { x: dx, y: dy }, arrowSize),
      label: midpoint(from, to),
    }
  }

  if (style === 'elbow') {
    if (vertical) {
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

  // curve
  const c1 = travelsVertically ? { x: from.x, y: from.y + dy / 2 } : { x: from.x + dx / 2, y: from.y }
  const c2 = travelsVertically ? { x: to.x, y: to.y - dy / 2 } : { x: to.x - dx / 2, y: to.y }
  return {
    d: `M ${round(from.x)} ${round(from.y)} C ${round(c1.x)} ${round(c1.y)}, ${round(c2.x)} ${round(c2.y)}, ${round(to.x)} ${round(to.y)}`,
    arrow: arrowPoints(to, { x: to.x - c2.x, y: to.y - c2.y }, arrowSize),
    label: bezierMid(from, c1, c2, to),
  }
}

function shapeElement(box: NodeBox, color: string, fillOpacity: number, strokeWidth: number, fontFamily: string, labelSize: number, foreground: string) {
  const cx = box.x + box.width / 2
  const cy = box.y + box.height / 2
  const common = {
    fill: color,
    fillOpacity,
    stroke: color,
    strokeWidth,
  }
  let body: ReactNode = null
  if (box.node.shape === 'diamond') {
    body = (
      <polygon
        points={`${round(cx)},${round(box.y)} ${round(box.x + box.width)},${round(cy)} ${round(cx)},${round(box.y + box.height)} ${round(box.x)},${round(cy)}`}
        {...common}
      />
    )
  } else {
    body = (
      <rect
        x={box.x}
        y={box.y}
        width={box.width}
        height={box.height}
        rx={box.node.shape === 'stadium' ? box.height / 2 : box.node.shape === 'round' ? 16 : 8}
        {...common}
      />
    )
  }
  return (
    <g key={`node-${box.node.id}`}>
      {body}
      <text
        x={round(cx)}
        y={round(cy + labelSize * 0.36)}
        textAnchor="middle"
        fontFamily={fontFamily}
        fontSize={labelSize}
        fontWeight={600}
        fill={foreground}
      >
        {box.label}
      </text>
    </g>
  )
}

/* ─────────────────────────── 图表定义 ─────────────────────────── */

/**
 * 流程图：节点 + 有向连线，支持判断菱形、起止圆角、自环与回流边。
 * 由 mint 自绘 SVG —— nivo 没有流程图布局。
 */
const flowchart: ChartDefinition = {
  id: 'flowchart',
  name: '流程图',
  englishName: 'Flowchart',
  category: 'flow',
  description: '用节点和有向连线表达流程与判断：矩形是步骤，菱形是判断，圆角胶囊是开始/结束。',
  dataShape: `{
  "nodes": [
    { "id": "start", "label": "开始", "shape": "stadium" },
    { "id": "check", "label": "库存充足？", "shape": "diamond" },
    { "id": "pay", "label": "创建订单" },
    { "id": "end", "label": "结束", "shape": "stadium" }
  ],
  "edges": [
    { "from": "start", "to": "check" },
    { "from": "check", "to": "pay", "label": "是" },
    { "from": "pay", "to": "end" },
    { "from": "check", "to": "end", "label": "否" }
  ]
}
shape：rect（默认，步骤）/ round（圆角）/ stadium（开始结束）/ diamond（判断）。
edges 支持 from/to（也可写 source/target）与 label（连线上的分支说明）。
画不下的回流边（如循环）会自动绕到最外侧通道，不会穿过节点。`,
  variants: ['vertical 从上到下', 'horizontal 从左到右'],
  aliases: ['流程图', 'flowchart', 'flow', '流程', '业务流程', 'uml图'],
  options: [
    { key: 'direction', type: 'string', description: '流程方向', default: 'vertical', values: ['vertical', 'horizontal'] },
    { key: 'edgeStyle', type: 'string', description: '连线样式', default: 'elbow', values: ['elbow', 'curve', 'straight'] },
    { key: 'edgeLabels', type: 'boolean', description: '是否显示连线上的标签', default: true },
    { key: 'nodeGap', type: 'number', description: '同层节点的间距', default: 30 },
    { key: 'layerGap', type: 'number', description: '层与层之间的间距', default: 74 },
    { key: 'minNodeWidth', type: 'number', description: '节点最小宽度', default: 120 },
    { key: 'maxNodeWidth', type: 'number', description: '节点最大宽度，超出用省略号截断', default: 240 },
    { key: 'labelSize', type: 'number', description: '节点文字字号', default: 14 },
    { key: 'edgeLabelSize', type: 'number', description: '连线标签字号', default: 11 },
    { key: 'lineWidth', type: 'number', description: '连线粗细', default: 1.6 },
  ],
  example: {
    data: {
      nodes: [
        { id: 'start', label: '开始', shape: 'stadium' },
        { id: 'submit', label: '提交订单' },
        { id: 'check', label: '库存充足？', shape: 'diamond' },
        { id: 'pay', label: '创建支付单' },
        { id: 'callback', label: '等待支付回调' },
        { id: 'success', label: '标记支付成功' },
        { id: 'close', label: '关闭订单' },
        { id: 'end', label: '结束', shape: 'stadium' },
      ],
      edges: [
        { from: 'start', to: 'submit' },
        { from: 'submit', to: 'check' },
        { from: 'check', to: 'pay', label: '是' },
        { from: 'pay', to: 'callback' },
        { from: 'callback', to: 'success', label: '支付成功' },
        { from: 'callback', to: 'close', label: '超时' },
        { from: 'success', to: 'end' },
        { from: 'close', to: 'end' },
        { from: 'check', to: 'close', label: '否' },
      ],
    },
    options: { direction: 'vertical', edgeStyle: 'elbow' },
  },
  render: (ctx) => {
    const graph = normalizeFlowchart(ctx.data)
    const options = ctx.options as Record<string, unknown>

    const number = (key: string, fallback: number) => {
      const value = options[key]
      return typeof value === 'number' && Number.isFinite(value) ? value : fallback
    }

    const vertical = options.direction !== 'horizontal'
    const edgeStyle: EdgeStyle =
      options.edgeStyle === 'curve' || options.edgeStyle === 'straight' ? options.edgeStyle : 'elbow'

    const cfg: LayoutConfig = {
      direction: vertical ? 'vertical' : 'horizontal',
      nodeGap: number('nodeGap', 30),
      layerGap: number('layerGap', 74),
      minNodeWidth: number('minNodeWidth', 120),
      maxNodeWidth: number('maxNodeWidth', 240),
      labelSize: number('labelSize', 14),
    }

    const labelSize = cfg.labelSize
    const edgeLabelSize = number('edgeLabelSize', 11)
    const lineWidth = number('lineWidth', 1.6)
    const arrowSize = Math.max(7, lineWidth * 4.6)

    const layout = layoutGraph(graph, cfg, vertical)

    const contentWidth = vertical ? layout.crossTotal : layout.mainTotal
    const contentHeight = vertical ? layout.mainTotal : layout.crossTotal

    // 回流边通道：画在内容外侧
    const backEdges = graph.edges
      .map((edge, index) => ({ edge, index }))
      .filter(({ index }) => layout.backEdges.has(index))
    const channelBase = vertical ? -30 : -30
    const channelStep = 26

    const colorOf = (box: NodeBox) => {
      const paletteIndex = graph.nodes.findIndex((n) => n.id === box.node.id)
      return ctx.colors[paletteIndex % ctx.colors.length]!
    }
    const dark = isDarkBackground(ctx.background)
    const fillOpacity = dark ? 0.24 : 0.12

    const edgeEls = graph.edges.map((edge, index) => {
      const from = layout.boxes.get(edge.from)!
      const to = layout.boxes.get(edge.to)!
      const isBack = layout.backEdges.has(index)
      const backOrdinal = isBack ? backEdges.findIndex((e) => e.index === index) : -1
      const channel = isBack
        ? vertical
          ? channelBase - backOrdinal * channelStep
          : channelBase - backOrdinal * channelStep
        : 0
      const geo = edgeGeometry(from, to, vertical, edgeStyle, arrowSize, channel)
      const labelWidth = edge.label ? textWidth(edge.label, edgeLabelSize) + 14 : 0
      const labelHeight = edgeLabelSize + 8
      return (
        <g key={`edge-${index}`}>
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

    const nodeEls = [...layout.boxes.values()].map((box) =>
      shapeElement(box, colorOf(box), fillOpacity, 1.4, ctx.fontFamily, labelSize, ctx.foreground),
    )

    // 回流通道在内容上方/左方，给它留出边距
    const pad = backEdges.length > 0 ? Math.abs(channelBase) + backEdges.length * channelStep : 0
    const totalWidth = contentWidth + (vertical ? 0 : pad)
    const totalHeight = contentHeight + (vertical ? pad : 0)
    const offsetX = vertical ? 0 : pad
    const offsetY = vertical ? pad : 0

    const scale = Math.min(1, ctx.width / totalWidth, ctx.height / totalHeight)
    const shiftX = (ctx.width - totalWidth * scale) / 2
    const shiftY = (ctx.height - totalHeight * scale) / 2

    return (
      <svg
        width={ctx.width}
        height={ctx.height}
        viewBox={`0 0 ${ctx.width} ${ctx.height}`}
        role="img"
        aria-label="流程图"
      >
        <g transform={`translate(${round(shiftX)}, ${round(shiftY)}) scale(${round(scale * 1000) / 1000})`}>
          <g transform={`translate(${round(offsetX)}, ${round(offsetY)})`}>
            {edgeEls}
            {nodeEls}
          </g>
        </g>
      </svg>
    )
  },
}

export default flowchart
