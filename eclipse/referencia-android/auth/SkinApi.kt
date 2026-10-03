package dev.eclipsecobblemon.launcher.auth

import dev.eclipsecobblemon.launcher.net.Http
import dev.eclipsecobblemon.launcher.net.HttpResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

enum class SkinVariant { CLASSIC, SLIM }

data class Cape(val id: String, val alias: String, val url: String, val active: Boolean)

data class SkinProfile(
    val skinUrl: String?,
    val variant: SkinVariant,
    val capes: List<Cape>,
) {
    val activeCape get() = capes.firstOrNull { it.active }
}

/**
 * Skins y capas de cuentas Microsoft, con la API oficial de Minecraft Services.
 * Los cambios son globales: se ven en cualquier servidor y en el launcher de PC.
 */
object SkinApi {
    private const val BASE = "https://api.minecraftservices.com/minecraft/profile"

    private fun bearer(token: String) = mapOf("Authorization" to "Bearer $token", "Accept" to "application/json")

    suspend fun profile(token: String): SkinProfile = io {
        parse(Http.get(BASE, bearer(token)))
    }

    /** Sube un PNG (64×64 o 64×32). */
    suspend fun upload(token: String, png: ByteArray, variant: SkinVariant): SkinProfile = io {
        parse(
            Http.postMultipart(
                "$BASE/skins", bearer(token),
                fields = mapOf("variant" to variant.name.lowercase()),
                fileField = "file", fileName = "skin.png", fileType = "image/png", file = png,
            )
        )
    }

    /** Cambia solo el modelo (clásico/fino) reutilizando la textura que ya tiene. */
    suspend fun changeVariant(token: String, url: String, variant: SkinVariant): SkinProfile = io {
        parse(Http.postJson("$BASE/skins", JSONObject().put("variant", variant.name.lowercase()).put("url", url), bearer(token)))
    }

    /** Vuelve a la skin por defecto (Steve/Alex según el UUID). */
    suspend fun reset(token: String): SkinProfile = io {
        parse(Http.send("$BASE/skins/active", "DELETE", bearer(token)))
    }

    /** Activa una capa, o la quita con null. */
    suspend fun setCape(token: String, capeId: String?): SkinProfile = io {
        parse(
            if (capeId == null) Http.send("$BASE/capes/active", "DELETE", bearer(token))
            else Http.send("$BASE/capes/active", "PUT", bearer(token), JSONObject().put("capeId", capeId).toString().toByteArray(), "application/json")
        )
    }

    private suspend fun <T> io(block: () -> T) = withContext(Dispatchers.IO) { block() }

    private fun parse(r: HttpResponse): SkinProfile {
        if (!r.ok) {
            val msg = runCatching { r.json().optString("errorMessage").ifEmpty { r.json().optString("error") } }.getOrNull()
            throw AuthException(
                when (r.code) {
                    400 -> "Skin inválida: ${msg ?: "use um PNG de 64×64"}"
                    401 -> "Sessão expirada: inicie sessão novamente"
                    429 -> "Demasiados pedidos. Aguarde um minuto e tente outra vez"
                    else -> "Erro da Mojang (${r.code})${msg?.let { ": $it" } ?: ""}"
                }
            )
        }
        val o = r.json()
        val skin = o.optJSONArray("skins")?.let { arr ->
            (0 until arr.length()).map { arr.getJSONObject(it) }.firstOrNull { it.optString("state") == "ACTIVE" }
        }
        val capes = o.optJSONArray("capes")?.let { arr ->
            (0 until arr.length()).map { arr.getJSONObject(it) }.map {
                Cape(it.getString("id"), it.optString("alias", "Capa"), it.optString("url"), it.optString("state") == "ACTIVE")
            }
        }.orEmpty()
        return SkinProfile(
            skinUrl = skin?.optString("url")?.replace("http://", "https://"),
            variant = if (skin?.optString("variant").equals("SLIM", ignoreCase = true)) SkinVariant.SLIM else SkinVariant.CLASSIC,
            capes = capes.map { it.copy(url = it.url.replace("http://", "https://")) },
        )
    }
}
