# mint spec 与选项详解

## 两种输入方式

### 1. 命令行参数（单张图，最常用）

```bash
mint render bar --data revenue.json --title "标题" --set groupMode=stacked -o out.png
```

### 2. spec JSON（批量或需要精确控制时）

`mint batch spec.json`，文件可以是「一张图的 spec」，也可以是「多张图的数组」。

```jsonc
{
  "chart": "bar",                 // 必填，图表 id
  "data": [ /* 必填，数据结构见 mint info <chart> */ ],
  "title": "各区域季度营收",
  "subtitle": "单位：百万元",
  "footnote": "数据来源：财务系统",
  "width": 1280,                  // 逻辑宽度，默认 1280
  "height": 760,                  // 逻辑高度，默认 760
  "scale": 2,                     // 输出倍数，默认 2（2x 高清）
  "theme": "light",               // light | dark
  "palette": "mint",              // 见 mint palettes
  "format": "png",                // png | svg | both
  "font": "/path/to/font.ttc",    // 可选，指定字体
  "options": {                    // 图表专属选项，见 mint info <chart>
    "groupMode": "stacked",
    "yLegend": "营收（百万元）"
  }
}
```

批量写法：

```jsonc
{
  "defaults": { "palette": "indigo", "theme": "light", "width": 1200 },
  "charts": [
    { "chart": "bar",  "data": [/* … */], "out": "out/01-revenue.png" },
    { "chart": "line", "dataFile": "dau.json", "out": "out/02-dau.png", "title": "日活趋势" }
  ]
}
```

- `defaults` 会与每项的字段合并，每项可覆盖。
- 每项可以用 `dataFile` 代替内联 `data`，路径相对 spec 文件所在目录解析。
- 不写 `out` 时默认输出到 `./<chart>.png`（重名会自动加序号）。

## 所有图表共享的选项

这些选项在每张图上都可用（不是每张都生效）：

| 选项 | 类型 | 说明 |
|------|------|------|
| `legend` | boolean | 是否显示图例，默认 `true` |
| `valueFormat` | string | `number`（默认，千分位）\| `percent` \| `compact`（1.2万 / 3.4亿） |
| `decimals` | number | 小数位数 |
| `valuePrefix` / `valueSuffix` | string | 数值前后缀，如 `¥` / ` 万` |
| `xLegend` / `yLegend` | string | 坐标轴标题 |

其余选项是图表专属的，`mint info <chart>` 会完整列出，包括类型、默认值和可选值。

## 尺寸与排版

- 画布会被自动切分：上边距放标题和副标题，下边距放脚注，中间是绘图区。
- 默认 1280×760 配 `--scale 2` 输出 2560×1520 的 PNG，适合嵌进报告再缩放到 50%~70%。
- 做封面通栏图时用 `--width 1600 --height 900`。
- 嵌进窄侧栏时用 `--width 900 --height 700`。
- 没有标题/副标题时，绘图区会自动占满整张画布。
- 画布太小（绘图区不足 120×80）会直接报 `CANVAS_TOO_SMALL`。

## 退出码

| 码 | 含义 |
|----|------|
| 0 | 成功 |
| 1 | 运行失败（`INVALID_DATA` / `CANVAS_TOO_SMALL` / `UNKNOWN_CHART` 等） |
| 2 | 参数用法错误 |

配合 `--json` 时，成功会输出 `{ "ok": true, "outputs": [...] }`，
失败输出 `{ "ok": false, "error": { "code": "...", "message": "...", "hint": "..." } }`，
便于脚本判断。
