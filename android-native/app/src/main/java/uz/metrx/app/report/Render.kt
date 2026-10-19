package uz.metrx.app.report

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfDocument
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.font.createFontFamilyResolver
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.core.content.FileProvider
import uz.metrx.app.data.Project
import uz.metrx.app.data.Quote
import uz.metrx.app.data.Snap
import uz.metrx.app.data.ViewFiles
import java.io.File

/** Measures the report's text outside any screen: the app's fonts at one pixel per page pixel. */
fun reportMeasurer(ctx: Context) = TextMeasurer(createFontFamilyResolver(ctx), Density(1f), LayoutDirection.Ltr, 64)

/** 3D view pictures for the pages, decoded at about twice their size on the page (keeps the PDF small). */
fun viewLoader(ctx: Context): (String) -> ImageBitmap? {
    val cache = HashMap<String, ImageBitmap?>()
    // photos fill the page's width, so they keep more of their pixels than the half-width 3D views
    return { img -> cache.getOrPut(img) { ViewFiles.load(ctx, img, if (img.startsWith("photos/") || "/ph-" in img) 1000 else 520)?.asImageBitmap() } }
}

/** One page as a picture [w] pixels wide (the preview and the zoomed viewer). */
fun pageBitmap(page: RPage, w: Int): ImageBitmap {
    val h = (w * PAGE_H / PAGE_W).toInt()
    val bmp = ImageBitmap(w, h)
    val k = w / PAGE_W
    CanvasDrawScope().draw(Density(1f), LayoutDirection.Ltr, Canvas(bmp), Size(w.toFloat(), h.toFloat())) { scale(k, k, androidx.compose.ui.geometry.Offset.Zero) { page.draw(this) } }
    return bmp
}

/** All pages as one PDF, one point per page pixel, text and drawings as vectors. */
fun writePdf(pages: List<RPage>, out: File) {
    val doc = PdfDocument()
    try {
        pages.forEachIndexed { i, pg ->
            val p = doc.startPage(PdfDocument.PageInfo.Builder(PAGE_W.toInt(), PAGE_H.toInt(), i + 1).create())
            CanvasDrawScope().draw(Density(1f), LayoutDirection.Ltr, Canvas(p.canvas), Size(PAGE_W, PAGE_H)) { pg.draw(this) }
            doc.finishPage(p)
        }
        out.parentFile?.mkdirs()
        out.outputStream().use { doc.writeTo(it) }
    } finally { doc.close() }
}

/** The PDF's file name (prototype A.share): project name and "Qoralama" or "Taklif №n", no awkward characters. */
fun pdfName(name: String, suffix: String) = (name + "_" + suffix).replace(Regex("[\\s,№./\\\\:*?\"<>|]+"), "_") + ".pdf"

/** Writes the PDF into the app's cache (only the latest one is kept there). */
fun pdfFile(ctx: Context, pages: List<RPage>, fname: String): File {
    val dir = File(ctx.cacheDir, "pdf").apply { mkdirs(); listFiles()?.forEach { it.delete() } }
    return File(dir, fname).also { writePdf(pages, it) }
}

/** Opens the phone's share sheet for the PDF (Telegram, WhatsApp, Files, print…). */
fun sharePdf(ctx: Context, f: File, title: String) {
    val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".files", f)
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "application/pdf"; putExtra(Intent.EXTRA_STREAM, uri); putExtra(Intent.EXTRA_SUBJECT, f.nameWithoutExtension)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    ctx.startActivity(Intent.createChooser(send, title).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
}

/**
 * Freezes the report as quote № [no]: the 3D pictures and photos are copied next to the quote, so removing a view later
 * from the room (or the room itself, or a photo) leaves the issued quote as it was.
 */
fun freezeQuote(ctx: Context, p: Project, sn: Snap, no: Int, now: Long): Quote {
    val dir = "quotes/${p.id}-$no"
    val rooms = sn.rooms.map { sr ->
        sr.copy(room = sr.room.copy(views = sr.room.views.map { v ->
            val src = ViewFiles.file(ctx, v.img); val dst = File(ctx.filesDir, "$dir/${v.id}.jpg")
            runCatching { dst.parentFile?.mkdirs(); src.copyTo(dst, overwrite = true) }
            v.copy(img = "$dir/${v.id}.jpg")
        }))
    }
    // the photos too, so a photo deleted or changed later leaves the quote as it was issued
    val extras = sn.extras.map { x ->
        val src = x.src ?: return@map x
        val dst = File(ctx.filesDir, "$dir/ph-${x.id}.jpg")
        runCatching { dst.parentFile?.mkdirs(); ViewFiles.file(ctx, src).copyTo(dst, overwrite = true) }
        x.copy(src = "$dir/ph-${x.id}.jpg")
    }
    val frozen = sn.copy(rooms = rooms, extras = extras)
    return Quote(no, now, frozen, fingerprint(sn), if (sn.furniture.isNotEmpty()) sn.ftotal else snapTotal(sn).toString())
}
