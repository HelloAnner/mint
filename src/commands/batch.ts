import { existsSync, readFileSync } from 'node:fs'
import { dirname, isAbsolute, join, resolve } from 'node:path'
import { fail } from '../core/errors'
import { planOutputs, writeOutputs } from '../core/output'
import { renderChart } from '../core/render'
import { requireChart } from '../core/registry'
import { normalizeSpec, type OutputFormat } from '../core/spec'
import { booleanValue, parseArgs, type FlagSpec } from '../cli/args'

const BATCH_FLAGS: FlagSpec[] = [
  { name: 'outdir', type: 'string', description: '所有输出的根目录', placeholder: '<dir>' },
  { name: 'json', type: 'boolean', description: '输出机器可读的结果' },
  { name: 'stop-on-error', type: 'boolean', description: '遇到第一个错误就停止' },
]

export function runBatch(argv: string[]): number | Promise<number> {
  const parsed = parseArgs(argv, BATCH_FLAGS)
  const specPath = parsed.positionals[0]

  if (!specPath) {
    fail('MISSING_ARGUMENT', 'mint batch 需要一个 spec 文件', '例如 mint batch report.json')
  }
  if (!existsSync(specPath)) {
    fail('DATA_NOT_FOUND', `找不到 spec 文件：${specPath}`)
  }

  return executeBatch(specPath, {
    outdir: parsed.values.outdir as string | undefined,
    json: booleanValue(parsed, 'json'),
    stopOnError: booleanValue(parsed, 'stop-on-error'),
  })
}

async function executeBatch(
  specPath: string,
  opts: { outdir?: string; json: boolean; stopOnError: boolean },
): Promise<number> {
  const specsDir = dirname(resolve(specPath))

  let raw: unknown
  try {
    raw = JSON.parse(readFileSync(specPath, 'utf8'))
  } catch (error) {
    fail('INVALID_SPEC', `${specPath} 不是合法 JSON：${(error as Error).message}`)
  }

  let defaults: Record<string, unknown> = {}
  let items: Record<string, unknown>[]

  if (Array.isArray(raw)) {
    items = raw as Record<string, unknown>[]
  } else if (raw && typeof raw === 'object' && Array.isArray((raw as Record<string, unknown>).charts)) {
    const obj = raw as Record<string, unknown>
    defaults = (obj.defaults as Record<string, unknown>) ?? {}
    items = obj.charts as Record<string, unknown>[]
  } else if (raw && typeof raw === 'object') {
    items = [raw as Record<string, unknown>]
  } else {
    fail('INVALID_SPEC', 'spec 文件需要是一个对象或对象数组')
  }

  if (items.length === 0) fail('INVALID_SPEC', 'spec 文件里没有要渲染的图表')

  const results: { chart: string; out: string; ok: boolean; error?: string }[] = []
  let failures = 0

  for (const [index, item] of items.entries()) {
    const merged = { ...defaults, ...item }
    const label = `#${index + 1} ${String(merged.chart ?? '?')}`

    try {
      const dataFile = merged.dataFile
      if (typeof dataFile === 'string') {
        const resolved = isAbsolute(dataFile) ? dataFile : join(specsDir, dataFile)
        if (!existsSync(resolved)) fail('DATA_NOT_FOUND', `找不到数据文件 ${resolved}`)
        try {
          merged.data = JSON.parse(readFileSync(resolved, 'utf8'))
        } catch (error) {
          fail('INVALID_DATA', `${resolved} 不是合法 JSON：${(error as Error).message}`)
        }
      }

      const spec = normalizeSpec(merged)
      const definition = requireChart(spec.chart)

      const result = await renderChart({
        definition,
        data: spec.data,
        options: spec.options,
        title: spec.title,
        subtitle: spec.subtitle,
        footnote: spec.footnote,
        width: spec.width,
        height: spec.height,
        scale: spec.scale,
        theme: spec.theme,
        palette: spec.palette,
        format: spec.format,
        font: spec.font,
      })

      const rawOut = typeof merged.out === 'string' ? merged.out : `${spec.chart}.png`
      const finalOut = opts.outdir
        ? join(opts.outdir, rawOut.replace(/^\.?\//, ''))
        : isAbsolute(rawOut)
          ? rawOut
          : join(specsDir, rawOut)

      const written = writeOutputs(result, planOutputs(finalOut, spec.format as OutputFormat))
      for (const file of written) {
        results.push({ chart: spec.chart, out: file.path, ok: true })
        if (!opts.json) console.log(`✓ ${label} → ${file.path} (${file.bytes} bytes)`)
      }
    } catch (error) {
      failures += 1
      const message = (error as Error).message
      results.push({ chart: String(merged.chart ?? '?'), out: String(merged.out ?? ''), ok: false, error: message })
      if (!opts.json) console.error(`✗ ${label} → ${message}`)
      if (opts.stopOnError) break
    }
  }

  if (opts.json) {
    console.log(JSON.stringify({ ok: failures === 0, total: results.length, failed: failures, results }, null, 2))
  } else {
    const succeeded = results.filter((r) => r.ok).length
    console.log(`\n共 ${succeeded} 张成功${failures > 0 ? `，${failures} 张失败` : ''}`)
  }

  return failures === 0 ? 0 : 1
}
