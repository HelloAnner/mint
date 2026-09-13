import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, extname, join, resolve } from 'node:path'
import type { OutputFormat } from './spec'
import type { RenderResult } from './render'

export interface OutputPlan {
  png?: string
  svg?: string
}

function withExtension(path: string, ext: '.png' | '.svg'): string {
  const current = extname(path).toLowerCase()
  if (current === ext) return path
  if (current === '.png' || current === '.svg') return path.slice(0, -current.length) + ext
  return path + ext
}

/** 根据输出格式决定真正要写哪些文件。 */
export function planOutputs(target: string, format: OutputFormat): OutputPlan {
  const absolute = resolve(target)
  if (format === 'png') return { png: withExtension(absolute, '.png') }
  if (format === 'svg') return { svg: withExtension(absolute, '.svg') }
  const base = absolute.replace(/\.(png|svg)$/i, '')
  return { png: base + '.png', svg: base + '.svg' }
}

export interface WrittenFile {
  path: string
  format: 'png' | 'svg'
  bytes: number
}

export function writeOutputs(result: RenderResult, plan: OutputPlan): WrittenFile[] {
  const written: WrittenFile[] = []

  if (plan.png && result.png) {
    mkdirSync(dirname(plan.png), { recursive: true })
    writeFileSync(plan.png, result.png)
    written.push({ path: plan.png, format: 'png', bytes: result.png.byteLength })
  }

  if (plan.svg) {
    mkdirSync(dirname(plan.svg), { recursive: true })
    writeFileSync(plan.svg, result.svg, 'utf8')
    written.push({ path: plan.svg, format: 'svg', bytes: Buffer.byteLength(result.svg, 'utf8') })
  }

  return written
}

/** 没写 -o 时的默认输出名。 */
export function defaultOutput(chartId: string, format: OutputFormat): string {
  if (format === 'svg') return join(process.cwd(), `${chartId}.svg`)
  return join(process.cwd(), `${chartId}.png`)
}
