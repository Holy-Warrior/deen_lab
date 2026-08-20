package com.holywarrior.silence_of_salah_engine.permissions

import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

object PermissionManager {
    private fun activityIntent(context: Context, action: String, uri: Uri? = null): Intent {
        return Intent(action).apply {
            uri?.let { data = it }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }

    fun hasExactAlarmPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    fun requestExactAlarmPermission(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        context.startActivity(
            activityIntent(
                context,
                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                Uri.parse("package:${context.packageName}")
            )
        )
    }

    fun hasDndAccess(context: Context): Boolean {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.isNotificationPolicyAccessGranted
    }

    fun requestDndAccess(context: Context) {
        context.startActivity(activityIntent(context, Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true

        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun requestIgnoreBatteryOptimizations(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        context.startActivity(
            activityIntent(
                context,
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:${context.packageName}")
            )
        )
    }

    fun hasNotificationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true

        return context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    fun requestNotificationPermission(activity: Activity, requestCode: Int) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return

        activity.requestPermissions(
            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
            requestCode
        )
    }

    data class PermissionStatus(
        val exactAlarm: Boolean,
        val dnd: Boolean,
        val batteryOptimization: Boolean,
        val notifications: Boolean
    ) {
        fun allGranted(): Boolean {
            return exactAlarm && dnd && batteryOptimization && notifications
        }
    }

    fun checkAll(context: Context): PermissionStatus {
        return PermissionStatus(
            exactAlarm = hasExactAlarmPermission(context),
            dnd = hasDndAccess(context),
            batteryOptimization = isIgnoringBatteryOptimizations(context),
            notifications = hasNotificationPermission(context)
        )
    }
}
