package com.holywarrior.silence_of_salah_engine.sensors

import android.content.Context
import android.hardware.*
import com.holywarrior.silence_of_salah_engine.EngineLog
import kotlin.math.sqrt

// Enum representing available sensors
enum class SensorType {
    ACCELEROMETER,
    GYROSCOPE,
    MAGNETOMETER
}

// Singleton sensor manager
object SensorsManager : SensorEventListener {
    private const val COMPONENT = "Sensors"

    private lateinit var sensorManager: SensorManager

    // Cache latest sensor values
    private val latestValues = mutableMapOf<SensorType, FloatArray>()
    private val sensors = mutableMapOf<SensorType, Sensor>()

    private var isListening = false

    /**
     * Initialize sensors
     */
    fun initialize(context: Context) {
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

        SensorType.values().forEach { type ->
            getSensor(type)?.let { sensors[type] = it }
        }
    }

    /**
     * Start listening to sensors
     */
    fun start() {
        if (isListening) return

        sensors.forEach { (_, sensor) ->
            sensorManager.registerListener(
                this,
                sensor,
                SensorManager.SENSOR_DELAY_GAME
            )
        }

        isListening = true
        EngineLog.d(COMPONENT, "Sensors started with SENSOR_DELAY_GAME.")
    }

    /**
     * Stop listening to sensors
     */
    fun stop() {
        if (!isListening) return
        sensorManager.unregisterListener(this)
        latestValues.values.forEach { values -> values.fill(0f) }
        isListening = false
        EngineLog.d(COMPONENT, "Sensors stopped and cached values cleared.")
    }

    /**
     * Get latest magnitudes snapshot
     */
    fun getLatestMagnitudes(): Triple<Float, Float, Float> {
        val acc = latestValues[SensorType.ACCELEROMETER]?.let { magnitude(it) } ?: 0f
        val gyr = latestValues[SensorType.GYROSCOPE]?.let { magnitude(it) } ?: 0f
        val mag = latestValues[SensorType.MAGNETOMETER]?.let { magnitude(it) } ?: 0f

        return Triple(acc, gyr, mag)
    }

    /**
     * Calculate magnitude of a 3D vector
     */
    private fun magnitude(values: FloatArray): Float {
        return sqrt(
            values[0] * values[0] +
            values[1] * values[1] +
            values[2] * values[2]
        )
    }

    private fun getSensor(sensorType: SensorType): Sensor? {
        return when (sensorType) {
            SensorType.ACCELEROMETER -> sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            SensorType.GYROSCOPE -> sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
            SensorType.MAGNETOMETER -> sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        val type = when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> SensorType.ACCELEROMETER
            Sensor.TYPE_GYROSCOPE -> SensorType.GYROSCOPE
            Sensor.TYPE_MAGNETIC_FIELD -> SensorType.MAGNETOMETER
            else -> null
        }

        type?.let {
            val target = latestValues.getOrPut(it) { FloatArray(event.values.size) }
            val copyLength = minOf(target.size, event.values.size)
            for (index in 0 until copyLength) {
                target[index] = event.values[index]
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
