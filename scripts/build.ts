/**
 * 编译单文件二进制：bun build --compile --minify。
 * skill 内容与 resvg 的 wasm 都通过 file 导入被 bun 打进二进制，产物可以单独分发。
 */
import { mkdirSync, rmSync, statSync } from 'node:fs'
import { join } from 'node:path'

const REPO = join(import.meta.dir, '..')
const OUT_DIR = join(REPO, 'dist')

// 先确保 skill 文档与内嵌清单是最新的
const embed = Bun.spawnSync({ cmd: ['bun', 'run', join(REPO, 'scripts', 'embed.ts')], stdout: 'inherit', stderr: 'inherit' })
if (embed.exitCode !== 0) {
  console.error('生成内嵌 skill 失败')
  process.exit(1)
}

// 版本号一致性
const pkg = (await Bun.file(join(REPO, 'package.json')).json()) as { version: string }
const versionSource = await Bun.file(join(REPO, 'src', 'version.ts')).text()
if (!versionSource.includes(`'${pkg.version}'`)) {
  console.error(`src/version.ts 与 package.json 的版本不一致（package.json 是 ${pkg.version}）`)
  process.exit(1)
}

rmSync(OUT_DIR, { recursive: true, force: true })
mkdirSync(OUT_DIR, { recursive: true })

const target = join(OUT_DIR, 'mint')
const build = Bun.spawnSync({
  cmd: [
    'bun',
    'build',
    '--compile',
    '--minify',
    '--outfile',
    target,
    join(REPO, 'src', 'cli.ts'),
  ],
  stdout: 'inherit',
  stderr: 'inherit',
  cwd: REPO,
})

if (build.exitCode !== 0) {
  console.error('编译失败')
  process.exit(1)
}

const size = statSync(target).size
console.log(`\n✓ 构建完成：${target}`)
console.log(`  体积 ${(size / 1024 / 1024).toFixed(1)} MB`)
console.log('  自检：' + target + ' doctor')
