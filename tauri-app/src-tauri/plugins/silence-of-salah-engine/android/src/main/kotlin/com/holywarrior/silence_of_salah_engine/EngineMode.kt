package com.holywarrior.silence_of_salah_engine

/**
 * How the engine decides when to silence the phone.
 *
 * The two working modes are deliberately exclusive rather than additive. They
 * silence the phone through the same persisted [EnginePersistentState], so
 * letting both run at once would mean two owners racing over
 * `audioState`/`originalRingerMode` - one restoring the ringer the other just
 * changed. Switching modes therefore tears the outgoing one down completely
 * (see `EngineNativeActions.setEngineMode`).
 *
 * - [ML] is the original behaviour: a wake alarm starts the foreground service,
 *   the service samples the motion sensors and the model decides. Accurate when
 *   it works, but it can miss a prayer entirely or silence the phone when you
 *   were only sitting still.
 * - [MANUAL] is purely clock-driven: silence at a given time, restore after a
 *   fixed window. No sensors, no model, no foreground service - it cannot
 *   misfire, but it also cannot adapt if you pray early or late.
 * - [DISABLED] arms nothing. Configuration for both modes is kept, so turning a
 *   mode back on does not require the app to re-send its schedule.
 */
enum class EngineMode {
    DISABLED,
    MANUAL,
    ML;

    /** Lowercase form used on the wire (Rust `EngineMode`, JS `"disabled" | "manual" | "ml"`). */
    fun wire(): String = name.lowercase()

    companion object {
        /**
         * Defaults to [ML] rather than [DISABLED] on purpose: an app built
         * against an older version of this plugin never sets a mode, and ML is
         * exactly what it used to get. Anything else would silently break those
         * callers the moment they upgraded.
         */
        val DEFAULT = ML

        fun fromWire(value: String?): EngineMode {
            if (value.isNullOrBlank()) return DEFAULT
            return values().firstOrNull { it.name.equals(value, ignoreCase = true) }
                ?: throw IllegalArgumentException(
                    "Unknown engine mode \"$value\". Expected one of: ${values().joinToString(", ") { it.wire() }}."
                )
        }
    }
}
