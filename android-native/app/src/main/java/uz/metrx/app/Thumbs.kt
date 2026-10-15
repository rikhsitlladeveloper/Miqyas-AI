package uz.metrx.app

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import uz.metrx.app.data.Room
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.LocalSettings

/** A room's small plan for lists (no labels). */
@Composable
fun editorThumb(r: Room, modifier: Modifier) {
    val s = LocalSettings.current
    uz.metrx.app.ui.editor.RoomThumb(r, r.name, s.unit, LocalLang.current == uz.metrx.app.core.Lang.EN, s.angleSnap, false, modifier)
}
