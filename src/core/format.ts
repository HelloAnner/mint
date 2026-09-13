export type FormatPreset = 'number' | 'percent' | 'compact'

export interface FormatConfig {
  preset?: FormatPreset
  decimals?: number
  prefix?: string
  suffix?: string
}

/** 中文语境下的紧凑数字：1.2万 / 3.4亿。 */
export function compactNumber(value: number, decimals = 1): string {
  const abs = Math.abs(value)
  if (abs >= 1e8) return `${(value / 1e8).toFixed(decimals)}亿`
  if (abs >= 1e4) return `${(value / 1e4).toFixed(decimals)}万`
  return String(Math.round(value * 10 ** decimals) / 10 ** decimals)
}

export function makeFormatter(config: FormatConfig = {}): (value: number) => string {
  const { preset = 'number', decimals, prefix = '', suffix = '' } = config

  return (value: number) => {
    if (!Number.isFinite(value)) return '—'
    let body: string
    switch (preset) {
      case 'percent':
        body = `${(value).toFixed(decimals ?? 1)}%`
        break
      case 'compact':
        body = compactNumber(value, decimals ?? 1)
        break
      default:
        body =
          decimals === undefined
            ? new Intl.NumberFormat('zh-CN').format(value)
            : value.toFixed(decimals)
    }
    return `${prefix}${body}${suffix}`
  }
}
