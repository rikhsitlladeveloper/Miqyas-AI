package uz.metrx.app.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import java.io.File

/**
 * Photos of workspaces and the Measure page's pictures. The prototype keeps each as JPEG data in the item, at most
 * 1280 px on the long side, 72 % quality (78 % from the live camera); here each is a file ("photos/<id>.jpg").
 */
object PhotoFiles {
    private fun dir(ctx: Context) = File(ctx.filesDir, "photos").apply { mkdirs() }

    fun file(ctx: Context, src: String) = File(ctx.filesDir, src)

    /** Saves [bmp] (made smaller first when needed) and returns its name and its size. */
    fun save(ctx: Context, id: String, bmp: Bitmap, quality: Int = 72): Triple<String, Int, Int>? = runCatching {
        val b = shrink(bmp, 1280)
        val f = File(dir(ctx), "$id.jpg")
        f.outputStream().use { b.compress(Bitmap.CompressFormat.JPEG, quality, it) }
        Triple("photos/${f.name}", b.width, b.height)
    }.getOrNull()

    /** A picture the phone gave us (gallery or camera app), upright as taken, at most 1280 px on its long side. */
    fun decode(ctx: Context, uri: Uri): Bitmap? = runCatching {
        val cr = ctx.contentResolver
        val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        cr.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, o) }
        if (o.outWidth <= 0 || o.outHeight <= 0) return null
        var s = 1; while (maxOf(o.outWidth, o.outHeight) / (s * 2) >= 1280) s *= 2
        val raw = cr.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = s }) } ?: return null
        val deg = runCatching {
            cr.openInputStream(uri)?.use { ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL) }
        }.getOrNull().let { when (it) { ExifInterface.ORIENTATION_ROTATE_90 -> 90f; ExifInterface.ORIENTATION_ROTATE_180 -> 180f; ExifInterface.ORIENTATION_ROTATE_270 -> 270f; else -> 0f } }
        val up = if (deg == 0f) raw else Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, Matrix().apply { postRotate(deg) }, true)
        shrink(up, 1280)
    }.getOrNull()

    fun load(ctx: Context, src: String, maxW: Int = 0): Bitmap? = runCatching {
        val f = file(ctx, src); if (!f.exists()) return null
        if (maxW <= 0) return BitmapFactory.decodeFile(f.path)
        val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }; BitmapFactory.decodeFile(f.path, o)
        var s = 1; while (o.outWidth / (s * 2) >= maxW) s *= 2
        BitmapFactory.decodeFile(f.path, BitmapFactory.Options().apply { inSampleSize = s })
    }.getOrNull()

    private fun shrink(b: Bitmap, max: Int): Bitmap {
        val k = minOf(1f, max.toFloat() / maxOf(b.width, b.height))
        return if (k >= 1f) b else Bitmap.createScaledBitmap(b, (b.width * k).toInt().coerceAtLeast(1), (b.height * k).toInt().coerceAtLeast(1), true)
    }

    /** Removes photos nothing refers to any more (deleted items and pictures, once their Undo has passed). */
    fun sweep(ctx: Context, used: Set<String>) {
        val names = used.map { File(it).name }.toSet()
        dir(ctx).listFiles()?.forEach { if (it.name !in names) it.delete() }
    }
}
