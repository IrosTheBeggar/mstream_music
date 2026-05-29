// title: Spectrum Bars
// author: mstream_music
// license: MIT
// description: Classic FFT-driven bouncing bars with color cycling.
//
// Demonstrates the simplest audio reaction — sample the FFT row of
// iChannel0 (y near 0.25) at one frequency per bar.
//
// params (iParams[]):
//   0 = contrast (FFT bar contrast / pow exponent)
//   1 = bars (number of bars across the screen)
// param: contrast 0.5 3.0 1.51
// param: bars 12 96 76

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // Bar count (iParams[1]); floor keeps whole bars while dragging.
    float numBars = floor(iParams[1]);
    float bar = floor(uv.x * numBars);
    float barCenter = (bar + 0.5) / numBars;

    // Skew the frequency lookup toward the low end where most music
    // energy lives. Pure linear gives a top-heavy result that looks
    // like nothing's happening on the bass.
    //
    // Note: AudioTexture has 512 bins, so at 44.1 kHz each bin ≈ 43 Hz
    // and the useful musical range tops out around x = 0.3 (≈ 12 kHz).
    // The 0.30 max cap below keeps the rightmost bars in lively
    // frequencies instead of dead air at 15–22 kHz.
    float freq = pow(bar / numBars, 1.6) * 0.30;
    float amp = texture(iChannel0, vec2(freq, 0.25)).x;
    // pow expands contrast (iParams[0]); no extra gain (real audio is
    // hot enough that the old *1.4 pegged the bass bars at full height).
    amp = pow(amp, iParams[0]);

    // Gap between bars.
    float barWidth = 0.7 / numBars;
    float dx = abs(uv.x - barCenter);
    float barMask = smoothstep(barWidth, barWidth - 0.004, dx);

    // Solid below the amplitude line.
    float fill = step(uv.y, amp);

    // Hue cycles with time and slightly with vertical position so
    // tall bars get a gradient.
    vec3 col = 0.5 + 0.5 * cos(
        iTime * 0.35 + uv.y * 1.6 + vec3(0.0, 2.094, 4.188));
    col *= fill * barMask;

    // Bright cap on top of each bar.
    float cap = smoothstep(0.018, 0.0, abs(uv.y - amp)) * barMask;
    col += cap * vec3(1.0, 1.0, 1.0);

    fragColor = vec4(col, 1.0);
}
