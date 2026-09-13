# mint

**把数据变成美观的图表。** 一条命令，把一份 JSON 渲染成可以直接嵌进报告的成品图。

```bash
mint render bar --data revenue.json --title "各区域季度营收" --subtitle "单位：百万元" -o revenue.png
```

mint 是给 AI 和工程师用的图表 CLI：内置 20 种经过端到端测试的图表、7 套调色板、
明暗两套主题，中文标签开箱可用。所有图表由 [nivo](https://github.com/plouc/nivo) 在服务端
渲染成 SVG，再由 [resvg](https://github.com/RazrFalcon/resvg) 光栅化为 PNG —— **不依赖浏览器**，
单张图通常 100ms 内完成。

## 预览

下面都是 `mint render <chart>` 用内置示例数据直接产出的原图（可点开看大图）：

| | |
|---|---|
| [![柱状图](docs/images/bar.png)](docs/images/bar.png) | [![折线图](docs/images/line.png)](docs/images/line.png) |
| [![环形图](docs/images/pie.png)](docs/images/pie.png) | [![矩形树图](docs/images/treemap.png)](docs/images/treemap.png) |
| [![日历热力图](docs/images/calendar.png)](docs/images/calendar.png) | [![桑基图](docs/images/sankey.png)](docs/images/sankey.png) |

想自己生成全部 20 张：`make examples`，产物在 `out/examples/`。

## 为什么是 mint

| | |
|---|---|
| **不用写代码** | 传 JSON 就出图，不需要起 React 工程、不需要配构建 |
| **不依赖浏览器** | 渲染是纯 JS + WASM，没有 Playwright/Puppeteer 那几百 MB 的负担 |
| **产物是成品** | 自动排版标题、副标题、脚注与留白，不是裸图 |
| **AI 友好** | 内置 skill，AI 助手装上就知道有哪些图、怎么传数据 |
| **单文件分发** | `bun build --compile` 打成一个二进制，skill 内容一起内嵌 |

## 安装

```bash
git clone <repo> && cd mint

make install          # 编译 CLI 到 ~/.local/bin，并把 skill 软链到 ~/.agents/skills/mint
make install PREFIX=/usr/local   # 自定义安装位置
```

也可以只用源码跑，不安装：

```bash
bun install
bun run src/cli.ts doctor
```

### 安装都做了什么

1. **CLI**：`bun build --compile` 产出单文件二进制 `dist/mint`，拷到 `$(PREFIX)/bin/mint`。
2. **Skill**：把仓库里的 `skills/mint` 软链到 `~/.agents/skills/mint`，
   这是各类 AI 助手约定的 skill 目录。

此外，**每次运行 `mint` 都会检查 skill 是否已安装，没有就自动装上**（软链）。
不想自动安装可以设 `MINT_NO_AUTO_SKILL=1`。

## 快速开始

```bash
mint list                 # 20 种图表一览
mint info bar             # 数据结构、选项、可运行示例
mint render bar -o out.png                 # 不传数据就用内置示例，先看效果
mint render bar --data revenue.json -o out.png
mint palettes             # 7 套调色板
mint doctor               # 自检：字体、光栅化、skill
```

## 图表

| 分类 | 图表 |
|------|------|
| 比较 | `bar` 柱状图 · `radar` 雷达图 · `radial-bar` 径向条形图 · `bullet` 子弹图 |
| 趋势 | `line` 折线图 · `stream` 堆叠面积图 · `bump` 排名变化图 |
| 构成 | `pie` 环形/饼图 · `waffle` 华夫图 · `marimekko` 马赛克图 |
| 关系 | `scatter` 散点/气泡图 · `parallel-coordinates` 平行坐标图 |
| 分布 | `heatmap` 热力图 · `calendar` 日历热力图 |
| 层级 | `treemap` 矩形树图 · `sunburst` 旭日图 · `icicle` 冰柱图 · `circle-packing` 圆形打包图 |
| 流向 | `funnel` 漏斗图 · `sankey` 桑基图 |

每张图都支持多种形态（如 `bar` 支持分组/堆叠/横向，`pie` 支持实心/环形，
`bump` 支持折线/面积），完整清单与数据结构见 [skills/mint/references/charts.md](skills/mint/references/charts.md)，
或直接跑 `mint list` / `mint info <chart>`。

## 数据格式

**大多数情况一个数组就够了**，mint 会自动判断哪列是分类、哪列是数值：

```json
[
  { "quarter": "Q1", "华东": 128, "华北": 96 },
  { "quarter": "Q2", "华东": 152, "华北": 108 }
]
```

也直接吃这些常见形状：

```jsonc
{ "搜索": 348, "社交": 266 }                        // 占比类
[{ "id": "Web", "data": [{ "x": "1月", "y": 42 }] }]  // 折线类
[{ "x": "1月", "y": 42, "channel": "Web" }]           // 扁平记录，自动分组
{ "name": "总计", "children": [{ "name": "华东", "value": 320 }] }   // 层级类
[{ "path": "线上/华东/上海", "value": 120 }]           // 斜杠路径自动建树
{ "links": [{ "source": "搜索", "target": "注册", "value": 320 }] }  // 流向类
```

## 命令

```
mint render <chart> [options]     渲染一张图
mint batch <spec.json>            按 spec 批量渲染
mint list                         列出全部图表
mint info <chart>                 数据结构、选项与示例
mint palettes                     列出调色板
mint doctor                       环境自检
mint install skill                安装 skill 软链
mint uninstall skill              移除 skill 软链
mint skill [status|path|list|show]  查看 skill 状态
```

渲染参数：

| 参数 | 说明 | 默认 |
|------|------|------|
| `-d, --data <file\|->` | 数据 JSON，`-` 表示 stdin | 内置示例数据 |
| `-o, --out <file>` | 输出路径，`-` 写到 stdout | `./<chart>.png` |
| `-t, --title` / `-s, --subtitle` / `--footnote` | 标题与脚注 | 无 |
| `-W, --width` / `-H, --height` | 逻辑尺寸 | 1280 × 760 |
| `--scale` | 像素倍数 | 2 |
| `--theme` | `light` / `dark` | light |
| `--palette` | 调色板 id | mint |
| `--format` | `png` / `svg` / `both` | png |
| `--set k=v` | 图表选项，可重复 | — |
| `--options '<json>'` | 选项 JSON | — |
| `--font <path>` | 指定字体（.ttf/.otf/.ttc） | 自动探测 |
| `--json` | 输出机器可读结果 | — |

退出码：`0` 成功，`1` 运行失败，`2` 用法错误。

## 批量出图

```jsonc
{
  "defaults": { "palette": "indigo", "width": 1280, "height": 760, "scale": 2 },
  "charts": [
    { "chart": "bar",    "dataFile": "revenue.json", "out": "out/01-revenue.png",
      "title": "各区域季度营收" },
    { "chart": "line",   "dataFile": "dau.json",     "out": "out/02-dau.png",
      "title": "日活趋势", "options": { "area": true } },
    { "chart": "pie",    "data": { "搜索": 348, "社交": 266 }, "out": "out/03-channel.png" }
  ]
}
```

```bash
mint batch report.json
```

`dataFile` 相对 spec 文件解析；某项失败不会中断其余渲染，最后统一汇总。

## 主题与调色板

`--theme` 只管明暗，`--palette` 管色彩倾向，两者正交组合。

| id | 名称 | 适用 |
|----|------|------|
| `mint` | 薄荷 | 默认，增长与产品类数据 |
| `indigo` | 靛蓝 | 商务报告与汇报 |
| `sunset` | 日落 | 营销与创意主题 |
| `ocean` | 海洋 | 流量、渠道与地理数据 |
| `forest` | 森林 | 生态、健康与可持续 |
| `candy` | 糖果 | 面向大众的轻量内容 |
| `mono` | 单色 | 黑白印刷与极简报告 |

热力图、日历图这类顺序色阶会自动从调色板主色派生出由浅到深的阶梯，保证同一主题下视觉一致。

## 架构

```
JSON 数据 ──▶ 数据归一化 ──▶ nivo 组件 ──▶ React SSR ──▶ SVG ──▶ 卡片排版 ──▶ resvg-wasm ──▶ PNG
                helpers.ts      charts/*.tsx   render.ts           frame.ts     raster.ts
```

关键设计取舍：

- **React 服务端渲染而不是无头浏览器**：nivo 的几何计算发生在 render 期间，
  因此 `renderToStaticMarkup` 就能拿到完整的 SVG，不需要真实 DOM。
  所有图表统一传 `animate={false}`，避免 react-spring 在服务端留下初始态。
- **resvg-wasm 而不是 sharp/canvas**：WASM 没有原生依赖，既方便本地安装，
  也能被 `bun build --compile` 直接打进单文件二进制。
- **卡片排版在 SVG 层做**：nivo 只负责绘图区，标题、副标题、脚注、留白由 `frame.ts`
  统一处理，因此 20 张图的排版规范完全一致。
- **字体从系统探测**：resvg 不自带字体，mint 会按平台候选列表（PingFang / 冬青黑 /
  思源黑体 / 文泉驿…）挑一个支持中文的，找不到时回落到 fontconfig。

### 目录

```
src/
  cli.ts                 入口与命令分发
  commands/              render / batch / list / skill / doctor
  cli/                   参数解析、选项解析
  core/
    render.ts            渲染管线
    frame.ts             标题卡片排版
    raster.ts            resvg-wasm 光栅化
    fonts.ts             字体探测
    palettes.ts          调色板与主题
    registry.ts          图表注册表
    skills.ts            skill 安装与自检
    spec.ts / output.ts  输入校验与输出路径
  charts/                20 个图表定义
  generated/             由 scripts/embed.ts 生成（内嵌文件清单）
skills/mint/             skill 内容（SKILL.md + references）
scripts/                 embed（生成文档与内嵌清单）、build（编译）、examples
tests/                   51 项测试，含每张图的端到端渲染
```

## Skill 机制

`~/.agents/skills/mint` 是各类 AI 助手约定的 skill 目录，mint 通过软链接入：

- **源码模式**：软链指向仓库的 `skills/mint`，改 `SKILL.md` 立即生效。
- **二进制模式**：编译时 skill 内容已内嵌进二进制，运行时释放到
  `~/.mint/skills/mint` 再软链过去，因此单独分发二进制也能用。

```bash
mint skill status     # 当前状态、来源模式、内嵌文件数
mint skill path       # 实际生效的 skill 目录
mint skill show       # 打印 SKILL.md 内容
```

skill 里还写死了一条工作纪律：**生成过程中的临时文件（数据 JSON、batch spec、预览图、
调试用 SVG）必须在交付前全部删除，只保留最终的图片文件**。mint 自身只写 `-o` 指定的那一个
路径，不产生任何中间文件，所以只要输入侧不发散，收工时目录就是干净的。

## 开发

```bash
make dev           # 用源码跑 CLI
make test          # 51 项测试（含每张图的端到端渲染）
make typecheck     # tsc --noEmit
make examples      # 把每张图的示例渲染到 out/examples
make build         # 编译单文件二进制
make check         # typecheck + test + build
```

新增一张图表只需要：

1. 在 `src/charts/` 加一个文件，导出一个 `ChartDefinition`（含 `example`）；
2. 在 `src/charts/index.ts` 注册；
3. `make test` —— 端到端测试会自动覆盖它，`charts.md` 也会在构建时自动重新生成。

## 环境变量

| 变量 | 作用 |
|------|------|
| `MINT_FONT` | 指定字体文件路径 |
| `MINT_NO_AUTO_SKILL=1` | 关闭启动时的 skill 自动安装 |
| `MINT_SKILLS_DIR` | 覆盖 skills 根目录（默认 `~/.agents/skills`） |
| `MINT_DEBUG=1` | 打印 React 渲染告警与错误堆栈 |
| `MINT_QUIET=1` | 静默模式 |

## License

MIT
