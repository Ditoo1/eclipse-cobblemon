package dev.eclipsecobblemon.launcher.game

import dev.eclipsecobblemon.launcher.net.Http
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File

/**
 * Fabric Loader desde los metadatos oficiales (meta.fabricmc.net): el perfil JSON va a
 * versions/<id>/<id>.json con `inheritsFrom` = la vanilla, como lo deja el instalador de Fabric.
 * Amethyst ya sabe lanzar versiones con `inheritsFrom`.
 */
object Fabric {
    private const val META = "https://meta.fabricmc.net/v2"

    fun versionId(minecraft: String, loader: String) = "fabric-loader-$loader-$minecraft"

    /** Descarga el perfil si falta; devuelve su id. Las librerías las baja después [VersionManager]. */
    suspend fun installProfile(vm: VersionManager, minecraft: String, loader: String, log: (String) -> Unit): String =
        withContext(Dispatchers.IO) {
            val id = versionId(minecraft, loader)
            val file = vm.versionJsonFile(id)
            if (!file.isFile) {
                log("A transferir o Fabric Loader $loader…")
                Http.download("$META/versions/loader/$minecraft/$loader/profile/json", file)
            }
            val json = JSONObject(file.readText())
            check(json.optString("inheritsFrom") == minecraft) { "Perfil do Fabric inválido para $minecraft" }
            copyClientJar(vm, minecraft, id)
            id
        }

    /**
     * Amethyst pone en el classpath versions/<id>/<id>.jar de la versión lanzada, también con
     * `inheritsFrom` (su MinecraftDownloader copia ahí el jar vanilla). Hacemos lo mismo.
     */
    internal fun copyClientJar(vm: VersionManager, minecraft: String, id: String) {
        val source = vm.clientJarFile(minecraft)
        val target = vm.clientJarFile(id)
        check(source.isFile) { "Falta o Minecraft $minecraft" }
        if (target.isFile && target.length() == source.length()) return
        val tmp = File(target.parentFile, "${target.name}.tmp")
        source.copyTo(tmp, overwrite = true)
        if (!tmp.renameTo(target)) {
            target.delete()
            check(tmp.renameTo(target)) { "Não foi possível preparar $id" }
        }
    }
}
