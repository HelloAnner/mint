# mint 命令与 spec 参考

## 命令一览

```
mint render <chart> [选项]        渲染一张图
mint batch <spec.json>            按 spec 批量渲染
mint list [--json]                列出全部图表
mint info <chart> [--json]        数据结构、选项与示例
mint palettes [--json]            列出调色板
mint styles [--json]              列出风格
mint doctor [--json]              环境自检
mint install skill [--force]      安装 skill 软链
mint uninstall skill              移除 skill 软链
mint skill [status|path|list|show]  查看 skill 状态
mint version | help               版本与帮助
```

## mint render

| 参数 | 说明 | 默认 |
|------|------|------|
| `-d, --data <file\|->` | 数据 JSON 文件，`-` 读 stdin | 该图内置示例数据 |
| `-o, --out <file>` | 输出路径。不带扩展名按格式自动补；`-` 表示把 SVG 写到 stdout | `./<chart>.png` |
| `-t, --title <text>` | 标题（支持 `\n` 换行） | 无 |
| `-S, --subtitle <text>` | 副标题 | 无 |
| `--footnote <text>` | 脚注（数据来源等） | 无 |
| `-W, --width <in>` | 画布宽度（英寸） | 7 |
| `-H, --height <in>` | 画布高度（英寸） | 4.35，固定长宽比的图会自动撑高 |
| `--dpi <n>` | 分辨率 | 300 |
| `-f, --format <fmt>` | `png` / `svg` / `both` | 由 `-o` 扩展名决定，否则 png |
| `-p, --palette <id>` | 调色板 id | `npg` |
| `--style <id>` | 风格 id | `professional` |
| `--font-family <name>` | 字体家族名 | 自动探测中文字体 |
| `--set <k=v>` | 图表选项，可重复 | — |
| `--options <json>` | 图表选项 JSON 对象 | — |
| `--json` | 输出机器可读结果 | — |
| `-q, --quiet` | 静默 | — |

示例：

```bash
# 用示例数据快速出图
mint render bar -o bar.png

# 指定数据、尺寸、调色板，同时产出矢量图
mint render line -d trend.json -W 3.5 -H 2.6 --palette okabe --format both -o trend

# 图表选项用 --set（会按字面量解析 true/false/数字/数组）
mint render bar -d d.json --set groupMode=stacked --set sort=desc --set valueLabel=false -o stacked.png

# 从 stdin 读数据，SVG 直接进管道
cat data.json | mint render pie -d - -f svg -o - > pie.svg
```

## mint batch

spec 文件可以是「对象数组」、「带 charts 的对象」或「单个对象」：

```jsonc
{
  "defaults": {                       // 可省略，作用到每一项
    "width": 7, "height": 4.35, "dpi": 300,
    "palette": "npg", "style": "professional", "format": "png",
    "options": { "legend": true }
  },
  "charts": [
    {
      "chart": "bar",                 // 必填
      "data": [ /* 内联数据 */ ],      // 与 data_file 二选一
      "data_file": "revenue.json",    // 相对 spec 文件所在目录
      "title": "季度营收", "subtitle": "单位：百万元", "footnote": "数据来源：财务系统",
      "width": 7, "height": 4.35, "dpi": 300,
      "palette": "nejm", "style": "professional", "format": "svg",
      "out": "revenue.svg",           // 省略则用 <chart>.png
      "options": { "groupMode": "stacked" }
    }
  ]
}
```

| 参数 | 说明 |
|------|------|
| `--outdir <dir>` | 所有输出的根目录（只取 out 的文件名） |
| `--stop-on-error` | 遇到第一个错误就停 |
| `--json` | 输出机器可读的汇总 |
| `-q, --quiet` | 静默 |

批量渲染在**一个 R 进程**里完成所有图，比逐张调 `mint render` 快得多（省掉每次启动 R 和加载 ggplot2 的开销）。

## 退出码与错误码

成功返回 0，失败返回 1；错误打到 stderr，格式为 `mint: [CODE] 信息` + 一行可操作提示。

| 错误码 | 含义 |
|--------|------|
| `UNKNOWN_CHART` | 图表 id 不存在（会给出近似建议） |
| `UNKNOWN_FLAG` / `MISSING_ARGUMENT` | 参数写错或缺参数 |
| `INVALID_DATA` | 数据结构不符合该图表要求 |
| `INVALID_SPEC` / `INVALID_VALUE` | spec 或选项取值不合法 |
| `DATA_NOT_FOUND` | 数据文件/spec 文件读不到 |
| `CANVAS_TOO_SMALL` | 画布减掉标题留白后太小，或内容放不下 |
| `UNKNOWN_PALETTE` / `UNKNOWN_STYLE` | 调色板/风格 id 不存在 |
| `MISSING_PACKAGE` | 该图表需要的 R 包装没装 |
| `FONT_NOT_FOUND` | `MINT_FONT` 指定的字体文件不存在 |
| `SKILL_EXISTS` | skill 目标路径已存在且不是 mint 管理的软链 |

## 环境变量

| 变量 | 作用 |
|------|------|
| `MINT_LIB` | R 依赖库路径（默认 `~/.local/share/mint/rlib`） |
| `MINT_HOME` | mint 安装目录（bin/mint 会自动设置） |
| `MINT_FONT_FAMILY` | 覆盖字体家族名 |
| `MINT_FONT` | 指定字体文件路径（.ttf/.otf/.ttc） |
| `MINT_SKILLS_DIR` | skill 安装根目录（默认 `~/.agents/skills`） |
| `MINT_CRAN` | 安装依赖时使用的 CRAN 镜像 |
| `MINT_DEBUG=1` | 出错时打印 R 堆栈 |
| `MINT_QUIET=1` | 静默模式 |
