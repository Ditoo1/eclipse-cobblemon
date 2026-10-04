package dev.eclipsecobblemon.launcher.auth

import org.json.JSONObject

enum class AccountType { MICROSOFT, OFFLINE }

data class Account(
    val type: AccountType,
    val username: String,
    val uuid: String,
    val accessToken: String,
    val refreshToken: String? = null,
    val xuid: String = "0",
    /** Epoch millis en que caduca el token de Minecraft (0 = no caduca, offline). */
    val expiresAt: Long = 0L,
) {
    val isPremium get() = type == AccountType.MICROSOFT
    val needsRefresh get() = isPremium && System.currentTimeMillis() > expiresAt - 60_000
    /** Valor de user_type en los argumentos del juego. */
    val userType get() = if (isPremium) "msa" else "legacy"

    fun toJson(): JSONObject = JSONObject()
        .put("type", type.name)
        .put("username", username)
        .put("uuid", uuid)
        .put("accessToken", accessToken)
        .put("refreshToken", refreshToken ?: JSONObject.NULL)
        .put("xuid", xuid)
        .put("expiresAt", expiresAt)

    companion object {
        fun fromJson(o: JSONObject) = Account(
            type = AccountType.valueOf(o.getString("type")),
            username = o.getString("username"),
            uuid = o.getString("uuid"),
            accessToken = o.getString("accessToken"),
            refreshToken = o.optString("refreshToken").takeIf { it.isNotEmpty() && it != "null" },
            xuid = o.optString("xuid", "0"),
            expiresAt = o.optLong("expiresAt", 0L),
        )
    }
}
