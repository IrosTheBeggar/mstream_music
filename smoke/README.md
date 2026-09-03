# Smoke tests

Device-level checks for the things unit tests cannot see: the Quick Connect
tunnel under real network churn, Bluetooth in the car, launch and server
switching, CarPlay, background playback. Two kinds:

- **Scripts** (`android/`, `ios/`, `run-android.sh`): repeatable, assert on the
  app's own log lines, drop screenshots and the filtered log in `out/`.
- **Recipes** (`recipes/`): the tests that need a car, a commute, a head unit
  or an hour of pocket time. Each says what to do, what pass looks like, and
  what evidence to capture.

## Prerequisites

- Android: a device or emulator over USB with the debug `.plus.dev` build
  (`sed -i '' 's/applicationIdSuffix ".plus"$/applicationIdSuffix ".plus.dev"/' android/app/build.gradle`,
  `flutter build apk --debug --flavor full --target-platform android-arm64`, then revert
  build.gradle), the personal server paired **both** ways (standard + Quick Connect),
  and for the Bluetooth test a paired headset. Wireless debugging dies with the radios —
  use USB.
- iOS: a booted simulator with `flutter build ios --simulator --debug`; the CarPlay
  round needs the Simulator GUI (I/O › External Displays › CarPlay) and one click.
- Screen coordinates default to a Galaxy S25 (1080×2340); override with the
  `SMOKE_*_XY` variables named at the top of each script for other phones.

## Running

```bash
smoke/run-android.sh                      # whole Android suite (soak: 120 min)
SMOKE_SOAK_MIN=10 smoke/run-android.sh    # quick version
smoke/android/dead-zone.sh                # one scenario
smoke/ios/carplay-round.sh                # simulator CarPlay, prompts for the click
```

Every script prints `PASS`/`FAIL`/`SKIP` lines and a summary, exits non-zero on
a FAIL, and restores any device config it changed (server order, Auto DJ
target) on exit, including on Ctrl-C. Nothing prints pairing codes or tokens.

| Script | What it proves | Time |
|---|---|---|
| `android/session-actions.sh` | shuffle/repeat advertised to the OS (lock screen, Auto, CarPlay) | 15 s |
| `android/launch-matrix.sh` | a standard default is usable at once; a Quick Connect default dials first; one dial, no teardown churn | 40 s |
| `android/switch-during-outage.sh` | switching to the standard server mid-outage resets the browser at once, no strip | 3 min |
| `android/media-resumption.sh` | headless boot on a PLAY key after a force-kill | 1 min |
| `android/bt-late-pause.sh` | the car-off late PAUSE is ignored | 1 min |
| `android/dead-zone.sh` | hand-off, 75 s outage, Retry tap, Wi-Fi return — all in place | 5 min |
| `android/playback-soak.sh` | screen-off playback survives (Samsung app-sleep) | 2 h |
| `android/cast-through-rebuild.sh` | opt-in (`SMOKE_CAST=1`, plays on a TV): cast + tunnel disturbance | 2 min |
| `ios/sim-launch.sh` | app-owned engine boots, UI renders, resume reaches Dart | 1 min |
| `ios/carplay-round.sh` | the whole CarPlay template flow, buttons, artist, Siri dry-run, depth guard | 2 min |

## Reading a failure

The scripts assert on log markers the app writes for exactly this purpose:
`[app] default server ready`, `[srv] switched to`, `[iroh] tunnel up`,
`reconnected: attempt`, `kicking the tunnel in place`, `output disconnected —
pausing`, `media button toggle ignored`. On a real phone the same lines are in
Diagnostics › Share, which is how the drive recipes are read afterwards.
