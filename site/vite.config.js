import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

// Every page is pre-rendered to static HTML.
export default defineConfig({
	plugins: [sveltekit({ adapter: adapter() })]
});
