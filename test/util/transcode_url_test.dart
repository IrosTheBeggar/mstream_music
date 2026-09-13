import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/transcode.dart';
import 'package:mstream_music/util/stream_url.dart';

void main() {
  test('buildServerTranscodeUrl: /transcode with the tier and the token, whatever the playback setting', () {
    TranscodeManager().transcodeOn = false;
    final s = Server('http://h:3000', 'u', 'p', 'JWT', 'home');
    expect(buildServerTranscodeUrl(s, '/Music/A B/1 #2.flac', codec: 'opus', bitrate: '96k'),
        'http://h:3000/transcode/Music/A%20B/1%20%232.flac?codec=opus&bitrate=96k&token=JWT');
    final pub = Server('http://h:3000', null, null, null, 'pub');
    expect(buildServerTranscodeUrl(pub, '/m/x.mp3', codec: 'mp3', bitrate: '128k'),
        'http://h:3000/transcode/m/x.mp3?codec=mp3&bitrate=128k');
    expect(buildServerDownloadUrl(s, '/m/x.mp3'), 'http://h:3000/media/m/x.mp3?token=JWT',
        reason: 'a download still fetches the original');
  });
}
