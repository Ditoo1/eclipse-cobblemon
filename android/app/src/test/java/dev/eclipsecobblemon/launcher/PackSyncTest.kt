package dev.eclipsecobblemon.launcher

import dev.eclipsecobblemon.launcher.game.PackManifest
import dev.eclipsecobblemon.launcher.game.PackPaths
import dev.eclipsecobblemon.launcher.game.PackSync
import dev.eclipsecobblemon.launcher.game.PackTransport
import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.security.MessageDigest

class PackSyncTest {
    private val url = "https://pack.test/v1/manifest"
    private lateinit var game: File
    private lateinit var server: FakeServer

    /** Servidor en memoria: manifiesto con ETag y objetos por SHA-1, como el Worker. */
    private class FakeServer : PackTransport {
        val objects = HashMap<String, ByteArray>()
        var manifest = ""
        var online = true
        var corrupt = false
        val downloads = mutableListOf<String>()
        private val etag get() = "\"" + sha1(manifest.toByteArray()) + "\""

        override fun fetchManifest(url: String, etag: String?): PackTransport.Fetched? {
            if (!online) throw IOException("offline")
            return if (etag == this.etag) null else PackTransport.Fetched(manifest, this.etag)
        }

        override fun download(url: String, dest: File, onBytes: (Long) -> Unit) {
            if (!online) throw IOException("offline")
            assertTrue(url, url.startsWith("https://pack.test/v1/objects/"))
            val hash = url.substringAfterLast('/')
            downloads += hash
            val data = if (corrupt) "lixo".toByteArray() else objects.getValue(hash)
            dest.parentFile?.mkdirs()
            dest.writeBytes(data)
            onBytes(data.size.toLong())
        }
    }

    private class Spec(val path: String, val content: String, val mode: String? = null, val platforms: List<String>? = null)

    private fun publish(revision: Long, vararg files: Spec, exclusive: List<String> = listOf("mods"), loader: String? = null) {
        val arr = JSONArray()
        for (f in files) {
            val bytes = f.content.toByteArray()
            val hash = sha1(bytes)
            server.objects[hash] = bytes
            arr.put(JSONObject().put("path", f.path).put("sha1", hash).put("size", bytes.size).apply {
                f.mode?.let { put("mode", it) }
                f.platforms?.let { put("platforms", JSONArray(it)) }
            })
        }
        server.manifest = JSONObject()
            .put("format", 1).put("revision", revision).put("minecraft", "1.21.1")
            .put("objects", "objects/").put("exclusive", JSONArray(exclusive)).put("files", arr)
            .apply { loader?.let { put("loader", JSONObject().put("type", "fabric").put("version", it)) } }
            .toString()
    }

    private fun sync(verify: Boolean = false): PackSync.Result = runBlocking {
        val s = PackSync(game, url, transport = server)
        s.apply(s.fetch(), verify, {}, { _, _ -> })
    }

    private fun file(path: String) = File(game, path)

    @Before
    fun setUp() {
        game = Files.createTempDirectory("pack").toFile()
        server = FakeServer()
    }

    @Test
    fun installsEverythingFirstTime() {
        publish(1, Spec("mods/cobblemon.jar", "cobblemon"), Spec("config/cobblemon/main.json", "{}"))
        val r = sync()
        assertEquals(2, r.downloaded)
        assertEquals("cobblemon", file("mods/cobblemon.jar").readText())
        assertEquals("{}", file("config/cobblemon/main.json").readText())
        assertFalse(file(".eclipse/staging").exists())
    }

    @Test
    fun secondSyncDownloadsNothing() {
        publish(1, Spec("mods/a.jar", "a"), Spec("mods/b.jar", "b"))
        sync()
        server.downloads.clear()
        val r = sync()
        assertEquals(0, r.downloaded)
        assertEquals(2, r.upToDate)
        assertTrue(server.downloads.isEmpty())
    }

    @Test
    fun updatesReplacesAndDeletes() {
        publish(1, Spec("mods/a.jar", "a1"), Spec("mods/old.jar", "old"), Spec("resourcepacks/eclipse.zip", "rp"))
        sync()
        file("mods/intruso.jar").writeText("x")
        file("resourcepacks/meu.zip").writeText("do jogador")

        publish(2, Spec("mods/a.jar", "a2"), Spec("resourcepacks/eclipse.zip", "rp"))
        val r = sync()
        assertEquals(1, r.downloaded)
        assertEquals("a2", file("mods/a.jar").readText())
        assertFalse("retirado do painel", file("mods/old.jar").exists())
        assertFalse("mods/ é exclusiva", file("mods/intruso.jar").exists())
        assertTrue("resourcepacks/ não é exclusiva", file("resourcepacks/meu.zip").exists())
    }

    @Test
    fun repairsModifiedFiles() {
        publish(1, Spec("mods/a.jar", "original"))
        sync()
        // Mismo tamaño: solo el SHA-1 lo detecta
        file("mods/a.jar").writeText("alterado")
        file("mods/a.jar").setLastModified(1_000)
        assertEquals(1, sync().downloaded)
        assertEquals("original", file("mods/a.jar").readText())
    }

    @Test
    fun verifyRehashesEvenWithSameDate() {
        publish(1, Spec("mods/a.jar", "original"))
        sync()
        val f = file("mods/a.jar")
        val mtime = f.lastModified()
        f.writeText("alterado")
        f.setLastModified(mtime)
        assertEquals("sem verify confia no estado", 0, sync().downloaded)
        assertEquals(1, sync(verify = true).downloaded)
        assertEquals("original", f.readText())
    }

    @Test
    fun onceFilesBelongToThePlayer() {
        publish(1, Spec("config/teclas.json", "padrão", mode = "once"), Spec("config/outro.json", "padrão", mode = "once"))
        sync()
        file("config/teclas.json").writeText("do jogador")

        publish(2, Spec("config/teclas.json", "novo padrão", mode = "once"), Spec("config/outro.json", "padrão", mode = "once"))
        sync()
        assertEquals("do jogador", file("config/teclas.json").readText())

        publish(3)
        sync()
        assertTrue("alterado pelo jogador: fica", file("config/teclas.json").exists())
        assertFalse("sem alterações: removido", file("config/outro.json").exists())
    }

    @Test
    fun noInternetBlocks() {
        publish(1, Spec("mods/a.jar", "a"))
        sync()
        server.online = false
        assertThrows(IOException::class.java) { sync() }
    }

    @Test
    fun corruptDownloadLeavesGameUntouched() {
        publish(1, Spec("mods/a.jar", "a1"), Spec("mods/b.jar", "b"))
        sync()
        publish(2, Spec("mods/a.jar", "a2"))
        server.corrupt = true
        assertThrows(IOException::class.java) { sync() }
        assertEquals("a1", file("mods/a.jar").readText())
        assertTrue("nada se apaga se a transferência falha", file("mods/b.jar").exists())
    }

    @Test
    fun sameContentIsDownloadedOnce() {
        publish(1, Spec("mods/a.jar", "igual"), Spec("config/copia.jar", "igual"))
        sync()
        assertEquals(1, server.downloads.size)
        assertEquals("igual", file("config/copia.jar").readText())
    }

    @Test
    fun platformFilter() {
        publish(1, Spec("mods/so-ios.jar", "i", platforms = listOf("ios")), Spec("mods/so-android.jar", "a", platforms = listOf("android")))
        sync()
        assertTrue(file("mods/so-android.jar").exists())
        assertFalse(file("mods/so-ios.jar").exists())
    }

    @Test
    fun playerFilesAreOffLimits() {
        listOf("options.txt", "saves/mundo/level.dat", "../fora", "/abs", "mods/../saves/x", "Saves/x", "versions/x.json", "a\\b")
            .forEach { assertFalse(it, PackPaths.isSafe(it)) }
        assertTrue(PackPaths.isSafe("mods/cobblemon.jar"))
        assertTrue(PackPaths.isSafe("config/cobblemon/main.json"))

        publish(1, Spec("options.txt", "x"))
        assertThrows(IllegalArgumentException::class.java) { sync() }
    }

    @Test
    fun savesSurviveExclusive() {
        file("saves/mundo/level.dat").apply { parentFile!!.mkdirs(); writeText("mundo") }
        file("options.txt").writeText("fov:90")
        publish(1, Spec("mods/a.jar", "a"))
        sync()
        assertEquals("mundo", file("saves/mundo/level.dat").readText())
        assertEquals("fov:90", file("options.txt").readText())
    }

    @Test
    fun fabricVersionId() {
        publish(1, loader = "0.16.14")
        assertEquals("fabric-loader-0.16.14-1.21.1", PackManifest.parse(server.manifest).versionId)
        publish(1)
        assertEquals("1.21.1", PackManifest.parse(server.manifest).versionId)
    }

    private companion object {
        fun sha1(bytes: ByteArray) = MessageDigest.getInstance("SHA-1").digest(bytes).joinToString("") { "%02x".format(it) }
    }
}
