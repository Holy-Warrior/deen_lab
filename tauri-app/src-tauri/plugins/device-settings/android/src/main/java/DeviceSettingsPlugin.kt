package com.deenlab.devicesettings

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.webkit.WebView
import android.widget.Toast
import app.tauri.annotation.Command
import app.tauri.annotation.InvokeArg
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.Plugin

@InvokeArg
class ToastArgs {
    lateinit var message: String
}

@TauriPlugin
class DeviceSettingsPlugin(private val activity: Activity) : Plugin(activity) {

    override fun load(webView: WebView) {
        super.load(webView)
    }

    @Command
    fun openLocationSettings(invoke: Invoke) {
        val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
        invoke.resolve()
    }

    // Once Android stops showing its own permission dialog (after a prior denial), this app's
    // own "App info" screen is the only remaining way for the user to grant it manually.
    @Command
    fun openAppSettings(invoke: Invoke) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = Uri.fromParts("package", activity.packageName, null)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
        invoke.resolve()
    }

    @Command
    fun showToast(invoke: Invoke) {
        val args = invoke.parseArgs(ToastArgs::class.java)
        // Toast must be shown from the UI thread; plugin commands don't run on it by default.
        activity.runOnUiThread {
            Toast.makeText(activity, args.message, Toast.LENGTH_LONG).show()
        }
        invoke.resolve()
    }
}
