<script>
	import Icon from './Icon.svelte';
	import { press } from './motion.js';
	import { swap } from './transitions.js';

	/** A command with a copy button; the button shows a check for 1.5 s after copying. */
	let { code } = $props();
	let copied = $state(false);
	let timer;

	async function copy() {
		try {
			await navigator.clipboard.writeText(code);
		} catch {
			return;
		}
		copied = true;
		clearTimeout(timer);
		timer = setTimeout(() => (copied = false), 1500);
	}
</script>

<div class="code box">
	<!-- Focusable so a long command can be scrolled with the keyboard. -->
	<pre class="caption" tabindex="0" aria-label="Command"><code>{code}</code></pre>
	<button class="copy hit" use:press onclick={copy} aria-label="Copy command">
		{#key copied}
			<span class="icon" in:swap><Icon name={copied ? 'check' : 'copy'} size={16} /></span>
		{/key}
	</button>
	<span class="sr-only" aria-live="polite">{copied ? 'Copied' : ''}</span>
</div>

<style>
	.code {
		position: relative;
		border-radius: 10px;
	}
	pre {
		margin: 0;
		padding: 14px 52px 14px 16px;
		overflow-x: auto;
		font-family: ui-monospace, 'SF Mono', Menlo, monospace;
		letter-spacing: 0;
		line-height: 1.6;
	}
	.copy {
		position: absolute;
		top: 8px;
		right: 8px;
		display: grid;
		place-items: center;
		width: 32px;
		height: 32px;
		border: 0;
		border-radius: 8px;
		background: transparent;
		color: var(--slate-11);
		cursor: pointer;
		transition: background-color 150ms var(--ease-out), color 150ms var(--ease-out);
	}
	@media (hover: hover) {
		.icon {
		display: grid;
		place-items: center;
	}
	.copy:hover {
			background: var(--slate-4);
			color: var(--slate-12);
		}
	}
</style>
