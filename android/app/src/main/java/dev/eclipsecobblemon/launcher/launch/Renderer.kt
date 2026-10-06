package dev.eclipsecobblemon.launcher.launch

import android.content.Context
import net.kdt.pojavlaunch.Tools

/**
 * Renderers que el jugador puede elegir. Solo los que trae el APK: MobileGlues (OpenGL ES),
 * MobileGlues sobre ANGLE y Kopper Zink; los dos últimos necesitan Vulkan.
 */
enum class Renderer(
    val id: String,
    val label: String,
    val description: String,
    /** pojavRendererName del perfil de Amethyst; null = el suyo por defecto (MobileGlues, con alternativa si falla). */
    val amethystName: String?,
    val angle: Boolean = false,
    val needsVulkan: Boolean = false,
) {
    AUTO("auto", "Automático", "MobileGlues; se não for compatível, usa o primeiro que funcionar.", null),
    MOBILEGLUES("mobileglues", "MobileGlues", "OpenGL ES. O mais rápido na maioria dos telemóveis.", "opengles_mobileglues"),
    MOBILEGLUES_ANGLE(
        "mobileglues_angle", "MobileGlues + ANGLE", "Por Vulkan. Pode corrigir gráficos estranhos em alguns telemóveis.",
        "opengles_mobileglues", angle = true, needsVulkan = true,
    ),
    ZINK("zink", "Zink (Vulkan)", "Mais compatível, mas normalmente mais lento.", "opengles3_desktopgl_zink_kopper", needsVulkan = true);

    companion object {
        fun fromId(id: String?): Renderer = entries.firstOrNull { it.id == id } ?: AUTO

        /** Los que funcionan en este equipo. */
        fun available(context: Context): List<Renderer> {
            val vulkan = Tools.checkVulkanSupport(context.packageManager)
            return entries.filter { !it.needsVulkan || vulkan }
        }
    }
}
