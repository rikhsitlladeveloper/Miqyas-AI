package uz.metrx.app.voice

/*
 * Spoken sizes to millimetres (UX upgrades §9, 26 Oct 2026): what the offline recogniser heard in Uzbek or Russian,
 * "uch ming to‘rt yuz" → 3400, "ikki yarim metr" → 2500, "три тысячи четыреста" → 3400, "полтора метра" → 1500,
 * digits as said ("3400"). A number with no unit is millimetres; "metr" / "sm" / "mm" after a number says its unit,
 * and a number after metres is centimetres when it is under 100 ("bir metr yigirma" → 1200), else millimetres.
 * Anything that is not a number, a unit, "half" or "and" makes the whole phrase unreadable (null), so a stray word
 * never writes a wrong size. Pure Kotlin: the shared cases in design/ux-upgrades/voice-cases.json test it.
 */
object VoiceNum {
    private enum class U { M, CM, MM }

    private sealed interface Tok {
        /** A number word: [add] is added to the hundreds group, [mul] multiplies it (yuz = 100), [big] closes it (ming = 1000). */
        data class Num(val add: Double = 0.0, val mul: Int = 0, val big: Int = 0) : Tok
        data class Unit(val u: U) : Tok
        /** "yarim", "половина": a half of the number before it (or 0,5 alone). */
        data object Half : Tok
        /** "va", "и", "с": nothing. */
        data object Skip : Tok
        /** "полметра": half a metre. */
        data object HalfMetre : Tok
    }

    private val UZ = mapOf(
        "nol" to 0, "bir" to 1, "ikki" to 2, "uch" to 3, "to'rt" to 4, "tort" to 4, "besh" to 5, "olti" to 6, "yetti" to 7,
        "sakkiz" to 8, "to'qqiz" to 9, "toqqiz" to 9, "o'n" to 10, "on" to 10, "yigirma" to 20, "o'ttiz" to 30, "ottiz" to 30,
        "qirq" to 40, "ellik" to 50, "oltmish" to 60, "yetmish" to 70, "sakson" to 80, "to'qson" to 90, "toqson" to 90
    )

    private val RU = mapOf(
        "ноль" to 0, "один" to 1, "одна" to 1, "одно" to 1, "два" to 2, "две" to 2, "три" to 3, "четыре" to 4, "пять" to 5,
        "шесть" to 6, "семь" to 7, "восемь" to 8, "девять" to 9, "десять" to 10, "одиннадцать" to 11, "двенадцать" to 12,
        "тринадцать" to 13, "четырнадцать" to 14, "пятнадцать" to 15, "шестнадцать" to 16, "семнадцать" to 17,
        "восемнадцать" to 18, "девятнадцать" to 19, "двадцать" to 20, "тридцать" to 30, "сорок" to 40, "пятьдесят" to 50,
        "шестьдесят" to 60, "семьдесят" to 70, "восемьдесят" to 80, "девяносто" to 90, "сто" to 100, "двести" to 200,
        "триста" to 300, "четыреста" to 400, "пятьсот" to 500, "шестьсот" to 600, "семьсот" to 700, "восемьсот" to 800,
        "девятьсот" to 900
    )

    private val UNITS = mapOf(
        "metr" to U.M, "metrga" to U.M, "m" to U.M, "santimetr" to U.CM, "santim" to U.CM, "sm" to U.CM, "millimetr" to U.MM, "mm" to U.MM,
        "метр" to U.M, "метра" to U.M, "метров" to U.M, "метре" to U.M, "м" to U.M,
        "сантиметр" to U.CM, "сантиметра" to U.CM, "сантиметров" to U.CM, "см" to U.CM,
        "миллиметр" to U.MM, "миллиметра" to U.MM, "миллиметров" to U.MM, "мм" to U.MM
    )

    /** Uzbek said in Cyrillic letters (an uz-Cyrillic phone's keyboard, or a recogniser that writes it so) → Latin. */
    private val CYR_UZ = mapOf(
        'а' to "a", 'б' to "b", 'в' to "v", 'г' to "g", 'д' to "d", 'е' to "e", 'ё' to "yo", 'ж' to "j", 'з' to "z", 'и' to "i",
        'й' to "y", 'к' to "k", 'л' to "l", 'м' to "m", 'н' to "n", 'о' to "o", 'п' to "p", 'р' to "r", 'с' to "s", 'т' to "t",
        'у' to "u", 'ф' to "f", 'х' to "x", 'ц' to "ts", 'ч' to "ch", 'ш' to "sh", 'ъ' to "'", 'ь' to "", 'э' to "e", 'ю' to "yu",
        'я' to "ya", 'ў' to "o'", 'қ' to "q", 'ғ' to "g'", 'ҳ' to "h"
    )

    private fun tok(w: String): Tok? {
        UZ[w]?.let { return Tok.Num(add = it.toDouble()) }
        RU[w]?.let { return Tok.Num(add = it.toDouble()) }
        UNITS[w]?.let { return Tok.Unit(it) }
        return when (w) {
            "yuz" -> Tok.Num(mul = 100)
            "ming", "тысяча", "тысячи", "тысяч", "тысячу" -> Tok.Num(big = 1000)
            "полтора", "полторы" -> Tok.Num(add = 1.5)
            "yarim", "половина", "половиной", "половину", "пол" -> Tok.Half
            "полметра" -> Tok.HalfMetre
            "va", "и", "с", "со" -> Tok.Skip
            else -> w.replace(',', '.').toDoubleOrNull()?.takeIf { it >= 0 }?.let { Tok.Num(add = it) }
        }
    }

    /** Lower case, one kind of apostrophe, no punctuation; Uzbek Cyrillic words read as Latin ones. */
    fun words(text: String): List<String> {
        val s = text.lowercase()
            .replace(Regex("[‘’ʻʼ`´]"), "'")
            .replace(Regex("(\\d)\\s+(?=\\d{3}\\b)"), "$1")   // "3 400" said as digits with a group space
            .replace(Regex("[^\\p{L}\\d',.'\\s]"), " ")
        return s.split(Regex("\\s+")).map { it.trim('.', ',', '\'') }.filter { it.isNotEmpty() }.map { w ->
            if (tok(w) == null && w.any { it in CYR_UZ }) w.map { c -> CYR_UZ[c] ?: c.toString() }.joinToString("") else w
        }
    }

    /**
     * The size in millimetres said in [text] ([lang] "uz" or "ru"; both kinds of words are read either way), or null
     * when it is not a size.
     */
    fun toMm(text: String, @Suppress("UNUSED_PARAMETER") lang: String = "uz"): Int? {
        val ws = words(text)
        if (ws.isEmpty()) return null
        // the groups said: a number and its unit (null: none said)
        val groups = ArrayList<Pair<Double, U?>>()
        var total = 0.0; var cur = 0.0; var any = false; var half = false
        fun close(u: U?) {
            if (!any && !half) return
            val v = total + cur + (if (half) .5 else 0.0)
            groups += v to u
            total = 0.0; cur = 0.0; any = false; half = false
        }
        for (w in ws) {
            when (val t = tok(w) ?: return null) {
                is Tok.Num -> {
                    when {
                        t.mul > 0 -> cur = (if (cur == 0.0) 1.0 else cur) * t.mul
                        t.big > 0 -> { total += (if (cur == 0.0) 1.0 else cur) * t.big; cur = 0.0 }
                        else -> {
                            // a new number right after a closed half ("ikki yarim … uch") starts its own group
                            if (half) close(null)
                            cur += t.add
                        }
                    }
                    any = true
                }
                is Tok.Half -> half = true
                is Tok.Unit -> { if (!any && !half) return null; close(t.u) }
                Tok.HalfMetre -> { close(null); groups += .5 to U.M }
                Tok.Skip -> {}
            }
        }
        close(null)
        if (groups.isEmpty()) return null
        var mm = 0.0
        var prev: U? = null
        for ((v, u) in groups) {
            val unit = u ?: when (prev) {
                // after metres: "bir metr yigirma" is 1 m 20 cm; "bir metr ikki yuz" 1 m 200 mm
                U.M -> if (v < 100) U.CM else U.MM
                U.CM -> U.MM
                else -> U.MM
            }
            mm += when (unit) { U.M -> v * 1000; U.CM -> v * 10; U.MM -> v }
            prev = unit
        }
        val r = Math.round(mm).toInt()
        return r.takeIf { it > 0 }
    }

    /**
     * The words the recogniser may hear (Vosk grammar): the numbers, units, "half" and "and" of both languages, with the
     * Uzbek apostrophes written the ways a model may spell them; "[unk]" catches everything else.
     */
    fun grammar(lang: String): List<String> {
        val uz = (UZ.keys + listOf("yuz", "ming", "yarim", "va", "metr", "santimetr", "santim", "millimetr", "sm", "mm")).flatMap { w ->
            if ('\'' in w) listOf(w, w.replace('\'', 'ʻ'), w.replace('\'', '‘'), w.replace('\'', '’')) else listOf(w)
        }
        val ru = RU.keys + listOf("тысяча", "тысячи", "тысяч", "полтора", "полторы", "половина", "половиной", "пол", "полметра", "и", "с",
            "метр", "метра", "метров", "сантиметр", "сантиметра", "сантиметров", "миллиметр", "миллиметра", "миллиметров")
        return (if (lang == "ru") ru else uz).distinct() + "[unk]"
    }
}
