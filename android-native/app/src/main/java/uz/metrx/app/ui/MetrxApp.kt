package uz.metrx.app.ui

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBars
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import dev.chrisbanes.haze.rememberHazeState
import uz.metrx.app.core.Settings
import uz.metrx.app.core.Strings
import uz.metrx.app.ui.auth.AuthNav
import uz.metrx.app.ui.auth.LocalScreen
import uz.metrx.app.ui.auth.LogInScreen
import uz.metrx.app.ui.auth.SignUpScreen
import uz.metrx.app.ui.auth.SoonSheet
import uz.metrx.app.ui.auth.WelcomeScreen
import uz.metrx.app.ui.components.ToastHost
import uz.metrx.app.ui.components.ToastKind
import uz.metrx.app.ui.components.ToastMsg
import uz.metrx.app.ui.glass.AuroraBox
import uz.metrx.app.ui.glass.LocalHaze
import uz.metrx.app.ui.main.DeviceSheet
import uz.metrx.app.ui.main.GlassNav
import uz.metrx.app.ui.main.HomeScreen
import uz.metrx.app.ui.main.LanguageSheet
import uz.metrx.app.ui.main.MainNav
import uz.metrx.app.ui.main.ProfileScreen
import uz.metrx.app.ui.projects.NewProjectScreen
import uz.metrx.app.ui.projects.NoteScreen
import uz.metrx.app.ui.projects.ProjectScreen
import uz.metrx.app.ui.projects.ProjectSheet
import uz.metrx.app.ui.projects.ProjectsList
import uz.metrx.app.ui.projects.SpaceScreen
import uz.metrx.app.data.Store
import uz.metrx.app.ui.main.Tab
import uz.metrx.app.ui.splash.RoomHops
import uz.metrx.app.ui.theme.LocalLang
import uz.metrx.app.ui.theme.LocalSettings

/** Screens of the sign-in flow. "Profile" means it was opened from Profile, so leaving it goes back there. */
private enum class AuthStep { WELCOME, SIGNUP, LOGIN, LOCAL, INDUSTRY }

@Composable
fun MetrxApp(settings: Settings, playIntro: Boolean) {
    val haze = rememberHazeState()
    val view = LocalView.current
    val density = LocalDensity.current

    var splash by remember { mutableStateOf(playIntro) }
    val splashFade = remember { Animatable(1f) }
    var welcomeRise by remember { mutableStateOf(playIntro) }

    val authStack = remember { mutableStateListOf<AuthStep>().apply { if (!settings.firstRunDone) add(AuthStep.WELCOME) } }
    var authFromProfile by remember { mutableStateOf(false) }
    var editMe by rememberSaveable { mutableStateOf(false) }
    var soon by remember { mutableStateOf(false) }
    val context = androidx.compose.ui.platform.LocalContext.current
    val app = remember { App(settings, Store.get(context), context.applicationContext) }

    val inAuth = authStack.isNotEmpty()
    val lang = settings.lang
    fun say(key: String, vararg v: Pair<String, Any?>, kind: ToastKind = ToastKind.INFO) = app.say(key, *v, kind = kind)

    // light status-bar icons over the blueprint of the opening animation, dark ones on every light screen
    SideEffect {
        val w = (view.context as? Activity)?.window ?: return@SideEffect
        WindowCompat.getInsetsController(w, view).apply {
            // light icons over the opening animation and the live camera, dark ones on every light screen
            // the sign-in pages and the builder's name and phone page (editMe) are always white
            val darkPage = splash || (!inAuth && !editMe && (app.top == Route.LiveCam || settings.dark))
            isAppearanceLightStatusBars = !darkPage
            isAppearanceLightNavigationBars = !darkPage
        }
    }

    // opening a sheet puts the keyboard away
    val focusManager = androidx.compose.ui.platform.LocalFocusManager.current
    LaunchedEffect(app.sheet) { if (app.sheet != null) focusManager.clearFocus() }

    // the real laser (one for the whole app): its measurements and news come here; every screen reads settings.laser
    androidx.compose.runtime.DisposableEffect(app) {
        val real = app.laser.real
        real.attach(settings)
        real.onReading = { app.laser.dispatch(it) }
        real.onEvent = { k, n, u -> app.laser.event(k, n, u) }
        onDispose { real.onReading = null; real.onEvent = null }
    }
    LaunchedEffect(app) { androidx.compose.runtime.snapshotFlow { app.laser.state() }.collect { settings.laser = it } }
    // a button waiting for the laser stops waiting when its page is left (not when it only shows another view, plan ↔ 3D),
    // when the sheet it was pressed in closes, or when the laser goes away
    LaunchedEffect(app.top, app.sheet) { app.laser.check(app.top, app.sheet) }
    LaunchedEffect(app.laser.isReal) { if (!app.laser.isReal) app.laser.cancel() }

    val authNav = object : AuthNav {
        override fun signUp() { authStack.add(AuthStep.SIGNUP) }
        override fun logIn() { authStack.add(AuthStep.LOGIN) }
        override fun local() {
            if (authFromProfile) { authStack.clear(); authFromProfile = false } else authStack.add(AuthStep.LOCAL)
        }
        override fun back() {
            when {
                editMe -> editMe = false
                authStack.size > 1 -> authStack.removeAt(authStack.lastIndex)
                authFromProfile -> { authStack.clear(); authFromProfile = false }
            }
        }
        override fun done() {
            if (editMe) { editMe = false; say("common.save", kind = ToastKind.OK); return }
            // the first run asks for the industry once, after sign-in (furniture plan section 3)
            if (settings.industry == null) { soon = false; authStack.add(AuthStep.INDUSTRY); return }
            settings.finishFirstRun(); authStack.clear(); authFromProfile = false; soon = false
        }
        override fun soon() { soon = true }
    }
    val mainNav = object : MainNav {
        // with a laser connected (or the simulator) the small Device sheet shows its status; else the radar finds one
        override fun laser() { app.openLaser() }
        override fun newProject() { app.push(Route.NewProject()) }
        override fun measure() { app.push(Route.Measure(false)) }
        override fun calculator() { app.push(Route.Measure(true)) }
        override fun languages() { app.sheet = Sheet.Language }
        override fun signIn() { authFromProfile = true; welcomeRise = false; authStack.clear(); authStack.add(AuthStep.WELCOME) }
    }

    BackHandler(enabled = !splash && (soon || app.sheet != null || editMe || authStack.size > 1 || authFromProfile || (!inAuth && (app.stack.size > 1 || app.tab != Tab.HOME)))) {
        when {
            soon -> soon = false
            app.sheet != null -> app.sheet = null
            editMe || inAuth -> authNav.back()
            app.stack.size > 1 -> app.pop()
            app.tab != Tab.HOME -> app.tab = Tab.HOME
        }
    }

    uz.metrx.app.ui.editor.PlanLabel.mode = settings.roomLabel
    uz.metrx.app.ui.theme.Theme.dark = settings.dark && !inAuth && !editMe
    CompositionLocalProvider(LocalSettings provides settings, LocalLang provides lang, LocalHaze provides haze, LocalApp provides app) {
        Box(Modifier.fillMaxSize()) {
            if (!splash || splashFade.value < 1f) {
                when {
                    editMe -> LocalScreen(authNav, Strings.t("fr.builderTitle", lang))
                    inAuth -> AnimatedContent(
                        authStack.last(),
                        transitionSpec = {
                            val fwd = targetState.ordinal > initialState.ordinal
                            (slideInHorizontally(tween(260)) { if (fwd) it / 4 else -it / 4 } + fadeIn(tween(200))) togetherWith
                                (slideOutHorizontally(tween(260)) { if (fwd) -it / 4 else it / 4 } + fadeOut(tween(160)))
                        }, label = "auth"
                    ) { step ->
                        when (step) {
                            AuthStep.WELCOME -> WelcomeScreen(authNav, fromSplash = welcomeRise)
                            AuthStep.SIGNUP -> SignUpScreen(authNav)
                            AuthStep.LOGIN -> LogInScreen(authNav)
                            AuthStep.LOCAL -> LocalScreen(authNav)
                            AuthStep.INDUSTRY -> AuroraBox(haze) {
                                uz.metrx.app.ui.furniture.IndustryScreen(onBack = authNav::back) { kind ->
                                    settings.setIndustryKind(kind); authNav.done()
                                }
                            }
                        }
                    }
                    else -> AuroraBox(haze) {
                        AnimatedContent(
                            app.tab to app.top,
                            // the same page with another tab, view or mode does not slide
                            contentKey = { (t, r) -> t to pageKey(r) },
                            transitionSpec = {
                                if (initialState.first != targetState.first) fadeIn(tween(180)) togetherWith fadeOut(tween(120))
                                else {
                                    val d = app.dir
                                    (slideInHorizontally(tween(280)) { w -> if (d > 0) w else -w / 3 } + fadeIn(tween(200))) togetherWith
                                        (slideOutHorizontally(tween(280)) { w -> if (d > 0) -w / 3 else w } + fadeOut(tween(200)))
                                }
                            }, label = "page"
                        ) { (t, route) ->
                            Box(Modifier.fillMaxSize()) {
                                when (route) {
                                    Route.Root -> when (t) {
                                        Tab.HOME -> HomeScreen(mainNav)
                                        Tab.PROJECTS -> ProjectsList()
                                        Tab.PROFILE -> ProfileScreen(mainNav) { editMe = true }
                                    }
                                    is Route.NewProject -> if (route.editId == null && app.settings.furniture) uz.metrx.app.ui.furniture.NewOrderScreen()
                                        else if (route.editId == null && app.settings.tiler) uz.metrx.app.ui.furniture.NewOrderScreen("tiler")
                                        else if (route.editId == null && app.settings.elec) uz.metrx.app.ui.furniture.NewOrderScreen("elec")
                                        else if (route.editId == null && app.settings.plumb) uz.metrx.app.ui.furniture.NewOrderScreen("plumb")
                                        else if (route.editId == null && app.settings.win) uz.metrx.app.ui.furniture.NewOrderScreen("win") else NewProjectScreen(route.editId)
                                    is Route.Project -> ProjectScreen(route)
                                    is Route.Space -> SpaceScreen(route)
                                    is Route.Note -> NoteScreen(route)
                                    is Route.Editor -> uz.metrx.app.ui.editor.EditorScreen(route)
                                    is Route.WallView -> uz.metrx.app.ui.editor.WallViewScreen(route)
                                    is Route.Sketch -> uz.metrx.app.ui.editor.SketchScreen(route)
                                    Route.SettingsMore -> uz.metrx.app.ui.main.SettingsMoreScreen()
                                    Route.Workshop -> uz.metrx.app.ui.furniture.WorkshopScreen()
                                    Route.Materials -> uz.metrx.app.ui.furniture.MaterialsScreen()
                                    Route.Subscription -> uz.metrx.app.ui.main.SubscriptionScreen()
                                    is Route.Report -> uz.metrx.app.ui.report.ReportScreen(route.pid, null)
                                    is Route.Quote -> uz.metrx.app.ui.report.ReportScreen(route.pid, route.no)
                                    is Route.Kitchen -> uz.metrx.app.ui.furniture.KitchenScreen(route)
                                    is Route.Wardrobe -> uz.metrx.app.ui.furniture.WardrobeScreen(route)
                                    is Route.FGallery -> uz.metrx.app.ui.furniture.FGalleryScreen(route)
                                    is Route.FSteps -> uz.metrx.app.ui.furniture.FStepsScreen(route)
                                    is Route.FWhere -> uz.metrx.app.ui.furniture.FWhereScreen(route)
                                    is Route.FPlace -> uz.metrx.app.ui.furniture.FPlaceScreen(route)
                                    is Route.TGallery -> uz.metrx.app.ui.tiles.TGalleryScreen(route)
                                    is Route.TSteps -> uz.metrx.app.ui.tiles.TStepsScreen(route)
                                    is Route.TView -> uz.metrx.app.ui.tiles.TViewScreen(route)
                                    is Route.EGallery -> uz.metrx.app.ui.elec.EGalleryScreen(route)
                                    is Route.ESteps -> uz.metrx.app.ui.elec.EStepsScreen(route)
                                    is Route.EView -> uz.metrx.app.ui.elec.EViewScreen(route)
                                    is Route.PGallery -> uz.metrx.app.ui.plumb.PGalleryScreen(route)
                                    is Route.PSteps -> uz.metrx.app.ui.plumb.PStepsScreen(route)
                                    is Route.PView -> uz.metrx.app.ui.plumb.PViewScreen(route)
                                    is Route.WGallery -> uz.metrx.app.ui.win.WGalleryScreen(route)
                                    is Route.WPlace -> uz.metrx.app.ui.win.WPlaceScreen(route)
                                    is Route.WDesign -> uz.metrx.app.ui.win.WDesignScreen(route)
                                    is Route.WView -> uz.metrx.app.ui.win.WViewScreen(route)
                                    is Route.FCut -> uz.metrx.app.ui.furniture.CutScreen(route)
                                    is Route.FPack -> uz.metrx.app.ui.report.PackScreen(route.pid, route.labels)
                                    is Route.FCheck -> uz.metrx.app.ui.furniture.CheckScreen(route)
                                    Route.Remnants -> uz.metrx.app.ui.furniture.RemnantsScreen()
                                    is Route.Measure -> uz.metrx.app.ui.measure.MeasureScreen(route.calc)
                                    is Route.Markup -> uz.metrx.app.ui.markup.MarkupScreen(route)
                                    Route.LiveCam -> uz.metrx.app.ui.markup.LiveCamScreen()
                                    Route.LaserTest -> uz.metrx.app.ui.main.LaserTestScreen()
                                    Route.LaserRadar -> uz.metrx.app.ui.main.LaserRadarScreen()
                                }
                                // the page sliding away takes no taps, so a second tap cannot create or go back twice
                                if (t != app.tab || pageKey(route) != pageKey(app.top)) Box(Modifier.matchParentSize().pointerInput(Unit) {
                                    awaitPointerEventScope { while (true) awaitPointerEvent(PointerEventPass.Initial).changes.forEach { it.consume() } }
                                })
                            }
                        }
                    }
                }
                // the tab bar shows on the tab pages and the project page; it steps away under a sheet
                val navOn = !inAuth && !editMe && app.sheet == null && (app.top == Route.Root || app.top is Route.Project || app.top is Route.Measure)
                if (navOn) Box(Modifier.align(Alignment.BottomCenter)) { GlassNav(app.tab, { app.selectTab(it) }) }
                when (val sh = app.sheet) {
                    Sheet.Language -> LanguageSheet(lang, { settings.setLanguage(it); app.sheet = null }) { app.sheet = null }
                    Sheet.Device -> DeviceSheet(onClose = { app.sheet = null }, onTest = { app.sheet = null; app.push(Route.LaserTest) }, onRadar = { app.sheet = null; app.push(Route.LaserRadar) })
                    null -> {}
                    else -> if (!uz.metrx.app.ui.win.WinSheet(sh) && !uz.metrx.app.ui.plumb.PlumbSheet(sh) && !uz.metrx.app.ui.elec.ElecSheet(sh) && !uz.metrx.app.ui.tiles.TileSheet(sh) && !uz.metrx.app.ui.furniture.OrderFlowSheet(sh) && !uz.metrx.app.ui.furniture.BazisSheet(sh) && !uz.metrx.app.ui.furniture.FreeSheet(sh) && !uz.metrx.app.ui.projects.TradeSheet(sh) && !uz.metrx.app.ui.furniture.FurnitureSheet(sh) && !uz.metrx.app.ui.furniture.KitchenSheet(sh) && !uz.metrx.app.ui.furniture.WardrobeSheet(sh) && !uz.metrx.app.ui.furniture.PriceSheet(sh) && !uz.metrx.app.ui.furniture.WorkshopSheet(sh) && !ProjectSheet(sh) && !uz.metrx.app.ui.main.ProfileSheet(sh) && !uz.metrx.app.ui.measure.MeasureSheet(sh) && !uz.metrx.app.ui.markup.MarkupSheet(sh)) uz.metrx.app.ui.editor.EditorSheet(sh)
                }
                if (soon) SoonSheet(onLocal = { soon = false; authNav.local() }, onClose = { soon = false })
                uz.metrx.app.laser.LaserWaitBar(app)
                ToastHost(app.toast) { app.toast = null }
                uz.metrx.app.ui.markup.PhotoIntake(app)
            }
            if (splash) {
                // the animation docks its tile where the next screen's header logo is
                val top = WindowInsets.statusBars.getTop(density).toFloat()
                val dock = with(density) {
                    if (inAuth) Rect(Offset(20.dp.toPx(), top + 14.dp.toPx()), Size(28.dp.toPx(), 28.dp.toPx()))
                    else Rect(Offset(20.dp.toPx(), top + 13.dp.toPx()), Size(38.dp.toPx(), 38.dp.toPx()))
                }
                var done by remember { mutableStateOf(false) }
                LaunchedEffect(done) {
                    if (done) { splashFade.animateTo(0f, tween(220)); splash = false }
                }
                RoomHops(dock, onDone = { done = true }, modifier = Modifier.alpha(splashFade.value))
            }
        }
    }
}

/** A page's identity: what it shows inside (project tab and view, editor mode) does not make it another page. */
private fun pageKey(r: Route): Any = when (r) {
    is Route.Project -> "project:" + r.id
    is Route.Editor -> "editor:" + r.pid + ":" + r.rid
    is Route.Measure -> "measure"
    is Route.Markup -> "markup:" + r.iid
    is Route.Kitchen -> "kitchen:" + r.pid + ":" + r.fid
    is Route.Wardrobe -> "wardrobe:" + r.pid + ":" + r.fid
    else -> r
}

private val Int.dp get() = androidx.compose.ui.unit.Dp(this.toFloat())
