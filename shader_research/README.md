# Shadertoy research

Scratch space for the audio-reactive shader sweep. **Not bundled into the APK** — `assets/shaders/` is what ships.

## `microphone-shaders.csv`

A running catalog of every Shadertoy entry that lists `microphone` (or `musicstream`) as an iChannel input — these are the shaders that are directly drop-in compatible with the `iChannel0` FFT/waveform texture our visualizer feeds.

| column | meaning |
|---|---|
| `id` | Shadertoy ID (use `https://www.shadertoy.com/view/{id}` to open) |
| `title` | Shader name (truncated to 80 chars) |
| `author` | Shadertoy username |
| `license` | Declared in the description. Categories: `CC0`, `MIT`, `WTFPL`, `Unlicense`, `Apache-2.0`, `LGPL`, `GPL-3.0`, `CC-BY` (no -NC/-SA/-ND), `CC-BY-NC`, `CC-BY-SA`, `CC-BY-ND`, `CC-BY-NC-SA`, `Public-Domain`, `No-License` (none declared → falls back to Shadertoy default CC-BY-NC-SA → not GPL-compatible). |
| `gpl_compat` | `true`/`false`. True means the license is safe to incorporate into this GPLv3 codebase. |
| `views` / `likes` | Popularity metrics from Shadertoy. |
| `date` | Unix timestamp string when the shader was published. |
| `passes` | Number of render passes (1 = image-only, 2+ = multipass — requires our `// === pass: NAME ===` packaging). |
| `has_mic` / `has_music` | Whether any pass consumes `microphone` or `musicstream` as a `ctype`. |
| `url` | Direct link to the Shadertoy entry. |

## How it's produced

A polite paced sweep runs in the Chrome MCP tab (`window.__startMicSweep`) — paginates `https://www.shadertoy.com/results?filter=microphone&sort=popular`, then for each unique ID POSTs to `/shadertoy` to fetch full metadata. Pacing: 3s between listing pages, 2s between metadata batches of 5. Total runtime: ~15-30 minutes for the full mic filter.

When you want to refresh the CSV, ask Claude to "dump the shader sweep" — it'll snapshot `window.__sweep.results` and rewrite this file.

## Workflow

1. Open `microphone-shaders.csv` in a spreadsheet, filter `gpl_compat=true`, sort by `likes` desc.
2. Pick a shader. Open its URL in a browser to preview the visual.
3. Ask Claude to "bundle shader `{id}`" — it'll fetch the source, package per pass, add the standard header (title / author / source URL / license / modifications), drop it into `assets/shaders/NN-name.glsl`.
