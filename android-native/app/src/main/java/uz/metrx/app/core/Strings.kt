package uz.metrx.app.core

import android.content.Context
import org.json.JSONObject

/** The four app languages, in the order the prototype lists them. */
enum class Lang(val code: String, val longName: String, val shortName: String) {
    UZ("uz", "O‘zbekcha (lotin)", "O‘zbekcha"),
    UZC("uzc", "Ўзбекча (кирилл)", "Ўзбекча"),
    RU("ru", "Русский", "Русский"),
    EN("en", "English", "English");

    /** Uzbek Cyrillic and Russian are set in Manrope, because Plus Jakarta Sans has no Cyrillic letters. */
    val cyrillic get() = this == UZC || this == RU

    companion object {
        fun of(code: String?) = entries.firstOrNull { it.code == code } ?: UZ
    }
}

/**
 * Every screen text in four languages. assets/strings.json is extracted from the prototype
 * (tools/extractD.js) as key -> [uz, uz-Cyrl, ru, en]; the few texts that only the native app needs are in [NATIVE].
 * Templates work as in the prototype: {name} is replaced, {n:form1|form2|form3} picks a plural form by the number n.
 */
object Strings {
    private val table = HashMap<String, Array<String>>(1400)

    fun load(context: Context) {
        if (table.isNotEmpty()) return
        val json = context.assets.open("strings.json").bufferedReader(Charsets.UTF_8).use { JSONObject(it.readText()) }
        for (key in json.keys()) {
            val a = json.getJSONArray(key)
            table[key] = Array(4) { a.optString(it, "") }
        }
        NATIVE.forEach { (k, v) -> table[k] = v }
    }

    fun has(key: String) = table.containsKey(key)

    /** Puts texts in without a Context (the unit tests read strings.json themselves). */
    internal fun put(key: String, v: Array<String>) { table[key] = v }

    fun t(key: String, lang: Lang, vars: Map<String, Any?>? = null): String {
        val e = table[key] ?: return key
        var s = e[lang.ordinal].ifEmpty { e[0] }
        // the room editor's and inner walls' texts in the room's unit (geo.RoomUnit, 1.0.2): their "mm" and the lengths
        // written in them follow it (the texts stay as they are for the iPhone app, which reads this file too)
        if (uz.metrx.app.geo.RoomUnit.unit != uz.metrx.app.geo.LenUnit.MM && (key.startsWith("re.") || key.startsWith("iw."))) s = inRoomUnit(key, s, lang)
        if (vars != null) {
            s = PLURAL.replace(s) { m ->
                // a number, or a number as text (a stored line's values: "n=1", "a=2,5")
                val v = vars[m.groupValues[1]]
                val n = (v as? Number)?.toDouble() ?: v?.toString()?.replace(',', '.')?.replace(" ", "")?.toDoubleOrNull() ?: m.groupValues[1].toDoubleOrNull() ?: 0.0
                plural(n, m.groupValues[2], lang)
            }
            s = VAR.replace(s) { m -> vars[m.groupValues[1]]?.toString() ?: m.value }
        }
        return s
    }

    private val PLURAL = Regex("""\{(\w+):([^}]+)\}""")
    private val VAR = Regex("""\{(\w+)\}""")

    /** A number written with its "mm" ("300 mm", "999 999 мм"), a "mm" alone, a number with no word in the texts that have such. */
    private val NUM_MM = Regex("""(?<![\d{])(\d{1,3}(?:[  ]\d{3})+|\d+)[  ]?(mm|мм)(?![\p{L}])""")
    private val MM = Regex("""(?<![\p{L}])(mm|мм)(?![\p{L}])""")
    private val BARE = Regex("""(?<![\d{°])(\d{1,3}(?:[  ,]\d{3})+|\d{2,})(?![\d}°]|D|[  ,]\d|[  ]?(?:mm|мм)(?![\p{L}]))""")
    /** The texts whose numbers are all lengths in mm even with no "mm" after them ("standart 100", "kamida 300", "400 × 400"). */
    private val BARE_KEYS = setOf("iw.thSub", "iw.o.thSub", "iw.note", "iw.winNote", "re.balMinW", "re.lenSub", "iw.cl.col", "re.i.water", "re.i.gas", "re.wallRange", "re.m.range")

    /** Template [s] of [key] with its lengths in [geo.RoomUnit]'s unit and its "mm" that unit's word (before its {values} go in). */
    internal fun inRoomUnit(key: String, s: String, lang: Lang): String {
        val ru = uz.metrx.app.geo.RoomUnit
        val w = table[uz.metrx.app.geo.unitKey(ru.unit)]?.let { a -> a.getOrElse(lang.ordinal) { a[0] }.ifEmpty { a[0] } } ?: return s
        fun len(n: String) = n.filter { it.isDigit() }.toIntOrNull()?.let { ru.text(it, ru.unit, lang == Lang.EN) } ?: n
        var r = if (key in BARE_KEYS) BARE.replace(s) { m -> len(m.groupValues[1]) } else s
        r = NUM_MM.replace(r) { m -> len(m.groupValues[1]) + " " + w }
        return MM.replace(r) { w }
    }

    private fun plural(n: Double, forms: String, lang: Lang): String {
        val f = forms.split('|')
        if (lang == Lang.RU) {
            val a = Math.abs(n.toLong()) % 100
            val b = a % 10
            return f.getOrElse(if (a in 11..19) 2 else if (b == 1L) 0 else if (b in 2..4) 1 else 2) { f.last() }
        }
        return if (n == 1.0) f[0] else f.getOrElse(1) { f[0] }
    }

    /** Texts that exist only in the native app: [uz, uz-Cyrl, ru, en]. */
    private val NATIVE = mapOf(
        "nt.soonT" to arrayOf("Hisoblar tez orada", "Ҳисоблар тез орада", "Аккаунты скоро", "Accounts are coming soon"),
        "nt.soonB" to arrayOf(
            "Ro‘yxatdan o‘tish va kirish hali ishlamaydi. Hozircha ilova hisobsiz to‘liq ishlaydi: hammasi shu telefonda saqlanadi.",
            "Рўйхатдан ўтиш ва кириш ҳали ишламайди. Ҳозирча илова ҳисобсиз тўлиқ ишлайди: ҳаммаси шу телефонда сақланади.",
            "Регистрация и вход пока не работают. Приложение полностью работает без аккаунта: всё хранится на этом телефоне.",
            "Sign-up and log-in don’t work yet. The app works fully without an account: everything stays on this phone."
        ),
        "nt.part" to arrayOf("Bu ekran {n}-qismda qo‘shiladi", "Бу экран {n}-қисмда қўшилади", "Этот экран появится в части {n}", "This screen arrives in part {n}"),
        "nt.simLaser" to arrayOf("Simulyatsiya: haqiqiy lazer hali ulanmagan", "Симуляция: ҳақиқий лазер ҳали уланмаган", "Симуляция: настоящий лазер пока не подключён", "Simulation: no real laser is connected yet"),
        "nt.back" to arrayOf("Orqaga", "Орқага", "Назад", "Back"),
        "nt.dark" to arrayOf("Tungi rejim", "Тунги режим", "Тёмная тема", "Dark mode")
    )
}
