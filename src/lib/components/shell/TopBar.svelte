<script lang="ts">
    import MenuDrawer from "./MenuDrawer.svelte";
    import NotificationsPanel from "./NotificationsPanel.svelte";
</script>

<!-- tailwind: .top-bar is grid-cols-[1fr_auto_1fr] (see app.css), so the title stays centered no matter how wide the two buttons are -->
<header class="top-bar">
    <MenuDrawer />

    <span class="justify-self-center text-lg font-bold">DeenLab</span>

    <NotificationsPanel />
</header>
