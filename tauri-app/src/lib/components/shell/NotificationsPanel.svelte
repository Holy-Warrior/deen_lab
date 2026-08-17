<script lang="ts">
    import { Popover } from "bits-ui";
    import { Bell } from "@lucide/svelte";

    let open = $state(false);
</script>

<Popover.Root bind:open>
    <Popover.Trigger class="icon-button justify-self-end" aria-label="Notifications">
        <Bell size={20} />
    </Popover.Trigger>

    <Popover.Portal>
        <!-- bits-ui: Content is positioned relative to Trigger via floating-ui, sideOffset just adds a gap below the bell -->
        <Popover.Content class="popover-panel" sideOffset={10} align="end">
            <p class="font-semibold">Notifications</p>
            <p class="mt-2 text-sm text-zinc-400">No notifications yet.</p>
        </Popover.Content>
    </Popover.Portal>
</Popover.Root>
