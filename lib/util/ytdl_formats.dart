/// The formats Add from YouTube offers, from the server's
/// `supportedAudioFiles` map (spec §5).
///
/// The route validates `outputCodec` against that map's `true` keys
/// (mStream src/api/ytdl.js), so the menu offers nothing else. m4b and m3u
/// never appear: an audiobook container is no choice for a song, and m3u is
/// a playlist. AAC lands as an .m4a, so it is offered only in M4A's place.
library;

const kYtdlFormatOrder = ['mp3', 'm4a', 'opus', 'ogg', 'flac', 'wav'];

/// [enabled] = the server's supportedAudioFiles keys whose value is true (null = unknown/malformed).
/// Ordered by kYtdlFormatOrder; 'aac' appears (after m4a's slot) only when m4a is off; m4b and m3u never.
/// null or nothing usable → ['mp3'].
List<String> ytdlFormatOptions(List<String>? enabled) {
  if (enabled == null) return const ['mp3'];
  final on = enabled.toSet();
  final options = [
    for (final f in kYtdlFormatOrder) ...[
      if (on.contains(f)) f,
      if (f == 'm4a' && !on.contains('m4a') && on.contains('aac')) 'aac',
    ],
  ];
  return options.isEmpty ? const ['mp3'] : options;
}

/// mp3 when on, else the first option.
String ytdlDefaultFormat(List<String>? enabled) {
  final options = ytdlFormatOptions(enabled);
  return options.contains('mp3') ? 'mp3' : options.first;
}

/// [remembered] when it is still an option, else the default.
String ytdlEffectiveFormat(String? remembered, List<String>? enabled) =>
    remembered != null && ytdlFormatOptions(enabled).contains(remembered)
        ? remembered
        : ytdlDefaultFormat(enabled);

/// A format's name as the card, menus and rows show it — not localized,
/// like the transcode screen's codec names.
String ytdlFormatName(String codec) => switch (codec.toLowerCase()) {
      'mp3' => 'MP3',
      'm4a' => 'M4A',
      'opus' => 'Opus',
      'ogg' => 'OGG Vorbis',
      'flac' => 'FLAC',
      'wav' => 'WAV',
      'aac' => 'AAC',
      final other => other.toUpperCase(),
    };
