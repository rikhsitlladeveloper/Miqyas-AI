package uz.metrx.app.voice

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.compose.runtime.mutableStateMapOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import uz.metrx.app.core.Lang
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream

/*
 * Offline voice numbers (UX upgrades §9): Vosk's small Uzbek and Russian models (about 50 MB each), downloaded by the
 * app the first time they are needed, over Wi-Fi only, into the app's files; then everything runs on the phone.
 */
object VoicePacks {
    private val URLS = mapOf(
        "uz" to "https://alphacephei.com/vosk/models/vosk-model-small-uz-0.22.zip",
        "ru" to "https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip"
    )

    /** The pack a language speaks: Russian for Russian, else Uzbek (Uzbek Cyrillic and English use the Uzbek one). */
    fun langOf(l: Lang) = if (l == Lang.RU) "ru" else "uz"

    /** A pack being downloaded: 0..1 (the last tenth is unpacking). */
    val progress = mutableStateMapOf<String, Float>()
    /** Packs ready on the phone (read from the files once, then kept). */
    private val readyMap = mutableStateMapOf<String, Boolean>()

    private fun dir(ctx: Context, lang: String) = File(ctx.filesDir, "vosk/$lang")
    /** The model's own folder inside the unpacked pack. */
    fun modelPath(ctx: Context, lang: String): String? = File(dir(ctx, lang), "path").takeIf { it.exists() }?.readText()?.trim()?.takeIf { File(it).isDirectory }

    fun ready(ctx: Context, lang: String): Boolean = readyMap[lang] ?: (modelPath(ctx, lang) != null)

    /** Wi-Fi (an unmetered network) only: the pack never uses mobile data. */
    fun onWifi(ctx: Context): Boolean {
        val cm = ctx.getSystemService(ConnectivityManager::class.java) ?: return false
        val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) &&
            (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) || caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET))
    }

    /** Downloads and unpacks [lang]'s pack; [done] gets null when ready, else the strings key of what went wrong. */
    fun download(ctx: Context, lang: String, scope: CoroutineScope, done: (String?) -> Unit) {
        if (progress.containsKey(lang) || ready(ctx, lang)) { done(null); return }
        val url = URLS[lang] ?: run { done("ux.v.fail"); return }
        if (!onWifi(ctx)) { done("ux.v.noWifi"); return }
        progress[lang] = 0f
        scope.launch {
            val ok = withContext(Dispatchers.IO) {
                runCatching {
                    val base = File(ctx.filesDir, "vosk").apply { mkdirs() }
                    val zip = File(base, "$lang.zip.part")
                    val c = (URL(url).openConnection() as HttpURLConnection).apply { connectTimeout = 20000; readTimeout = 30000; instanceFollowRedirects = true }
                    try {
                        if (c.responseCode !in 200..299) error("HTTP ${c.responseCode}")
                        val total = c.contentLengthLong.takeIf { it > 0 } ?: 50_000_000L
                        var got = 0L; var shown = -1
                        c.inputStream.use { inp -> zip.outputStream().use { out ->
                            val buf = ByteArray(64 * 1024)
                            while (true) {
                                val n = inp.read(buf); if (n < 0) break
                                out.write(buf, 0, n); got += n
                                val pct = (got * 90 / total).toInt().coerceIn(0, 90)
                                if (pct != shown) { shown = pct; withContext(Dispatchers.Main) { progress[lang] = pct / 100f } }
                            }
                        } }
                    } finally { c.disconnect() }
                    val target = dir(ctx, lang)
                    target.deleteRecursively(); target.mkdirs()
                    unzip(zip, target)
                    zip.delete()
                    withContext(Dispatchers.Main) { progress[lang] = 1f }
                    // the model's folder: the one holding "am" or "conf"
                    val root = target.walkTopDown().maxDepth(2).firstOrNull { f -> f.isDirectory && (File(f, "am").exists() || File(f, "conf").exists()) } ?: error("no model")
                    File(target, "path").writeText(root.absolutePath)
                    true
                }.getOrElse { File(ctx.filesDir, "vosk/$lang.zip.part").delete(); false }
            }
            progress.remove(lang)
            readyMap[lang] = ok
            done(if (ok) null else "ux.v.fail")
        }
    }

    /** Unpacks [zip] into [to], refusing any entry that would land outside it. */
    private fun unzip(zip: File, to: File) {
        val root = to.canonicalFile
        ZipInputStream(zip.inputStream().buffered()).use { z ->
            while (true) {
                val e = z.nextEntry ?: break
                val out = File(root, e.name).canonicalFile
                if (!out.path.startsWith(root.path + File.separator)) error("bad entry")
                if (e.isDirectory) out.mkdirs() else { out.parentFile?.mkdirs(); out.outputStream().use { z.copyTo(it) } }
            }
        }
    }
}

/**
 * Hold-to-talk: the model (loaded once, kept for the session), a recogniser limited to the number words (more accurate
 * than free dictation), the microphone while the finger is down; the words heard come back when it is lifted.
 */
object VoiceRec {
    private var model: Model? = null
    private var modelLang: String? = null
    private var svc: SpeechService? = null
    private var recog: Recognizer? = null
    /** False once the finger was lifted (a start still loading the model then stops at once). */
    @Volatile private var held = false

    private suspend fun modelFor(ctx: Context, lang: String): Model = withContext(Dispatchers.IO) {
        synchronized(this@VoiceRec) {
            model?.takeIf { modelLang == lang } ?: run {
                runCatching { model?.close() }
                val path = VoicePacks.modelPath(ctx, lang) ?: error("no pack")
                Model(path).also { model = it; modelLang = lang }
            }
        }
    }

    /** Loads the model ahead of the first hold (it takes a second or two). */
    suspend fun preload(ctx: Context, lang: String) { runCatching { modelFor(ctx, lang) } }

    /** Starts listening; [onPartial] the words so far, [onFinal] all of them once the finger is up, [onError] when it can't. */
    suspend fun start(ctx: Context, lang: String, onPartial: (String) -> Unit, onFinal: (String) -> Unit, onError: (Throwable) -> Unit) {
        held = true
        val m = try { modelFor(ctx, lang) } catch (e: Throwable) { onError(e); return }
        if (!held) { onFinal(""); return }
        try {
            release()
            val r = Recognizer(m, 16000f, JSONArray(VoiceNum.grammar(lang)).toString())
            recog = r
            val s = SpeechService(r, 16000f)
            svc = s
            s.startListening(object : RecognitionListener {
                override fun onPartialResult(hypothesis: String?) { hypothesis?.let { onPartial(JSONObject(it).optString("partial")) } }
                override fun onResult(hypothesis: String?) { hypothesis?.let { onPartial(JSONObject(it).optString("text")) } }
                override fun onFinalResult(hypothesis: String?) { val t = hypothesis?.let { JSONObject(it).optString("text") }.orEmpty(); release(); onFinal(t) }
                override fun onError(exception: Exception?) { release(); onError(exception ?: RuntimeException("voice")) }
                override fun onTimeout() { release(); onFinal("") }
            })
        } catch (e: Throwable) { release(); onError(e) }
    }

    /** The finger is up: the words heard come to onFinal. */
    fun stop() { held = false; svc?.stop() }

    /** The page went away mid-hold: nothing is delivered. */
    fun cancel() { held = false; runCatching { svc?.cancel() }; release() }

    private fun release() {
        runCatching { svc?.shutdown() }; svc = null
        runCatching { recog?.close() }; recog = null
    }
}
