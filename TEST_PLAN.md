# mstream_music Test Plan

## Goal

A tight regression-detection loop for an existing Flutter app whose modernization is in progress. The plan is shaped by what *this* codebase actually looks like (heavy singletons, no DI, direct `http`/plugin calls), not by an idealized "build it from scratch" guide.

## What we have today

- **App version**: 0.14.0+25
- **Flutter**: 3.38.9 / Dart 3.10.8
- **Source tree**: `lib/main.dart` (root UI), `lib/screens/*` (page widgets), `lib/singletons/*` (state + side effects), `lib/objects/*` (data classes), `lib/media/*` (audio_service handler)
- **Existing tests**: a 2021 boilerplate counter test that never matched the app — replaced.
- **Baseline `flutter analyze`**: 2 minor issues
  1. `info`: `ConcatenatingAudioSource` deprecated in [lib/media/audio_stuff.dart:19](lib/media/audio_stuff.dart#L19) — `just_audio` wants `AudioPlayer.setAudioSources` instead.
  2. `warning`: dead private method `_deleteServeDirectory` in [lib/singletons/server_list.dart:200](lib/singletons/server_list.dart#L200).

## Codebase characteristics that shape the plan

These are the load-bearing properties of the codebase. The plan accommodates them rather than fighting them.

1. **Singleton-everywhere**. `ApiManager`, `ServerManager`, `BrowserManager`, `MediaManager`, `DownloadManager`, `FileExplorer`, `TranscodeManager` are all `factory` singletons with private constructors. There is no DI container. Tests cannot easily swap implementations.
2. **API layer writes side-effects, not return values**. e.g. `ApiManager.getAlbums()` decodes the JSON, builds `DisplayItem`s, and pushes them into `BrowserManager().addListToStack(...)`. There's no pure `parseAlbums(json) → List<DisplayItem>`. To unit-test parsing today, you'd have to read the global `BrowserManager` state after the call.
3. **HTTP is direct**. `http.get` / `http.post` are imported and called inline. No client abstraction, so mocking means swapping `http.Client` via the `package:http` `Client.withClient` style or using `http_mock_adapter` / `mockito`.
4. **Plugin coupling at startup**. `main()` calls `MediaManager().start()` (audio_service), `MStreamApp.initState` calls `ServerManager().loadServerList()` (path_provider) and `DownloadManager().initDownloader()` (flutter_downloader). A widget test that builds `MStreamApp` will throw on every one of those without platform-channel mocks.
5. **Pure data classes exist**. `Server` and `MusicMetadata` already have `fromJson` / `toJson`. These are the only zero-friction unit-test targets in the codebase right now.

## Test layers

Four layers, ordered cheapest → most expensive. Each has a clear cost/benefit profile and a clear set of regressions it can catch.

### Layer 1 — Pure-Dart unit tests (no Flutter binding)

**What it covers**: pure data classes and pure functions. JSON parsing for `Server` and `MusicMetadata`. URL construction (currently inlined in `ApiManager.getRecursiveFiles`, `audio_stuff.autoDJ`, `DisplayItem.getImage`). Auto-DJ `ignoreVPaths` payload string assembly.

**Cost**: trivial. Runs in <1s. Already implemented for `Server` and `MusicMetadata` ([test/objects/](test/objects/)).

**Regression value**: catches the *easiest-to-introduce* regressions during a server-side API contract change — e.g. someone renames `albumArt` to `album_art` server-side, the client silently breaks album art for everyone. Pure unit tests catch that immediately.

**To unlock more of these**: extract response-parsing functions out of `ApiManager` into pure top-level functions:

```dart
// lib/api/parsers.dart
List<DisplayItem> parseAlbums(dynamic json, Server? server) { … }
List<DisplayItem> parseRecentlyAdded(dynamic json, Server? server) { … }
MediaItem parseAutoDJSong(dynamic decoded, Server server) { … }
```

then have `ApiManager` call them. This is a cheap refactor (move code, no behavior change) that unlocks a large chunk of testable surface.

**Targets to add (in priority order)**:
- [ ] `parseAlbums` / `parseArtists` / `parseRecentlyAdded` / `parseRated` / `parseAlbumSongs` / `parsePlaylistContents` / `parseSearchResults` / `parseFileList` — once extracted from `ApiManager`.
- [ ] `buildMediaUrl(server, filepath)` — currently inlined in `ApiManager.getRecursiveFiles` and `audio_stuff.autoDJ` with subtle differences (one uses `Uri.encodeFull` on the whole string, the other does per-segment `Uri.encodeComponent`). This inconsistency is itself a likely bug — extracting + testing surfaces it.
- [ ] `buildAlbumArtUrl(server, file, {compress})` — inlined in `DisplayItem.getImage` and `audio_stuff.autoDJ`.
- [ ] `buildAutoDJPayload(server, ignoreList)` — currently a triple-quoted string with conditional commas in `audio_stuff.autoDJ:283-286`; this is brittle.

### Layer 2 — Widget tests with mocked plugins

**What it covers**: rendering of individual widgets, stream-based UI updates, tap handling, navigation. The `BottomBar`, `NowPlaying`, `Browser` screens, drawer items.

**Cost**: medium. Each test needs:
- `TestDefaultBinaryMessengerBinding` mocks for `path_provider`, `flutter_downloader`, `audio_service`. (The audio_service package ships test helpers — use them.)
- A way to seed singletons. Since the singletons are real instances backed by static fields, the test pattern is: in `setUp`, push known data into the singleton's streams (`BrowserManager()._browserStream.add(...)`), then in `tearDown` reset.

**Targets**:
- [ ] `BottomBar` smoke test — pumps with a fake `MediaManager` audio handler, verifies play/pause toggle reacts to playback state stream.
- [ ] `Browser` screen — pumps with seeded `BrowserManager.browserList`, taps an item, verifies the right `ApiManager` method gets called (requires `ApiManager` to be mockable — see Refactoring section).
- [ ] `NowPlaying` queue — pumps with seeded queue stream, verifies items render with title + artist.
- [ ] `AddServerScreen` form validation — text input, error states.

**Regression value**: catches UI regressions from `flutter_slidable` major version bumps, theme changes, breaking widget API changes (e.g. `PopScope` renames). This is the layer that catches the kinds of bugs that current modernization work introduces.

### Layer 3 — Golden tests (visual regression)

**What it covers**: pixel-level rendering of stable screens. Catches accidental layout, color, font, or icon changes.

**Cost**: medium-high upfront (need to capture baselines on a known platform; goldens are platform-sensitive — flutter publishes goldens via CI on Linux), low ongoing. Run with `flutter test --update-goldens` to refresh, then `flutter test` to verify.

**Targets** (one golden per stable screen):
- [ ] Empty/no-server state of `Browser`.
- [ ] Browser screen with seeded album list.
- [ ] `BottomBar` in playing/paused/shuffle states.
- [ ] `Drawer` menu.
- [ ] `AddServerScreen` initial state.

**Notes**:
- Run goldens only on a single OS (e.g. Linux in CI, or your dev box). Skip them on Windows/macOS — anti-aliasing differs.
- Don't golden the `NowPlaying` list with album art — network images create flake. Stub `Image.network` with a fake provider, or assert structure-only.

**Regression value**: high for UI-heavy refactors; ~zero for logic changes. Use selectively.

### Layer 4 — Integration tests on a real emulator

**What it covers**: end-to-end flows. Add a server, browse to an album, queue a song, hit play, verify playback state. Real `audio_service`, real `just_audio`, real network if configured.

**Cost**: highest. Needs:
- Android emulator booted (`flutter emulators --launch <id>` then `flutter devices` to confirm).
- A controllable mStream backend. Easiest: spin up the real mStream server in this monorepo against a fixture music directory on `localhost:3000`, point the app at it via the integration-test setup.
- `dev_dependencies: integration_test: { sdk: flutter }` — currently absent from `pubspec.yaml`, will need adding.
- Test code lives in `integration_test/` (sibling of `test/`).

**Targets** (in priority order — each catches a frequent regression source):
- [ ] **Cold start, no server**: launch app, verify "Welcome To mStream" screen, no crashes.
- [ ] **Add server flow**: tap "+", enter URL, submit, verify navigation to browser, verify default browse items appear.
- [ ] **Browse + play**: tap "Albums", tap an album, tap a song, verify `audioHandler.play()` reaches `playing: true` state.
- [ ] **Queue manipulation**: queue 2 songs, swipe to dismiss one, verify queue length goes to 1.
- [ ] **Auto DJ toggle**: enable Auto DJ, verify subsequent track loads from `/api/v1/db/random-songs`.
- [ ] **Search**: type a query, verify results render in the three sections (artists, albums, titles).

**Screenshot capture on failure**: integration_test supports `binding.takeScreenshot('name')`. Wire each test's failure path to dump a screenshot, so when the loop fails, a human (or me) can see what the screen actually looked like.

**Regression value**: very high. This is the layer that catches the bugs the user actually hits — auth flows breaking, audio not starting, shuffle button doing nothing.

## The tight loop

Once layers 1, 2, and 4 each have at least a smoke test, the loop is:

```bash
# from C:/Users/paul/Documents/code/mstream_music
flutter analyze && flutter test                       # layers 1+2 — fast (<30s)
flutter test integration_test --device-id <emulator>  # layer 4 — slow (minutes)
```

Wrap that into a script, e.g. `scripts/check.sh`:

```bash
#!/usr/bin/env bash
set -e
flutter analyze
flutter test
if [ "$1" = "--full" ]; then
  flutter test integration_test
fi
```

In day-to-day work, run `./scripts/check.sh` after each meaningful change; run `./scripts/check.sh --full` before each commit.

## Refactoring required to unlock more testability

These are the *minimum* refactors that pay for themselves quickly. None changes app behavior.

1. **Extract API response parsers from `ApiManager` into pure functions** (`lib/api/parsers.dart`). Unblocks ~8 quick unit tests.

2. **Extract URL builders** (`buildMediaUrl`, `buildAlbumArtUrl`, `buildAutoDJPayload`). Currently duplicated and slightly inconsistent across `api.dart` and `audio_stuff.dart`. This refactor + tests will likely catch a real bug in URL encoding.

3. **Inject `http.Client` into `ApiManager`** (constructor parameter, default `http.Client()`). Lets layer-2 tests verify request/response handling without standing up a real server.

4. **Split `audio_stuff.AudioPlayerHandler.autoDJ` HTTP call out of the handler**. The HTTP call is doing JSON construction, network, parsing, and queue manipulation in one method. Splitting parse from effect lets us unit-test the response → MediaItem transformation.

## What we are NOT testing (and why)

- **`flutter_downloader` callbacks**. Lifecycle is bound to platform isolates; running it in a unit test is more work than it's worth. Cover via integration tests only.
- **`audio_service` background notification UI**. Visible only on a real device; not testable from Flutter.
- **iOS-specific paths**. Project targets Android primarily; iOS testing is out of scope unless an emulator is set up.
- **Color/theme exact values**. Material 3 + theme tweaks change pixels constantly; gate via golden tests on stable screens only, never assert exact `Color(0xFF…)` values in widget tests.

## Known follow-ups (not regressions, but worth the round trip)

- [ ] **`flutter_slidable` 3.1.2 → 4.0.3 major bump** — held back from this dep upgrade because major bumps deserve their own PR + regression sweep. Likely changes `ActionPane` / `Slidable` API.
- [ ] **`ConcatenatingAudioSource` deprecation** — migrate `audio_stuff.dart:19` to `AudioPlayer.setAudioSources`. This is the kind of change that needs Layer 4 integration tests around playback before it's safe to do.
- [ ] **Dead code**: remove `_deleteServeDirectory` in [lib/singletons/server_list.dart:200](lib/singletons/server_list.dart#L200) (or wire it back up — comment in `removeServer` suggests it was intentionally disabled).

## Suggested next steps, in order

1. Stand up an Android emulator and confirm `flutter run` works against it (sanity check before any test work).
2. Add `integration_test` dev dependency and write the **cold-start, no-server** integration test — smallest possible end-to-end test that exercises the platform-plugin init path.
3. Do refactor #1 (extract parsers) and add unit tests for the 8 parsers. Roughly one session.
4. Add the **add server** integration test (covers the most-frequently-broken flow during modernization).
5. Add golden tests for the empty browser screen and the bottom bar.
6. From there, iterate as bugs are found — every regression caught in the wild gets a test added retroactively so it can't reappear.
