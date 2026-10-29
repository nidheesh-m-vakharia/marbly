<script>
	import Icon from '#lib/Icon.svelte';
	import Logo from '#lib/Logo.svelte';
	import Segmented from '#lib/Segmented.svelte';
	import Shot from '#lib/Shot.svelte';
	import { tick } from 'svelte';
	import { intro, press, swapIn, keyPress, thock, prefetch } from '#lib/motion.js';
	import Board from '#lib/board/Board.svelte';
	import Editor from '#lib/board/Editor.svelte';
	import keys from '#lib/board/keys.json';
	import { themes } from '#lib/board/model.js';

	// The live board's settings, starting from the Graphite theme like the app.
	const graphite = themes[0];

	// Two Finder windows, each with its own key, numbered top-left.
	const finder = keys.find((k) => k.name === 'Finder');
	const windowKeys = [
		{ ...finder, name: 'Downloads', window: 'Downloads', windowNumber: 1, running: true },
		{ ...finder, name: 'Projects', window: 'Projects', windowNumber: 2, running: true }
	];
	let settings = $state({
		caseColor: graphite.caseColor,
		profile: graphite.profile,
		lighting: { ...graphite.lighting },
		gapFill: 'plate',
		gapColor: '#3E63DD',
		backlight: 0.7,
		keySize: 56,
		legend: 'icon',
		reflection: true,
		sound: true,
		releaseSounds: true,
		volume: 0.5,
		switchType: 'thock'
	});

	const pages = [
		{ value: 'appearance', label: 'Appearance' },
		{ value: 'keyboard', label: 'Keyboard' },
		{ value: 'sound', label: 'Sound' }
	];
	let settingsPage = $state('appearance');
	let settingsEl = $state();

	// Cross-fade only when the visitor switches, never on load, and only once
	// Svelte has put the new image in place.
	async function pickPage(v) {
		if (v === settingsPage) return;
		settingsPage = v;
		await tick();
		swapIn(settingsEl);
	}

	// The other boards and settings pages, ready before anyone clicks.
	$effect(() => {
		const dark = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
		prefetch(pages.slice(1).map((p) => `/showcase/settings-${p.value}-${dark}.png`));
	});

	let heroMark;
	function pressHero() {
		keyPress(heroMark);
		thock();
	}

	const features = [
		{ icon: 'palette', title: 'Coloured by your icons', text: "Each keycap takes its colour from the app's icon edge, so the walls continue the face." },
		{ icon: 'volume', title: 'Real switch sounds', text: 'Eight switches rendered with mechsound, from deep Thock to crisp Blue. Press, and release.' },
		{ icon: 'window', title: 'A key for every window', text: 'Apps with several windows get a key each, numbered in the corner. Click one to bring that window forward.' },
		{ icon: 'eye', title: 'Out of the way', text: 'Hides like the Dock, slides up at the bottom edge, and steps aside for the real Dock in Mission Control.' },
		{ icon: 'cpu', title: 'Light on your Mac', text: 'Nothing polls. At rest Marbly sits at 0% CPU and around 30 MB of memory.' }
	];
</script>

<svelte:head>
	<title>Marbly · Your Dock, as a mechanical keyboard</title>
	<meta name="description" content="Marbly turns your Mac's Dock into a row of mechanical keycaps, coloured by each app's icon, with real switch sounds." />
</svelte:head>

<div use:intro>
	<section class="hero">
		<button
			class="hero-mark"
			data-intro
			aria-label="Press the Marbly key"
			onpointerdown={pressHero}
			onclick={(e) => {
				// Keyboard activation (Enter/Space) arrives as a click with no pointer.
				if (e.detail === 0) pressHero();
			}}
		>
			<span bind:this={heroMark}><Logo size={56} /></span>
		</button>
		<h1 class="title" data-intro>Your Dock, as a mechanical keyboard.</h1>
		<p class="muted" data-intro>
			Marbly turns the apps in your Dock into sculpted keycaps, each coloured from its icon,
			lit, shaded and reflected, with a real switch sound when you press one.
		</p>
		<div class="actions" data-intro>
			<a class="button primary" href="/guide#install" use:press>
				<Icon name="download" size={16} />Get Marbly
			</a>
			<a class="button secondary" href="/guide" use:press>Read the guide</a>
		</div>
		<p class="caption faint" data-intro>Free · macOS 14 or later</p>
	</section>

	<!-- The real board, live: press the keys, then restyle it below. -->
	<section class="showcase" data-intro>
		<Board {keys} {settings} />
	</section>
	<section class="editor" data-intro>
		<Editor {settings} />
	</section>
</div>

<section class="features">
	{#each features as f}
		<article>
			<span class="icon"><Icon name={f.icon} size={20} /></span>
			<div>
				<h2 class="body-medium">{f.title}</h2>
				<p class="caption muted">{f.text}</p>
			</div>
		</article>
	{/each}
</section>

<section class="block">
	<header>
		<h2 class="heading">One key per window</h2>
		<p class="caption muted">Each window gets its own key, numbered in the corner.</p>
	</header>
	<div class="box framed">
		<Board keys={windowKeys} settings={{ ...settings, keySize: 88, reflection: false }} typeable={false} label="Two Finder keys, window 1 Downloads and window 2 Projects" />
	</div>
</section>

<section class="block">
	<header>
		<h2 class="heading">Make it yours</h2>
		<p class="caption muted">Themes, lighting, keycap profiles, backlights and switch sounds, all with a live preview.</p>
	</header>
	<div class="switcher start">
		<Segmented label="Settings page" options={pages} bind:value={() => settingsPage, pickPage} />
	</div>
	<div class="box framed screen" bind:this={settingsEl}>
		<Shot name="settings-{settingsPage}" alt="Marbly's {settingsPage} settings" width="1800" height="1400" />
	</div>
</section>

<section class="block">
	<header>
		<h2 class="heading">Always a click away</h2>
		<p class="caption muted">Mute the keys, hide the board or jump to a setting from the menu bar.</p>
	</header>
	<div class="box framed menu">
		<Shot name="menu" alt="Marbly's menu bar menu" width="528" height="280" />
	</div>
</section>

<section class="cta box">
	<h2 class="heading">Press a key you already know.</h2>
	<p class="caption muted">Marbly puts your Dock settings back the moment you quit.</p>
	<a class="button primary" href="/guide#install" use:press><Icon name="download" size={16} />Get Marbly</a>
</section>

<style>
	.hero {
		display: grid;
		gap: 16px;
		padding: 48px 0 40px;
	}
	.hero-mark {
		justify-self: start;
		padding: 0;
		border: 0;
		background: none;
		color: var(--slate-11);
		cursor: pointer;
	}
	.hero-mark span {
		display: inline-flex;
	}
	.actions {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
		margin-top: 8px;
	}
	.showcase {
		/* The board is the product, so it gets more room than the text column. */
		margin: 0 -96px;
	}
	.editor {
		padding-top: 8px;
	}
	.switcher {
		display: flex;
		justify-content: center;
		margin-top: 8px;
	}
	.switcher.start {
		justify-content: flex-start;
	}
	.features {
		display: grid;
		gap: 24px;
		padding: 64px 0 24px;
	}
	.features article {
		display: grid;
		grid-template-columns: 36px 1fr;
		gap: 16px;
		align-items: start;
	}
	.features h2 {
		margin-bottom: 4px;
	}
	.icon {
		display: grid;
		place-items: center;
		width: 36px;
		height: 36px;
		border-radius: 10px;
		background: var(--slate-3);
		color: var(--slate-11);
	}
	.block {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		gap: 16px;
		padding-top: 72px;
	}
	.block header {
		display: grid;
		gap: 4px;
	}
	.framed {
		padding: 24px;
		display: grid;
	}
	/* The settings window at its real size: 900 × 700 pt, one point per CSS pixel,
	   breaking out of the text column the way the board does. */
	.screen {
		width: min(900px, 100vw - 32px);
		margin-inline: calc((100% - min(900px, 100vw - 32px)) / 2);
		padding: 0;
		background: none;
	}
	.screen :global(img) {
		width: 100%;
		border-radius: 12px;
		box-shadow: 0 24px 48px -12px rgb(0 0 0 / 0.35);
	}
	.menu {
		justify-items: center;
	}
	.menu :global(img) {
		max-width: 264px;
		border-radius: 10px;
	}
	.cta {
		display: grid;
		justify-items: start;
		gap: 8px;
		margin-top: 96px;
		padding: 32px;
	}
	.cta .button {
		margin-top: 8px;
	}
	@media (max-width: 760px) {
		.showcase {
			margin: 0;
		}
	}
</style>
