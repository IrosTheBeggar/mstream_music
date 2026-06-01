import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../media/local_media_server.dart';
import '../media/visualizer_cast_spike.dart';
import '../native/shader_params.dart';
import '../native/visualizer_bridge.dart';
import '../objects/server.dart';
import '../screens/visualizer_screen.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../singletons/sleep_timer.dart';
import '../theme/velvet_theme.dart';
import 'sleep_timer_sheet.dart';

/// "More" actions bottom sheet — collects the session/secondary controls that
/// used to crowd the bottom bar (Auto DJ, sleep timer, visualizer, clear
/// queue), leaving the bar to transport + shuffle/repeat.
///
/// [parentContext] is a context ABOVE this sheet (the bottom bar's), used to
/// launch follow-on navigation / sheets after this one is dismissed — the
/// sheet's own context is gone once it's popped.
class MoreActionsSheet extends StatelessWidget {
  final BuildContext parentContext;
  const MoreActionsSheet({required this.parentContext});

  void _toggleAutoDJ(BuildContext context, Server? autoDJState) {
    final current = ServerManager().currentServer;
    if (current == null) return;
    final handler = MediaManager().audioHandler;
    final messenger = ScaffoldMessenger.of(context);
    if (autoDJState == null) {
      handler.customAction('setAutoDJ', {'autoDJServer': current});
      messenger.showSnackBar(SnackBar(
          content: Text(ServerManager().serverList.length == 1
              ? 'Auto DJ Enabled'
              : 'Auto DJ Enabled For ${current.url}')));
    } else if (current == autoDJState) {
      handler.customAction('setAutoDJ', {'autoDJServer': null});
      messenger
          .showSnackBar(const SnackBar(content: Text('Auto DJ Disabled')));
    } else {
      handler.customAction('setAutoDJ', {'autoDJServer': current});
      messenger.showSnackBar(
          SnackBar(content: Text('Auto DJ Enabled For ${current.url}')));
    }
  }

  // DEBUG (visualizer-cast Phase 0a spike): transcode the current track to a
  // local MP4 of the visualizer reacting to it, so the A/V pipeline + visual
  // quality (and audio sync) can be judged on the phone with no Chromecast.
  Future<void> _runVisualizerSpike(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final item = MediaManager().audioHandler.mediaItem.valueOrNull;
    if (item == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Queue a track first')));
      return;
    }
    final source = (item.extras?['localPath'] as String?) ?? item.id;
    // Always render the spectrum-bars ("equalizer") shader for the spike — it's
    // the most audio-responsive, so it's easy to tell whether reactivity works.
    String? preset;
    try {
      preset =
          await rootBundle.loadString('assets/shaders/01-spectrum-bars.glsl');
    } catch (_) {}
    // Shader visuals react to audio through iParams; replicate the on-screen
    // path's tuning push (global response curve + per-shader defaults).
    final tuning = preset != null
        ? <double>[
            ...SettingsManager.defaultGlobalParams,
            for (final p in parseShaderParams(preset)) p.def,
          ]
        : null;
    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No external storage available')));
      return;
    }
    final output = '${dir.path}/viz_spike.mp4';
    messenger.showSnackBar(const SnackBar(
        content: Text('Transcoding visualizer to MP4… (~20s)')));
    final result = await VisualizerBridge.startTranscode(
      source: source,
      output: output,
      preset: preset,
      engine: VisualizerBridge.engineShader,
      maxMs: 20000,
      tuning: tuning,
    );
    messenger.showSnackBar(SnackBar(
      content:
          Text(result != null ? 'Saved: $result' : 'Transcode failed — see logcat'),
      duration: const Duration(seconds: 10),
    ));
  }

  // DEBUG (Phase 0b validation): render the current track's visualizer to MP4,
  // serve it from the on-device server, and cast it to the first Chromecast —
  // proves the cast-video path end-to-end before the live HLS muxer.
  Future<void> _castVisualizerToTv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final item = MediaManager().audioHandler.mediaItem.valueOrNull;
    if (item == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Queue a track first')));
      return;
    }
    final source = (item.extras?['localPath'] as String?) ?? item.id;
    String? preset;
    try {
      preset =
          await rootBundle.loadString('assets/shaders/01-spectrum-bars.glsl');
    } catch (_) {}
    final tuning = preset != null
        ? <double>[
            ...SettingsManager.defaultGlobalParams,
            for (final p in parseShaderParams(preset)) p.def,
          ]
        : null;
    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No external storage available')));
      return;
    }
    messenger.showSnackBar(
        const SnackBar(content: Text('Rendering visualizer… (~20s)')));
    final hlsDir = '${dir.path}/viz_hls';
    final playlist = await VisualizerBridge.startTranscode(
      source: source,
      output: hlsDir,
      preset: preset,
      engine: VisualizerBridge.engineShader,
      maxMs: 25000,
      tuning: tuning,
      mode: 'hls',
    );
    if (playlist == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Transcode failed — see logcat')));
      return;
    }
    try {
      await LocalMediaServer().ensureStarted();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Local server failed: $e')));
      return;
    }
    // Serve the HLS directory; the .m3u8 references its .ts segments relatively.
    final url = LocalMediaServer().registerDirectory(hlsDir);
    messenger.showSnackBar(
        const SnackBar(content: Text('Connecting to Chromecast…')));
    final err = await castVideoToFirstChromecast(url,
        title: item.title,
        subtitle: item.artist,
        contentType: 'application/x-mpegurl',
        statusLogPath: '$hlsDir/_status.log');
    messenger.showSnackBar(SnackBar(
      content: Text(err ?? 'Casting to your TV — check the screen'),
      duration: const Duration(seconds: 8),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Auto DJ — toggles in place; the switch reflects live state.
          StreamBuilder<dynamic>(
            stream: MediaManager().audioHandler.customState,
            builder: (context, snapshot) {
              final Server? autoDJState =
                  (snapshot.data?.autoDJState as Server?);
              final on = autoDJState != null;
              return SwitchListTile(
                secondary: Icon(Icons.album,
                    color: on
                        ? VelvetColors.primary
                        : VelvetColors.textSecondary),
                title: Text('Auto DJ',
                    style: TextStyle(color: VelvetColors.textPrimary)),
                subtitle: Text(on ? 'On' : 'Off',
                    style: TextStyle(color: VelvetColors.textSecondary)),
                value: on,
                activeThumbColor: VelvetColors.primary,
                onChanged: (_) => _toggleAutoDJ(context, autoDJState),
              );
            },
          ),
          // Sleep timer — opens the timer picker.
          StreamBuilder<Duration?>(
            stream: SleepTimerManager().remainingStream,
            initialData: SleepTimerManager().remaining,
            builder: (context, snapshot) {
              final d = snapshot.data;
              final active = d != null;
              return ListTile(
                leading: Icon(active ? Icons.bedtime : Icons.bedtime_outlined,
                    color: active
                        ? VelvetColors.primary
                        : VelvetColors.textSecondary),
                title: Text('Sleep timer',
                    style: TextStyle(color: VelvetColors.textPrimary)),
                subtitle: Text(d != null ? 'Pauses in ${_fmt(d)}' : 'Off',
                    style: TextStyle(color: VelvetColors.textSecondary)),
                onTap: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet(
                    context: parentContext,
                    backgroundColor: VelvetColors.surface,
                    isScrollControlled: true,
                    builder: (_) => SleepTimerSheet(),
                  );
                },
              );
            },
          ),
          // Visualizer.
          ListTile(
            leading:
                Icon(Icons.auto_awesome, color: VelvetColors.textSecondary),
            title: Text('Visualizer',
                style: TextStyle(color: VelvetColors.textPrimary)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(parentContext).push(
                MaterialPageRoute(builder: (_) => VisualizerScreen()),
              );
            },
          ),
          // DEBUG: visualizer-cast spike — render the current track to an MP4.
          ListTile(
            leading: Icon(Icons.movie_filter_outlined,
                color: VelvetColors.textSecondary),
            title: Text('Cast visualizer (spike test)',
                style: TextStyle(color: VelvetColors.textPrimary)),
            subtitle: Text('Render current track → MP4 on this device',
                style: TextStyle(color: VelvetColors.textSecondary)),
            onTap: () {
              Navigator.of(context).pop();
              _runVisualizerSpike(parentContext);
            },
          ),
          // DEBUG: cast the rendered visualizer to the Chromecast (Phase 0b).
          ListTile(
            leading: Icon(Icons.cast, color: VelvetColors.textSecondary),
            title: Text('Cast visualizer to TV (spike)',
                style: TextStyle(color: VelvetColors.textPrimary)),
            subtitle: Text('Render current track → cast to Chromecast',
                style: TextStyle(color: VelvetColors.textSecondary)),
            onTap: () {
              Navigator.of(context).pop();
              _castVisualizerToTv(parentContext);
            },
          ),
          // Clear queue.
          ListTile(
            leading: Icon(Icons.delete_sweep, color: VelvetColors.error),
            title: Text('Clear queue',
                style: TextStyle(color: VelvetColors.textPrimary)),
            onTap: () {
              Navigator.of(context).pop();
              MediaManager().audioHandler.customAction('clearPlaylist');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
