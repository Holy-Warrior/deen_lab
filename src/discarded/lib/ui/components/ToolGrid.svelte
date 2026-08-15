<script lang="ts">
    import type { ToolDefinition } from "$lib/ui";

    export let tools: ToolDefinition[];
</script>

<div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
    {#each tools as tool}
        <a class="tool-card" href={tool.route}>
            <div class="text-3xl">☪</div>
            <div class="mt-3 font-semibold">{tool.name}</div>

            {#if tool.description}
                <div class="mt-1 text-sm text-zinc-400">{tool.description}</div>
            {/if}
        </a>
    {/each}
</div>
