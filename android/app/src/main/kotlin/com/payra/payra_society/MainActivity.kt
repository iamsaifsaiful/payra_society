package com.payra.payra_society

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Opens a ready message in a chosen WhatsApp app (personal com.whatsapp or
 * Business com.whatsapp.w4b), so the admin sends from the number they want.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "payra/whatsapp").setMethodCallHandler { call, result ->
            when (call.method) {
                "send" -> {
                    val pkg = call.argument<String>("package") ?: "com.whatsapp"
                    val phone = call.argument<String>("phone") ?: ""
                    val text = call.argument<String>("text") ?: ""
                    val intent = if (phone.isNotEmpty()) {
                        Intent(Intent.ACTION_VIEW, Uri.parse("whatsapp://send?phone=" + Uri.encode(phone) + "&text=" + Uri.encode(text)))
                    } else {
                        Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
                    }
                    intent.setPackage(pkg)
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        result.success(false)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "installed" -> {
                    val found = listOf("com.whatsapp", "com.whatsapp.w4b").filter { p ->
                        try {
                            packageManager.getPackageInfo(p, 0)
                            true
                        } catch (e: Exception) {
                            false
                        }
                    }
                    result.success(found)
                }
                else -> result.notImplemented()
            }
        }
    }
}
