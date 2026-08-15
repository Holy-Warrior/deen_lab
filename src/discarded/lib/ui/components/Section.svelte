<script lang="ts">

    import ToolGrid from "./ToolGrid.svelte";

    import type {
        RenderedSection
    } from "$lib/ui/render/types";

    export let section: RenderedSection;

</script>

<section class="space-y-4">

    <h2
        class="
            text-lg
            font-bold
        "
    >

        {section.definition.title}

    </h2>

    {#if section.definition.view === "grid"}

        <ToolGrid
            tools={section.tools}
        />

    {/if}

</section>
