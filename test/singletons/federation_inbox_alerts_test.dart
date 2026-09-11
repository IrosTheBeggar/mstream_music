import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/federation_inbox_alerts.dart';

void main() {
  group('inboxAlertFor', () {
    test('a rise is news', () {
      expect(inboxAlertFor(previous: 0, current: 1, enabled: true),
          InboxAlert.notify);
      expect(inboxAlertFor(previous: null, current: 2, enabled: true),
          InboxAlert.notify,
          reason: 'never seen a count before: an unknown is an empty inbox');
      expect(inboxAlertFor(previous: 1, current: 3, enabled: true),
          InboxAlert.notify);
    });

    test('the same number again says nothing', () {
      expect(inboxAlertFor(previous: 2, current: 2, enabled: true),
          InboxAlert.none);
      expect(inboxAlertFor(previous: null, current: 0, enabled: true),
          InboxAlert.none);
    });

    test('a drop retires whatever the shade shows', () {
      expect(inboxAlertFor(previous: 2, current: 1, enabled: true),
          InboxAlert.clear);
      expect(inboxAlertFor(previous: 1, current: 0, enabled: true),
          InboxAlert.clear);
      // Even with alerts off: a stale entry from before the switch flipped.
      expect(inboxAlertFor(previous: 1, current: 0, enabled: false),
          InboxAlert.clear);
    });

    test('switched off never notifies', () {
      expect(inboxAlertFor(previous: 0, current: 1, enabled: false),
          InboxAlert.none);
    });
  });

  group('shouldPollInbox', () {
    test('only our own servers that have answered with the field', () {
      final s = Server('https://home.example.com', null, null, 'JWT', 'home');
      expect(shouldPollInbox(s), isFalse,
          reason: 'never pinged, or an older build without the count');
      s.federationInbox = 0;
      expect(shouldPollInbox(s), isTrue);
      final peer = Server('federated://home/1', null, null, null, 'home-1')
        ..federationParent = 'home'
        ..federationInbox = 1;
      expect(shouldPollInbox(peer), isFalse,
          reason: "a peer's requests are its operator's business");
    });
  });
}
