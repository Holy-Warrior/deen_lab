<script lang="ts">
    import { tools } from "$lib/tools/discover";
</script>

<div class="grid grid-cols-2 gap-3">
    {#if tools.length === 0}
        <!-- design: nothing registered in $lib/features/**/tool.ts yet -- same empty slots as before the mechanism existed -->
        {#each Array.from({ length: 4 }) as _}
            <div class="placeholder-slot"></div>
        {/each}
    {:else}
        <!-- svelte: (tool.id) keys each block by id instead of array index, so Svelte can match/reorder tiles correctly if the list changes instead of re-rendering everything -->
        {#each tools as tool (tool.id)}
            {@const Icon = tool.icon}
            <a class="tool-card min-h-[5.5rem]" href={tool.route}>
                <Icon size={20} class="text-emerald-400" />
                <div class="mt-2 font-semibold">{tool.name}</div>
                {#if tool.description}
                    <div class="mt-1 text-xs text-zinc-400">{tool.description}</div>
                {/if}
            </a>
        {/each}
    {/if}
</div>
