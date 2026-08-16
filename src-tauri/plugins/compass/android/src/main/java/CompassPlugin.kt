package com.deenlab.compass

import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.webkit.WebView
import app.tauri.annotation.Command
import app.tauri.annotation.InvokeArg
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Channel
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin

@InvokeArg
class StartArgs {
    lateinit var channel: Channel
}

// design: no @TauriPlugin permissions block -- TYPE_ACCELEROMETER/TYPE_MAGNETIC_FIELD/
// TYPE_GYROSCOPE are all "normal" motion sensors on Android, not the dangerous BODY_SENSORS
// permission group, so there's nothing to request.
@TauriPlugin
class CompassPlugin(private val activity: Activity) : Plugin(activity), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var magnetometer: Sensor? = null
    private var gyroscope: Sensor? = null

    private var channel: Channel? = null
    private var mode = MODE_NONE

    private val gravity = FloatArray(3)
    private val geomagnetic = FloatArray(3)
    private var hasGravity = false
    private var hasGeomagnetic = false

    // design: without a magnetometer there's no absolute reference to anchor to -- instead,
    // integrate the gyroscope's vertical-axis angular velocity into a running heading that
    // starts at 0 the moment `start` is called. This tracks how far the phone has *physically
    // turned* since then accurately (gyroscopes are precise over short spans, just drift over
    // long ones), it just isn't anchored to true north the way the real sensor reading is.
    // The front-end seeds its initial needle angle from the GPS-computed static bearing either
    // way, so a fresh `start` always begins at the same place a real compass would.
    private var gyroHeadingDegrees = 0f
    private var lastGyroTimestampNs = 0L

    override fun load(webView: WebView) {
        super.load(webView)
        sensorManager = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        magnetometer = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
    }

    override fun onPause() {
        super.onPause()
        sensorManager.unregisterListener(this)
    }

    override fun onResume() {
        super.onResume()
        if (channel != null) registerListenersForMode()
    }

    @Command
    fun start(invoke: Invoke) {
        val args = invoke.parseArgs(StartArgs::class.java)
        channel = args.channel
        hasGravity = false
        hasGeomagnetic = false
        gyroHeadingDegrees = 0f
        lastGyroTimestampNs = 0L
        mode = availableMode()
        registerListenersForMode()

        val result = JSObject()
        result.put("mode", mode)
        invoke.resolve(result)
    }

    @Command
    fun stop(invoke: Invoke) {
        sensorManager.unregisterListener(this)
        channel = null
        mode = MODE_NONE
        invoke.resolve()
    }

    private fun availableMode(): String = when {
        accelerometer != null && magnetometer != null -> MODE_SENSOR
        gyroscope != null -> MODE_GYROSCOPE
        else -> MODE_NONE
    }

    private fun registerListenersForMode() {
        when (mode) {
            MODE_SENSOR -> {
                sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI)
                sensorManager.registerListener(this, magnetometer, SensorManager.SENSOR_DELAY_UI)
            }
            MODE_GYROSCOPE -> {
                sensorManager.registerListener(this, gyroscope, SensorManager.SENSOR_DELAY_UI)
            }
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                System.arraycopy(event.values, 0, gravity, 0, 3)
                hasGravity = true
                emitFusedHeading()
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                System.arraycopy(event.values, 0, geomagnetic, 0, 3)
                hasGeomagnetic = true
                emitFusedHeading()
            }
            Sensor.TYPE_GYROSCOPE -> emitGyroHeading(event)
        }
    }

    // tauri: SensorManager.getRotationMatrix + getOrientation is the standard Android recipe
    // for "the compass sensor" -- it fuses the accelerometer (which way is down) with the
    // magnetometer (which way is magnetic north) since the magnetometer alone can't tell
    // heading unless the phone is held perfectly flat.
    private fun emitFusedHeading() {
        if (!hasGravity || !hasGeomagnetic) return

        val rotationMatrix = FloatArray(9)
        val orientation = FloatArray(3)
        if (!SensorManager.getRotationMatrix(rotationMatrix, null, gravity, geomagnetic)) return

        SensorManager.getOrientation(rotationMatrix, orientation)
        val azimuth = (Math.toDegrees(orientation[0].toDouble()).toFloat() + 360f) % 360f
        send(azimuth, absolute = true)
    }

    private fun emitGyroHeading(event: SensorEvent) {
        if (lastGyroTimestampNs != 0L) {
            val dtSeconds = (event.timestamp - lastGyroTimestampNs) / 1_000_000_000f
            // event.values[2] is angular velocity (rad/s) around the device's own Z axis --
            // the vertical axis when held flat like a real compass, same pose the fused-sensor
            // mode above expects. Integrating it over time gives the heading change since start.
            val degreesTurned = Math.toDegrees(event.values[2].toDouble()).toFloat() * dtSeconds
            gyroHeadingDegrees = (gyroHeadingDegrees - degreesTurned + 360f) % 360f
            send(gyroHeadingDegrees, absolute = false)
        }
        lastGyroTimestampNs = event.timestamp
    }

    private fun send(degrees: Float, absolute: Boolean) {
        val payload = JSObject()
        payload.put("degrees", degrees.toDouble())
        payload.put("absolute", absolute)
        channel?.send(payload)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    companion object {
        private const val MODE_SENSOR = "sensor"
        private const val MODE_GYROSCOPE = "gyroscope"
        private const val MODE_NONE = "none"
    }
}
