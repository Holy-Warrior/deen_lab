<script lang="ts">
    import { Dialog } from "bits-ui";
    import { Menu, X, House, BookOpen, Sparkles, Info } from "@lucide/svelte";

    // svelte: local reactive state via the $state rune, no store needed for a single component's open/closed flag
    let open = $state(false);

    // sveltekit: hardcoded to match BottomNav for now; both will read from one place once a tool/nav registry exists
    const links = [
        { href: "/", label: "Home", icon: House },
        { href: "/library", label: "Library", icon: BookOpen },
        { href: "/feature-studio", label: "Studio", icon: Sparkles },
        // design: About lives in the drawer rather than the bottom nav -- it is read once,
        // not switched between, so it does not earn a permanent tab
        { href: "/about", label: "About", icon: Info }
    ];
</script>

<!-- bits-ui: Root only tracks open state and renders nothing itself -- Trigger/Content do the actual rendering -->
<Dialog.Root bind:open>
    <Dialog.Trigger class="icon-button justify-self-start" aria-label="Open menu">
        <Menu size={20} />
    </Dialog.Trigger>

    <Dialog.Portal>
        <!-- bits-ui: Portal teleports Overlay/Content to <body>, so the fixed top bar's stacking context can't clip them -->
        <Dialog.Overlay class="overlay" />
        <Dialog.Content class="drawer-panel">
            <div class="flex items-center justify-between">
                <Dialog.Title class="text-lg font-bold">DeenLab</Dialog.Title>
                <Dialog.Close class="icon-button" aria-label="Close menu">
                    <X size={20} />
                </Dialog.Close>
            </div>

            <nav class="flex flex-col gap-1">
                {#each links as link}
                    {@const Icon = link.icon}
                    <a class="drawer-link" href={link.href} onclick={() => (open = false)}>
                        <Icon size={20} />
                        <span>{link.label}</span>
                    </a>
                {/each}
            </nav>

            <p class="mt-auto text-sm text-zinc-500">More tools will appear here as they're added.</p>
        </Dialog.Content>
    </Dialog.Portal>
</Dialog.Root>
