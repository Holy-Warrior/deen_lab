<script lang="ts">
    import LibraryGrid from "$lib/components/library/LibraryGrid.svelte";
</script>

<svelte:head><title>Library · DeenLab</title></svelte:head>

<div class="space-y-6">
    <header class="app-header">
        <h1 class="text-3xl font-bold">Library</h1>
        <p class="mt-2 text-zinc-400">Duas, Quran, Hadith, and other reading tools.</p>
    </header>

    <LibraryGrid />
</div>
