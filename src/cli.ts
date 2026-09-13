#!/usr/bin/env bun
import { MintError } from './core/errors'
import { ensureSkill } from './core/skills'
import { renderFlagTable } from './cli/args'
import { runInfo, runList, runPalettes } from './commands/list'
import { RENDER_FLAGS, reportRenderResult, runRender } from './commands/render'
import { runBatch } from './commands/batch'
import { runDoctor } from './commands/doctor'
import { runInstallSkill, runSkillCommand, runUninstallSkill } from './commands/skill'
import { MINT_VERSION } from './version'

/** 这些错误码属于用法问题，退出码用 2 与运行期失败区分开。 */
const USAGE_ERROR_CODES = new Set([
  'MISSING_ARGUMENT',
  'UNKNOWN_FLAG',
  'MISSING_VALUE',
  'INVALID_VALUE',
  'UNKNOWN_CHART',
])

const COMMANDS = [
  ['render <chart>', '渲染一张图（省略 --data 时用内置示例数据）'],
  ['batch <spec.json>', '按 spec 批量渲染'],
  ['list', '列出全部图表'],
  ['info <chart>', '查看某张图的数据结构、选项与示例'],
  ['palettes', '列出调色板'],
  ['doctor', '自检环境（字体、光栅化、skill）'],
  ['install skill', '把 mint skill 软链到 ~/.agents/skills'],
  ['uninstall skill', '移除该软链'],
  ['skill [status|path|list|show]', '查看 skill 安装状态'],
] as const

const EXAMPLES = [
  'mint list',
  'mint info bar',
  'mint render bar -o revenue.png',
  'mint render line --data dau.json --title "日活趋势" --theme dark -o dau.png',
  "cat data.json | mint render pie --data - --title '渠道占比' -o pie.png",
  'mint batch report.json',
  'mint doctor',
]

function printHelp(): void {
  const cmdWidth = Math.max(...COMMANDS.map(([name]) => name.length)) + 2
  console.log(`mint — 把数据变成美观的图表

用法
  mint <command> [options]
  mint render --help        查看渲染参数

命令`)
  for (const [name, description] of COMMANDS) {
    console.log(`  ${name.padEnd(cmdWidth)}${description}`)
  }
  console.log(`
常用渲染参数
${renderFlagTable(RENDER_FLAGS.filter((f) => !['set', 'options', 'json'].includes(f.name))).join('\n')}

示例`)
  for (const example of EXAMPLES) console.log(`  ${example}`)
  console.log(`
图表数据默认从 --data 指定的 JSON 读取；不传则用该图的内置示例数据，方便先看效果。
`)
}

function printRenderHelp(): void {
  console.log(`mint render <chart> [options]

参数
${renderFlagTable(RENDER_FLAGS).join('\n')}

示例
  mint render bar -o revenue.png
  mint render bar --data revenue.json --title "各区域季度营收" --subtitle "单位：百万元" -o revenue.png
  mint render line --data dau.json --set area=true --set yLegend="DAU（万）" -o dau.png
  mint render pie --data channel.json --theme dark --palette sunset -o channel.png
  mint render treemap --data tree.json --format svg -o tree.svg
`)
}

function hasFlag(argv: string[], name: string): boolean {
  return argv.some((token) => token === `--${name}` || token === `-${name.charAt(0)}`)
}

function suggestCommand(input: string): string | undefined {
  const candidates = COMMANDS.map(([name]) => name.split(' ')[0]!).filter((n) => n && !n.startsWith('<'))
  const hit = candidates.find((c) => c.startsWith(input.slice(0, 2)) || input.startsWith(c.slice(0, 2)))
  return hit
}

async function main(argv: string[]): Promise<number> {
  const [command, ...rest] = argv

  const quiet = process.env.MINT_QUIET === '1' || hasFlag(argv, 'quiet')

  if (!command || command === 'help' || command === '--help' || command === '-h') {
    printHelp()
    return 0
  }

  if (command === 'version' || command === '--version' || command === '-v') {
    console.log(MINT_VERSION)
    return 0
  }

  if (rest.includes('--help') || rest.includes('-h')) {
    if (command === 'render') printRenderHelp()
    else printHelp()
    return 0
  }

  // 每次运行都确认 skill 已安装；卸载命令除外，否则会立刻被装回去
  if (command !== 'uninstall') {
    const ensured = await ensureSkill()
    if (ensured.action === 'installed' && !quiet) {
      console.error(`mint: 检测到 skill 未安装，已自动软链到 ${ensured.path}`)
      console.error('      （不想自动安装可设置环境变量 MINT_NO_AUTO_SKILL=1）')
    }
  }

  switch (command) {
    case 'render': {
      const result = await runRender(rest)
      if (hasFlag(rest, 'json')) console.log(JSON.stringify(result, null, 2))
      else if (!quiet) reportRenderResult(result)
      return 0
    }
    case 'batch':
      return await runBatch(rest)
    case 'list':
      return runList(rest)
    case 'info':
      return runInfo(rest)
    case 'palettes':
    case 'palette':
      return runPalettes(rest)
    case 'doctor':
      return await runDoctor(rest)
    case 'install':
      return await runInstallSkill(rest)
    case 'uninstall':
      return await runUninstallSkill(rest)
    case 'skill':
      return runSkillCommand(rest)
    default: {
      const suggestion = suggestCommand(command)
      throw new MintError(
        'MISSING_ARGUMENT',
        `未知命令：${command}`,
        suggestion ? `你是不是想用 mint ${suggestion}？` : '用 mint help 查看全部命令',
      )
    }
  }
}

try {
  const code = await main(Bun.argv.slice(2))
  process.exitCode = code
} catch (error) {
  if (error instanceof MintError) {
    console.error(`\n✗ ${error.message}`)
    if (error.hint) console.error(`  → ${error.hint}`)
    process.exitCode = USAGE_ERROR_CODES.has(error.code) ? 2 : 1
  } else {
    console.error('\n✗ 未预期的错误：', error instanceof Error ? error.message : error)
    if (process.env.MINT_DEBUG === '1' && error instanceof Error) console.error(error.stack)
    else console.error('  → 加 MINT_DEBUG=1 重新运行可以看到完整堆栈')
    process.exitCode = 1
  }
}
