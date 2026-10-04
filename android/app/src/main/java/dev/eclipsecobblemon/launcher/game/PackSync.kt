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
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.concurrent.atomic.AtomicLong

/*
 * Sincronización del pack del servidor (mods, resource packs, configs…) con el .minecraft.
 * Especificación: docs/pack-sync.md. La versión iOS (Natives/eclipse/ECPackSync.m) sigue las mismas reglas.
 */

/** Un archivo del pack. [platforms] null = todas. */
data class PackFile(
    val path: String,
    val sha1: String,
    val size: Long,
    val mode: Mode = Mode.SYNC,
    val platforms: Set<String>? = null,
) {
    enum class Mode(val id: String) {
        /** Siempre igual que en el servidor; se borra cuando sale del manifiesto. */
        SYNC("sync"),
        /** Solo se instala si no existe; después es del jugador y no se sobrescribe. */
        ONCE("once");

        companion object {
            fun of(id: String) = entries.firstOrNull { it.id == id }
                ?: throw IllegalArgumentException("modo desconhecido: $id")
        }
    }
}

data class PackLoader(val type: String, val version: String)

data class PackManifest(
    val revision: Long,
    val minecraft: String,
    val loader: PackLoader?,
    /** Base de los objetos, relativa a la URL del manifiesto (o absoluta). */
    val objects: String,
    /** Carpetas donde todo lo que no esté en el manifiesto se borra (p. ej. "mods"). */
    val exclusive: List<String>,
    val files: List<PackFile>,
) {
    fun filesFor(platform: String) = files.filter { it.platforms == null || platform in it.platforms }

    /** Versión que hay que lanzar: el perfil de Fabric si el pack lo pide, si no la vanilla. */
    val versionId: String
        get() = loader?.let { Fabric.versionId(minecraft, it.version) } ?: minecraft

    companion object {
        const val FORMAT = 1
        private val SHA1 = Regex("^[0-9a-f]{40}$")
        private val LOADER_VERSION = Regex("^[0-9A-Za-z.+_-]{1,64}$")

        fun parse(text: String): PackManifest = try {
            parse(JSONObject(text))
        } catch (e: Exception) {
            throw IllegalArgumentException("Manifesto do pack inválido: ${e.message}", e)
        }

        private fun parse(json: JSONObject): PackManifest {
            val format = json.getInt("format")
            require(format == FORMAT) { "formato $format não suportado (esta app lê o $FORMAT)" }
            val files = json.getJSONArray("files").objects().map { f ->
                val path = f.getString("path")
                require(PackPaths.isSafe(path)) { "caminho não permitido: $path" }
                val sha1 = f.getString("sha1").lowercase()
                require(SHA1.matches(sha1)) { "sha1 inválido em $path" }
                PackFile(
                    path = path,
                    sha1 = sha1,
                    size = f.getLong("size").also { require(it >= 0) { "tamanho inválido em $path" } },
                    mode = PackFile.Mode.of(f.optString("mode", "sync")),
                    platforms = f.optJSONArray("platforms")?.let { a -> (0 until a.length()).map(a::getString).toSet() },
                )
            }
            val seen = HashSet<String>()
            files.forEach { require(seen.add(it.path.lowercase())) { "caminho repetido: ${it.path}" } }
            val exclusive = json.optJSONArray("exclusive")?.let { a -> (0 until a.length()).map(a::getString) } ?: emptyList()
            exclusive.forEach { require(PackPaths.isSafe(it)) { "pasta não permitida: $it" } }
            val loader = json.optJSONObject("loader")?.let {
                val type = it.getString("type")
                require(type == "fabric") { "loader não suportado: $type" }
                val version = it.getString("version")
                require(LOADER_VERSION.matches(version)) { "versão do loader inválida: $version" }
                PackLoader(type, version)
            }
            return PackManifest(
                revision = json.getLong("revision"),
                minecraft = json.getString("minecraft"),
                loader = loader,
                objects = json.optString("objects", "objects/"),
                exclusive = exclusive,
                files = files,
            )
        }
    }
}

/**
 * Qué rutas puede tocar el pack: relativas, sin "..", y fuera de lo que es del jugador
 * (mundos, capturas, options.txt) o del launcher (versiones, librerías, assets, cuentas).
 */
object PackPaths {
    private val PROTECTED = setOf(
        ".eclipse", "saves", "screenshots", "logs", "crash-reports",
        "versions", "libraries", "assets", "accounts", "controlmap",
        "options.txt", "launcher_profiles.json", "launcher_preferences.plist",
    )

    fun isSafe(path: String): Boolean {
        if (path.isEmpty() || path.length > 512 || path.startsWith("/") || '\\' in path || ':' in path) return false
        val parts = path.split('/')
        if (parts.any { it.isEmpty() || it == "." || it == ".." }) return false
        return parts[0].lowercase() !in PROTECTED
    }
}

/** Red del sincronizador; los tests la sustituyen por una falsa. */
interface PackTransport {
    class Fetched(val body: String, val etag: String?)

    /** null si el servidor responde 304 (sigue valiendo el manifiesto en caché). */
    fun fetchManifest(url: String, etag: String?): Fetched?

    /** Descarga a [dest]; [onBytes] recibe cada bloque leído. */
    fun download(url: String, dest: File, onBytes: (Long) -> Unit)
}

object HttpPackTransport : PackTransport {
    private fun open(url: String) = (URL(url).openConnection() as HttpURLConnection).apply {
        connectTimeout = 15_000
        readTimeout = 30_000
        setRequestProperty("User-Agent", Http.USER_AGENT)
    }

    override fun fetchManifest(url: String, etag: String?): PackTransport.Fetched? {
        val c = open(url)
        c.useCaches = false
        etag?.let { c.setRequestProperty("If-None-Match", it) }
        try {
            return when (val code = c.responseCode) {
                304 -> null
                in 200..299 -> PackTransport.Fetched(c.inputStream.bufferedReader().use { it.readText() }, c.getHeaderField("ETag"))
                else -> throw IOException("HTTP $code em $url")
            }
        } finally {
            c.disconnect()
        }
    }

    override fun download(url: String, dest: File, onBytes: (Long) -> Unit) {
        dest.parentFile?.mkdirs()
        val c = open(url)
        try {
            if (c.responseCode !in 200..299) throw IOException("HTTP ${c.responseCode} em $url")
            c.inputStream.use { input ->
                dest.outputStream().use { out ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                        onBytes(n.toLong())
                    }
                }
            }
        } finally {
            c.disconnect()
        }
    }
}

/**
 * Deja el .minecraft igual que el manifiesto publicado en el panel:
 * 1. [fetch]: baja el manifiesto (con ETag). Sin conexión falla: no se juega con un pack sin verificar.
 * 2. [apply]: decide qué falta o cambió. Lo que coincide con el estado guardado (tamaño + fecha)
 *    no se vuelve a leer, salvo con `verify`.
 * 3. Descarga cada objeto una sola vez a `.eclipse/staging/<sha1>` y comprueba tamaño y SHA-1.
 * 4. Solo si todo llegó bien: coloca los archivos, borra lo retirado y guarda el estado.
 *    Si algo falla antes, el .minecraft queda como estaba (y lo descargado se reaprovecha).
 */
class PackSync(
    private val gameDir: File,
    private val manifestUrl: String,
    private val platform: String = PLATFORM,
    private val transport: PackTransport = HttpPackTransport,
    private val sha1: (File) -> String? = NativeCore::sha1,
) {
    private val metaDir = File(gameDir, ".eclipse")
    private val stateFile = File(metaDir, "pack-state.json")
    private val cacheFile = File(metaDir, "pack-manifest.json")
    private val stagingDir = File(metaDir, "staging")

    /** Manifiesto recién validado contra el servidor. */
    class Remote(val manifest: PackManifest, internal val text: String, internal val etag: String?)

    data class Result(val downloaded: Int, val deleted: Int, val upToDate: Int, val bytes: Long)

    private data class Entry(val sha1: String, val size: Long, val mtime: Long, val mode: PackFile.Mode)

    private class State(val revision: Long, val etag: String?, val files: Map<String, Entry>)

    suspend fun fetch(): Remote = withContext(Dispatchers.IO) {
        val state = readState()
        val fetched = try {
            transport.fetchManifest(manifestUrl, state.etag.takeIf { cacheFile.isFile })
        } catch (e: IOException) {
            throw IOException("Sem ligação ao servidor do pack. É preciso internet para jogar.", e)
        }
        if (fetched == null) {
            val text = cacheFile.readText()
            Remote(PackManifest.parse(text), text, state.etag)
        } else {
            Remote(PackManifest.parse(fetched.body), fetched.body, fetched.etag)
        }
    }

    /** [verify] = releer el SHA-1 de todo, sin fiarse del estado guardado. */
    suspend fun apply(
        remote: Remote,
        verify: Boolean,
        log: (String) -> Unit,
        progress: (done: Long, total: Long) -> Unit,
    ): Result = withContext(Dispatchers.IO) {
        val manifest = remote.manifest
        val state = readState()
        if (manifest.revision != state.revision) log("Pack: revisão ${manifest.revision}")

        // 1. Plan
        val wanted = manifest.filesFor(platform)
        val wantedPaths = wanted.mapTo(HashSet()) { it.path }
        val newState = HashMap<String, Entry>()
        val toFetch = mutableListOf<PackFile>()
        var upToDate = 0
        for (f in wanted) {
            val target = File(gameDir, f.path)
            val old = state.files[f.path]
            when {
                !target.isFile -> toFetch += f
                f.mode == PackFile.Mode.ONCE -> {
                    // Ya existe: es del jugador. Solo se recuerda si lo instaló el pack.
                    upToDate++
                    if (old != null) newState[f.path] = old.copy(mode = f.mode)
                }
                !verify && old != null && old.sha1 == f.sha1 &&
                    target.length() == old.size && target.lastModified() == old.mtime -> {
                    upToDate++
                    newState[f.path] = old.copy(mode = f.mode)
                }
                sha1(target) == f.sha1 -> {
                    upToDate++
                    newState[f.path] = entry(target, f)
                }
                else -> toFetch += f
            }
        }

        val toDelete = linkedSetOf<String>()
        for ((path, e) in state.files) {
            if (path in wantedPaths || !PackPaths.isSafe(path)) continue
            val file = File(gameDir, path)
            if (!file.isFile) continue
            // Un "once" que el jugador modificó se queda
            if (e.mode == PackFile.Mode.SYNC || sha1(file) == e.sha1) toDelete += path
        }
        for (dir in manifest.exclusive) {
            File(gameDir, dir).walkTopDown().filter { it.isFile }.forEach {
                val rel = it.relativeTo(gameDir).invariantSeparatorsPath
                if (rel !in wantedPaths) toDelete += rel
            }
        }

        // 2. Descargas: un objeto por hash aunque lo usen varias rutas
        val byHash = toFetch.groupBy { it.sha1 }
        val total = byHash.values.sumOf { it.first().size }
        if (byHash.isNotEmpty()) log("Pack: ${toFetch.size} ficheiros para transferir (${mb(total)})")
        val done = AtomicLong(0)
        progress(0, total)
        stagingDir.mkdirs()
        val gate = Semaphore(PARALLEL)
        coroutineScope {
            byHash.map { (hash, files) ->
                async(Dispatchers.IO) {
                    gate.withPermit { stage(manifest, hash, files.first().size, done, total, progress) }
                }
            }.awaitAll()
        }

        // 3. Aplicar
        for ((hash, files) in byHash) {
            val staged = File(stagingDir, hash)
            files.forEachIndexed { i, f ->
                val target = File(gameDir, f.path)
                if (target.isDirectory) throw IOException("${f.path} existe como pasta")
                target.parentFile?.mkdirs()
                if (i == files.lastIndex) {
                    Files.move(staged.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING)
                } else {
                    staged.copyTo(target, overwrite = true)
                }
                newState[f.path] = entry(target, f)
            }
        }
        for (path in toDelete) {
            if (File(gameDir, path).delete()) log("Removido: $path")
        }
        stagingDir.deleteRecursively()
        writeState(State(manifest.revision, remote.etag, newState))
        writeAtomic(cacheFile, remote.text)

        Result(toFetch.size, toDelete.size, upToDate, total)
    }

    /** Descarga un objeto a staging; si ya estaba de un intento anterior y es válido, se reaprovecha. */
    private fun stage(
        manifest: PackManifest,
        hash: String,
        size: Long,
        done: AtomicLong,
        total: Long,
        progress: (Long, Long) -> Unit,
    ) {
        val staged = File(stagingDir, hash)
        if (staged.isFile && staged.length() == size && sha1(staged) == hash) {
            progress(done.addAndGet(size), total)
            return
        }
        val url = URL(URL(manifestUrl), manifest.objects + hash.substring(0, 2) + "/" + hash).toString()
        var last: Throwable? = null
        repeat(3) {
            var got = 0L
            try {
                transport.download(url, staged) { n ->
                    got += n
                    progress(done.addAndGet(n), total)
                }
                if (staged.length() != size || sha1(staged) != hash) throw IOException("Hash incorreto no objeto $hash")
                return
            } catch (e: Throwable) {
                last = e
                staged.delete()
                done.addAndGet(-got)
            }
        }
        throw last!!
    }

    private fun entry(file: File, f: PackFile) = Entry(f.sha1, file.length(), file.lastModified(), f.mode)

    private fun readState(): State = try {
        val json = JSONObject(stateFile.readText())
        val files = json.getJSONObject("files")
        State(
            json.optLong("revision", -1),
            json.optString("etag").ifEmpty { null },
            files.keys().asSequence().associateWith { k ->
                files.getJSONObject(k).let {
                    Entry(it.getString("sha1"), it.getLong("size"), it.getLong("mtime"), PackFile.Mode.of(it.optString("mode", "sync")))
                }
            },
        )
    } catch (_: Exception) {
        State(-1, null, emptyMap())
    }

    private fun writeState(s: State) {
        val files = JSONObject()
        s.files.toSortedMap().forEach { (path, e) ->
            files.put(path, JSONObject().put("sha1", e.sha1).put("size", e.size).put("mtime", e.mtime).put("mode", e.mode.id))
        }
        val json = JSONObject().put("revision", s.revision).put("files", files)
        s.etag?.let { json.put("etag", it) }
        writeAtomic(stateFile, json.toString(1))
    }

    private fun writeAtomic(file: File, text: String) {
        file.parentFile?.mkdirs()
        val tmp = File(file.path + ".tmp")
        tmp.writeText(text)
        Files.move(tmp.toPath(), file.toPath(), StandardCopyOption.REPLACE_EXISTING)
    }

    companion object {
        const val PLATFORM = "android"
        private const val PARALLEL = 6

        fun mb(bytes: Long) = "%.1f MB".format(bytes / 1048576.0)
    }
}
