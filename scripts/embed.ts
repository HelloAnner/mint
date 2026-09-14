/**
 * 构建前置脚本，做两件事：
 * 1. 由图表注册表生成 skill 里的图表目录 charts.md，保证文档与代码不脱节；
 * 2. 生成 src/generated/skill-files.ts，用 bun 的 file 导入把 skill 内容登记下来，
 *    这样 bun build --compile 会把它们一起打进二进制。
 */
import { mkdirSync, readdirSync, statSync, writeFileSync } from 'node:fs'
import { join, relative } from 'node:path'
import { CHARTS } from '../src/charts'
import { CATEGORY_LABELS, type ChartCategory } from '../src/core/types'
import { PALETTES } from '../src/core/palettes'

const REPO = join(import.meta.dir, '..')
const SKILL_DIR = join(REPO, 'skills', 'mint')

function walk(dir: string): string[] {
  const out: string[] = []
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry)
    if (statSync(full).isDirectory()) out.push(...walk(full))
    else out.push(full)
  }
  return out
}

function renderChartsDoc(): string {
  const lines: string[] = []
  lines.push('# mint 图表目录')
  lines.push('')
  lines.push(`共 ${CHARTS.length} 种图表，均随 mint 一起安装了端到端渲染测试。`)
  lines.push('')
  lines.push('除 `architecture`（架构图，mint 自绘 SVG）外，其余图表都基于 nivo 0.99 渲染。')
  lines.push('')
  lines.push('用 `mint info <id>` 查看某张图的完整选项与可运行示例。')
  lines.push('')

  const byCategory = new Map<ChartCategory, typeof CHARTS>()
  for (const chart of CHARTS) {
    const list = byCategory.get(chart.category) ?? []
    byCategory.set(chart.category, [...list, chart])
  }

  lines.push('## 分类速览')
  lines.push('')
  lines.push('| 分类 | 图表 |')
  lines.push('|------|------|')
  for (const [category, charts] of byCategory) {
    lines.push(`| ${CATEGORY_LABELS[category]} | ${charts.map((c) => `\`${c.id}\``).join(' · ')} |`)
  }
  lines.push('')

  for (const [category, charts] of byCategory) {
    lines.push(`## ${CATEGORY_LABELS[category]}`)
    lines.push('')
    for (const chart of charts) {
      lines.push(`### \`${chart.id}\` — ${chart.name}（${chart.englishName}）`)
      lines.push('')
      lines.push(chart.description)
      lines.push('')
      if (chart.variants?.length) {
        lines.push(`**形态**：${chart.variants.join(' / ')}`)
        lines.push('')
      }
      lines.push('**数据结构**')
      lines.push('')
      lines.push('```')
      lines.push(chart.dataShape)
      lines.push('```')
      lines.push('')
      lines.push(`**最小示例**：\`mint render ${chart.id} -o ${chart.id}.png\`（不传 --data 时用内置示例数据）`)
      lines.push('')
      if (chart.options?.length) {
        lines.push('**专属选项**')
        lines.push('')
        lines.push('| 选项 | 类型 | 默认 | 说明 |')
        lines.push('|------|------|------|------|')
        for (const option of chart.options) {
          const values = option.values ? `（${option.values.join(' / ')}）` : ''
          const def = option.default === undefined ? '—' : `\`${JSON.stringify(option.default)}\``
          lines.push(`| \`${option.key}\` | ${option.type} | ${def} | ${option.description}${values} |`)
        }
        lines.push('')
      }
      if (chart.aliases?.length) {
        lines.push(`**别名**：${chart.aliases.join('、')}`)
        lines.push('')
      }
    }
  }

  lines.push('## 调色板')
  lines.push('')
  lines.push('| id | 名称 | 说明 |')
  lines.push('|----|------|------|')
  for (const palette of PALETTES) {
    lines.push(`| \`${palette.id}\` | ${palette.name} | ${palette.description} |`)
  }
  lines.push('')

  return lines.join('\n')
}

// 1) charts.md
mkdirSync(join(SKILL_DIR, 'references'), { recursive: true })
writeFileSync(join(SKILL_DIR, 'references', 'charts.md'), renderChartsDoc(), 'utf8')
console.log('generated skills/mint/references/charts.md')

// 2) src/generated/skill-files.ts
const allFiles = walk(SKILL_DIR).sort()
const generatedDir = join(REPO, 'src', 'generated')
mkdirSync(generatedDir, { recursive: true })

const imports: string[] = []
const entries: string[] = []
allFiles.forEach((file, index) => {
  const relToSkill = relative(SKILL_DIR, file).split('\\').join('/')
  const relFromGenerated = relative(generatedDir, file).split('\\').join('/')
  const specifier = relFromGenerated.startsWith('.') ? relFromGenerated : './' + relFromGenerated
  imports.push(`import skillFile${index} from '${specifier}' with { type: 'file' }`)
  entries.push(`  { path: '${relToSkill}', file: skillFile${index} },`)
})

const content = [
  '// 本文件由 scripts/embed.ts 自动生成，请勿手改。',
  '// 这些 import 会被 bun build --compile 一并打进二进制，运行时用 Bun.file() 读取。',
  '',
  ...imports,
  '',
  'export interface EmbeddedSkillFile {',
  '  /** 相对 skill 根目录的路径 */',
  '  path: string',
  '  /** 运行时可直接读取的文件引用 */',
  '  file: string',
  '}',
  '',
  'export const SKILL_FILES: readonly EmbeddedSkillFile[] = [',
  ...entries,
  ']',
  '',
].join('\n')

writeFileSync(join(generatedDir, 'skill-files.ts'), content, 'utf8')
console.log(`generated src/generated/skill-files.ts (${allFiles.length} files)`)
