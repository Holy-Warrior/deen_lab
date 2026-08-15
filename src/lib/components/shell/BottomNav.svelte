<script lang="ts">
    import { page } from "$app/state";
    import { House, BookOpen, Sparkles } from "@lucide/svelte";

    const tabs = [
        { href: "/", label: "Home", icon: House },
        { href: "/library", label: "Library", icon: BookOpen },
        { href: "/feature-studio", label: "Studio", icon: Sparkles }
    ];
</script>

<nav class="bottom-nav" aria-label="Primary">
    {#each tabs as tab}
        <!-- svelte: page is a rune exported from $app/state (SvelteKit 2.12+) -- reading page.url.pathname re-runs this on every navigation, no subscribe/unsubscribe needed like the old $app/stores API -->
        {@const active = page.url.pathname === tab.href}
        {@const Icon = tab.icon}
        <a class="nav-tab" href={tab.href} data-active={active} aria-current={active ? "page" : undefined}>
            <Icon size={22} />
            <span>{tab.label}</span>
        </a>
    {/each}
</nav>
