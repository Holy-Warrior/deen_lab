<!-- design: stands in for the auto-rendered 2-column tool grid, once a tool-discovery/registry system exists -->
<div class="grid grid-cols-2 gap-3">
    {#each Array.from({ length: 4 }) as _}
        <div class="placeholder-slot"></div>
    {/each}
</div>
