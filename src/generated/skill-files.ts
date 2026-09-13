// 本文件由 scripts/embed.ts 自动生成，请勿手改。
// 这些 import 会被 bun build --compile 一并打进二进制，运行时用 Bun.file() 读取。

import skillFile0 from '../../skills/mint/SKILL.md' with { type: 'file' }
import skillFile1 from '../../skills/mint/references/charts.md' with { type: 'file' }
import skillFile2 from '../../skills/mint/references/recipes.md' with { type: 'file' }
import skillFile3 from '../../skills/mint/references/spec.md' with { type: 'file' }

export interface EmbeddedSkillFile {
  /** 相对 skill 根目录的路径 */
  path: string
  /** 运行时可直接读取的文件引用 */
  file: string
}

export const SKILL_FILES: readonly EmbeddedSkillFile[] = [
  { path: 'SKILL.md', file: skillFile0 },
  { path: 'references/charts.md', file: skillFile1 },
  { path: 'references/recipes.md', file: skillFile2 },
  { path: 'references/spec.md', file: skillFile3 },
]
