/** @nivo/parallel-coordinates 没有随包发布类型声明 */
declare module '@nivo/parallel-coordinates' {
  import type { ComponentType } from 'react'
  export const ParallelCoordinates: ComponentType<Record<string, unknown>>
  export const ResponsiveParallelCoordinates: ComponentType<Record<string, unknown>>
}

declare module '*.wasm' {
  const path: string
  export default path
}

declare module '*.md' {
  const path: string
  export default path
}
