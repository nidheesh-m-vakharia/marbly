<script>
	import Segmented from '../Segmented.svelte';
	import Slider from '../Slider.svelte';
	import Switch from '../Switch.svelte';
	import { themes, caseSwatches, profiles, gapFills, caseFinish } from './model.js';
	import { switches, playSwitch } from './sound.js';
	import { press } from '../motion.js';
	import { rise, sink, reveal } from '../transitions.js';

	/** The app's settings, live: every change redraws the board above. */
	let { settings } = $props();

	let tab = $state('look');
	const tabs = [
		{ value: 'look', label: 'Look' },
		{ value: 'lighting', label: 'Lighting' },
		{ value: 'keys', label: 'Keys' },
		{ value: 'sound', label: 'Sound' }
	];

	const activeTheme = $derived(
		themes.find(
			(t) =>
				t.caseColor.toLowerCase() === settings.caseColor.toLowerCase() &&
				t.profile === settings.profile &&
				JSON.stringify(t.lighting) === JSON.stringify(settings.lighting)
		)
	);

	function applyTheme(t) {
		settings.caseColor = t.caseColor;
		settings.profile = t.profile;
		settings.lighting = { ...t.lighting };
	}

	const direction = (a) =>
		`${a < -60 ? 'Left' : a < -15 ? 'Upper left' : a <= 15 ? 'Above' : a <= 60 ? 'Upper right' : 'Right'} · ${a < 0 ? '−' : ''}${Math.abs(Math.round(a))}°`;
	const gloss = (v) => (v < 0.34 ? 'Matte' : v < 0.67 ? 'Satin' : 'Polished');
</script>

<div class="editor">
	<div class="tabs">
		<Segmented label="Editor section" options={tabs} bind:value={tab} />
	</div>

	<!-- Panels share one grid cell, so the outgoing and incoming panel overlap
	     instead of stacking while they cross-fade. -->
	<div class="panels">
		{#key tab}
			<div class="panel" in:rise={{ delay: 60 }} out:sink>
			{#if tab === 'look'}
				<section>
					<p class="caption muted">Themes pair a case colour, keycap shape and lighting.</p>
					<div class="themes">
						{#each themes as t}
							{@const f = caseFinish(t.caseColor)}
							<button
								class="theme"
								class:selected={activeTheme?.id === t.id}
								aria-pressed={activeTheme?.id === t.id}
								use:press
								onclick={() => applyTheme(t)}
							>
								<span class="swatch" style:background="linear-gradient({f.top}, {f.bottom})">
									<span style:background={f.plate}></span>
								</span>
								<span class="caption">{t.name}</span>
							</button>
						{/each}
					</div>
					{#if !activeTheme}<p class="caption faint" in:rise out:sink>Custom</p>{/if}
				</section>
				<section class="box rows">
					<div class="row">
						<div><p>Case colour</p><p class="caption muted">The plate and bevel are shaded from it.</p></div>
					</div>
					<div class="swatches">
						{#each caseSwatches as c}
							<button
								class="dot hit"
								class:selected={settings.caseColor.toLowerCase() === c.toLowerCase()}
								style:background={c}
								aria-label="Case colour {c}"
								aria-pressed={settings.caseColor.toLowerCase() === c.toLowerCase()}
								onclick={() => (settings.caseColor = c)}
							></button>
						{/each}
						<label class="custom hit" aria-label="Custom case colour">
							<input
								type="color"
								value={settings.caseColor.toLowerCase()}
								oninput={(e) => (settings.caseColor = e.currentTarget.value)}
							/>
						</label>
					</div>
				</section>
			{:else if tab === 'lighting'}
				<section class="box stack">
					<Slider label="Direction" bind:value={settings.lighting.angle} min={-90} max={90} step={1} format={direction} />
					<Slider label="Highlight" bind:value={settings.lighting.intensity} />
					<Slider label="Gloss" bind:value={settings.lighting.gloss} format={gloss} />
					<Slider label="Shadow" bind:value={settings.lighting.shadow} />
				</section>
			{:else if tab === 'keys'}
				<section class="box rows">
					<div class="row">
						<div><p>Keycap profile</p><p class="caption muted">Shape and travel.</p></div>
						<Segmented label="Keycap profile" options={Object.entries(profiles).map(([value, p]) => ({ value, label: p.label }))} bind:value={settings.profile} />
					</div>
					<div class="row">
						<div><p>Between keys</p><p class="caption muted">What fills the gaps.</p></div>
						<Segmented label="Between keys" options={Object.entries(gapFills).map(([value, label]) => ({ value, label }))} bind:value={settings.gapFill} />
					</div>
					{#if settings.gapFill === 'color'}
						<div class="row">
							<div><p>Gap colour</p><p class="caption muted">Shaded so the gaps still look recessed.</p></div>
							<label class="custom hit" aria-label="Gap colour"><input
								type="color"
								value={settings.gapColor.toLowerCase()}
								oninput={(e) => (settings.gapColor = e.currentTarget.value)}
							/></label>
						</div>
					{/if}
					{#if settings.gapFill === 'backlight'}
						<div class="pad" transition:reveal><Slider label="Backlight" bind:value={settings.backlight} min={0.1} max={1} /></div>
					{/if}
					<div class="pad"><Slider label="Key size" bind:value={settings.keySize} min={40} max={72} step={1} format={(v) => `${Math.round(v)} pt`} /></div>
					<div class="row">
						<div><p>Legend</p><p class="caption muted">What's printed on each key.</p></div>
						<Segmented label="Legend" options={[{ value: 'icon', label: 'Icon' }, { value: 'name', label: 'Name' }]} bind:value={settings.legend} />
					</div>
					<div class="row">
						<div><p>Reflection</p><p class="caption muted">A faded mirror image below.</p></div>
						<Switch label="Reflection" bind:checked={settings.reflection} />
					</div>
				</section>
			{:else}
				<section>
					<p class="caption muted">Choose a switch to hear it. Then press the keys, or type 1 to 0.</p>
					<div class="switches">
						{#each switches as s}
							<button
								class="chip caption"
								class:selected={settings.switchType === s.id}
								aria-pressed={settings.switchType === s.id}
								use:press
								onclick={() => {
									settings.switchType = s.id;
									if (settings.sound) playSwitch(s.id, 'down', settings.volume);
								}}>{s.label}</button
							>
						{/each}
					</div>
				</section>
				<section class="box rows">
					<div class="row">
						<div><p>Key sounds</p><p class="caption muted">A switch sound when a key goes down.</p></div>
						<Switch label="Key sounds" bind:checked={settings.sound} />
					</div>
					<div class="row">
						<div><p>Release sounds</p><p class="caption muted">The softer sound as it comes back up.</p></div>
						<Switch label="Release sounds" bind:checked={settings.releaseSounds} />
					</div>
					<div class="pad"><Slider label="Volume" bind:value={settings.volume} /></div>
				</section>
			{/if}
			</div>
		{/key}
	</div>
</div>

<style>
	.editor {
		display: grid;
		gap: 16px;
	}
	.tabs {
		display: flex;
		justify-content: center;
	}
	.panels {
		display: grid;
	}
	.panel {
		grid-area: 1 / 1;
		display: grid;
		gap: 12px;
		align-content: start;
	}
	section {
		display: grid;
		gap: 12px;
	}
	.box.rows,
	.box.stack {
		gap: 2px;
		padding: 4px;
		border-radius: 10px;
	}
	.box.stack {
		gap: 4px;
	}
	.row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
		min-height: 52px;
		padding: 10px 12px;
	}
	.row p:first-child {
		margin-bottom: 2px;
	}
	.pad {
		padding: 4px;
	}
	.themes {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 8px;
	}
	.theme,
	.chip {
		border: 0;
		font: inherit;
		color: var(--slate-12);
		background: var(--slate-2);
		cursor: pointer;
		transition: background-color 150ms var(--ease-out), color 150ms var(--ease-out);
	}
	.theme {
		display: grid;
		gap: 8px;
		padding: 8px 8px 10px;
		border-radius: 14px;
		text-align: left;
	}
	.swatch {
		display: grid;
		place-items: center;
		height: 36px;
		border-radius: 8px;
	}
	.swatch span {
		width: 60%;
		height: 12px;
		border-radius: 4px;
	}
	.theme .caption {
		padding: 0 4px;
	}
	.switches {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 8px;
	}
	.chip {
		height: 40px;
		border-radius: 10px;
	}
	@media (hover: hover) {
		.theme:hover,
		.chip:hover {
			background: var(--slate-3);
		}
	}
	.theme.selected,
	.chip.selected {
		background: var(--indigo-4);
		color: var(--indigo-11);
	}
	.swatches {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
		padding: 0 12px 12px;
	}
	.dot {
		width: 24px;
		height: 24px;
		padding: 0;
		border: 0;
		border-radius: 50%;
		cursor: pointer;
		box-shadow: inset 0 0 0 1px rgb(0 0 0 / 0.12);
	}
	.dot.selected {
		box-shadow: 0 0 0 2px var(--slate-1), 0 0 0 4px var(--indigo-9);
	}
	.custom {
		display: inline-grid;
		place-items: center;
		width: 24px;
		height: 24px;
		border-radius: 50%;
		overflow: hidden;
		background: conic-gradient(red, yellow, lime, cyan, blue, magenta, red);
		cursor: pointer;
	}
	.custom input {
		opacity: 0;
		width: 100%;
		height: 100%;
		cursor: pointer;
	}
	@media (max-width: 520px) {
		.row {
			flex-wrap: wrap;
		}
		.switches {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}
</style>
