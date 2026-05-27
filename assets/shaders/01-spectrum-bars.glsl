// title: Spectrum Bars
// author: mstream_music
// license: MIT
// description: Classic FFT-driven bouncing bars with color cycling.
//
// Demonstrates the simplest audio reaction — sample the FFT row of
// iChannel0 (y near 0.25) at one frequency per bar.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // 48 bars across the screen.
    float numBars = 48.0;
    float bar = floor(uv.x * numBars);
    float barCenter = (bar + 0.5) / numBars;

    // Skew the frequency lookup toward the low end where most music
    // energy lives. Pure linear gives a top-heavy result that looks
    // like nothing's happening on the bass.
    float freq = pow(bar / numBars, 1.6);
    float amp = texture(iChannel0, vec2(freq, 0.25)).x;
    amp = pow(amp, 1.4) * 1.4;

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
