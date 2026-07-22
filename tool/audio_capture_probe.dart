// Probe for the WASAPI loopback capture shim. Opens the built audio_capture.dll,
// starts capture, samples for ~1s, and reports the endpoint sample rate + signal
// RMS. Play some audio first to see a non-zero level (proves real audio is being
// captured end-to-end); silence reads back ~0.
//
//   dart run tool/audio_capture_probe.dart
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';

typedef _IntVoidC = Int32 Function();
typedef _IntVoidD = int Function();
typedef _VoidC = Void Function();
typedef _VoidD = void Function();
typedef _ReadC = Int32 Function(Pointer<Float>, Int32);
typedef _ReadD = int Function(Pointer<Float>, int);
typedef _ErrC = Pointer<Utf8> Function();

void main() {
  final dll = File(
      r'build\windows\x64\runner\Release\audio_capture.dll');
  if (!dll.existsSync()) {
    stdout.writeln('not built: ${dll.path}');
    return;
  }
  final lib = DynamicLibrary.open(dll.absolute.path);
  final start = lib.lookupFunction<_IntVoidC, _IntVoidD>('ac_start');
  final stop = lib.lookupFunction<_VoidC, _VoidD>('ac_stop');
  final read = lib.lookupFunction<_ReadC, _ReadD>('ac_read');
  final rate = lib.lookupFunction<_IntVoidC, _IntVoidD>('ac_sample_rate');
  final err = lib.lookupFunction<_ErrC, _ErrC>('ac_last_error');

  if (start() != 0) {
    final e = err();
    stdout.writeln('ac_start failed: ${e == nullptr ? "?" : e.toDartString()}');
    return;
  }
  stdout.writeln('capture started · endpoint ${rate()} Hz');

  const n = 1024;
  final buf = calloc<Float>(n);
  var peak = 0.0;
  for (var s = 0; s < 10; s++) {
    sleep(const Duration(milliseconds: 100));
    final got = read(buf, n);
    var sum = 0.0;
    for (var i = 0; i < got; i++) {
      sum += buf[i] * buf[i];
    }
    final rms = got > 0 ? sqrt(sum / got) : 0.0;
    if (rms > peak) peak = rms;
    stdout.writeln('  +${(s + 1) * 100}ms  samples=$got  rms=${rms.toStringAsFixed(4)}');
  }
  calloc.free(buf);
  stop();
  stdout.writeln('peak rms=${peak.toStringAsFixed(4)} '
      '(~0 = silence; >0 = real audio captured)');
}
