package com.holywarrior.silence_of_salah_engine.alarm

import com.holywarrior.silence_of_salah_engine.Config
import org.json.JSONObject
import java.util.Calendar

/**
 * One clock-driven silence period used by `EngineMode.MANUAL`: go silent at
 * [hour]:[minute], come back [durationMinutes] later, every day.
 *
 * [hour] and [minute] are the *final* wall-clock start, with any prayer-time
 * offset already applied by the caller. The plugin has no idea when Asr is - it
 * cannot compute prayer times and has no location - so the app owns that
 * arithmetic and sends the resolved time, exactly as it already does for
 * [ScheduledAlarm].
 *
 * A window that runs past midnight needs no special handling: the start is a
 * daily repeating clock time (so it just lands on the neighbouring day), and the
 * end is an absolute instant computed when the window actually opens.
 */
data class SilenceWindow(
    val id: Int,
    val hour: Int,
    val minute: Int,
    val durationMinutes: Int,
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

    /** When a window opened at [startedAtMillis] should hand the ringer back. */
    fun endsAtMillis(startedAtMillis: Long): Long =
        startedAtMillis + durationMinutes * 60_000L

    fun toMap(nextTriggerAtMillis: Long = nextTriggerAtMillis()): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "hour" to hour,
            "minute" to minute,
            "durationMinutes" to durationMinutes,
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
            put("durationMinutes", durationMinutes)
            put("label", label)
            put("enabled", enabled)
        }
    }

    companion object {
        fun fromJson(json: JSONObject): SilenceWindow {
            return SilenceWindow(
                id = json.getInt("id"),
                hour = json.getInt("hour"),
                minute = json.getInt("minute"),
                durationMinutes = json.optInt("durationMinutes", Config.MANUAL_WINDOW_DEFAULT_MINUTES),
                label = json.optString("label").takeIf { it.isNotBlank() },
                enabled = json.optBoolean("enabled", true)
            )
        }
    }
}
