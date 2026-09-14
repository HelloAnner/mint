import { mkdirSync, writeFileSync } from 'node:fs'
import { CHARTS } from '../src/charts'
import { renderChart } from '../src/core/render'

mkdirSync('out/examples', { recursive: true })

for (const chart of CHARTS) {
  const result = await renderChart({
    definition: chart,
    data: chart.example.data,
    options: chart.example.options,
    title: chart.name,
    subtitle: chart.description,
    footnote: 'mint · 示例数据',
    width: 1000,
    height: 620,
    scale: 2,
    theme: 'light',
    palette: 'mint',
    format: 'png',
  })
  writeFileSync(`out/examples/${chart.id}.png`, result.png!)
  writeFileSync(`out/examples/${chart.id}.svg`, result.svg)
  console.log('wrote', chart.id)
}
