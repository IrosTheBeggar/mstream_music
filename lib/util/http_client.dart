import 'package:http/http.dart' as http;

/// App-wide [http.Client] reused for one-shot API calls — the genre list, share
/// links, the server-path / ping probe, and AutoDJ top-ups. The package:http
/// convenience helpers (`http.get` / `http.post`) open AND tear down a fresh
/// connection per call, paying a full TLS handshake every time; reusing a single
/// Client lets those requests share pooled keep-alive connections.
///
/// Respects `HttpOverrides.global` (the self-signed-cert override installed in
/// main's _startApp): the underlying HttpClient is created lazily on first use,
/// which is always after startup. Lives for the app's lifetime — like the
/// manager singletons — so it is never closed.
///
/// NOT used by `ApiManager.makeServerCall`: that deliberately creates a per-call
/// Client so closing it aborts an in-flight browse (Back-to-cancel).
final http.Client appHttpClient = http.Client();
