/// What kind of device a [CastTarget] is. Drives the icon shown in the picker
/// and (later) which backend is built when the target is selected.
enum CastTargetKind { local, dlna, chromecast }

/// A selectable playback destination shown in the cast picker: either the
/// local device (on-device just_audio playback) or a remote renderer
/// discovered on the network.
class CastTarget {
  /// Stable identity. The local device uses [localId]; remote devices use
  /// their protocol id (UDN for DLNA, the Cast device id for Chromecast).
  final String id;
  final String name;
  final CastTargetKind kind;

  const CastTarget({
    required this.id,
    required this.name,
    required this.kind,
  });

  /// Sentinel id for "this device" (local just_audio playback).
  static const String localId = '__local__';

  /// The always-present local target.
  static const CastTarget local = CastTarget(
    id: localId,
    name: 'This device',
    kind: CastTargetKind.local,
  );

  bool get isLocal => kind == CastTargetKind.local;

  @override
  bool operator ==(Object other) =>
      other is CastTarget && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);

  @override
  String toString() => 'CastTarget($kind, $name, $id)';
}
