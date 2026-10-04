package dev.eclipsecobblemon.launcher.game

import dev.eclipsecobblemon.launcher.BuildConfig
import dev.eclipsecobblemon.launcher.auth.Account
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** Todo lo necesario para arrancar Minecraft Java en una JVM: lo consume la capa Amethyst/Pojav. */
data class LaunchSpec(
    val versionId: String,
    val javaMajor: Int,
    val mainClass: String,
    val classpath: List<String>,
    val jvmArgs: List<String>,
    val gameArgs: List<String>,
    val gameDir: String,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("versionId", versionId)
        .put("javaMajor", javaMajor)
        .put("mainClass", mainClass)
        .put("classpath", JSONArray(classpath))
        .put("jvmArgs", JSONArray(jvmArgs))
        .put("gameArgs", JSONArray(gameArgs))
        .put("gameDir", gameDir)

    /** Versión legible para el log (con el token oculto). */
    fun preview(): String =
        (listOf("java") + jvmArgs + listOf("-cp", "<${classpath.size} jars>", mainClass) + gameArgs)
            .joinToString(" ")
            .replace(Regex("--accessToken \\S+"), "--accessToken ***")

    companion object {
        fun build(vm: VersionManager, versionId: String, account: Account, ramMb: Int): LaunchSpec {
            val json = vm.readVersionJson(versionId)

            // LWJGL lo sustituye el runtime de Amethyst por su build para Android.
            val classpath = json.getJSONArray("libraries").objects()
                .filter { Rules.allowed(it.optJSONArray("rules")) }
                .map { it.getString("name") }
                .filterNot { it.contains(":natives-") || it.startsWith("org.lwjgl") }
                .map { File(vm.librariesDir, mavenPath(it)).absolutePath }
                .distinct() + vm.clientJarFile(versionId).absolutePath

            val vars = mapOf(
                "auth_player_name" to account.username,
                "version_name" to versionId,
                "game_directory" to vm.gameDir.absolutePath,
                "assets_root" to vm.assetsDir.absolutePath,
                "game_assets" to vm.assetsDir.absolutePath,
                "assets_index_name" to json.getJSONObject("assetIndex").getString("id"),
                "auth_uuid" to account.uuid.replace("-", ""),
                "auth_access_token" to account.accessToken,
                "auth_session" to account.accessToken,
                "auth_xuid" to account.xuid,
                "clientid" to "",
                "user_type" to account.userType,
                "user_properties" to "{}",
                "version_type" to json.optString("type", "release"),
            )

            val rawGameArgs = json.optJSONObject("arguments")?.optJSONArray("game")?.let { arr ->
                (0 until arr.length()).mapNotNull { arr.opt(it) as? String }
            } ?: json.optString("minecraftArguments").split(" ").filter { it.isNotBlank() }

            val jvmArgs = listOf(
                "-Xms${minOf(512, ramMb)}M",
                "-Xmx${ramMb}M",
                "-Dminecraft.launcher.brand=EclipseCobblemon",
                "-Dminecraft.launcher.version=${BuildConfig.VERSION_NAME}",
            )

            return LaunchSpec(
                versionId = versionId,
                javaMajor = json.optJSONObject("javaVersion")?.optInt("majorVersion", 8) ?: 8,
                mainClass = json.getString("mainClass"),
                classpath = classpath,
                jvmArgs = jvmArgs,
                gameArgs = substitute(rawGameArgs, vars),
                gameDir = vm.gameDir.absolutePath,
            )
        }

        /** Reemplaza las variables de Mojang y descarta flags cuyo valor quedó sin resolver. */
        fun substitute(args: List<String>, vars: Map<String, String>): List<String> {
            val placeholder = Regex("\\$\\{([a-zA-Z_]+)\\}")
            val out = mutableListOf<String>()
            for (arg in args) {
                val resolved = placeholder.replace(arg) { m -> vars[m.groupValues[1]] ?: m.value }
                if (resolved.contains("\${")) {
                    if (out.lastOrNull()?.startsWith("--") == true) out.removeAt(out.lastIndex)
                    continue
                }
                out += resolved
            }
            return out
        }
    }
}
