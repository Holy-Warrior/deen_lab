<script lang="ts">

    import Section from "./Section.svelte";

    import {
        renderPage
    } from "$lib/ui/render/page";

    export let page: string;

    const rendered = renderPage(page);

</script>

{#if rendered}

    <div
        class="
            space-y-10
        "
    >

        {#each rendered.sections as section}

            <Section
                {section}
            />

        {/each}

    </div>

{/if}
