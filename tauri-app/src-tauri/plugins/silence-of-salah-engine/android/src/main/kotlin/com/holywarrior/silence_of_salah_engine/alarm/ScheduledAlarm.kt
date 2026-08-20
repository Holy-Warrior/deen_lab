package com.holywarrior.silence_of_salah_engine.alarm

import org.json.JSONObject
import java.util.Calendar

data class ScheduledAlarm(
    val id: Int,
    val hour: Int,
    val minute: Int,
    val label: String? = null,
    val enabled: Boolean = true
) {
    fun nextTriggerAtMillis(nowMillis: Long = System.currentTimeMillis()): Long {
        val calendar = Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
        }

        if (calendar.timeInMillis <= nowMillis) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        return calendar.timeInMillis
    }

    fun toMap(nextTriggerAtMillis: Long = nextTriggerAtMillis()): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "hour" to hour,
            "minute" to minute,
            "label" to label,
            "enabled" to enabled,
            "nextTriggerAtMillis" to nextTriggerAtMillis,
            "repeatDaily" to true
        )
    }

    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("hour", hour)
            put("minute", minute)
            put("label", label)
            put("enabled", enabled)
        }
    }

    companion object {
        fun fromJson(json: JSONObject): ScheduledAlarm {
            return ScheduledAlarm(
                id = json.getInt("id"),
                hour = json.getInt("hour"),
                minute = json.getInt("minute"),
                label = json.optString("label").takeIf { it.isNotBlank() },
                enabled = json.optBoolean("enabled", true)
            )
        }
    }
}
