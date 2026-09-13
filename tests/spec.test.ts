import { describe, expect, test } from 'bun:test'
import { normalizeSpec } from '../src/core/spec'
import { planOutputs } from '../src/core/output'
import { getPalette, PALETTES, tint, tintRamp } from '../src/core/palettes'
import { embeddedSkillFiles, skillLinkPath } from '../src/core/skills'
import { MINT_VERSION } from '../src/version'

describe('spec 归一化', () => {
  test('补全默认值', () => {
    const spec = normalizeSpec({ chart: 'bar', data: [] })
    expect(spec.width).toBe(1280)
    expect(spec.height).toBe(760)
    expect(spec.scale).toBe(2)
    expect(spec.theme).toBe('light')
    expect(spec.palette).toBe('mint')
    expect(spec.format).toBe('png')
  })

  test('接受字符串形式的数字', () => {
    const spec = normalizeSpec({ chart: 'bar', data: [], width: '800', scale: '1' })
    expect(spec.width).toBe(800)
    expect(spec.scale).toBe(1)
  })

  test('主题取值受限', () => {
    expect(() => normalizeSpec({ chart: 'bar', data: [], theme: 'blue' })).toThrow()
  })

  test('调色板必须存在', () => {
    expect(() => normalizeSpec({ chart: 'bar', data: [], palette: 'nope' })).toThrow()
  })

  test('缺少 chart 或 data 会被拒绝', () => {
    expect(() => normalizeSpec({ data: [] })).toThrow()
    expect(() => normalizeSpec({ chart: 'bar' })).toThrow()
  })
})

describe('输出路径规划', () => {
  test('png 单格式', () => {
    expect(planOutputs('a/b/out', 'png').png).toMatch(/out\.png$/)
  })

  test('svg 会替换扩展名', () => {
    expect(planOutputs('a/b/out.png', 'svg').svg).toMatch(/out\.svg$/)
  })

  test('both 会输出两份', () => {
    const plan = planOutputs('a/out.svg', 'both')
    expect(plan.png).toMatch(/out\.png$/)
    expect(plan.svg).toMatch(/out\.svg$/)
  })
})

describe('调色板', () => {
  test('每个调色板至少有 8 个颜色且都是合法 hex', () => {
    for (const palette of PALETTES) {
      expect(palette.colors.length).toBeGreaterThanOrEqual(8)
      for (const color of palette.colors) expect(color).toMatch(/^#[0-9a-f]{6}$/)
    }
  })

  test('未知调色板回落到默认', () => {
    expect(getPalette('nope').id).toBe('mint')
  })

  test('tint 在两端分别得到白色与原色', () => {
    expect(tint('#0d9488', 0)).toBe('#ffffff')
    expect(tint('#0d9488', 1)).toBe('#0d9488')
  })

  test('tintRamp 生成由浅到深的阶梯', () => {
    const ramp = tintRamp('#0d9488', 5)
    expect(ramp).toHaveLength(5)
    expect(ramp[0]).toBe(tint('#0d9488', 0.18))
    expect(ramp[4]).toBe('#0d9488')
  })
})

describe('skill 内嵌', () => {
  test('内嵌了 SKILL.md 与参考文档', () => {
    const files = embeddedSkillFiles()
    expect(files).toContain('SKILL.md')
    expect(files.some((f) => f.startsWith('references/'))).toBe(true)
  })

  test('安装路径遵循 ~/.agents/skills 约定', () => {
    expect(skillLinkPath()).toMatch(/\.agents\/skills\/mint$/)
  })
})

describe('版本', () => {
  test('是语义化版本', () => {
    expect(MINT_VERSION).toMatch(/^\d+\.\d+\.\d+/)
  })
})
