<script lang="ts">
    // design: the app-wide convention for API/backend errors is an inline banner above
    // the content it failed to refresh (not a blocking dialog) -- cached content, if any,
    // stays visible and usable underneath while this explains what went wrong.
    let { message, onRetry, retryLabel = "Try again" }: { message: string; onRetry?: () => void; retryLabel?: string } = $props();
</script>

<div class="error-banner" role="alert">
    <span>{message}</span>

    {#if onRetry}
        <button class="button button--secondary" onclick={onRetry}>{retryLabel}</button>
    {/if}
</div>
