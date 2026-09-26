# 常见任务配方

按「用户想干什么」组织。每条都给出可直接执行的命令，把 `<id>` 换成实际数据源。

## 1. 一句话出图（先给用户看效果）

```bash
mint render bar -o bar.png          # 不传 --data 时用该图内置示例数据
```

只要用户没说清用哪张图，先 `mint list` 扫一遍分类，再用 `mint info <chart>` 确认数据结构。

## 2. 从 CSV 起步

mint 只吃 JSON，所以先把 CSV 转成数组：

```bash
python3 - <<'PY' > /tmp/data.json
import csv, json, sys
rows = list(csv.DictReader(open("data.csv")))
for r in rows:
    for k, v in r.items():
        try: r[k] = float(v) if "." in v else int(v)
        except (ValueError, TypeError): pass
print(json.dumps(rows, ensure_ascii=False))
PY
mint render bar -d /tmp/data.json -o bar.png
```

## 3. 论文/报告用图（双栏满宽、矢量、色盲安全）

```bash
mint render line -d trend.json \
  --title "干预前后效应值变化" --subtitle "n = 240" --footnote "数据来源：2025 年队列" \
  --palette okabe --format both --width 7 -o fig2
# → fig2.png (2100×1305 @300dpi) + fig2.svg（投稿用矢量图）
```

- 单栏图：`--width 3.5 --height 2.6`
- 幻灯片：`--width 10 --dpi 150`
- 黑白打印：`--palette greys`

## 4. 一页多图（同一套配色与尺寸）

```jsonc
{
  "defaults": { "width": 3.5, "height": 2.6, "palette": "npg", "style": "professional" },
  "charts": [
    { "chart": "bar",    "data_file": "a.json", "title": "各渠道 ROI", "out": "a.png" },
    { "chart": "line",   "data_file": "b.json", "title": "留存趋势",   "out": "b.png" },
    { "chart": "boxplot","data_file": "c.json", "title": "分组分布",   "out": "c.png" }
  ]
}
```

```bash
mint batch panel.json --outdir out/
```

## 5. 直接标注数值，少用图例

专业图表的原则是「让读者少来回找」：

```bash
mint render bar -d d.json --set valueLabel=true -o bar.png     # 柱顶直标数值
mint render line -d d.json --set labelSeries=end -o line.png    # 系列名贴在右端
mint render pie -d d.json --set showPercent=true --set showValue=true -o pie.png
```

## 6. 类别很多、标签挤不下

```bash
mint render bar -d many.json --set layout=horizontal --set sort=desc -o bar.png   # 横向 + 降序
mint render lollipop -d many.json --set sort=desc -o lollipop.png                 # 更透气
mint render heatmap -d matrix.json -o heatmap.png                                  # 二维网格
```

## 7. 相关矩阵 / 二维分布

`heatmap` 吃长表 `[{x,y,value}]` 或宽表 `[{行名, 列1:值, 列2:值}]`：

```bash
mint render heatmap -d corr.json --set xLegend="指标" --set yLegend="指标" --set ramp=rdbu -o corr.png
```

## 8. 时间分布（一年每天）

```bash
mint render calendar -d daily.json --title "2025 年每日活跃" --palette blue -o calendar.png
```

## 9. 层级占比

```bash
mint render treemap -d tree.json -o treemap.png     # 递归 {name, value, children:[...]}
mint render sunburst -d tree.json -o sunburst.png
```

## 10. 流程 / 时序 / 架构

```bash
mint render flowchart -d flow.json -o flow.png          # {nodes:[{id,label,shape}], edges:[{from,to,label}]}
mint render sequence  -d seq.json  -o seq.png           # {participants:[...], messages:[{from,to,label,type}]}
mint render architecture -d arch.json -o arch.png
```

这几张是自绘图形，**画布比例会直接影响观感**：纵向流程用 `--width 5`，时序图用 `--width 7`。

## 11. 只要图不要标题（自己排版）

```bash
mint render bar -d d.json -o bar.png        # 不传 --title/--subtitle 就只有图
mint render bar -d d.json -o bar.svg -f svg # SVG 里的文字可编辑，方便二次排版
```

## 12. 交付前的清理纪律

```bash
# 临时数据、spec、预览图全部放 /tmp 并在交付前删掉
mint render bar -d /tmp/mint-data.json -o /tmp/mint-preview.png
# 交付：只留下最终图片
cp /tmp/mint-preview.png ./final.png && rm -f /tmp/mint-data.json /tmp/mint-preview.png
```

能不走磁盘就别走：`cat data.json | mint render bar -d - -o bar.png`。
