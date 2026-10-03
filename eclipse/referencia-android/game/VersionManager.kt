package dev.eclipsecobblemon.launcher.game

import dev.eclipsecobblemon.launcher.nativecore.NativeCore
import dev.eclipsecobblemon.launcher.net.Http
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

data class VersionEntry(val id: String, val type: String, val url: String)

/** Un archivo que hay que tener en disco (con hash opcional para verificar). */
private data class FileTask(val url: String, val file: File, val sha1: String?)

/** Descarga e instala versiones vanilla de Minecraft Java en el .minecraft del launcher. */
class VersionManager(val gameDir: File) {
    val versionsDir = File(gameDir, "versions")
    val librariesDir = File(gameDir, "libraries")
    val assetsDir = File(gameDir, "assets")

    private companion object {
        const val MANIFEST = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
        const val RESOURCES = "https://resources.download.minecraft.net"
        const val LIBRARIES = "https://libraries.minecraft.net/"
        const val PARALLEL = 16
    }

    suspend fun fetchVersions(includeSnapshots: Boolean = false): List<VersionEntry> = withContext(Dispatchers.IO) {
        val arr = Http.get(MANIFEST).json().getJSONArray("versions")
        (0 until arr.length()).map { arr.getJSONObject(it) }
            .filter { includeSnapshots || it.getString("type") == "release" }
            .map { VersionEntry(it.getString("id"), it.getString("type"), it.getString("url")) }
    }

    fun versionJsonFile(id: String) = File(versionsDir, "$id/$id.json")
    fun clientJarFile(id: String) = File(versionsDir, "$id/$id.jar")
    fun isInstalled(id: String) = versionJsonFile(id).isFile && clientJarFile(id).isFile

    fun readVersionJson(id: String) = JSONObject(versionJsonFile(id).readText())

    /**
     * Instala (o verifica) una versión: JSON, client.jar, librerías y assets.
     * Los archivos que ya existen con el hash correcto no se vuelven a descargar.
     */
    suspend fun install(
        version: VersionEntry,
        log: (String) -> Unit,
        progress: (done: Int, total: Int) -> Unit,
    ) = withContext(Dispatchers.IO) {
        log("A transferir ${version.id}.json")
        val jsonFile = versionJsonFile(version.id)
        Http.download(version.url, jsonFile)
        val json = JSONObject(jsonFile.readText())

        val tasks = mutableListOf<FileTask>()

        json.getJSONObject("downloads").getJSONObject("client").let {
            tasks += FileTask(it.getString("url"), clientJarFile(version.id), it.optString("sha1", null))
        }

        json.optJSONObject("logging")?.optJSONObject("client")?.optJSONObject("file")?.let {
            tasks += FileTask(it.getString("url"), File(gameDir, it.getString("id")), it.optString("sha1", null))
        }

        val libs = libraryTasks(json)
        tasks += libs
        log("Bibliotecas: ${libs.size}")

        val assetIndex = json.getJSONObject("assetIndex")
        val indexFile = File(assetsDir, "indexes/${assetIndex.getString("id")}.json")
        if (NativeCore.sha1(indexFile) != assetIndex.getString("sha1")) {
            Http.download(assetIndex.getString("url"), indexFile)
        }
        val objects = JSONObject(indexFile.readText()).getJSONObject("objects")
        val assets = objects.keys().asSequence().map { key ->
            val hash = objects.getJSONObject(key).getString("hash")
            val sub = hash.substring(0, 2)
            FileTask("$RESOURCES/$sub/$hash", File(assetsDir, "objects/$sub/$hash"), hash)
        }.distinctBy { it.file }.toList()
        tasks += assets
        log("Assets: ${assets.size}")

        downloadAll(tasks, log, progress)
        log("${version.id} instalada ✔")
    }

    private suspend fun downloadAll(
        tasks: List<FileTask>,
        log: (String) -> Unit,
        progress: (Int, Int) -> Unit,
    ) = coroutineScope {
        val done = AtomicInteger(0)
        val downloaded = AtomicInteger(0)
        val gate = Semaphore(PARALLEL)
        progress(0, tasks.size)
        tasks.map { t ->
            async(Dispatchers.IO) {
                gate.withPermit {
                    val valid = t.file.isFile && (t.sha1 == null || NativeCore.sha1(t.file) == t.sha1)
                    if (!valid) {
                        retry(3) { Http.download(t.url, t.file) }
                        if (t.sha1 != null && NativeCore.sha1(t.file) != t.sha1) {
                            throw IllegalStateException("Hash incorreto: ${t.file.name}")
                        }
                        downloaded.incrementAndGet()
                    }
                    progress(done.incrementAndGet(), tasks.size)
                }
            }
        }.awaitAll()
        log("Transferidos ${downloaded.get()} ficheiros, ${tasks.size - downloaded.get()} já estavam OK")
    }

    private inline fun retry(times: Int, block: () -> Unit) {
        var last: Throwable? = null
        repeat(times) {
            try {
                return block()
            } catch (e: Throwable) {
                last = e
            }
        }
        throw last!!
    }

    /** Librerías aplicables (Android cuenta como "linux"). Los natives los aporta el runtime Amethyst. */
    private fun libraryTasks(json: JSONObject): List<FileTask> {
        val out = mutableListOf<FileTask>()
        for (lib in json.getJSONArray("libraries").objects()) {
            if (!Rules.allowed(lib.optJSONArray("rules"))) continue
            val name = lib.getString("name")
            if (name.contains(":natives-")) continue
            val artifact = lib.optJSONObject("downloads")?.optJSONObject("artifact")
            if (artifact != null) {
                out += FileTask(
                    artifact.getString("url"),
                    File(librariesDir, artifact.getString("path")),
                    artifact.optString("sha1", null),
                )
            } else if (!lib.has("downloads")) {
                // Formato antiguo / Fabric: solo "name" (+ "url" base opcional)
                val path = mavenPath(name)
                out += FileTask(lib.optString("url", LIBRARIES).trimEnd('/') + "/" + path, File(librariesDir, path), null)
            }
        }
        return out
    }
}

/** Evaluación de "rules" de Mojang con el sistema operativo fijado a linux. */
object Rules {
    fun allowed(rules: JSONArray?): Boolean {
        if (rules == null || rules.length() == 0) return true
        var allow = false
        for (rule in rules.objects()) {
            if (rule.has("features")) continue
            val os = rule.optJSONObject("os")
            val matches = os == null || os.optString("name", "linux") == "linux"
            if (matches) allow = rule.getString("action") == "allow"
        }
        return allow
    }
}

/** "group:artifact:version[:classifier]" -> "group/path/artifact/version/artifact-version[-classifier].jar" */
fun mavenPath(name: String): String {
    val p = name.split(":")
    val (group, artifact, version) = Triple(p[0].replace('.', '/'), p[1], p[2])
    val classifier = p.getOrNull(3)?.let { "-$it" } ?: ""
    return "$group/$artifact/$version/$artifact-$version$classifier.jar"
}

fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }
