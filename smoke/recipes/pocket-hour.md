# An hour in the pocket, then play

iOS suspension and Android Doze. **Do.** Pause, lock the phone, leave it for an hour, unlock, open the app, press play.

**Pass.** Playing within a few seconds. iOS export: `probe #1 failed (refused` → `kicking the tunnel in place (resume)` → `listener re-bound` → `reconnected: attempt 1`. Android export: either nothing (the tunnel survived) or a single in-place reconnect. No `tunnel stopped`, no `stream URLs rebuilt`.
