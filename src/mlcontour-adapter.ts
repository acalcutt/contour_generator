import sharp from 'sharp'
import { default as mlcontour } from '../node_modules/maplibre-contour/dist/index.mjs'
import type { DemTile, Encoding, GlobalContourTileOptions } from '../node_modules/maplibre-contour/dist/types'

/**
 * Processes image data from a blob.
 * @param {Blob} blob - The image data as a Blob.
 * @param {Encoding} encoding - The encoding to use when decoding.
 * @param {AbortController} abortController - An AbortController to cancel the image processing.
 * @returns {Promise<DemTile>} - A Promise that resolves with the processed image data, or throws if aborted.
 * @throws If an error occurs during image processing.
 */
export async function GetImageData(blob: Blob, encoding: Encoding, abortController: AbortController): Promise<DemTile> {
  if (abortController?.signal?.aborted) {
    throw new Error('Image processing was aborted.')
  }
  try {
    const buffer = await blob.arrayBuffer()
    const image = sharp(Buffer.from(buffer))

    if (abortController?.signal?.aborted) {
      throw new Error('Image processing was aborted.')
    }

    const { data, info } = await image
      .ensureAlpha() // Ensure RGBA output
      .raw()
      .toBuffer({ resolveWithObject: true })

    if (abortController?.signal?.aborted) {
      throw new Error('Image processing was aborted.')
    }
    const parsed = mlcontour.decodeParsedImage(info.width, info.height, encoding, data as any as Uint8ClampedArray)
    if (abortController?.signal?.aborted) {
      throw new Error('Image processing was aborted.')
    }

    return parsed
  } catch (error) {
    console.error('Error processing image:', error)
    if (error instanceof Error) {
      throw error
    }
    throw new Error('An unknown error has occurred.')
  }
}

export function extractZXYFromUrlTrim(url: string): { z: number; x: number; y: number } | null {
  // 1. Find the index of the last `/`
  const lastSlashIndex = url.lastIndexOf('/')
  if (lastSlashIndex === -1) {
    return null // URL does not have any slashes
  }

  const segments = url.split('/')
  if (segments.length <= 3) {
    return null
  }

  const ySegment = segments[segments.length - 1]
  const xSegment = segments[segments.length - 2]
  const zSegment = segments[segments.length - 3]

  const lastDotIndex = ySegment.lastIndexOf('.')
  const cleanedYSegment = lastDotIndex === -1 ? ySegment : ySegment.substring(0, lastDotIndex)

  // 3. Attempt to parse segments as numbers
  const z = parseInt(zSegment, 10)
  const x = parseInt(xSegment, 10)
  const y = parseInt(cleanedYSegment, 10)

  if (isNaN(z) || isNaN(x) || isNaN(y)) {
    return null // Conversion failed, invalid URL format
  }

  return { z, x, y }
}

//This getOptionsForZoom function should be exported by mlcontour but I couldn't figure out how to access it so i put it here for now.
export function getOptionsForZoom(options: GlobalContourTileOptions, zoom: number): any {
  const { thresholds, ...rest } = options

  let levels: number[] = []
  let maxLessThanOrEqualTo: number = -Infinity

  Object.entries(thresholds).forEach(([zString, value]) => {
    const z = Number(zString)
    if (z <= zoom && z > maxLessThanOrEqualTo) {
      maxLessThanOrEqualTo = z
      levels = typeof value === 'number' ? [value] : value
    }
  })

  return {
    levels,
    ...rest,
  }
}
