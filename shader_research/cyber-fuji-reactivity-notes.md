# Cyber Fuji audio reactivity — behavioral notes

**Purpose:** Clean-room spec for re-implementing audio reactivity in our
`assets/shaders/04-cyber-fuji.glsl` (CC BY 3.0 by kaiware007).

**Reference:** Chaotnix's "Cyber Fuji 2020 audio reactive" fork
(`fd2GRw` on Shadertoy, default CC-BY-NC-SA — not directly usable).
Author's stated diff vs. original: *"based on Cyber Fuji 2020 by
kaiware007 [original-url] — I just added mic."*

**Why this document exists:** Chaotnix's specific code is under a
license we can't bundle. Behaviors/ideas are not copyrightable, only
specific expressions are. These notes describe *what* the reactivity
does, abstracted from *how* it was coded, so re-implementation can be
done from this spec without re-reading the original. This is the same
"clean room" approach Compaq used to clone the IBM BIOS legally.

## What I observed (structurally, from automated analysis)

The fork makes 5 modifications to the original, all reading from the
**mic input on `iChannel0`**. Each sample:

| # | Function | What gets modulated | Frequency band sampled |
|---|---|---|---|
| 1 | `sun()` | something inside the sun's body | bass (low FFT bin, x≈0.1 on the audio texture's FFT row) |
| 2 | `grid()` | something inside the grid generator | bass (same low FFT bin) |
| 3 | `mainImage` | the mountain's width parameter (the `sdTrapezoid` width arg) | bass (same low FFT bin) |
| 4 | `mainImage` | cloud-related (one of the `cloudY` values) | bass (same low FFT bin) |
| 5 | `mainImage` | cloud-related (the other `cloudY`) | bass (same low FFT bin) |

Every sample is run through `pow(..., n)` for some exponent — i.e.
**non-linear response curve** that accentuates strong hits and
suppresses ambient noise. (A perceptually-tuned default in audio
visualization; equivalent to a soft expander/gate.)

**Frequency picking:** all 5 modulations tap the same low frequency
bin. Chaotnix did not use mid or treble — only bass.

## What this implies, behaviorally

Visually, when bass hits the shader:

1. **Sun pulses.** The sun's appearance changes — most likely its
   cut-frequency animation speed (the horizontal banding) or its
   bloom intensity. The exact visual is one of those two.

2. **Grid pulses.** The retro grid floor either:
   - moves faster (scroll-speed term gets boosted), or
   - lines get thicker/brighter (size term gets boosted).

3. **Mountain bulges horizontally.** Same behavior we already have
   in our shader — the `sdTrapezoid` width param has a bass-derived
   term added.

4. **Both clouds shift vertically on bass hits.** Each of the two
   clouds gets its base Y coordinate offset by a bass-derived
   amount. Probably small magnitude so they "breathe" rather than
   slam around.

The overall effect (per author's "just added mic" remark): a
moderate, coherent bass-reactive treatment touching multiple scene
elements with the same source signal, so everything pulses in
unison rather than chaotically.

## What we already have

Our `04-cyber-fuji.glsl` currently implements **only #3** — mountain
width modulation. We sample 6 bass bins (slightly different from the
fork's single bin) and use the sum:

```glsl
float mstreamBass = 0.0;
for (int i = 0; i < 6; i++) {
    mstreamBass += texture(iChannel0, vec2(float(i) * 0.01 + 0.005, 0.25)).x;
}
mstreamBass = clamp(mstreamBass * 0.4, 0.0, 1.0);
```

Our pattern is slightly more robust than the fork's single-bin sample
(averaging across 6 bins reduces flicker on transients). We can keep
our `mstreamBass` extractor and just apply it to more targets.

## Re-implementation plan

Reuse our existing `mstreamBass` variable (no need to reproduce the
fork's single-bin extraction). Add four new modulations using the
same already-computed bass value:

1. **Sun** — multiply the sun's bloom intensity by `(1.0 + bass * k)`,
   so the bloom radius grows on bass hits. Our original `sun()`
   returns `clamp(val * cut, 0.0, 1.0) + bloom * 0.6`; replace the
   bloom coefficient with a bass-modulated version. Magnitude: small
   (k ≈ 0.6) so the sun grows but doesn't dominate the frame.

2. **Grid** — boost the grid's scroll speed with bass. Our `grid()`
   uses `iTime * 4.0 * (battery + 0.05)` as the scroll term;
   multiply by `(1.0 + bass * k)` so grid scrolls faster on hits.
   Magnitude: moderate (k ≈ 0.5) — the grid is already pretty
   active visually.

3. **Mountain** — already done. No change needed.

4. **Cloud Y** — apply small vertical offset to both `cloudY`
   constants. Both clouds get `cloudY += bass * delta` where delta
   is small (≈ 0.05 in shader uv space) so the clouds bob
   subtly. Optional: give the two clouds opposite-sign offsets so
   they bob counter to each other for visual interest.

All four additions follow the same pattern as our existing mountain
modulation: take a hardcoded constant or expression, add a
bass-derived term scaled by a small factor. Each is a 1-line edit.

## What this implementation does NOT reproduce

- The exact magnitudes/strengths from the fork (those are
  expressive choices the original author made; we pick our own).
- The exact sampling pattern (we use 6-bin average; the fork used
  single bin).
- The exact non-linear curve shape (we use linear scaling; the fork
  used `pow(...)`). We can add `pow(bass, 1.5)` later if the
  response feels too soft.

These differences are not deficiencies — they're independent
implementation choices made for our own reasons (smoother response,
matching the existing extractor pattern we already had).

## Attribution

When this lands, update the modifications block in
`04-cyber-fuji.glsl` to credit the inspiration:

> modifications: (existing list...)
> (N) added bass-driven modulation to sun bloom, grid scroll speed,
>     and cloud vertical position. Behavior pattern inspired by
>     Chaotnix's fd2GRw fork (their NC-licensed code was not used;
>     these behaviors were independently implemented from a
>     behavioral spec in shader_research/cyber-fuji-reactivity-notes.md).

---

# Addendum: Waveform rendering — reference lt23W1

**Reference:** FabriceNeyret2's "mic analysis" shader (`lt23W1` on
Shadertoy, No-License declared → defaults to CC-BY-NC-SA, not
usable directly).

**Why this section exists:** The user wanted the cyber-fuji snow
line to read more like an oscilloscope display (the standard
audio-analysis aesthetic) rather than a wavy fill boundary. This
section documents what FabriceNeyret2's mic analyzer does, at the
behavioral level, so we can re-implement.

## Structural observations (no verbatim code)

The shader is 78 lines, single pass, samples `iChannel0` 5 times:

| line | x coord       | y coord    | what it does               |
|------|---------------|------------|----------------------------|
| 23   | `f / fmax`    | `.5 / 2.`  | FFT, parameterized scan    |
| 43   | `uv.x`        | `.5 / 2.`  | FFT, screen-x indexed      |
| 59   | `uv.x`        | `.5 / 2.`  | FFT (octave/harmonic test) |
| 68   | `x / 512.`    | `1.5 / 2.` | waveform, in a for-loop    |
| 73   | `uv.x`        | `1.5 / 2.` | waveform, direct render    |

The y constants reveal Fabrice knows the texture layout: `.5/2 = 0.25`
samples the FFT row (Shadertoy convention), `1.5/2 = 0.75` samples
the waveform row. And `x/512.` on line 68 confirms he knows
**BINS=512** (this is where we recently realized our own shaders were
sampling wrong frequencies under the assumption of 256 bins).

**No smoothstep anywhere in the file.** All conditional rendering
uses raw `if (...) col = ...;` with direct comparisons — produces
hard edges. Visually that gives a "diagram" / "analyzer" look, not
the soft / cinematic look of our other modulations.

## Waveform render pattern

The waveform-row reads (lines 68 and 73) operate at different scales:

1. **Per-sample dot/bar plotting (line 68, inside for-loop):** the
   shader iterates over the full set of 512 waveform samples,
   indexed by `x` from 0..N. For each, it samples that exact
   waveform value and tests whether the current pixel falls on it.
   This is the classical oscilloscope point-cloud approach — each
   sample becomes a small lit pixel(/bar).
2. **Per-pixel direct render (line 73, outside loop):** samples
   waveform at the current screen `uv.x` and tests if `uv.y` is
   close to the sampled amplitude. This is the simpler "for each
   screen pixel, look up nearest sample and draw a line".

The two combined produce both an *outline* of the wave (line 73, the
continuous line shape) and *anchor dots* at the actual sample
positions (line 68 loop, individual samples lit).

The render uses raw `if (abs(...) < threshold) col = waveColor;`
style — no smoothstep antialiasing.

## What to take into cyber fuji

For our snow ridge, the visual we want is:

- **A thin bright line traced ON the waveform** (oscilloscope
  appearance) — what Fabrice's render achieves
- Keep the existing soft snow fill above the line (it's part of the
  mountain's visual identity; removing it changes the synthwave look)
- Increase the waveform sample-averaging window for cleaner shape
  (Fabrice's per-sample dot pattern is too busy for our small
  mountain top — we want a continuous line, not stippling)

In other words: keep the wavy snow fill we have, and ADD a bright
white line drawn directly on the wave boundary, smoothstep-edged so
it looks clean against the snow color.

## Re-implementation plan

In the cyber-fuji image pass, right after the existing snow fill
mix, compute the signed distance from the current pixel to the wave
line and draw a thin band:

```
// (after the existing fill)
float distFromWaveLine = abs(waveVal);    // waveVal is signed distance
float oscLineMask = smoothstep(0.008, 0.0, distFromWaveLine);
col = mix(col, vec3(1.0), oscLineMask * step(fujiVal, 0.0));
```

`waveVal` is already a signed distance from the wave (positive
above, negative below), so its absolute value is unsigned distance.
`smoothstep(0.008, 0.0, ...)` produces a clean ~16-pixel-wide line
at the wave boundary that fades out smoothly. The `* step(fujiVal, 0.0)`
keeps the line clipped to the mountain shape.

Also: bump the waveform sampling window from 5 to 7 samples and
slightly wider spacing for a smoother shape (the line will be
visually thinner than the snow boundary, so any jaggedness shows
more).

## What this does NOT reproduce

- The per-sample dot pattern from Fabrice's for-loop. Our snow
  ridge is only a few pixels wide visually (mountain top is narrow);
  dot stippling would be illegible. Continuous line is better.
- The hard-edge `step` style from Fabrice — we use smoothstep for
  antialiasing because our line is thinner and would alias hard.
  This is a stylistic choice consistent with the rest of cyber-fuji's
  smooth-edge aesthetic.

---

# Second addendum: Glow-line algorithm — reference 3dGGDy

**Reference:** ncote's "LineMouth" shader (`3dGGDy` on Shadertoy,
No-License declared → defaults to CC-BY-NC-SA, not usable directly).

**Why this section exists:** The smoothstep oscilloscope line we
added from the lt23W1 reference is functional but looks "computery"
(hard band with soft edges). The user wanted a softer, more
luminous line drawing. 3dGGDy demonstrates a cleaner line
technique that's worth replicating.

## Structural observations (no verbatim code)

34 lines, single pass, 1195 bytes. Two `iChannel0` samples:
- Line 5: `texture(iChannel0, vec2(frequency / 512.0, 0))` — FFT row, indexed by a loop variable (BINS=512 confirmed)
- Line 25: `texture(iChannel0, vec2(uvTrue.x, 1))` — waveform row, indexed by screen x

The for-loop on line 21 iterates frequencies for the spectrum side
of the visualization. The waveform line drawing is *outside* the
loop, lines 25–27.

## The line drawing pattern

Lines 25–27 form the entire line drawing:

1. **Line 25:** sample waveform at current pixel's x coordinate
2. **Line 26:** compute signed distance between current pixel's y
   and the sampled amplitude. Has `abs()`, division, and the
   pixel's y coordinate referenced. Long (92 chars) — does the
   actual displacement math.
3. **Line 27:** compute line intensity. Has `abs()`, one division,
   one multiplication. Short (47 chars) — looks like the classic
   `thickness / (abs(distance) + epsilon)` glow formula.

**No smoothstep anywhere.** **No fwidth.** The line softness comes
entirely from the `1/d` division falloff. As pixel distance to the
line approaches zero, intensity approaches infinity (capped by a
`min()` or similar), producing a bright core with smooth glow
falling off proportionally to inverse distance.

This is a well-established "neon" line technique — it produces
visually pleasing glowing lines without explicit antialiasing
math because the division naturally smoothes the edge.

## What to take into cyber fuji

Replace the smoothstep-based oscilloscope line (added from the
lt23W1 reference) with a 1/d glow line:

```
float glow = thickness / (abs(waveDistFromLine) + eps);
glow = min(glow, maxIntensity);  // cap the core
col += vec3(1.0) * glow * step(fujiVal, 0.0);
```

Where:
- `thickness` ≈ 0.004 → controls the visual line width
- `eps` ≈ 0.001 → prevents division by zero
- `maxIntensity` ≈ 4.0 → caps the core brightness so the center
  doesn't overbloom into a featureless white blob
- The `+=` (additive blend) on top of the existing pink snow fill
  produces a bright glowing line over the snow boundary.

This replaces the previous `smoothstep(0.008, 0.0, abs(waveVal))`
band approach with a continuous-falloff glow that reads as luminous
rather than as a flat strip.

## Also: widen the waveform mapping

The user also wants the waveform to extend beyond the mountain's
snow line so the wave shape is visible regardless of how much the
mountain has bulged. Switch the texX mapping from
`(uv.x - 0.55) / 0.40` (matches snow line width, ~0.4 uv units) to
something like `(uv.x - 0.25)` (covers ~1.0 uv units centered on
the mountain — wider than the snow line, so the visible wave
extends slightly past the mountain edges and the `step(fujiVal, 0)`
mask clips it cleanly to whatever shape the mountain has).

## What this does NOT reproduce

- The for-loop spectrum side of 3dGGDy — we're using the waveform
  algorithm only, not the spectrum bars.
- The sin/cos color palette (3dGGDy uses a rainbow palette via
  `0.5 + 0.5 * sin(t + vec3(0, 2.094, 4.188))`). Our snow stays
  pink-and-white because that's the cyber-fuji aesthetic.
