<script lang="ts">
    let { size = 28 }: { size?: number } = $props();
</script>

<!-- design: hand-drawn silhouette (two domed minarets, a central onion dome, a crescent +
     star finial, an arched doorway cut from the base) instead of a raster image -- stays crisp
     at any size with no asset to ship, and `fill="currentColor"` lets the parent's CSS `color`
     pick light-on-dark or dark-on-light without a second copy of the icon -->
<svg viewBox="0 0 64 64" width={size} height={size} fill="currentColor" aria-hidden="true">
    <!-- base wall with a rounded archway cut out of it (evenodd: the second subpath punches
         a hole through the first instead of drawing on top of it, so it stays a true cutout
         regardless of what's behind the icon) -->
    <path fill-rule="evenodd" d="M4,30 L60,30 L60,60 L4,60 Z M26,60 L26,42 A6,6 0 0 1 38,42 L38,60 Z" />

    <!-- minaret towers -->
    <rect x="8" y="14" width="7" height="20" />
    <rect x="49" y="14" width="7" height="20" />

    <!-- minaret domes -->
    <path d="M11.5,4 C9.5,4 8,7 8,10 C8,12.5 9.5,14 11.5,14 C13.5,14 15,12.5 15,10 C15,7 13.5,4 11.5,4 Z" />
    <path d="M52.5,4 C50.5,4 49,7 49,10 C49,12.5 50.5,14 52.5,14 C54.5,14 56,12.5 56,10 C56,7 54.5,4 52.5,4 Z" />

    <!-- central onion dome -->
    <path d="M32,11 C24,15 18,20 18,26 C18,30 24,30 32,30 C40,30 46,30 46,26 C46,20 40,15 32,11 Z" />

    <!-- crescent + star finial -->
    <path d="M32,1 A4,4 0 1 0 32,9 A3.2,3.2 0 1 1 32,1 Z" />
    <path d="M37,0.5 L37.8,2.3 L39.5,3 L37.8,3.7 L37,5.5 L36.2,3.7 L34.5,3 L36.2,2.3 Z" />
</svg>
