<script lang="ts">
    import { Combobox } from "bits-ui";
    import { cities, type City } from "./cities";

    let { onSelect }: { onSelect: (city: City) => void } = $props();

    let searchValue = $state("");
    let selectedValue = $state("");

    // svelte: $derived recomputes automatically whenever searchValue changes -- no manual
    // event wiring needed to keep the filtered list in sync with what's typed
    let filteredCities = $derived.by(() => {
        const query = searchValue.trim().toLowerCase();
        if (!query) return cities;
        return cities.filter(city =>
            city.name.toLowerCase().includes(query) || city.country.toLowerCase().includes(query)
        );
    });

    function cityKey(city: City) {
        return `${city.name}|${city.country}`;
    }

    function handleValueChange(value: string) {
        selectedValue = value;
        const city = cities.find(candidate => cityKey(candidate) === value);
        if (city) onSelect(city);
    }
</script>

<!-- bits-ui: Combobox.Root just tracks value/open state -- Input/Content do the actual rendering -->
<Combobox.Root type="single" bind:value={selectedValue} onValueChange={handleValueChange}>
    <Combobox.Input
        class="control w-full"
        placeholder="Search for a city"
        aria-label="Search for a city"
        oninput={(event) => (searchValue = event.currentTarget.value)}
    />

    <Combobox.Portal>
        <Combobox.Content class="popover-panel max-h-64 overflow-y-auto" sideOffset={6}>
            {#each filteredCities as city (cityKey(city))}
                <Combobox.Item value={cityKey(city)} label={`${city.name}, ${city.country}`} class="drawer-link cursor-pointer">
                    {city.name}, {city.country}
                </Combobox.Item>
            {:else}
                <p class="p-3 text-sm text-zinc-400">No cities match your search.</p>
            {/each}
        </Combobox.Content>
    </Combobox.Portal>
</Combobox.Root>
