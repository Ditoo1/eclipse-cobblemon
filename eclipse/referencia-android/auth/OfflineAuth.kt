package dev.eclipsecobblemon.launcher.auth

import dev.eclipsecobblemon.launcher.nativecore.NativeCore

object OfflineAuth {
    private val VALID_NAME = Regex("^[A-Za-z0-9_]{3,16}$")

    fun isValidName(name: String) = VALID_NAME.matches(name)

    fun login(name: String): Account {
        require(isValidName(name)) { "O nome deve ter 3-16 caracteres: letras, números ou _" }
        return Account(
            type = AccountType.OFFLINE,
            username = name,
            uuid = NativeCore.offlineUuid(name),
            accessToken = "0",
        )
    }
}
