<script>
	import { onMount } from 'svelte';
	import { profiles, layout, caseFinish, glowColor, lightingMath, radii } from './model.js';
	import { playSwitch } from './sound.js';
	import { reducedMotion } from '../motion.js';
	import { pop, unpop } from '../transitions.js';

	/**
	 * The board, drawn the way the macOS app draws it and just as pressable:
	 * pointer, touch, Tab + Enter/Space, or the number keys 1–9 and 0.
	 * Clicking a key that isn't running "launches" it: its LED comes on.
	 */
	let { keys, settings, label = 'Marbly keyboard. Press the keys, or type 1 to 0.', typeable = true } = $props();

	let width = $state(0);
	let pressed = $state(new Set());
	let hovered = $state(null);
	// The tooltip lives at board level: the wells clip their contents (for the backlight),
	// so a tooltip inside a key would be cut off.
	let fitEl;
	let tip = $state(null);

	function showTip(key, el) {
		hovered = key.index;
		const fit = fitEl.getBoundingClientRect();
		const r = el.getBoundingClientRect();
		tip = { name: key.name, x: r.left - fit.left + r.width / 2, y: r.top - fit.top };
	}

	function hideTip(key) {
		if (hovered !== key.index) return;
		hovered = null;
		tip = null;
	}
	let running = $state(new Set());
	let capEls = [];

	$effect(() => {
		running = new Set(keys.flatMap((k, i) => (k.running ? [i] : [])));
	});

	const profile = $derived(profiles[settings.profile]);
	const light = $derived(lightingMath(settings.lighting));
	const finish = $derived(caseFinish(settings.caseColor));

	// Keys split into wells at spacers, keeping each key's index.
	const groups = $derived.by(() => {
		const out = [[]];
		keys.forEach((k, i) => {
			if (k.spacer) {
				if (out.at(-1).length) out.push([]);
			} else out.at(-1).push({ ...k, index: i });
		});
		return out.filter((g) => g.length);
	});
	const appKeys = $derived(groups.flat());

	// Largest key size that fits, capped at the chosen size.
	const unit = $derived.by(() => {
		const n = groups.length;
		const across = 2 * layout.caseWall + n * 2 * layout.plate + appKeys.length * (1 + layout.spacing) + (n - 1) * layout.gap;
		return width ? Math.min(settings.keySize, (width - 8) / across) : settings.keySize;
	});
	const r = $derived(radii(unit, profile));
	const plateRadius = $derived(r.cap + unit * layout.plate);
	const caseRadius = $derived(plateRadius + unit * layout.caseWall);

	const pan = (i) => (appKeys.length > 1 ? (appKeys.findIndex((k) => k.index === i) / (appKeys.length - 1)) * 1.2 - 0.6 : 0);

	function down(i) {
		if (pressed.has(i)) return;
		pressed = new Set(pressed).add(i);
		if (settings.sound) playSwitch(settings.switchType, 'down', settings.volume, pan(i));
		const cap = capEls[i];
		if (cap && !reducedMotion()) {
			cap.animate([{ transform: `translateY(${unit * profile.travel}px)` }], {
				duration: 40,
				easing: 'cubic-bezier(0.22, 1, 0.36, 1)',
				fill: 'forwards'
			});
		}
	}

	function up(i, activate = true) {
		if (!pressed.has(i)) return;
		const next = new Set(pressed);
		next.delete(i);
		pressed = next;
		if (settings.sound && settings.releaseSounds) playSwitch(settings.switchType, 'up', settings.volume, pan(i));
		const cap = capEls[i];
		if (cap && !reducedMotion()) {
			cap.animate([{ transform: `translateY(${unit * profile.travel}px)` }, { transform: 'translateY(0)' }], {
				duration: 260,
				easing: 'cubic-bezier(0.34, 1.56, 0.64, 1)',
				fill: 'forwards'
			});
		}
		if (activate && !running.has(i)) running = new Set(running).add(i);
	}

	// Number keys 1–9 and 0 press the first ten keys, so the board can be "typed" on.
	onMount(() => {
		if (!typeable) return;
		const keyFor = (e) => {
			if (e.metaKey || e.ctrlKey || e.altKey) return;
			if (/^(input|textarea|select)$/i.test(e.target?.tagName ?? '')) return;
			const n = '1234567890'.indexOf(e.key);
			return n >= 0 && n < appKeys.length ? appKeys[n].index : undefined;
		};
		const onDown = (e) => {
			const i = keyFor(e);
			if (i !== undefined && !e.repeat) down(i);
		};
		const onUp = (e) => {
			const i = keyFor(e);
			if (i !== undefined) up(i);
		};
		addEventListener('keydown', onDown);
		addEventListener('keyup', onUp);
		return () => {
			removeEventListener('keydown', onDown);
			removeEventListener('keyup', onUp);
		};
	});

	function wellBackground() {
		switch (settings.gapFill) {
			case 'body': return finish.recess;
			case 'color': return settings.gapColor;
			case 'backlight': return finish.backlit;
			default: return finish.plate;
		}
	}
</script>

<div class="fit" bind:clientWidth={width} bind:this={fitEl}>
	<div
		class="board"
		class:reflect={settings.reflection}
		role="group"
		aria-label={label}
		style:--u="{unit}px"
		style:--case-radius="{caseRadius}px"
		style:--plate-radius="{plateRadius}px"
		style:--cap-radius="{r.cap}px"
		style:--face-radius="{r.face}px"
		style:background="linear-gradient({finish.top}, {finish.bottom})"
		style:box-shadow="inset 0 1px 0 rgb(255 255 255 / {finish.bevel}), inset 0 -1px 0 rgb(0 0 0 / 0.4), {unit * light.shadowX * 2}px {unit * (0.04 + 0.1 * settings.lighting.shadow)}px {unit * 0.36}px rgb(0 0 0 / {0.6 * settings.lighting.shadow})"
	>
		{#each groups as group}
			<div
				class="well"
				style:background={wellBackground()}
				style:box-shadow="inset 0 {unit * 0.03}px {unit * 0.06}px rgb(0 0 0 / {settings.gapFill === 'plate' || settings.gapFill === 'backlight' ? 0.7 : 0.45})"
			>
				{#each group as key (key.index)}
					{@const p = key.palette}
					{@const isDown = pressed.has(key.index)}
					<button
						class="key"
						aria-label={key.name}
						aria-pressed={isDown}
						onpointerdown={(e) => {
							e.currentTarget.setPointerCapture(e.pointerId);
							down(key.index);
						}}
						onpointerup={() => up(key.index)}
						onpointercancel={() => up(key.index, false)}
						onkeydown={(e) => {
							if ((e.key === 'Enter' || e.key === ' ') && !e.repeat) {
								e.preventDefault();
								down(key.index);
							}
						}}
						onkeyup={(e) => {
							if (e.key === 'Enter' || e.key === ' ') up(key.index);
						}}
						onpointerenter={(e) => showTip(key, e.currentTarget)}
						onpointerleave={() => hideTip(key)}
						onfocus={(e) => showTip(key, e.currentTarget)}
						onblur={() => hideTip(key)}
					>
						{#if settings.gapFill === 'backlight'}
							<span
								class="glow"
								style:background="radial-gradient(circle closest-side, transparent 45%, {glowColor(p.base)} 46%, color-mix(in srgb, {glowColor(p.base)} 30%, transparent) 72%, transparent)"
								style:opacity={settings.backlight * 0.9}
							></span>
						{/if}
						<span
							class="contact"
							style:transform="translate({unit * light.shadowX}px, {unit * (isDown ? 0.03 : 0.04 + 0.07 * settings.lighting.shadow)}px)"
							style:background="linear-gradient(transparent, rgb(0 0 0 / {(isDown ? 0.45 : 0.75) * settings.lighting.shadow}))"
						></span>
						<span class="cap" bind:this={capEls[key.index]}>
							<span
								class="walls"
								style:background="linear-gradient(90deg, rgb(0 0 0 / {light.leftShade}), transparent 16%, transparent 84%, rgb(0 0 0 / {light.rightShade})), linear-gradient({p.wallLight}, {p.wallDark})"
								style:box-shadow="inset 0 0 0 0.5px rgb(0 0 0 / 0.35), inset {-light.lx * 1.5}px {-light.ly * 1.5}px 0 rgb(255 255 255 / {light.rim * 0.5})"
							></span>
							<span
								class="face"
								style:top="{unit * profile.inset.top}px"
								style:left="{unit * profile.inset.side}px"
								style:right="{unit * profile.inset.side}px"
								style:bottom="{unit * profile.inset.bottom}px"
								style:background="linear-gradient({p.faceTop}, {p.base})"
								style:box-shadow="inset 0 0 0 {Math.max(1, unit * 0.03)}px color-mix(in srgb, {p.wallDark} 35%, transparent), inset {-light.lx * 1.5}px {-light.ly * 1.5}px 0 rgb(255 255 255 / {light.rim}), inset {light.lx * 1.5}px {light.ly * 1.5}px 0 rgb(0 0 0 / {light.rim * 0.4})"
							>
								{#if settings.legend === 'icon'}
									<img src="/keys/{key.icon}" alt="" draggable="false" />
									{#if key.windowNumber}
										<!-- Which window, printed thick top-left in the key's own colour. -->
										<span class="number" style:background={p.base} style:color={p.legend}>{key.windowNumber}</span>
									{/if}
								{:else}
									<span class="name" style:color={p.legend}>{key.name}</span>
								{/if}
								<!-- Concave dish: shaded toward the light, lit on the far wall. -->
								<span
									class="shade soft"
									style:background="linear-gradient({light.cssAngle}deg, rgb(0 0 0 / {profile.dish * 4}), transparent 50%, rgb(255 255 255 / {profile.dish * 2.5}))"
								></span>
								<span
									class="shade multiply"
									style:background="radial-gradient(circle {unit * 0.36}px at 50% 56%, rgb({255 * (1 - profile.dish * 1.6)} {255 * (1 - profile.dish * 1.6)} {255 * (1 - profile.dish * 1.6)}), white), linear-gradient(rgb({255 * (1 - profile.dish * 2)} {255 * (1 - profile.dish * 2)} {255 * (1 - profile.dish * 2)}), white 20%)"
								></span>
								<span
									class="shade screen"
									style:background="linear-gradient({light.cssAngle}deg, rgb(255 255 255 / {light.peak * 0.8}) 0%, rgb(255 255 255 / {light.peak * 0.2}) {light.falloff * 60}%, transparent {light.falloff * 100}%)"
								></span>
								<!-- Glare: a soft spot of reflected light on the side the light comes from. -->
								<span
									class="shade screen"
									style:background="radial-gradient(circle {unit * light.glareRadius}px at {50 + light.lx * 30}% {50 + light.ly * 30}%, rgb(255 255 255 / {light.glare}), transparent)"
								></span>
								<span class="led" class:on={running.has(key.index)}></span>
							</span>
						</span>
					</button>
				{/each}
			</div>
		{/each}
	</div>
	{#if tip && !pressed.has(hovered)}
		{#key tip.name}
			<span class="tip caption" role="tooltip" style:left="{tip.x}px" style:top="{tip.y}px" in:pop out:unpop
				>{tip.name}</span
			>
		{/key}
	{/if}
</div>

<style>
	.fit {
		/* Full width, so the measured space is what's available, not the board itself. */
		position: relative;
		width: 100%;
		display: flex;
		justify-content: center;
		padding: calc(var(--u, 56px) * 0.7) 0 0;
		user-select: none;
		-webkit-user-select: none;
	}
	.board {
		display: flex;
		gap: calc(var(--u) * 0.22);
		padding: calc(var(--u) * 0.12);
		border-radius: var(--case-radius);
		transition: background 200ms cubic-bezier(0.22, 1, 0.36, 1);
	}
	.board.reflect {
		margin-bottom: calc(var(--u) * 0.6);
		-webkit-box-reflect: below calc(var(--u) * 0.04) linear-gradient(transparent 52%, rgb(0 0 0 / 0.3));
	}
	.well {
		position: relative;
		display: flex;
		gap: calc(var(--u) * 0.07);
		padding: calc(var(--u) * 0.14);
		border-radius: var(--plate-radius);
		/* Glows stay inside the well, like light under the plate. */
		overflow: hidden;
		isolation: isolate;
	}
	.key {
		position: relative;
		width: var(--u);
		height: var(--u);
		padding: 0;
		border: 0;
		background: none;
		cursor: pointer;
		touch-action: manipulation;
		-webkit-tap-highlight-color: transparent;
	}
	.key:focus-visible {
		outline: 2px solid var(--indigo-9);
		outline-offset: 3px;
		border-radius: var(--cap-radius);
	}
	.glow {
		position: absolute;
		inset: -40%;
		mix-blend-mode: plus-lighter;
		pointer-events: none;
	}
	.contact,
	.cap,
	.walls,
	.shade {
		position: absolute;
		inset: 0;
		pointer-events: none;
	}
	.contact {
		inset: 0 calc(var(--u) * 0.02);
		border-radius: var(--cap-radius);
	}
	.cap {
		border-radius: var(--cap-radius);
	}
	.walls {
		border-radius: var(--cap-radius);
	}
	.face {
		position: absolute;
		overflow: hidden;
		border-radius: var(--face-radius);
		isolation: isolate;
	}
	.face img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		transform: scale(1.04);
	}
	.name {
		position: absolute;
		inset: calc(var(--u) * 0.07);
		font-size: max(8px, calc(var(--u) * 0.14));
		font-weight: 500;
		line-height: 1.15;
		text-align: left;
		overflow: hidden;
	}
	.number {
		position: absolute;
		top: calc(var(--u) * 0.06);
		left: calc(var(--u) * 0.06);
		min-width: calc(var(--u) * 0.23);
		padding: 0 calc(var(--u) * 0.03);
		border-radius: calc(var(--u) * 0.06);
		box-shadow: 0 calc(var(--u) * 0.01) calc(var(--u) * 0.03) rgb(0 0 0 / 0.25);
		font-size: max(8px, calc(var(--u) * 0.2));
		font-weight: 600;
		font-variant-numeric: tabular-nums;
		line-height: 1.2;
		text-align: center;
		z-index: 1;
	}
	.soft {
		mix-blend-mode: soft-light;
	}
	.multiply {
		mix-blend-mode: multiply;
	}
	.screen {
		mix-blend-mode: screen;
	}
	.led {
		position: absolute;
		top: calc(var(--u) * 0.06);
		right: calc(var(--u) * 0.06);
		width: calc(var(--u) * 0.075);
		height: calc(var(--u) * 0.075);
		border-radius: 50%;
		background: rgb(0 0 0 / 0.35);
		transition: background 200ms cubic-bezier(0.22, 1, 0.36, 1), box-shadow 200ms cubic-bezier(0.22, 1, 0.36, 1);
	}
	.led.on {
		background: radial-gradient(circle at 40% 35%, white, rgb(140 255 190));
		box-shadow: 0 0 calc(var(--u) * 0.06) rgb(140 255 190 / 0.6);
	}
	.tip {
		position: absolute;
		transform: translate(-50%, calc(-100% - 8px));
		/* Grows from the key it points at. */
		transform-origin: 50% 100%;
		padding: 4px 10px;
		border-radius: 999px;
		/* Inverted (slate-12 on slate-1), so it stands out on light and dark pages alike. */
		background: var(--slate-12);
		color: var(--slate-1);
		box-shadow: 0 4px 12px rgb(0 0 0 / 0.2);
		white-space: nowrap;
		pointer-events: none;
		z-index: 1;
	}
</style>
