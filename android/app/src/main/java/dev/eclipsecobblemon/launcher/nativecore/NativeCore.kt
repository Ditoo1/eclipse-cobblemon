package dev.eclipsecobblemon.launcher.nativecore

import java.io.File
import java.security.MessageDigest
import java.util.UUID

/**
 * Capa Rust (native/ -> libeclipse_core.so) para hash de archivos y UUID offline.
 * Si la librería no está compilada en jniLibs se usa la implementación Kotlin equivalente.
 */
object NativeCore {
    val available: Boolean = try {
        System.loadLibrary("eclipse_core")
        true
    } catch (_: Throwable) {
        false
    }

    @JvmStatic private external fun nativeOfflineUuid(name: String): String
    @JvmStatic private external fun nativeSha1File(path: String): String?

    /** UUID v3 de "OfflinePlayer:<nombre>", igual que el servidor vanilla en modo offline. */
    fun offlineUuid(name: String): String =
        if (available) nativeOfflineUuid(name)
        else UUID.nameUUIDFromBytes("OfflinePlayer:$name".toByteArray()).toString()

    fun sha1(file: File): String? {
        if (!file.isFile) return null
        if (available) return nativeSha1File(file.absolutePath)
        val md = MessageDigest.getInstance("SHA-1")
        file.inputStream().use { input ->
            val buf = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buf)
                if (n < 0) break
                md.update(buf, 0, n)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }
}
