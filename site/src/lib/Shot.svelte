<script>
	/**
	 * A screenshot of the app that follows the visitor's light or dark setting.
	 * Pass `name` for a light/dark pair, or `src` for a single image.
	 */
	let { name = '', src = '', alt, width, height, eager = false } = $props();
</script>

{#if name}
	<picture>
		<source srcset="/showcase/{name}-dark.png" media="(prefers-color-scheme: dark)" />
		<img class="ring" src="/showcase/{name}-light.png" {alt} {width} {height} loading={eager ? 'eager' : 'lazy'} draggable="false" />
	</picture>
{:else}
	<img class="ring" {src} {alt} {width} {height} loading={eager ? 'eager' : 'lazy'} draggable="false" />
{/if}
