---
name: mint
description: 把数据变成美观的图表图片。当用户说"画个图""生成图表""做成柱状图/折线图/饼图""把这份数据可视化""给报告配张图""生成图表 PNG"时使用。通过 mint CLI 把 JSON/CSV 数据渲染成 PNG 或 SVG，内置 23 种经过测试的图表（含架构图、流程图、时序图）、7 套调色板与明暗两套主题，支持中文标签。核心命令是 `mint render <chart> --data data.json -o out.png`；不确定用哪种图表时先 `mint list`，需要数据结构说明时用 `mint info <chart>`。
---

# Mint — 数据到图表的 CLI

mint 把一份 JSON 数据渲染成一张带标题、副标题、脚注的成品图表（PNG 或 SVG）。
图表在服务端渲染成 SVG（绝大多数基于 nivo，`architecture` 架构图由 mint 自绘），
再由 resvg 光栅化为 PNG，不依赖浏览器，单张图通常 100ms 内完成。

## 核心原则

1. **先选对图，再谈美观**。图表类型选错，数据再准也读不出来。拿不准就先读
   [references/charts.md](references/charts.md) 里的「什么时候用」一列。
2. **先看数据结构，再决定 chart**。mint 会自动推断分类轴与数值系列，但显式传
   `indexBy` / `keys` 更稳。数据形状不知道怎么写时，用 `mint info <chart>` 看示例。
3. **不要一次画太多系列**。同一张图超过 6 个系列就该拆图或改用堆叠；饼图超过 6 个扇区
   建议换成柱状图或矩形树图。
4. **中文标题直接写在 spec 里**，不要在图上后期叠加文字。mint 自带中文字体探测。
5. **验证产出**：渲染完成后读一次生成的 PNG 再交付。图能生成不代表布局没问题
   （标签重叠、空图、坐标轴超出画布都可能在"成功"之后才发现）。
6. **临时文件必须清干净**。生成过程中写过的数据 JSON、batch spec、预览图、调试用的 SVG
   都算临时文件，交付前必须全部删除，**只保留最终要交付的图片**。能不走磁盘就别走
   （数据用 `--data -` 从 stdin 传），必须落盘就放进临时目录并保证异常退出也会清理。
   细则见下面「临时文件与清理」。

## 快速开始

```bash
# 1. 看有哪些图可用
mint list

# 2. 看某张图需要什么数据结构（会给出可直接运行的示例）
mint info bar

# 3. 用示例数据直接出一张图（不需要准备数据）
mint render bar -o demo.png

# 4. 用自己的数据出图
mint render bar --data revenue.json --title "各区域季度营收" --subtitle "单位：百万元" -o revenue.png
```

数据也可以从标准输入读：`cat data.json | mint render bar --data - -o out.png`。

## 临时文件与清理（硬性要求）

**mint 自身不产生任何临时文件**：它只写入 `-o` 指定的那一个路径。
所以只要管住自己喂给 mint 的输入，收工时目录就是干净的。

### 首选：干脆不落盘

数据用 stdin 传，连数据文件都不用建：

```bash
printf '%s' '[
  { "quarter": "Q1", "华东": 128, "华北": 96 },
  { "quarter": "Q2", "华东": 152, "华北": 108 }
]' | mint render bar --data - --title "各区域季度营收" --subtitle "单位：百万元" -o revenue.png
```

只想先看一眼效果时，输出到临时目录而不是工作区：

```bash
preview="$(mktemp -d)/preview.png"
mint render bar -o "$preview"     # 看完即可，不要留在项目目录里
```

### 必须落盘时：放进临时目录 + trap 兜底

数据量大、或要用 `mint batch` 时，把**所有输入**写进临时目录，并用 `trap` 保证
即使中途报错也会清理：

```bash
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 输入全部放 $tmp
cp data.json "$tmp/data.json"
cat > "$tmp/report.json" <<'JSON'
{
  "defaults": { "palette": "indigo", "scale": 2 },
  "charts": [
    { "chart": "bar", "dataFile": "data.json", "out": "out/01-revenue.png", "title": "各区域季度营收" }
  ]
}
JSON

mint batch "$tmp/report.json"     # out 指向真实交付目录，输入留在 $tmp
# 退出时 trap 自动删除 $tmp
```

关键点：

- **输出指向最终交付目录**（`./out/` 或用户指定的位置），**输入全放 `$tmp`**。
- 不要把中间文件丢在仓库根目录、当前目录或用户的笔记/文档目录里。
- 不要为了"保险"把数据文件留在旁边——用户没要的都不要留。
- 别用 `--format both`，它会额外写一个 SVG；只有明确需要矢量图时才输出 SVG。

### 交付前收尾清单

逐条确认，缺一不可：

- [ ] 自己写过的数据文件、spec 文件、预览图、调试 SVG **已全部删除**
- [ ] 只留下用户明确要的图片文件（默认就是 PNG）
- [ ] 临时目录已随 `trap` 清理，没有 `mktemp` 残留
- [ ] `ls -la` 检查过工作区，没有 `*.json` / `*.svg` / `*.tmp` / `*.log` 之类的新增残留
- [ ] 交付说明里只提最终图片的路径，不夹带中间文件

> 判断标准很简单：**把这次任务新增的文件列出来，除了图片，其它都应该已经不存在了。**

## 命令总览

| 命令 | 作用 |
|------|------|
| `mint list [--category trend] [--json]` | 列出全部图表 |
| `mint info <chart> [--json]` | 单张图的说明、数据结构、选项与完整示例 |
| `mint render <chart> [选项]` | 渲染一张图 |
| `mint batch <file.json>` | 一次渲染多张图 |
| `mint palettes` | 列出调色板 |
| `mint doctor` | 自检环境（字体、光栅化后端、skill 安装状态） |
| `mint install skill` | 把本 skill 软链到 `~/.agents/skills/mint` |
| `mint skill path` | 打印 skill 实际所在目录 |

`mint render` 常用参数：

| 参数 | 说明 | 默认 |
|------|------|------|
| `-d, --data <file\|->` | 数据文件，`-` 表示 stdin；省略则用该图的内置示例数据 | 示例数据 |
| `-o, --out <file>` | 输出路径 | `./<chart>.png` |
| `-t, --title <text>` | 主标题 | 无 |
| `-s, --subtitle <text>` | 副标题 | 无 |
| `--footnote <text>` | 左下角脚注（常用来写数据来源） | 无 |
| `-W, --width <n>` / `-H, --height <n>` | 逻辑尺寸 | 1280 × 760 |
| `--scale <n>` | 像素倍数，2 即 2x 高清 | 2 |
| `--theme <light\|dark>` | 主题 | light |
| `--palette <id>` | 调色板，见 `mint palettes` | mint |
| `--format <png\|svg\|both>` | 输出格式 | png |
| `--set key=value` | 设置图表选项，可重复 | — |
| `--options '<json>'` | 用 JSON 一次性传选项 | — |
| `--json` | 输出机器可读的结果 | — |

## 数据怎么写

**大多数情况只需要一个数组**，mint 会自己判断哪列是分类、哪列是数值：

```json
[
  { "quarter": "Q1", "华东": 128, "华北": 96 },
  { "quarter": "Q2", "华东": 152, "华北": 108 }
]
```

`mint render bar --data revenue.json --title "各区域季度营收"` 就能出图。

其他常见形状 mint 也能直接吃：

```jsonc
// 占比类：对象或键值对数组都行
{ "搜索": 348, "社交": 266 }              // → pie / waffle / funnel
[["搜索", 348], ["社交", 266]]

// 折线类：系列结构，或扁平记录自动分组
[{ "id": "Web", "data": [{ "x": "1月", "y": 42 }] }]
[{ "x": "1月", "y": 42, "channel": "Web" }]   // --set seriesBy=channel

// 层级类：嵌套，或用斜杠路径自动建树
{ "name": "总计", "children": [{ "name": "华东", "value": 320 }] }
[{ "path": "线上/华东/上海", "value": 120 }]   // → treemap / sunburst / icicle

// 流向类
{ "links": [{ "source": "搜索", "target": "注册", "value": 320 }] }  // → sankey

// 架构类：层 + 方块 + 箭头
{ "layers": [{ "name": "接入层", "nodes": [{ "id": "gateway", "label": "API 网关" }] }],
  "edges": [{ "from": "web", "to": "gateway" }] }                      // → architecture
```

数据是 CSV 时，先用任意方式转成 JSON 数组再喂给 mint。

## 选图速查

| 你想表达 | 用 | 备注 |
|---------|-----|------|
| 类别之间比大小 | `bar` | 横向用 `--set layout=horizontal` |
| 总量随时间变化 | `line` / `stream` | 看总量+结构变化用 `stream` |
| 各部分占比 | `pie` / `waffle` / `treemap` | 分类多、有层级用 `treemap` |
| 层级拆解 | `treemap` / `sunburst` / `icicle` | 要文字标签用 `icicle` |
| 转化/流失 | `funnel` | 逐级人数递减 |
| 来源到去向 | `sankey` | 带宽即数量 |
| 两个变量关系 | `scatter` | 第三个变量用气泡 |
| 二维强度分布 | `heatmap` | 时段×星期这类交叉 |
| 一年节律 | `calendar` | 类似 GitHub 贡献图 |
| 名次此消彼长 | `bump` | `--set variant=area` 换面积式 |
| 多项 KPI 达成 | `bullet` | 实际值/目标值/区间一体 |
| 多维度对照 | `radar` / `parallel-coordinates` | 维度 ≤ 8 用雷达 |
| 系统/服务架构 | `architecture` | 分层方块 + 依赖箭头，`--set direction=horizontal` 可横排 |

完整的图表清单与每张图的适用/不适用场景见 [references/charts.md](references/charts.md)。

## 常用配方

见 [references/recipes.md](references/recipes.md)，包括：
年度报告配图、埋点数据漏斗、渠道占比、季度对比、暗色主题用于深色 PPT 等。

## 主题与调色板

```bash
mint palettes                      # 查看全部调色板
mint render bar --theme dark --palette sunset -o out.png
```

主题只管明暗，调色板管色彩倾向。深色底用 `--theme dark`，
正式报告推荐 `--palette indigo`（稳），产品增长类推荐默认的 `mint`（清爽）。

## 自检与排错

```bash
mint doctor        # 字体、光栅化后端、skill 安装状态
MINT_DEBUG=1 mint render bar -o out.png   # 打印 React 层的渲染告警
```

- **中文显示成方框**：系统缺中文字体，用 `--font /path/to/font.ttc` 指定，或设置 `MINT_FONT`。
- **报 `CANVAS_TOO_SMALL`**：画布减去标题和留白后没地方画图了，调大 `--width` / `--height`。
- **报 `INVALID_DATA`**：数据结构不符合该图表要求，`mint info <chart>` 里有正确示例。
- **图出来了但不满意**：先 `mint info <chart>` 看有没有现成选项（比如 `legend`、`valueFormat`、
  `xLegend`），再考虑换图。

## 在报告里使用

- 生成 2x 图（默认）嵌入 Markdown/HTML 报告，缩放到一半宽度即清晰。
- 需要矢量图给 LaTeX/排版软件时用 `--format svg`。
- 一组报告图建议统一 `--palette` 与 `--width`，并给每张图写 `--footnote "数据来源：…"`。
