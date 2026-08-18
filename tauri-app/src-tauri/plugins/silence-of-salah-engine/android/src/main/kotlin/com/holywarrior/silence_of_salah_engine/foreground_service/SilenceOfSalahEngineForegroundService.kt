package com.holywarrior.silence_of_salah_engine.foreground_service

import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import com.holywarrior.silence_of_salah_engine.Config
import com.holywarrior.silence_of_salah_engine.EngineLog
import com.holywarrior.silence_of_salah_engine.ml_inference.ModelAssetInstaller
import com.holywarrior.silence_of_salah_engine.sensors.SensorsManager
import com.holywarrior.silence_of_salah_engine.task.Task
import com.holywarrior.silence_of_salah_engine.task.TaskStateController

class SilenceOfSalahEngineForegroundService : Service() {
    private var controller: ForegroundTaskController? = null
    private lateinit var notificationController: NotificationController

    override fun onCreate() {
        super.onCreate()
        EngineLog.i(TAG, "onCreate")

        NotificationHelper.createChannel(this)
        notificationController = NotificationController(this)
        startForeground(Config.NOTIFICATION_ID, notificationController.build())

        SensorsManager.initialize(applicationContext)
        val modelPath = ModelAssetInstaller.ensureInstalled(applicationContext)
        val loaded = ModelAssetInstaller.loadModel(modelPath)
        EngineLog.i(TAG, "Model load completed. loaded=$loaded path=$modelPath")
        notificationController
            .setTitle(Config.NOTIFICATION_TITLE)
            .setText(Config.NOTIFICATION_TEXT_RUNNING)
            .update()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: Config.ACTION_START
        val reason = intent?.getStringExtra(Config.EXTRA_START_REASON)
        EngineLog.i(TAG, "onStartCommand action=$action startId=$startId flags=$flags reason=$reason")

        when (action) {
            Config.ACTION_STOP, Config.ACTION_WAKELOCK_TIMEOUT -> {
                clearPendingStart()
                controller?.requestStop(reason ?: action)
                    ?: stopSelfSafely()
                return START_NOT_STICKY
            }
        }

        if (controller?.isActive() == true) {
            EngineLog.d(TAG, "Start request ignored because the task is already active.")
            return START_STICKY
        }

        val task = pendingTask ?: Task()
        val stateController = pendingStateController ?: TaskStateController(applicationContext)
        pendingTask = null
        pendingStateController = null

        val taskController = ForegroundTaskController(this, notificationController)
        controller = taskController
        taskController.acquireWakeLock()

        TaskRunner.start(
            controller = taskController,
            task = task,
            persistentController = stateController,
            isRecovery = intent?.getBooleanExtra(EXTRA_RECOVERY, false) == true
        )

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        EngineLog.i(TAG, "onTaskRemoved")
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        EngineLog.i(TAG, "onDestroy")
        controller?.handleServiceDestroy()
        controller = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    fun stopSelfSafely() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    companion object {
        private const val TAG = "Service"
        const val EXTRA_RECOVERY = "recovery"

        @Volatile
        private var taskActive: Boolean = false

        @JvmStatic
        internal var pendingTask: Task? = null

        @JvmStatic
        internal var pendingStateController: TaskStateController? = null

        @JvmStatic
        fun isTaskRunning(): Boolean = taskActive || pendingTask != null

        @JvmStatic
        fun setTaskActive(active: Boolean) {
            taskActive = active
        }

        @JvmStatic
        fun clearPendingStart() {
            pendingTask = null
            pendingStateController = null
            taskActive = false
        }
    }
}
