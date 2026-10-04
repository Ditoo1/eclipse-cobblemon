package dev.eclipsecobblemon.launcher

import dev.eclipsecobblemon.launcher.auth.OfflineAuth
import dev.eclipsecobblemon.launcher.game.LaunchSpec
import dev.eclipsecobblemon.launcher.game.Rules
import dev.eclipsecobblemon.launcher.game.mavenPath
import org.json.JSONArray
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameLogicTest {
    @Test
    fun offlineUuidMatchesVanilla() {
        // Sin libeclipse_core.so en la JVM de tests se usa el fallback Kotlin; ambos deben coincidir.
        assertEquals("b50ad385-829d-3141-a216-7e7d7539ba7f", OfflineAuth.login("Notch").uuid)
    }

    @Test
    fun offlineNameValidation() {
        assertTrue(OfflineAuth.isValidName("Steve_01"))
        assertFalse(OfflineAuth.isValidName("ab"))
        assertFalse(OfflineAuth.isValidName("con espacio"))
    }

    @Test
    fun mavenPathWithClassifier() {
        assertEquals("org/lwjgl/lwjgl/3.3.3/lwjgl-3.3.3-natives-linux.jar", mavenPath("org.lwjgl:lwjgl:3.3.3:natives-linux"))
        assertEquals("com/google/guava/guava/32.1.2-jre/guava-32.1.2-jre.jar", mavenPath("com.google.guava:guava:32.1.2-jre"))
    }

    @Test
    fun rulesTreatAndroidAsLinux() {
        val onlyMac = JSONArray("""[{"action":"allow","os":{"name":"osx"}}]""")
        val allButMac = JSONArray("""[{"action":"allow"},{"action":"disallow","os":{"name":"osx"}}]""")
        val onlyLinux = JSONArray("""[{"action":"allow","os":{"name":"linux"}}]""")
        assertFalse(Rules.allowed(onlyMac))
        assertTrue(Rules.allowed(allButMac))
        assertTrue(Rules.allowed(onlyLinux))
        assertTrue(Rules.allowed(null))
    }

    @Test
    fun substituteDropsUnresolvedFlags() {
        val args = listOf("--username", "\${auth_player_name}", "--quickPlayPath", "\${quickPlayPath}", "--userType", "\${user_type}")
        val out = LaunchSpec.substitute(args, mapOf("auth_player_name" to "Steve", "user_type" to "legacy"))
        assertEquals(listOf("--username", "Steve", "--userType", "legacy"), out)
    }
}
