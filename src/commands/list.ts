import { PALETTES } from '../core/palettes'
import { allCharts, chartById } from '../core/registry'
import { CATEGORY_LABELS, type ChartCategory } from '../core/types'
import { fail } from '../core/errors'
import { booleanValue, parseArgs, stringValue, type FlagSpec } from '../cli/args'

const LIST_FLAGS: FlagSpec[] = [
  { name: 'category', alias: 'c', type: 'string', description: '只显示某个分类', placeholder: '<cmp|trend|…>' },
  { name: 'json', type: 'boolean', description: '输出 JSON' },
]

export function runList(argv: string[]): number {
  const parsed = parseArgs(argv, LIST_FLAGS)
  const category = stringValue(parsed, 'category')

  const charts = allCharts().filter((c) => {
    if (!category) return true
    const needle = category.toLowerCase()
    const matched = (Object.entries(CATEGORY_LABELS) as [ChartCategory, string][]).find(
      ([key, label]) => key === needle || label === category,
    )
    return matched ? c.category === matched[0] : c.category === needle
  })

  if (booleanValue(parsed, 'json')) {
    console.log(
      JSON.stringify(
        charts.map((c) => ({
          id: c.id,
          name: c.name,
          englishName: c.englishName,
          category: c.category,
          categoryLabel: CATEGORY_LABELS[c.category],
          description: c.description,
          variants: c.variants ?? [],
          aliases: c.aliases ?? [],
          nivoPackage: c.nivoPackage,
        })),
        null,
        2,
      ),
    )
    return 0
  }

  const byCategory = new Map<ChartCategory, typeof charts>()
  for (const chart of charts) {
    byCategory.set(chart.category, [...(byCategory.get(chart.category) ?? []), chart])
  }

  console.log(`mint 内置 ${allCharts().length} 种图表\n`)

  const idWidth = Math.max(...charts.map((c) => c.id.length)) + 2
  const nameWidth = Math.max(...charts.map((c) => c.name.length)) + 2

  for (const [cat, list] of byCategory) {
    console.log(`${CATEGORY_LABELS[cat]}  (${cat})`)
    for (const chart of list) {
      console.log(
        `  ${chart.id.padEnd(idWidth)}${chart.name.padEnd(nameWidth)}${chart.description}`,
      )
    }
    console.log('')
  }

  console.log('查看某张图的详情与选项：mint info <chart>')
  console.log('直接出图（用内置示例数据）：mint render <chart> -o out.png')
  return 0
}

const INFO_FLAGS: FlagSpec[] = [
  { name: 'json', type: 'boolean', description: '输出 JSON' },
  { name: 'example', type: 'boolean', description: '只输出可运行示例' },
]

export function runInfo(argv: string[]): number {
  const parsed = parseArgs(argv, INFO_FLAGS)
  const id = parsed.positionals[0]
  if (!id) fail('MISSING_ARGUMENT', 'mint info 需要指定图表 id', '例如 mint info bar')

  const chart = chartById(id)
  if (!chart) return unknownChart(id)

  const exampleCommand = `mint render ${chart.id} -o ${chart.id}.png`
  const exampleWithData = `mint render ${chart.id} --data data.json --title "标题" -o ${chart.id}.png`

  if (booleanValue(parsed, 'json')) {
    console.log(
      JSON.stringify(
        {
          id: chart.id,
          name: chart.name,
          englishName: chart.englishName,
          category: chart.category,
          categoryLabel: CATEGORY_LABELS[chart.category],
          description: chart.description,
          dataShape: chart.dataShape,
          nivoPackage: chart.nivoPackage,
          variants: chart.variants ?? [],
          aliases: chart.aliases ?? [],
          options: chart.options ?? [],
          example: chart.example,
          exampleCommand,
        },
        null,
        2,
      ),
    )
    return 0
  }

  if (booleanValue(parsed, 'example')) {
    console.log(exampleCommand)
    console.log(exampleWithData)
    return 0
  }

  console.log(`${chart.id} — ${chart.name}（${chart.englishName}）`)
  console.log(`分类：${CATEGORY_LABELS[chart.category]}　nivo 包：${chart.nivoPackage}`)
  console.log('')
  console.log(chart.description)
  console.log('')

  if (chart.variants?.length) {
    console.log(`形态：${chart.variants.join(' / ')}`)
    console.log('')
  }
  if (chart.aliases?.length) {
    console.log(`别名：${chart.aliases.join('、')}`)
    console.log('')
  }

  console.log('数据结构：')
  for (const line of chart.dataShape.split('\n')) console.log(`  ${line}`)
  console.log('')

  if (chart.options?.length) {
    console.log('选项：')
    const keyWidth = Math.max(...chart.options.map((o) => o.key.length)) + 2
    for (const option of chart.options) {
      const def = option.default === undefined ? '' : `  默认 ${JSON.stringify(option.default)}`
      const values = option.values ? `  [${option.values.join(' | ')}]` : ''
      console.log(`  ${option.key.padEnd(keyWidth)}${option.description}${values}${def}`)
    }
    console.log('')
  }

  console.log('示例：')
  console.log(`  ${exampleCommand}`)
  console.log(`  ${exampleWithData}`)
  console.log('')
  console.log('内置示例数据：')
  console.log(
    JSON.stringify(chart.example.data, null, 2)
      .split('\n')
      .slice(0, 20)
      .map((l) => '  ' + l)
      .join('\n'),
  )
  const exampleLines = JSON.stringify(chart.example.data, null, 2).split('\n').length
  if (exampleLines > 20) console.log('  …（完整数据见 mint info ' + chart.id + ' --json）')
  if (chart.example.options) {
    console.log('')
    console.log(`建议选项：--options '${JSON.stringify(chart.example.options)}'`)
  }

  return 0
}

function unknownChart(id: string): number {
  fail('UNKNOWN_CHART', `没有名为「${id}」的图表`, '用 mint list 查看全部图表')
}

export function runPalettes(argv: string[]): number {
  const parsed = parseArgs(argv, [{ name: 'json', type: 'boolean', description: '输出 JSON' }])
  if (booleanValue(parsed, 'json')) {
    console.log(JSON.stringify(PALETTES, null, 2))
    return 0
  }
  console.log('mint 内置调色板\n')
  const width = Math.max(...PALETTES.map((p) => p.id.length)) + 2
  for (const palette of PALETTES) {
    console.log(`  ${palette.id.padEnd(width)}${palette.name.padEnd(6)}${palette.description}`)
    console.log(`  ${' '.repeat(width + 6)}${palette.colors.join(' ')}`)
  }
  console.log('')
  console.log('用法：mint render bar --palette indigo --theme light -o out.png')
  return 0
}
