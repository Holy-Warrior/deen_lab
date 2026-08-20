import { verifySchedule, type ScheduleHealthReport } from "./engine";

/**
 * The startup self-check for Auto Silent.
 *
 * The problem it solves: the plugin's schedule and Android's AlarmManager drift
 * apart silently. A force-stop drops every alarm the app owns and tells nobody,
 * and until now the only thing that repaired it was opening the Auto Silent
 * page, which rewrites the schedule unconditionally. Someone who opened the app
 * for prayer times and left still had a feature that could never fire.
 *
 * Running it from app start rather than from the feature page is the whole
 * point, so it deliberately lives outside `AutoSilentPage`.
 */

/** What the last check found, kept so the page can be honest about it. */
export interface HealthRecord {
    checkedAt: number;
    healthy: boolean;
    repaired: boolean;
    /** A one-line summary of what it put right, or "" when nothing needed doing. */
    fixed: string;
}

const recordKey = "deenlab.auto-silent.last-check";

/**
 * Long enough that the check never competes with first paint, short enough that
 * it still runs during a brief visit to the app. The work itself is native and
 * cheap; the delay is about startup feel, not cost.
 */
const delayMs = 5000;

/**
 * Turns a report into something worth showing a person.
 *
 * Ordered by consequence: a phone left silent is the worst thing this feature
 * can do to someone, so it is said first and said plainly.
 */
export function describe(report: ScheduleHealthReport): string {
    const parts: string[] = [];

    if (report.strandedSilenceRestored) parts.push("turned your ringer back on");
    if (report.restoreAlarmRearmed) parts.push("restored the alarm that ends a silence");
    if (report.repaired && report.missingBefore.length > 0) {
        const n = report.missingBefore.length;
        parts.push(`re-armed ${n} ${n === 1 ? "reminder" : "reminders"}`);
    }
    if (report.disarmedWhileOff) parts.push("cleared reminders left over while it was off");

    if (!report.healthy) {
        // Being wrong in the reassuring direction is the one failure this must
        // not have, so an unrepairable schedule says so rather than going quiet.
        parts.push(
            report.exactAlarmPermission
                ? "could not re-arm everything"
                : "could not re-arm: alarm permission is off"
        );
    }

    return parts.join(", ");
}

function remember(report: ScheduleHealthReport): HealthRecord {
    const record: HealthRecord = {
        checkedAt: report.checkedAtMillis,
        healthy: report.healthy,
        repaired: report.repaired || report.strandedSilenceRestored || report.disarmedWhileOff,
        fixed: describe(report)
    };
    try {
        localStorage.setItem(recordKey, JSON.stringify(record));
    } catch {
        // a lost preference is not worth interrupting anyone over
    }
    return record;
}

export function lastCheck(): HealthRecord | null {
    try {
        const raw = localStorage.getItem(recordKey);
        if (!raw) return null;
        const parsed = JSON.parse(raw) as Partial<HealthRecord>;
        if (typeof parsed.checkedAt !== "number") return null;
        return {
            checkedAt: parsed.checkedAt,
            healthy: parsed.healthy !== false,
            repaired: parsed.repaired === true,
            fixed: typeof parsed.fixed === "string" ? parsed.fixed : ""
        };
    } catch {
        return null;
    }
}

/**
 * Runs the check once, after a delay, and returns a canceller.
 *
 * Once per cold start, not per resume: repairing is cheap but it is still a
 * write to the alarm table, and there is nothing to gain from doing it every
 * time the user switches back to the app.
 */
export function scheduleStartupCheck(): () => void {
    const timer = setTimeout(async () => {
        try {
            const report = await verifySchedule();
            remember(report);
            // vite: import.meta.env.DEV is a build-time literal, so both of these
            // logs vanish from a release bundle. A silent repair is the right
            // behaviour for a user and the wrong one for whoever is debugging it.
            if (import.meta.env.DEV) console.info("[auto-silent] check", JSON.stringify(report));
        } catch (cause) {
            // Rejects on desktop, and on Android if the plugin is unavailable.
            // Neither is worth surfacing to a user: this is a background repair
            // nobody asked for, and the page reports the real state anyway.
            if (import.meta.env.DEV) console.error("[auto-silent] check failed", cause);
        }
    }, delayMs);

    return () => clearTimeout(timer);
}
