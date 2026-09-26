---
name: mint
description: 把数据变成期刊级专业图表。当用户说"画个图""生成图表""做成柱状图/折线图/饼图/热力图""把这份数据可视化""给报告/论文配张图""生成图表 PNG/SVG"时使用。mint 是一个 R + ggplot2 的命令行工具，把 JSON 数据渲染成 300 dpi 的 PNG 或可编辑 SVG，内置 27 种图表、期刊调色板（Nature/Science/NEJM/Lancet/JAMA/Okabe-Ito）与专业排版风格，中文开箱可用。核心命令是 `mint render <chart> --data data.json -o out.png`；不确定用哪种图表先 `mint list`，需要数据结构说明用 `mint info <chart>`。
---

# Mint —— 数据到期刊级图表的 CLI

mint 把一份 JSON 数据渲染成一张**成品图**：默认 7 × 4.35 英寸、300 dpi（期刊双栏满宽），
自带标题、副标题、脚注排版。风格是刻意的期刊风格 —— 细轴线、浅网格、小字号、高信息密度，
不用渐变、不用圆角、不用阴影。输出可以是 PNG，也可以是**可编辑的矢量 SVG**（投稿优先给 SVG）。

底层是 R + ggplot2；图表布局、字体、配色、版心都由 mint 统一控制。

## 核心原则

1. **先选对图，再谈美观。** 拿不准就读 [references/charts.md](references/charts.md) 的「什么时候用」，
   或直接 `mint list` / `mint info <chart>`。
2. **先看数据结构，再决定 chart。** 每种图都有自己的数据形状，`mint info <chart>` 里有可运行示例。
   数据形状不清楚就先用 `--data -` 把示例数据喂进去试。
3. **克制地提高信息密度。** 同一张图系列数 ≤ 6；饼图/环形图扇区 ≤ 6；
   数值能直接标在图形上就不要靠图例来回比对；类别很多时用棒棒糖图或横向柱状图，不要硬塞。
4. **尺寸按用途选。** 单栏 3.5 in、双栏 7 in（默认）、幻灯片 10 in；
   `--dpi 300` 用于印刷（默认），屏幕预览用 `--dpi 150` 就够。
5. **中文直接写在 spec 里**，不要在图上后期叠字。中文字体会自动探测，不会出现方框。
6. **投稿要矢量图**：`--format both` 同时产出 PNG 与 SVG，正文/排版优先用 SVG。
7. **验证产出**：渲染完成后读一次生成的 PNG 再交付。能生成不代表布局没问题
   （标签重叠、空图、坐标轴被裁都可能在"成功"之后才发现）。
8. **临时文件必须清干净**：数据 JSON、batch spec、预览图、调试用的 SVG 都算临时文件，
   交付前全部删除，只保留最终要交付的图片。能不走磁盘就别走（`--data -` 从 stdin 传）。

## 快速开始

```bash
mint list                                   # 27 种图表一览
mint info bar                               # 某张图的数据结构、选项与示例
mint palettes                               # 期刊调色板
mint styles                                 # 可用风格
mint render bar --data revenue.json --title "各区域季度营收" --subtitle "单位：百万元" -o revenue.png
mint render scatter -d points.json --set trend=linear --set xLegend="干预强度" -o fit.svg
mint doctor                                 # 环境自检
```

`mint render` 常用参数：

| 参数 | 说明 | 默认 |
|------|------|------|
| `-d, --data <file\|->` | 数据 JSON，`-` 表示 stdin | 该图的内置示例数据 |
| `-o, --out <file>` | 输出路径（不带扩展名会自动补），`-` 输出 SVG 到 stdout | `./<chart>.png` |
| `-t, --title` / `-S, --subtitle` / `--footnote` | 标题、副标题、脚注 | 无 |
| `-W, --width` / `-H, --height` | 画布尺寸，**英寸** | 7 × 4.35 |
| `--dpi` | 分辨率 | 300 |
| `-f, --format` | `png` / `svg` / `both` | `png` |
| `-p, --palette` | 调色板 id | `npg` |
| `--style` | 风格 id | `professional` |
| `--set k=v` | 图表选项，可重复 | — |
| `--options <json>` | 一次性传多个图表选项 | — |
| `--json` | 输出机器可读结果 | — |

## 选图速查

| 你想表达 | 用哪张图 |
|----------|----------|
| 比较几个类别的数值 | `bar`（横向 `--set layout=horizontal`，排序 `--set sort=desc`） |
| 类别很多、想让画面透气 | `lollipop` |
| 看数值随时间的变化 | `line`（`--set area=true` 变面积图） |
| 看构成比例随时间变化 | `stream`（`--set baseline=symmetric` 河流图） |
| 看排名变化 | `bump` |
| 看整体占比 | `pie`（环形）或 `waffle`（华夫） |
| 两类分类的交叉占比 | `marimekko` |
| 两个变量的相关性 | `scatter`（`--set trend=linear` 加拟合线） |
| 多维对象对比 | `radar`、`parallel-coordinates` |
| 二维网格上的数值分布 | `heatmap`（相关矩阵就用它） |
| 一年里的时间分布 | `calendar` |
| 数值分布形态 | `histogram`、`boxplot`（`--set showPoints=true` 加蜂群散点）、`ridgeline` |
| 单值达成情况 | `bullet` |
| 层级占比 | `treemap`、`sunburst`、`icicle`、`circle-packing` |
| 转化漏斗 | `funnel` |
| 流向与分流 | `sankey` |
| 流程/状态流转 | `flowchart` |
| 交互时序 | `sequence` |
| 分层架构 | `architecture` |

## 数据结构怎么写

三种最常见形状（其余见 `mint info <chart>`）：

```jsonc
// 1) 行式：一行一条记录，第一个字符串字段是分类轴，数值字段是系列
[ { "quarter": "Q1", "华东": 128, "华北": 96 },
  { "quarter": "Q2", "华东": 152, "华北": 108 } ]

// 2) 占比/单值：id + value（也接受 {名称: 数值} 或 [["名称", 数值]]）
[ { "id": "搜索", "value": 348 }, { "id": "社交", "value": 266 } ]

// 3) 关系/坐标：任意字段名，用 xKey/yKey 指定
[ { "x": 12.4, "y": 88, "group": "对照组" } ]
```

需要显式指定字段时用 `--set`：`--set indexBy=quarter --set keys=华东,华北`。

## 排版与尺寸

- 画布用英寸：`--width 3.5` 单栏、`--width 7` 双栏（默认）、`--width 10` 幻灯片。
- 高度只给宽度时，mint 会按内容比例自动撑高（饼图、雷达图这类方图不会留一大片空白）。
- 标题/副标题/脚注占用的高度会从图表区扣掉，不会压到图上。
- 字号是期刊尺度（坐标轴 7pt、标题 11pt），所以**不要为了"看得清"把画布缩到 2 英寸以下**。

## 风格与配色

- 目前内置 `professional` 一种风格（期刊级）；后续会加更多场景风格，用 `mint styles` 查看。
- 调色板默认 `npg`（Nature 系）。医学/临床用 `nejm`，投稿要色盲安全用 `okabe`，
  黑白印刷用 `greys`；连续映射（热力图/日历图）用 `blue` / `viridis`，有正负用 `rdbu`。
- 同一张图里系列超过 6 个就该拆图或改用堆叠，不要靠调色板硬撑。

## 批量出图

一个进程出多张图，比逐张调 CLI 快得多：

```bash
mint batch report.json --outdir out/
```

```jsonc
{
  "defaults": { "width": 7, "palette": "npg", "style": "professional" },
  "charts": [
    { "chart": "bar",  "data_file": "revenue.json", "title": "季度营收", "out": "revenue.png" },
    { "chart": "line", "data": [ /* 内联数据 */ ], "title": "趋势", "out": "trend.svg",
      "format": "svg", "options": { "points": true } }
  ]
}
```

明细见 [references/spec.md](references/spec.md)。

批量在**一个 R 进程**里渲染所有图：单张冷启动约 1.2 秒（R 启动 + 加载 ggplot2 占 0.8 秒），
批量则约 0.5 秒/张。要出多张图就用 `mint batch`，不要循环调 `mint render`。

## 排错

| 现象 | 处理 |
|------|------|
| `mint: command not found` | 把 mint 所在目录加进 PATH |
| `mint: 找不到 Rscript` | 先装 R：`brew install r` 或 https://cran.r-project.org |
| `[MISSING_PACKAGE]` | 运行 `Rscript scripts/install-deps.R` 装依赖 |
| `[CANVAS_TOO_SMALL]` | 画布太小，调大 `--width` / `--height` |
| `[INVALID_DATA]` | 数据形状不对，`mint info <chart>` 看正确形状 |
| 中文变成方框 | 装一个中文字体（Noto Sans CJK / 思源黑体），或 `--font-family` 指定已装字体 |
| 图太大/太小 | 尺寸按英寸算，7 × 4.35 @300dpi = 2100 × 1305 px |
| 想看堆栈 | `MINT_DEBUG=1 mint render ...` |

## 环境变量

| 变量 | 作用 |
|------|------|
| `MINT_FONT_FAMILY` | 指定字体家族名 |
| `MINT_FONT` | 指定字体文件（.ttf/.otf/.ttc），会注册成 mint 专用字体 |
| `MINT_LIB` | R 依赖库位置，默认 `~/.local/share/mint/rlib` |
| `MINT_SKILLS_DIR` | skill 安装根目录，默认 `~/.agents/skills` |
| `MINT_DEBUG=1` | 出错时打印 R 堆栈 |
