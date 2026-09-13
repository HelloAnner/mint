import { fail } from '../core/errors'
import { defaultOutput, planOutputs, writeOutputs } from '../core/output'
import { renderChart } from '../core/render'
import { requireChart } from '../core/registry'
import type { OutputFormat } from '../core/spec'
import { booleanValue, listValue, numberValue, parseArgs, stringValue, type FlagSpec } from '../cli/args'
import { loadData, parseOptionsJson, parseSetFlags } from '../cli/render-options'

export const RENDER_FLAGS: FlagSpec[] = [
  { name: 'data', alias: 'd', type: 'string', description: '数据 JSON 文件，- 表示从 stdin 读取', placeholder: '<file|->' },
  { name: 'out', alias: 'o', type: 'string', description: '输出路径，- 表示写到 stdout', placeholder: '<file>' },
  { name: 'title', alias: 't', type: 'string', description: '主标题', placeholder: '<text>' },
  { name: 'subtitle', alias: 's', type: 'string', description: '副标题', placeholder: '<text>' },
  { name: 'footnote', type: 'string', description: '左下角脚注，常用来写数据来源', placeholder: '<text>' },
  { name: 'width', alias: 'W', type: 'number', description: '逻辑宽度', placeholder: '<n>' },
  { name: 'height', alias: 'H', type: 'number', description: '逻辑高度', placeholder: '<n>' },
  { name: 'scale', type: 'number', description: '像素倍数，2 为 2x 高清', placeholder: '<n>' },
  { name: 'theme', type: 'string', description: '主题 light 或 dark', placeholder: '<light|dark>' },
  { name: 'palette', type: 'string', description: '调色板 id，见 mint palettes', placeholder: '<id>' },
  { name: 'format', type: 'string', description: '输出格式 png / svg / both', placeholder: '<fmt>' },
  { name: 'font', type: 'string', description: '指定字体文件（.ttf/.otf/.ttc）', placeholder: '<path>' },
  { name: 'set', type: 'list', description: '设置图表选项 key=value，可重复', placeholder: '<k=v>' },
  { name: 'options', type: 'string', description: '用 JSON 一次性传图表选项', placeholder: '<json>' },
  { name: 'border', type: 'boolean', description: '给图像描一圈边' },
  { name: 'json', type: 'boolean', description: '输出机器可读的结果' },
]

export interface RenderCommandResult {
  ok: true
  chart: string
  outputs: { path: string; format: string; bytes: number }[]
  width: number
  height: number
  pixelWidth: number
  pixelHeight: number
  font: string
  fontFamily: string
}

export async function runRender(argv: string[]): Promise<RenderCommandResult> {
  const parsed = parseArgs(argv, RENDER_FLAGS)
  const chartId = parsed.positionals[0]

  if (!chartId) {
    fail('MISSING_ARGUMENT', 'mint render 需要指定图表 id', '例如 mint render bar -o out.png，用 mint list 查看全部图表')
  }

  const definition = requireChart(chartId)
  const loaded = await loadData(stringValue(parsed, 'data'))
  const usingExampleData = loaded === undefined
  const data = loaded?.data ?? definition.example.data

  // 示例里的 options 只是为了让内置 demo 好看，绝不能当作所有渲染的默认值：
  // 否则用户数据会被塞进「营收（百万元）」「DAU（万）」这类示例坐标轴标题。
  const options = {
    ...(usingExampleData ? (definition.example.options ?? {}) : {}),
    ...parseOptionsJson(stringValue(parsed, 'options')),
    ...parseSetFlags(listValue(parsed, 'set')),
  }

  const format = (stringValue(parsed, 'format') ?? 'png') as OutputFormat
  if (!['png', 'svg', 'both'].includes(format)) {
    fail('INVALID_VALUE', `--format 只能是 png / svg / both，收到 ${format}`)
  }

  const theme = stringValue(parsed, 'theme') ?? 'light'
  if (theme !== 'light' && theme !== 'dark') {
    fail('INVALID_VALUE', `--theme 只能是 light 或 dark，收到 ${theme}`)
  }

  const outTarget = stringValue(parsed, 'out')
  const toStdout = outTarget === '-'
  const target = toStdout ? null : (outTarget ?? defaultOutput(definition.id, format))

  const result = await renderChart({
    definition,
    data,
    options,
    title: stringValue(parsed, 'title'),
    subtitle: stringValue(parsed, 'subtitle'),
    footnote: stringValue(parsed, 'footnote'),
    width: numberValue(parsed, 'width') ?? 1280,
    height: numberValue(parsed, 'height') ?? 760,
    scale: numberValue(parsed, 'scale') ?? 2,
    theme,
    palette: stringValue(parsed, 'palette') ?? 'mint',
    format,
    font: stringValue(parsed, 'font'),
    border: booleanValue(parsed, 'border'),
  })

  if (toStdout) {
    if (format === 'svg') {
      process.stdout.write(result.svg)
    } else if (format === 'png') {
      process.stdout.write(result.png!)
    } else {
      fail('INVALID_VALUE', '--format both 不能配合 --out - 使用')
    }
    return {
      ok: true,
      chart: definition.id,
      outputs: [{ path: '<stdout>', format, bytes: format === 'png' ? result.png!.byteLength : result.svg.length }],
      width: result.width,
      height: result.height,
      pixelWidth: result.pixelWidth,
      pixelHeight: result.pixelHeight,
      font: result.font.path,
      fontFamily: result.font.family,
    }
  }

  const plan = planOutputs(target!, format)
  const written = writeOutputs(result, plan)

  return {
    ok: true,
    chart: definition.id,
    outputs: written.map((f) => ({ path: f.path, format: f.format, bytes: f.bytes })),
    width: result.width,
    height: result.height,
    pixelWidth: result.pixelWidth,
    pixelHeight: result.pixelHeight,
    font: result.font.path,
    fontFamily: result.font.family,
  }
}

export function reportRenderResult(result: RenderCommandResult): void {
  for (const output of result.outputs) {
    console.log(`✓ ${output.path}  (${output.format}, ${output.bytes} bytes)`)
  }
  console.log(
    `  ${result.chart}　${result.pixelWidth}×${result.pixelHeight}px　${result.fontFamily}`,
  )
}
