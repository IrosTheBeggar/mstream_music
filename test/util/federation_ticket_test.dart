// The friend's-side read of a federation ticket: the same envelope the
// server builds (`mstrfed<V>:<base64url(JSON)>`), found inside whatever the
// user pasted — the bare string, a text message, a link with the ticket in
// its fragment — and validated the way the server validates it.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/federation_ticket.dart';

String _ticket(Map<String, dynamic> payload, {int version = 1}) {
  final body =
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return 'mstrfed$version:$body';
}

void main() {
  final full = _ticket({
    't': 'endpoint-ticket',
    'k': 'fedk_abc',
    'n': "Bob's NAS",
    'l': ['Vinyl', 'Podcasts'],
    'e': '2030-01-02T03:04:05.000Z',
  });

  test('a bare ticket parses with every informational field', () {
    final r = FederationTicket.parse(full);
    expect(r.isOk, isTrue);
    final t = r.ticket!;
    expect(t.raw, full);
    expect(t.version, 1);
    expect(t.endpointTicket, 'endpoint-ticket');
    expect(t.apiKey, 'fedk_abc');
    expect(t.serverName, "Bob's NAS");
    expect(t.libraries, ['Vinyl', 'Podcasts']);
    expect(t.expiresAt, DateTime.utc(2030, 1, 2, 3, 4, 5).toLocal());
    expect(t.isExpired, isFalse);
  });

  test('the ticket is found inside a text message and inside a link', () {
    final msg = 'Paste this in mStream:\n\n$full\n\nIt works once.';
    expect(FederationTicket.extract(msg), full);
    expect(FederationTicket.parse(msg).ticket?.raw, full);
    final link = 'https://mstream.io/f#$full';
    expect(FederationTicket.parse(link).ticket?.raw, full);
  });

  test('only t and k are required; padding is tolerated', () {
    final minimal = _ticket({'t': 'x', 'k': 'y'});
    final r = FederationTicket.parse('$minimal==');
    expect(r.isOk, isTrue);
    expect(r.ticket!.serverName, isNull);
    expect(r.ticket!.libraries, isEmpty);
    expect(r.ticket!.expiresAt, isNull);
    expect(r.ticket!.raw, '$minimal==');
  });

  test('a guest ticket, plain text and garbage are not tickets', () {
    final guest = 'mstrfedg1:${base64Url.encode(utf8.encode('{"t":"a","g":"b"}'))}';
    expect(FederationTicket.parse(guest).error, FederationTicketError.notFound);
    expect(FederationTicket.parse('hello').error, FederationTicketError.notFound);
    expect(FederationTicket.parse('mstrfed1:!!!').error,
        FederationTicketError.notFound);
    expect(FederationTicket.parse('mstrfed1:${base64Url.encode(utf8.encode('[1]'))}')
        .error, FederationTicketError.malformed);
    expect(FederationTicket.parse(_ticket({'t': 'only-t'})).error,
        FederationTicketError.malformed);
  });

  test('a newer format is refused rather than misread', () {
    final r = FederationTicket.parse(_ticket({'t': 'x', 'k': 'y'}, version: 2));
    expect(r.error, FederationTicketError.tooNew);
  });

  test('an expiry in the past reads as expired', () {
    final r = FederationTicket.parse(
        _ticket({'t': 'x', 'k': 'y', 'e': '2020-01-01T00:00:00Z'}));
    expect(r.ticket!.isExpired, isTrue);
  });
}
