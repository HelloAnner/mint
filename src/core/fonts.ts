import { existsSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { fail } from './errors'

export interface FontChoice {
  /** 字体文件绝对路径 */
  path: string
  /** 字体内注册的家族名，用于 SVG font-family 与 resvg 匹配 */
  family: string
  /** 来源说明 */
  source: string
}

interface Candidate {
  path: string
  family: string
}

/** macOS 常见中文字体，按优先级排列。 */
const DARWIN_CANDIDATES: Candidate[] = [
  { path: '/System/Library/Fonts/PingFang.ttc', family: 'PingFang SC' },
  { path: '/System/Library/Fonts/Hiragino Sans GB.ttc', family: 'Hiragino Sans GB' },
  { path: '/System/Library/Fonts/STHeiti Medium.ttc', family: 'Heiti SC' },
  { path: '/System/Library/Fonts/Supplemental/Songti.ttc', family: 'Songti SC' },
  { path: '/Library/Fonts/Arial Unicode.ttf', family: 'Arial Unicode MS' },
  { path: '/System/Library/Fonts/Helvetica.ttc', family: 'Helvetica' },
]

/** Linux 常见中文字体。 */
const LINUX_CANDIDATES: Candidate[] = [
  { path: '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc', family: 'Noto Sans CJK SC' },
  { path: '/usr/share/fonts/opentype/noto/NotoSansCJKsc-Regular.otf', family: 'Noto Sans CJK SC' },
  { path: '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc', family: 'Noto Sans CJK SC' },
  { path: '/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc', family: 'Noto Sans CJK SC' },
  { path: '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc', family: 'WenQuanYi Micro Hei' },
  { path: '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc', family: 'WenQuanYi Zen Hei' },
  { path: '/usr/share/fonts/truetype/arphic/uming.ttc', family: 'AR PL UMing CN' },
  { path: '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', family: 'DejaVu Sans' },
]

/**
 * macOS 上 PingFang 常被系统以资源包形式下发，路径带 hash，
 * 因此额外扫描 AssetsV2 目录。
 */
function findPingFangInAssets(): string | undefined {
  const base = '/System/Library/AssetsV2/com_apple_MobileAsset_Font7'
  if (!existsSync(base)) return undefined
  try {
    for (const entry of readdirSync(base)) {
      const candidate = join(base, entry, 'AssetData', 'PingFang.ttc')
      if (existsSync(candidate)) return candidate
    }
  } catch {
    /* 忽略权限等问题 */
  }
  return undefined
}

/** 通过 fontconfig 兜底查找一个支持中文的字体。 */
function findByFontconfig(): FontChoice | undefined {
  try {
    const proc = Bun.spawnSync({
      cmd: ['sh', '-c', "fc-list :lang=zh file family 2>/dev/null | head -1"],
      stdout: 'pipe',
      stderr: 'ignore',
    })
    const line = proc.stdout.toString().trim()
    if (!line) return undefined
    const [rawPath, ...rest] = line.split(':')
    const path = rawPath?.trim()
    const family = rest.join(':').split(',')[0]?.trim()
    if (!path || !existsSync(path)) return undefined
    return { path, family: family || 'sans-serif', source: 'fontconfig' }
  } catch {
    return undefined
  }
}

/**
 * 解析要使用的字体。
 * 优先级：显式指定 > 内置候选列表 > fontconfig 探测。
 */
export function resolveFont(explicit?: string): FontChoice {
  if (explicit) {
    if (!existsSync(explicit)) {
      fail('FONT_NOT_FOUND', `字体文件不存在：${explicit}`, '用 --font <path> 指定一个 .ttf/.otf/.ttc 文件')
    }
    return { path: explicit, family: 'sans-serif', source: 'explicit' }
  }

  const envFont = process.env.MINT_FONT
  if (envFont) return resolveFont(envFont)

  const candidates = process.platform === 'darwin' ? DARWIN_CANDIDATES : LINUX_CANDIDATES
  for (const c of candidates) {
    if (existsSync(c.path)) return { ...c, source: 'builtin' }
  }

  if (process.platform === 'darwin') {
    const pingfang = findPingFangInAssets()
    if (pingfang) return { path: pingfang, family: 'PingFang SC', source: 'assets' }
  }

  const fc = findByFontconfig()
  if (fc) return fc

  fail(
    'FONT_NOT_FOUND',
    '找不到可用的字体文件',
    '用 --font <path> 指定字体，或设置环境变量 MINT_FONT',
  )
}

export function listFontCandidates(): Candidate[] {
  const all = process.platform === 'darwin' ? DARWIN_CANDIDATES : LINUX_CANDIDATES
  return all.filter((c) => existsSync(c.path))
}
