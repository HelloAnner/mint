import { readFileSync } from 'node:fs'
import { Resvg, initWasm } from '@resvg/resvg-wasm'
import wasmFile from '@resvg/resvg-wasm/index_bg.wasm' with { type: 'file' }
import type { FontChoice } from './fonts'

/**
 * resvg 编译成 WASM 后不依赖任何原生模块，因此可以被 bun 直接打进单文件二进制，
 * 用户机器上不需要装浏览器或 cairo。
 */
let wasmReady: Promise<void> | undefined

function ensureWasm(): Promise<void> {
  if (!wasmReady) {
    wasmReady = (async () => {
      const bytes = new Uint8Array(await Bun.file(wasmFile).arrayBuffer())
      await initWasm(bytes)
    })()
  }
  return wasmReady
}

let cachedFont: { path: string; buffer: Uint8Array } | undefined

function loadFont(path: string): Uint8Array {
  if (cachedFont?.path !== path) {
    cachedFont = { path, buffer: new Uint8Array(readFileSync(path)) }
  }
  return cachedFont.buffer
}

export interface RasterOptions {
  /** 输出缩放倍数，2 表示 2x 高清 */
  scale: number
  background: string
  font: FontChoice
}

export async function rasterize(svg: string, options: RasterOptions): Promise<Uint8Array> {
  await ensureWasm()
  const { scale, background, font } = options

  const resvg = new Resvg(svg, {
    background,
    font: {
      fontBuffers: [loadFont(font.path)],
      defaultFontFamily: font.family,
      loadSystemFonts: false,
    },
    fitTo: { mode: 'zoom', value: scale },
  })

  return resvg.render().asPng()
}
