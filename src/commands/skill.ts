import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fail } from '../core/errors'
import {
  SKILL_NAME,
  agentsSkillsRoot,
  embeddedSkillFiles,
  installSkill,
  materializedSkillDir,
  repoSkillDir,
  skillLinkPath,
  skillStatus,
  uninstallSkill,
} from '../core/skills'
import { booleanValue, parseArgs, type FlagSpec } from '../cli/args'

const INSTALL_FLAGS: FlagSpec[] = [
  { name: 'force', alias: 'f', type: 'boolean', description: '覆盖已存在的安装' },
  { name: 'json', type: 'boolean', description: '输出 JSON' },
]

export async function runInstallSkill(argv: string[]): Promise<number> {
  const parsed = parseArgs(argv, INSTALL_FLAGS)
  const what = parsed.positionals[0]

  if (what !== 'skill') {
    fail('MISSING_ARGUMENT', '目前只支持 mint install skill', '用法：mint install skill [--force]')
  }

  const result = await installSkill({ force: booleanValue(parsed, 'force') })

  if (booleanValue(parsed, 'json')) {
    console.log(JSON.stringify({ ok: true, action: 'install', ...result }, null, 2))
    return 0
  }

  if (result.replaced) console.log(`已覆盖原有安装：${result.path}`)
  else if (result.files === 0) console.log(`已经安装过了：${result.path}`)
  else console.log(`已安装：${result.path}`)

  console.log(`  → ${result.target}`)
  if (result.mode === 'repo') {
    console.log('  模式：软链到仓库源码目录（改动 SKILL.md 立即生效）')
  } else {
    console.log(`  模式：二进制内嵌内容已释放到磁盘（${result.files} 个文件）`)
  }
  return 0
}

export async function runUninstallSkill(argv: string[]): Promise<number> {
  const parsed = parseArgs(argv, INSTALL_FLAGS)
  const what = parsed.positionals[0]

  if (what !== 'skill') {
    fail('MISSING_ARGUMENT', '目前只支持 mint uninstall skill')
  }

  const result = uninstallSkill()

  if (booleanValue(parsed, 'json')) {
    console.log(JSON.stringify({ ok: true, action: 'uninstall', ...result }, null, 2))
    return 0
  }

  if (result.removed) console.log(`已移除：${result.path}`)
  else console.log(`未移除：${result.path}${result.note ? `（${result.note}）` : ''}`)
  return 0
}

const SKILL_FLAGS: FlagSpec[] = [{ name: 'json', type: 'boolean', description: '输出 JSON' }]

export function runSkillCommand(argv: string[]): number {
  const parsed = parseArgs(argv, SKILL_FLAGS)
  const sub = parsed.positionals[0] ?? 'status'

  switch (sub) {
    case 'path': {
      const status = skillStatus()
      console.log(status.installed ? (status.target ?? status.path) : status.path)
      return status.installed ? 0 : 1
    }
    case 'list': {
      if (booleanValue(parsed, 'json')) {
        console.log(JSON.stringify(embeddedSkillFiles(), null, 2))
        return 0
      }
      console.log(`内嵌 skill 文件（${SKILL_NAME}）：`)
      for (const file of embeddedSkillFiles()) console.log(`  ${file}`)
      return 0
    }
    case 'show': {
      const target = parsed.positionals[1] ?? 'SKILL.md'
      const repo = repoSkillDir()
      const base = repo ?? materializedSkillDir()
      const file = join(base, target)
      try {
        process.stdout.write(readFileSync(file, 'utf8'))
      } catch {
        fail('FILE_NOT_FOUND', `读不到 ${target}`, `可用文件：${embeddedSkillFiles().join(', ')}`)
      }
      return 0
    }
    default: {
      const status = skillStatus()
      if (booleanValue(parsed, 'json')) {
        console.log(JSON.stringify({ ...status, embeddedFiles: embeddedSkillFiles(), repoDir: repoSkillDir() ?? null }, null, 2))
        return 0
      }
      console.log(`mint skill 状态`)
      console.log(`  约定目录　${agentsSkillsRoot()}`)
      console.log(`  安装路径　${skillLinkPath()}`)
      console.log(`  已安装　　${status.installed ? '是' : '否'}`)
      if (status.target) console.log(`  指向　　　${status.target}`)
      console.log(`  来源模式　${repoSkillDir() ? '源码目录软链' : '二进制内嵌内容'}`)
      console.log(`  内嵌文件　${embeddedSkillFiles().length} 个`)
      return 0
    }
  }
}
