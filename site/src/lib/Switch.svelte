<script>
	/** Pill switch: grey track off, indigo on, the knob springs across. */
	let { label, checked = $bindable() } = $props();
</script>

<button class="switch hit" role="switch" aria-checked={checked} aria-label={label} onclick={() => (checked = !checked)}>
	<span class="knob"></span>
</button>

<style>
	.switch {
		position: relative;
		width: 40px;
		height: 24px;
		flex: none;
		padding: 0;
		border: 0;
		border-radius: 999px;
		background: var(--slate-5);
		cursor: pointer;
		transition: background-color 150ms var(--ease-out);
	}
	.switch[aria-checked='true'] {
		background: var(--indigo-9);
	}
	.knob {
		position: absolute;
		top: 3px;
		left: 3px;
		width: 18px;
		height: 18px;
		border-radius: 50%;
		background: var(--slate-11);
		transition: transform 200ms var(--ease-spring), background-color 150ms var(--ease-out);
	}
	.switch[aria-checked='true'] .knob {
		transform: translateX(16px);
		background: white;
	}
	@media (prefers-reduced-motion: reduce) {
		.knob {
			transition: none;
		}
	}
</style>
