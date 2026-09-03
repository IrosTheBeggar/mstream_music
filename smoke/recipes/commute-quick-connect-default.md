# Commute with the Quick Connect server as default

The end-to-end check of the tunnel work (PRs #133, #134) on the real carrier.

**Setup.** Quick Connect server first in the server list, Auto DJ on it, keep-queue-offline as you normally run it. Start playback at home on Wi-Fi.

**Do.** Drive the usual route: the Wi-Fi → cellular hand-off leaving the house, every dead zone, the return. Do not touch the app unless something is wrong; if you do tap Retry, note the time.

**Pass.**
- No manual Retry needed; playback resumes on its own after every gap.
- In the export: every gap ends with `reconnected: attempt N` on the same port as `tunnel up port=…` at launch, and `stream URLs rebuilt` does not appear.
- Auto DJ picks that landed during a gap show `pick landed — resuming the parked queue`.

**Capture.** Diagnostics › Share at the end of the drive. Note any moment the app felt stalled and the clock time.
