<script>
	import { icons } from './icons.js';

	/** @type {{ name: keyof typeof icons, size?: number }} */
	let { name, size = 20 } = $props();
</script>

<svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
	{@html icons[name]}
</svg>

<style>
	svg {
		flex: none;
	}
</style>
