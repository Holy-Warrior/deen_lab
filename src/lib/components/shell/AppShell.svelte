<script lang="ts">
    import TopBar from "./TopBar.svelte";
    import BottomNav from "./BottomNav.svelte";
    import type { Snippet } from "svelte";

    // svelte: `children` is how Svelte 5 passes the default slot content -- render it with {@render children()}
    let { children }: { children: Snippet } = $props();
</script>

<div class="app-shell">
    <TopBar />

    <main class="shell-main">
        <div class="page-container">
            {@render children()}
        </div>
    </main>

    <BottomNav />
</div>
