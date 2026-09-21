# Home-screen widget

The Android Now Playing widget (`packages/now_playing_widget`). The script
`smoke/android/home-widget.sh` covers the mirror, the three buttons and a
Play tap after a kill, on an English launcher; this is what it cannot see.

**Do.** Long-press the home screen › Widgets › mStream, place the 4×1 and a
4×2. Play a track from each kind of server: a standard one, Quick Connect,
a federated peer. Switch the system to dark and back. Set the app's language
(Settings › Language) to another one, then back to the system's. Clear the
queue. Reboot the phone with a track paused. With the app killed from
Recents' "close all", press a Bluetooth headset's play key.

**Pass.** Both sizes show the cover, the title and the artist, and the icons
follow the wallpaper palette (Android 12+) and the dark switch. The cover
loads for all three server kinds — Quick Connect's rides the loopback tunnel,
the peer's the parent's `/art/` proxy, both of which the art provider used to
refuse. The two lines of the empty state and the button descriptions
(TalkBack) follow the app's language, not only the phone's. The empty state
appears within a second of clearing the queue. After the reboot the widget
shows the track with a Play icon (never a stale Pause). The Bluetooth resume
reaches the widget: it shows Pause within a few seconds, with no app window
ever opened — the `[widget] publish` line in Diagnostics › Share comes from
the headless boot.
