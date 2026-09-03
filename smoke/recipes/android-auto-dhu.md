# Android Auto with the desktop head unit

Not installed on this Mac yet: SDK Manager › SDK Tools › "Android Auto Desktop Head Unit emulator" installs it under `$ANDROID_SDK/extras/google/auto/`. On the phone: Android Auto › developer settings › "Start head unit server", then `adb forward tcp:5277 tcp:5277` and run `desktop-head-unit`.

**Do.** Force-kill the app first (cold bind). Browse the root, Albums, an album, play; use the Assistant: "play <album> on mStream". Then airplane mode for 60 s mid-browse.

**Pass.** Cold bind renders the tree without the app UI (`[auto] getChildren` lines with no `[app]` UI lines before them is fine). Lists during the outage show the notice rows ("Couldn't load"), never blank. Playback recovers after service returns.
