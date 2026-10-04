package dev.eclipsecobblemon.launcher.net

import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

class HttpResponse(val code: Int, val body: String) {
    val ok get() = code in 200..299
    fun json() = JSONObject(body)
}

/** Cliente HTTP mínimo sobre HttpURLConnection (sin dependencias extra). */
object Http {
    private const val USER_AGENT = "EclipseCobblemon/0.1"

    private fun open(url: String, method: String, headers: Map<String, String>): HttpURLConnection =
        (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15_000
            readTimeout = 30_000
            setRequestProperty("User-Agent", USER_AGENT)
            headers.forEach { (k, v) -> setRequestProperty(k, v) }
        }

    private fun HttpURLConnection.readResponse(): HttpResponse {
        val code = responseCode
        val stream = if (code >= 400) errorStream else inputStream
        val body = stream?.bufferedReader()?.use { it.readText() } ?: ""
        disconnect()
        return HttpResponse(code, body)
    }

    fun get(url: String, headers: Map<String, String> = emptyMap()): HttpResponse =
        open(url, "GET", headers).readResponse()

    fun postForm(url: String, form: Map<String, String>): HttpResponse {
        val body = form.entries.joinToString("&") {
            "${URLEncoder.encode(it.key, "UTF-8")}=${URLEncoder.encode(it.value, "UTF-8")}"
        }
        return post(url, body, "application/x-www-form-urlencoded", emptyMap())
    }

    fun postJson(url: String, json: JSONObject, headers: Map<String, String> = emptyMap()): HttpResponse =
        post(url, json.toString(), "application/json", headers + ("Accept" to "application/json"))

    private fun post(url: String, body: String, type: String, headers: Map<String, String>): HttpResponse =
        open(url, "POST", headers + ("Content-Type" to type)).run {
            doOutput = true
            outputStream.use { it.write(body.toByteArray()) }
            readResponse()
        }

    fun getBytes(url: String, headers: Map<String, String> = emptyMap()): ByteArray =
        open(url, "GET", headers).run {
            if (responseCode !in 200..299) {
                disconnect()
                throw IOException("HTTP $responseCode em $url")
            }
            inputStream.use { it.readBytes() }.also { disconnect() }
        }

    /** Petición con cualquier verbo (PUT/DELETE…) y cuerpo opcional. */
    fun send(
        url: String,
        method: String,
        headers: Map<String, String> = emptyMap(),
        body: ByteArray? = null,
        type: String? = null,
    ): HttpResponse = open(url, method, headers + listOfNotNull(type?.let { "Content-Type" to it })).run {
        if (body != null) {
            doOutput = true
            outputStream.use { it.write(body) }
        }
        readResponse()
    }

    /** multipart/form-data con campos de texto y un archivo. */
    fun postMultipart(
        url: String,
        headers: Map<String, String>,
        fields: Map<String, String>,
        fileField: String,
        fileName: String,
        fileType: String,
        file: ByteArray,
    ): HttpResponse {
        val boundary = "----EclipseCobblemon" + System.nanoTime()
        val out = java.io.ByteArrayOutputStream()
        fun line(s: String = "") = out.write("$s\r\n".toByteArray())
        fields.forEach { (k, v) ->
            line("--$boundary")
            line("Content-Disposition: form-data; name=\"$k\"")
            line()
            line(v)
        }
        line("--$boundary")
        line("Content-Disposition: form-data; name=\"$fileField\"; filename=\"$fileName\"")
        line("Content-Type: $fileType")
        line()
        out.write(file)
        line()
        line("--$boundary--")
        return send(url, "POST", headers, out.toByteArray(), "multipart/form-data; boundary=$boundary")
    }

    /** Descarga a un .part y lo renombra al terminar, para no dejar archivos a medias. */
    fun download(url: String, dest: File) {
        dest.parentFile?.mkdirs()
        val tmp = File(dest.path + ".part")
        val conn = open(url, "GET", emptyMap())
        if (conn.responseCode !in 200..299) {
            conn.disconnect()
            throw IOException("HTTP ${conn.responseCode} al descargar $url")
        }
        conn.inputStream.use { input -> tmp.outputStream().use { input.copyTo(it) } }
        conn.disconnect()
        if (dest.exists()) dest.delete()
        if (!tmp.renameTo(dest)) throw IOException("No se pudo mover ${tmp.name}")
    }
}
