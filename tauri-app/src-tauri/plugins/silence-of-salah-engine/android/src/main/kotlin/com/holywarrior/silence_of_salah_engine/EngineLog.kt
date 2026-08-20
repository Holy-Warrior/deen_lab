package com.holywarrior.silence_of_salah_engine

import android.util.Log

object EngineLog {
    private const val TAG = "SilenceEngine"

    fun d(component: String, message: String) {
        Log.d(TAG, "[$component] $message")
    }

    fun i(component: String, message: String) {
        Log.i(TAG, "[$component] $message")
    }

    fun w(component: String, message: String) {
        Log.w(TAG, "[$component] $message")
    }

    fun e(component: String, message: String, throwable: Throwable? = null) {
        Log.e(TAG, "[$component] $message", throwable)
    }
}
