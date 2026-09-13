import { describe, expect, test } from 'bun:test'
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { runRender } from '../src/commands/render'
import { MintError } from '../src/core/errors'
import { asGraph, asHierarchy, asPairs, asSeries, inferIndexKeys } from '../src/charts/helpers'
import { renderChart } from '../src/core/render'
import { requireChart } from '../src/core/registry'

describe('数据归一化', () => {
  test('对象形式的占比数据能转成键值对', () => {
    const pairs = asPairs({ 搜索: 348, 社交: 266 }, 'pie')
    expect(pairs).toHaveLength(2)
    expect(pairs[0]).toEqual({ id: '搜索', label: '搜索', value: 348 })
  })

  test('二元数组形式的占比数据', () => {
    const pairs = asPairs([['搜索', 348]], 'pie')
    expect(pairs[0]!.value).toBe(348)
  })

  test('扁平记录能按系列字段分组成折线数据', () => {
    const series = asSeries(
      [
        { x: '1月', y: 1, channel: 'A' },
        { x: '1月', y: 2, channel: 'B' },
        { x: '2月', y: 3, channel: 'A' },
      ],
      'line',
    )
    expect(series).toHaveLength(2)
    expect(series.find((s) => s.id === 'A')!.data).toHaveLength(2)
  })

  test('斜杠路径能建成层级树', () => {
    const tree = asHierarchy([
      { path: '线上/华东', value: 10 },
      { path: '线上/华北', value: 20 },
      { path: '线下', value: 5 },
    ])
    expect(tree.name).toBe('总计')
    expect(tree.children).toHaveLength(2)
    expect(tree.children!.find((c) => c.name === '线上')!.children).toHaveLength(2)
  })

  test('扁平 name 里的斜杠不拆层级，且内部节点不写死 value', () => {
    const tree = asHierarchy([
      { name: '文件/投影等待超时', value: 3 },
      { name: '文件与编辑', value: 4 },
    ])
    expect(tree.children).toHaveLength(2)
    expect(tree.children!.map((c) => c.name)).toContain('文件/投影等待超时')
    // 根节点带 value 会让 treemap 面积分配出现大面积留白
    expect(tree.value).toBeUndefined()
    expect(tree.children!.every((c) => c.value !== undefined)).toBe(true)
  })

  test('桑基图可以只给 links', () => {
    const graph = asGraph({ links: [{ source: 'a', target: 'b', value: 3 }] }, 'sankey')
    expect(graph.nodes.map((n) => n.id).sort()).toEqual(['a', 'b'])
  })

  test('自动推断分类轴与数值系列', () => {
    const { indexBy, keys } = inferIndexKeys([
      { quarter: 'Q1', 华东: 1, 华北: 2 },
      { quarter: 'Q2', 华东: 3, 华北: 4 },
    ])
    expect(indexBy).toBe('quarter')
    expect(keys).toEqual(['华东', '华北'])
  })
})

describe('错误处理', () => {
  test('未知图表给出可用列表', () => {
    expect(() => requireChart('not-a-chart')).toThrow(MintError)
  })

  test('数据结构不对时报 INVALID_DATA 并给出提示', async () => {
    const chart = requireChart('bar')
    await expect(
      renderChart({
        definition: chart,
        data: [{ quarter: 'Q1' }],
        width: 400,
        height: 300,
        scale: 1,
        theme: 'light',
        palette: 'mint',
        format: 'png',
      }),
    ).rejects.toThrow(/数值系列|INVALID_DATA/)
  })

  test('画布过小会被拒绝', async () => {
    const chart = requireChart('bar')
    await expect(
      renderChart({
        definition: chart,
        data: chart.example.data,
        title: '标题占掉了太多空间',
        width: 200,
        height: 150,
        scale: 1,
        theme: 'light',
        palette: 'mint',
        format: 'png',
      }),
    ).rejects.toThrow(/CANVAS_TOO_SMALL|画布太小/)
  })
})

describe('示例选项不污染用户数据', () => {
  test('用户数据渲染时不会继承示例的坐标轴标题', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'mint-opt-'))
    const dataPath = join(dir, 'data.json')
    const outPath = join(dir, 'bar.svg')
    writeFileSync(dataPath, JSON.stringify([{ 区域: 'A', 数值: 1 }, { 区域: 'B', 数值: 2 }]))
    await runRender(['bar', '--data', dataPath, '-o', outPath, '--format', 'svg'])
    const svg = readFileSync(outPath, 'utf8')
    expect(svg).not.toContain('营收（百万元）')
    expect(svg).not.toContain('2025 财年')
    rmSync(dir, { recursive: true, force: true })
  })

  test('用内置示例数据时仍保留示例选项', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'mint-opt-demo-'))
    const outPath = join(dir, 'bar.svg')
    await runRender(['bar', '-o', outPath, '--format', 'svg'])
    const svg = readFileSync(outPath, 'utf8')
    expect(svg).toContain('营收（百万元）')
    rmSync(dir, { recursive: true, force: true })
  })
})

describe('图表别名', () => {
  test('中文别名能定位到图表', () => {
    expect(requireChart('柱状图').id).toBe('bar')
    expect(requireChart('饼图').id).toBe('pie')
    expect(requireChart('折线').id).toBe('line')
  })
})
