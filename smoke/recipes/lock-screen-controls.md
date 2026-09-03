# Lock-screen shuffle and repeat

New since the handler advertises `setShuffleMode` / `setRepeatMode`.

**Do.** Play, lock the phone. Android: expand the media notification and the lock-screen player; iOS: lock screen and Control Center. Toggle shuffle and cycle repeat where offered; check the app agrees when unlocked.

**Pass.** The controls appear where the OS offers them, each toggle is reflected in the app's player panel, and the app's own toggles are reflected back within a second. `smoke/android/session-actions.sh` covers the advertised half automatically.
