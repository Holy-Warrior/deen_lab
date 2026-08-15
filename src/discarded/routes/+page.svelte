<script lang="ts">
    import PageRenderer from "$lib/ui/components/PageRenderer.svelte";
    import { initializeApplication } from "$lib/ui/kernel/discover";

    initializeApplication();
</script>

<svelte:head><title>DeenLab</title></svelte:head>

<div class="app-shell">
    <main class="page-container space-y-10">
        <header class="app-header">
            <div class="text-4xl font-bold">DeenLab</div>
            <div class="mt-2 text-zinc-400">Islamic knowledge and daily practice tools</div>
        </header>

        <PageRenderer page="home" />
    </main>
</div>
