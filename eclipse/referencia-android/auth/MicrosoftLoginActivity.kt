package dev.eclipsecobblemon.launcher.auth

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient

/**
 * Abre la página real de login de Microsoft y espera a que redirija a REDIRECT_URI con el
 * código en la query (igual que la ventana embebida de template-launcher). Devuelve el código
 * en EXTRA_CODE, o EXTRA_ERROR si Microsoft devolvió un error.
 */
class MicrosoftLoginActivity : Activity() {
    companion object {
        const val EXTRA_CODE = "code"
        const val EXTRA_ERROR = "error"
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "Iniciar sessão com a Microsoft"

        // Sin cookies previas, para poder elegir otra cuenta cada vez.
        CookieManager.getInstance().removeAllCookies(null)

        val web = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
                    intercept(request.url)

                @Deprecated("API < 24")
                override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean =
                    intercept(Uri.parse(url))
            }
        }
        setContentView(web)
        web.loadUrl(MicrosoftAuth.authorizeUrl)
    }

    private fun intercept(url: Uri): Boolean {
        if (!url.toString().startsWith(MicrosoftAuth.REDIRECT_URI)) return false
        val code = url.getQueryParameter("code")
        val data = Intent()
        if (code != null) {
            data.putExtra(EXTRA_CODE, code)
            setResult(RESULT_OK, data)
        } else {
            data.putExtra(EXTRA_ERROR, url.getQueryParameter("error_description") ?: url.getQueryParameter("error") ?: "Início de sessão cancelado")
            setResult(RESULT_CANCELED, data)
        }
        finish()
        return true
    }
}
