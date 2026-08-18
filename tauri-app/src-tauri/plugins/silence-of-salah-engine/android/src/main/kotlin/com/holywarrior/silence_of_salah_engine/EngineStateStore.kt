package com.holywarrior.silence_of_salah_engine

import android.content.Context
import com.holywarrior.silence_of_salah_engine.alarm.ScheduledAlarm
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

enum class ManagedAudioState {
    DEFAULT,
    SILENT
}

data class EnginePersistentState(
    val recentMlOutputs: List<Boolean> = emptyList(),
    val originalRingerMode: Int? = null,
    val audioState: ManagedAudioState = ManagedAudioState.DEFAULT,
    val hasEnteredSilentOnce: Boolean = false,
    val shutdownDeadlineMillis: Long? = null,
    val alarms: List<ScheduledAlarm> = emptyList()
)

object EngineStateStore {
    private const val COMPONENT = "StateStore"

    fun load(context: Context): EnginePersistentState {
        val file = stateFile(context)
        if (!file.exists()) {
            return EnginePersistentState()
        }

        return try {
            fromJson(JSONObject(file.readText()))
        } catch (error: Exception) {
            EngineLog.e(COMPONENT, "Failed to read persisted engine state. Resetting store.", error)
            EnginePersistentState()
        }
    }

    fun save(context: Context, state: EnginePersistentState) {
        val file = stateFile(context)
        try {
            file.writeText(toJson(state).toString())
        } catch (error: Exception) {
            EngineLog.e(COMPONENT, "Failed to persist engine state.", error)
        }
    }

    fun update(
        context: Context,
        transform: (EnginePersistentState) -> EnginePersistentState
    ): EnginePersistentState {
        val updatedState = transform(load(context))
        save(context, updatedState)
        return updatedState
    }

    fun resetForFreshServiceStart(context: Context, originalRingerMode: Int): EnginePersistentState {
        val state = load(context)
        val refreshed = state.copy(
            recentMlOutputs = emptyList(),
            originalRingerMode = originalRingerMode,
            audioState = ManagedAudioState.DEFAULT,
            hasEnteredSilentOnce = false,
            shutdownDeadlineMillis = null
        )
        save(context, refreshed)
        return refreshed
    }

    fun appendMlOutput(context: Context, value: Boolean): EnginePersistentState {
        return update(context) { current ->
            val nextOutputs = (current.recentMlOutputs + value).takeLast(Config.ML_BUFFER_SIZE)
            current.copy(recentMlOutputs = nextOutputs)
        }
    }

    fun updateAlarms(context: Context, alarms: List<ScheduledAlarm>): EnginePersistentState {
        return update(context) {
            it.copy(alarms = alarms.sortedWith(compareBy({ alarm -> alarm.hour }, { alarm -> alarm.minute }, { alarm -> alarm.id })))
        }
    }

    private fun stateFile(context: Context): File {
        return File(context.filesDir, Config.STATE_FILE_NAME)
    }

    private fun toJson(state: EnginePersistentState): JSONObject {
        return JSONObject().apply {
            put("recentMlOutputs", JSONArray().apply {
                state.recentMlOutputs.forEach { put(it) }
            })
            put("originalRingerMode", state.originalRingerMode)
            put("audioState", state.audioState.name)
            put("hasEnteredSilentOnce", state.hasEnteredSilentOnce)
            put("shutdownDeadlineMillis", state.shutdownDeadlineMillis)
            put("alarms", JSONArray().apply {
                state.alarms.forEach { put(it.toJson()) }
            })
        }
    }

    private fun fromJson(json: JSONObject): EnginePersistentState {
        val outputs = buildList {
            val array = json.optJSONArray("recentMlOutputs") ?: JSONArray()
            for (index in 0 until array.length()) {
                add(array.optBoolean(index))
            }
        }

        val alarms = buildList {
            val array = json.optJSONArray("alarms") ?: JSONArray()
            for (index in 0 until array.length()) {
                add(ScheduledAlarm.fromJson(array.getJSONObject(index)))
            }
        }

        return EnginePersistentState(
            recentMlOutputs = outputs.takeLast(Config.ML_BUFFER_SIZE),
            originalRingerMode = json.optInt("originalRingerMode").takeIf { json.has("originalRingerMode") },
            audioState = json.optString("audioState")
                .takeIf { it.isNotBlank() }
                ?.let(ManagedAudioState::valueOf)
                ?: ManagedAudioState.DEFAULT,
            hasEnteredSilentOnce = json.optBoolean("hasEnteredSilentOnce", false),
            shutdownDeadlineMillis = json.optLong("shutdownDeadlineMillis").takeIf {
                json.has("shutdownDeadlineMillis") && !json.isNull("shutdownDeadlineMillis")
            },
            alarms = alarms
        )
    }
}
