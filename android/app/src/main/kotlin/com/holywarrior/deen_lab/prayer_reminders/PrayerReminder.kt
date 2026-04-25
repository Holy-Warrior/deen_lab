package com.holywarrior.deen_lab.prayer_reminders

data class PrayerReminder(
    val id: Int,
    val hour: Int,
    val minute: Int,
    val label: String,
    val silenceEngineEnabled: Boolean
)
