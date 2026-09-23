# Audio texture golden vectors

`test/visualizer/audio_texture_golden.bin` is what Android's audio texture
uploads for a known signal, and `lib/visualizer/spectrum_curve.dart` — the same
curve for iOS and desktop — is held to it (`flutter test test/visualizer`).
`generate.cpp` produces it from the reference itself: it links
`android/app/src/main/cpp/audio_texture.cpp`, unmodified, against the stub GLES
in `stubs/` (whose `glTexSubImage2D` keeps the bytes it is handed) and the
kissfft beside it, built as CMakeLists.txt builds it (`kiss_fft_scalar=float`).

The terminal player (`mstream-terminal-player`, `test/golden/audio_texture/`)
holds its own port to the same file.

## The run

Ten uploads, each after 735 stereo frames (a 60 Hz frame at 44.1 kHz):

- a 60 Hz triangle and noise on the left, 440 Hz and 3 kHz triangles and noise
  on the right, every sample from integer arithmetic and float operations that
  are exact or singly rounded — so the test generates the same samples bit for
  bit, and the FNV-1a hash of them in the header proves it did;
- `setParams(-80, -30, 0.6)` before the sixth upload;
- silence from the ninth, so the smoothing's decay is pinned too.

The first upload reads a ring that is mostly still zeros, which pins the
start-up case: fewer samples than the transform wants.

## Format

| Bytes | |
|---|---|
| 8 | `MSATGLD1` |
| 4 | uploads, u32 LE (10) |
| 4 | stereo frames per upload, u32 LE (735) |
| 8 | FNV-1a 64 of every input float's bits, left then right, LE |
| 1024 × uploads | each upload: 512 spectrum bytes, then 512 waveform bytes |

## Regenerating

After a change to `audio_texture.cpp`, from this directory:

```bash
M=../../android/app/src/main/cpp
clang -c -O2 -ffp-contract=off -Dkiss_fft_scalar=float -I "$M/kissfft" "$M/kissfft/kiss_fft.c" "$M/kissfft/kiss_fftr.c"
clang++ -std=c++17 -O2 -ffp-contract=off -Dkiss_fft_scalar=float -I stubs -I "$M" -I "$M/kissfft" generate.cpp "$M/audio_texture.cpp" kiss_fft.o kiss_fftr.o -o generate
./generate ../../test/visualizer/audio_texture_golden.bin
rm -f generate kiss_fft.o kiss_fftr.o
```

`-ffp-contract=off` keeps the signal's arithmetic unfused, as Dart's is. The
test allows one step either way per byte, rarely taken: the Dart side runs its
FFT in double where kissfft runs in float, and a truncation to 0..255 can land
either side of a boundary.
