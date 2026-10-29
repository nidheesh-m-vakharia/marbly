// Motion, all through the Web Animations API. Two rules from the app carry over:
// motion answers the visitor (presses, switching views), and the one intro plays
// once per session. Reduced motion keeps fades and drops movement.

const easeOut = 'cubic-bezier(0.22, 1, 0.36, 1)';
const spring = 'cubic-bezier(0.34, 1.56, 0.64, 1)';

export const reducedMotion = () =>
	typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;

/**
 * Svelte action: shrinks to 97% while held, springs back on release.
 * @param {HTMLElement} node
 */
export function press(node) {
	if (reducedMotion()) return;
	let pressed = false;
	const down = () => {
		pressed = true;
		node.animate([{ transform: 'scale(0.97)' }], { duration: 100, easing: easeOut, fill: 'forwards' });
	};
	// Only spring back from a real press; plain hovering in and out does nothing.
	const up = () => {
		if (!pressed) return;
		pressed = false;
		node.animate([{ transform: 'scale(0.97)' }, { transform: 'scale(1)' }], {
			duration: 220,
			easing: spring,
			fill: 'forwards'
		});
	};
	node.addEventListener('pointerdown', down);
	node.addEventListener('pointerup', up);
	node.addEventListener('pointerleave', up);
	return {
		destroy() {
			node.removeEventListener('pointerdown', down);
			node.removeEventListener('pointerup', up);
			node.removeEventListener('pointerleave', up);
		}
	};
}

/**
 * Svelte action: the page's intro. Children marked [data-intro] rise and fade in,
 * staggered 40 ms apart. Plays once per session; later visits show the page at rest.
 * @param {HTMLElement} node
 */
export function intro(node) {
	const items = /** @type {HTMLElement[]} */ ([...node.querySelectorAll('[data-intro]')]);
	let seen = false;
	try {
		seen = sessionStorage.getItem('marbly-intro') === '1';
		sessionStorage.setItem('marbly-intro', '1');
	} catch {}
	if (seen) return;
	const still = reducedMotion();
	items.forEach((el, i) => {
		el.animate(
			still
				? [{ opacity: 0 }, { opacity: 1 }]
				: [
						{ opacity: 0, transform: 'translateY(8px)', filter: 'blur(4px)' },
						{ opacity: 1, transform: 'none', filter: 'blur(0)' }
					],
			{ duration: still ? 200 : 400, delay: i * 40, easing: easeOut, fill: 'backwards' }
		);
	});
}

/**
 * Cross-fades a showcase when the visitor switches it. Call after the content changes.
 * @param {HTMLElement | undefined} el
 */
export function swapIn(el) {
	if (!el) return;
	// Opacity and transform only: a blur over a large image is costly to paint.
	el.animate(
		reducedMotion()
			? [{ opacity: 0 }, { opacity: 1 }]
			: [
					{ opacity: 0, transform: 'scale(0.985)' },
					{ opacity: 1, transform: 'none' }
				],
		{ duration: 240, easing: easeOut }
	);
}

/** Fetch images the visitor is likely to switch to, once the browser is idle. */
export function prefetch(urls) {
	const go = () => urls.forEach((u) => (new Image().src = u));
	if ('requestIdleCallback' in window) requestIdleCallback(go);
	else setTimeout(go, 1500);
}

/**
 * Presses the logo like a key: down 3 px, then back with a little overshoot.
 * @param {HTMLElement} el
 */
export function keyPress(el) {
	if (reducedMotion()) return;
	el.animate(
		[{ transform: 'translateY(0)' }, { transform: 'translateY(3px)', offset: 0.3 }, { transform: 'translateY(0)' }],
		{ duration: 260, easing: spring }
	);
}

let audio;
/** A short synthesised switch "thock", like the app's fallback sound. */
export function thock() {
	try {
		audio ??= new AudioContext();
		const t = audio.currentTime;
		const osc = audio.createOscillator();
		const gain = audio.createGain();
		osc.type = 'sine';
		osc.frequency.setValueAtTime(220, t);
		osc.frequency.exponentialRampToValueAtTime(130, t + 0.03);
		gain.gain.setValueAtTime(0.0001, t);
		gain.gain.exponentialRampToValueAtTime(0.35, t + 0.002);
		gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.09);
		osc.connect(gain).connect(audio.destination);
		osc.start(t);
		osc.stop(t + 0.1);
	} catch {}
}
