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
      expect(chart.nivoPackage).toMatch(/^@nivo\//)
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
