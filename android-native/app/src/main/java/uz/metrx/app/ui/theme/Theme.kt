package uz.metrx.app.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import uz.metrx.app.R
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Settings
import uz.metrx.app.core.Strings

/**
 * Light or dark (Profile → "Tungi rejim", settings.dark). Every colour in [G] reads [dark], so the screens follow at
 * once. Paper drawings (the report's plans, card thumbnails, a drawing's white sheet) keep their light colours: code that
 * draws one runs inside [onPaper].
 */
object Theme {
    var dark by mutableStateOf(false)
    // per thread: the PDF is drawn off the main thread while the screen keeps drawing
    @PublishedApi internal val paperFlag: ThreadLocal<Boolean> = ThreadLocal.withInitial { false }
    val paper: Boolean get() = paperFlag.get() == true
    inline fun <T> onPaper(f: () -> T): T { val o = paper; paperFlag.set(true); try { return f() } finally { paperFlag.set(o) } }
}

private fun pick(light: Color, dark: Color) = if (Theme.dark) dark else light

/*
 * Colours of the founder's liquid-glass design (prototype modules/glass.css). The dark values are ours (no dark design
 * exists yet): taken from the "Tun" glass option (design/glass/home-glass-options.html) — a near-black ground, smoky glass
 * with a faint white rim, light text — keeping the app's blue, lifted so it reads on black and still carries white text.
 */
object G {
    val paper get() = pick(Color(0xFFEEF1F8), Color(0xFF0B0E16))
    val ink get() = pick(Color(0xFF0F172A), Color(0xFFE8ECF4))
    val ink2 get() = pick(Color(0xFF475569), Color(0xFFAAB3C5))
    val ink3 get() = pick(Color(0xFF64748B), Color(0xFF8A93A7))
    val slate get() = pick(Color(0xFF334155), Color(0xFFC2C9D6))
    val cobalt get() = pick(Color(0xFF3550E0), Color(0xFF5B74FF))
    val cobalt2 get() = pick(Color(0xFF2B47D9), Color(0xFF9AA9FF))
    val green get() = pick(Color(0xFF16A34A), Color(0xFF3DD68C))
    val greyIcon get() = pick(Color(0xFF8A93A6), Color(0xFF7C8597))
    val fill get() = glass(.42f)
    val rim get() = if (Theme.dark) Color.White.copy(alpha = .12f) else Color.White.copy(alpha = .8f)
    val shade get() = pick(Color(0xFF1E286E), Color.Black) // rgba(30,40,110,...) used for every glass shadow
    val auroraBlue = Color(0xFF5B7BFF)
    val auroraViolet = Color(0xFFB07CFF)
    val auroraCyan = Color(0xFF3FD8F2)
    val auroraPeach = Color(0xFFFFB58A)
    val err get() = pick(Color(0xFFB42318), Color(0xFFFF8A80))
    val errWash get() = pick(Color(0xFFFDEDEB), Color(0xFF3A1B1B))
    val blueprint = Color(0xFF0A1030)
    /** See-through white of the glass cards at [a] (prototype rgba(255,255,255,a)); smoky glass in the dark. */
    fun glass(a: Float) = Color.White.copy(alpha = if (Theme.dark) a * .16f else a)
    /** The bright inner top edge of glass (prototype inset 0 1.5px 0 rgba(255,255,255,.95)), at [a]. */
    fun hi(a: Float) = Color.White.copy(alpha = if (Theme.dark) a * .16f else a)
    /** The initials circle on Profile. */
    val avatar get() = pick(Color(0xFF0F172A), Color(0xFF2A3247))
    /** Amber notices (waiting, not connected) and their text. */
    val amberWash get() = pick(Color(0xFFFFF1DF), Color(0xFF33260F))
    val amberInk get() = pick(Color(0xFF9A4D00), Color(0xFFFFB45C))
    /** A note's yellow paper. */
    val noteWash get() = pick(Color(0xFFFFFAEB), Color(0xFF2A2616))
    /** A pale blue wash (selected, calculated). */
    val blueWash get() = pick(Color(0xFFE7EEFD), Color(0xFF1C2546))
    /** A pale green wash (done, confirmed). */
    val greenWash get() = pick(Color(0xFFE8F6EE), Color(0xFF14291E))
    /** The dimming behind a sheet or dialog. */
    val scrim get() = pick(Color(0x6B0E1C36), Color(0x99000000))
    /** The tint of sheets and other glass that content slides behind (prototype rgba(255,255,255,.84)). */
    fun sheet(a: Float = .84f) = if (Theme.dark) Color(0xFF161B27).copy(alpha = minOf(1f, a * .3f + .68f)) else Color.White.copy(alpha = a)
    /** An opaque card or field (prototype #fff). */
    val solid get() = pick(Color.White, Color(0xFF1A2030))
    /** Behind a drawing or photo while it is edited. */
    val stage get() = pick(Color(0xFFE9EDF3), Color(0xFF10141E))
}

/* Colours of the sign-in screens (prototype modules/auth.css, from the founder's Figma file). */
object Au {
    val cobalt = Color(0xFF3355B4)
    val cobalt2 = Color(0xFF27448F)
    val wash = Color(0xFFEBF2FC)
    val ink = Color(0xFF0B1226)
    val ink2 = Color(0xFF56627A)
    val ink3 = Color(0xFF626E87)
    val line = Color(0xFFC9D6E8)
    val hair = Color(0xFFE7ECF3)
    val tint = Color(0xFFF1F6FA)
    val chip = Color(0xFFD3DFEF)
    val plan = Color(0xFFF3F6FB)
    val step = Color(0xFFE4E9ED)
}

private fun variable(res: Int, w: Int) = Font(res, FontWeight(w), variationSettings = FontVariation.Settings(FontVariation.weight(w)))

/** Plus Jakarta Sans (Latin), the glass design's typeface. */
val Jakarta = FontFamily((400..800 step 100).map { variable(R.font.plus_jakarta_sans, it) })
/** Manrope: the prototype's next font in the stack, used for Cyrillic (and the sign-in screens). */
val Manrope = FontFamily((400..800 step 100).map { variable(R.font.manrope, it) })
val PlexMono = FontFamily(
    Font(R.font.ibm_plex_mono_regular, FontWeight.Normal),
    Font(R.font.ibm_plex_mono_medium, FontWeight.Medium),
    Font(R.font.ibm_plex_mono_semibold, FontWeight.SemiBold),
    Font(R.font.ibm_plex_mono_bold, FontWeight.Bold)
)

/** IBM Plex Sans Condensed: the prototype's --f-num, for numbers (areas, counts, money). Weight 800 shows as Bold, as in the browser. */
val PlexCond = FontFamily(
    Font(R.font.ibm_plex_condensed_regular, FontWeight.Normal),
    Font(R.font.ibm_plex_condensed_medium, FontWeight.Medium),
    Font(R.font.ibm_plex_condensed_semibold, FontWeight.SemiBold),
    Font(R.font.ibm_plex_condensed_bold, FontWeight.Bold)
)

fun num(size: Float, weight: Int = 700, color: Color = G.ink, spacing: Float = 0f) = TextStyle(
    fontFamily = PlexCond, fontSize = size.sp, fontWeight = FontWeight(minOf(weight, 700)), color = color, letterSpacing = spacing.em
)

val LocalSettings = staticCompositionLocalOf<Settings> { error("Settings not provided") }
val LocalLang = staticCompositionLocalOf { Lang.UZ }

/** UI font for the current language: Jakarta for Latin scripts, Manrope where the text is Cyrillic. */
@Composable @ReadOnlyComposable
fun uiFont(): FontFamily = if (LocalLang.current.cyrillic) Manrope else Jakarta

/** The sign-in screens use Manrope in every language, as in the prototype. */
val authFont: FontFamily get() = Manrope

@Composable @ReadOnlyComposable
fun tr(key: String, vararg vars: Pair<String, Any?>): String =
    Strings.t(key, LocalLang.current, if (vars.isEmpty()) null else vars.toMap())

/** CSS letter-spacing in em. */
fun ls(em: Float): TextUnit = em.em

@Composable @ReadOnlyComposable
fun ui(size: Float, weight: Int = 400, color: Color = G.ink, lineHeight: Float? = null, spacing: Float = 0f) = TextStyle(
    fontFamily = uiFont(), fontSize = size.sp, fontWeight = FontWeight(weight), color = color,
    lineHeight = lineHeight?.let { (size * it).sp } ?: TextUnit.Unspecified, letterSpacing = spacing.em
)

fun au(size: Float, weight: Int = 400, color: Color = Au.ink, lineHeight: Float? = null, spacing: Float = 0f) = TextStyle(
    fontFamily = Manrope, fontSize = size.sp, fontWeight = FontWeight(weight), color = color,
    lineHeight = lineHeight?.let { (size * it).sp } ?: TextUnit.Unspecified, letterSpacing = spacing.em
)

fun mono(size: Float, weight: Int = 500, color: Color = Au.ink, spacing: Float = 0f) = TextStyle(
    fontFamily = PlexMono, fontSize = size.sp, fontWeight = FontWeight(weight), color = color, letterSpacing = spacing.em
)
