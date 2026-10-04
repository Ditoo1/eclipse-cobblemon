package dev.eclipsecobblemon.launcher.auth

import android.content.Context
import org.json.JSONObject

/** Guarda la cuenta activa en el almacenamiento privado de la app. */
class AccountStore(context: Context) {
    private val prefs = context.getSharedPreferences("accounts", Context.MODE_PRIVATE)

    fun load(): Account? = prefs.getString("active", null)?.let {
        runCatching { Account.fromJson(JSONObject(it)) }.getOrNull()
    }

    fun save(account: Account) = prefs.edit().putString("active", account.toJson().toString()).apply()

    fun clear() = prefs.edit().remove("active").apply()
}
