package dev.eclipsecobblemon.launcher

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import android.graphics.Bitmap
import androidx.compose.material.icons.filled.Add
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import dev.eclipsecobblemon.launcher.auth.SkinVariant
import dev.eclipsecobblemon.launcher.game.PackSync
import kotlin.math.roundToInt
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.TextButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import dev.eclipsecobblemon.launcher.LauncherViewModel.Stage
import dev.eclipsecobblemon.launcher.auth.MicrosoftLoginActivity
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

// ---------- Tema: "Constelación" sobria sobre el diseño original ----------

private val Gold = Color(0xFFF5C542)
private val GoldHi = Color(0xFFF8D46A)
private val GoldLo = Color(0xFFE5B33A)
private val Night = Color(0xFF07070A)
private val Ivory = Color(0xFFF3EEDF)
private val Muted = Color(0xFFA39C88)
private val Dim = Color(0xFF6E6858)
private val SheetBg = Color(0xFF111015)
private val Surface = Color(0xFF0F0E13)
private val Hair = Ivory.copy(alpha = .10f)
private val Online = Color(0xFF7BD88F)
private val Danger = Color(0xFFE07A6B)

@OptIn(ExperimentalTextApi::class)
private fun lexend(weight: Int) =
    Font(R.font.lexend, FontWeight(weight), variationSettings = FontVariation.Settings(FontVariation.weight(weight)))

private val Lexend = FontFamily(lexend(300), lexend(400), lexend(500), lexend(600), lexend(700))

private val LexendTypography = Typography().run {
    fun TextStyle.l() = copy(fontFamily = Lexend)
    Typography(
        displayLarge.l(), displayMedium.l(), displaySmall.l(), headlineLarge.l(), headlineMedium.l(),
        headlineSmall.l(), titleLarge.l(), titleMedium.l(), titleSmall.l(), bodyLarge.l(), bodyMedium.l(),
        bodySmall.l(), labelLarge.l(), labelMedium.l(), labelSmall.l(),
    )
}

private val EclipseColors = darkColorScheme(
    primary = Gold,
    onPrimary = Night,
    background = Night,
    surface = SheetBg,
    surfaceContainer = SheetBg,
    onBackground = Ivory,
    onSurface = Ivory,
    onSurfaceVariant = Muted,
)

private enum class Sheet { PROFILE, SETTINGS }

/** Servidor de la comunidad. Sin dirección todavía: la tarjeta lo indica. */
private const val SERVER_NAME = "Eclipse Cobblemon"
private val SERVER_ADDRESS: String? = null

/** Enlaces de la comunidad (botones de la tarjeta del castillo). */
private const val SITE_URL = "https://eclipse-cobblemon0.netlify.app/"
private const val DISCORD_URL = "https://discord.gg/UCcXN3xqmn"

class MainActivity : ComponentActivity() {
    private val vm: LauncherViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MaterialTheme(colorScheme = EclipseColors, typography = LexendTypography) {
                Box(Modifier.fillMaxSize().background(Night)) {
                    // Sin sesión: pantalla de acceso propia; el launcher solo existe con cuenta
                    Crossfade(vm.account == null, animationSpec = tween(450), label = "auth") { loggedOut ->
                        if (loggedOut) LoginScreen(vm) else LauncherScreen(vm)
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        vm.onLauncherResumed()
    }
}

// ---------- Pantalla principal ----------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LauncherScreen(vm: LauncherViewModel) {
    var sheet by remember { mutableStateOf<Sheet?>(null) }
    val activity = LocalContext.current as Activity
    val busy = vm.busy && vm.stage != Stage.LAUNCHING

    val openProfile = { sheet = Sheet.PROFILE }

    Column(Modifier.fillMaxSize().safeDrawingPadding().padding(horizontal = 20.dp, vertical = 10.dp)) {
        Header(vm, onAvatar = openProfile)
        Spacer(Modifier.height(14.dp))

        // Tarjeta del castillo con el botón de play montado en su borde inferior
        Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.BottomCenter) {
            HeroCard(dim = busy, modifier = Modifier.fillMaxSize().padding(bottom = 56.dp))
            Crossfade(busy, label = "play") { loading ->
                if (loading) ProgressRing(vm) else PlayButton {
                    vm.play(activity)
                }
            }
        }

        Spacer(Modifier.height(16.dp))
        StatusBlock(vm, busy)
        Spacer(Modifier.height(10.dp))
        StarStrip(
            lit = when {
                !busy -> 0f
                vm.stage == Stage.JAVA -> vm.javaProgress ?: 0f
                else -> vm.progress ?: 0f
            },
            idle = !busy,
            modifier = Modifier.align(Alignment.CenterHorizontally).width(300.dp).height(40.dp),
        )
        Box(Modifier.fillMaxWidth().height(22.dp), contentAlignment = Alignment.Center) {
            if (busy) StepLabels(vm.stage, vm.packEnabled)
        }
        Spacer(Modifier.height(12.dp))
        NavBar(
            onProfile = openProfile,
            onSettings = { sheet = Sheet.SETTINGS },
        )
    }

    AnimatedVisibility(vm.stage == Stage.LAUNCHING, enter = fadeIn(tween(500)), exit = fadeOut(tween(400))) {
        LaunchingScreen(vm.renderer.label)
    }

    sheet?.let { current ->
        ModalBottomSheet(
            onDismissRequest = { sheet = null },
            containerColor = SheetBg,
            shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
            scrimColor = Color(0xFF050508).copy(alpha = .62f),
            dragHandle = {
                Box(Modifier.padding(top = 12.dp).size(40.dp, 4.dp).background(Ivory.copy(alpha = .18f), CircleShape))
            },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp).padding(top = 18.dp, bottom = 28.dp).navigationBarsPadding(),
            ) {
                when (current) {
                    Sheet.PROFILE -> ProfileSheet(vm, onSettings = { sheet = Sheet.SETTINGS })
                    Sheet.SETTINGS -> SettingsSheet(vm)
                }
            }
        }
    }
}

// ---------- Acceso (sin sesión) ----------

@Composable
private fun LoginScreen(vm: LauncherViewModel) {
    Box(Modifier.fillMaxSize().background(Night)) {
        Image(
            painterResource(R.drawable.bg_eclipse),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize().scale(1.08f),
        )
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    0f to Night.copy(alpha = .55f),
                    .25f to Night.copy(alpha = .1f),
                    .5f to Night.copy(alpha = .35f),
                    .7f to Night,
                )
            )
        )
        Column(
            Modifier.align(Alignment.TopCenter).safeDrawingPadding().padding(top = 56.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Moon(Modifier.size(56.dp), cut = Color(0xFF0C0C12))
            Spacer(Modifier.height(16.dp))
            Text("ECLIPSE COBBLEMON", color = Gold, fontSize = 20.sp, fontWeight = FontWeight.SemiBold, letterSpacing = .18.em)
            Spacer(Modifier.height(6.dp))
            Text("Minecraft ${LauncherViewModel.DEFAULT_VERSION} · Cobblemon", color = Ivory.copy(alpha = .7f), fontSize = 13.sp)
        }
        Column(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth()
                .clip(RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp))
                .background(SheetBg)
                .border(1.dp, Hair, RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp))
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp).padding(top = 26.dp, bottom = 28.dp)
                .navigationBarsPadding().imePadding(),
        ) {
            LoginSheet(vm)
        }
    }
}

@Composable
private fun Header(vm: LauncherViewModel, onAvatar: () -> Unit) {
    Row(Modifier.fillMaxWidth().height(44.dp), verticalAlignment = Alignment.CenterVertically) {
        Moon(Modifier.size(30.dp))
        Spacer(Modifier.width(12.dp))
        Text(
            "ECLIPSE COBBLEMON",
            color = Gold, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, letterSpacing = .16.em, maxLines = 1,
        )
        Spacer(Modifier.weight(1f))
        Box(
            Modifier.size(40.dp).clip(RoundedCornerShape(10.dp)).border(1.dp, Gold.copy(alpha = .45f), RoundedCornerShape(10.dp)).clickable(onClick = onAvatar),
            contentAlignment = Alignment.Center,
        ) {
            val name = vm.account?.username
            if (name != null) PlayerHead(vm.skinTexture, name, 15.sp, Modifier.fillMaxSize())
            else Icon(Icons.Filled.Person, "Iniciar sessão", tint = Gold, modifier = Modifier.size(20.dp))
        }
    }
}

/** Luna creciente: disco dorado tapado por otro del color del fondo. */
@Composable
private fun Moon(modifier: Modifier, cut: Color = Night) {
    Canvas(modifier) {
        val r = size.minDimension / 2
        drawCircle(Gold, r * .82f)
        drawCircle(cut, r * .68f, center = center + Offset(r * .36f, -r * .2f))
    }
}

@Composable
private fun HeroCard(dim: Boolean, modifier: Modifier) {
    val shape = RoundedCornerShape(26.dp)
    val veil by animateFloatAsState(if (dim) .5f else 0f, tween(600), label = "veil")
    Box(modifier.clip(shape).border(1.dp, Gold.copy(alpha = .32f), shape)) {
        Image(
            painterResource(R.drawable.bg_eclipse),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            colorFilter = if (dim) ColorFilter.colorMatrix(ColorMatrix().apply { setToSaturation(.45f) }) else null,
            modifier = Modifier.fillMaxSize().scale(1.08f),
        )
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    0f to Night.copy(alpha = .25f),
                    .3f to Color.Transparent,
                    .55f to Color.Transparent,
                    1f to Night.copy(alpha = .8f),
                )
            )
        )
        Box(Modifier.fillMaxSize().background(Night.copy(alpha = veil)))
        ServerChip(Modifier.align(Alignment.TopCenter).padding(14.dp))
        // Site y Discord, en las esquinas inferiores a los lados del botón de jugar
        LinkPill(R.drawable.ic_site, "Site", SITE_URL, Modifier.align(Alignment.BottomStart).padding(14.dp))
        LinkPill(R.drawable.ic_discord, "Discord", DISCORD_URL, Modifier.align(Alignment.BottomEnd).padding(14.dp))
    }
}

@Composable
private fun LinkPill(icon: Int, label: String, url: String, modifier: Modifier) {
    val uri = LocalUriHandler.current
    Row(
        modifier.height(34.dp).clip(CircleShape).background(Night.copy(alpha = .62f)).border(1.dp, Hair, CircleShape)
            .clickable { runCatching { uri.openUri(url) } }.padding(start = 12.dp, end = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(painterResource(icon), null, tint = Gold, modifier = Modifier.size(15.dp))
        Spacer(Modifier.width(6.dp))
        Text(label, fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = Ivory, maxLines = 1)
    }
}

@Composable
private fun ServerChip(modifier: Modifier) {
    Row(
        modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Night.copy(alpha = .62f))
            .border(1.dp, Hair, RoundedCornerShape(14.dp)).padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(8.dp).background(if (SERVER_ADDRESS != null) Online else Dim, CircleShape))
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(SERVER_NAME, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Ivory)
            Text(SERVER_ADDRESS ?: "Servidor oficial · em breve", fontSize = 11.5.sp, color = Muted)
        }
    }
}

@Composable
private fun PlayButton(onClick: () -> Unit) {
    Box(
        Modifier.size(112.dp).clip(CircleShape).background(Night).border(1.dp, Gold.copy(alpha = .35f), CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier.size(88.dp).background(Brush.verticalGradient(listOf(GoldHi, GoldLo)), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.PlayArrow, "Jugar", tint = Color(0xFF15110A), modifier = Modifier.size(46.dp))
        }
    }
}

/** El botón de play convertido en anillo de progreso (indeterminado si no hay porcentaje). */
@Composable
private fun ProgressRing(vm: LauncherViewModel) {
    val value = if (vm.stage == Stage.JAVA) vm.javaProgress else vm.progress
    val spin by rememberInfiniteTransition(label = "spin").animateFloat(
        0f, 360f, infiniteRepeatable(tween(1400, easing = LinearEasing)), label = "a",
    )
    val shown by animateFloatAsState(value ?: 0f, tween(300), label = "p")
    Box(Modifier.size(112.dp).background(Night, CircleShape), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize().padding(5.dp)) {
            val stroke = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round)
            drawCircle(Gold.copy(alpha = .16f), style = Stroke(2.5.dp.toPx()))
            if (value != null) drawArc(Gold, -90f, 360f * shown, false, style = stroke)
            else drawArc(Gold, spin - 90f, 70f, false, style = stroke)
        }
        if (value != null) Row(verticalAlignment = Alignment.Bottom) {
            Text("${(value * 100).toInt()}", fontSize = 26.sp, fontWeight = FontWeight.SemiBold, color = Ivory)
            Text("%", fontSize = 13.sp, color = Muted, modifier = Modifier.padding(bottom = 4.dp, start = 1.dp))
        } else Moon(Modifier.size(34.dp))
    }
}

@Composable
private fun ColumnScope.StatusBlock(vm: LauncherViewModel, busy: Boolean) {
    val acc = vm.account
    val (title, sub) = when {
        busy && vm.stage == Stage.FILES -> "A transferir ficheiros" to "%,d de %,d".format(vm.filesDone, vm.filesTotal).replace(',', '.')
        busy && vm.stage == Stage.PACK -> "A sincronizar o pack" to
            if (vm.packTotal > 0) "${PackSync.mb(vm.packDone)} de ${PackSync.mb(vm.packTotal)}" else "A verificar mods e ficheiros…"
        busy && vm.stage == Stage.JAVA -> "A preparar o Java" to (vm.javaProgress?.let { "A instalar · ${(it * 100).toInt()} %" } ?: "A verificar o runtime…")
        busy -> "A preparar o Minecraft ${vm.selectedVersion}" to "A ler a versão…"
        acc == null -> "Bem-vindo" to "Inicie sessão para jogar"
        else -> "Minecraft ${vm.selectedVersion}" to "${acc.username} · pronto para jogar"
    }
    Text(title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Ivory, modifier = Modifier.align(Alignment.CenterHorizontally))
    Spacer(Modifier.height(3.dp))
    Text(sub, fontSize = 12.5.sp, color = Muted, modifier = Modifier.align(Alignment.CenterHorizontally))
}

/** Línea de estrellas: se encienden de izquierda a derecha con el progreso. */
@Composable
private fun StarStrip(lit: Float, idle: Boolean, modifier: Modifier) {
    val t by rememberInfiniteTransition(label = "tw").animateFloat(
        0f, (2 * PI).toFloat(), infiniteRepeatable(tween(4000, easing = LinearEasing)), label = "t",
    )
    val shown by animateFloatAsState(lit, tween(400), label = "lit")
    Canvas(modifier) {
        val n = 13
        val pts = List(n) { k ->
            Offset(size.width * k / (n - 1), size.height / 2 + sin(k * .9f) * size.height * .32f)
        }
        val on = if (idle) -1 else (shown * (n - 1)).toInt()
        val hair = Ivory.copy(alpha = .10f)
        for (k in 0 until n - 1) {
            drawLine(if (k < on) Gold.copy(alpha = .55f) else hair, pts[k], pts[k + 1], 1.dp.toPx())
        }
        pts.forEachIndexed { k, p ->
            val twinkle = .45f + .55f * ((sin(t + k * .8f) + 1) / 2)
            when {
                k <= on -> drawCircle(Gold.copy(alpha = if (k == on) twinkle else 1f), 2.6.dp.toPx(), p)
                idle -> drawCircle(Gold.copy(alpha = .25f + .45f * twinkle), 1.9.dp.toPx(), p)
                else -> drawCircle(Ivory.copy(alpha = .28f), 1.8.dp.toPx(), p)
            }
        }
    }
}

@Composable
private fun StepLabels(stage: Stage, withPack: Boolean) {
    val steps = listOfNotNull(
        "Versão" to Stage.VERSION,
        "Ficheiros" to Stage.FILES,
        ("Mods" to Stage.PACK).takeIf { withPack },
        "Java" to Stage.JAVA,
        "Iniciar" to Stage.LAUNCHING,
    )
    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        steps.forEach { (label, s) ->
            val done = s.ordinal < stage.ordinal
            val current = s == stage
            Text(
                (if (done) "✓ " else "") + label,
                fontSize = 11.5.sp,
                fontWeight = if (current) FontWeight.Bold else FontWeight.Medium,
                color = when { done -> Gold; current -> Ivory; else -> Dim },
            )
        }
    }
}

@Composable
private fun NavBar(onProfile: () -> Unit, onSettings: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    Row(Modifier.fillMaxWidth().height(58.dp).clip(shape).background(Surface).border(1.dp, Hair, shape)) {
        NavItem(Icons.Filled.Person, "Perfil", onProfile)
        Box(Modifier.width(1.dp).fillMaxHeight().background(Hair))
        NavItem(Icons.Filled.Settings, "Definições", onSettings)
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.NavItem(icon: ImageVector, label: String, onClick: () -> Unit) {
    Row(
        Modifier.weight(1f).fillMaxHeight().clickable(onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(icon, null, tint = Gold, modifier = Modifier.size(19.dp))
        Spacer(Modifier.width(8.dp))
        Text(label, color = Ivory, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

// ---------- Lanzando ----------

@Composable
private fun LaunchingScreen(renderer: String) {
    val stars = remember { List(26) { floatArrayOf(Random.nextFloat(), Random.nextFloat(), Random.nextFloat() * 6.28f, 1f + Random.nextFloat()) } }
    val inf = rememberInfiniteTransition(label = "launch")
    val t by inf.animateFloat(0f, (2 * PI).toFloat(), infiniteRepeatable(tween(4000, easing = LinearEasing)), label = "t")
    val shimmer by inf.animateFloat(-.4f, 1f, infiniteRepeatable(tween(1600)), label = "s")
    Box(
        Modifier.fillMaxSize().background(Night)
            .clickable(remember { MutableInteractionSource() }, indication = null) {}, // bloquea toques al fondo
    ) {
        Canvas(Modifier.fillMaxSize()) {
            stars.forEach { (x, y, ph, s) ->
                val a = .15f + .45f * ((sin(t + ph) + 1) / 2)
                drawCircle(Ivory.copy(alpha = a), s.dp.toPx() / 2 + .5f, Offset(size.width * x, size.height * y))
            }
        }
        Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
            Constellation(t, Modifier.size(220.dp))
            Spacer(Modifier.height(40.dp))
            Text("A entrar no mundo", fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = Ivory)
            Spacer(Modifier.height(8.dp))
            Text("Minecraft ${LauncherViewModel.DEFAULT_VERSION} · $renderer", fontSize = 13.sp, color = Muted)
            Spacer(Modifier.height(20.dp))
            Box(Modifier.width(160.dp).height(2.dp).background(Ivory.copy(alpha = .08f))) {
                Canvas(Modifier.fillMaxSize()) {
                    val w = size.width * .4f
                    drawLine(Gold, Offset(size.width * shimmer, size.height / 2), Offset(size.width * shimmer + w, size.height / 2), size.height)
                }
            }
        }
        Text(
            "Dica: pode editar os controlos táteis no menu do jogo.",
            fontSize = 12.5.sp, color = Dim, textAlign = TextAlign.Center, lineHeight = 19.sp,
            modifier = Modifier.align(Alignment.BottomCenter).safeDrawingPadding().padding(horizontal = 36.dp, vertical = 40.dp),
        )
    }
}

/** Luna creciente dibujada con estrellas, que laten en secuencia. */
@Composable
private fun Constellation(t: Float, modifier: Modifier) {
    Canvas(modifier) {
        val s = size.minDimension
        val pts = buildList {
            repeat(18) { k ->
                val a = Math.toRadians(50.0 + k * 260.0 / 17).toFloat()
                add(Offset(s / 2 + cos(a) * s * .42f, s / 2 + sin(a) * s * .42f))
            }
            repeat(9) { k ->
                val a = Math.toRadians(100.0 + k * 20.0).toFloat()
                add(Offset(s * .46f + cos(a) * s * .30f, s / 2 + sin(a) * s * .30f))
            }
        }
        val outline = Path().apply {
            pts.take(18).forEachIndexed { i, p -> if (i == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y) }
        }
        drawPath(outline, Gold.copy(alpha = .18f), style = Stroke(1.dp.toPx()))
        pts.forEachIndexed { k, p ->
            val pulse = .55f + .45f * ((sin(t * 1.5f - k * .35f) + 1) / 2)
            drawCircle(Gold.copy(alpha = .18f * pulse), 7.dp.toPx(), p)
            drawCircle(Gold.copy(alpha = pulse), 3.dp.toPx(), p)
        }
    }
}

// ---------- Paneles ----------

@Composable
private fun SheetTitle(text: String) {
    Text(text, fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = Ivory)
}

@Composable
private fun GoldButton(text: String, icon: ImageVector? = null, enabled: Boolean = true, loading: Boolean = false, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier.fillMaxWidth().height(54.dp).clip(shape)
            .background(if (enabled) Gold else Gold.copy(alpha = .35f))
            .clickable(enabled = enabled && !loading, onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        if (loading) CircularProgressIndicator(Modifier.size(18.dp), color = Night, strokeWidth = 2.dp)
        else if (icon != null) Icon(icon, null, tint = Color(0xFF15110A), modifier = Modifier.size(19.dp))
        Spacer(Modifier.width(10.dp))
        Text(text, color = Color(0xFF15110A), fontWeight = FontWeight.Bold, fontSize = 15.sp)
    }
}

@Composable
private fun OutlineButton(
    text: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = Ivory,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier.height(50.dp).clip(shape).border(1.dp, if (tint == Ivory) Hair else tint.copy(alpha = .35f), shape)
            .clickable(enabled = enabled, onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(icon, null, tint = if (enabled) tint else Dim, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(text, color = if (enabled) tint else Dim, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
    }
}

private val NAME_RE = Regex("^[A-Za-z0-9_]{3,16}$")

@Composable
private fun LoginSheet(vm: LauncherViewModel) {
    val ctx = LocalContext.current
    val login = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { r ->
        vm.onMicrosoftCode(
            r.data?.getStringExtra(MicrosoftLoginActivity.EXTRA_CODE),
            r.data?.getStringExtra(MicrosoftLoginActivity.EXTRA_ERROR),
        )
    }
    var name by remember { mutableStateOf("") }
    val valid = NAME_RE.matches(name)

    SheetTitle("Iniciar sessão")
    Spacer(Modifier.height(6.dp))
    Text("Use a sua conta do Minecraft: Java Edition ou jogue sem ligação.", fontSize = 13.5.sp, color = Muted, lineHeight = 20.sp)
    Spacer(Modifier.height(20.dp))
    GoldButton(
        if (vm.loggingIn) "A verificar a conta…" else "Continuar com a Microsoft",
        icon = Icons.Filled.Lock, loading = vm.loggingIn,
    ) { login.launch(Intent(ctx, MicrosoftLoginActivity::class.java)) }

    Row(Modifier.padding(vertical = 18.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.weight(1f).height(1.dp).background(Hair))
        Text("ou sem ligação", fontSize = 12.sp, color = Dim, modifier = Modifier.padding(horizontal = 12.dp))
        Box(Modifier.weight(1f).height(1.dp).background(Hair))
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        OutlinedTextField(
            value = name,
            onValueChange = { name = it.take(16) },
            placeholder = { Text("Nome do jogador", color = Dim) },
            singleLine = true,
            shape = RoundedCornerShape(16.dp),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { if (valid) vm.loginOffline(name) }),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Gold.copy(alpha = .6f), unfocusedBorderColor = Hair,
                cursorColor = Gold, focusedTextColor = Ivory, unfocusedTextColor = Ivory,
            ),
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(10.dp))
        Box(
            Modifier.size(56.dp).clip(RoundedCornerShape(16.dp))
                .border(1.dp, Gold.copy(alpha = if (valid) .5f else .15f), RoundedCornerShape(16.dp))
                .clickable(enabled = valid) { vm.loginOffline(name) },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.AutoMirrored.Filled.ArrowForward, "Entrar sem ligação", tint = if (valid) Gold else Dim)
        }
    }
    Spacer(Modifier.height(10.dp))
    Text(
        if (name.isNotEmpty() && !valid) "3–16 caracteres: letras, números ou _" else "Sem ligação: um jogador e servidores não premium.",
        fontSize = 12.sp, color = if (name.isNotEmpty() && !valid) GoldLo else Dim,
    )
}

@Composable
private fun ColumnScope.ProfileSheet(vm: LauncherViewModel, onSettings: () -> Unit) {
    val acc = vm.account ?: return
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier.size(60.dp).clip(RoundedCornerShape(12.dp)).background(Surface).border(1.dp, Gold.copy(alpha = .45f), RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center,
        ) {
            PlayerHead(vm.skinTexture, acc.username, 22.sp, Modifier.fillMaxSize())
        }
        Spacer(Modifier.width(14.dp))
        Column {
            Text(acc.username, fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = Ivory)
            Text(if (acc.isPremium) "Microsoft" else "Offline", fontSize = 12.5.sp, color = if (acc.isPremium) Gold else Muted)
        }
    }
    Spacer(Modifier.height(18.dp))
    var tab by rememberSaveable { mutableStateOf(0) }
    Segmented(listOf("Conta", "Skin"), tab) { tab = it }
    Spacer(Modifier.height(16.dp))
    if (tab == 1) return SkinTab(vm)
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Tile(Icons.Filled.Star, "Versão", vm.selectedVersion, Modifier.weight(1f), onSettings)
        Tile(Icons.Filled.Settings, "Memória", "${vm.ramMb} MB", Modifier.weight(1f), onSettings)
        Tile(Icons.Filled.Build, "Renderer", vm.renderer.label, Modifier.weight(1f), onSettings)
    }
    Spacer(Modifier.height(18.dp))
    OutlineButton("Terminar sessão", Icons.AutoMirrored.Filled.ExitToApp, Modifier.fillMaxWidth(), enabled = !vm.busy, onClick = vm::logout)
}

/** Cabeza (con capa) recortada de la textura de la skin; mientras carga, la inicial. */
@Composable
private fun PlayerHead(texture: Bitmap?, username: String, fallbackSize: TextUnit, modifier: Modifier) {
    val img = remember(texture) { texture?.asImageBitmap() }
    if (img == null) {
        Text(username.take(1).uppercase(), color = Gold, fontWeight = FontWeight.Bold, fontSize = fallbackSize)
        return
    }
    Canvas(modifier) {
        val px = size.minDimension / 8
        skinPart(img, 8, 8, 8, 8, 0, 0, px)
        skinPart(img, 40, 8, 8, 8, 0, 0, px)
    }
}

/** Dibuja un rectángulo de la textura (píxeles de skin) en la celda (dx, dy), sin suavizado. */
private fun DrawScope.skinPart(
    img: ImageBitmap, sx: Int, sy: Int, w: Int, h: Int, dx: Int, dy: Int, px: Float,
    origin: Offset = Offset.Zero, scale: Int = 1,
) {
    val x0 = (origin.x + dx * px).roundToInt()
    val y0 = (origin.y + dy * px).roundToInt()
    val x1 = (origin.x + (dx + w) * px).roundToInt()
    val y1 = (origin.y + (dy + h) * px).roundToInt()
    drawImage(
        img, IntOffset(sx * scale, sy * scale), IntSize(w * scale, h * scale),
        IntOffset(x0, y0), IntSize(x1 - x0, y1 - y0), filterQuality = FilterQuality.None,
    )
}

/**
 * Jugador completo en 2D, de frente o de espaldas (16×32 píxeles de skin), con la capa
 * de la skin encima. Soporta skins 64×64 y las antiguas 64×32 (brazo/pierna izquierdos = derechos).
 */
@Composable
private fun SkinFigure(texture: Bitmap, slim: Boolean, back: Boolean, cape: Bitmap?, modifier: Modifier) {
    val img = remember(texture) { texture.asImageBitmap() }
    val capeImg = remember(cape) { cape?.asImageBitmap() }
    Canvas(modifier) {
        val px = minOf(size.width / 16, size.height / 32)
        val o = Offset((size.width - 16 * px) / 2, (size.height - 32 * px) / 2)
        val aw = if (slim) 3 else 4
        val legacy = img.height == 32
        fun p(sx: Int, sy: Int, w: Int, h: Int, dx: Int, dy: Int) = skinPart(img, sx, sy, w, h, dx, dy, px, o)
        if (!back) {
            p(8, 8, 8, 8, 4, 0); p(20, 20, 8, 12, 4, 8)
            p(44, 20, aw, 12, 4 - aw, 8)
            if (legacy) p(44, 20, aw, 12, 12, 8) else p(36, 52, aw, 12, 12, 8)
            p(4, 20, 4, 12, 4, 20)
            if (legacy) p(4, 20, 4, 12, 8, 20) else p(20, 52, 4, 12, 8, 20)
            p(40, 8, 8, 8, 4, 0)
            if (!legacy) {
                p(20, 36, 8, 12, 4, 8); p(44, 36, aw, 12, 4 - aw, 8); p(52, 52, aw, 12, 12, 8)
                p(4, 36, 4, 12, 4, 20); p(4, 52, 4, 12, 8, 20)
            }
        } else {
            val rx = if (slim) 51 else 52
            val lx = if (slim) 43 else 44
            p(24, 8, 8, 8, 4, 0); p(32, 20, 8, 12, 4, 8)
            p(rx, 20, aw, 12, 12, 8)
            if (legacy) p(rx, 20, aw, 12, 4 - aw, 8) else p(lx, 52, aw, 12, 4 - aw, 8)
            p(12, 20, 4, 12, 8, 20)
            if (legacy) p(12, 20, 4, 12, 4, 20) else p(28, 52, 4, 12, 4, 20)
            p(56, 8, 8, 8, 4, 0)
            if (!legacy) {
                p(32, 36, 8, 12, 4, 8); p(rx, 36, aw, 12, 12, 8); p(lx + 16, 52, aw, 12, 4 - aw, 8)
                p(12, 36, 4, 12, 8, 20); p(12, 52, 4, 12, 4, 20)
            }
            capeImg?.let { skinPart(it, 1, 1, 10, 16, 3, 8, px, o, scale = maxOf(1, it.width / 64)) }
        }
    }
}

/** Parte trasera de una capa, para los selectores. */
@Composable
private fun CapeThumb(cape: Bitmap, modifier: Modifier) {
    val img = remember(cape) { cape.asImageBitmap() }
    Canvas(modifier) {
        val px = minOf(size.width / 10, size.height / 16)
        skinPart(img, 1, 1, 10, 16, 0, 0, px, Offset((size.width - 10 * px) / 2, 0f), scale = maxOf(1, img.width / 64))
    }
}

@Composable
private fun Segmented(options: List<String>, selected: Int, enabled: Boolean = true, onSelect: (Int) -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    Row(Modifier.fillMaxWidth().height(44.dp).clip(shape).background(Surface).border(1.dp, Hair, shape).padding(4.dp)) {
        options.forEachIndexed { i, label ->
            val on = i == selected
            Box(
                Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(10.dp))
                    .background(if (on) Gold.copy(alpha = .14f) else Color.Transparent)
                    .clickable(enabled = enabled) { onSelect(i) },
                contentAlignment = Alignment.Center,
            ) {
                Text(label, color = if (on) Gold else if (enabled) Muted else Dim, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun ColumnScope.SkinTab(vm: LauncherViewModel) {
    val acc = vm.account ?: return
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri -> uri?.let(vm::pickSkin) }
    val current = vm.skinProfile
    var variant by remember(current?.variant) { mutableStateOf(current?.variant ?: SkinVariant.CLASSIC) }
    val shown = vm.pendingSkin ?: vm.skinTexture
    val cape = current?.activeCape?.let { vm.capeTextures[it.id] }
    val shape = RoundedCornerShape(20.dp)

    // Vista previa: frente y espalda
    Box(
        Modifier.fillMaxWidth().height(230.dp).clip(shape).background(Surface).border(1.dp, Hair, shape),
        contentAlignment = Alignment.Center,
    ) {
        if (shown != null) {
            Row(Modifier.padding(vertical = 18.dp), horizontalArrangement = Arrangement.spacedBy(36.dp)) {
                SkinFigure(shown, variant == SkinVariant.SLIM, back = false, cape = null, modifier = Modifier.width(96.dp).fillMaxHeight())
                SkinFigure(shown, variant == SkinVariant.SLIM, back = true, cape = cape, modifier = Modifier.width(96.dp).fillMaxHeight())
            }
        } else if (vm.skinBusy) {
            CircularProgressIndicator(Modifier.size(26.dp), color = Gold, strokeWidth = 2.dp)
        } else {
            Text("Skin indisponível", color = Dim, fontSize = 13.sp)
        }
        if (vm.pendingSkin != null) {
            Text(
                "Nova · por aplicar", color = Night, fontSize = 11.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.TopStart).padding(12.dp)
                    .background(Gold, CircleShape).padding(horizontal = 10.dp, vertical = 3.dp),
            )
        }
    }

    if (!acc.isPremium) {
        Spacer(Modifier.height(14.dp))
        Text(
            "As contas offline não têm skin na Mojang: a pré-visualização mostra a skin associada a este nome. " +
                "Em breve poderá escolher a sua skin no servidor Eclipse.",
            fontSize = 13.sp, color = Muted, lineHeight = 19.sp,
        )
        return
    }

    Spacer(Modifier.height(16.dp))
    Text("Modelo", fontSize = 13.sp, color = Muted)
    Spacer(Modifier.height(8.dp))
    Segmented(listOf("Clássico", "Fino"), variant.ordinal, enabled = !vm.skinBusy && shown != null) {
        variant = SkinVariant.entries[it]
    }

    Spacer(Modifier.height(14.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlineButton("Escolher imagem", Icons.Filled.Add, Modifier.weight(1f), enabled = !vm.skinBusy) { picker.launch("image/*") }
        OutlineButton("Repor", Icons.Filled.Refresh, Modifier.weight(1f), enabled = !vm.skinBusy) { vm.resetSkin() }
    }
    Spacer(Modifier.height(10.dp))
    val dirty = vm.pendingSkin != null || (current != null && variant != current.variant)
    GoldButton(
        if (vm.skinBusy && dirty) "A aplicar…" else "Aplicar skin", icon = Icons.Filled.Check,
        enabled = dirty, loading = vm.skinBusy && dirty,
    ) { vm.applySkin(variant) }
    if (vm.pendingSkin != null) {
        TextButton(onClick = vm::clearPendingSkin, modifier = Modifier.align(Alignment.CenterHorizontally)) {
            Text("Descartar", color = Muted)
        }
    }

    if (current != null && current.capes.isNotEmpty()) {
        Spacer(Modifier.height(18.dp))
        Text("Capa", fontSize = 13.sp, color = Muted)
        Spacer(Modifier.height(8.dp))
        val options = listOf(null) + current.capes
        options.chunked(4).forEach { row ->
            Row(Modifier.padding(bottom = 10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { c ->
                    val mod = Modifier.weight(1f)
                    if (c == null) CapeChip("Nenhuma", null, current.activeCape == null, !vm.skinBusy, mod) { vm.setCape(null) }
                    else CapeChip(c.alias, vm.capeTextures[c.id], c.active, !vm.skinBusy, mod) { vm.setCape(c.id) }
                }
                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }

    vm.skinMessage?.let {
        Spacer(Modifier.height(12.dp))
        Text(it, fontSize = 12.5.sp, color = if (it.startsWith("Skin ")) Online else GoldLo, lineHeight = 18.sp)
    }
    Spacer(Modifier.height(10.dp))
    Text(
        "As alterações aplicam-se à sua conta Microsoft: verá a nova skin em todos os servidores e no PC.",
        fontSize = 12.sp, color = Dim, lineHeight = 18.sp,
    )
}

@Composable
private fun CapeChip(label: String, texture: Bitmap?, selected: Boolean, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    Column(
        modifier.clip(shape).border(1.dp, if (selected) Gold.copy(alpha = .7f) else Hair, shape)
            .clickable(enabled = enabled && !selected, onClick = onClick).padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.height(48.dp), contentAlignment = Alignment.Center) {
            if (texture != null) CapeThumb(texture, Modifier.size(30.dp, 48.dp))
            else Text("—", color = Dim, fontSize = 18.sp)
        }
        Spacer(Modifier.height(6.dp))
        Text(label, fontSize = 11.sp, color = if (selected) Gold else Muted, maxLines = 1, modifier = Modifier.padding(horizontal = 6.dp))
    }
}

@Composable
private fun Tile(icon: ImageVector, label: String, value: String, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    Column(modifier.clip(shape).border(1.dp, Hair, shape).clickable(onClick = onClick).padding(14.dp)) {
        Icon(icon, null, tint = Gold, modifier = Modifier.size(19.dp))
        Spacer(Modifier.height(8.dp))
        Text(label, fontSize = 11.5.sp, color = Muted)
        Text(value, fontSize = if (value.length > 9) 13.sp else 15.sp, fontWeight = FontWeight.Bold, color = Ivory, maxLines = 1)
    }
}

@Composable
private fun SettingsSheet(vm: LauncherViewModel) {
    var showLog by remember { mutableStateOf(false) }
    var confirmWipe by remember { mutableStateOf(false) }
    var pickRenderer by remember { mutableStateOf(false) }
    var editArgs by remember { mutableStateOf(false) }

    SheetTitle("Definições")
    Spacer(Modifier.height(8.dp))

    SettingRow("Versão", vm.selectedVersion)

    Column(Modifier.padding(top = 16.dp, bottom = 12.dp)) {
        Row {
            Text("Memória", fontSize = 15.sp, color = Ivory, modifier = Modifier.weight(1f))
            Text("${vm.ramMb} MB", fontSize = 15.sp, color = Gold)
        }
        Slider(
            value = vm.ramMb.toFloat(),
            onValueChange = { vm.ramMb = (it / 256).toInt() * 256 },
            valueRange = 1024f..6144f,
            enabled = !vm.busy,
            colors = SliderDefaults.colors(thumbColor = Ivory, activeTrackColor = Gold, inactiveTrackColor = Ivory.copy(alpha = .12f)),
        )
        Text("Recomendado para este dispositivo: ${vm.recommendedRamMb} MB", fontSize = 12.sp, color = Muted)
    }
    Box(Modifier.fillMaxWidth().height(1.dp).background(Hair))
    SettingRow("Renderer", vm.renderer.label, chevron = true, enabled = !vm.busy) { pickRenderer = true }
    SettingRow(
        "Argumentos Java", if (vm.jvmArgs.isBlank()) "Predefinidos" else "Personalizados",
        chevron = true, divider = false, enabled = !vm.busy,
    ) { editArgs = true }
    if (pickRenderer) RendererDialog(vm) { pickRenderer = false }
    if (editArgs) JvmArgsDialog(vm) { editArgs = false }

    Spacer(Modifier.height(16.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlineButton("Verificar ficheiros", Icons.Filled.Refresh, Modifier.weight(1f), enabled = !vm.busy) { vm.install() }
        OutlineButton(if (showLog) "Ocultar registo" else "Registo", Icons.AutoMirrored.Filled.List, Modifier.weight(1f)) { showLog = !showLog }
    }
    if (showLog) {
        Spacer(Modifier.height(12.dp))
        LogConsole(vm, Modifier.fillMaxWidth().height(240.dp))
    }
    Spacer(Modifier.height(10.dp))
    // Registos del launcher, de Java y de Minecraft en un .zip, para mandarlos por Discord o WhatsApp
    val activity = LocalContext.current as Activity
    OutlineButton("Partilhar registos", Icons.Filled.Share, Modifier.fillMaxWidth()) { vm.shareLogs(activity) }
    Spacer(Modifier.height(10.dp))
    OutlineButton(
        "Apagar dados do Minecraft", Icons.Filled.Delete, Modifier.fillMaxWidth(),
        enabled = !vm.busy, tint = Danger,
    ) { confirmWipe = true; vm.measureGameData() }

    if (confirmWipe) {
        val size = vm.gameDataBytes
        AlertDialog(
            onDismissRequest = { confirmWipe = false },
            containerColor = SheetBg,
            title = { Text("Apagar dados do Minecraft?", color = Ivory, fontWeight = FontWeight.SemiBold) },
            text = {
                Text(
                    "Serão apagadas versões, bibliotecas, recursos, mundos, mods e definições do jogo" +
                        (if (size != null) " (%.1f MB)".format(size / 1048576.0) else "") +
                        ". A sua conta e o Java mantêm-se instalados. Esta ação não pode ser anulada.",
                    color = Muted, lineHeight = 20.sp,
                )
            },
            confirmButton = {
                TextButton(onClick = { confirmWipe = false; vm.wipeGameData() }) {
                    Text("Apagar tudo", color = Danger, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmWipe = false }) { Text("Cancelar", color = Ivory) }
            },
        )
    }
    Spacer(Modifier.height(18.dp))
    Text("EclipseCobblemon ${BuildConfig.VERSION_NAME} · Runtime Amethyst 1.1.7", fontSize = 11.5.sp, color = Dim)
}

@Composable
private fun RendererDialog(vm: LauncherViewModel, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = SheetBg,
        title = { Text("Renderer", color = Ivory, fontWeight = FontWeight.SemiBold) },
        text = {
            Column {
                vm.renderers.forEach { r ->
                    val selected = r == vm.renderer
                    Row(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                            .clickable { vm.selectRenderer(r); onDismiss() }
                            .padding(vertical = 10.dp, horizontal = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(r.label, fontSize = 15.sp, color = if (selected) Gold else Ivory, fontWeight = FontWeight.SemiBold)
                            Text(r.description, fontSize = 12.5.sp, color = Muted, lineHeight = 17.sp)
                        }
                        if (selected) Icon(Icons.Filled.Check, null, tint = Gold, modifier = Modifier.size(20.dp))
                    }
                }
                Spacer(Modifier.height(8.dp))
                Text("Se o jogo fechar ou tiver gráficos estranhos, experimente outro.", fontSize = 12.sp, color = Dim, lineHeight = 17.sp)
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Fechar", color = Ivory) } },
    )
}

@Composable
private fun JvmArgsDialog(vm: LauncherViewModel, onDismiss: () -> Unit) {
    var text by remember { mutableStateOf(vm.jvmArgs) }
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = SheetBg,
        title = { Text("Argumentos Java", color = Ivory, fontWeight = FontWeight.SemiBold) },
        text = {
            Column {
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    placeholder = { Text("-XX:+UseG1GC", color = Dim) },
                    textStyle = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
                    shape = RoundedCornerShape(14.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Gold.copy(alpha = .6f), unfocusedBorderColor = Hair,
                        cursorColor = Gold, focusedTextColor = Ivory, unfocusedTextColor = Ivory,
                    ),
                    modifier = Modifier.fillMaxWidth().height(120.dp),
                )
                Spacer(Modifier.height(10.dp))
                Text(
                    "Só para utilizadores avançados: um argumento errado impede o jogo de abrir. " +
                        "A memória ajusta-se em Memória (-Xmx e -Xms são ignorados). Deixe vazio para usar os predefinidos.",
                    fontSize = 12.sp, color = Muted, lineHeight = 17.sp,
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { vm.saveJvmArgs(text); onDismiss() }) { Text("Guardar", color = Gold, fontWeight = FontWeight.Bold) }
        },
        dismissButton = {
            Row {
                if (vm.jvmArgs.isNotBlank()) TextButton(onClick = { vm.saveJvmArgs(""); onDismiss() }) { Text("Repor", color = Danger) }
                TextButton(onClick = onDismiss) { Text("Cancelar", color = Ivory) }
            }
        },
    )
}

@Composable
private fun SettingRow(
    label: String,
    value: String,
    chevron: Boolean = false,
    divider: Boolean = true,
    enabled: Boolean = true,
    onClick: (() -> Unit)? = null,
) {
    Column {
        Row(
            Modifier.fillMaxWidth()
                .then(if (onClick != null) Modifier.clickable(enabled = enabled, onClick = onClick) else Modifier)
                .padding(vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(label, fontSize = 15.sp, color = Ivory, modifier = Modifier.weight(1f))
            Text(value, fontSize = 14.sp, color = Muted)
            if (chevron) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Muted, modifier = Modifier.size(18.dp))
        }
        if (divider) Box(Modifier.fillMaxWidth().height(1.dp).background(Hair))
    }
}

@Composable
private fun LogConsole(vm: LauncherViewModel, modifier: Modifier) {
    val state = rememberLazyListState()
    LaunchedEffect(vm.logs.size) {
        if (vm.logs.isNotEmpty()) state.scrollToItem(vm.logs.lastIndex)
    }
    LazyColumn(
        state = state,
        modifier = modifier.background(Color(0xFF09080C), RoundedCornerShape(14.dp)).border(1.dp, Hair, RoundedCornerShape(14.dp)).padding(10.dp),
    ) {
        items(vm.logs) { line ->
            Text(line, fontFamily = FontFamily.Monospace, fontSize = 11.sp, color = Color(0xFFBDB6A0))
        }
    }
}
