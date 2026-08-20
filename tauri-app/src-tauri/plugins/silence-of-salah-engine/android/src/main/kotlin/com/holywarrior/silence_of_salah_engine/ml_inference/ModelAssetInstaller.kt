package com.holywarrior.silence_of_salah_engine.ml_inference

import android.content.Context
import android.util.Log
import java.io.File

object ModelAssetInstaller {

    private const val TAG = "ModelAssetInstaller"
    private const val NATIVE_ASSET_PATH = "models/model_100ms_xgb_native.json"
    private const val NATIVE_FILE_NAME = "model_100ms_xgb_native.json"

    @Volatile
    var installedModelPath: String? = null
        private set

    @Volatile
    var installedNativeModelPath: String? = null
        private set

    fun ensureInstalled(context: Context): String {
        val targetDir = File(context.filesDir, "silence_of_salah_engine")
        if (!targetDir.exists()) {
            targetDir.mkdirs()
        }

        val nativeTargetFile = File(targetDir, NATIVE_FILE_NAME)
        installAsset(context, NATIVE_ASSET_PATH, nativeTargetFile)
        installedNativeModelPath = nativeTargetFile.absolutePath
        installedModelPath = null

        return nativeTargetFile.absolutePath
    }

    fun loadModel(modelPath: String): Boolean {
        val loaded = XGBoostInference.loadSafely(modelPath)
        if (!loaded) {
            Log.e(TAG, "Failed to load model from $modelPath")
        }
        return loaded
    }

    private fun installAsset(context: Context, assetPath: String, targetFile: File) {
        val assetBytes = context.assets.open(assetPath).use { it.readBytes() }
        val shouldWrite = !targetFile.exists() || targetFile.length() != assetBytes.size.toLong()
        if (shouldWrite) {
            targetFile.outputStream().use { it.write(assetBytes) }
            Log.d(TAG, "Installed asset $assetPath at ${targetFile.absolutePath}")
        }
    }
}
