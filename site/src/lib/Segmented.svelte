<script>
	import { press } from './motion.js';

	/**
	 * Options on a filled track; the chosen one is indigo, like the app.
	 * A radio group: Tab reaches the chosen option, arrow keys move the choice.
	 */
	let { options, value = $bindable(), label } = $props();
	let buttons = [];

	function onkeydown(event, index) {
		const last = options.length - 1;
		const next = {
			ArrowRight: index === last ? 0 : index + 1,
			ArrowDown: index === last ? 0 : index + 1,
			ArrowLeft: index === 0 ? last : index - 1,
			ArrowUp: index === 0 ? last : index - 1,
			Home: 0,
			End: last
		}[event.key];
		if (next === undefined) return;
		event.preventDefault();
		value = options[next].value;
		buttons[next]?.focus();
	}
</script>

<div class="track" role="radiogroup" aria-label={label}>
	{#each options as option, i}
		<button
			bind:this={buttons[i]}
			role="radio"
			aria-checked={value === option.value}
			tabindex={value === option.value ? 0 : -1}
			class="caption hit"
			class:selected={value === option.value}
			use:press
			onclick={() => (value = option.value)}
			onkeydown={(e) => onkeydown(e, i)}
		>
			{option.label}
		</button>
	{/each}
</div>

<style>
	.track {
		display: inline-flex;
		gap: 4px;
		padding: 4px;
		border-radius: 10px;
		background: var(--slate-4);
	}
	button {
		height: 32px;
		padding: 0 12px;
		border: 0;
		border-radius: 6px;
		background: transparent;
		color: var(--slate-11);
		font: inherit;
		cursor: pointer;
		transition: background-color 150ms var(--ease-out), color 150ms var(--ease-out);
	}
	@media (hover: hover) {
		button:hover {
			color: var(--slate-12);
		}
	}
	.selected,
	.selected:hover {
		background: var(--indigo-4);
		color: var(--indigo-11);
	}
</style>
