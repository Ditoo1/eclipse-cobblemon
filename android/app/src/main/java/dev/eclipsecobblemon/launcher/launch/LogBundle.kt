package dev.eclipsecobblemon.launcher.launch

import android.content.Context
import android.os.Build
import net.kdt.pojavlaunch.Tools
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * Junta los registos para que el jugador los mande a quien le ayude: el del launcher, la salida de Java
 * (latestlog.txt de Amethyst), logs/latest.log de Minecraft y los últimos crash reports.
 */
object LogBundle {
    private const val CRASH_REPORTS = 3

    /** Crea el .zip dentro de la carpeta de Amethyst (la que comparte su FolderProvider). */
    fun create(context: Context, launcherLog: List<String>, details: List<String>): File {
        Tools.initStorageConstants(context)
        val home = File(Tools.DIR_GAME_HOME)
        val game = AmethystBridge.gameDir(context)
        home.listFiles { f -> f.name.startsWith("EclipseCobblemon-registos") }?.forEach { it.delete() }
        val stamp = SimpleDateFormat("yyyyMMdd-HHmm", Locale.US).format(Date())
        val zip = File(home, "EclipseCobblemon-registos-$stamp.zip")

        val version = runCatching { context.packageManager.getPackageInfo(context.packageName, 0).versionName }.getOrNull()
        val header = listOf(
            "Eclipse Cobblemon ${version ?: "?"} (Android)",
            "Dispositivo: ${Build.MANUFACTURER} ${Build.MODEL}",
            "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}) · ${Build.SUPPORTED_ABIS.firstOrNull()}",
        ) + details

        ZipOutputStream(zip.outputStream().buffered()).use { out ->
            fun add(name: String, file: File) {
                if (!file.isFile) return
                out.putNextEntry(ZipEntry(name))
                file.inputStream().use { it.copyTo(out) }
                out.closeEntry()
            }
            out.putNextEntry(ZipEntry("launcher.txt"))
            out.write((header + "" + launcherLog).joinToString("\n", postfix = "\n").toByteArray())
            out.closeEntry()
            add("latestlog.txt", File(home, "latestlog.txt"))
            add("latestlog.old.txt", File(home, "latestlog.old.txt"))
            add("latest.log", File(game, "logs/latest.log"))
            File(game, "crash-reports").listFiles()
                ?.sortedByDescending { it.lastModified() }
                ?.take(CRASH_REPORTS)
                ?.forEach { add("crash-reports/${it.name}", it) }
        }
        return zip
    }
}
