import type { ChartDefinition } from '../core/types'

import bar from './bar'
import line from './line'
import stream from './stream'
import pie from './pie'
import radar from './radar'
import scatter from './scatter'
import heatmap from './heatmap'
import treemap from './treemap'
import sunburst from './sunburst'
import icicle from './icicle'
import circlePacking from './circle-packing'
import funnel from './funnel'
import bump from './bump'
import calendar from './calendar'
import sankey from './sankey'
import waffle from './waffle'
import radialBar from './radial-bar'
import bullet from './bullet'
import marimekko from './marimekko'
import parallelCoordinates from './parallel-coordinates'
import architecture from './architecture'
import flowchart from './flowchart'
import sequence from './sequence'

/** 所有内置图表。顺序即 mint list 的展示顺序。 */
export const CHARTS: readonly ChartDefinition[] = [
  bar,
  line,
  stream,
  pie,
  radar,
  scatter,
  heatmap,
  treemap,
  sunburst,
  icicle,
  circlePacking,
  funnel,
  bump,
  calendar,
  sankey,
  waffle,
  radialBar,
  bullet,
  marimekko,
  parallelCoordinates,
  architecture,
  flowchart,
  sequence,
]
