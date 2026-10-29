// Entry and exit transitions. Svelte 5 runs `css` transitions through the Web
// Animations API, so these are WAAPI animations with Svelte handling mount/unmount.
//
// Rules (Emil): entrances ease out; exits are faster, ease in, and travel less;
// nothing scales from zero; reduced motion keeps the fade and drops the movement.

import { cubicIn } from 'svelte/easing';

/** cubic-bezier(0.22, 1, 0.36, 1), the site's ease-out, as an easing function. */
export function easeOut(t) {
	// Newton–Raphson on the bezier's x(t), then y.
	const x1 = 0.22, y1 = 1, x2 = 0.36, y2 = 1;
	const bx = (u) => 3 * x1 * u * (1 - u) ** 2 + 3 * x2 * u ** 2 * (1 - u) + u ** 3;
	const by = (u) => 3 * y1 * u * (1 - u) ** 2 + 3 * y2 * u ** 2 * (1 - u) + u ** 3;
	const dx = (u) => 3 * x1 * (1 - u) ** 2 + 6 * (x2 - x1) * u * (1 - u) + 3 * (1 - x2) * u ** 2;
	let u = t;
	for (let i = 0; i < 6; i++) {
		const d = dx(u);
		if (Math.abs(d) < 1e-6) break;
		u -= (bx(u) - t) / d;
	}
	return by(Math.min(1, Math.max(0, u)));
}

const still = () =>
	typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;

/** Content arriving: up 6 px from 98%, fading in. */
export function rise(_node, { delay = 0, duration = 220, y = 6 } = {}) {
	if (still()) return { delay, duration: 160, css: (t) => `opacity: ${t}` };
	return {
		delay,
		duration,
		easing: easeOut,
		css: (t, u) => `opacity: ${t}; transform: translateY(${u * y}px) scale(${0.98 + 0.02 * t})`
	};
}

/** Content leaving: quicker, and only a little movement. */
export function sink(_node, { duration = 120, y = -2 } = {}) {
	if (still()) return { duration: 100, css: (t) => `opacity: ${t}` };
	return {
		duration,
		easing: cubicIn,
		css: (t, u) => `opacity: ${t}; transform: translateY(${u * y}px)`
	};
}

/** A small popover (tooltip) growing from its anchor below it. */
export function pop(node, { duration = 150 } = {}) {
	if (still()) return { duration: 100, css: (t) => `opacity: ${t}` };
	const base = getComputedStyle(node).transform;
	const prefix = base === 'none' ? '' : base;
	return {
		duration,
		easing: easeOut,
		css: (t, u) => `opacity: ${t}; transform: ${prefix} translateY(${u * 3}px) scale(${0.94 + 0.06 * t})`
	};
}

/** The tooltip leaving: a fast fade. */
export function unpop(_node, { duration = 90 } = {}) {
	return { duration, easing: cubicIn, css: (t) => `opacity: ${t}` };
}

/** A row opening or closing in place: height and opacity together. */
export function reveal(node, { duration = 200 } = {}) {
	const height = node.offsetHeight;
	if (still()) return { duration: 120, css: (t) => `opacity: ${t}` };
	return {
		duration,
		easing: easeOut,
		css: (t) => `overflow: hidden; height: ${t * height}px; opacity: ${t * t}`
	};
}

/** An icon swapping for another (copy → check). */
export function swap(_node, { duration = 160 } = {}) {
	if (still()) return { duration: 100, css: (t) => `opacity: ${t}` };
	return {
		duration,
		easing: easeOut,
		css: (t) => `opacity: ${t}; transform: scale(${0.6 + 0.4 * t})`
	};
}
