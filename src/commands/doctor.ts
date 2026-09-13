import { accessSync, constants, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { listFontCandidates, resolveFont } from '../core/fonts'
import { PALETTES } from '../core/palettes'
import { allCharts } from '../core/registry'
import { rasterize } from '../core/raster'
import { agentsSkillsRoot, embeddedSkillFiles, repoSkillDir, skillStatus } from '../core/skills'
import { booleanValue, parseArgs, type FlagSpec } from '../cli/args'

const DOCTOR_FLAGS: FlagSpec[] = [{ name: 'json', type: 'boolean', description: '输出 JSON' }]

interface Check {
  name: string
  ok: boolean
  detail: string
  hint?: string
}

export async function runDoctor(argv: string[]): Promise<number> {
  const parsed = parseArgs(argv, DOCTOR_FLAGS)
  const checks: Check[] = []

  checks.push({
    name: '运行时',
    ok: true,
    detail: `Bun ${Bun.version} / ${process.platform} ${process.arch}`,
  })

  // 字体
  try {
    const font = resolveFont(process.env.MINT_FONT)
    const candidates = listFontCandidates()
    checks.push({
      name: '字体',
      ok: true,
      detail: `${font.family}（${font.path}）`,
    })
    if (candidates.length > 1) {
      checks.push({
        name: '字体候选',
        ok: true,
        detail: candidates.map((c) => c.family).join('、'),
      })
    }
  } catch (error) {
    checks.push({
      name: '字体',
      ok: false,
      detail: (error as Error).message,
      hint: '用 --font <path> 指定字体，或设置 MINT_FONT',
    })
  }

  // 光栅化后端：真跑一次最小渲染
  try {
    const font = resolveFont(process.env.MINT_FONT)
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><rect width="40" height="40" fill="#0d9488"/><text x="4" y="26" font-family="' + font.family + '" font-size="14" fill="#fff">图</text></svg>'
    const png = await rasterize(svg, { scale: 1, background: '#ffffff', font })
    checks.push({
      name: '光栅化后端',
      ok: png.byteLength > 0,
      detail: `resvg-wasm 可用，最小渲染产出 ${png.byteLength} bytes（含中文）`,
    })
  } catch (error) {
    checks.push({
      name: '光栅化后端',
      ok: false,
      detail: (error as Error).message,
      hint: '这是内嵌的 WASM，若失败通常说明二进制损坏，请重新构建',
    })
  }

  // 图表注册表
  checks.push({
    name: '图表',
    ok: allCharts().length > 0,
    detail: `已注册 ${allCharts().length} 种图表、${PALETTES.length} 套调色板`,
  })

  // 输出目录可写
  try {
    const dir = mkdtempSync(join(tmpdir(), 'mint-doctor-'))
    accessSync(dir, constants.W_OK)
    rmSync(dir, { recursive: true, force: true })
    checks.push({ name: '临时目录可写', ok: true, detail: dir.replace(/mint-doctor-.*/, '') })
  } catch (error) {
    checks.push({ name: '临时目录可写', ok: false, detail: (error as Error).message })
  }

  // skill 安装状态
  const status = skillStatus()
  checks.push({
    name: 'skill 安装',
    ok: status.installed,
    detail: status.installed
      ? `${status.path} → ${status.target}`
      : `未安装（${status.path}）`,
    hint: status.installed ? undefined : '运行 mint install skill 安装',
  })

  checks.push({
    name: 'skill 来源',
    ok: true,
    detail: repoSkillDir()
      ? `仓库源码目录：${repoSkillDir()}（${embeddedSkillFiles().length} 个内嵌文件）`
      : `二进制内嵌内容，会释放到 ~/.mint/skills（${embeddedSkillFiles().length} 个文件）`,
  })

  checks.push({
    name: 'skills 目录',
    ok: true,
    detail: agentsSkillsRoot(),
  })

  if (booleanValue(parsed, 'json')) {
    console.log(JSON.stringify({ ok: checks.every((c) => c.ok), checks }, null, 2))
    return checks.every((c) => c.ok) ? 0 : 1
  }

  console.log('mint doctor\n')
  for (const check of checks) {
    console.log(`${check.ok ? '✓' : '✗'} ${check.name.padEnd(14)} ${check.detail}`)
    if (check.hint) console.log(`  ${' '.repeat(14)} → ${check.hint}`)
  }

  const failed = checks.filter((c) => !c.ok)
  console.log('')
  if (failed.length === 0) {
    console.log('一切正常，可以开始出图：mint render bar -o out.png')
  } else {
    console.log(`有 ${failed.length} 项需要处理。`)
  }
  return failed.length === 0 ? 0 : 1
}
