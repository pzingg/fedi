/* npm install --save-dev fs path chokidar esbuild \
  @fortawesome/fontawesome-free ../deps/phoenix ../deps/phoenix_html ../deps/phoenix_live_view */

const fs = require('fs');
const path = require('path');
const { watch } = require('chokidar');
// const { sassPlugin } = require("esbuild-sass-plugin");
// const postcss = require('postcss');
// const autoprefixer = require('autoprefixer');
// const tailwindcss = require('tailwindcss');

// config
const ENTRY_FILE = 'app.js';
const OUTPUT_DIR = path.resolve(__dirname, '../../priv/static/assets');
const OUTPUT_FILE = 'app.js';
const MODE = process.env['NODE_ENV'] || 'production';
const TARGET = 'es2016'

// build
function build(entryFile, outFile) {
	console.log(`[+] Starting static assets build with esbuild. Build mode ${MODE}...`)
	require('esbuild').build({
		entryPoints: [entryFile],
		outfile: outFile,
		minify: MODE === 'dev' || MODE === 'development' ? false : true, // if dev mode, don't minify
		watch: false,
		bundle: true,
		target: TARGET,
		logLevel: 'silent',
		loader: { // built-in loaders: js, jsx, ts, tsx, css, json, text, base64, dataurl, file, binary
			'.ttf': 'file',
			'.otf': 'file',
			'.svg': 'file',
			'.eot': 'file',
			'.woff': 'file',
			'.woff2': 'file'
		},
		define: {
			'process.env.NODE_ENV': MODE === 'dev' || MODE === 'development' ? '"development"' : '"production"',
			'global': 'window'
		},
		sourcemap: MODE === 'dev' || MODE === 'development' ? true : false

	})
		.then(() => { console.log(`[+] Esbuild ${entryFile} to ${outFile} succeeded.`) })
		.catch((e) => {
			console.log('[-] Error building:', e.message);
			process.exit(1)
		})
}
