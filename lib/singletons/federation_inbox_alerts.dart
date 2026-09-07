import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../screens/federation/federation_screen.dart';
import './app_messenger.dart';
import './log_manager.dart';
import './media.dart';
import './server_list.dart';
import './settings.dart';

/// What a freshly read inbox count means for the phone's notification shade.
enum InboxAlert { none, notify, clear }

/// The one rule behind the federation-request alert, kept pure for tests: a
/// rise is news, a drop makes whatever is showing stale (the in-app banner
/// keeps the live number), and an unchanged count says nothing.
InboxAlert inboxAlertFor(
    {required int? previous, required int current, required bool enabled}) {
  final prev = previous ?? 0;
  if (current == prev) return InboxAlert.none;
  if (current < prev) return InboxAlert.clear;
  return enabled ? InboxAlert.notify : InboxAlert.none;
}

/// Which servers the periodic poll re-pings: our own (a peer's requests are
/// its operator's business) that have already answered with the field — an
/// older server is never asked twice for a number it cannot give.
bool shouldPollInbox(Server s) => !s.isFederated && s.federationInbox != null;

/// Federation-request alerts: a phone notification when a request lands in an
/// admin's inbox while the app is open, or playing in the background.
///
/// The count itself travels on the boot payload (`user.federationInbox`), so
/// there is no second channel to keep up: ServerManager reports every value
/// it reads ([onCount]) and this class only decides whether the shade needs
/// a new entry. Between pings a timer re-pings the servers that carry the
/// field, but only while there is someone to tell — the app in front, or
/// audio playing (the isolate stays alive for the player then; with neither,
/// the OS suspends the app and the timer simply stops with it).
class FederationInboxAlerts {
  static final FederationInboxAlerts _instance = FederationInboxAlerts._();
  factory FederationInboxAlerts() => _instance;
  FederationInboxAlerts._();

  static const _channelId = 'federation_inbox';
  static const pollEvery = Duration(minutes: 3);

  final _plugin = FlutterLocalNotificationsPlugin();
  // The last count handled per server, so a ping that repeats a number the
  // shade already shows stays quiet.
  final Map<String, int> _known = {};
  bool _inited = false;
  bool _available = false;
  bool _foreground = true;
  bool? _permitted;
  String? _pendingOpen;
  Timer? _timer;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_music'),
          // The permission is asked for in context (a switch, the first
          // alert while the app is in front), never at launch.
          iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) => open(r.payload),
      );
      _available = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _pendingOpen = launch!.notificationResponse?.payload;
      }
    } catch (e) {
      appLog('[inbox] notifications unavailable here: $e');
    }
    _timer ??= Timer.periodic(pollEvery, (_) => unawaited(poll()));
  }

  /// Every count a ping (or the Federation screen) reads comes through here;
  /// [previous] is what the server object held before it.
  Future<void> onCount(Server server, int count, {int? previous}) async {
    final prev = _known[server.localname] ?? previous;
    _known[server.localname] = count;
    final verdict = inboxAlertFor(
        previous: prev,
        current: count,
        enabled: SettingsManager().notifyFederationRequests);
    if (verdict == InboxAlert.none || !_available) return;
    if (verdict == InboxAlert.clear) {
      await _plugin.cancel(id: _id(server));
      return;
    }
    if (!await _permission(prompt: _foreground)) return;
    final l = _l10n();
    await _plugin.show(
      id: _id(server),
      title: l.federationInboxNotificationTitle(count),
      body: l.federationInboxNotificationBody(server.displayName),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
            _channelId, l.federationInboxChannelName,
            channelDescription: l.federationInboxChannelDescription,
            importance: Importance.high,
            priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: server.localname,
    );
    appLog('[inbox] ${server.localname}: $count waiting — notified');
  }

  /// Re-ping the servers that carry the count. The ping path reads the field
  /// and lands in [onCount]; nothing here parses a response.
  Future<void> poll({bool force = false}) async {
    if (!force && !_foreground && !_playing) return;
    for (final s in ServerManager().serverList.where(shouldPollInbox)) {
      unawaited(ServerManager().getServerPaths(s));
    }
  }

  void onLifecycle(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    final wasFg = _foreground;
    _foreground = fg;
    // Coming back is the one moment a stale count is certain: re-ping now.
    if (fg && !wasFg) unawaited(poll(force: true));
  }

  /// Tap-through: the Federation screen of the server the payload names. On
  /// a cold launch from the shade the navigator is not up yet, so the open
  /// waits for [onFirstFrame].
  void open(String? localname) {
    if (localname == null) return;
    Server? server;
    for (final s in ServerManager().serverList) {
      if (s.localname == localname) server = s;
    }
    if (server == null) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) {
      _pendingOpen = localname;
      return;
    }
    final s = server;
    nav.push(MaterialPageRoute(builder: (_) => FederationScreen(parent: s)));
  }

  void onFirstFrame() {
    final p = _pendingOpen;
    _pendingOpen = null;
    if (p != null) open(p);
  }

  /// The OS permission, asked for when the user would understand why: a
  /// switch turned on, or the first alert while the app is in front.
  Future<bool> ensurePermission() => _permission(prompt: true);

  Future<bool> _permission({required bool prompt}) async {
    if (!_available) return false;
    if (_permitted == true) return true;
    // Not asking (app in the background): post anyway when undecided and
    // let the platform drop it if it must; a known refusal stays refused.
    if (!prompt) return _permitted ?? true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        _permitted = await android.requestNotificationsPermission() ?? true;
        return _permitted!;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        _permitted = await ios.requestPermissions(
                alert: true, badge: true, sound: true) ??
            false;
        return _permitted!;
      }
    } catch (e) {
      appLog('[inbox] permission request failed: $e');
    }
    return false;
  }

  bool get _playing {
    try {
      return MediaManager().audioHandler.playbackState.value.playing;
    } catch (_) {
      return false; // the handler is not up yet
    }
  }

  int _id(Server s) => s.localname.hashCode & 0x7fffffff;

  // Strings without a widget context: the live app's localizations when the
  // navigator is up, else the configured (or device) locale.
  AppLocalizations _l10n() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null) return AppLocalizations.of(ctx);
    final locale = SettingsManager().localeOverride ??
        WidgetsBinding.instance.platformDispatcher.locale;
    try {
      return lookupAppLocalizations(locale);
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }
}
