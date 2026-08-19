# Auto Silent

Silences the phone while you pray, and puts the ringer back afterwards. It is the app's front end
for the vendored `tauri-plugin-silence-of-salah-engine` — see
[`backend-api.md`](backend-api.md#tauri-plugin-silence-of-salah-engine-android-only-localvendored)
for the plugin's own contract.

Source: [`src/lib/features/auto-silent/`](../src/lib/features/auto-silent/)

## How it actually works

The engine does not predict prayer, it *recognises* it. A foreground service samples the
accelerometer, gyroscope and magnetometer in a 100 ms loop, runs each window through a small
on-device XGBoost model, and feeds the verdicts into a five-value rolling buffer with deliberate
hysteresis:

- **Going silent** needs *all five* recent verdicts to be `true` the first time in a session, and
  *any* `true` after that. The first transition is conservative on purpose; later ones are
  responsive, because by then you have demonstrably been praying.
- **Coming back** happens when *none* of the five are `true`. The engine then sets a ten-minute
  shutdown deadline rather than restoring immediately, so a pause between rakats does not
  un-silence the phone. A single `true` before the deadline cancels it.

Because it recognises movement rather than predicting it, **the service has to already be running
when you start praying.** That is what the alarms are for.

## The scheduling chain

1. `AutoSilentPage` fetches today's prayer times through the existing
   `prayerTimesService.day(...)` — the same Aladhan call and the same cache the Prayer Times tab
   uses, so the two features never disagree about when Asr is.
2. `planWakes(day, settings)` computes, for each enabled prayer,
   `wakeAt = prayerTime + offset − leadMinutes`.
3. `alarmsFor(wakes)` turns that into the plugin's alarm shape, and `scheduleDailyAlarms` writes
   the whole list natively.
4. The plugin's own `AlarmManager` entries fire at those times and start the service. Its
   `BOOT_COMPLETED` receiver re-arms them after a reboot, so nothing in the app has to.

Alarms are a bare hour and minute repeating daily, which means prayer times drifting by a minute
or two need re-syncing — that happens whenever the page loads or the plan changes.

## Offsets, and why they don't touch Prayer Times

A calculated prayer time is when the window *opens*, which is rarely the minute anyone actually
starts. The Flutter version of this app solved that by sending Aladhan a `tune` parameter, so the
offsets shifted the displayed times too — its default shipped Dhuhr at +60 minutes, meaning the
times the app showed you were an hour off the calculated ones.

This version deliberately does not do that. Offsets live in Auto Silent's own settings and move
only when the engine wakes; the Prayer Times tab keeps showing the calculated times unchanged.
People read prayer times as authoritative, and quietly shifting them to suit a phone setting is
not a trade worth making. The offsets editor says so directly.

Offsets cover the five fard prayers only. Sunrise is a boundary rather than a prayer, and
Tahajjud is voluntary and falls at an hour where silencing the phone unasked would be its own
problem.

## Permissions

Four, all owned by the plugin, all required before anything is scheduled:

| Permission | Why it is needed |
| --- | --- |
| Notifications | Android requires a visible notification for any background service |
| Exact alarms | Otherwise the wake time is "sometime around then" |
| Do Not Disturb access | Without it Android refuses to let the app change the ringer at all |
| Unrestricted battery | Stops Android killing the engine mid-prayer |

Each request opens a system settings screen and resolves immediately — Android never reports the
user's answer back. The page therefore re-polls `get_permission_status` on `visibilitychange`,
which is the only reliable moment to notice a grant. The master toggle stays disabled until
`allGranted` is true.

## What this version has that the Flutter one didn't

- **A manual stop.** The Flutter app never called `stopNativeTask` from anywhere, so a stuck
  detection could only be cleared by force-stopping the app or waiting out the 45-minute wakelock
  timeout. "End now" is on the status card whenever the service is running.
- **A way to test it.** "Check it works" uses the plugin's debug commands to force the ringer
  silent and back, proving the DND/ringer chain in seconds instead of requiring a real prayer.
- **A configurable lead time.** Flutter hardcoded three minutes; here it is 0–30.
- **Live status.** The Flutter UI showed one read-only "service running: true/false" row. This
  shows phase, which prayer it likely woke for, and the restore countdown.

## The time-based mode the plugin now offers

Everything above describes ML mode, which is what this page currently drives. The plugin also
supports a second, clock-only mode, and the app does not use it yet.

`set_engine_mode` chooses between `disabled`, `manual` and `ml`. In `manual` mode the plugin
takes a list of silence windows — a start time and a duration each — and silences the phone for
exactly that period, with no sensors, no model and no foreground service. Two exact alarms per
window is the whole mechanism.

It exists because detection is the weakest part of this feature. The model can miss a prayer
outright, and no amount of UI honesty makes that acceptable as someone's only option. A window
that is merely approximate still beats one that does not fire. The trade is the obvious one:
manual mode silences the phone whether or not anyone is praying, and it stops on schedule whether
or not they have finished.

The window start is a resolved wall-clock time, offset already applied — the same division of
labour the wake alarms already use, because the plugin has no location and no calendar and cannot
compute prayer times itself. So the offsets editor described above is exactly the input manual
mode needs; a duration per prayer is the only new thing to collect.

Both schedules survive a mode switch, so the app can send its windows once and let the user flip
between modes without rebuilding anything.

The switch itself needs a prompt in the UI. Tearing the outgoing mode down restores the ringer,
and doing that while the engine has the phone silent would make it ring mid-prayer — the exact
failure this feature exists to prevent. So `setEngineMode` defaults to refusing while a session
is running and hands back what blocked it (`activeSession`, with a `silencing` flag and, in
manual mode, the prayer's name). The page should turn that into a choice — switch now, or switch
when this prayer finishes — and send the answer back as `"immediate"` or `"afterCurrentSession"`.
A deferred switch is the plugin's problem from then on: it is persisted and applied by whichever
path ends the session, with no further involvement from the app.

See
[`backend-api.md`](backend-api.md#tauri-plugin-silence-of-salah-engine-android-only-localvendored)
for the command list and the restore guarantees.

## Known limitations

- **Android only.** Every command rejects elsewhere; the page detects that on its first call and
  switches to an honest "Android only" state rather than showing an error.
- **The engine reports no events.** Status is polled every three seconds while the page is open,
  so the UI can lag reality by up to that long, and does not update at all in the background.
- **Which prayer it woke for is a guess.** The plugin does not report what started the service,
  so `likelyPrayerLabel()` infers it from whichever alarm most recently passed. It is used as a
  label only — nothing behavioural depends on it.
- **Detection is imperfect.** It can miss a prayer, or silence the phone when you were only
  sitting still. The page says this in plain words rather than implying reliability it does not
  have. The plugin's time-based mode is the answer to this, and is not wired into the page yet.

## The effect wiring, and one trap in it

`syncAlarms()` both reads `status` (to compare against what is already scheduled) and writes it
(via `refreshStatus()` afterwards). Driving it from an effect that tracks those reads would mean
every three-second status poll re-entered scheduling — and if the native side ever normalised a
plan even slightly differently from what was sent, `alarmsMatch` would never be satisfied and the
app would rewrite five alarms forever.

So the effect depends on exactly one thing: a derived `planSignature` string covering the enabled
flag, the granted flag and the computed alarm list. The call itself is wrapped in `untrack()`.

## Never trust the plugin's alarm list

`getNativeStatus().scheduledAlarms` is the plugin's own persisted record of what it once
scheduled. It is **not** a live query of `AlarmManager`, and the two drift apart: Android silently
cancels every one of an app's alarms when the app is force-stopped, and the plugin's record knows
nothing about it.

`syncAlarms()` originally compared the plan against that record and skipped the write when they
matched. On a device this produced the worst possible failure — after a force-stop, `AlarmManager`
held zero alarms, the record still claimed five, the comparison passed, nothing was rewritten, and
the page reported "Ready. Next listening for Dhuhr at 12:15 PM" for a feature that could never
fire.

The fix is to always write. Re-arming five exact alarms is free, `planSignature` already prevents
it running on every render, and writing unconditionally makes the feature self-healing: opening
the page is enough to recover from a force-stop, a crash, or anything else that clears alarms.
Confirmed by force-stopping the app, watching `dumpsys alarm` drop to zero, and seeing all five
come back on reopening the page.

## Two errors, not one

`error` and `actionError` are deliberately separate. The first belongs to the three-second status
poll and is cleared whenever a poll succeeds; the second belongs to a button the user just pressed.

They started out as one string, and the result was found on a real device: tapping "Silence now"
without Do Not Disturb access threw `SecurityException: Not allowed to change Do Not Disturb
state`, the catch stored it, and then `run()`'s own `finally` called `refreshStatus()`, which
succeeded and immediately set `error = ""`. The failure erased itself within milliseconds. On the
phone it looked exactly like the button doing nothing at all.

The same fix has a second half: the surviving message is rendered *inside* the "Check it works"
card, next to the button that produced it, rather than in the banner at the top of the page. On a
phone that banner is well over a screen away from the buttons, so even a correctly-stored error
would have gone unread.

And because Android's own wording for that failure explains nothing, `explain()` rewrites just
that one case into something actionable, naming the permission and where to grant it. Every other
message is passed through untouched rather than guessed at.
