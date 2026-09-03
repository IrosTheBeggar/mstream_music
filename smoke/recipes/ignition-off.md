# Ignition off with music playing (five cycles)

The late-PAUSE race fixed in PR #135, in the real car.

**Do.** Five times: play over the car's Bluetooth, turn the ignition off, wait 20 s, listen. Then start the car again and check playback resumes the way you expect from that head unit.

**Pass.** Silence after every ignition-off. Export: each cycle shows `output disconnected — pausing`, and if the head unit sent its late PAUSE, `media button toggle ignored — output lost Ns ago`. No `[play] play` between the disconnect and the next time you touch the app or the car turns on.
