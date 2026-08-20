package com.holywarrior.silence_of_salah_engine.task

import java.util.ArrayDeque

/**
 * Fixed-size rolling buffer for sensor magnitudes.
 * Stores ACC, GYR, MAG values separately but allows flattened output.
 *
 * Now supports overlapping windows by removing a portion of old data.
 */
class SensorBuffer(private val windowSize: Int = 150) {

    private val accBuffer = ArrayDeque<Float>(windowSize)
    private val gyrBuffer = ArrayDeque<Float>(windowSize)
    private val magBuffer = ArrayDeque<Float>(windowSize)

    @Synchronized
    fun addSample(acc: Float, gyr: Float, mag: Float) {
        accBuffer.addLast(acc)
        gyrBuffer.addLast(gyr)
        magBuffer.addLast(mag)

        // Trim oldest if over capacity
        if (accBuffer.size > windowSize) accBuffer.removeFirst()
        if (gyrBuffer.size > windowSize) gyrBuffer.removeFirst()
        if (magBuffer.size > windowSize) magBuffer.removeFirst()
    }

    @Synchronized
    fun isFull(): Boolean {
        return accBuffer.size == windowSize &&
               gyrBuffer.size == windowSize &&
               magBuffer.size == windowSize
    }

    /**
     * Remove a portion of oldest samples to allow overlapping windows.
     *
     * @param ratio Fraction of current buffer size to remove (default 0.5 = 50%)
     */
    @Synchronized
    fun pop(ratio: Float = 0.5f) {
        require(ratio in 0f..1f) { "Ratio must be between 0 and 1" }

        val currentSize = accBuffer.size
        val removeCount = (currentSize * ratio).toInt()

        repeat(removeCount) {
            if (accBuffer.isNotEmpty()) accBuffer.removeFirst()
            if (gyrBuffer.isNotEmpty()) gyrBuffer.removeFirst()
            if (magBuffer.isNotEmpty()) magBuffer.removeFirst()
        }
    }

    /**
     * Convenience method for 50% overlap
     */
    @Synchronized
    fun popHalf() {
        pop(0.5f)
    }

    /**
     * Flatten buffers into a single FloatArray for ML inference:
     * [ACC[0..N-1], GYR[0..N-1], MAG[0..N-1]]
     */
    @Synchronized
    fun toFlatArray(): FloatArray {
        val flat = FloatArray(windowSize * 3)
        var index = 0

        accBuffer.forEach { flat[index++] = it }
        gyrBuffer.forEach { flat[index++] = it }
        magBuffer.forEach { flat[index++] = it }

        return flat
    }

    @Synchronized
    fun clear() {
        accBuffer.clear()
        gyrBuffer.clear()
        magBuffer.clear()
    }
}