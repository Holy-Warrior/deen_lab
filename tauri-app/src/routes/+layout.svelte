<script lang="ts">
    import "../app.css";
    import { onMount } from "svelte";
    import AppShell from "$lib/components/shell/AppShell.svelte";
    import { scheduleStartupCheck } from "$lib/features/auto-silent/health";
    import type { Snippet } from "svelte";

    let { children }: { children: Snippet } = $props();

    onMount(scheduleStartupCheck);
</script>

<AppShell>
    {@render children()}
</AppShell>
