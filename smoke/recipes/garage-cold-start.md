# Cold start with no service

**Setup.** Quick Connect server as default. Kill the app. Stand where there is no signal (garage, basement).

**Do.** Open the app, wait 20 s, walk or drive to signal.

**Pass.**
- Browser home grid usable within a second (the strip shows "Connecting…", that is fine — you are on the Quick Connect server).
- Mini-player fills in within 12 s of launch even with no service (the queue restores parked).
- Once service arrives: `retry #N` in the export leads to `tunnel up`, then `iroh tunnel back — resuming parked playback` if you had pressed play.
- Never a `tunnel start failed` without a `retry #… in …s` after it.
