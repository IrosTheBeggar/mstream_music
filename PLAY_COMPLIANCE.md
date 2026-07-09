# Google Play compliance — permissions & Data safety

Reference for the `play` flavor's Play Console submission: the sensitive-permission
declarations and the Data safety form. The `play` build (`mstream.music`) is the
Play-compliant edition; the `full` sideload build (`mstream.music.plus`) is not on
Play. This is guidance — the developer owns the final declarations.

## Permissions the `play` build requests

| Permission | Why | Optional? |
| --- | --- | --- |
| `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE` | Reach the user's mStream server; DLNA/Chromecast and mStream (`_mstream._tcp`, Quick Connect) discovery use Wi-Fi multicast | — |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK` | Background audio playback + background downloads | — |
| `POST_NOTIFICATIONS` | Now-playing / download notifications | — |
| `RECEIVE_BOOT_COMPLETED` | Resume/restore playback state | — |
| **`CAMERA`** | **Scan an iroh Remote-Access pairing QR code** (add-server → iroh tab) | Yes — `uses-feature android.hardware.camera required="false"` |
| `RECORD_AUDIO` | Opt-in "real audio" music visualizer (Android Visualizer API needs it to read the app's own output) | Yes — `uses-feature android.hardware.microphone required="false"` |

The `play` flavor deliberately **omits** `MANAGE_EXTERNAL_STORAGE` / `READ`/`WRITE_EXTERNAL_STORAGE`
(it uses app-scoped storage) and strips the location permissions the cast plugins
pull in transitively — see `android/app/src/main/AndroidManifest.xml`.

## Sensitive-permission declarations (Play Console → App content → Permissions)

### CAMERA
- **Use:** the only camera use is scanning a **QR pairing code** to connect the app
  to the user's self-hosted mStream server over iroh (peer-to-peer Remote Access).
- **Behavior:** the camera preview decodes the QR **on-device** (ML Kit via
  `mobile_scanner`); the decoded text is the pairing code. **No photos or video are
  captured, saved, or transmitted.** Pairing also works by pasting the code, so the
  camera is optional (`required="false"`).
- **Suggested declaration text:** "Camera is used solely to scan a QR code that pairs
  the app with the user's own media server. The image is processed on-device to read
  the QR; no photos or video are stored or sent."

### RECORD_AUDIO (microphone)
- **Use:** only when the user opts into the "real audio" visualizer mode. Android's
  `Visualizer` API requires `RECORD_AUDIO` even to read the app's **own** playback
  output. No microphone audio is recorded, stored, or transmitted.

## Data safety form

The app is a client for the **user's own** self-hosted mStream server. The developer
operates **no backend** and **collects no data**. Library, account, and playback data
travel only between the user's device and their server.

- **Does the app collect or share user data?** No data is collected or shared **with
  the developer**. All data flows to the user's own server.
- **Camera:** No data collected. (On-device QR decode; nothing stored/sent.)
- **Microphone:** No data collected. (On-device visualizer; opt-in.)
- **Account info / audio (library) / app activity:** sent only to the user's own
  server, which the user controls — not to the developer or any developer service.
- **Encrypted in transit?** **Yes.** HTTP-over-TLS for direct server connections;
  the iroh transport is QUIC with end-to-end encryption.

### iroh relay routing — the disclosure to get right
iroh connects **peer-to-peer**. When it can't hole-punch a direct path (strict NAT),
it falls back to routing through **relay servers** (the public n0 relays by default).

- The relay forwards **opaque, end-to-end-encrypted QUIC bytes** — it is a transport
  intermediary (like an ISP or CDN) and **cannot read** the content (credentials,
  library, audio). It does not store or use the data.
- Recommended Data-safety stance: this is **transit through a service provider**, not
  "sharing data with a third party," and the connection **is encrypted in transit**.
  We therefore do **not** declare it as data sharing, but it is documented here for
  transparency and so the relay operator is a known dependency.
- If you prefer maximal transparency (or self-host relays to remove the third party),
  note it in the store listing; the relay set is configurable on the server side.

## Notes
- `uses-feature` for both camera and microphone is `required="false"`, so Play does
  **not** exclude camera-less / mic-less devices.
- Keep this in sync if permissions change. The iroh transport's network behavior is
  detailed in `IROH_KEEPALIVE_BATTERY.md` and `IROH_TRANSPORT_PLAN.md`.
