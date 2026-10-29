// The keyboard's look, ported from the macOS app (KeyStyle.swift, KeycapPalette.swift)
// so the web board matches it: same profiles, lighting maths, case shading and themes.

export const profiles = {
	cherry: { label: 'Cherry', inset: { top: 0.045, side: 0.11, bottom: 0.17 }, dish: 0.12, travel: 0.06 },
	sa: { label: 'SA', inset: { top: 0.03, side: 0.13, bottom: 0.22 }, dish: 0.2, travel: 0.06 },
	dsa: { label: 'DSA', inset: { top: 0.07, side: 0.12, bottom: 0.12 }, dish: 0.09, travel: 0.06 },
	low: { label: 'Low profile', inset: { top: 0.04, side: 0.06, bottom: 0.09 }, dish: 0.04, travel: 0.035 }
};

export const gapFills = {
	plate: 'Plate',
	body: 'Body',
	color: 'Colour',
	backlight: 'Backlight'
};

export const themes = [
	{ id: 'graphite', name: 'Graphite', caseColor: '#2B2D31', profile: 'cherry', lighting: { angle: -35, intensity: 0.45, gloss: 0.5, shadow: 0.6 } },
	{ id: 'silver', name: 'Silver', caseColor: '#C9CCD1', profile: 'cherry', lighting: { angle: -35, intensity: 0.5, gloss: 0.55, shadow: 0.5 } },
	{ id: 'milk', name: 'Milk', caseColor: '#EDE6DA', profile: 'sa', lighting: { angle: -20, intensity: 0.35, gloss: 0.3, shadow: 0.45 } },
	{ id: 'midnight', name: 'Midnight', caseColor: '#1D2433', profile: 'low', lighting: { angle: -45, intensity: 0.6, gloss: 0.75, shadow: 0.7 } },
	{ id: 'sage', name: 'Sage', caseColor: '#8E9E86', profile: 'dsa', lighting: { angle: -30, intensity: 0.4, gloss: 0.4, shadow: 0.5 } },
	{ id: 'rose', name: 'Rose', caseColor: '#D8A7A7', profile: 'sa', lighting: { angle: -25, intensity: 0.4, gloss: 0.35, shadow: 0.5 } }
];

export const caseSwatches = [...themes.map((t) => t.caseColor), '#5B4636', '#2F4F4F', '#E3C770', '#F2F2F2'];

// Board layout, in key units (BoardLayout in KeyboardView.swift).
export const layout = { caseWall: 0.12, plate: 0.14, spacing: 0.07, gap: 0.22, reflection: 0.55 };

// --- Colour ---------------------------------------------------------------

export function hexToRgb(hex) {
	const n = parseInt(hex.replace('#', ''), 16);
	return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

export function rgbToHsv([r, g, b]) {
	const max = Math.max(r, g, b);
	const d = max - Math.min(r, g, b);
	let h = 0;
	if (d > 0) {
		if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
		else if (max === g) h = (b - r) / d + 2;
		else h = (r - g) / d + 4;
		h /= 6;
	}
	return [h, max === 0 ? 0 : d / max, max];
}

export function hsv(h, s, v) {
	const i = Math.floor(h * 6) % 6;
	const f = h * 6 - Math.floor(h * 6);
	const p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
	const [r, g, b] = [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][i];
	return `rgb(${Math.round(r * 255)} ${Math.round(g * 255)} ${Math.round(b * 255)})`;
}

const luma = ([r, g, b]) => 0.299 * r + 0.587 * g + 0.114 * b;

/** Case, plate and recess colours from one body colour (CaseFinish). */
export function caseFinish(hex) {
	const rgb = hexToRgb(hex);
	const [h, s, v] = rgbToHsv(rgb);
	return {
		top: hsv(h, s, Math.min(1, v * 1.1)),
		bottom: hsv(h, Math.min(1, s * 1.05), v * 0.78),
		plate: hsv(h, Math.min(1, s * 1.1), v * 0.32),
		recess: hsv(h, Math.min(1, s * 1.05), v * 0.86),
		backlit: hsv(h, Math.min(1, s * 1.1), v * 0.16),
		bevel: luma(rgb) > 0.5 ? 0.8 : 0.22
	};
}

/** The colour a key's backlight glows: its own hue at full brightness. */
export function glowColor(hex) {
	const [h, s] = rgbToHsv(hexToRgb(hex));
	return hsv(h, Math.min(1, s * 1.1), 1);
}

// --- Lighting -------------------------------------------------------------

/**
 * Everything the light controls. On the web the light is drawn more strongly than a
 * flat wash: a glare spot that sits where the light is, rims on the lit edges, walls
 * that brighten and darken by side, and shadows thrown away from the light.
 */
export function lightingMath(l) {
	const rad = (l.angle * Math.PI) / 180;
	const sin = Math.sin(rad), cos = Math.cos(rad);
	return {
		// CSS gradient angle running from the lit edge to the far edge.
		cssAngle: 180 + l.angle,
		// Unit vector toward the light, in screen space (y down).
		lx: sin,
		ly: -cos,
		leftShade: Math.max(0.02, 0.22 + 0.2 * sin),
		rightShade: Math.max(0.02, 0.22 - 0.2 * sin),
		shadowX: -sin * 0.09 * l.shadow,
		peak: Math.min(0.95, l.intensity * (0.75 + 0.45 * l.gloss)),
		falloff: 0.85 - 0.4 * l.gloss,
		// Glare spot: brighter and tighter as the surface gets glossier.
		glare: Math.min(0.9, l.intensity * (0.35 + 0.65 * l.gloss)),
		glareRadius: 0.62 - 0.32 * l.gloss,
		rim: 0.15 + 0.6 * l.intensity
	};
}

/** Face and cap corner radii, concentric (KeycapView.faceRadius / capRadius). */
export function radii(unit, profile) {
	const face = unit * (1 - 2 * profile.inset.side) * 0.225;
	return { face, cap: face + unit * profile.inset.side * 0.6 };
}
