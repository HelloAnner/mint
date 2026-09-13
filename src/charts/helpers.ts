import { fail } from '../core/errors'

export type Row = Record<string, unknown>

export function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function shapeHint(): string {
  return '参见 mint info <chart> 里的「数据结构」一节'
}

/** 要求数据是「一行一条记录」的数组。 */
export function asRows(data: unknown, chartId: string): Row[] {
  if (!Array.isArray(data)) {
    fail('INVALID_DATA', `${chartId} 需要数组数据，收到 ${typeof data}`, shapeHint())
  }
  if (data.length === 0) {
    fail('INVALID_DATA', `${chartId} 的数据为空`, '至少提供一条记录')
  }
  const rows = data.filter(isPlainObject)
  if (rows.length !== data.length) {
    fail('INVALID_DATA', `${chartId} 的每一行都必须是对象`, shapeHint())
  }
  return rows as Row[]
}

export interface IndexKeys {
  indexBy: string
  keys: string[]
}

/**
 * 推断「分类轴 + 数值系列」结构：
 * 取第一个既定的分类字段作为 indexBy，其余数值字段作为系列 keys。
 */
export function inferIndexKeys(
  rows: Row[],
  options: { indexBy?: string; keys?: readonly string[] } = {},
): IndexKeys {
  const first = rows[0]!
  const fields = Object.keys(first)

  const indexBy =
    options.indexBy ??
    fields.find((f) => typeof first[f] === 'string') ??
    fields[0]!

  if (options.keys && options.keys.length > 0) {
    return { indexBy, keys: [...options.keys] }
  }

  const keys = fields.filter((f) => f !== indexBy && typeof first[f] === 'number')
  if (keys.length === 0) {
    fail(
      'INVALID_DATA',
      `无法推断数值系列：${indexBy} 之外没有数值字段`,
      `可用一条形如 {"${indexBy}": "Q1", "系列A": 100} 的记录`,
    )
  }
  return { indexBy, keys }
}

export interface PairDatum {
  id: string
  label: string
  value: number
  /** nivo 的部分图表要求数据带字符串索引签名 */
  [key: string]: string | number
}

/**
 * 归一化「占比 / 流程 / 分布」类数据，兼容多种常见写法：
 * - [{ id, label, value }]
 * - [{ name, value }]
 * - { "渠道A": 12, "渠道B": 30 }
 * - [["渠道A", 12], ["渠道B", 30]]
 */
export function asPairs(data: unknown, chartId: string): PairDatum[] {
  if (Array.isArray(data)) {
    if (data.length === 0) fail('INVALID_DATA', `${chartId} 的数据为空`)
    return data.map((item, i) => {
      if (Array.isArray(item)) {
        const [label, value] = item as [unknown, unknown]
        if (typeof value !== 'number') {
          fail('INVALID_DATA', `${chartId} 的第 ${i + 1} 项不是 [名称, 数值] 形式`)
        }
        const text = String(label)
        return { id: text, label: text, value }
      }
      if (isPlainObject(item)) {
        const rawId = item.id ?? item.name ?? item.key ?? item.label
        const rawValue = item.value ?? item.y ?? item.count ?? item.total
        if (rawId === undefined || typeof rawValue !== 'number') {
          fail(
            'INVALID_DATA',
            `${chartId} 的第 ${i + 1} 项缺少 id/name 或数值型 value`,
            '形如 {"id": "搜索", "value": 348}',
          )
        }
        const id = String(rawId)
        return { id, label: String(item.label ?? rawId), value: rawValue }
      }
      fail('INVALID_DATA', `${chartId} 的第 ${i + 1} 项既不是对象也不是二元数组`)
    })
  }

  if (isPlainObject(data)) {
    const entries = Object.entries(data).filter(([, v]) => typeof v === 'number') as [string, number][]
    if (entries.length === 0) {
      fail('INVALID_DATA', `${chartId} 的对象数据里没有数值字段`, '形如 {"搜索": 348, "社交": 266}')
    }
    return entries.map(([k, v]) => ({ id: k, label: k, value: v }))
  }

  fail('INVALID_DATA', `${chartId} 需要数组或对象数据，收到 ${typeof data}`, shapeHint())
}

export interface SeriesDatum {
  id: string
  data: { x: string | number; y: number }[]
}

/**
 * 归一化「折线 / 散点 / 面积」类数据，兼容：
 * - [{ id, data: [{ x, y }] }]
 * - [{ x, y, series }]  （用 series 字段分组）
 * - { "系列A": [1, 2, 3] }（配合 labels 生成 x）
 */
export function asSeries(
  data: unknown,
  chartId: string,
  options: { seriesBy?: string; xBy?: string; yBy?: string; labels?: readonly string[] } = {},
): SeriesDatum[] {
  const xBy = options.xBy ?? 'x'
  const yBy = options.yBy ?? 'y'

  if (Array.isArray(data)) {
    if (data.length === 0) fail('INVALID_DATA', `${chartId} 的数据为空`)

    const nested = data.filter(
      (d) => isPlainObject(d) && Array.isArray((d as Row).data),
    ) as Row[]

    if (nested.length === data.length) {
      return nested.map((serie, i) => {
        const id = String(serie.id ?? serie.name ?? `系列 ${i + 1}`)
        const points = (serie.data as unknown[])
          .filter(isPlainObject)
          .map((p, j) => {
            const row = p as Row
            const x = row[xBy] ?? row.name ?? row.label ?? row.x
            const y = row[yBy] ?? row.value ?? row.y
            if (y === undefined || typeof y !== 'number') {
              fail('INVALID_DATA', `${chartId} 的系列「${id}」第 ${j + 1} 个点缺少数值型 y`)
            }
            if (x === undefined) {
              fail('INVALID_DATA', `${chartId} 的系列「${id}」第 ${j + 1} 个点缺少 x`)
            }
            return { x: x as string | number, y }
          })
        if (points.length === 0) fail('INVALID_DATA', `${chartId} 的系列「${id}」没有数据点`)
        return { id, data: points }
      })
    }

    // 扁平记录：按 seriesBy 分组
    const rows = data.filter(isPlainObject) as Row[]
    const seriesField =
      options.seriesBy ?? Object.keys(rows[0]!).find((f) => typeof rows[0]![f] === 'string' && f !== xBy)

    if (seriesField) {
      const groups = new Map<string, { x: string | number; y: number }[]>()
      for (const [i, row] of rows.entries()) {
        const id = String(row[seriesField] ?? '默认')
        const x = row[xBy]
        const y = row[yBy]
        if (typeof y !== 'number' || x === undefined) {
          fail('INVALID_DATA', `${chartId} 的第 ${i + 1} 行缺少数值型 ${yBy} 或 ${xBy}`)
        }
        if (!groups.has(id)) groups.set(id, [])
        groups.get(id)!.push({ x: x as string | number, y })
      }
      return [...groups.entries()].map(([id, points]) => ({ id, data: points }))
    }

    // 单系列：x/y 两列
    const rows2 = rows.filter((r) => typeof r[yBy] === 'number')
    if (rows2.length > 0 && seriesField === undefined) {
      const keys = Object.keys(rows[0]!).filter((k) => k !== xBy && typeof rows[0]![k] === 'number')
      if (keys.length > 1) {
        return keys.map((key) => ({
          id: key,
          data: rows2.map((r) => ({ x: r[xBy] as string | number, y: r[key] as number })),
        }))
      }
      return [
        {
          id: '数值',
          data: rows2.map((r) => ({ x: r[xBy] as string | number, y: r[yBy] as number })),
        },
      ]
    }
  }

  if (isPlainObject(data)) {
    const entries = Object.entries(data)
    return entries.map(([id, value]) => {
      if (!Array.isArray(value)) {
        fail('INVALID_DATA', `${chartId} 的「${id}」不是数组`, '形如 {"系列A": [1, 2, 3]}')
      }
      const labels = options.labels ?? value.map((_, i) => String(i + 1))
      return {
        id,
        data: value.map((v, i) => {
          if (typeof v !== 'number') fail('INVALID_DATA', `${chartId} 的「${id}」第 ${i + 1} 项不是数字`)
          return { x: labels[i] ?? String(i + 1), y: v }
        }),
      }
    })
  }

  fail('INVALID_DATA', `${chartId} 需要数组或对象数据，收到 ${typeof data}`, shapeHint())
}

export interface HierarchyNode {
  name: string
  value?: number
  children?: HierarchyNode[]
}

/**
 * 归一化层级数据，兼容：
 * - { name, children: [...] } 嵌套结构
 * - [{ name, value }] 单层列表（自动套一个根节点）
 * - [{ path: "A/B/C", value }] 用斜杠路径自动建树
 */
export function asHierarchy(data: unknown, options: { root?: string } = {}): HierarchyNode {
  const rootName = options.root ?? '总计'

  if (isPlainObject(data)) {
    if (Array.isArray(data.children)) return data as unknown as HierarchyNode
    if ('name' in data && typeof data.value === 'number') {
      return data as unknown as HierarchyNode
    }
  }

  if (Array.isArray(data) && data.length > 0) {
    const rows = data.filter(isPlainObject) as Row[]
    // 只有显式写了 path 字段才按 "/" 拆层级；name 里的斜杠是普通字符
    // （否则「文件/投影等待超时」会被误拆成两层）。
    const usesPath = rows.every((r) => typeof r.path === 'string')
    const usesName = rows.every((r) => typeof r.name === 'string')
    const hasPath = usesPath || usesName

    if (hasPath) {
      const root: HierarchyNode = { name: rootName, children: [] }

      for (const row of rows) {
        const raw = String(usesPath ? row.path : row.name)
        const value = typeof row.value === 'number' ? row.value : 1
        const segments = (usesPath ? raw.split('/') : [raw]).map((s) => s.trim()).filter(Boolean)
        let node = root
        for (const [depth, segment] of segments.entries()) {
          node.children ??= []
          let child = node.children.find((c) => c.name === segment)
          if (!child) {
            child = { name: segment }
            node.children.push(child)
          }
          if (depth === segments.length - 1) child.value = value
          node = child
        }
      }

      pruneEmpty(root)
      return root
    }
  }

  fail(
    'INVALID_DATA',
    '无法把数据解析成层级结构',
    '可以是 { name, children: [...] }，或 [{ name/path, value }]',
  )
}

/** 没有 value 也没有 children 的中间节点会导致 nivo 报错，这里做一次清理。 */
function pruneEmpty(node: HierarchyNode): number {
  if (node.children && node.children.length > 0) {
    let sum = 0
    node.children = node.children.filter((child) => {
      const v = pruneEmpty(child)
      if (v <= 0 && (!child.children || child.children.length === 0)) return false
      sum += v
      return true
    })
    // 有子节点的内部节点不写 value：nivo 会由 children 自动求和，
    // 显式写入会让 treemap 的面积分配出现根节点大面积留白。
    return sum
  }
  return node.value ?? 0
}

/** 归一化桑基图数据：既接受 { nodes, links }，也接受只有 links 的写法。 */
export function asGraph(
  data: unknown,
  chartId: string,
): { nodes: { id: string }[]; links: { source: string; target: string; value: number }[] } {
  if (isPlainObject(data) && Array.isArray(data.links)) {
    const rawLinks = data.links.filter(isPlainObject) as Row[]
    const links = rawLinks.map((l, i) => {
      const source = l.source ?? l.from
      const target = l.target ?? l.to
      const value = l.value ?? l.weight
      if (source === undefined || target === undefined || typeof value !== 'number') {
        fail('INVALID_DATA', `${chartId} 的第 ${i + 1} 条连线缺少 source/target/数值型 value`)
      }
      return { source: String(source), target: String(target), value }
    })

    let nodes = Array.isArray(data.nodes)
      ? (data.nodes as unknown[]).map((n) =>
          isPlainObject(n) ? { id: String(n.id ?? n.name) } : { id: String(n) },
        )
      : []

    if (nodes.length === 0) {
      const ids = new Set<string>()
      for (const l of links) {
        ids.add(l.source)
        ids.add(l.target)
      }
      nodes = [...ids].map((id) => ({ id }))
    }

    return { nodes, links }
  }

  fail(
    'INVALID_DATA',
    `${chartId} 需要 { nodes: [{ id }], links: [{ source, target, value }] } 结构`,
    'nodes 可以省略，会从 links 里自动推导',
  )
}
