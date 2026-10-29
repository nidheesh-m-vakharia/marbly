<script>
	import Code from '#lib/Code.svelte';
</script>

<svelte:head>
	<title>Guide · Marbly</title>
	<meta name="description" content="Install Marbly, set it up, and get the most out of your keyboard Dock." />
</svelte:head>

<article>
	<header class="intro">
		<h1 class="title">Guide</h1>
		<p class="muted">Everything from installing Marbly to getting your Dock back.</p>
	</header>


	<section id="install">
		<h2 class="heading">Install</h2>
		<p class="muted">Marbly needs macOS 14 or later. Build it from the project folder:</p>
		<Code code="./scripts/bundle.sh" />
		<p class="muted">
			That makes <code>build/Marbly.app</code>. Drag it to Applications and open it. To try it without
			bundling, run it in place:
		</p>
		<Code code="swift run" />
		<p class="muted">
			Switch sounds come from mechsound. Render them once before building; until then each switch uses
			Marbly's built-in sound.
		</p>
		<Code
			code={`python3 -m venv .venv
.venv/bin/pip install numpy
.venv/bin/pip install --no-deps git+https://github.com/airodynamic07/mechanical-keyboard-sound
.venv/bin/python scripts/generate_sounds.py`}
		/>
	</section>

	<section id="first-run">
		<h2 class="heading">First run</h2>
		<p class="muted">
			Marbly lives in the menu bar. The real Dock steps aside and your apps appear as keycaps at the
			bottom of the screen. Click a key to open its app; right-click for the same options the Dock
			gives you, like Keep in Dock, Show in Finder and Quit.
		</p>
		<p class="muted">
			If your Dock was set to hide, Marbly hides too and slides up when the pointer reaches the bottom
			edge.
		</p>
	</section>

	<section id="settings">
		<h2 class="heading">Settings</h2>
		<p class="muted">
			Open them from the menu bar icon, or press <kbd>⌘</kbd><kbd>,</kbd> with the menu open.
		</p>
		<dl class="caption">
			<div><dt>Appearance</dt><dd>Themes, case colour, light or dark window.</dd></div>
			<div><dt>Lighting</dt><dd>Light direction, highlight, gloss and shadow depth.</dd></div>
			<div><dt>Keyboard</dt><dd>Keycap profile, what fills the gaps between keys, key size, legend.</dd></div>
			<div><dt>Sound</dt><dd>Eight switch profiles, volume, release sounds.</dd></div>
			<div><dt>Dock</dt><dd>Replacing the Dock, hiding, window keys.</dd></div>
		</dl>
	</section>

	<section id="windows">
		<h2 class="heading">Window keys</h2>
		<p class="muted">
			When an app has two or more windows on the current Space, each gets its own key, numbered in the corner. Clicking one brings that exact window forward. Turn it off under
			Dock, Show each window.
		</p>
	</section>

	<section id="mission-control">
		<h2 class="heading">Mission Control</h2>
		<p class="muted">
			Mission Control and App Exposé show the real Dock, as they always do. Marbly steps aside
			while they're open and comes back when they close. It needs Accessibility to notice them.
		</p>
	</section>

	<section id="permissions">
		<h2 class="heading">Permissions</h2>
		<p class="muted">
			Marbly asks for one permission: Accessibility, to read window titles and step aside for Mission Control.
			It doesn't need Screen Recording, Input Monitoring or Full Disk Access, and it never connects to
			the internet.
		</p>
	</section>

	<section id="dock-back">
		<h2 class="heading">Getting the Dock back</h2>
		<p class="muted">
			Quitting Marbly restores your Dock exactly as it was. If Marbly was force-quit and the Dock stays
			hidden, open and quit Marbly again, or run:
		</p>
		<Code code="defaults delete com.apple.dock autohide-delay; killall Dock" />
	</section>

	<section id="uninstall">
		<h2 class="heading">Uninstall</h2>
		<p class="muted">Quit Marbly from its menu, move it to the Bin, then clear its settings:</p>
		<Code code="defaults delete Marbly" />
	</section>
</article>

<style>
	article {
		display: grid;
		/* minmax(0, 1fr) lets long commands scroll inside their box instead of
		   widening the column. */
		grid-template-columns: minmax(0, 1fr);
		gap: 48px;
		padding-top: 32px;
	}
	.intro {
		display: grid;
		gap: 6px;
	}
	section {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		gap: 12px;
		scroll-margin-top: 24px;
	}
	code:not(pre code),
	kbd {
		font-family: ui-monospace, 'SF Mono', Menlo, monospace;
		font-size: 0.875em;
		letter-spacing: 0;
		padding: 1px 6px;
		border-radius: 6px;
		background: var(--slate-3);
		color: var(--slate-12);
	}
	kbd + kbd {
		margin-left: 2px;
	}
	dl {
		display: grid;
		gap: 2px;
		margin: 0;
		padding: 4px;
		border-radius: 10px;
		background: var(--slate-2);
	}
	dl div {
		display: grid;
		grid-template-columns: 110px 1fr;
		gap: 12px;
		padding: 10px 12px;
	}
	dt {
		font-weight: 500;
	}
	dd {
		margin: 0;
		color: var(--slate-11);
	}
</style>
