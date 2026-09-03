# Commute with the LAN server as default, queue on Quick Connect

The configuration fixed in PR #137, never driven. The standard server becomes unreachable the moment you leave the house while the queue keeps streaming through the tunnel.

**Setup.** Standard (LAN) server first in the list, Quick Connect second, a queue that was started from the Quick Connect server.

**Do.** Open the app at home (browser should be up at once, no strip), play, drive away. At some point away from home, open the browser and tap a section on the LAN server; then switch to the Quick Connect server with the picker and browse.

**Pass.**
- At launch: home grid within a second, no "Connecting to server…" strip.
- Away from home: playback continues; the LAN server shows a clear failure, not a spinner or a blank panel.
- The picker switch to Quick Connect works immediately; the strip appears only if that tunnel is actually reconnecting.
- Export: `[app] default server ready` within 2 s of `mStream … started`, one `tunnel up … (queue-server)`, no `tunnel stopped (no-target`.
