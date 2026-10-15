package uz.metrx.app.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File

/**
 * Pictures of 3D views added to the report. The prototype keeps them in the project as JPEG data;
 * here each is a JPEG file in the app's own storage and the room keeps its name ([View3D.img] = "views/<id>.jpg").
 */
object ViewFiles {
    private fun dir(ctx: Context) = File(ctx.filesDir, "views").apply { mkdirs() }

    fun file(ctx: Context, img: String) = File(ctx.filesDir, img)

    /** Saves the picture as JPEG at 80 % like the prototype's toDataURL('image/jpeg', 0.8). */
    fun save(ctx: Context, id: String, bmp: Bitmap): String? = runCatching {
        val f = File(dir(ctx), "$id.jpg")
        f.outputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, 80, it) }
        "views/${f.name}"
    }.getOrNull()

    fun load(ctx: Context, img: String, maxW: Int = 0): Bitmap? = runCatching {
        val f = file(ctx, img); if (!f.exists()) return null
        if (maxW <= 0) return BitmapFactory.decodeFile(f.path)
        val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }; BitmapFactory.decodeFile(f.path, o)
        var s = 1; while (o.outWidth / (s * 2) >= maxW) s *= 2
        BitmapFactory.decodeFile(f.path, BitmapFactory.Options().apply { inSampleSize = s })
    }.getOrNull()

    fun delete(ctx: Context, img: String) { runCatching { file(ctx, img).delete() } }

    /** Removes pictures no room refers to any more (a deleted room or project, once its Undo has passed). */
    fun sweep(ctx: Context, projects: List<Project>) {
        val used = projects.flatMap { p -> p.rooms.flatMap { r -> r.views.map { File(it.img).name } } }.toSet()
        dir(ctx).listFiles()?.forEach { if (it.name !in used) it.delete() }
        // pictures kept with issued quotes go with their project
        val ids = projects.map { it.id }.toSet()
        File(ctx.filesDir, "quotes").listFiles()?.forEach { d -> if (ids.none { d.name.startsWith("$it-") }) d.deleteRecursively() }
    }
}
