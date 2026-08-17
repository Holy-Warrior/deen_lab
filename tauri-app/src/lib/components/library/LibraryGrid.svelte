<script lang="ts">
    import { libraryEntries } from "$lib/library/discover";
</script>

<div class="grid grid-cols-2 gap-3">
    {#if libraryEntries.length === 0}
        <!-- design: nothing registered in $lib/features/**/library.ts yet -- same empty slots as Home's ToolGrid before any tool.ts existed -->
        {#each Array.from({ length: 4 }) as _}
            <div class="placeholder-slot"></div>
        {/each}
    {:else}
        {#each libraryEntries as entry (entry.id)}
            {@const Icon = entry.icon}
            <a class="tool-card min-h-[5.5rem]" href={entry.route}>
                <Icon size={20} class="text-emerald-400" />
                <div class="mt-2 font-semibold">{entry.name}</div>
                {#if entry.description}
                    <div class="mt-1 text-xs text-zinc-400">{entry.description}</div>
                {/if}
            </a>
        {/each}
    {/if}
</div>
