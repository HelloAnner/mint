# mint 图表目录

共 27 种图表。全部由 R + ggplot2 渲染，统一走 mint 的 professional 风格。

用 `mint info <id>` 查看某张图的完整选项与可运行示例；
本文件由 `Rscript scripts/gen-docs.R` 从代码自动生成，请勿手改。

## 比较

| id | 名称 | 一句话 | 形态 |
|----|------|--------|------|
| `bar` | 柱状图 | 比较不同类别或分组的数值大小，可分组、可堆叠、可横向 | grouped 分组 / stacked 堆叠 / horizontal 横向 |
| `radar` | 雷达图 | 在多个维度上同时比较若干对象，适合能力评估、产品对标 | filled 填充 / outline 描边 |
| `radial-bar` | 径向条形图 | 把条形沿圆周排布，省横向空间，适合类别很多的排名对比 | circular 环形 |
| `bullet` | 子弹图 | 一根横条里同时呈现实际值、目标值与达成区间，适合 KPI 罗列 | bullet 子弹 |
| `lollipop` | 棒棒糖图 | 用细杆加圆点替代柱子，类别多时信息密度更高、留白更多 | vertical 纵向 / horizontal 横向 |

### `bar` — 柱状图（Bar）

比较不同类别或分组的数值大小，可分组、可堆叠、可横向

**形态**：grouped 分组 / stacked 堆叠 / horizontal 横向

**数据结构**

```
数组，每行一条记录：分类字段 + 若干数值字段
[
  { "quarter": "Q1", "华东": 128, "华北": 96 },
  { "quarter": "Q2", "华东": 152, "华北": 108 }
]
不传 keys 时自动把数值字段识别为系列，第一个字符串字段识别为分类轴。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `groupMode` | 字符串 | grouped | 分组方式（grouped / stacked） |
| `layout` | 字符串 | vertical | 方向（vertical / horizontal） |
| `indexBy` | 字符串 | — | 分类轴字段名 |
| `keys` | 数组 | — | 参与绘制的数值字段 |
| `barWidth` | 数值 | 0.68 | 柱子宽度占槽位的比例 |
| `valueLabel` | 布尔 | TRUE | 是否直接标注数值 |
| `sort` | 字符串 | none | 分类轴排序（none / asc / desc） |
| `xLegend` | 字符串 | — | X 轴标题 |
| `yLegend` | 字符串 | — | Y 轴标题 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render bar -o bar.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"yLegend":"营收（百万元）","xLegend":"2025 财年"}`

**别名**：column、柱状图、条形图、直方图、columns

### `radar` — 雷达图（Radar）

在多个维度上同时比较若干对象，适合能力评估、产品对标

**形态**：filled 填充 / outline 描边

**数据结构**

```
数组，每行一个维度：
[
  { "dimension": "性能", "本产品": 82, "竞品A": 68 },
  { "dimension": "易用性", "本产品": 74, "竞品A": 88 }
]
除维度字段外的数值字段都会被当成一个比较对象；维度建议 3~8 个。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `indexBy` | 字符串 | — | 维度字段名 |
| `keys` | 数组 | — | 参与比较的对象字段 |
| `fillOpacity` | 数值 | 0.15 | 填充不透明度，0 为纯描边 |
| `gridLevels` | 数值 | 5 | 网格圈数（数值轴刻度数） |
| `xLegend` | 字符串 | — | X 轴标题（雷达图没有坐标轴，仅为兼容保留） |
| `yLegend` | 字符串 | — | Y 轴标题（雷达图没有坐标轴，仅为兼容保留） |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render radar -o radar.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"fillOpacity":0.15}`

**别名**：雷达、蜘蛛图、spider、能力图

### `radial-bar` — 径向条形图（RadialBar）

把条形沿圆周排布，省横向空间，适合类别很多的排名对比

**形态**：circular 环形

**数据结构**

```
数组，每项一个类别：
[
  { "id": "华东", "value": 187 },
  { "id": "华北", "value": 139 }
]
也兼容旧版「一个环一个系列」的写法 [{ "id": "华东", "data": [{ "x": "Q1", "y": 128 }] }]。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `innerRadius` | 数值 | 0.3 | 内孔半径占外圈半径的比例 |
| `innerRatio` | 数值 | — | 内孔比例的别名，写了就以它为准 |
| `padAngle` | 数值 | 0.6 | 扇区之间的间隔（角度，单位度） |
| `tracks` | 布尔 | TRUE | 是否显示底轨（满值刻度弧） |
| `tracksColor` | 字符串 | #e8eef4 | 底轨颜色 |
| `sort` | 字符串 | desc | 排序方式（desc / asc / none） |
| `valueLabel` | 布尔 | TRUE | 是否直接标注数值 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render radial-bar -o radial-bar.png`（不传 `--data` 时用内置示例数据）

**别名**：径向条形图、圆形条形、radial bar、环形柱状

### `bullet` — 子弹图（Bullet）

一根横条里同时呈现实际值、目标值与达成区间，适合 KPI 罗列

**形态**：bullet 子弹

**数据结构**

```
数组，每行一个指标：
[
  { "label": "营收", "value": 128, "target": 150, "ranges": [100, 200] },
  { "label": "新增用户", "value": 142, "target": 150, "ranges": [80, 120, 170] }
]
ranges 是定性区间（由小到大，从 0 起算的档位边界，可省略）。
也兼容旧写法 measures / markers（取第一个值）。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `titleAlign` | 字符串 | end | 类别名对齐（start / middle / end） |
| `valueLabel` | 布尔 | TRUE | 是否直标实际值与目标值 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render bullet -o bullet.png`（不传 `--data` 时用内置示例数据）

**别名**：子弹图、bullet、kpi图、目标对比

### `lollipop` — 棒棒糖图（Lollipop）

用细杆加圆点替代柱子，类别多时信息密度更高、留白更多

**形态**：vertical 纵向 / horizontal 横向

**数据结构**

```
数组，每项一个类别：
[
  { "id": "A", "value": 12 },
  { "id": "B", "value": 30 }
]
也支持对象写法 { "A": 12, "B": 30 } 与二元数组 [["A", 12]]。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `layout` | 字符串 | vertical | 方向（vertical / horizontal） |
| `sort` | 字符串 | desc | 排序方式（desc / asc / none） |
| `valueLabel` | 布尔 | TRUE | 是否直接标注数值 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render lollipop -o lollipop.png`（不传 `--data` 时用内置示例数据）

**别名**：棒棒糖图、lollipop、棒糖图、点棒图

## 趋势

| id | 名称 | 一句话 | 形态 |
|----|------|--------|------|
| `line` | 折线图 | 展示数值随时间的走势，可多系列对比、可填充面积 | line 折线 / area 面积 / step 阶梯 |
| `stream` | 河流图 | 按时间把多个系列堆叠起来，同时读总量走势与内部结构占比的漂移 | stacked 堆叠 / symmetric 对称河流 / expand 百分比堆叠 |
| `bump` | 排名变化图 | 用交叉的线条展示多个对象在名次上的此消彼长，比折线更适合看排名 | bump 折线排名 / area 面积排名 |

### `line` — 折线图（Line）

展示数值随时间的走势，可多系列对比、可填充面积

**形态**：line 折线 / area 面积 / step 阶梯

**数据结构**

```
两种写法都支持：
1) 行式（推荐）：[ { "month": "1月", "本期": 12, "上期": 9 } ]
2) 系列式：[ { "id": "本期", "data": [ { "x": "1月", "y": 12 } ] } ]
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `indexBy` | 字符串 | — | X 轴字段名 |
| `keys` | 数组 | — | 参与绘制的数值字段 |
| `area` | 布尔 | FALSE | 是否填充面积 |
| `points` | 布尔 | FALSE | 是否画数据点 |
| `curve` | 字符串 | linear | 线型（linear / step） |
| `labelSeries` | 字符串 | auto | 系列名标注方式（auto / end / legend / none） |
| `yZero` | 布尔 | FALSE | Y 轴是否从 0 开始 |
| `xLegend` | 字符串 | — | X 轴标题 |
| `yLegend` | 字符串 | — | Y 轴标题 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render line -o line.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"yLegend":"活跃用户（万）","xLegend":"2025 年","points":true}`

**别名**：line、折线图、曲线图、走势图、趋势图、area、面积图

### `stream` — 河流图（Stream）

按时间把多个系列堆叠起来，同时读总量走势与内部结构占比的漂移

**形态**：stacked 堆叠 / symmetric 对称河流 / expand 百分比堆叠

**数据结构**

```
两种写法都支持：
1) 行式（推荐）：[ { "month": "1月", "自然搜索": 320, "社交媒体": 180 } ]
2) 系列式：[ { "id": "自然搜索", "data": [ { "x": "1月", "y": 320 } ] } ]
除第一个字符串字段外，其余数值字段都会按顺序堆叠。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `offsetType` | 字符串 | none | 堆叠方式（none / expand / silhouette / wiggle） |
| `baseline` | 字符串 | zero | 基线（zero / symmetric） |
| `indexBy` | 字符串 | — | 时间/分类字段名 |
| `keys` | 数组 | — | 参与堆叠的数值字段 |
| `fillOpacity` | 数值 | 0.88 | 填充不透明度 |
| `labelSeries` | 字符串 | auto | 系列名标注方式（auto / end / legend / none） |
| `xLegend` | 字符串 | — | X 轴标题 |
| `yLegend` | 字符串 | — | Y 轴标题 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render stream -o stream.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"yLegend":"访问量（万次）","xLegend":"2025 年"}`

**别名**：堆叠面积图、面积图、河流图、streamgraph、stacked area、areachart

### `bump` — 排名变化图（Bump）

用交叉的线条展示多个对象在名次上的此消彼长，比折线更适合看排名

**形态**：bump 折线排名 / area 面积排名

**数据结构**

```
两种写法都支持：
1) 系列式（推荐）：[ { "id": "产品A", "data": [ { "x": "1月", "y": 3 } ] } ]
2) 行式：[ { "period": "2023", "产品A": 3, "产品B": 1 } ]
y 是名次，数字越小越靠上；若传的是分数而非名次，打开 reverseRank。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `variant` | 字符串 | bump | 形态（bump / area） |
| `reverseRank` | 布尔 | FALSE | 值为分数而非名次：打开后数值越大越靠上 |
| `indexBy` | 字符串 | — | 时间字段名 |
| `keys` | 数组 | — | 参与绘制的对象字段 |
| `pointSize` | 数值 | 8 | 数据点大小 |
| `labelSeries` | 字符串 | auto | 对象名标注方式（auto / end / both / legend / none） |
| `xLegend` | 字符串 | — | X 轴标题 |
| `yLegend` | 字符串 | — | Y 轴标题 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render bump -o bump.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"xLegend":"2025 年","yLegend":"名次"}`

**别名**：排名图、排名变化图、名次变化、bump、ranking

## 构成

| id | 名称 | 一句话 | 形态 |
|----|------|--------|------|
| `pie` | 环形图 | 展示整体中各部分的占比，可实心可环形 | donut 环形 / pie 实心 |
| `waffle` | 华夫图 | 用等量方格表示比例，比饼图更容易读出「几比几」的量级感 | waffle 华夫 |
| `marimekko` | 马赛克图 | 条形宽度表示组间占比、堆叠高度表示组内构成，一张图同时读两级比例 | marimekko 马赛克 |

### `pie` — 环形图（Pie）

展示整体中各部分的占比，可实心可环形

**形态**：donut 环形 / pie 实心

**数据结构**

```
数组或对象都行：
[ { "id": "搜索", "value": 348 }, { "id": "社交", "value": 266 } ]
{ "搜索": 348, "社交": 266 }
[ ["搜索", 348], ["社交", 266] ]
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `donut` | 布尔 | TRUE | 是否挖空成环形 |
| `innerRatio` | 数值 | 0.58 | 环形内径占外径的比例 |
| `showPercent` | 布尔 | TRUE | 标签是否显示百分比 |
| `showValue` | 布尔 | FALSE | 标签是否显示绝对值 |
| `sort` | 字符串 | desc | 排序方式（desc / asc / none） |
| `minShare` | 数值 | 0.015 | 占比低于该值并入「其他」 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render pie -o pie.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"showPercent":true,"showValue":true}`

**别名**：饼图、环形图、甜甜圈、donut、piechart、占比图

### `waffle` — 华夫图（Waffle）

用等量方格表示比例，比饼图更容易读出「几比几」的量级感

**形态**：waffle 华夫

**数据结构**

```
支持三种写法：
[ { "id": "已完成", "label": "已完成", "value": 62 } ]
{ "已完成": 62, "进行中": 23 }
[ ["已完成", 62], ["进行中", 23] ]
value 是权重，total 是格子总数（默认取权重之和，上限 100）。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `rows` | 数值 | — | 行数，省略则按总格数自动推导 |
| `columns` | 数值 | — | 列数，省略则按总格数自动推导 |
| `total` | 数值 | — | 格子总数，省略则取权重之和（上限 100） |
| `fillDirection` | 字符串 | top | 填充方向（top / right / bottom / left） |
| `emptyColor` | 字符串 | #f1f5f9 | 空格子的颜色 |
| `legend` | 布尔 | TRUE | 是否在右侧显示类别说明 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render waffle -o waffle.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"rows":10,"columns":10,"total":100}`

**别名**：华夫图、方格图、点阵图、waffle

### `marimekko` — 马赛克图（Marimekko）

条形宽度表示组间占比、堆叠高度表示组内构成，一张图同时读两级比例

**形态**：marimekko 马赛克

**数据结构**

```
两种写法：
1) 宽表（推荐）：[ { "id": "华东", "value": 320, "新客": 120, "老客": 200 } ]
2) 长表：[ { "类别": "华东", "子类": "新客", "value": 120 } ]
value 决定该组的宽度，其余数值字段构成组内堆叠，会自动识别为 dimensions。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `idBy` | 字符串 | id | 分组字段名 |
| `valueBy` | 字符串 | value | 决定宽度的字段名 |
| `dimensions` | 数组 | — | 组内堆叠字段，省略则自动识别 |
| `innerPadding` | 数值 | 2 | 组内间距（磅） |
| `outerPadding` | 数值 | 6 | 组间间距（磅） |
| `xLegend` | 字符串 | — | X 轴标题 |
| `yLegend` | 字符串 | — | Y 轴标题 |
| `legend` | 布尔 | TRUE | 是否显示颜色图例 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render marimekko -o marimekko.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"yLegend":"组内构成","xLegend":"区域规模"}`

**别名**：马赛克图、marimekko、mosiac、mosaic

## 关系

| id | 名称 | 一句话 | 形态 |
|----|------|--------|------|
| `scatter` | 散点图 | 看两个变量的相关关系，可分组着色、可按第三维调点大小 | scatter 散点 / bubble 气泡 / trend 带拟合线 |
| `parallel-coordinates` | 平行坐标图 | 把多个数值维度并排放置，每个对象一条折线，观察多维聚类与离群 | parallel 平行坐标 / highlight 高亮对比 |
| `architecture` | 架构图 | 把系统画成分层方块图：层是带子，方块是组件，细箭头表示组件之间的调用或依赖 | vertical 纵向分层 / horizontal 横向分层 |

### `scatter` — 散点图（Scatter）

看两个变量的相关关系，可分组着色、可按第三维调点大小

**形态**：scatter 散点 / bubble 气泡 / trend 带拟合线

**数据结构**

```
数组，每行一个点：
[
  { "x": 12.4, "y": 88, "group": "对照组" },
  { "x": 18.1, "y": 96, "group": "实验组", "size": 3 }
]
字段名可用 xKey / yKey / seriesKey / sizeKey 改写。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `xKey` | 字符串 | x | X 数值字段 |
| `yKey` | 字符串 | y | Y 数值字段 |
| `seriesKey` | 字符串 | — | 分组字段 |
| `sizeKey` | 字符串 | — | 气泡大小字段 |
| `labelKey` | 字符串 | — | 点标注字段 |
| `pointSize` | 数值 | — | 点大小（mm） |
| `alpha` | 数值 | — | 点透明度 |
| `trend` | 字符串 | none | 拟合线（none / linear / loess） |
| `trendCI` | 布尔 | TRUE | 拟合线是否带置信带 |
| `labels` | 布尔 | FALSE | 是否标注点 |
| `xZero` | 布尔 | FALSE | X 轴是否包含 0 |
| `yZero` | 布尔 | FALSE | Y 轴是否包含 0 |
| `xLegend` | 字符串 | — | X 轴标题 |
| `yLegend` | 字符串 | — | Y 轴标题 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render scatter -o scatter.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"xLegend":"干预强度","yLegend":"效应值","trend":"linear"}`

**别名**：散点图、气泡图、scatterplot、bubble、相关

### `parallel-coordinates` — 平行坐标图（ParallelCoordinates）

把多个数值维度并排放置，每个对象一条折线，观察多维聚类与离群

**形态**：parallel 平行坐标 / highlight 高亮对比

**数据结构**

```
每一行一条记录，第一列是对象名，其余数值字段作为维度：
[
  { "name": "城市A", "房价": 82, "通勤": 34, "绿化": 61 },
  { "name": "城市B", "房价": 65, "通勤": 48, "绿化": 73 }
]
可用 variables 选项指定参与绘制的维度，逗号分隔。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `variables` | 数组 | — | 参与绘制的字段，逗号分隔；省略则用全部数值字段 |
| `highlight` | 字符串 | — | 高亮的对象名（逗号分隔可高亮多个），其余线条降为浅灰 |
| `band` | 字符串 | none | 背景参考带：均值±标准差，或其余对象的取值范围（none / mean / minmax） |
| `lineWidth` | 数值 | — | 线宽（pt），省略则用风格线宽 |
| `opacity` | 数值 | 0.55 | 线条不透明度 |
| `xLegend` | 字符串 | — | X 轴标题 |
| `yLegend` | 字符串 | — | Y 轴标题 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render parallel-coordinates -o parallel-coordinates.png`（不传 `--data` 时用内置示例数据）

**别名**：平行坐标、parallel、多维图

### `architecture` — 架构图（Architecture Diagram）

把系统画成分层方块图：层是带子，方块是组件，细箭头表示组件之间的调用或依赖

**形态**：vertical 纵向分层 / horizontal 横向分层

**数据结构**

```
{
  "layers": [
    { "name": "客户端", "nodes": [{ "id": "web", "label": "Web 控制台", "description": "React SPA" }] },
    { "name": "接入层", "nodes": [{ "id": "gateway", "label": "API 网关" }] }
  ],
  "edges": [{ "from": "web", "to": "gateway", "label": "HTTPS" }]
}
nodes 里每一项可以是字符串（id 即名称）或对象；对象支持 label 显示名、description 小字说明。
layers 也可以写成 { "接入层": [...], "服务层": [...] }；
或者省略 layers，直接给 nodes，用每个节点的 layer / group 字段自动分层。
edges 支持 from/to（也可写 source/target），label 是连线上的小标签。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `direction` | 字符串 | vertical | 分层方向：纵向从上到下，横向从左到右（vertical / horizontal） |
| `edgeStyle` | 字符串 | curve | 连线样式（curve / straight / elbow） |
| `showLayers` | 布尔 | TRUE | 是否显示层名的底衬色带 |
| `showDescriptions` | 布尔 | TRUE | 是否显示方块里的小字说明 |
| `edgeLabels` | 布尔 | TRUE | 是否显示连线上的标签 |
| `nodeGap` | 数值 | 0.14 | 同一层内方块的间距（英寸） |
| `layerGap` | 数值 | 0.3 | 层与层之间的间距（英寸） |
| `detourGap` | 数值 | 0.2 | 同层连线绕开中间方块时向外绕行的距离（英寸），0 表示不绕行 |
| `minNodeWidth` | 数值 | 0.9 | 方块最小宽度（英寸） |
| `maxNodeWidth` | 数值 | 2.4 | 方块最大宽度（英寸） |
| `labelSize` | 数值 | 7.5 | 方块主标题字号（pt） |
| `descriptionSize` | 数值 | 6.5 | 方块说明文字字号（pt） |
| `edgeLabelSize` | 数值 | 6.5 | 连线标签字号（pt） |
| `lineWidth` | 数值 | 0.6 | 连线粗细（pt） |
| `cornerRadius` | 数值 | 0 | 方块圆角半径（pt），0 为直角（期刊风格默认直角） |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render architecture -o architecture.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"direction":"vertical","edgeStyle":"curve"}`

**别名**：架构图、系统架构图、架构、architecture、arch、topology、拓扑图、部署图

## 分布

| id | 名称 | 一句话 | 形态 |
|----|------|--------|------|
| `heatmap` | 热力图 | 用颜色深浅表达二维网格上的数值，适合相关矩阵、时段 × 维度的分布 | long 长表 / wide 宽表 / correlation 相关矩阵 |
| `calendar` | 日历热力图 | 按天着色，展示一整年的活跃度分布与周期性节律 | calendar 日历 / year 整年 |
| `histogram` | 直方图 | 看一个数值变量的分布形态：集中、离散、偏态与多峰 | frequency 频数 / density 密度 / grouped 分组 |
| `boxplot` | 箱线图 | 比较若干组数据的分布：中位数、四分位距、离群点 | box 箱线 / strip 带散点 / notch 带凹槽 |
| `ridgeline` | 山脊图 | 把多组核密度曲线叠成山脊，一眼比较多组分布的形状差异 | ridge 山脊 / quantiles 带分位线 |

### `heatmap` — 热力图（Heatmap）

用颜色深浅表达二维网格上的数值，适合相关矩阵、时段 × 维度的分布

**形态**：long 长表 / wide 宽表 / correlation 相关矩阵

**数据结构**

```
两种写法：
1) 长表（推荐）：[ { "x": "周一", "y": "上午", "value": 12 } ]
2) 宽表：[ { "时段": "上午", "周一": 12, "周二": 18 } ]（第一个字符串字段作 Y 轴）
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `xKey` | 字符串 | x | X 字段（长表） |
| `yKey` | 字符串 | y | Y 字段（长表） |
| `valueKey` | 字符串 | value | 数值字段（长表） |
| `showValues` | 布尔 | TRUE | 是否在格子里写数值 |
| `showScale` | 布尔 | TRUE | 是否画右侧色条 |
| `ramp` | 字符串 | blue | 色阶调色板 id |
| `reverse` | 布尔 | FALSE | 色阶是否反向 |
| `xLegend` | 字符串 | — | X 轴标题 |
| `yLegend` | 字符串 | — | Y 轴标题 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render heatmap -o heatmap.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"xLegend":"日期","yLegend":"时段"}`

**别名**：热力图、热图、相关性矩阵、相关矩阵、matrix、heat

### `calendar` — 日历热力图（Calendar）

按天着色，展示一整年的活跃度分布与周期性节律

**形态**：calendar 日历 / year 整年

**数据结构**

```
两种写法都支持：
[ { "day": "2025-01-15", "value": 12 } ]
{ "2025-01-15": 12 }
from / to 可省略，会按数据里的最早/最晚日期自动确定范围。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `from` | 字符串 | — | 起始日期 YYYY-MM-DD |
| `to` | 字符串 | — | 结束日期 YYYY-MM-DD |
| `ramp` | 字符串 | blue | 色阶调色板 id |
| `reverse` | 布尔 | FALSE | 色阶是否反向（浅=高） |
| `monthLabel` | 布尔 | TRUE | 是否显示月份标签 |
| `yearLegend` | 布尔 | TRUE | 月份标签是否带上年份 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render calendar -o calendar.png`（不传 `--data` 时用内置示例数据）

**别名**：日历图、日历热力、贡献图、calendar、github图

### `histogram` — 直方图（Histogram）

看一个数值变量的分布形态：集中、离散、偏态与多峰

**形态**：frequency 频数 / density 密度 / grouped 分组

**数据结构**

```
三种写法都支持：
1) 一维数值数组：[ 12, 15, 15, 18, 21 ]
2) 行式：[ { "value": 12 }, { "value": 15 } ]（value 也可写 x / count 等）
3) 分组：[ { "group": "对照组", "value": 12 } ]，group 字段名可用 groupKey 改写
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `valueKey` | 字符串 | — | 数值字段名，省略则自动识别 value / x 等 |
| `groupKey` | 字符串 | — | 分组字段名，省略则用第一个文本字段 |
| `bins` | 数值 | — | 分组数，省略按 ceiling(sqrt(n)) 自动取 |
| `binwidth` | 数值 | — | 组距，给了就以它为准（优先于 bins） |
| `groupMode` | 字符串 | overlay | 多组的排布方式（overlay / stack） |
| `density` | 布尔 | FALSE | 改用密度刻度并叠加核密度曲线 |
| `xZero` | 布尔 | FALSE | X 轴是否包含 0 |
| `xLegend` | 字符串 | — | X 轴标题 |
| `yLegend` | 字符串 | — | Y 轴标题 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render histogram -o histogram.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"xLegend":"测量值（mm）","yLegend":"频数"}`

**别名**：直方图、频数分布、分布图、histogram、hist、distribution

### `boxplot` — 箱线图（Boxplot）

比较若干组数据的分布：中位数、四分位距、离群点

**形态**：box 箱线 / strip 带散点 / notch 带凹槽

**数据结构**

```
三种写法都支持：
1) 长表（推荐）：[ { "group": "对照组", "value": 12 } ]
2) 行式多样本：[ { "group": "对照组", "x": 12, "y": 15 } ]，该行所有数值列都算这组的观测值
3) 只有数值列：[ { "x": 12, "y": 15 } ]，每列一个箱体
字段名可用 groupKey / valueKey 改写。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `groupKey` | 字符串 | — | 分组字段名，省略则用第一个文本字段 |
| `valueKey` | 字符串 | — | 数值字段名，省略则把所有数值列都当作观测值 |
| `showPoints` | 布尔 | FALSE | 是否叠加蜂群散点 |
| `showOutliers` | 布尔 | FALSE | 是否画出离群点 |
| `notch` | 布尔 | FALSE | 是否使用凹槽（中位数置信区间） |
| `sort` | 字符串 | desc | 按中位数排序（desc / asc / none） |
| `xLegend` | 字符串 | — | X 轴标题 |
| `yLegend` | 字符串 | — | Y 轴标题 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render boxplot -o boxplot.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"yLegend":"响应值（mg/L）"}`

**别名**：箱线图、盒须图、箱形图、boxplot、box、分布对比

### `ridgeline` — 山脊图（Ridgeline）

把多组核密度曲线叠成山脊，一眼比较多组分布的形状差异

**形态**：ridge 山脊 / quantiles 带分位线

**数据结构**

```
长表（推荐）：[ { "group": "对照组", "value": 12 } ]
也支持行式多样本 [ { "group": "A", "x": 12, "y": 15 } ]（该行数值列都算 A 的观测值）
和只有数值列的 [ { "x": 12, "y": 15 } ]（每列一组）。
字段名可用 groupKey / valueKey 改写。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `groupKey` | 字符串 | — | 分组字段名，省略则用第一个文本字段 |
| `valueKey` | 字符串 | — | 数值字段名，省略则把所有数值列都当作观测值 |
| `scale` | 数值 | 1.4 | 山脊的重叠高度倍率，越大越互相重叠 |
| `alpha` | 数值 | 0.7 | 填充透明度 |
| `showQuantiles` | 布尔 | FALSE | 是否标注每组的中位线 |
| `xLegend` | 字符串 | — | X 轴标题 |
| `yLegend` | 字符串 | — | Y 轴标题 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render ridgeline -o ridgeline.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"xLegend":"血药浓度（μg/mL）"}`

**别名**：山脊图、脊线图、峰峦图、ridgeline、ridge、joyplot、密度分布

## 层级

| id | 名称 | 一句话 | 形态 |
|----|------|--------|------|
| `treemap` | 矩形树图 | 用矩形面积表达占比，支持多层嵌套，适合看大盘构成 | squarify 方形 / sliceDice 切片 |
| `sunburst` | 旭日图 | 用同心环表达多层级的构成，从内到外逐层展开 | sunburst 旭日 |
| `icicle` | 冰柱图 | 横向分层的矩形层级图，每层代表一级，宽度代表占比 | vertical 纵向 / horizontal 横向 |
| `circle-packing` | 圆形打包图 | 用嵌套圆的面积表达层级占比，视觉柔和，适合摘要与封面 | packed 打包 |

### `treemap` — 矩形树图（TreeMap）

用矩形面积表达占比，支持多层嵌套，适合看大盘构成

**形态**：squarify 方形 / sliceDice 切片

**数据结构**

```
三种写法：
1) 嵌套：{ "name": "总计", "children": [{ "name": "华东", "value": 300 }] }
2) 平铺：[{ "name": "华东", "value": 300 }]（会自动套一个根节点）
3) 路径：[{ "path": "线上/华东/上海", "value": 120 }]（用 / 自动建树）
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `tile` | 字符串 | squarify | 切分算法（squarify / slice / dice / sliceDice / binary） |
| `innerPadding` | 数值 | 3 | 子节点内边距 |
| `outerPadding` | 数值 | 4 | 根节点外边距 |
| `labelSkipSize` | 数值 | 26 | 小于该面积的矩形不显示标签 |
| `root` | 字符串 | 总计 | 自动生成根节点时的名字 |
| `valueFormat` | 字符串 | number | 数值格式化方式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | 字符串 | — | 数值前缀，如 ¥ |
| `valueSuffix` | 字符串 | — | 数值后缀，如 万 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render treemap -o treemap.png`（不传 `--data` 时用内置示例数据）

**别名**：树图、矩形树图、treemap、占比方块

### `sunburst` — 旭日图（Sunburst）

用同心环表达多层级的构成，从内到外逐层展开

**形态**：sunburst 旭日

**数据结构**

```
与矩形树图一致，同为层级结构：
{ "name": "总计", "children": [{ "name": "线上", "children": [{ "name": "华东", "value": 320 }] }] }
也接受 [{ "name": "华东", "value": 320 }] 或 [{ "path": "线上/华东", "value": 120 }]。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `cornerRadius` | 数值 | 3 | 扇区圆角（R 版为直角扇区，此选项保留兼容） |
| `borderWidth` | 数值 | 1 | 扇区描边宽度 |
| `root` | 字符串 | 总计 | 自动生成根节点时的名字 |
| `valueFormat` | 字符串 | number | 数值格式化方式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | 字符串 | — | 数值前缀，如 ¥ |
| `valueSuffix` | 字符串 | — | 数值后缀，如 万 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render sunburst -o sunburst.png`（不传 `--data` 时用内置示例数据）

**别名**：旭日图、sunburst、环形层级

### `icicle` — 冰柱图（Icicle）

横向分层的矩形层级图，每层代表一级，宽度代表占比

**形态**：vertical 纵向 / horizontal 横向

**数据结构**

```
与矩形树图一致：
{ "name": "总计", "children": [{ "name": "线上", "children": [{ "name": "华东", "value": 320 }] }] }
也接受 [{ "name": "华东", "value": 320 }] 或 [{ "path": "线上/华东", "value": 120 }]。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `orientation` | 字符串 | vertical | 展开方向（vertical / horizontal） |
| `borderWidth` | 数值 | 1 | 矩形描边宽度 |
| `labelSkipWidth` | 数值 | 24 | 过窄的矩形不显示标签 |
| `root` | 字符串 | 总计 | 自动生成根节点时的名字 |
| `valueFormat` | 字符串 | number | 数值格式化方式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | 字符串 | — | 数值前缀，如 ¥ |
| `valueSuffix` | 字符串 | — | 数值后缀，如 万 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render icicle -o icicle.png`（不传 `--data` 时用内置示例数据）

**别名**：冰柱图、icicle、层级条形

### `circle-packing` — 圆形打包图（CirclePacking）

用嵌套圆的面积表达层级占比，视觉柔和，适合摘要与封面

**形态**：packed 打包

**数据结构**

```
与矩形树图一致：
{ "name": "总计", "children": [{ "name": "线上", "children": [{ "name": "华东", "value": 320 }] }] }
也接受 [{ "name": "华东", "value": 320 }] 或 [{ "path": "线上/华东", "value": 120 }]。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `padding` | 数值 | 4 | 圆之间的间距 |
| `labelSkipRadius` | 数值 | 12 | 半径小于该值的圆不显示标签 |
| `root` | 字符串 | 总计 | 自动生成根节点时的名字 |
| `valueFormat` | 字符串 | number | 数值格式化方式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | 字符串 | — | 数值前缀，如 ¥ |
| `valueSuffix` | 字符串 | — | 数值后缀，如 万 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render circle-packing -o circle-packing.png`（不传 `--data` 时用内置示例数据）

**别名**：圆打包、气泡图、气泡树、bubble tree

## 流向

| id | 名称 | 一句话 | 形态 |
|----|------|--------|------|
| `funnel` | 漏斗图 | 展示多级流程中每一步的留存与流失，适合转化率分析 | funnel 漏斗 |
| `sankey` | 桑基图 | 用带宽表示流向的规模，展示来源到去向的分配路径 | horizontal 横向 / vertical 纵向 |
| `flowchart` | 流程图 | 按分层自动排版的流程/状态流转图，支持矩形、圆角、胶囊与判断菱形 | layered 分层自动排版 / orthogonal 直角连线 |
| `sequence` | 时序图 | 按时间顺序展示参与者之间的消息往返，支持返回虚线、自调用与备注 | solid 调用 / dashed 返回 / note 备注 |

### `funnel` — 漏斗图（Funnel）

展示多级流程中每一步的留存与流失，适合转化率分析

**形态**：funnel 漏斗

**数据结构**

```
按流程顺序排列：
[
  { "id": "访问", "label": "访问落地页", "value": 12000 },
  { "id": "注册", "label": "注册账号", "value": 4800 }
]
也支持 { "访问": 12000, "注册": 4800 } 或 [["访问", 12000], ["注册", 4800]]。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `spacing` | 数值 | 4 | 层与层之间的缝隙（pt） |
| `shapeBlending` | 数值 | 0.66 | 层内斜面的融合程度：0 为上下贯通的连续斜面，1 为纯台阶 |
| `valueLabel` | 布尔 | TRUE | 是否直接标注数值与转化率 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render funnel -o funnel.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"valueFormat":"number"}`

**别名**：漏斗、转化、funnel、转化率

### `sankey` — 桑基图（Sankey）

用带宽表示流向的规模，展示来源到去向的分配路径

**形态**：horizontal 横向 / vertical 纵向

**数据结构**

```
{
  "nodes": [{ "id": "搜索" }, { "id": "注册" }, { "id": "付费" }],
  "links": [{ "source": "搜索", "target": "注册", "value": 320 }]
}
nodes 可以省略，会从 links 的 source/target 自动推导。
source/target 也支持写成 from/to，value 支持写成 weight。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `layout` | 字符串 | horizontal | 布局方向（horizontal / vertical） |
| `nodeThickness` | 数值 | 16 | 节点条厚度（pt） |
| `nodeSpacing` | 数值 | 18 | 同一阶段内节点之间的间距（pt） |
| `linkOpacity` | 数值 | 0.28 | 连线透明度 |
| `gradient` | 布尔 | TRUE | 连线是否按来源→目标渐变色 |
| `valueFormat` | 字符串 | number | 数值格式（number / percent / compact） |
| `decimals` | 数值 | — | 小数位数 |
| `valuePrefix` | 字符串 | — | 数值前缀 |
| `valueSuffix` | 字符串 | — | 数值后缀 |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render sankey -o sankey.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"layout":"horizontal","linkOpacity":0.3}`

**别名**：桑基图、sankey、流向图、流量图

### `flowchart` — 流程图（Flowchart）

按分层自动排版的流程/状态流转图，支持矩形、圆角、胶囊与判断菱形

**形态**：layered 分层自动排版 / orthogonal 直角连线

**数据结构**

```
{
  "nodes": [
    { "id": "start", "label": "开始", "shape": "stadium" },
    { "id": "check", "label": "风控通过？", "shape": "diamond" },
    { "id": "pay", "label": "发起支付" }
  ],
  "edges": [
    { "from": "start", "to": "check" },
    { "from": "check", "to": "pay", "label": "是" }
  ]
}
shape 可取 rect（默认）/ round / stadium（开始结束）/ diamond（判断）。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `direction` | 字符串 | TB | 排版方向（TB / LR） |
| `nodeHeight` | 数值 | 0.34 | 节点高度（英寸） |
| `rankGap` | 数值 | 0.62 | 层间距（英寸） |
| `siblingGap` | 数值 | 0.24 | 同层节点间距（英寸） |
| `edgeLabels` | 布尔 | TRUE | 是否显示连线标签 |
| `labelWrap` | 数值 | 0 | 节点文字折行宽度（字符，0 表示自动） |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render flowchart -o flowchart.png`（不传 `--data` 时用内置示例数据）

**别名**：流程图、流程、状态图、flow、diagram

### `sequence` — 时序图（Sequence）

按时间顺序展示参与者之间的消息往返，支持返回虚线、自调用与备注

**形态**：solid 调用 / dashed 返回 / note 备注

**数据结构**

```
{
  "participants": ["用户", "App", "服务端"],
  "messages": [
    { "from": "用户", "to": "App", "label": "提交订单" },
    { "from": "App", "to": "服务端", "label": "创建订单" },
    { "from": "服务端", "to": "App", "label": "订单号", "type": "dashed" }
  ],
  "notes": [ { "from": "App", "to": "服务端", "label": "同一事务内写入" } ]
}
participants 可省略（按 messages 首次出现顺序推导）；type 为 dashed / return / reply 时画虚线返回。
```

**选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `number` | 布尔 | FALSE | 是否给消息自动编号 |
| `labelSize` | 数值 | 6.5 | 消息文字字号（pt） |
| `noteSize` | 数值 | 6.5 | 备注文字字号（pt） |
| `boxWidth` | 数值 | 0.84 | 参与者盒子宽度（相对列距） |
| `lineWidth` | 数值 | 0.45 | 消息箭头粗细（pt） |
| `legend` | 布尔 | TRUE | 是否显示图例 |

**最小示例**：`mint render sequence -o sequence.png`（不传 `--data` 时用内置示例数据）

**示例选项**：`{"number":true}`

**别名**：时序图、顺序图、序列图、时序、交互图、uml时序、sequence-diagram

## 风格与调色板

`mint styles` 看风格，`mint palettes` 看配色：

| 用途 | 推荐 |
|------|------|
| 通用分类 | `npg`（默认）、`aaas`、`lancet`、`jama` |
| 医学/临床 | `nejm` |
| 色盲安全（投稿） | `okabe` |
| 黑白印刷 | `greys` |
| 连续映射（热力图/日历图） | `blue`、`viridis` |
| 有正负/基准的发散映射 | `rdbu` |

