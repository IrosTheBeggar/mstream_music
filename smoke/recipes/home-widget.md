# Home-screen widget

The Android Now Playing widget (`packages/now_playing_widget`). The script
`smoke/android/home-widget.sh` covers the mirror, the three buttons and a
Play tap after a kill, on an English launcher; this is what it cannot see.

**Do.** Long-press the home screen › Widgets › mStream, place one, then
resize copies to every size: 2×1 (mini), 2×2 (tile), 4×1 (row), 4×2 (card)
and 4×3 or taller (large, with the album line, progress and shuffle /
repeat). Play a track from each kind of server: a standard one, Quick Connect,
a federated peer. Switch the system to dark and back. Set the app's language
(Settings › Language) to another one, then back to the system's. Clear the
queue. Reboot the phone with a track paused. With the app killed from
Recents' "close all", press a Bluetooth headset's play key.

**Pass.** Every size shows the cover, the title and the artist, and the icons
follow the wallpaper palette (Android 12+) and the dark switch; the tile's
cover fills it with the text on a dark strip. On the large one the progress
bar and elapsed time move every few seconds while playing and stop when
paused, and its shuffle and repeat icons follow the app's own toggles both
ways (the app's within a second, the widget's on the next publish). The cover
loads for all three server kinds — Quick Connect's rides the loopback tunnel,
the peer's the parent's `/art/` proxy, both of which the art provider used to
refuse. The two lines of the empty state and the button descriptions
(TalkBack) follow the app's language, not only the phone's. The empty state
appears within a second of clearing the queue. After the reboot the widget
shows the track with a Play icon (never a stale Pause). The Bluetooth resume
reaches the widget: it shows Pause within a few seconds, with no app window
ever opened — the `[widget] publish` line in Diagnostics › Share comes from
the headless boot.

## iOS

`smoke/ios/widget-sim.sh` checks the bundle, the App Group snapshot, the
intent handshake and a play / pause / next round trip through the same path
the widget's buttons take. Placing the widget is by hand.

**Do.** Simulator (iOS 17+): long-press the home screen › Edit › Add Widget ›
mStream Music, add the small, medium and large sizes; on iOS 16+ add the lock
screen one too. Play a track in the app, go home, tap the widget's pause,
play, next, and on the large one shuffle and repeat. Then, with the app
swiped away from the app switcher, tap play on the widget. On an iOS 16 phone
(the iPhone X) tap the widget itself.

**Pass.** Every size shows the cover, the title and the artist; the large one
shows the album line, a progress bar and an elapsed time that both move
while playing without the app publishing anything (they are WidgetKit's
self-updating timer views; a plain label would sit at 0:00 until the next
reload), and the five buttons. Each button acts within a second and the widget follows (the app's
`[widget] <action>: sent` then `[widget] action: <action>` in Diagnostics ›
Share). With the app swiped away, a play tap launches it in the background
and the log shows `[widget] play: Dart not up yet, holding` and then `sent
after the handshake`. On iOS 16 a tap on the widget opens the app. With the
phone in another language the gallery entry reads in it; with the app's own
language set (Settings › Language) the placed widget's "Nothing playing"
reads in that one, as on Android.

Seeding a queue on the simulator when it restored none: copy the emulator's
rig queue (`adb shell run-as mstream.music.plus.dev cat app_flutter/queue.json`)
into the app container's `Documents/queue.json`
(`xcrun simctl get_app_container <udid> mstream.music data`), rewriting
`10.0.2.2:3161` to `127.0.0.1:3161`, and put that rig first in
`Documents/servers.json`.
