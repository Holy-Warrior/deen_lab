package com.holywarrior.deen_lab.prayer_reminders

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object PrayerReminderStore {
    private const val PREFS_NAME = "deen_lab_prayer_reminders"
    private const val REMINDERS_KEY = "daily_reminders"

    fun save(context: Context, reminders: List<PrayerReminder>) {
        val json = JSONArray()
        reminders.forEach { reminder ->
            json.put(
                JSONObject()
                    .put("id", reminder.id)
                    .put("hour", reminder.hour)
                    .put("minute", reminder.minute)
                    .put("label", reminder.label)
                    .put("silenceEngineEnabled", reminder.silenceEngineEnabled)
            )
        }

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(REMINDERS_KEY, json.toString())
            .apply()
    }

    fun load(context: Context): List<PrayerReminder> {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(REMINDERS_KEY, null)
            ?: return emptyList()

        return runCatching {
            val json = JSONArray(raw)
            List(json.length()) { index ->
                val item = json.getJSONObject(index)
                PrayerReminder(
                    id = item.getInt("id"),
                    hour = item.getInt("hour"),
                    minute = item.getInt("minute"),
                    label = item.optString("label", "Prayer reminder"),
                    silenceEngineEnabled = item.optBoolean("silenceEngineEnabled", false)
                )
            }
        }.getOrDefault(emptyList())
    }

    fun find(context: Context, id: Int): PrayerReminder? {
        return load(context).firstOrNull { it.id == id }
    }
}
