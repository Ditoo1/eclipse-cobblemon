package dev.eclipsecobblemon.launcher.game

import dev.eclipsecobblemon.launcher.net.Http
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

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
            id
        }
}
