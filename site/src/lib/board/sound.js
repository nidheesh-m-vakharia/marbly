// Switch sounds, synthesised the same way as Marbly's built-in fallback (SwitchSynth.swift):
// a high-passed noise transient, a pitched body thump gliding down, a plastic resonance,
// and click-jacket snaps for clicky switches. Rendered once per switch and cached.

const voices = {
	thocky: { bodyHz: 135, bodyDecay: 0.032, resHz: 820, resDecay: 0.011, resLevel: 0.3, noiseDecay: 0.0013, noiseLevel: 0.55, clicks: [] },
	creamy: { bodyHz: 205, bodyDecay: 0.022, resHz: 1300, resDecay: 0.008, resLevel: 0.22, noiseDecay: 0.0009, noiseLevel: 0.35, clicks: [] },
	clicky: { bodyHz: 250, bodyDecay: 0.016, resHz: 2100, resDecay: 0.006, resLevel: 0.28, noiseDecay: 0.0008, noiseLevel: 0.45, clicks: [0, 0.007] }
};

/** The eight switches, each mapped to its closest voice (as in SwitchType.fallback). */
export const switches = [
	{ id: 'brown', label: 'Brown', voice: 'creamy' },
	{ id: 'red', label: 'Red', voice: 'creamy' },
	{ id: 'blue', label: 'Blue', voice: 'clicky' },
	{ id: 'thock', label: 'Thock', voice: 'thocky' },
	{ id: 'deep', label: 'Deep', voice: 'thocky' },
	{ id: 'clicky', label: 'Clicky', voice: 'clicky' },
	{ id: 'soft', label: 'Soft', voice: 'creamy' },
	{ id: 'mix', label: 'Mix', voice: 'thocky' }
];

let ctx;
const cache = new Map();

function render(voiceName, stroke, pitch, seed) {
	const base = voices[voiceName];
	const p = { ...base };
	if (stroke === 'up') {
		p.bodyHz *= 1.4; p.resHz *= 1.25; p.bodyDecay *= 0.6; p.resDecay *= 0.7; p.noiseLevel *= 0.6;
		p.clicks = p.clicks.slice(0, 1);
	}
	const rate = ctx.sampleRate;
	const n = Math.floor(rate * 0.11);
	const buffer = ctx.createBuffer(1, n, rate);
	const out = buffer.getChannelData(0);
	let phase = 0, last = 0, s = seed;
	const rand = () => ((s = (s * 1664525 + 1013904223) % 4294967296) / 4294967296);
	for (let i = 0; i < n; i++) {
		const t = i / rate;
		const noise = rand() * 2 - 1;
		const transient = (noise - last) * 0.5 * Math.exp(-t / p.noiseDecay) * p.noiseLevel;
		last = noise;
		phase += (2 * Math.PI * p.bodyHz * pitch * (1 + 0.6 * Math.exp(-t / 0.004))) / rate;
		const body = Math.sin(phase) * Math.exp(-t / p.bodyDecay);
		const res = Math.sin(2 * Math.PI * p.resHz * pitch * t) * Math.exp(-t / p.resDecay) * p.resLevel;
		let click = 0;
		for (const onset of p.clicks) if (t >= onset) click += Math.sin(2 * Math.PI * 4300 * pitch * (t - onset)) * Math.exp(-(t - onset) / 0.0012) * 0.7;
		out[i] = (transient + body + res + click) * Math.min(1, t / 0.0004);
	}
	let peak = 0;
	for (const v of out) peak = Math.max(peak, Math.abs(v));
	const gain = peak ? (0.9 / peak) * (stroke === 'up' ? 0.5 : 1) : 0;
	const fade = Math.floor(rate * 0.008);
	for (let i = 0; i < n; i++) out[i] *= gain * (i >= n - fade ? (n - i) / fade : 1);
	return buffer;
}

/**
 * Plays a keystroke. `pan` is −1…1 from the key's place on the board.
 * @param {string} switchId @param {'down'|'up'} stroke @param {number} volume @param {number} pan
 */
export function playSwitch(switchId, stroke, volume, pan = 0) {
	if (volume <= 0) return;
	try {
		ctx ??= new AudioContext();
		const voice = switches.find((s) => s.id === switchId)?.voice ?? 'creamy';
		const variant = Math.floor(Math.random() * 3);
		const key = `${voice}-${stroke}-${variant}`;
		if (!cache.has(key)) cache.set(key, render(voice, stroke, 0.95 + 0.05 * variant, (variant + 1) * 7919));
		const src = ctx.createBufferSource();
		src.buffer = cache.get(key);
		const gain = ctx.createGain();
		gain.gain.value = volume;
		const panner = ctx.createStereoPanner();
		panner.pan.value = Math.max(-1, Math.min(1, pan));
		src.connect(gain).connect(panner).connect(ctx.destination);
		src.start();
	} catch {}
}
