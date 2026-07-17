import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hash a password exactly the way the mStream server does
/// (src/util/auth.js): PBKDF2-HMAC-SHA512, 15000 iterations, 32-byte key,
/// 16-byte random salt — both base64. NB: the server passes the salt's
/// BASE64 TEXT to pbkdf2 (not the raw bytes), so we feed the utf8 bytes of
/// the base64 string as the salt. Used by the desktop onboarding to write
/// the first user straight into the server config.
({String hash, String salt}) hashServerPassword(String password) {
  final rnd = Random.secure();
  final saltBytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  final salt = base64.encode(saltBytes);
  final key = _pbkdf2Sha512(
      utf8.encode(password), utf8.encode(salt), 15000, 32);
  return (hash: base64.encode(key), salt: salt);
}

// RFC 2898 PBKDF2 over HMAC-SHA512. dkLen <= 64 here, so a single block.
List<int> _pbkdf2Sha512(
    List<int> password, List<int> salt, int iterations, int dkLen) {
  final prf = Hmac(sha512, password);
  final blocks = (dkLen / 64).ceil();
  final out = <int>[];
  for (var i = 1; i <= blocks; i++) {
    var u = prf.convert([
      ...salt,
      (i >> 24) & 0xff,
      (i >> 16) & 0xff,
      (i >> 8) & 0xff,
      i & 0xff,
    ]).bytes;
    final t = List<int>.of(u);
    for (var n = 1; n < iterations; n++) {
      u = prf.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.addAll(t);
  }
  return out.sublist(0, dkLen);
}
