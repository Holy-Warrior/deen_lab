# Studio — generating small tools with Groq

Studio takes a plain-English description ("a tasbeeh counter with a running total") and builds a
working, interactive mini-tool from it, which then lives on the device and can be opened like any
other feature. The model does the writing; the app supplies everything around it — the styling
runtime, the sandbox, and the rules the output has to satisfy.

- Frontend: `src/lib/features/feature-studio/`
- Backend command: `build_feature` in [`src-tauri/src/lib.rs`](../src-tauri/src/lib.rs), documented
  in [`backend-api.md`](./backend-api.md#build_featureprompt-string-promisefeaturebuildresult)
- Routes: `/feature-studio` (the Studio tab) and `/feature-studio/build`

## Two screens, not one

Studio is split across two routes:

| Route | Component | Purpose |
|---|---|---|
| `/feature-studio` | `StudioHomePage.svelte` | The tab itself: a wide entry card, any interrupted build, and your tools |
| `/feature-studio/build` | `StudioBuildPage.svelte` | The prompt box, the suggestions, and the build button |

The first version put everything on the tab, and on a 360dp phone the prompt box plus five
full-sentence suggestion pills filled the entire screen — the tools you had already built were
pushed below the fold, so the tab was dominated by the act of building rather than by what you
had built. Splitting it means the tab answers "what do I have?" and the build screen answers
"what do I want?".

Two consequences worth keeping:

- **Your tools render as the same two-column tile grid as Home and Library**, so something you
  made yourself sits in the app exactly the way something that shipped with it does.
- **Tiles have no delete button.** Deleting lives in the preview's top bar, which keeps the tile
  tappable anywhere and puts the action where you are most likely to want it — just after looking
  at the thing and deciding it is not worth keeping.

### Deleting asks first, and makes you wait

Deleting a generated tool is genuinely unrecoverable: the markup exists only on this device, and
rebuilding from the same prompt produces something different rather than the same thing back. The
first version deleted on a single tap, which is far too easy for an action with no undo.

It now opens a `bits-ui` `AlertDialog` (not `Dialog` — `AlertDialog` won't dismiss on an outside
click and traps focus on the two choices, which is what a destructive prompt should do), and the
confirm button is **held out for 4 seconds**, counting down in its own label: `Delete (4)` →
`Delete`. The point is that the second tap has to be a decision rather than a continuation of the
first — the same reason the trash icon and a confirm button should never land under the same
finger position.

The confirm is a plain `<button>`, deliberately **not** `AlertDialog.Action`: `Action` closes the
dialog on any click, which would dismiss the whole prompt on a tap made while the button was still
held out.

Suggestions are short labels (`Tasbeeh counter`) that insert a longer prompt, rather than being
the long prompt themselves. A suggestion has to be scannable to be worth having.

## The central design decision: the app supplies Tailwind, not the model

Generated HTML needs a styling system, or every tool comes back as unstyled text on a white page.
Tailwind is the obvious choice — it is what the rest of the app uses, and utility classes are
exactly the kind of thing a language model writes well.

The tempting approach is to tell the model to add the Tailwind CDN `<script>` tag itself. That was
rejected, for three reasons:

1. **It would require network access.** A tool that only styles itself when the phone is online is
   not a tool the app can promise anything about.
2. **The model would have to get a URL right.** Models are unreliable at reproducing exact URLs and
   version specifiers, and the failure is silent — a slightly wrong CDN URL yields an unstyled
   page, not an error.
3. **It contradicts the sandbox.** The whole point of the preview is that a generated tool cannot
   reach the network. Carving out an exception for one script would mean the sandbox no longer
   guarantees anything.

**Instead the contract is inverted.** The model is told, in the system prompt:

> Tailwind CSS is ALREADY LOADED and ready for you. Use Tailwind utility classes directly. Do not
> add a Tailwind CDN link, a stylesheet, or any build step. Trust that the classes work.

and the app injects the runtime itself, from a copy committed at
`static/vendor/tailwind-browser.js`. That file is `@tailwindcss/browser`, pinned to **4.3.3 — the
same version as the app's own `tailwindcss`** — so previews style exactly the way the rest of the
app does. It is 281 KB, and jsDelivr's build header naming the upstream package is left intact in
the file as provenance.

Two things were checked before relying on it:

- It contains **no `</script>` sequence**, so embedding it inline in the document cannot terminate
  the `<script>` block early.
- It uses **no `eval`, no `new Function`, and no WebAssembly**, so it runs under a CSP without
  `'unsafe-eval'`. It compiles CSS by creating one `<style>` element and setting `textContent`.

## The output contract: body-only markup

`build_feature` returns `html` that is **the markup that goes inside `<body>`** — not a whole
document. The prompt forbids `<!doctype>`, `<html>`, `<head>`, `<body>`, `<link>` and
`<script src=...>` outright.

This is deliberate. If the model returned a complete document, the app would have to perform string
surgery on it to inject the runtime — find the `<head>`, hope it exists, hope it is well-formed.
Asking for a fragment and building the document around it removes that entire class of failure:
there is exactly one document template, written by hand, and the model's output is dropped into a
known slot in it.

`extractBodyMarkup()` in `document.ts` still defends against the model ignoring the contract
(unwrapping a `<body>` if one appears, stripping `<link>` and external `<script src>`), because
"reliably complies" is not "always complies". Measured across the prompts used to validate this,
compliance was **100% — zero violations** — but the guard costs nothing.

## How a generated tool is contained

`composeDocument()` assembles the document and `FeaturePreview.svelte` renders it into
`<iframe srcdoc=...>`. Three layers do the containment:

**1. `sandbox="allow-scripts"`, and deliberately *not* `allow-same-origin`.** Scripts are needed —
both by the Tailwind runtime and by the tool's own behaviour. Withholding `allow-same-origin` puts
the frame on an opaque origin, so it cannot read the app's storage or touch its DOM. The two must
never be combined: `allow-scripts` plus `allow-same-origin` would let the frame delete its own
`sandbox` attribute and escape entirely.

**2. A restrictive CSP inside the document.** This is what actually enforces "no network access" —
the system prompt only *asks*:

```text
default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline';
img-src data:; font-src data:; base-uri 'none'; form-action 'none'
```

`'unsafe-inline'` is unavoidable because everything here is inline by design. `'unsafe-eval'` is
absent, per the check above.

**3. A storage shim.** On an opaque origin, merely *reading* `localStorage` throws a
`SecurityError`, which would take down the tool's entire script — a tool that tried to save a
counter would appear completely broken rather than just failing to persist. The document therefore
replaces `localStorage` and `sessionStorage` with its own implementation, described next.

There is also a plain `<style>` block setting a dark background before Tailwind has compiled
anything. Without it the preview flashes white on open, because the runtime generates its
stylesheet asynchronously after the document first paints.

## Giving the frame a capability: persistent storage

A sealed frame is only useful if it can still do the things a tool needs. Storage was the first
real gap — a Ramadan tracker built in Studio would show "Day 15 of 30", then reopen at Day 1,
because its state lived in a variable that died with the frame.

`postMessage` is the one channel that crosses the sandbox boundary without `allow-same-origin`,
and it is one-way by construction: the frame can hand data out, but cannot reach in and read
anything. That makes it the right primitive for handing capabilities into the frame.

### Why the ordinary Storage API, and not a bespoke one

The obvious design is a custom async API — `DeenLab.storage.get(key)` returning a Promise over
postMessage. It was rejected: it is an API the model has to be *told* about, and every token spent
teaching it is a token not spent on the tool, with a real chance the model forgets and reaches for
`localStorage` anyway.

Instead the frame gets a working `localStorage`, which the model already knows:

- **Reads are synchronous** because the saved data is *inlined into the document* at compose time,
  before the feature's script runs. This is the trick that makes the standard API possible at all —
  `getItem` cannot await a round trip, so the round trip has to have already happened.
- **Writes fire a `postMessage`** to the app, which persists them against that tool's id.

So the model writes the code it would write anyway, and it simply persists.

### What the app does not trust

The payload is built by model-written code inside a sandbox, so the receiving end treats it as
hostile input:

| Risk | Guard |
|---|---|
| A message from some other frame or page | `event.source !== frame.contentWindow` is rejected. The frame's origin is the string `"null"`, so `event.origin` is useless here — the window reference is the only trustworthy identity |
| Wrong shape / non-string values | `sanitiseFeatureState()` accepts only a flat `Record<string, string>` |
| One tool exhausting the shared quota | 32 KB ceiling per tool; oversized payloads are dropped |
| One tool reading another's data | State is keyed by feature id, and only that tool's slice is inlined into its document |
| A stored value containing `</script>` | `<` is escaped to `<` when inlining, so a value cannot terminate the script block and inject markup |

Deleting a tool also clears its stored state — ids are never reused, so anything left behind would
be unreadable forever.

The system prompt was updated to match: it now says storage works and survives closing the app, and
notes that a tool which silently forgets a month of progress is worse than one that never offered
to remember.

## How the system prompt is written

`FEATURE_STUDIO_PROMPT` is deliberately written as **explained context rather than a rule list**.
An earlier version stacked up imperatives — "Never write…", "Nothing may…", "Tap targets at least
44px" — and the output got noticeably mechanical: the model followed the letter of each rule
instead of designing something for the person who asked.

The guidance now follows three habits:

- **Every constraint carries its reason.** "Adding a CDN link would fail: the frame is sealed off
  from the network by a Content-Security-Policy, and any external URL is blocked before it loads"
  rather than "Never add a CDN link." A model told *why* can generalise to cases the prompt never
  anticipated. A model told only the rule pattern-matches against it.
- **Judgement calls are hedged.** "You may find a row of three or more controls is where a layout
  starts to break" rather than "Three buttons will not fit, so stack them." The prompt cannot see
  the request; the model can.
- **The situation is described instead of the output specified.** "This is a phone app and your
  tool opens full-screen inside it. There is no desktop version" does the work that a pixel width
  was doing, without pretending the prompt knows the layout in advance.

What stays firm is the distinction that makes this safe: **facts about the environment are
explained but not softened**, and the **JSON response shape is a machine contract, stated exactly
and never hedged** — there is no judgement to exercise in whether the reply parses.

Measured after the rewrite: contract compliance held at zero violations, the 3-across layouts that
caused a real overflow on-device stopped appearing, and declines began explaining themselves
("would need real-time data from the internet") rather than reciting a refusal.

## Upgrading a tool, and version history

A tool is stored as a **list of versions**, not a single blob of markup. The first is the original
build; each accepted upgrade appends another and moves `currentVersionId`. Nothing is ever
overwritten or edited in place, which is what makes stepping back trustworthy.

```ts
interface GeneratedFeature {
  id: string; title: string; createdAt: string;
  versions: FeatureVersion[];      // append-only, chronological
  currentVersionId: string;        // which one is in use
}
```

`activeVersion()` resolves the pointer and falls back to the newest if it ever dangles, so a
corrupted pointer degrades to "show the latest" rather than rendering nothing.

### The candidate is never applied automatically

`upgrade_feature` returns a **candidate**, and the front-end decides its fate. `UpgradePanel`
shows the request box at the top and renders the new version *underneath it, running*, with
**Discard** and **Keep this version**. Nothing about the stored tool changes until Keep is pressed.

This matters more than it sounds: reading a description of a change tells you very little, and
using it tells you everything. A model that says "added a reset button" may have quietly
rearranged the layout as well. So a bad upgrade costs one request and nothing else.

The upgrade always revises **the version currently in use**, not the newest — if the user has
stepped back to an older version, that is the one they are looking at and asking about.

### What the upgrade prompt has to say that the build prompt does not

`UPGRADE_INTRO` carries two instructions with no equivalent on the build side:

- **Keep what was not asked about.** "Someone asking for a reset button has not asked you to
  redesign the layout, and finding the rest rearranged is worse than not getting the button."
  Left unsaid, models rewrite freely, because rewriting is what they are good at.
- **Reuse the same `localStorage` keys.** Saved state persists across versions (it is keyed by
  feature id, not version id), so a rename silently orphans the user's data — the tool keeps
  working and their month of progress is simply gone.

Both prompts share `PROMPT_ENVIRONMENT` through `system_prompt(Task)`, so a change to how the
sandbox behaves is made once and cannot drift between building and revising. `run_chain()` is
likewise shared: the two commands differ only in their system prompt and user message, and both
get the same fallback chain, retry classification and progress reporting.

## The model chain

`MODEL_CHAIN` lives in `lib.rs`, **not** in the gitignored `groq_config.rs`. The key is a secret;
the model list is a project decision and belongs under version control. This also guards against a
failure already hit once: Groq retires models, and the previously configured
`llama-3.3-70b-versatile` had been decommissioned — it no longer appears in
`GET /openai/v1/models`, so Studio was silently broken with no local sign of why.

Three models are tried in order, best-for-the-job first:

| Order | Model | Typical build | Notes |
|---|---|---|---|
| 1 | `openai/gpt-oss-20b` | 1.2–2.2 s | Fastest, and no measurably worse at this task — the default |
| 2 | `openai/gpt-oss-120b` | 1.8–2.5 s | The heavier backstop |
| 3 | `qwen/qwen3.6-27b` | ~5.2 s | Slowest, but writes the most detailed markup |

"Best for the job" here means *fastest at equal quality*, not largest. Across the validation
prompts the 120b produced nothing measurably better than the 20b while taking longer, and for a
tool the user is waiting on, latency is the quality that shows.

**The reason a chain is worth having is that the token allowance is per model, not per account.**
That was measured, not assumed: with `gpt-oss-120b` returning 429, both `gpt-oss-20b` and
`qwen/qwen3.6-27b` answered *immediately* with no wait. Each model carries its own 8,000 TPM, so
three models carry roughly three times the capacity — about six builds per minute instead of two.

`reasoning_effort` is set **per model, not globally**. `gpt-oss` models accept `"low"`;
`qwen/qwen3.6-27b` uses a different mechanism and `groq/compound` rejects the parameter outright
with a 400. Hence `ModelSpec.reasoning_effort` being an `Option` rather than a constant.

### Why the budget is 2,700 tokens

The free plan gives **8,000 tokens per minute per model**, and Groq reserves
`prompt_tokens + max_completion_tokens` **up front**, before generating anything. So the completion
budget is a throughput decision as much as a size cap: at 6,500 only one build lands per minute per
model.

The number is sized so two builds fit inside the allowance alongside the ~920-token system prompt:
`(8000 / 2) - 920`, less room for the user's own words. Real features come in far under it — a
tasbeeh counter needs ~580 completion tokens, a zakat calculator ~950 — so the ceiling costs
nothing in practice. It is worth recomputing if the system prompt is ever substantially rewritten;
lengthening the prompt silently buys fewer builds per minute.

`reasoning_effort: "low"` matters more than it looks. `gpt-oss` models think before answering and
those reasoning tokens are billed against the same completion budget. Measured with it omitted, a
3,000-token budget produced `400 Failed to generate JSON` — the model spent the budget reasoning
and the JSON object was cut off mid-string. With it set to `"low"`, the same prompts finish in
~600–950 tokens with `finish_reason: "stop"`.

### What counts as worth retrying

`AttemptError` splits failures in two. **Retryable** — rate limits (429/413), a truncated reply,
Groq rejecting its own JSON, a network blip, or a malformed decision — all move to the next model,
because a different model genuinely may succeed. **Fatal** — a rejected API key (401/403) or any
other unexpected status — stops immediately, because no other model will fix it.

The chain runs straight through with **no delay between models**, since a 429 from one says nothing
about the next. Only when all three are exhausted is there anything to wait for, and then the wait
uses Groq's own retry hint (clamped to `MAX_WAIT_SECONDS = 45`) before one more pass. Progress is
streamed to the UI over a `Channel` so a wait is explained rather than looking like a hang.

`reasoning_effort: "low"` matters more than it looks. `gpt-oss` models think before answering and
those reasoning tokens are billed against the same completion budget. Measured with it omitted, a
3,000-token budget produced `400 Failed to generate JSON` — the model spent the budget reasoning
and the JSON object was cut off mid-string. With it set to `"low"`, the same prompts finish in
~600–950 tokens with `finish_reason: "stop"`.

### Why not `groq/compound`

`groq/compound` advertises **70,000 TPM against gpt-oss's 8,000**, which looks like nearly 9× the
headroom. Measured, it is not:

| | `openai/gpt-oss-20b` | `groq/compound-mini` |
|---|---|---|
| Time per build | **1.6–2.2 s** | 7.1–9.7 s |
| Builds before HTTP 429 | **2** | 2 |
| Max `max_completion_tokens` accepted | 65,536 | **~1,200** (2,000 returns HTTP 413) |
| `reasoning_effort` | supported | rejected with HTTP 400 |

The advertised ceiling does not apply because compound is an **agentic system, not a model** —
it is powered by Llama 4 Scout / Llama 3.3 70B plus GPT-OSS 120B, and its internal calls draw on
*those* models' budgets. Its 429 says so explicitly, naming a model the caller never asked for:

```text
Rate limit reached for model `openai/gpt-oss-120b` ... on tokens per minute (TPM): Limit 8000
```

So compound delivers the same two builds per minute, 3–6× slower, and caps output so low that
larger tools cannot be generated at all. `groq/compound` **does** support
`response_format: json_object` (Groq's docs list it as a capability) — that was not the
disqualifier. Throughput was.

Undocumented findings worth knowing, all established by measurement rather than from the docs:
the up-front reservation of `max_completion_tokens`; compound's ~1,200-token practical output
ceiling; and compound rejecting `reasoning_effort`.

## Errors are rewritten before the user sees them

Groq's raw error bodies carry organization ids, service-tier names and an upgrade link — noise to
someone who only wants to know whether to wait or give up. Most conditions no longer surface at all,
because the chain simply moves to the next model; only a failure that outlives all three becomes a
message:

| Condition | Handling |
|---|---|
| HTTP 429 / 413 (allowance exhausted for that model) | Retryable — next model, no delay. Groq's retry hint is kept in case every model is exhausted |
| `finish_reason == "length"` | Retryable — checked **before** JSON parsing, since a truncated reply is invalid JSON and `EOF while parsing a string` explains nothing |
| HTTP 400 naming `failed_generation` | Retryable — Groq rejected its own output against the JSON shape; another model may not |
| Network blip, malformed reply, unexpected `decision` | Retryable — one attempt failing says nothing about the next |
| HTTP 401 / 403 | **Fatal** — the key is wrong; no other model fixes that |
| All three models exhausted, twice | One plain sentence: every model is busy, wait a moment |

One frontend trap, inherited from the old implementation and fixed in this one: **a Rust
`Err(String)` arrives at `invoke()` as a plain string, not an `Error`.** A `catch` that only tests
`cause instanceof Error` silently discards every backend message and shows a generic fallback.

## Interrupted builds are offered back, not kept alive

A build can outlive the user's attention — they switch apps, and Android is free to freeze or kill
the process while it is backgrounded. Keeping the request alive through that would mean a
foreground service and an ongoing notification, which is a lot of native machinery and a permanent
notification channel for something that normally takes two seconds.

The cheaper answer is to accept the interruption and recover from it. Before the request goes out,
`savePending({ prompt, startedAt })` writes a marker to `localStorage`; the `finally` block clears
it however the build ends — success, decline, or error. **The marker therefore only survives if the
app never got to run that `finally`**, which is exactly the interrupted case and nothing else.

On the next visit, `loadPending()` finds it and Studio offers the prompt back with a "Build it now"
button and how long ago it was started. The marker is deliberately *not* cleared just for being
seen — leaving the page without deciding keeps the offer for next time. Only building or discarding
removes it.

Only the prompt is stored, never a partial result. Rebuilding from the prompt costs one request,
and the user is the one who decides whether they still want it.

## Back navigation

The open preview is a drill-down inside a single route, so it uses SvelteKit **shallow routing** —
`pushState("", { feature })` with the open tool read back out of `page.state`. Without a real
history entry the phone's hardware back button would exit the app on the first press instead of
closing the preview. The full explanation is in
[`android-back-navigation.md`](./android-back-navigation.md).

`bits-ui`'s `Dialog` is driven from `page.state` rather than a local flag, so the back button, the
Escape key and the close button all run through the same history entry and cannot drift apart.
`$state.snapshot()` is required on the way in — a raw `$state` proxy is not structured-cloneable
and `pushState` throws `DataCloneError` at runtime, which no type check catches.

### Navigate after cleanup, not during it

A finished build ends by navigating to the Studio screen with the new tool already open. The first
version did that inside the `try` block, which produced a wrong-looking bug on the device: after a
build that had plainly just succeeded, the Studio screen announced an **"Unfinished build"**.

The cause is ordering. `goto()` mounts `StudioHomePage`, whose `onMount` calls `loadPending()` —
and at that moment the pending marker was still set, because `clearPending()` lives in the
`finally` block that had not run yet. The screen was reading state that was one step out of date.

The fix is to hold the result in a local, let `finally` clean up, and navigate afterwards:

```ts
let built: GeneratedFeature | null = null;
try { /* ... */ built = feature; }
finally { clearPending(); isBuilding = false; }
if (built) { await goto("/feature-studio"); pushState("", { feature: built }); }
```

Worth remembering generally: when one screen's `onMount` reads storage that another screen is
still finishing writing, navigation has to come after the write, not alongside it.

## Setup

Studio needs a Groq API key, which is not bundled. Copy
[`groq_config.example.rs`](../src-tauri/src/groq_config.example.rs) to
`src-tauri/src/groq_config.rs` (gitignored) and fill in a key from
[console.groq.com](https://console.groq.com). A free key is enough. Without one, every other
feature works normally and Studio reports that it is not configured.
