import { readFileSync } from 'node:fs'
import { fail } from '../core/errors'

/** 把 --set 的字符串值按字面量还原成 boolean / number / 数组 / 对象。 */
export function coerceOptionValue(raw: string): unknown {
  const text = raw.trim()
  if (text === 'true') return true
  if (text === 'false') return false
  if (text === 'null') return null
  if (/^-?\d+(\.\d+)?$/.test(text)) return Number(text)
  if (text.startsWith('[') || text.startsWith('{')) {
    try {
      return JSON.parse(text)
    } catch {
      return raw
    }
  }
  return raw
}

/** 解析可重复的 --set key=value。 */
export function parseSetFlags(entries: string[]): Record<string, unknown> {
  const options: Record<string, unknown> = {}
  for (const entry of entries) {
    const eq = entry.indexOf('=')
    if (eq <= 0) {
      fail('INVALID_VALUE', `--set 需要 key=value 形式，收到「${entry}」`, '例如 --set groupMode=stacked')
    }
    const key = entry.slice(0, eq).trim()
    options[key] = coerceOptionValue(entry.slice(eq + 1))
  }
  return options
}

export function parseOptionsJson(raw: string | undefined): Record<string, unknown> {
  if (!raw) return {}
  try {
    const parsed = JSON.parse(raw)
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      fail('INVALID_VALUE', '--options 需要是一个 JSON 对象')
    }
    return parsed as Record<string, unknown>
  } catch (error) {
    if (error instanceof SyntaxError) {
      fail('INVALID_VALUE', `--options 不是合法 JSON：${error.message}`)
    }
    throw error
  }
}

/** 读取 --data 指定的数据：支持文件路径与 "-"（stdin）。 */
export async function loadData(source: string | undefined): Promise<{ data: unknown; from: string } | undefined> {
  if (!source) return undefined

  let text: string
  let from: string

  if (source === '-') {
    text = await new Response(Bun.stdin.stream()).text()
    from = '<stdin>'
  } else {
    try {
      text = readFileSync(source, 'utf8')
    } catch {
      fail('DATA_NOT_FOUND', `读不到数据文件：${source}`)
    }
    from = source
  }

  if (text.trim() === '') {
    fail('INVALID_DATA', `${from} 是空的`)
  }

  try {
    return { data: JSON.parse(text), from }
  } catch (error) {
    fail(
      'INVALID_DATA',
      `${from} 不是合法 JSON：${(error as Error).message}`,
      'mint 目前只接受 JSON；CSV 请先转成 JSON 数组',
    )
  }
}
