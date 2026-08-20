# Auto Silent

Silences the phone while you pray, and puts the ringer back afterwards, either by recognising
salah from movement or by the clock alone. It is the app's front end
for the vendored `tauri-plugin-silence-of-salah-engine` — see
[`backend-api.md`](backend-api.md#tauri-plugin-silence-of-salah-engine-android-only-localvendored)
for the plugin's own contract.

Source: [`src/lib/features/auto-silent/`](../src/lib/features/auto-silent/)

## Two modes, and why there are two

The page is a three-way choice — **Off**, **By time**, **Detection** — and the mode itself is
never stored here. The plugin keeps it in its own state file and acts on it while the app is
closed: alarms fire, the boot receiver re-arms, a deferred switch lands when a prayer ends. A
second copy in `localStorage` could only drift out of step with the thing actually doing the
work, so `status.mode` is read as the source of truth and `settings` holds only what the plugin
does not know about — which prayers, the lead time, the offsets, the durations.

There is nothing to hand over on first run, either. The plugin's own default mode is `disabled`,
which is the same thing the page shows while the first status read is still in flight, so a fresh
install starts off and stays off until someone picks a mode. That agreement is deliberate: it is
what lets scheduling begin immediately instead of waiting on a handshake.

| | Detection | By time |
| --- | --- | --- |
| Decides with | Motion sensors and the model | The clock |
| Costs | A foreground service and a wakelock while listening | Two exact alarms per window; nothing runs between them |
| Gets it wrong by | Missing a prayer, or silencing you for sitting still | Silencing you when you were not praying, or ending before you finished |

Time mode exists because detection is the weakest part of this feature, and no amount of honest
UI copy makes "it might just not fire" acceptable as someone's only option.

## How detection works

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
2. Each mode plans from that, per enabled prayer:
   - **Detection** — `planWakes` computes `wakeAt = prayerTime + offset − leadMinutes`, and
     `alarmsFor` turns it into the plugin's alarm shape.
   - **By time** — `planWindows` computes `startAt = prayerTime + offset` and
     `endAt = startAt + duration`, and `windowsFor` turns it into the plugin's window shape.
3. `scheduleDailyAlarms` / `scheduleManualWindows` writes the whole list natively.
4. The plugin's own `AlarmManager` entries fire at those times. Its `BOOT_COMPLETED` receiver
   re-arms them after a reboot, so nothing in the app has to.

`leadMinutes` deliberately plays no part in time mode. It exists in detection mode because the
service has to already be running before you start moving; a clock-driven window has nothing to
warm up, so starting it early would only be silence while you are not yet praying. The offset
alone positions the window, which makes it the "when do I actually start" knob in both modes.

Ids are per prayer and shared between the two plans, so switching modes reuses the same id for
the same prayer rather than leaving a stale entry behind under a different number.

Both are a bare hour and minute repeating daily, which means prayer times drifting by a minute
or two need re-syncing — that happens whenever the page loads or the plan changes. Only the
active mode's plan is pushed, plus a queued mode's if there is one: a queued switch arms itself
from whatever the plugin has stored, and for a mode the user has never used that would be
nothing at all.

## Switching modes without ending a prayer

Switching tears the outgoing mode down, and if that mode is holding the ringer silent at the
time, tearing it down turns the ringer back on — possibly mid-prayer, which is the exact failure
this feature exists to prevent.

So `setEngineMode` is called with the default `ifIdle` policy, which refuses while a session is
running and hands back the session that blocked it. The page turns that into `ModeSwitchDialog`:
*switch when this finishes* (`afterCurrentSession`) or *switch now* (`immediate`), with the safe
option first and visually primary. The wording turns on the session's `silencing` flag rather
than on which mode owns it — "your phone is silent right now" is the fact that makes switching a
bad idea; whether a model or a clock decided it is not something the user needs to think about at
that moment.

A queued switch shows as a dashed outline on the mode chip plus a line of text, because otherwise
the tap that queued it looks exactly like a tap that did not register. Re-picking the mode already
running cancels it — that is the plugin's own rule, so `chooseMode` deliberately does *not*
short-circuit when the tapped mode is already active.

`start_native_task` rejects outside detection mode, so the "Start detecting now" button only
exists there rather than being rendered and then failing.

## Offsets, and why they don't touch Prayer Times

A calculated prayer time is when the window *opens*, which is rarely the minute anyone actually
starts. The Flutter version of this app solved that by sending Aladhan a `tune` parameter, so the
offsets shifted the displayed times too — its default shipped Dhuhr at +60 minutes, meaning the
times the app showed you were an hour off the calculated ones.

This version deliberately does not do that. Offsets live in Auto Silent's own settings and move
only when the engine acts -- when it starts listening, or when it goes silent -- while the
Prayer Times tab keeps showing the calculated times unchanged.
People read prayer times as authoritative, and quietly shifting them to suit a phone setting is
not a trade worth making. The timings editor says so directly.

Offsets cover the five fard prayers only. Sunrise is a boundary rather than a prayer, and
Tahajjud is voluntary and falls at an hour where silencing the phone unasked would be its own
problem.

Durations default to 25 minutes: long enough for a fard prayer with its sunnah and a
congregation, short enough that a phone left silent by a prayer you skipped is not silent for the
rest of the hour. Erring long is the safer direction — ending early means the phone rings
mid-prayer — but only slightly, since every minute of it is a minute of missed calls.

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

See
[`backend-api.md`](backend-api.md#tauri-plugin-silence-of-salah-engine-android-only-localvendored)
for the full command list and the plugin's restore guarantees.

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
  have, and time mode is the answer for anyone who would rather not gamble.
- **Time mode does not adapt.** It silences on the clock whether or not you are praying, and
  stops when the window is up whether or not you have finished. The page says that too — the
  closing paragraph swaps to match the active mode rather than describing both at once.

## The effect wiring, and one trap in it

`syncSchedule()` both reads `status` (to compare against what is already scheduled) and writes it
(via `refreshStatus()` afterwards). Driving it from an effect that tracks those reads would mean
every three-second status poll re-entered scheduling — and if the native side ever normalised a
plan even slightly differently from what was sent, the comparison that used to guard the write
would never be satisfied and the app would rewrite the whole list forever.

So the effect depends on exactly one thing: a derived `planSignature` string covering the active
mode, any queued mode, the granted flag and the computed plan. The call itself is wrapped in
`untrack()`.

The signature is also what keeps the mode out of local state from becoming a loop. `mode` is
derived from `status`, and `syncSchedule` writes `status` — but a three-second poll that returns
the same mode produces the same signature, so `lastSynced` short-circuits it.

## The two defaults have to agree

For a while the plugin defaulted to detection mode and the page defaulted to off, and the gap
between them was a real bug. The first status read came back reporting detection, which was
enough for the sync effect to fire and arm five wake alarms — a beat before the page could tell
the plugin to switch off. A fresh profile ended up with a state file reporting `mode: disabled`
and five ML alarms sitting inside it, plus five live entries in `dumpsys alarm`: a feature that
had armed itself before anyone asked.

The first fix was a `ready` flag gating `syncSchedule` until the handshake finished. The better
one was to remove the disagreement: the plugin now defaults to `disabled` too, so there is no
window in which the page believes a working mode is active. Re-tested from a wiped profile:
`mode: disabled`, `alarms: []`, and nothing in `dumpsys alarm`.

The general point is worth keeping in mind for any future plugin state the page mirrors — a
default on one side of the bridge that differs from the default on the other is a bug waiting for
the right timing.

## Never trust the plugin's alarm list

`getNativeStatus().scheduledAlarms` is the plugin's own persisted record of what it once
scheduled. It is **not** a live query of `AlarmManager`, and the two drift apart: Android silently
cancels every one of an app's alarms when the app is force-stopped, and the plugin's record knows
nothing about it.

`syncSchedule()` originally compared the plan against that record and skipped the write when they
matched. On a device this produced the worst possible failure — after a force-stop, `AlarmManager`
held zero alarms, the record still claimed five, the comparison passed, nothing was rewritten, and
the page reported "Ready. Next listening for Dhuhr at 12:15 PM" for a feature that could never
fire.

The fix is to always write. Re-arming five exact alarms is free, `planSignature` already prevents
it running on every render, and writing unconditionally makes the feature self-healing: opening
the page is enough to recover from a force-stop, a crash, or anything else that clears alarms.
Confirmed by force-stopping the app, watching `dumpsys alarm` drop to zero, and seeing all five
come back on reopening the page.

## Verified on a device

Unit tests cover the planning arithmetic and the plugin's own state machine, but neither can say
whether a real alarm fires on a real OEM Android. Exercised on a OnePlus CPH2421 running Android
11, using a dev-only panel that schedules a throwaway window a minute out — waiting for a genuine
prayer would have meant hours, since the offset range only reaches two hours either side of one:

- A window fired from a real `AlarmManager` entry, silenced the ringer, and posted the
  notification.
- The ringer came back at the deadline **to the second**, and the state fields cleared.
- Switching mode mid-silence produced the prompt, naming the window and its end time.
- "Switch when this finishes" left the phone silent and queued the switch.
- "Switch now" restored the ringer immediately and switched.
- The laptop lost power mid-test, which turned into the best check of the lot: the phone finished
  the deferred switch on its own — restored the ringer, applied the queued mode, and armed the
  incoming mode's schedule — with nothing connected to it.
- Force-stopping cleared every alarm, exactly the behaviour the persisted restore deadline exists
  to survive.

One thing that stayed dev-only: rescheduling from the app *while* a window is open cancels its
pending alarms, and `rearmActiveEnd` puts the restore back. That path ran for real during the
power-loss test and the restore still landed on time.

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
