# mint 图表目录

共 21 种图表，均随 mint 一起安装了端到端渲染测试。

除 `architecture`（架构图，mint 自绘 SVG）外，其余图表都基于 nivo 0.99 渲染。

用 `mint info <id>` 查看某张图的完整选项与可运行示例。

## 分类速览

| 分类 | 图表 |
|------|------|
| 比较 | `bar` · `radar` · `radial-bar` · `bullet` |
| 趋势 | `line` · `stream` · `bump` |
| 构成 | `pie` · `waffle` · `marimekko` |
| 关系 | `scatter` · `parallel-coordinates` · `architecture` |
| 分布 | `heatmap` · `calendar` |
| 层级 | `treemap` · `sunburst` · `icicle` · `circle-packing` |
| 流向 | `funnel` · `sankey` |

## 比较

### `bar` — 柱状图（Bar）

比较不同类别或不同分组的数值大小，可分组、可堆叠、可横向。

**形态**：grouped 分组 / stacked 堆叠 / horizontal 横向

**数据结构**

```
数组，每行一条记录：分类字段 + 若干数值字段
[
  { "quarter": "Q1", "华东": 128, "华北": 96 },
  { "quarter": "Q2", "华东": 152, "华北": 108 }
]
不传 keys 时会自动把数值字段识别为系列，第一个字符串字段识别为分类轴。
```

**最小示例**：`mint render bar -o bar.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `groupMode` | string | `"grouped"` | 分组方式（grouped / stacked） |
| `layout` | string | `"vertical"` | 方向（vertical / horizontal） |
| `indexBy` | string | — | 分类轴字段名 |
| `keys` | array | — | 参与绘制的数值字段，逗号分隔 |
| `borderRadius` | number | `6` | 柱子的圆角半径 |
| `valueLabel` | boolean | `true` | 是否在柱子上直接标数值 |
| `legend` | boolean | `true` | 是否显示图例 |
| `xLegend` | string | — | X 轴标题 |
| `yLegend` | string | — | Y 轴标题 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：column、柱状图、条形图、直方图、columns

### `radar` — 雷达图（Radar）

在多个维度上同时比较若干对象，适合能力评估、产品对标。

**形态**：filled 填充 / outline 描边

**数据结构**

```
数组，每行一个维度：
[
  { "dimension": "性能", "本产品": 82, "竞品A": 68 },
  { "dimension": "易用性", "本产品": 74, "竞品A": 88 }
]
除维度字段外的数值字段都会被当成一个比较对象。
```

**最小示例**：`mint render radar -o radar.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `indexBy` | string | — | 维度字段名 |
| `keys` | array | — | 比较对象字段，逗号分隔 |
| `fillOpacity` | number | `0.15` | 填充不透明度，0 为纯描边 |
| `gridLevels` | number | `5` | 网格层数 |
| `legend` | boolean | `true` | 是否显示图例 |
| `xLegend` | string | — | X 轴标题 |
| `yLegend` | string | — | Y 轴标题 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：雷达、蜘蛛图、spider、能力图

### `radial-bar` — 径向条形图（RadialBar）

把条形沿圆周排布，省横向空间，适合类别很多的排名对比。

**形态**：circular 环形

**数据结构**

```
每个环一个系列：
[
  { "id": "华东", "data": [{ "x": "Q1", "y": 128 }, { "x": "Q2", "y": 152 }] }
]
也支持 { "华东": [128, 152] } 配合 labels 选项。
```

**最小示例**：`mint render radial-bar -o radial-bar.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `innerRadius` | number | `0.3` | 内半径比例 |
| `padAngle` | number | `0.6` | 扇形间隔 |
| `cornerRadius` | number | `3` | 圆角 |
| `tracks` | boolean | `true` | 是否显示底轨 |
| `tracksColor` | string | `"#f1f5f9"` | 底轨颜色 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：径向条形图、圆形条形、radial bar、环形柱状

### `bullet` — 子弹图（Bullet）

一根横条里同时呈现实际值、目标值与达成区间，适合 KPI 罗列。

**形态**：bullet 子弹

**数据结构**

```
[
  {
    "id": "营收",
    "title": "营收",
    "ranges": [150, 200, 260],
    "measures": [187],
    "markers": [200]
  }
]
ranges 是背景区间（由小到大），measures 是实际值，markers 是目标值。
```

**最小示例**：`mint render bullet -o bullet.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `titleAlign` | string | `"end"` | 标题对齐（start / middle / end） |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：子弹图、bullet、kpi图、目标对比

## 趋势

### `line` — 折线图（Line）

展示一个量随时间或有序维度的变化趋势，支持多系列对比与面积填充。

**形态**：line 折线 / area 面积 / step 阶梯

**数据结构**

```
推荐用「系列」结构：
[
  { "id": "Web",   "data": [{ "x": "1月", "y": 42 }, { "x": "2月", "y": 51 }] },
  { "id": "App",   "data": [{ "x": "1月", "y": 30 }, { "x": "2月", "y": 38 }] }
]
也支持扁平记录 [{ "x": "1月", "y": 42, "channel": "Web" }]，
会按第一个字符串字段（或 seriesBy 指定字段）自动分组。
```

**最小示例**：`mint render line -o line.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `curve` | string | `"monotoneX"` | 曲线插值方式（linear / monotoneX / natural / step / stepAfter / basis / cardinal） |
| `area` | boolean | `false` | 是否填充面积（面积图） |
| `points` | boolean | `false` | 是否显示数据点 |
| `lineWidth` | number | `3` | 线宽 |
| `seriesBy` | string | — | 扁平记录下用于分组的字段名 |
| `xBy` | string | — | X 字段名，默认 x |
| `yBy` | string | — | Y 字段名，默认 y |
| `xLegend` | string | — | X 轴标题 |
| `yLegend` | string | — | Y 轴标题 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：折线、趋势图、trend、area、面积图

### `stream` — 堆叠面积图（Stream）

按时间堆叠多个系列，一眼看出总量走势与结构占比的变化。

**形态**：stacked 堆叠 / expand 百分比堆叠

**数据结构**

```
数组，每行一个时间点，每列一个系列（数值）：
[
  { "month": "1月", "自然搜索": 320, "社交媒体": 180 },
  { "month": "2月", "自然搜索": 345, "社交媒体": 205 }
]
除第一个字符串字段外，其余数值字段都会被当成堆叠系列。
```

**最小示例**：`mint render stream -o stream.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `offsetType` | string | `"none"` | 堆叠方式，expand 表示百分比堆叠（none / expand / silhouette / wiggle） |
| `indexBy` | string | — | 时间/分类字段名 |
| `keys` | array | — | 参与堆叠的数值字段，逗号分隔 |
| `fillOpacity` | number | `0.88` | 填充不透明度 |
| `legend` | boolean | `true` | 是否显示图例 |
| `xLegend` | string | — | X 轴标题 |
| `yLegend` | string | — | Y 轴标题 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：堆叠面积图、面积图、stacked area、areachart

### `bump` — 排名变化图（Bump）

用交叉的线条展示多个对象在名次上的此消彼长，比折线更适合看排名。

**形态**：bump 折线排名 / area-bump 面积排名

**数据结构**

```
每个系列一组「时间 → 名次」的点：
[
  { "id": "产品A", "data": [{ "x": "1月", "y": 3 }, { "x": "2月", "y": 2 }] },
  { "id": "产品B", "data": [{ "x": "1月", "y": 1 }, { "x": "2月", "y": 4 }] }
]
y 是名次，数字越小越靠上。
```

**最小示例**：`mint render bump -o bump.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `variant` | string | `"bump"` | 形态（bump / area） |
| `pointSize` | number | `8` | 数据点大小 |
| `xLegend` | string | — | X 轴标题 |
| `yLegend` | string | — | Y 轴标题 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：排名图、bump、名次变化、ranking

## 构成

### `pie` — 环形图 / 饼图（Pie）

展示各部分占整体的比例，环形模式可在中心放一个总量指标。

**形态**：donut 环形 / pie 实心饼

**数据结构**

```
支持三种写法：
1) [{ "id": "搜索", "label": "搜索广告", "value": 348 }]
2) { "搜索": 348, "社交": 266 }
3) [["搜索", 348], ["社交", 266]]
```

**最小示例**：`mint render pie -o pie.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `donut` | boolean | `true` | 是否为环形（中空） |
| `innerRadius` | number | `0.62` | 内半径比例 0~1，donut 打开时生效 |
| `padAngle` | number | `1.6` | 扇区间隔角度 |
| `cornerRadius` | number | `6` | 扇区圆角 |
| `linkLabels` | boolean | `true` | 是否显示外圈引导线与标签 |
| `sortByValue` | boolean | `true` | 是否按数值从大到小排序 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：饼图、环形图、donut、甜甜圈、占比图

### `waffle` — 华夫图（Waffle）

用等量方格表示比例，比饼图更容易读出"几比几"的量级感。

**形态**：waffle 华夫

**数据结构**

```
[{ "id": "已完成", "label": "已完成", "value": 68 }]
value 是"格数"的权重，total 是格子总数（默认取权重之和，上限 100）。
```

**最小示例**：`mint render waffle -o waffle.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `rows` | number | — | 行数，省略则自动推导 |
| `columns` | number | — | 列数，省略则自动推导 |
| `total` | number | — | 格子总数，省略则取权重之和（上限 100） |
| `fillDirection` | string | `"top"` | 填充方向（top / right / bottom / left） |
| `emptyColor` | string | `"#f1f5f9"` | 空格子的颜色 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：华夫图、方格图、waffle、点阵图

### `marimekko` — 马赛克图（Marimekko）

条形宽度表示组间占比、堆叠高度表示组内构成，一张图看两层比例。

**形态**：marimekko 马赛克

**数据结构**

```
[
  {
    "id": "华东",
    "value": 320,
    "新客": 120,
    "老客": 200
  },
  { "id": "华南", "value": 180, "新客": 90, "老客": 90 }
]
value 决定该组的宽度，其余数值字段构成组内的堆叠，会自动识别为 dimensions。
```

**最小示例**：`mint render marimekko -o marimekko.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `idBy` | string | `"id"` | 分组字段名 |
| `valueBy` | string | `"value"` | 决定宽度的字段名 |
| `dimensions` | array | — | 组内堆叠字段，逗号分隔；省略则自动识别 |
| `innerPadding` | number | `2` | 组内间距 |
| `outerPadding` | number | `6` | 组间间距 |
| `xLegend` | string | — | X 轴标题 |
| `yLegend` | string | — | Y 轴标题 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：马赛克图、marimekko、mosiac

## 关系

### `scatter` — 散点图（Scatter）

观察两个数值变量之间的相关性、聚集与离群点，可扩展成气泡图。

**形态**：points 散点 / bubble 气泡

**数据结构**

```
数组，每个系列一组点：
[
  { "id": "A 组", "data": [{ "x": 12, "y": 34 }, { "x": 20, "y": 41 }] }
]
气泡图时给每个点加 size 字段：[{ "x": 12, "y": 34, "size": 8 }]。
也支持扁平记录 [{ "x": 12, "y": 34, "group": "A 组" }]。
```

**最小示例**：`mint render scatter -o scatter.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `pointSize` | number | `10` | 点大小 |
| `seriesBy` | string | — | 扁平记录下用于分组的字段名 |
| `xLegend` | string | — | X 轴标题 |
| `yLegend` | string | — | Y 轴标题 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：散点、气泡图、bubble、相关性

### `parallel-coordinates` — 平行坐标图（ParallelCoordinates）

把多个数值维度并排放置，每个对象一条折线，观察多维聚类与离群。

**形态**：parallel 平行坐标

**数据结构**

```
每一行一条记录，所有数值字段自动作为维度：
[
  { "name": "城市A", "房价": 82, "通勤": 34, "绿化": 61 },
  { "name": "城市B", "房价": 65, "通勤": 48, "绿化": 73 }
]
可用 variables 选项指定参与绘制的维度，逗号分隔。
```

**最小示例**：`mint render parallel-coordinates -o parallel-coordinates.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `variables` | array | — | 参与绘制的字段，逗号分隔；省略则用全部数值字段 |
| `lineWidth` | number | `2` | 线宽 |
| `opacity` | number | `0.55` | 线条不透明度 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：平行坐标、parallel、多维图

### `architecture` — 架构图（Architecture Diagram）

把系统画成分层方块图：层是横向的带子，方块是组件，箭头表示组件之间的调用或依赖。

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
nodes 里的每一项可以是字符串（id 即名称）或对象；对象支持 label 显示名、description 小字说明。
layers 也可以写成 { "接入层": [...], "服务层": [...] }；
或者省略 layers，直接给 nodes，用每个节点的 layer / group 字段自动分层。
edges 支持 from/to（也可写 source/target），label 是连线上的小标签。
```

**最小示例**：`mint render architecture -o architecture.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `direction` | string | `"vertical"` | 分层方向：纵向从上到下，横向从左到右（vertical / horizontal） |
| `edgeStyle` | string | `"curve"` | 连线样式（curve / straight / elbow） |
| `showLayers` | boolean | `true` | 是否显示层名的底衬色带 |
| `showDescriptions` | boolean | `true` | 是否显示方块里的小字说明 |
| `edgeLabels` | boolean | `true` | 是否显示连线上的标签 |
| `nodeGap` | number | `26` | 同一层内方块的间距 |
| `layerGap` | number | `36` | 层与层之间的间距 |
| `detourGap` | number | `30` | 同层连线需要绕过中间方块时向外绕行的距离，0 表示不绕行 |
| `minNodeWidth` | number | `128` | 方块最小宽度 |
| `maxNodeWidth` | number | `260` | 方块最大宽度，超出用省略号截断 |
| `labelSize` | number | `15` | 方块主标题字号 |
| `descriptionSize` | number | `12` | 方块说明文字号 |
| `edgeLabelSize` | number | `11` | 连线标签字号 |
| `lineWidth` | number | `1.6` | 连线粗细 |
| `cornerRadius` | number | `10` | 方块圆角半径 |

**别名**：架构图、系统架构图、架构、architecture、arch、topology、拓扑图、部署图

## 分布

### `heatmap` — 热力图（HeatMap）

用颜色深浅表现两个维度交叉后的数值强度，快速定位高低分布。

**形态**：matrix 热力 / heat strip

**数据结构**

```
两种写法：
1) 行 × 列矩阵：
[
  { "id": "周一", "data": [{ "x": "上午", "y": 12 }, { "x": "下午", "y": 20 }] },
  { "id": "周二", "data": [{ "x": "上午", "y": 15 }, { "x": "下午", "y": 25 }] }
]
2) 长表 [{ "row": "周一", "col": "上午", "value": 12 }]，会自动转成矩阵。
```

**最小示例**：`mint render heatmap -o heatmap.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `rowBy` | string | `"row"` | 长表模式下的行字段名 |
| `colBy` | string | `"col"` | 长表模式下的列字段名 |
| `valueBy` | string | `"value"` | 长表模式下的数值字段名 |
| `cellBorder` | boolean | `true` | 是否显示单元格白边 |
| `valueLabel` | boolean | `false` | 是否在格子里标数值 |
| `xLegend` | string | — | X 轴标题 |
| `yLegend` | string | — | Y 轴标题 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：热力、热力图、矩阵图、heat map

### `calendar` — 日历热力图（Calendar）

按天着色，展示一整年的活跃度分布与周期性节律。

**形态**：calendar 日历

**数据结构**

```
[{ "day": "2025-01-01", "value": 12 }]，也接受 { "2025-01-01": 12 }
from / to 可省略，会按数据里的最早/最晚日期自动确定范围。
```

**最小示例**：`mint render calendar -o calendar.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `from` | string | — | 起始日期 YYYY-MM-DD |
| `to` | string | — | 结束日期 YYYY-MM-DD |
| `direction` | string | `"horizontal"` | 排列方向（horizontal / vertical） |
| `emptyColor` | string | `"#f1f5f9"` | 无数据日期的底色 |
| `yearLegend` | boolean | `true` | 是否显示年份标签 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：日历图、日历热力、贡献图、calendar、github图

## 层级

### `treemap` — 矩形树图（TreeMap）

用矩形面积表达占比，支持多层嵌套，适合看大盘构成。

**形态**：squarify 方形 / sliceDice 切片

**数据结构**

```
三种写法：
1) 嵌套：{ "name": "总计", "children": [{ "name": "华东", "value": 300 }] }
2) 平铺：[{ "name": "华东", "value": 300 }]（会自动套一个根节点）
3) 路径：[{ "path": "线上/华东/上海", "value": 120 }]（用 / 自动建树）
```

**最小示例**：`mint render treemap -o treemap.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `tile` | string | `"squarify"` | 切分算法（squarify / slice / dice / sliceDice / binary） |
| `innerPadding` | number | `3` | 子节点内边距 |
| `outerPadding` | number | `4` | 根节点外边距 |
| `labelSkipSize` | number | `26` | 小于该面积的矩形不显示标签 |
| `root` | string | `"总计"` | 自动生成根节点时的名字 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：树图、矩形树图、treemap、占比方块

### `sunburst` — 旭日图（Sunburst）

用同心环表达多层级的构成，从内到外逐层展开。

**形态**：sunburst 旭日

**数据结构**

```
与矩形树图一致，同为层级结构：
{ "name": "总计", "children": [{ "name": "线上", "children": [{ "name": "华东", "value": 320 }] }] }
也接受 [{ "name": "华东", "value": 320 }] 或 [{ "path": "线上/华东", "value": 120 }]。
```

**最小示例**：`mint render sunburst -o sunburst.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `cornerRadius` | number | `3` | 扇区圆角 |
| `borderWidth` | number | `1` | 扇区描边宽度 |
| `root` | string | `"总计"` | 自动生成根节点时的名字 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：旭日图、sunburst、环形层级

### `icicle` — 冰柱图（Icicle）

横向分层的矩形层级图，每层代表一级，宽度代表占比。

**形态**：vertical 纵向 / horizontal 横向

**数据结构**

```
与矩形树图一致：
{ "name": "总计", "children": [{ "name": "线上", "children": [{ "name": "华东", "value": 320 }] }] }
```

**最小示例**：`mint render icicle -o icicle.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `orientation` | string | `"vertical"` | 展开方向（vertical / horizontal） |
| `borderWidth` | number | `1` | 矩形描边宽度 |
| `labelSkipWidth` | number | `24` | 过窄的矩形不显示标签 |
| `root` | string | `"总计"` | 自动生成根节点时的名字 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：冰柱图、icicle、层级条形

### `circle-packing` — 圆形打包图（CirclePacking）

用嵌套圆的面积表达层级占比，视觉柔和，适合摘要与封面。

**形态**：packed 打包

**数据结构**

```
与矩形树图一致：
{ "name": "总计", "children": [{ "name": "华东", "value": 320 }] }
也接受 [{ "name": "华东", "value": 320 }] 或 [{ "path": "线上/华东", "value": 120 }]。
```

**最小示例**：`mint render circle-packing -o circle-packing.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `padding` | number | `4` | 圆之间的间距 |
| `labelSkipRadius` | number | `12` | 半径小于该值的圆不显示标签 |
| `root` | string | `"总计"` | 自动生成根节点时的名字 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：圆打包、气泡图、气泡树、bubble tree

## 流向

### `funnel` — 漏斗图（Funnel）

展示多级流程中每一步的留存与流失，适合转化率分析。

**形态**：funnel 漏斗

**数据结构**

```
按流程顺序排列：
[
  { "id": "访问", "label": "访问", "value": 12000 },
  { "id": "注册", "label": "注册", "value": 4800 },
  { "id": "下单", "label": "下单", "value": 1900 }
]
也支持 { "访问": 12000, "注册": 4800 } 或 [["访问", 12000], ["注册", 4800]]。
```

**最小示例**：`mint render funnel -o funnel.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `spacing` | number | `4` | 层与层的间距 |
| `shapeBlending` | number | `0.66` | 形状融合程度 0~1 |
| `valueLabel` | boolean | `true` | 是否显示数值 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：漏斗、转化、funnel、转化率

### `sankey` — 桑基图（Sankey）

用带宽表示流向的规模，展示来源到去向的分配路径。

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

**最小示例**：`mint render sankey -o sankey.png`（不传 --data 时用内置示例数据）

**专属选项**

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `layout` | string | `"horizontal"` | 布局方向（horizontal / vertical） |
| `nodeThickness` | number | `16` | 节点条厚度 |
| `nodeSpacing` | number | `18` | 节点间距 |
| `linkOpacity` | number | `0.28` | 连线透明度 |
| `gradient` | boolean | `true` | 连线是否使用渐变 |
| `legend` | boolean | `true` | 是否显示图例 |
| `valueFormat` | string | `"number"` | 数值格式化方式（number / percent / compact） |
| `decimals` | number | — | 小数位数，省略则用千分位整数 |
| `valuePrefix` | string | — | 数值前缀，如 ¥ |
| `valueSuffix` | string | — | 数值后缀，如 万 |

**别名**：桑基图、sankey、流向图、流量图

## 调色板

| id | 名称 | 说明 |
|----|------|------|
| `mint` | 薄荷 | 青绿主色，清爽、适合增长与产品类数据 |
| `indigo` | 靛蓝 | 偏商务的蓝紫主色，适合报告与汇报 |
| `sunset` | 日落 | 暖色渐变，适合营销与创意主题 |
| `ocean` | 海洋 | 冷色系，适合流量、渠道与地理数据 |
| `forest` | 森林 | 自然绿色系，适合生态、健康与可持续主题 |
| `candy` | 糖果 | 高饱和糖果色，适合面向大众的轻量内容 |
| `mono` | 单色 | 同色系灰阶，适合黑白印刷或极简报告 |
