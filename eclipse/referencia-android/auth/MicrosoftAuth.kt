package dev.eclipsecobblemon.launcher.auth

import android.net.Uri
import dev.eclipsecobblemon.launcher.net.Http
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

class AuthException(message: String) : Exception(message)

/**
 * Login premium, igual que template-launcher (session.rs):
 * OAuth en login.live.com (WebView) -> Xbox Live -> XSTS -> Minecraft Services -> licencia -> perfil.
 *
 * Usa el client ID público del launcher oficial (el mismo que PojavLauncher/Amethyst), así que
 * no hace falta registrar una app en Azure. Para producción propia, cambia CLIENT_ID por el tuyo.
 */
object MicrosoftAuth {
    const val CLIENT_ID = "00000000402b5328"
    const val REDIRECT_URI = "https://login.live.com/oauth20_desktop.srf"
    private const val SCOPE = "service::user.auth.xboxlive.com::MBI_SSL"
    private const val TOKEN_URL = "https://login.live.com/oauth20_token.srf"

    val authorizeUrl: String = Uri.parse("https://login.live.com/oauth20_authorize.srf").buildUpon()
        .appendQueryParameter("client_id", CLIENT_ID)
        .appendQueryParameter("response_type", "code")
        .appendQueryParameter("redirect_uri", REDIRECT_URI)
        .appendQueryParameter("scope", SCOPE)
        .appendQueryParameter("prompt", "select_account")
        .build().toString()

    /** Paso tras el WebView: canjea el código de autorización por la cuenta completa. */
    suspend fun loginWithCode(code: String, log: (String) -> Unit): Account = withContext(Dispatchers.IO) {
        val ms = tokenRequest(
            mapOf("code" to code, "grant_type" to "authorization_code", "redirect_uri" to REDIRECT_URI)
        )
        log("Tokens da Microsoft obtidos")
        finishLogin(ms, checkOwnership = true, log = log)
    }

    suspend fun refresh(account: Account, log: (String) -> Unit): Account = withContext(Dispatchers.IO) {
        val rt = account.refreshToken ?: throw AuthException("Sem refresh token: inicie sessão novamente")
        val ms = tokenRequest(mapOf("refresh_token" to rt, "grant_type" to "refresh_token"))
        log("Sessão da Microsoft renovada")
        finishLogin(ms, checkOwnership = false, log = log)
    }

    private fun tokenRequest(params: Map<String, String>): JSONObject {
        val r = Http.postForm(TOKEN_URL, params + mapOf("client_id" to CLIENT_ID, "scope" to SCOPE))
        if (!r.ok) throw AuthException("A Microsoft recusou o token (${r.code}): ${r.body}")
        return r.json()
    }

    private fun finishLogin(ms: JSONObject, checkOwnership: Boolean, log: (String) -> Unit): Account {
        val msToken = ms.getString("access_token")

        // 1. Xbox Live (con el client ID de live.com el ticket va sin el prefijo "d=")
        val xbl = Http.postJson(
            "https://user.auth.xboxlive.com/user/authenticate",
            JSONObject()
                .put("Properties", JSONObject()
                    .put("AuthMethod", "RPS")
                    .put("SiteName", "user.auth.xboxlive.com")
                    .put("RpsTicket", msToken))
                .put("RelyingParty", "http://auth.xboxlive.com")
                .put("TokenType", "JWT")
        )
        if (!xbl.ok) throw AuthException("A Xbox Live recusou a solicitação (${xbl.code}): ${xbl.body}")
        val xblJson = xbl.json()
        val xblToken = xblJson.getString("Token")
        val uhs = xblJson.getJSONObject("DisplayClaims").getJSONArray("xui").getJSONObject(0).getString("uhs")
        log("Token XBL obtido")

        // 2. XSTS
        val xsts = Http.postJson(
            "https://xsts.auth.xboxlive.com/xsts/authorize",
            JSONObject()
                .put("Properties", JSONObject()
                    .put("SandboxId", "RETAIL")
                    .put("UserTokens", JSONArray().put(xblToken)))
                .put("RelyingParty", "rp://api.minecraftservices.com/")
                .put("TokenType", "JWT")
        )
        if (!xsts.ok) {
            val xerr = runCatching { xsts.json().optLong("XErr") }.getOrDefault(0L)
            throw AuthException(
                when (xerr) {
                    2148916233L -> "Esta conta não tem perfil Xbox. Crie um primeiro em xbox.com"
                    2148916235L -> "A Xbox Live não está disponível no seu país"
                    2148916236L, 2148916237L -> "A conta precisa de verificação de idade adulta"
                    2148916238L -> "Esta é uma conta infantil. Ela precisa ser adicionada a um grupo familiar da Microsoft"
                    else -> "O XSTS recusou a solicitação (${xsts.code}): ${xsts.body}"
                }
            )
        }
        val xstsJson = xsts.json()
        val xstsToken = xstsJson.getString("Token")
        val xuid = xstsJson.getJSONObject("DisplayClaims").getJSONArray("xui").getJSONObject(0)
            .optString("xid", "0")
        log("Token XSTS obtido")

        // 3. Minecraft Services
        val mc = Http.postJson(
            "https://api.minecraftservices.com/authentication/login_with_xbox",
            JSONObject().put("identityToken", "XBL3.0 x=$uhs;$xstsToken")
        )
        if (!mc.ok) throw AuthException("O Minecraft recusou o token (${mc.code}): ${mc.body}")
        val mcJson = mc.json()
        val mcToken = mcJson.getString("access_token")
        val expiresAt = System.currentTimeMillis() + mcJson.optLong("expires_in", 86400) * 1000
        log("Token do Minecraft obtido")
        val bearer = mapOf("Authorization" to "Bearer $mcToken")

        // 4. Licencia (solo en el primer login, como en el template)
        if (checkOwnership) {
            val ent = Http.get("https://api.minecraftservices.com/entitlements/mcstore", bearer)
            val items = runCatching { ent.json().optJSONArray("items") }.getOrNull()
            if (items == null || items.length() == 0) {
                throw AuthException("Esta conta não tem o Minecraft: Java Edition. Compre em minecraft.net")
            }
            log("Licença verificada")
        }

        // 5. Perfil
        val profile = Http.get("https://api.minecraftservices.com/minecraft/profile", bearer)
        if (profile.code == 404) throw AuthException("A conta não tem perfil do Minecraft Java (falta escolher um nome?)")
        if (!profile.ok) throw AuthException("Erro ao obter o perfil (${profile.code}): ${profile.body}")
        val p = profile.json()
        log("Perfil: ${p.getString("name")}")

        return Account(
            type = AccountType.MICROSOFT,
            username = p.getString("name"),
            uuid = dashUuid(p.getString("id")),
            accessToken = mcToken,
            refreshToken = ms.optString("refresh_token").ifEmpty { null },
            xuid = xuid,
            expiresAt = expiresAt,
        )
    }

    private fun dashUuid(id: String) = if (id.length != 32) id else
        "${id.substring(0, 8)}-${id.substring(8, 12)}-${id.substring(12, 16)}-" +
            "${id.substring(16, 20)}-${id.substring(20)}"
}
