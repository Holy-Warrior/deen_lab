<script lang="ts">
    import LibraryGrid from "$lib/components/library/LibraryGrid.svelte";
</script>

<svelte:head><title>Library · DeenLab</title></svelte:head>

<div class="space-y-6">
    <header class="app-header">
        <h1 class="text-3xl font-bold">Library</h1>
        <!-- design: names only what is actually here. Hadith was listed before it existed and
             then dropped outright over translation licensing (see docs/credits.md), so naming
             specific tools that aren't in the grid below is a promise this app can't keep. -->
        <p class="mt-2 text-zinc-400">Duas and Quran, with more reading tools to come.</p>
    </header>

    <LibraryGrid />
</div>
