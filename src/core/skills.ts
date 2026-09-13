import {
  existsSync,
  lstatSync,
  mkdirSync,
  readlinkSync,
  rmSync,
  symlinkSync,
  writeFileSync,
  readdirSync,
  statSync,
} from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { SKILL_FILES } from '../generated/skill-files'
import { fail } from './errors'

export const SKILL_NAME = 'mint'

/** 遵循 ~/.agents/skills/<name> 的通用约定 */
export function agentsSkillsRoot(): string {
  return process.env.MINT_SKILLS_DIR ?? join(homedir(), '.agents', 'skills')
}

export function skillLinkPath(): string {
  return join(agentsSkillsRoot(), SKILL_NAME)
}

/**
 * 源码模式：从仓库直接运行时，skill 就在仓库里，软链过去即可，
 * 这样改 SKILL.md 会立即生效，不需要重新安装。
 */
export function repoSkillDir(): string | undefined {
  const candidate = resolve(import.meta.dir, '..', '..', 'skills', SKILL_NAME)
  return existsSync(join(candidate, 'SKILL.md')) ? candidate : undefined
}

/** 编译成二进制后没有源码目录，把内嵌内容释放到这里。 */
export function materializedSkillDir(): string {
  return join(homedir(), '.mint', 'skills', SKILL_NAME)
}

function lstatSafe(path: string) {
  try {
    return lstatSync(path)
  } catch {
    return undefined
  }
}

function countFiles(dir: string): number {
  let count = 0
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry)
    count += statSync(full).isDirectory() ? countFiles(full) : 1
  }
  return count
}

/** 把内嵌的 skill 文件写到磁盘上。 */
export async function materializeEmbedded(dest: string): Promise<number> {
  let count = 0
  for (const entry of SKILL_FILES) {
    const target = join(dest, entry.path)
    mkdirSync(dirname(target), { recursive: true })
    writeFileSync(target, await Bun.file(entry.file).text(), 'utf8')
    count += 1
  }
  return count
}

export type SkillMode = 'repo' | 'embedded' | 'missing'

export interface SkillStatus {
  /** ~/.agents/skills/mint 是否存在且可用 */
  installed: boolean
  /** 软链或目录本身 */
  path: string
  /** 软链指向的真实目录 */
  target?: string
  mode: SkillMode
  /** 是否是我们管理的软链 */
  managed: boolean
}

export function skillStatus(): SkillStatus {
  const path = skillLinkPath()
  const stat = lstatSafe(path)

  if (!stat) {
    return { installed: false, path, mode: 'missing', managed: false }
  }

  if (stat.isSymbolicLink()) {
    const target = readlinkSync(path)
    const alive = existsSync(target)
    const isRepo = repoSkillDir() === target
    return {
      installed: alive,
      path,
      target,
      mode: alive ? (isRepo ? 'repo' : 'embedded') : 'missing',
      managed: true,
    }
  }

  // 真实目录（例如手动拷贝安装的），也认为装好了，但不归我们管理
  return {
    installed: existsSync(join(path, 'SKILL.md')),
    path,
    target: path,
    mode: 'missing',
    managed: false,
  }
}

export interface InstallResult {
  path: string
  target: string
  mode: 'repo' | 'embedded'
  files: number
  /** 是否覆盖了原有安装 */
  replaced: boolean
}

export async function installSkill(options: { force?: boolean } = {}): Promise<InstallResult> {
  const linkPath = skillLinkPath()
  const root = agentsSkillsRoot()

  const existing = lstatSafe(linkPath)
  if (existing && !options.force) {
    const status = skillStatus()
    if (status.installed && status.managed) {
      return {
        path: linkPath,
        target: status.target ?? linkPath,
        mode: status.mode === 'repo' ? 'repo' : 'embedded',
        files: 0,
        replaced: false,
      }
    }
    fail(
      'SKILL_EXISTS',
      `${linkPath} 已存在且不是 mint 管理的安装`,
      '确认可以覆盖后加 --force',
    )
  }

  mkdirSync(root, { recursive: true })
  if (existing) rmSync(linkPath, { recursive: true, force: true })

  const repo = repoSkillDir()
  if (repo) {
    symlinkSync(repo, linkPath, 'dir')
    return { path: linkPath, target: repo, mode: 'repo', files: countFiles(repo), replaced: Boolean(existing) }
  }

  const dest = materializedSkillDir()
  rmSync(dest, { recursive: true, force: true })
  const files = await materializeEmbedded(dest)
  symlinkSync(dest, linkPath, 'dir')
  return { path: linkPath, target: dest, mode: 'embedded', files, replaced: Boolean(existing) }
}

export interface UninstallResult {
  path: string
  removed: boolean
  note?: string
}

export function uninstallSkill(): UninstallResult {
  const path = skillLinkPath()
  const status = skillStatus()

  if (!lstatSafe(path)) return { path, removed: false, note: '本来就没有安装' }

  if (status.managed) {
    rmSync(path, { recursive: true, force: true })
    return { path, removed: true }
  }

  return { path, removed: false, note: '该目录不是 mint 管理的软链，未删除' }
}

export interface EnsureResult {
  action: 'ok' | 'installed' | 'skipped'
  path: string
  target?: string
}

/**
 * 每次运行 mint 时顺手确认 skill 已安装。
 * 静默失败：skill 没装上不该阻断出图这个主流程。
 */
export async function ensureSkill(): Promise<EnsureResult> {
  const path = skillLinkPath()

  if (process.env.MINT_NO_AUTO_SKILL === '1') {
    return { action: 'skipped', path }
  }

  try {
    if (skillStatus().installed) return { action: 'ok', path }
    const result = await installSkill({ force: true })
    return { action: 'installed', path: result.path, target: result.target }
  } catch {
    return { action: 'skipped', path }
  }
}

/** 供 doctor 使用：列出内嵌 skill 的文件清单。 */
export function embeddedSkillFiles(): readonly string[] {
  return SKILL_FILES.map((f) => f.path)
}
