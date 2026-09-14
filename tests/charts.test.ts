import { describe, expect, test } from 'bun:test'
import { allCharts } from '../src/core/registry'
import { renderChart } from '../src/core/render'

const charts = allCharts()

describe('图表注册表', () => {
  test('图表数量符合预期', () => {
    expect(charts.length).toBeGreaterThanOrEqual(20)
  })

  test('id 唯一', () => {
    const ids = charts.map((c) => c.id)
    expect(new Set(ids).size).toBe(ids.length)
  })

  test('每张图都有完整元信息', () => {
    for (const chart of charts) {
      expect(chart.id).toMatch(/^[a-z][a-z0-9-]*$/)
      expect(chart.name.length).toBeGreaterThan(0)
      expect(chart.englishName.length).toBeGreaterThan(0)
      expect(chart.description.length).toBeGreaterThan(0)
      expect(chart.dataShape.length).toBeGreaterThan(0)
      // 自绘图表（如架构图）没有 nivo 包，有就必须写对
      if (chart.nivoPackage) expect(chart.nivoPackage).toMatch(/^@nivo\//)
      expect(chart.example.data).toBeDefined()
    }
  })

  test('选项 key 不重复', () => {
    for (const chart of charts) {
      const keys = (chart.options ?? []).map((o) => o.key)
      expect(new Set(keys).size, `${chart.id} 有重复的选项 key`).toBe(keys.length)
    }
  })
})

/**
 * 端到端冒烟：每张图都用自带的示例数据真渲染一次。
 * 这是「每一张图都经过测试」这条承诺的兑现方式 —— 新增图表会自动被覆盖。
 */
describe('端到端渲染', () => {
  for (const chart of charts) {
    test(`${chart.id} 渲染出 PNG 与 SVG`, async () => {
      const result = await renderChart({
        definition: chart,
        data: chart.example.data,
        options: chart.example.options,
        title: chart.name,
        width: 720,
        height: 480,
        scale: 1,
        theme: 'light',
        palette: 'mint',
        format: 'both',
      })

      expect(result.png, 'png 应该是 Buffer').toBeDefined()
      expect(result.png!.byteLength).toBeGreaterThan(1500)
      // PNG 魔数
      expect(Array.from(result.png!.slice(0, 4))).toEqual([0x89, 0x50, 0x4e, 0x47])

      expect(result.svg.startsWith('<svg')).toBe(true)
      expect(result.svg).toContain('</svg>')
      expect(result.svg).toContain(chart.name)
    })
  }
})

describe('主题与调色板', () => {
  test('暗色主题也能渲染', async () => {
    const chart = charts.find((c) => c.id === 'bar')!
    const result = await renderChart({
      definition: chart,
      data: chart.example.data,
      options: chart.example.options,
      width: 640,
      height: 420,
      scale: 1,
      theme: 'dark',
      palette: 'sunset',
      format: 'png',
    })
    expect(result.png!.byteLength).toBeGreaterThan(1500)
    expect(result.svg).toContain('#0f172a')
  })

  test('七套调色板都能用于同一张图', async () => {
    const chart = charts.find((c) => c.id === 'bar')!
    for (const palette of ['mint', 'indigo', 'sunset', 'ocean', 'forest', 'candy', 'mono']) {
      const result = await renderChart({
        definition: chart,
        data: chart.example.data,
        width: 480,
        height: 360,
        scale: 1,
        theme: 'light',
        palette,
        format: 'png',
      })
      expect(result.png!.byteLength, palette).toBeGreaterThan(1000)
    }
  })
})

/**
 * 只断言「产出了 PNG」会漏掉「画布空白」这类问题：
 * 例如平行坐标图曾因 variables 字段名不对，每张图都只画出一根竖线。
 */
describe('图表内容不塌陷', () => {
  test('平行坐标图为每个对象画出数据线', async () => {
    const chart = charts.find((c) => c.id === 'parallel-coordinates')!
    const result = await renderChart({
      definition: chart,
      data: chart.example.data,
      width: 900,
      height: 540,
      scale: 1,
      theme: 'light',
      palette: 'mint',
      format: 'svg',
    })
    const paths = (result.svg.match(/<path/g) ?? []).length
    expect(paths).toBeGreaterThanOrEqual((chart.example.data as unknown[]).length)
  })

  test('马赛克图渲染出组内构成的图例', async () => {
    const chart = charts.find((c) => c.id === 'marimekko')!
    const result = await renderChart({
      definition: chart,
      data: chart.example.data,
      width: 900,
      height: 540,
      scale: 1,
      theme: 'light',
      palette: 'mint',
      format: 'svg',
    })
    expect(result.svg).toContain('新客')
    expect(result.svg).toContain('老客')
  })
})
/**
 * 架构图是唯一一张 mint 自绘 SVG 的图表，单独盯住「层、方块、箭头都真的画出来了」。
 */
describe('架构图', () => {
  const chart = charts.find((c) => c.id === 'architecture')!
  const example = chart.example.data as { layers: { nodes: unknown[] }[]; edges: unknown[] }
  const nodeCount = example.layers.reduce((sum, layer) => sum + layer.nodes.length, 0)

  test('层名、方块标题、说明小字与箭头都出现在 SVG 里', async () => {
    const result = await renderChart({
      definition: chart,
      data: chart.example.data,
      title: chart.name,
      width: 1000,
      height: 700,
      scale: 1,
      theme: 'light',
      palette: 'mint',
      format: 'svg',
    })
    expect(result.svg).toContain('客户端')
    expect(result.svg).toContain('API 网关')
    expect(result.svg).toContain('鉴权 · 限流')
    // 每个节点至少一个 rect，每条连线一个箭头 polygon
    expect((result.svg.match(/<rect/g) ?? []).length).toBeGreaterThanOrEqual(nodeCount)
    expect((result.svg.match(/<polygon/g) ?? []).length).toBe(example.edges.length)
  })

  test('nodes + layer 字段能自动分层', async () => {
    const result = await renderChart({
      definition: chart,
      data: {
        nodes: [
          { id: 'a', label: '前端', layer: '客户端' },
          { id: 'b', label: '后端', layer: '服务端' },
        ],
        edges: [{ from: 'a', to: 'b' }],
      },
      width: 800,
      height: 600,
      scale: 1,
      theme: 'dark',
      palette: 'ocean',
      format: 'svg',
    })
    expect(result.svg).toContain('客户端')
    expect(result.svg).toContain('服务端')
    expect(result.svg).toContain('前端')
  })

  test('横向分层与折线连线也能渲染', async () => {
    const result = await renderChart({
      definition: chart,
      data: chart.example.data,
      options: { direction: 'horizontal', edgeStyle: 'elbow' },
      width: 1000,
      height: 640,
      scale: 1,
      theme: 'light',
      palette: 'indigo',
      format: 'png',
    })
    expect(result.png!.byteLength).toBeGreaterThan(1500)
  })
})

