<script>
	import '../app.css';
	import Logo from '#lib/Logo.svelte';
	import { keyPress, thock } from '#lib/motion.js';
	import { rise, sink } from '#lib/transitions.js';
	import { page } from '$app/state';

	let { children } = $props();
	let mark;

	function tap() {
		keyPress(mark);
		thock();
	}

	const nav = [
		{ href: '/guide', label: 'Guide' },
		{ href: '/terms', label: 'Terms' }
	];
</script>

<div class="column">
	<header>
		<a class="brand" href="/" aria-label="Marbly home" onpointerdown={tap}>
			<span class="mark" bind:this={mark}><Logo size={28} /></span>
			<span class="body-medium">Marbly</span>
		</a>
		<nav aria-label="Main">
			{#each nav as item}
				<a
					class="caption hit"
					href={item.href}
					aria-current={page.url.pathname === item.href ? 'page' : undefined}>{item.label}</a
				>
			{/each}
		</nav>
	</header>

	<main>
		{#key page.url.pathname}
			<div class="page" in:rise={{ delay: 80, duration: 260, y: 8 }} out:sink={{ duration: 100 }}>
				{@render children()}
			</div>
		{/key}
	</main>

	<footer class="caption">
		<span class="faint">© 2026 Marbly</span>
		<span class="links">
			<a class="hit" href="https://marbly.click">marbly.click</a>
			<a class="hit" href="/terms">Terms</a>
			<a class="hit" href="/guide">Guide</a>
		</span>
	</footer>
</div>

<style>
	.column {
		max-width: var(--column);
		margin: 0 auto;
		padding: 0 24px;
	}
	header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 32px 0;
	}
	.brand {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		text-decoration: none;
		color: var(--slate-12);
	}
	.mark {
		display: inline-flex;
		color: var(--slate-11);
	}
	nav {
		display: flex;
		gap: 4px;
	}
	nav a,
	footer a {
		text-decoration: none;
		color: var(--slate-10);
		transition: color 150ms var(--ease-out), background-color 150ms var(--ease-out);
	}
	nav a {
		padding: 6px 12px;
		border-radius: 8px;
	}
	@media (hover: hover) {
		nav a:hover,
		footer a:hover {
			color: var(--slate-12);
		}
	}
	nav a[aria-current='page'] {
		background: var(--indigo-4);
		color: var(--indigo-11);
	}
	main {
		display: grid;
		padding-bottom: 96px;
	}
	/* Outgoing and incoming pages overlap in one cell rather than stacking. */
	.page {
		grid-area: 1 / 1;
		min-width: 0;
	}
	footer {
		display: flex;
		justify-content: space-between;
		gap: 16px;
		padding: 32px 0 48px;
		border-top: 2px solid var(--slate-3);
	}
	.links {
		display: flex;
		gap: 16px;
	}
</style>
