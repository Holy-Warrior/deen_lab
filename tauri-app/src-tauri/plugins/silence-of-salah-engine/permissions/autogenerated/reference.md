## Default Permission

Allows the core lifecycle of the silence-of-salah-engine plugin: starting
and stopping the foreground service, reading its status, managing daily
alarms, and driving the native permission-request flows.

Does NOT include the `debug-*` commands (`trigger_ml_processing`,
`submit_ml_decision_output`, `debug_set_audio_silent`,
`debug_restore_audio_default`) - add the `silence-of-salah-engine:debug`
permission set separately if your app's UI needs them (see the example app
in the original repo for a debug-only screen that does).

#### This default permission set includes the following:

- `allow-get-platform-version`
- `allow-start-native-task`
- `allow-stop-native-task`
- `allow-get-native-status`
- `allow-schedule-daily-alarms`
- `allow-get-scheduled-alarms`
- `allow-cancel-all-alarms`
- `allow-get-permission-status`
- `allow-request-exact-alarm-permission`
- `allow-request-dnd-access`
- `allow-request-battery-optimization`
- `allow-request-notification-permission`

## Permission Table

<table>
<tr>
<th>Identifier</th>
<th>Description</th>
</tr>


<tr>
<td>

`silence-of-salah-engine:allow-cancel-all-alarms`

</td>
<td>

Enables the cancel_all_alarms command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-cancel-all-alarms`

</td>
<td>

Denies the cancel_all_alarms command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-debug-restore-audio-default`

</td>
<td>

Enables the debug_restore_audio_default command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-debug-restore-audio-default`

</td>
<td>

Denies the debug_restore_audio_default command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-debug-set-audio-silent`

</td>
<td>

Enables the debug_set_audio_silent command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-debug-set-audio-silent`

</td>
<td>

Denies the debug_set_audio_silent command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-get-native-status`

</td>
<td>

Enables the get_native_status command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-get-native-status`

</td>
<td>

Denies the get_native_status command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-get-permission-status`

</td>
<td>

Enables the get_permission_status command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-get-permission-status`

</td>
<td>

Denies the get_permission_status command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-get-platform-version`

</td>
<td>

Enables the get_platform_version command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-get-platform-version`

</td>
<td>

Denies the get_platform_version command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-get-scheduled-alarms`

</td>
<td>

Enables the get_scheduled_alarms command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-get-scheduled-alarms`

</td>
<td>

Denies the get_scheduled_alarms command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-request-battery-optimization`

</td>
<td>

Enables the request_battery_optimization command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-request-battery-optimization`

</td>
<td>

Denies the request_battery_optimization command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-request-dnd-access`

</td>
<td>

Enables the request_dnd_access command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-request-dnd-access`

</td>
<td>

Denies the request_dnd_access command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-request-exact-alarm-permission`

</td>
<td>

Enables the request_exact_alarm_permission command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-request-exact-alarm-permission`

</td>
<td>

Denies the request_exact_alarm_permission command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-request-notification-permission`

</td>
<td>

Enables the request_notification_permission command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-request-notification-permission`

</td>
<td>

Denies the request_notification_permission command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-schedule-daily-alarms`

</td>
<td>

Enables the schedule_daily_alarms command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-schedule-daily-alarms`

</td>
<td>

Denies the schedule_daily_alarms command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-start-native-task`

</td>
<td>

Enables the start_native_task command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-start-native-task`

</td>
<td>

Denies the start_native_task command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-stop-native-task`

</td>
<td>

Enables the stop_native_task command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-stop-native-task`

</td>
<td>

Denies the stop_native_task command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-submit-ml-decision-output`

</td>
<td>

Enables the submit_ml_decision_output command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-submit-ml-decision-output`

</td>
<td>

Denies the submit_ml_decision_output command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:allow-trigger-ml-processing`

</td>
<td>

Enables the trigger_ml_processing command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:deny-trigger-ml-processing`

</td>
<td>

Denies the trigger_ml_processing command without any pre-configured scope.

</td>
</tr>

<tr>
<td>

`silence-of-salah-engine:debug`

</td>
<td>

Allows the debug-only commands: running the ML model directly
(`trigger_ml_processing`), feeding a manual prediction into the decision
engine (`submit_ml_decision_output`), and forcing the ringer mode without
going through the decision engine (`debug_set_audio_silent`,
`debug_restore_audio_default`). Mirrors the "ML Debug" / "Audio Debug"
sections of the original plugin's example app.


</td>
</tr>
</table>
