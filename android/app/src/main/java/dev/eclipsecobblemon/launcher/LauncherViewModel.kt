package dev.eclipsecobblemon.launcher

import android.app.Activity
import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import dev.eclipsecobblemon.launcher.auth.Account
import dev.eclipsecobblemon.launcher.auth.AccountStore
import dev.eclipsecobblemon.launcher.auth.MicrosoftAuth
import dev.eclipsecobblemon.launcher.auth.OfflineAuth
import dev.eclipsecobblemon.launcher.auth.SkinApi
import dev.eclipsecobblemon.launcher.auth.SkinProfile
import dev.eclipsecobblemon.launcher.auth.SkinVariant
import dev.eclipsecobblemon.launcher.net.Http
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import dev.eclipsecobblemon.launcher.game.VersionEntry
import dev.eclipsecobblemon.launcher.game.VersionManager
import dev.eclipsecobblemon.launcher.launch.AmethystBridge
import dev.eclipsecobblemon.launcher.nativecore.NativeCore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LauncherViewModel(app: Application) : AndroidViewModel(app) {
    private val store = AccountStore(app)
    /** Prepara Amethyst (rutas, LWJGL, controles…) antes de nada: comparte el .minecraft con él. */
    private val amethystReady = AmethystBridge.init(app)
    private val versionManager = VersionManager(AmethystBridge.gameDir(app))

    var account by mutableStateOf(store.load())
        private set
    var loggingIn by mutableStateOf(false)
        private set
    var versions by mutableStateOf<List<VersionEntry>>(emptyList())
        private set
    /** Versión fija del servidor por ahora. */
    val selectedVersion = DEFAULT_VERSION
    var ramMb by mutableStateOf(0)
    var busy by mutableStateOf(false)
        private set
    var progress by mutableStateOf<Float?>(null)
        private set
    val logs = mutableStateListOf<String>()

    /** Etapa visible en la interfaz mientras se prepara y lanza el juego. */
    enum class Stage { IDLE, VERSION, FILES, JAVA, LAUNCHING }
    var stage by mutableStateOf(Stage.IDLE)
        private set
    var filesDone by mutableStateOf(0)
        private set
    var filesTotal by mutableStateOf(0)
        private set
    var javaProgress by mutableStateOf<Float?>(null)
        private set
    private var launchedAt = 0L

    /** RAM sugerida: ~40 % de la memoria total del equipo, en pasos de 256 MB (1–4 GB). */
    val recommendedRamMb: Int = run {
        val am = app.getSystemService(android.content.Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val info = android.app.ActivityManager.MemoryInfo().also(am::getMemoryInfo)
        ((info.totalMem / (1024 * 1024) * 0.4).toInt() / 256 * 256).coerceIn(1024, 4096)
    }

    private val timeFmt = SimpleDateFormat("HH:mm:ss", Locale.US)


    fun log(msg: String) {
        val line = "[${timeFmt.format(Date())}] $msg"
        viewModelScope.launch(Dispatchers.Main) {
            logs += line
            if (logs.size > 300) logs.removeRange(0, logs.size - 300)
        }
    }

    fun loadVersions() = viewModelScope.launch {
        runCatching { versionManager.fetchVersions() }
            .onSuccess {
                versions = it
                log("${it.size} versões disponíveis")
            }
            .onFailure { log("Não foi possível carregar a lista de versões: ${it.message}") }
    }

    fun loginOffline(name: String) {
        runCatching { OfflineAuth.login(name.trim()) }
            .onSuccess { saveAccount(it); log("Sessão sem ligação: ${it.username} (${it.uuid})") }
            .onFailure { log("Erro: ${it.message}") }
    }

    /** Llamado con el resultado del WebView de MicrosoftLoginActivity. */
    fun onMicrosoftCode(code: String?, error: String?) {
        if (code == null) return log("Login Microsoft: ${error ?: "cancelado"}")
        loggingIn = true
        viewModelScope.launch {
            try {
                val acc = MicrosoftAuth.loginWithCode(code, ::log)
                saveAccount(acc)
                log("Sessão premium: ${acc.username}")
            } catch (e: Exception) {
                log("Erro: ${e.message}")
            } finally {
                loggingIn = false
            }
        }
    }

    fun logout() {
        store.clear()
        account = null
        loadSkin()
        log("Sessão encerrada")
    }

    private fun saveAccount(acc: Account) {
        val changed = account?.uuid != acc.uuid
        store.save(acc)
        account = acc
        if (changed) loadSkin()
    }

    // ---------- Skin ----------

    /** Perfil de skin/capas (solo Microsoft). */
    var skinProfile by mutableStateOf<SkinProfile?>(null)
        private set
    /** Textura 64×64 (o 64×32) de la skin actual. */
    var skinTexture by mutableStateOf<Bitmap?>(null)
        private set
    var capeTextures by mutableStateOf<Map<String, Bitmap>>(emptyMap())
        private set
    /** Skin elegida en la galería, aún sin aplicar. */
    var pendingSkin by mutableStateOf<Bitmap?>(null)
        private set
    private var pendingPng: ByteArray? = null
    var skinBusy by mutableStateOf(false)
        private set
    var skinMessage by mutableStateOf<String?>(null)
        private set

    fun loadSkin() {
        val acc = account
        skinProfile = null
        skinTexture = null
        capeTextures = emptyMap()
        clearPendingSkin()
        if (acc == null) return
        skinTask(quiet = true) {
            if (acc.isPremium) {
                val p = SkinApi.profile(freshToken())
                applyProfile(p)
            } else {
                // Offline: la skin que tendría ese nombre en Mojang (o Steve), solo como vista previa
                skinTexture = download("https://mc-heads.net/skin/${acc.username}")
            }
        }
    }

    fun pickSkin(uri: Uri) {
        val bytes = runCatching { getApplication<Application>().contentResolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull()
        val bmp = bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
        skinMessage = when {
            bmp == null -> "Não foi possível ler a imagem"
            bmp.width != 64 || (bmp.height != 64 && bmp.height != 32) -> "A skin tem de ser um PNG de 64×64 (esta tem ${bmp.width}×${bmp.height})"
            else -> null
        }
        if (skinMessage != null || bmp == null) return
        pendingPng = if (bytes.isPng()) bytes else java.io.ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
        pendingSkin = bmp
    }

    fun clearPendingSkin() {
        pendingSkin = null
        pendingPng = null
    }

    /** Sube la skin pendiente, o cambia solo el modelo si no hay ninguna pendiente. */
    fun applySkin(variant: SkinVariant) = skinTask {
        val png = pendingPng
        val p = if (png != null) SkinApi.upload(freshToken(), png, variant)
        else SkinApi.changeVariant(freshToken(), skinProfile?.skinUrl ?: return@skinTask, variant)
        clearPendingSkin()
        applyProfile(p)
        skinMessage = "Skin atualizada"
        log("Skin atualizada (${variant.name.lowercase()})")
    }

    fun resetSkin() = skinTask {
        applyProfile(SkinApi.reset(freshToken()))
        clearPendingSkin()
        skinMessage = "Skin reposta"
        log("Skin reposta para a predefinida")
    }

    fun setCape(id: String?) = skinTask {
        applyProfile(SkinApi.setCape(freshToken(), id))
        log(if (id == null) "Capa removida" else "Capa alterada")
    }

    private suspend fun applyProfile(p: SkinProfile) {
        val acc = account
        skinTexture = p.skinUrl?.let { download(it) }
            ?: acc?.let { download("https://mc-heads.net/skin/${it.uuid.replace("-", "")}") }
        capeTextures = p.capes.mapNotNull { c -> runCatching { c.id to download(c.url) }.getOrNull() }.toMap()
        skinProfile = p
    }

    private suspend fun download(url: String): Bitmap = withContext(Dispatchers.IO) {
        val b = Http.getBytes(url)
        BitmapFactory.decodeByteArray(b, 0, b.size) ?: throw IllegalStateException("Imagem inválida")
    }

    /** Token de Minecraft válido, renovando la sesión si hace falta. */
    private suspend fun freshToken(): String {
        var acc = account ?: throw IllegalStateException("Sem sessão")
        if (acc.needsRefresh) {
            acc = MicrosoftAuth.refresh(acc, ::log)
            store.save(acc)
            account = acc
        }
        return acc.accessToken
    }

    private fun skinTask(quiet: Boolean = false, block: suspend () -> Unit) {
        if (skinBusy) return
        skinBusy = true
        if (!quiet) skinMessage = null
        viewModelScope.launch {
            try {
                block()
            } catch (e: Exception) {
                skinMessage = e.message
                log("Skin: ${e.message}")
            } finally {
                skinBusy = false
            }
        }
    }

    private fun ByteArray.isPng() = size > 8 && this[0] == 0x89.toByte() && this[1] == 'P'.code.toByte()

    fun install() = runTask { installSelected() }

    /** Tamaño del .minecraft (versiones, librerías, assets, mundos…); null mientras se calcula. */
    var gameDataBytes by mutableStateOf<Long?>(null)
        private set

    fun measureGameData() = viewModelScope.launch {
        gameDataBytes = null
        gameDataBytes = withContext(Dispatchers.IO) {
            versionManager.gameDir.walkBottomUp().filter { it.isFile }.sumOf { it.length() }
        }
    }

    /** Borra todo el .minecraft. La cuenta y el Java de Amethyst se conservan. */
    fun wipeGameData() = runTask {
        log("A apagar os dados do Minecraft…")
        withContext(Dispatchers.IO) {
            versionManager.gameDir.listFiles()?.forEach { it.deleteRecursively() }
            versionManager.gameDir.mkdirs()
        }
        gameDataBytes = 0
        log("Dados do Minecraft apagados")
    }

    /** Necesita la Activity: Amethyst la usa para instalar el JRE y para abrir el juego. */
    fun play(activity: Activity) = runTask {
        if (!amethystReady) throw IllegalStateException("Armazenamento indisponível para o Amethyst")
        var acc = account ?: return@runTask log("Inicie sessão primeiro")
        if (acc.needsRefresh) {
            log("A renovar a sessão da Microsoft…")
            acc = MicrosoftAuth.refresh(acc, ::log)
            saveAccount(acc)
        }
        if (!versionManager.isInstalled(selectedVersion)) installSelected()

        stage = Stage.JAVA
        withContext(Dispatchers.IO) {
            AmethystBridge.prepare(activity, acc, selectedVersion, ramMb, ::log) { pct ->
                viewModelScope.launch(Dispatchers.Main) { javaProgress = pct / 100f }
            }
        }
        log("A iniciar o Minecraft $selectedVersion…")
        stage = Stage.LAUNCHING
        launchedAt = System.currentTimeMillis()
        AmethystBridge.launch(activity, selectedVersion)
    }

    /** Al volver del juego (o si no llegó a abrirse) la pantalla de lanzamiento se cierra. */
    fun onLauncherResumed() {
        if (stage == Stage.LAUNCHING && System.currentTimeMillis() - launchedAt > 1500) stage = Stage.IDLE
    }

    private suspend fun installSelected() {
        val entry = versions.firstOrNull { it.id == selectedVersion }
            ?: throw IllegalStateException("Versão $selectedVersion não encontrada (sem ligação?)")
        log("A instalar ${entry.id}…")
        stage = Stage.VERSION
        versionManager.install(entry, ::log) { done, total ->
            viewModelScope.launch(Dispatchers.Main) {
                stage = Stage.FILES
                filesDone = done
                filesTotal = total
                progress = if (total == 0) null else done.toFloat() / total
            }
        }
    }

    private fun runTask(block: suspend () -> Unit) {
        if (busy) return
        busy = true
        viewModelScope.launch {
            try {
                block()
            } catch (e: Exception) {
                log("Erro: ${e.message}")
                stage = Stage.IDLE
            } finally {
                busy = false
                progress = null
                javaProgress = null
                if (stage != Stage.LAUNCHING) stage = Stage.IDLE
            }
        }
    }

    // Al final: el init usa propiedades declaradas más arriba.
    init {
        ramMb = recommendedRamMb
        log("EclipseCobblemon ${BuildConfig.VERSION_NAME}")
        log("Camada Rust: " + if (NativeCore.available) "libeclipse_core.so carregada" else "não compilada (a usar Kotlin)")
        log("Runtime Amethyst: " + if (amethystReady) "pronto" else "sem armazenamento")
        log("Diretório: ${versionManager.gameDir}")
        loadVersions()
        loadSkin()
    }

    companion object {
        /** Cobblemon apunta a 1.21.1. */
        const val DEFAULT_VERSION = "1.21.1"
    }
}
