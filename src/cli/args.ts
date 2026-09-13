import { fail } from '../core/errors'

export type FlagType = 'string' | 'number' | 'boolean' | 'list'

export interface FlagSpec {
  name: string
  alias?: string
  type: FlagType
  description: string
  placeholder?: string
}

export interface ParsedArgs {
  positionals: string[]
  values: Record<string, string | number | boolean | string[] | undefined>
}

function findSpec(specs: FlagSpec[], token: string): FlagSpec | undefined {
  const name = token.replace(/^--?/, '')
  return specs.find((s) => s.name === name || (s.alias && s.alias === name))
}

/** 极简参数解析：支持 --flag value、--flag=value、-f value，以及重复出现的 list 参数。 */
export function parseArgs(argv: string[], specs: FlagSpec[]): ParsedArgs {
  const values: ParsedArgs['values'] = {}
  const positionals: string[] = []

  let index = 0
  while (index < argv.length) {
    const token = argv[index]!

    if (token === '--') {
      positionals.push(...argv.slice(index + 1))
      break
    }

    if (token.startsWith('-') && token !== '-') {
      const eq = token.indexOf('=')
      const rawKey = eq === -1 ? token : token.slice(0, eq)
      const inlineValue = eq === -1 ? undefined : token.slice(eq + 1)
      const spec = findSpec(specs, rawKey)

      if (!spec) {
        fail('UNKNOWN_FLAG', `未知参数 ${rawKey}`, '用 mint help 查看全部参数')
      }

      if (spec.type === 'boolean') {
        values[spec.name] = inlineValue === undefined ? true : inlineValue !== 'false'
        index += 1
        continue
      }

      const raw = inlineValue ?? argv[index + 1]
      if (raw === undefined) {
        fail('MISSING_VALUE', `参数 ${rawKey} 需要一个值`)
      }
      if (inlineValue === undefined) index += 1

      switch (spec.type) {
        case 'number': {
          const n = Number(raw)
          if (!Number.isFinite(n)) fail('INVALID_VALUE', `参数 ${rawKey} 需要数字，收到 ${raw}`)
          values[spec.name] = n
          break
        }
        case 'list': {
          const list = (values[spec.name] as string[] | undefined) ?? []
          list.push(raw)
          values[spec.name] = list
          break
        }
        default:
          values[spec.name] = raw
      }

      index += 1
      continue
    }

    positionals.push(token)
    index += 1
  }

  return { positionals, values }
}

export function stringValue(parsed: ParsedArgs, name: string): string | undefined {
  const value = parsed.values[name]
  return typeof value === 'string' ? value : undefined
}

export function numberValue(parsed: ParsedArgs, name: string): number | undefined {
  const value = parsed.values[name]
  return typeof value === 'number' ? value : undefined
}

export function booleanValue(parsed: ParsedArgs, name: string): boolean {
  return parsed.values[name] === true
}

export function listValue(parsed: ParsedArgs, name: string): string[] {
  const value = parsed.values[name]
  return Array.isArray(value) ? value : []
}

export function renderFlagTable(specs: FlagSpec[]): string[] {
  const rows = specs.map((spec) => {
    const short = spec.alias ? `-${spec.alias}, ` : '    '
    const left = `  ${short}--${spec.name}${spec.placeholder ? ' ' + spec.placeholder : ''}`
    return [left, spec.description] as [string, string]
  })
  const width = Math.max(...rows.map(([left]) => left.length), 0) + 2
  return rows.map(([left, right]) => left.padEnd(width) + right)
}
