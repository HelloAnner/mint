# mint 常用配方

按「拿到一份数据 → 该跑什么命令」组织。命令都可直接复制执行。

> **清理提醒**：下面的例子为了可读性会写 `revenue.json` 这样的数据文件。
> 真实使用时，能改成 stdin（`--data -`）就别落盘；必须落盘的数据与 spec 一律放
> `mktemp -d` 出来的临时目录，并用 `trap 'rm -rf "$tmp"' EXIT` 兜底。
> **交付时只保留最终图片，其余全部删掉。** 详见 SKILL.md 的「临时文件与清理」。

## 1. 季度/月度对比（分组柱状图）

数据 `revenue.json`：

```json
[
  { "quarter": "Q1", "华东": 128, "华北": 96, "华南": 74 },
  { "quarter": "Q2", "华东": 152, "华北": 108, "华南": 88 },
  { "quarter": "Q3", "华东": 141, "华北": 124, "华南": 103 },
  { "quarter": "Q4", "华东": 187, "华北": 139, "华南": 121 }
]
```

```bash
mint render bar --data revenue.json \
  --title "各区域季度营收" --subtitle "单位：百万元" \
  --set yLegend="营收（百万元）" --set xLegend="2025 财年" \
  --set valueSuffix= --palette indigo \
  -o revenue.png
```

**想强调总量而不是对比**：改成堆叠 `--set groupMode=stacked`。
**类别名称很长**：加 `--set layout=horizontal` 换成横向条形图。

## 2. 逐级转化漏斗

```json
[
  { "id": "visit",  "label": "访问落地页", "value": 12000 },
  { "id": "signup", "label": "注册账号",   "value": 4800 },
  { "id": "active", "label": "完成激活",   "value": 2600 },
  { "id": "order",  "label": "首次下单",   "value": 1900 }
]
```

```bash
mint render funnel --data funnel.json \
  --title "注册转化漏斗" --subtitle "2025 年 3 月" \
  --set valueFormat=number --scale 2 -o funnel.png
```

把每一步的 `value` 换算成相对上一步的百分比，就能在同一张图里直接读转化率。

## 3. 渠道占比（环形图）

```bash
# 对象形式的数据也能直接吃
echo '{ "搜索广告": 348, "社交媒体": 266, "合作推荐": 184, "内容营销": 143, "线下活动": 82 }' | \
  mint render pie --data - --title "获客渠道占比" --set donut=true -o channel.png
```

扇区超过 6 个时建议换 `treemap`，面积比角度更容易比较。

## 4. 时间趋势（折线 + 面积）

```json
[
  { "id": "Web", "data": [{ "x": "1月", "y": 42 }, { "x": "2月", "y": 51 }, { "x": "3月", "y": 68 }] },
  { "id": "App", "data": [{ "x": "1月", "y": 30 }, { "x": "2月", "y": 38 }, { "x": "3月", "y": 52 }] }
]
```

```bash
mint render line --data dau.json --title "日活用户趋势" \
  --set area=true --set curve=monotoneX --set yLegend="DAU（万）" \
  -o dau.png
```

## 5. 结构随时间的漂移（堆叠面积图）

扁平记录，每个时间点一行：

```bash
mint render stream --data traffic.json --title "流量来源结构" \
  --set yLegend="访问量（万次）" -o traffic.png

# 想改看「占比」而不是绝对量：
mint render stream --data traffic.json --set offsetType=expand -o traffic-share.png
```

## 6. 埋点时段热力（热力图）

长表格式最省事，mint 会自动转成矩阵：

```json
[
  { "row": "周一", "col": "上午", "value": 12 },
  { "row": "周一", "col": "下午", "value": 20 }
]
```

```bash
mint render heatmap --data heat.json --title "一周活跃时段分布" \
  --set valueLabel=true -o heat.png
```

## 7. 多维能力对标（雷达图）

```bash
mint render radar --data capability.json \
  --title "产品能力对标" --set fillOpacity=0.2 -o radar.png
```

维度控制在 3~8 个；超过 8 个改用 `parallel-coordinates`。

## 8. KPI 达成情况（子弹图）

```json
[
  { "id": "revenue", "title": "营收", "ranges": [150, 200, 260], "measures": [187], "markers": [200] },
  { "id": "users",   "title": "新增用户", "ranges": [80, 120, 170], "measures": [142], "markers": [150] }
]
```

```bash
mint render bullet --data kpi.json --title "Q4 关键指标达成" -o kpi.png
```

`ranges` 是由小到大的三段区间（差/中/优），`markers` 是目标值。

## 9. 名称此消彼长（排名变化图）

```bash
mint render bump --data ranking.json --title "Top 4 产品排名变化" --set yLegend="名次" -o bump.png
mint render bump --data ranking.json --set variant=area -o bump-area.png   # 面积式
```

## 10. 一年活跃节律（日历热力图）

```bash
mint render calendar --data daily.json --title "全年活跃度" \
  --set from=2025-01-01 --set to=2025-12-31 -o calendar.png
```

## 11. 一页报告的多图批量出图

`report.json`：

```jsonc
{
  "defaults": { "palette": "indigo", "theme": "light", "width": 1280, "height": 760, "scale": 2 },
  "charts": [
    { "chart": "bar",    "dataFile": "revenue.json",  "out": "out/01-revenue.png",
      "title": "各区域季度营收", "subtitle": "单位：百万元" },
    { "chart": "line",   "dataFile": "dau.json",      "out": "out/02-dau.png",
      "title": "日活用户趋势" },
    { "chart": "funnel", "dataFile": "funnel.json",   "out": "out/03-funnel.png",
      "title": "注册转化漏斗" },
    { "chart": "pie",    "dataFile": "channel.json",  "out": "out/04-channel.png",
      "title": "获客渠道占比" }
  ]
}
```

```bash
mkdir -p out && mint batch report.json
```

## 12. 深色主题 / 论文灰阶

```bash
# 深色底，用于深色 PPT
mint render bar --data revenue.json --theme dark --palette sunset -o dark.png

# 黑白印刷，用单色板的灰阶
mint render bar --data revenue.json --palette mono --theme light -o print.png

# 论文投稿要矢量图
mint render line --data dau.json --format svg -o figure2.svg
```

## 13. 让 AI 自己挑图

不确定用哪种图时，把数据的形状描述清楚再让 AI 决策：

```bash
mint list --json | head          # 拿到全部图表 id、分类、说明
mint info treemap --json         # 看某张图的数据结构与全部选项
```

选择顺序建议：**先定「比较 / 趋势 / 构成 / 分布 / 层级 / 流向 / 关系」是哪一类，
再在该类里挑**。同一类里优先选能直接读出数值的那张。
