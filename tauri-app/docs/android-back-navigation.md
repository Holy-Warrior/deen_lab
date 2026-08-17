# Android hardware back button vs. in-page navigation state

Any feature that manages its own drill-down state (a list → detail flow, tabs, a wizard) inside
a single route — instead of using separate SvelteKit routes for each level — needs to opt in to
this pattern explicitly, or the phone's hardware/gesture back button will exit the feature
entirely on the first press instead of stepping back one screen. This bit Duas
(`src/lib/features/duas/DuasPage.svelte`, categories → duas-in-category → dua detail, all one
route) and cost a real investigation to root-cause; this doc exists so the next feature with the
same shape doesn't repeat it.

## Why the back button skips straight to exiting

Tauri's Android shell is auto-generated (`src-tauri/gen/android/.../generated/WryActivity.kt`,
regenerated on build — don't hand-edit it) and installs an `OnBackPressedCallback` with this
logic, roughly:

```kotlin
if (webView.canGoBack()) {
    webView.goBack()
} else {
    // falls through to the default: finish the Activity
    onBackPressed()
}
```

This is the same model Capacitor/Cordova WebViews use — the hardware back button maps to the
WebView's own browser-style navigation history, not to some app-aware "go back one screen"
concept. `canGoBack()` reflects real entries in that history stack (real route changes, or
`history.pushState` calls), **not** plain Svelte component state. A feature that tracks its
drill-down level with `let selected = $state(null)` and nothing else never pushes anything onto
that stack, so `canGoBack()` is `false` the moment you're inside it, and the very first back
press falls straight through to closing/backgrounding the app.

## The fix: SvelteKit shallow routing, not a hand-rolled `popstate` listener

The correct tool is already built into SvelteKit 2 for exactly this "in-page state that back
should step through" case: **shallow routing**, via `pushState`/`page.state`
(https://svelte.dev/docs/kit/shallow-routing). Don't reach for a manual
`window.addEventListener("popstate", ...)` with your own depth-tracking — it's fighting
SvelteKit's already-running client router instead of using it, and it's easy to get subtly wrong
across route boundaries (see "what we didn't need to build," below).

```ts
import { pushState } from "$app/navigation";
import { page } from "$app/state";

interface DuasNavState { category?: DuaCategory; dua?: Dua }

// reads back whatever the *current* history entry's state is -- SvelteKit updates this
// automatically on every push/pop, including a pop caused by the hardware back button
let selectedCategory = $derived((page.state as DuasNavState).category ?? null);
let selectedDua = $derived((page.state as DuasNavState).dua ?? null);

function openCategory(category: DuaCategory) {
    // "" as the url keeps the current URL unchanged -- only page.state changes
    pushState("", { category } satisfies DuasNavState);
}
```

Each `pushState` call adds a real history entry (even though the URL text doesn't change), which
is exactly what makes `webView.canGoBack()` true and routes the next hardware-back press into
`goBack()` → a `popstate` → SvelteKit restoring the previous `page.state` → your `$derived`
values updating on their own. No manual event listener needed anywhere in the feature.

Make the in-page back button call `history.back()` instead of resetting state by hand, so it's
the *exact same code path* as the hardware button and can never drift out of sync with the
pushed history stack:

```ts
function goBack() {
    history.back();
}
```

## The gotcha: `$state` proxies aren't structured-cloneable

`pushState`'s `state` argument goes straight to the browser's native `history.pushState`, which
requires the value to be structured-cloneable. An object read out of a Svelte 5 `$state` array
(e.g. `category` from `{#each categories as category}`, where `categories` itself is
`$state([])`) is a **reactive proxy**, not a plain object — passing it directly throws at
runtime:

```
DataCloneError: Failed to execute 'pushState' on 'History': #<Object> could not be cloned.
```

This doesn't show up in `svelte-check` or any compile-time check — it's a runtime-only failure,
and the button will look like it's simply doing nothing (the `catch` swallows it silently unless
you're specifically logging). Unwrap with `$state.snapshot()` before pushing:

```ts
pushState("", { category: $state.snapshot(category) } satisfies DuasNavState);
```

## What we didn't need to build

An earlier version of this fix considered a hand-rolled `popstate` listener that tracked a
numeric "depth" (0/1/2) in `history.state` and restored `selectedCategory`/`selectedDua` from
local component arrays by depth alone. That approach breaks the moment the user leaves the
feature mid-drill-down (e.g. taps a bottom-nav tab two levels deep) and later hits back far
enough to cross back over the route boundary: the component remounts from scratch, its local
`categories`/`duas` arrays reset, and a bare depth number has nothing to restore from. Shallow
routing sidesteps this entirely because `page.state` carries the *actual* selected
category/dua object with it, not just a depth number, and remounting always lands cleanly at
depth 0 (the categories grid) rather than in a broken partial state.

## When you don't need any of this

Features that use real SvelteKit routes for each level (separate `+page.svelte` files, real URL
changes via `<a href>` or `goto()`) get correct back-button behavior for free — that's ordinary
route history, which `canGoBack()` already sees. This pattern is only needed when a feature
deliberately keeps multiple "screens" inside one route's component state, the way Duas does.

## Reference implementation

`src/lib/features/duas/DuasPage.svelte` — `DuasNavState`, `openCategory`/`openDua` (both call
`pushState`), `goBack` (`history.back()`), and the `$derived` reads of `page.state` at the top of
the `<script>` block.
