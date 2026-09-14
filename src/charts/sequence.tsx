import type { ChartDefinition } from '../core/types'
import { fail } from '../core/errors'
import { isPlainObject } from './helpers'
import { arrowPoints, ellipsize, isDarkBackground, openArrowPoints, round, textWidth } from './diagram-utils'

/* ─────────────────────────── 数据归一化 ─────────────────────────── */

interface Participant {
  id: string
  label: string
}

type MessageType = 'solid' | 'dashed'

interface Message {
  from: string
  to: string
  label: string
  type: MessageType
}

interface Note {
  from: string
  to?: string
  label: string
}

interface SequenceDiagram {
  participants: Participant[]
  messages: Message[]
  notes: Note[]
}

const CHART = 'sequence'

function shapeHint(): string {
  return '推荐写法：{ "participants": ["用户", "App"], "messages": [{ "from": "用户", "to": "App", "label": "提交订单" }] }'
}

function readParticipant(raw: unknown, where: string): Participant {
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
    return { id, label: String(raw.label ?? raw.name ?? id) }
  }
  fail('INVALID_DATA', `${where} 必须是字符串或对象`, shapeHint())
}

function readMessageType(raw: unknown): MessageType {
  if (raw === undefined || raw === null) return 'solid'
  const type = String(raw).toLowerCase()
  // return / reply / response 视为返回（虚线）
  return type === 'dashed' || type === 'return' || type === 'reply' || type === 'response' ? 'dashed' : 'solid'
}

/**
 * 解析时序图数据，兼容这些写法：
 * - { participants: [...], messages: [{ from, to, label, type }] }
 * - participants 可以是字符串数组，也可以整个省略（按 messages 首次出现顺序推导）
 * - notes: [{ from, to?, label }] 在生命线之间画一条备注
 */
export function normalizeSequence(data: unknown): SequenceDiagram {
  if (!isPlainObject(data)) {
    fail('INVALID_DATA', `${CHART} 需要对象数据，收到 ${typeof data}`, shapeHint())
  }

  const participants: Participant[] = []
  const seen = new Set<string>()
  const pushParticipant = (participant: Participant) => {
    if (!seen.has(participant.id)) {
      seen.add(participant.id)
      participants.push(participant)
    }
  }

  if (Array.isArray(data.participants)) {
    data.participants.forEach((raw, i) => pushParticipant(readParticipant(raw, `participants 第 ${i + 1} 项`)))
  }

  const rawMessages = data.messages ?? data.calls ?? []
  if (!Array.isArray(rawMessages)) {
    fail('INVALID_DATA', 'messages 必须是数组', '形如 [{ "from": "用户", "to": "App", "label": "提交订单" }]')
  }
  const messages: Message[] = rawMessages.map((raw, i) => {
    if (!isPlainObject(raw)) fail('INVALID_DATA', `messages 第 ${i + 1} 项必须是对象`, shapeHint())
    const from = raw.from ?? raw.source ?? raw.caller
    const to = raw.to ?? raw.target ?? raw.callee
    if (from === undefined || to === undefined) {
      fail('INVALID_DATA', `messages 第 ${i + 1} 项缺少 from / to`, '形如 { "from": "a", "to": "b", "label": "..." }')
    }
    const message: Message = {
      from: String(from),
      to: String(to),
      label: raw.label === undefined || raw.label === null ? '' : String(raw.label),
      type: readMessageType(raw.type ?? raw.style),
    }
    pushParticipant({ id: message.from, label: message.from })
    pushParticipant({ id: message.to, label: message.to })
    return message
  })

  if (messages.length === 0 && participants.length === 0) {
    fail('INVALID_DATA', '时序图需要至少一条消息或一个参与者', shapeHint())
  }

  const rawNotes = data.notes ?? []
  if (!Array.isArray(rawNotes)) {
    fail('INVALID_DATA', 'notes 必须是数组', '形如 [{ "from": "api", "to": "db", "label": "事务内" }]')
  }
  const notes: Note[] = rawNotes.map((raw, i) => {
    if (!isPlainObject(raw)) fail('INVALID_DATA', `notes 第 ${i + 1} 项必须是对象`, shapeHint())
    const from = raw.from ?? raw.participant
    if (from === undefined) {
      fail('INVALID_DATA', `notes 第 ${i + 1} 项缺少 from`, '形如 { "from": "api", "label": "备注" }')
    }
    const note: Note = {
      from: String(from),
      to: raw.to === undefined || raw.to === null ? undefined : String(raw.to),
      label: String(raw.label ?? raw.text ?? ''),
    }
    pushParticipant({ id: note.from, label: note.from })
    if (note.to) pushParticipant({ id: note.to, label: note.to })
    return note
  })

  return { participants, messages, notes }
}

/* ─────────────────────────── 排版 ─────────────────────────── */

interface ParticipantBox {
  participant: Participant
  index: number
  x: number
  width: number
  label: string
}

type Row =
  | { kind: 'message'; index: number; y: number; height: number }
  | { kind: 'note'; index: number; y: number; height: number }

interface Layout {
  boxes: ParticipantBox[]
  centerOf: Map<string, number>
  rows: Row[]
  topPad: number
  headerHeight: number
  width: number
  height: number
}

const HEAD = { height: 40, padX: 22 }
const LANE = { minGap: 176, gapExtra: 56 }
const ROW = { gap: 18, minHeight: 30, notePadX: 14, notePadY: 10 }

function layoutDiagram(
  diagram: SequenceDiagram,
  opts: { labelSize: number; noteSize: number; number: boolean },
): Layout {
  const labelSize = opts.labelSize

  // 每个参与者的头部宽度
  const measured = diagram.participants.map((p) => {
    const label = ellipsize(p.label, 220, labelSize)
    const width = Math.round(Math.max(108, textWidth(label, labelSize) + HEAD.padX * 2))
    return { participant: p, label, width }
  })

  const maxHeadWidth = Math.max(...measured.map((m) => m.width))
  const gap = Math.max(LANE.minGap, maxHeadWidth + LANE.gapExtra)
  const sideMargin = 30
  // 生命线等距分布，整体居中：第一条生命线留半边最宽头部 + 边距
  const width = Math.round(sideMargin * 2 + maxHeadWidth + gap * (measured.length - 1))
  const centers = measured.map((_, i) => Math.round(sideMargin + maxHeadWidth / 2 + i * gap))
  const finalBoxes: ParticipantBox[] = measured.map((m, i) => ({
    participant: m.participant,
    index: i,
    x: Math.round(centers[i]! - m.width / 2),
    width: m.width,
    label: m.label,
  }))
  const centerOf = new Map<string, number>(diagram.participants.map((p, i) => [p.id, centers[i]!]))

  const topPad = 8
  const headerHeight = topPad + HEAD.height

  // 逐行排消息与备注
  const rows: Row[] = []
  let y = headerHeight + 34
  const messageRows = new Map<number, number>()
  const noteRows = new Map<number, number>()

  diagram.messages.forEach((message, index) => {
    const numberPrefix = opts.number ? `${index + 1}. ` : ''
    const fullLabel = numberPrefix + message.label
    const span = Math.abs(centerOf.get(message.to)! - centerOf.get(message.from)!)
    const maxText = Math.max(60, (message.from === message.to ? 120 : span) - 24)
    const label = ellipsize(fullLabel, maxText, labelSize)
    const height = ROW.minHeight
    messageRows.set(index, y)
    rows.push({ kind: 'message', index, y, height })
    y += height + ROW.gap
  })

  // 备注插在指定消息之后（after 字段），默认排在其 from 参与者最后一次出现之后
  diagram.notes.forEach((note, index) => {
    const fromX = centerOf.get(note.from)!
    const toX = note.to ? centerOf.get(note.to)! : fromX
    const left = Math.min(fromX, toX)
    const right = Math.max(fromX, toX)
    const spanWidth = Math.max(160, right === left ? 200 : right - left + 40)
    const lines = wrapText(note.label, spanWidth - ROW.notePadX * 2, opts.noteSize)
    const height = lines.length * opts.noteSize * 1.4 + ROW.notePadY * 2
    noteRows.set(index, y)
    rows.push({ kind: 'note', index, y, height })
    y += height + ROW.gap
  })

  const height = y + 26
  return { boxes: finalBoxes, centerOf, rows, topPad, headerHeight, width, height }
}

function wrapText(text: string, maxWidth: number, fontSize: number): string[] {
  if (textWidth(text, fontSize) <= maxWidth) return [text]
  const lines: string[] = []
  let current = ''
  for (const ch of text) {
    if (textWidth(current + ch, fontSize) > maxWidth && current !== '') {
      lines.push(current)
      current = ch
    } else {
      current += ch
    }
  }
  if (current) lines.push(current)
  return lines
}

/* ─────────────────────────── 图表定义 ─────────────────────────── */

/**
 * 时序图：参与者沿生命线收发消息，实线是调用、虚线是返回，支持备注。
 * 由 mint 自绘 SVG —— nivo 没有时序图。
 */
const sequence: ChartDefinition = {
  id: 'sequence',
  name: '时序图',
  englishName: 'Sequence Diagram',
  category: 'flow',
  description: '按时间顺序展示对象之间的消息往来：实线是调用，虚线是返回，常用于接口与交互文档。',
  dataShape: `{
  "participants": [
    { "id": "user", "label": "用户" },
    { "id": "app", "label": "App" },
    { "id": "api", "label": "订单服务" },
    { "id": "db", "label": "数据库" }
  ],
  "messages": [
    { "from": "user", "to": "app", "label": "提交订单" },
    { "from": "app", "to": "api", "label": "POST /orders" },
    { "from": "api", "to": "db", "label": "INSERT orders" },
    { "from": "db", "to": "api", "label": "订单 ID", "type": "dashed" },
    { "from": "api", "to": "app", "label": "201 Created", "type": "dashed" },
    { "from": "app", "to": "user", "label": "下单成功", "type": "dashed" }
  ],
  "notes": [
    { "from": "api", "to": "db", "label": "同事务内写入" }
  ]
}
participants 可以省略，按 messages 里首次出现的顺序自动推导。
type 为 dashed（或 return / reply）时画虚线返回箭头；发给自己的小消息画自环。
notes 的 from/to 决定备注横跨的生命线范围。`,
  variants: ['sequence 时序'],
  aliases: ['时序图', 'sequence', '顺序图', '序列图', '时序', '交互图', 'uml时序', 'sequence diagram'],
  options: [
    { key: 'number', type: 'boolean', description: '是否给消息自动编号', default: false },
    { key: 'labelSize', type: 'number', description: '消息文字字号', default: 13 },
    { key: 'noteSize', type: 'number', description: '备注文字字号', default: 12 },
    { key: 'lifelineWidth', type: 'number', description: '生命线粗细', default: 1 },
    { key: 'lineWidth', type: 'number', description: '消息箭头粗细', default: 1.6 },
  ],
  example: {
    data: {
      participants: [
        { id: 'user', label: '用户' },
        { id: 'app', label: 'App' },
        { id: 'api', label: '订单服务' },
        { id: 'pay', label: '支付网关' },
        { id: 'db', label: '数据库' },
      ],
      messages: [
        { from: 'user', to: 'app', label: '提交订单' },
        { from: 'app', to: 'api', label: 'POST /orders' },
        { from: 'api', to: 'db', label: '写入订单（待支付）' },
        { from: 'api', to: 'pay', label: '创建支付单' },
        { from: 'pay', to: 'api', label: '支付回调', 'type': 'dashed' },
        { from: 'api', to: 'db', label: '更新为已支付' },
        { from: 'api', to: 'app', label: '201 Created', 'type': 'dashed' },
        { from: 'app', to: 'user', label: '下单成功', 'type': 'dashed' },
        { from: 'api', to: 'api', label: '发送通知事件' },
      ],
      notes: [
        { from: 'api', to: 'pay', label: '回调验签通过后才会更新订单状态' },
        { from: 'db', label: '订单与流水同事务' },
      ],
    },
    options: { number: true },
  },
  render: (ctx) => {
    const diagram = normalizeSequence(ctx.data)
    const options = ctx.options as Record<string, unknown>

    const number = (key: string, fallback: number) => {
      const value = options[key]
      return typeof value === 'number' && Number.isFinite(value) ? value : fallback
    }

    const labelSize = number('labelSize', 13)
    const noteSize = number('noteSize', 12)
    const lifelineWidth = number('lifelineWidth', 1)
    const lineWidth = number('lineWidth', 1.6)
    const arrowSize = Math.max(7, lineWidth * 4.6)
    const showNumber = options.number === true

    const layout = layoutDiagram(diagram, { labelSize, noteSize, number: showNumber })

    const scale = Math.min(1, ctx.width / layout.width, ctx.height / layout.height)
    const shiftX = (ctx.width - layout.width * scale) / 2
    const shiftY = (ctx.height - layout.height * scale) / 2

    const colorOf = (index: number) => ctx.colors[index % ctx.colors.length]!
    const dark = isDarkBackground(ctx.background)
    const headFillOpacity = dark ? 0.24 : 0.12
    const noteFill = dark ? '#3b3f2a' : '#fdf6e3'
    const noteBar = '#d69e2e'

    const bottom = layout.height - 10

    const lifelines = layout.boxes.map((box) => (
      <line
        key={`lifeline-${box.participant.id}`}
        x1={layout.centerOf.get(box.participant.id)!}
        y1={layout.headerHeight + 10}
        x2={layout.centerOf.get(box.participant.id)!}
        y2={bottom}
        stroke={ctx.muted}
        strokeWidth={lifelineWidth}
        strokeDasharray="5 5"
        strokeOpacity={dark ? 0.5 : 0.65}
      />
    ))

    const heads = layout.boxes.map((box) => {
      const color = colorOf(box.index)
      return (
        <g key={`head-${box.participant.id}`}>
          <rect
            x={box.x}
            y={layout.topPad}
            width={box.width}
            height={HEAD.height}
            rx={9}
            fill={color}
            fillOpacity={headFillOpacity}
            stroke={color}
            strokeWidth={1.4}
          />
          <text
            x={box.x + box.width / 2}
            y={layout.topPad + HEAD.height / 2 + labelSize * 0.36}
            textAnchor="middle"
            fontFamily={ctx.fontFamily}
            fontSize={labelSize}
            fontWeight={600}
            fill={ctx.foreground}
          >
            {box.label}
          </text>
        </g>
      )
    })

    const messageEls = diagram.messages.map((message, index) => {
      const rowY = layout.rows.find((r) => r.kind === 'message' && r.index === index)!.y
      const y = rowY + ROW.minHeight / 2
      const fromX = layout.centerOf.get(message.from)!
      const toX = layout.centerOf.get(message.to)!

      const numberPrefix = showNumber ? `${index + 1}. ` : ''
      const fullLabel = numberPrefix + message.label
      const span = Math.abs(toX - fromX)
      const maxText = Math.max(60, (message.from === message.to ? 200 : span) - 24)
      const label = ellipsize(fullLabel, maxText, labelSize)

      if (message.from === message.to) {
        // 自消息：生命线右侧绕一个清晰的半环
        const loop = 60
        const rise = 26
        const d = `M ${round(fromX)} ${round(y)} C ${round(fromX + loop)} ${round(y)}, ${round(fromX + loop)} ${round(y - rise)}, ${round(fromX + 2)} ${round(y - rise)}`
        return (
          <g key={`msg-${index}`}>
            <path d={d} fill="none" stroke={ctx.muted} strokeWidth={lineWidth} strokeLinecap="round" />
            <polygon points={arrowPoints({ x: fromX + 2, y: y - rise }, { x: -1, y: 0 }, arrowSize)} fill={ctx.muted} />
            {label ? (
              <text
                x={fromX + loop + 12}
                y={y - rise / 2 + labelSize * 0.36}
                fontFamily={ctx.fontFamily}
                fontSize={labelSize}
                fill={ctx.foreground}
              >
                {label}
              </text>
            ) : null}
          </g>
        )
      }

      const leftToRight = toX > fromX
      const startX = fromX
      const endX = toX
      const dir = leftToRight ? 1 : -1
      const dashed = message.type === 'dashed'
      const head = dashed
        ? <polyline
            points={openArrowPoints({ x: endX - dir * 1, y }, { x: dir, y: 0 }, arrowSize)}
            fill="none"
            stroke={ctx.muted}
            strokeWidth={lineWidth}
          />
        : <polygon points={arrowPoints({ x: endX - dir * 1, y }, { x: dir, y: 0 }, arrowSize)} fill={ctx.muted} />

      return (
        <g key={`msg-${index}`}>
          <line
            x1={startX + dir * 2}
            y1={y}
            x2={endX - dir * (arrowSize + 2)}
            y2={y}
            stroke={ctx.muted}
            strokeWidth={lineWidth}
            strokeDasharray={dashed ? '7 5' : undefined}
          />
          {head}
          {label ? (
            <text
              x={(startX + endX) / 2}
              y={y - 7 + labelSize * 0.36}
              textAnchor="middle"
              fontFamily={ctx.fontFamily}
              fontSize={labelSize}
              fill={ctx.foreground}
            >
              {label}
            </text>
          ) : null}
        </g>
      )
    })

    const noteEls = diagram.notes.map((note, index) => {
      const row = layout.rows.find((r) => r.kind === 'note' && r.index === index)!
      const fromX = layout.centerOf.get(note.from)!
      const toX = note.to ? layout.centerOf.get(note.to)! : fromX
      const left = Math.min(fromX, toX)
      const right = Math.max(fromX, toX)
      const spanWidth = Math.max(160, right === left ? 200 : right - left + 40)
      const x = right === left ? left - spanWidth / 2 : left - 20
      const lines = wrapText(note.label, spanWidth - ROW.notePadX * 2, noteSize)
      const height = row.height
      return (
        <g key={`note-${index}`}>
          <rect x={round(x)} y={round(row.y)} width={round(spanWidth)} height={round(height)} rx={6} fill={noteFill} stroke={noteBar} strokeOpacity={0.35} />
          <rect x={round(x)} y={round(row.y)} width={4} height={round(height)} rx={2} fill={noteBar} />
          {lines.map((line, i) => (
            <text
              key={i}
              x={round(x + ROW.notePadX + 4)}
              y={round(row.y + ROW.notePadY + noteSize * (i + 0.72))}
              fontFamily={ctx.fontFamily}
              fontSize={noteSize}
              fill={ctx.foreground}
            >
              {line}
            </text>
          ))}
        </g>
      )
    })

    return (
      <svg
        width={ctx.width}
        height={ctx.height}
        viewBox={`0 0 ${ctx.width} ${ctx.height}`}
        role="img"
        aria-label="时序图"
      >
        <g transform={`translate(${round(shiftX)}, ${round(shiftY)}) scale(${round(scale * 1000) / 1000})`}>
          {lifelines}
          {messageEls}
          {noteEls}
          {heads}
        </g>
      </svg>
    )
  },
}

export default sequence
