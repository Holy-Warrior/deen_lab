package com.holywarrior.silence_of_salah_engine.foreground_service

/**
 * Base class for creating a foreground task with lifecycle hooks and optional loop.
 *
 * @param T User-defined persistent state controller type
 */
abstract class BaseForegroundTask<T : Any> {

    /**
     * Called when the task starts normally.
     *
     * Use this function to initialize your task, setup resources, and start any initial operations.
     * This is **not called** if the task is recovered after an unexpected shutdown; in that case, [onRecover] is called instead.
     */
    abstract suspend fun onStart(
        taskController: ForegroundTaskController,
        notificationController: NotificationController,
        stateController: T
    )

    /**
     * Called when the task is recovered after a system kill, crash, or modified OEM OS restart.
     *
     * This is **not called** during a normal task start; use [onStart] for that.
     * Use this function to restore state, reload resources, or resume interrupted operations.
     */
    open suspend fun onRecover(
        taskController: ForegroundTaskController,
        notificationController: NotificationController,
        stateController: T
    ) { }

    /**
     * Called when the task is being destroyed, for cleanup.
     *
     * This function runs **before** wakelocks, notification, and other top-level resources are released.
     * Use this to save state, close files, stop services, and gracefully end operations.
     *
     * It is invoked when [ForegroundTaskController.stopTask] is called or the service is being stopped.
     */
    open suspend fun onDestroy(
        taskController: ForegroundTaskController,
        notificationController: NotificationController,
        stateController: T
    ) { }

    /**
     * Called periodically if the loop is enabled (loopIntervalMillis > 0).
     *
     * Use this function to perform repeated operations like updating notifications,
     * polling, or periodic background work.
     *
     * The loop automatically stops if the task is cancelled via [ForegroundTaskController.stopTask].
     */
    open suspend fun onLoop(
        taskController: ForegroundTaskController,
        notificationController: NotificationController,
        stateController: T
    ) { }

    /**
     * Interval in milliseconds for the optional loop.
     *
     * Default is 0, which disables the loop. Override to enable periodic execution.
     */
    open val loopIntervalMillis: Long = 0
}