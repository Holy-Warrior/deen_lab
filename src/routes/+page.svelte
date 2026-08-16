<script lang="ts">
    import PrayerCardPlaceholder from "$lib/components/home/PrayerCardPlaceholder.svelte";
    import ToolGrid from "$lib/components/home/ToolGrid.svelte";
</script>

<svelte:head><title>DeenLab</title></svelte:head>

<!-- design: layout is static (greeting, then the card, then the grid) -- only the pieces inside each slot are meant to be dynamic -->
<div class="space-y-6">
    <div>
        <h1 class="text-2xl font-bold">Assalamu Alaikum!</h1>
        <p class="mt-1 text-zinc-400">May your Salah bring you peace and success.</p>
    </div>

    <PrayerCardPlaceholder />

    <ToolGrid />
</div>
