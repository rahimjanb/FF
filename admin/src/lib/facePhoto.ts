// Face photos for the Hikvision terminals, prepared in the browser before upload.

/** What the terminals accept: JPEG up to 200 KB; at least 240 px on the short side for a usable face model. */
export const MAX_FACE_BYTES = 200 * 1024
export const MIN_FACE_SIDE = 240
const MAX_SIDE = 800

/** Loads an image file with EXIF orientation applied. */
async function loadImage(file: File): Promise<ImageBitmap> {
  try { return await createImageBitmap(file, { imageOrientation: 'from-image' }) }
  catch { throw new Error('Не удалось открыть файл. Выберите фото JPEG, PNG или HEIC/WebP, которое открывает браузер.') }
}

function toJpeg(canvas: HTMLCanvasElement, quality: number): Promise<Blob> {
  return new Promise((resolve, reject) =>
    canvas.toBlob(b => (b ? resolve(b) : reject(new Error('Не удалось подготовить фото.'))), 'image/jpeg', quality))
}

/**
 * Prepares a photo for the terminals in the browser: longer side up to 800 px, JPEG, quality (and if needed size)
 * lowered until it fits into 200 KB.
 */
export async function prepareFacePhoto(file: File): Promise<Blob> {
  const image = await loadImage(file)
  if (Math.min(image.width, image.height) < MIN_FACE_SIDE)
    throw new Error(`Фото слишком маленькое: нужно не меньше ${MIN_FACE_SIDE} пикселей по короткой стороне.`)
  let scale = Math.min(1, MAX_SIDE / Math.max(image.width, image.height))
  const canvas = document.createElement('canvas')
  for (;;) {
    canvas.width = Math.round(image.width * scale)
    canvas.height = Math.round(image.height * scale)
    const ctx = canvas.getContext('2d')
    if (!ctx) throw new Error('Браузер не может обработать фото.')
    ctx.drawImage(image, 0, 0, canvas.width, canvas.height)
    for (const q of [0.9, 0.82, 0.74, 0.66, 0.58]) {
      const blob = await toJpeg(canvas, q)
      if (blob.size <= MAX_FACE_BYTES) return blob
    }
    const next = scale * 0.85
    if (Math.min(image.width, image.height) * next < MIN_FACE_SIDE) throw new Error('Не удалось уместить фото в 200 КБ. Выберите другое фото.')
    scale = next
  }
}
