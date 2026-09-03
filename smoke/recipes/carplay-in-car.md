# CarPlay in the car

Needs the device build signed with the CarPlay+Siri provisioning profile.

**Do.**
1. Phone locked, app not running, plug in (or connect wirelessly). Tap mStream on the car display.
2. Browse Albums → an album → a track. Check artwork on Now Playing, the shuffle / repeat / DJ buttons, Queue, and the artist name as a button.
3. "Hey Siri, play <an album you have> on mStream." Then a song, then an artist, then something you don't have.
4. Unplug, wait a minute, plug back in.
5. With the Quick Connect server as default, drive through a dead zone while browsing.

**Pass.** Root list within a few seconds of the tap (cold launch, no phone UI). Artwork on Now Playing (the simulator never draws it; the car must). Siri resolves the three and says it can't find the fourth. Reconnect restores the last screen or the root. During a dead zone the lists show notice rows, never a permanent spinner; playback recovers by itself.
