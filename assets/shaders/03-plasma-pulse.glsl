// title: Plasma Pulse
// author: mstream_music
// license: MIT
// description: Classic demoscene plasma. Overall amplitude (averaged
//              across the FFT) modulates brightness — chill when quiet,
//              luminous when loud.
//
// Demonstrates the "average FFT into a loudness signal" pattern, useful
// when you want music-reactive intensity without picking specific bands.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    // Average across 16 FFT bins for an overall loudness signal.
    // AudioTexture has 512 bins; most music energy lives below ~6 kHz
    // (x = 0.14 in the texture). Spreading samples across the full
    // x = [0, 1] range puts half the samples in near-silent 11–22 kHz
    // bins which drags the average down. Cap to x = 0.30.
    float loudness = 0.0;
    for (int i = 0; i < 16; ++i) {
        float f = ((float(i) + 0.5) / 16.0) * 0.30;
        loudness += texture(iChannel0, vec2(f, 0.25)).x;
    }
    loudness *= (1.0 / 16.0);

    // Classic plasma — sum of sines at different rates.
    float v = 0.0;
    v += sin(p.x * 3.0 + iTime);
    v += sin(p.y * 4.0 + iTime * 1.3);
    v += sin((p.x + p.y) * 2.5 + iTime * 0.7);
    v += sin(length(p) * 5.0 - iTime * 1.5);
    v *= 0.25; // back into [-1, 1]

    // Hue from v; saturation full; brightness from loudness.
    vec3 col;
    col.r = 0.5 + 0.5 * sin(v * 3.14159 + 0.0);
    col.g = 0.5 + 0.5 * sin(v * 3.14159 + 2.094);
    col.b = 0.5 + 0.5 * sin(v * 3.14159 + 4.188);

    col *= 0.35 + loudness * 3.5;

    fragColor = vec4(col, 1.0);
}
