package dev.eclipsecobblemon.launcher.launch

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.kdt.mcgui.ProgressLayout
import dev.eclipsecobblemon.launcher.auth.Account
import net.kdt.pojavlaunch.MainActivity
import net.kdt.pojavlaunch.NewJREUtil
import net.kdt.pojavlaunch.PojavProfile
import net.kdt.pojavlaunch.Tools
import net.kdt.pojavlaunch.prefs.LauncherPreferences
import net.kdt.pojavlaunch.progresskeeper.ProgressKeeper
import net.kdt.pojavlaunch.progresskeeper.ProgressListener
import net.kdt.pojavlaunch.tasks.AsyncAssetManager
import net.kdt.pojavlaunch.value.MinecraftAccount
import net.kdt.pojavlaunch.value.launcherprofiles.LauncherProfiles
import net.kdt.pojavlaunch.value.launcherprofiles.MinecraftProfile
import java.io.File
import java.util.UUID

/**
 * Último eslabón: Android -> Kotlin/Rust -> **Amethyst/Pojav** -> Minecraft Java.
 *
 * El módulo :amethyst (código vendorizado de Amethyst-Android) aporta el JRE para Android,
 * LWJGL, los renderers GL (MobileGlues / gl4es / Zink) y la Activity del juego con controles
 * táctiles. Este puente hace lo mismo que el launcher original de Amethyst antes de jugar:
 * registra la cuenta y el perfil en sus formatos, garantiza el JRE y abre su MainActivity,
 * que corre en el proceso ":game".
 */
object AmethystBridge {
    private const val PROFILE_NAME = "EclipseCobblemon"

    /**
     * Amethyst re-indexa con un UUID aleatorio cualquier perfil cuya clave no sea un UUID
     * (LauncherProfiles.normalizeProfileIds), así que la clave tiene que ser un UUID fijo.
     */
    private val PROFILE_KEY: String = UUID.nameUUIDFromBytes(PROFILE_NAME.toByteArray()).toString()

    /** Layout táctil propio (assets/controls, desde ASSETS/Controles_Eclipse.json). Amethyst migra v7 -> v8. */
    private const val CONTROLS_ASSET = "controls/eclipse_controls.json"
    private const val CONTROLS_FILE = "EclipseCobblemon.json"

    /**
     * Equivalente a TestStorageActivity.exit() de Amethyst: inicializa rutas/preferencias y
     * extrae en segundo plano LWJGL, caciocavallo, los parches log4j y los controles por defecto.
     */
    fun init(context: Context): Boolean {
        if (!Tools.checkStorageRoot(context)) return false
        LauncherPreferences.loadPreferences(context)
        AsyncAssetManager.unpackComponents(context)
        AsyncAssetManager.unpackSingleFiles(context)
        return true
    }

    /** El .minecraft que usa Amethyst; nuestras descargas van al mismo sitio. */
    fun gameDir(context: Context): File =
        Tools.DIR_GAME_NEW?.let(::File) ?: File(context.getExternalFilesDir(null), ".minecraft")

    /**
     * Registra cuenta y perfil para Amethyst y garantiza el JRE que pide la versión
     * (lo descarga de los builds de AngelAuraMC si no está). Bloqueante: llamar fuera del hilo UI.
     */
    fun prepare(
        activity: Activity,
        account: Account,
        versionId: String,
        ramMb: Int,
        renderer: Renderer,
        jvmArgs: String,
        log: (String) -> Unit,
        javaProgress: (Int) -> Unit = {},
    ) {
        // 1. Cuenta, en el formato de Amethyst (accounts/<nombre>.json + preferencia activa)
        val mc = MinecraftAccount().apply {
            username = account.username
            profileId = account.uuid.replace("-", "")
            accessToken = if (account.isPremium) account.accessToken else "0"
            isMicrosoft = account.isPremium
            msaRefreshToken = account.refreshToken ?: "0"
            xuid = account.xuid
            expiresAt = account.expiresAt
            selectedVersion = versionId
        }
        mc.save()
        PojavProfile.setCurrentProfile(activity, mc.username)
        Tools.switchDemo(false)

        // 2. Perfil de lanzamiento (launcher_profiles.json) + RAM, renderer y argumentos Java
        LauncherProfiles.load()
        val profiles = LauncherProfiles.mainProfileJson.profiles
        // Limpia copias re-indexadas de versiones anteriores del launcher
        profiles.entries.removeAll { it.key != PROFILE_KEY && it.value.name == PROFILE_NAME }
        val profile = profiles[PROFILE_KEY] ?: MinecraftProfile.createTemplate()
        profile.name = PROFILE_NAME
        profile.lastVersionId = versionId
        profile.controlFile = installControls(activity)
        profile.pojavRendererName = renderer.amethystName
        profile.useANGLE = renderer.angle
        // Amethyst ignora -Xms/-Xmx: la memoria sale del control de Memória
        profile.javaArgs = jvmArgs.ifBlank { null }
        profiles[PROFILE_KEY] = profile
        LauncherProfiles.write()
        LauncherPreferences.DEFAULT_PREF.edit()
            .putString(LauncherPreferences.PREF_KEY_CURRENT_PROFILE, PROFILE_KEY)
            .putInt("allocation", ramMb)
            .commit()
        LauncherPreferences.loadPreferences(activity)
        log("Perfil Amethyst pronto (${mc.username}, ${ramMb} MB, ${renderer.label})")
        if (jvmArgs.isNotBlank()) log("Argumentos Java: $jvmArgs")

        // 3. JRE (Java 8/17/21/25 según la versión)
        val info = Tools.getVersionInfo(versionId)
        val javaMajor = info.javaVersion?.majorVersion ?: 8
        log("A verificar o Java $javaMajor…")
        val listener = JreProgressLogger(javaMajor, log, javaProgress)
        ProgressKeeper.addListener(ProgressLayout.UNPACK_RUNTIME, listener)
        try {
            if (!NewJREUtil.installNewJreIfNeeded(activity, info)) {
                throw IllegalStateException("Não foi possível instalar o Java $javaMajor")
            }
        } finally {
            ProgressKeeper.removeListener(ProgressLayout.UNPACK_RUNTIME, listener)
        }
        log("Java $javaMajor pronto")
    }

    /**
     * Copia el layout a controlmap/ de Amethyst. Solo se sobrescribe si cambia el del APK,
     * para respetar lo que el jugador edite con el editor de controles de Amethyst.
     */
    private fun installControls(context: Context): String {
        val bundled = context.assets.open(CONTROLS_ASSET).use { it.readBytes() }
        val hash = bundled.contentHashCode()
        val prefs = context.getSharedPreferences("amethyst_bridge", Context.MODE_PRIVATE)
        val dest = File(Tools.CTRLMAP_PATH, CONTROLS_FILE)
        if (!dest.isFile || prefs.getInt("controls_hash", 0) != hash) {
            dest.parentFile?.mkdirs()
            dest.writeBytes(bundled)
            prefs.edit().putInt("controls_hash", hash).apply()
        }
        return CONTROLS_FILE
    }

    /** Abre la Activity del juego de Amethyst (proceso :game). */
    fun launch(activity: Activity, versionId: String) {
        activity.startActivity(
            Intent(activity, MainActivity::class.java)
                .putExtra(MainActivity.INTENT_MINECRAFT_VERSION, versionId)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        )
    }

    /** Pasa el progreso de descarga/extracción del JRE a la consola, cada 10 %. */
    private class JreProgressLogger(
        val javaMajor: Int,
        val log: (String) -> Unit,
        val onProgress: (Int) -> Unit,
    ) : ProgressListener {
        private var lastStep = -1
        private var started = false
        override fun onProgressStarted() {
            started = true
            log("A transferir o Java $javaMajor…")
        }
        override fun onProgressUpdated(progress: Int, resid: Int, vararg va: Any?) {
            started = true
            onProgress(progress)
            val step = progress / 10
            if (step != lastStep) {
                lastStep = step
                log("Java $javaMajor: $progress %")
            }
        }
        // ProgressKeeper avisa "terminado" al registrar el listener si no hay tarea en curso
        override fun onProgressEnded() {
            if (started) log("Java $javaMajor transferido, a instalar…")
        }
    }
}
