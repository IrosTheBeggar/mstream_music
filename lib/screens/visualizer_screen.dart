// Full-screen Milkdrop-style visualizer. Tries to bring up the native
// bridge (projectM via Kotlin + JNI + EGL); falls back to a status
// placeholder if the bridge can't start (e.g. iOS/macOS/Linux, or
// Android device without an EGL context).

import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../native/projectm_controller.dart';
import '../native/visualizer_bridge.dart';
import '../native/visualizer_presets.dart';
import '../singletons/settings.dart';
import '../singletons/visualizer_audio.dart';
import '../theme/velvet_theme.dart';

class VisualizerScreen extends StatefulWidget {
  @override
  State<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends State<VisualizerScreen>
    with WidgetsBindingObserver {
  int? _textureId;
  String? _bridgeError;
  bool _bringingUp = false;
  // Tracks whether we've parked the bridge so didChangeAppLifecycleState
  // doesn't double-pause / double-resume.
  bool _backgroundPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bringUpBridge());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VisualizerAudio().stop();
    VisualizerBridge.dispose();
    super.dispose();
  }

  // When the OS moves the app off-screen, park the native render
  // loop and stop synthesizing PCM. On resume, kick both back up.
  // No-op while the bridge isn't alive (e.g. on non-Android, or
  // before _bringUpBridge has succeeded).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_textureId == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (!_backgroundPaused) {
          _backgroundPaused = true;
          VisualizerAudio().stop();
          VisualizerBridge.pause();
        }
        break;
      case AppLifecycleState.resumed:
        if (_backgroundPaused) {
          _backgroundPaused = false;
          VisualizerBridge.resume();
          VisualizerAudio().start();
        }
        break;
      case AppLifecycleState.detached:
        // App is shutting down — dispose() will run shortly.
        break;
    }
  }

  Future<void> _bringUpBridge() async {
    if (_bringingUp || !mounted) return;
    _bringingUp = true;

    // Size the GL surface to the screen's pixel dimensions so the
    // visualizer renders at full resolution.
    final view = View.of(context);
    final size = view.physicalSize;
    final w = size.width.round().clamp(64, 4096);
    final h = size.height.round().clamp(64, 4096);

    final id = await VisualizerBridge.create(width: w, height: h);
    if (!mounted) return;
    setState(() {
      _textureId = id;
      _bridgeError = id == null ? 'Bridge failed to start' : null;
      _bringingUp = false;
    });
    // Audio source feed only matters if the texture came up; without
    // a bridge there's nothing on the receiving end to consume PCM.
    if (id != null) {
      VisualizerAudio().start();
      // Pick a random Milkdrop preset on bringup. Without this projectM
      // falls back to its idle preset (still nice, but every session
      // looks the same).
      await VisualizerPresets().loadRandom(smooth: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = Platform.isAndroid;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Visualizer'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tap when rendering = next preset (so the user can cycle).
        // Tap when stuck on the placeholder = close (no preset to
        // switch). Long-press always closes — escape hatch.
        onTap: () {
          if (_textureId != null) {
            VisualizerPresets().loadNext();
          } else {
            Navigator.of(context).maybePop();
          }
        },
        onLongPress: () => Navigator.of(context).maybePop(),
        child: supported ? _androidBody() : _unsupported(),
      ),
    );
  }

  Widget _androidBody() {
    // Three rendering states:
    //   * waiting for the bridge to come up — show the status placeholder
    //   * bridge up, texture id assigned — show the Texture widget
    //     (projectM frames are pushed into it from the native render
    //     thread)
    //   * bridge failed — show the placeholder with an error line
    if (_textureId != null) {
      return Stack(
        children: [
          Positioned.fill(child: Texture(textureId: _textureId!)),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Text(
              'Tap = next preset · long-press to close',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(160),
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      );
    }
    return Center(child: _statusPlaceholder());
  }

  Widget _statusPlaceholder() {
    final source = SettingsManager().visualizerAudioSource;
    final projectMLoaded = ProjectMController.isAvailable;
    final statusLine = ProjectMController.statusLine();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _bridgeError != null
                ? Icons.error_outline
                : (projectMLoaded
                    ? Icons.hourglass_top
                    : Icons.auto_awesome),
            size: 72,
            color: _bridgeError != null
                ? Colors.redAccent
                : (projectMLoaded
                    ? Colors.greenAccent
                    : VelvetColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            _bridgeError != null
                ? 'Visualizer failed to start'
                : _bringingUp
                    ? 'Bringing up renderer…'
                    : 'Visualizer ready',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusLine,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: projectMLoaded
                  ? Colors.greenAccent
                  : VelvetColors.textSecondary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          if (_bridgeError != null) ...[
            const SizedBox(height: 6),
            Text(
              _bridgeError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Audio source: ${source.label.toLowerCase()}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VelvetColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tap anywhere to close',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VelvetColors.textTertiary,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _unsupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Visualizer is currently only supported on Android.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: VelvetColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
