<script>
	/**
	 * The app's slider: label and value inside a filled track, a thin bar marking the
	 * position. Drag, click, or use the arrow keys (Shift for bigger steps).
	 */
	let { label, value = $bindable(), min = 0, max = 1, step = 0.01, format = (v) => `${Math.round(v * 100)}%` } = $props();
	let track;
	let dragging = $state(false);
	const fraction = $derived((value - min) / (max - min));

	function set(clientX) {
		const r = track.getBoundingClientRect();
		const f = Math.min(1, Math.max(0, (clientX - r.left - 4) / (r.width - 8)));
		value = Math.round((min + f * (max - min)) / step) * step;
	}

	function onkeydown(e) {
		const big = (max - min) / 10;
		const delta = { ArrowRight: step, ArrowUp: step, ArrowLeft: -step, ArrowDown: -step, PageUp: big, PageDown: -big }[e.key];
		if (e.key === 'Home') value = min;
		else if (e.key === 'End') value = max;
		else if (delta !== undefined) value = Math.min(max, Math.max(min, value + delta * (e.shiftKey ? 10 : 1)));
		else return;
		e.preventDefault();
	}
</script>

<div
	class="slider"
	class:dragging
	bind:this={track}
	role="slider"
	tabindex="0"
	aria-label={label}
	aria-valuemin={min}
	aria-valuemax={max}
	aria-valuenow={value}
	aria-valuetext={format(value)}
	style:--f={fraction}
	onpointerdown={(e) => {
		e.currentTarget.setPointerCapture(e.pointerId);
		dragging = true;
		set(e.clientX);
	}}
	onpointermove={(e) => dragging && set(e.clientX)}
	onpointerup={() => (dragging = false)}
	onpointercancel={() => (dragging = false)}
	{onkeydown}
>
	<span class="fill"></span>
	<span class="thumb"></span>
	<span class="label caption">{label}</span>
	<span class="value caption">{format(value)}</span>
</div>

<style>
	.slider {
		position: relative;
		height: 44px;
		border-radius: 10px;
		background: var(--slate-3);
		cursor: ew-resize;
		touch-action: none;
		user-select: none;
	}
	.fill {
		position: absolute;
		top: 4px;
		bottom: 4px;
		left: 4px;
		width: max(16px, calc((100% - 8px) * var(--f)));
		border-radius: 6px;
		background: var(--slate-5);
	}
	.thumb {
		position: absolute;
		top: 50%;
		left: calc(4px + max(16px, (100% - 8px) * var(--f)) - 10px);
		width: 4px;
		height: 20px;
		border-radius: 2px;
		background: var(--slate-12);
		transform: translateY(-50%);
		transition: height 200ms var(--ease-spring);
	}
	.dragging .thumb {
		height: 24px;
	}
	.label,
	.value {
		position: absolute;
		top: 50%;
		transform: translateY(-50%);
		pointer-events: none;
	}
	.label {
		left: 16px;
		font-weight: 500;
	}
	.value {
		right: 16px;
		color: var(--slate-11);
		font-variant-numeric: tabular-nums;
	}
</style>
