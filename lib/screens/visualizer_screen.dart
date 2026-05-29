// Full-screen Milkdrop-style visualizer. Tries to bring up the native
// bridge (projectM via Kotlin + JNI + EGL); falls back to a status
// placeholder if the bridge can't start (e.g. iOS/macOS/Linux, or
// Android device without an EGL context).

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../native/projectm_controller.dart';
import '../native/shader_params.dart';
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
  // Snapshot at bringup so engine swaps via Settings only take effect
  // next time the visualizer opens — no half-swapped GL state.
  late final VisualizerEngine _engine =
      SettingsManager().visualizerEngine;
  VisualizerPresetKind get _presetKind => _engine == VisualizerEngine.shader
      ? VisualizerPresetKind.shader
      : VisualizerPresetKind.milkdrop;

  // --- Tuning panel (Shader engine + showVisualizerKnobs only) ---------
  // Whether to surface the live tuning sliders at all. Snapshotted at
  // bringup like _engine (the setting can't change while we're open).
  late final bool _knobsEnabled = _engine == VisualizerEngine.shader &&
      SettingsManager().showVisualizerKnobs;
  bool _panelOpen = false;
  String? _shaderKey; // current shader asset path (persistence key)
  List<ShaderParam> _shaderParams = const [];
  List<double> _paramValues = []; // per-shader iParams values
  List<double> _globalValues =
      List<double>.from(SettingsManager.defaultGlobalParams);

  // Slider [min, max] and labels for the global response-curve knobs, in
  // the same order as SettingsManager.defaultGlobalParams.
  static const List<List<double>> _globalRanges = [
    [-120.0, -50.0], // dB floor (minDb)
    [-60.0, -5.0], // dB ceiling (maxDb)
    [0.0, 0.95], // smoothing
  ];
  static const List<String> _globalLabels = [
    'dB floor',
    'dB ceiling',
    'Smoothing',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Full-immersive landscape for the visualizer. Hides status +
    // navigation bars so the shader uses every pixel; locks the
    // device to landscape because most Shadertoy/Milkdrop content
    // is composed for that aspect.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (Platform.isAndroid) {
      // Wait for the orientation change to settle before sampling the
      // physical size for the GL surface — a postFrameCallback alone
      // can fire while the screen is still portrait. 250ms is plenty
      // on every device I've tested and the user only sees black
      // during the gap.
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _bringUpBridge();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Restore the app chrome before the parent route reappears.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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
    if (!mounted || _textureId == null) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Backgrounded but the activity is still alive — home, app switch,
        // notification shade, etc. Park the render loop to save power and
        // STAY on the screen, so returning resumes the visualizer right
        // where it left off.
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
        // The activity was destroyed while the Flutter engine/isolate lives
        // on — which is exactly what swiping the app away from recents does
        // while audio_service keeps the process alive for playback. (A plain
        // home-press only stops the activity → 'paused', not 'detached', so
        // the visualizer survives and resumes.) Pop the visualizer so the
        // retained navigation stack drops back to the main screen and the
        // next open lands there. When nothing keeps the process alive,
        // swipe-away just kills it and a relaunch is a fresh start anyway.
        Navigator.of(context).maybePop();
        break;
    }
  }

  Future<void> _bringUpBridge() async {
    if (_bringingUp || !mounted) return;
    _bringingUp = true;

    // Size the GL surface to the screen's pixel dimensions in
    // landscape — we force landscape orientation in initState but
    // the orientation change may not have fully propagated by the
    // time we read physicalSize. max/min collapses both states to
    // the right landscape dimensions regardless.
    final view = View.of(context);
    final size = view.physicalSize;
    final w = math.max(size.width, size.height).round().clamp(64, 4096);
    final h = math.min(size.width, size.height).round().clamp(64, 4096);

    final id = await VisualizerBridge.create(
      width: w,
      height: h,
      engine: _engine.nativeKind,
    );
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
      // Pick a random preset matching the active engine. ProjectM
      // falls back to its idle preset if we don't load one (still
      // looks fine); ShaderEngine clears to black so loading is
      // essential.
      final path = await VisualizerPresets().loadRandom(_presetKind, smooth: false);
      _onShaderLoaded(path);
    }
  }

  // Cycle to the next preset, then refresh the tuning panel for it.
  Future<void> _nextPreset() async {
    final path = await VisualizerPresets().loadNext(_presetKind);
    _onShaderLoaded(path);
  }

  // Called after every shader load. Parses the shader's `// param:`
  // knobs, loads persisted-or-default values, and pushes them to the
  // engine. Runs for the Shader engine regardless of whether the panel
  // is visible — shaders read iParams[i] and would otherwise see 0, so
  // their declared defaults must always be pushed.
  void _onShaderLoaded(String? path) {
    if (!mounted || _engine != VisualizerEngine.shader || path == null) return;
    final source = VisualizerPresets().currentShaderSource ?? '';
    final params = parseShaderParams(source);
    final saved = SettingsManager().visualizerShaderParams[path];
    final values = <double>[
      for (var i = 0; i < params.length; i++)
        params[i].clamp((saved != null && i < saved.length)
            ? saved[i]
            : params[i].def),
    ];
    final g = SettingsManager().visualizerGlobalParams;
    final globals = g.length == _globalLabels.length
        ? List<double>.from(g)
        : List<double>.from(SettingsManager.defaultGlobalParams);
    setState(() {
      _shaderKey = path;
      _shaderParams = params;
      _paramValues = values;
      _globalValues = globals;
    });
    _pushTuning();
  }

  // Push [global response curve..., per-shader params...] to the engine.
  void _pushTuning() {
    VisualizerBridge.setTuning([..._globalValues, ..._paramValues]);
  }

  void _persistGlobal() =>
      SettingsManager().setVisualizerGlobalParams(_globalValues);

  void _persistShader() {
    final key = _shaderKey;
    if (key != null) {
      SettingsManager().setVisualizerShaderParams(key, _paramValues);
    }
  }

  // Reset the current shader's knobs + the global curve to their
  // defaults and drop the saved overrides.
  void _resetTuning() {
    setState(() {
      _paramValues = _shaderParams.map((p) => p.def).toList();
      _globalValues = List<double>.from(SettingsManager.defaultGlobalParams);
    });
    _pushTuning();
    final key = _shaderKey;
    if (key != null) SettingsManager().clearVisualizerShaderParams(key);
    SettingsManager().setVisualizerGlobalParams(const []);
  }

  @override
  Widget build(BuildContext context) {
    final supported = Platform.isAndroid;
    // No AppBar — the visualizer is fullscreen + immersive. The top-left
    // back button is the reliable exit; tap-to-cycle and long-press are
    // secondary.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Tap when rendering = next preset (so the user can cycle).
            // Tap on the placeholder = exit. Long-press always exits.
            onTap: () {
              if (_textureId != null) {
                _nextPreset();
              } else {
                _exit();
              }
            },
            onLongPress: _exit,
            child: supported ? _androidBody() : _unsupported(),
          ),
          // Always-visible escape hatch, on top of everything. Guarantees a
          // way out even if the OS resumes the app straight into the
          // visualizer after a swipe-away — immersive mode hides the system
          // back affordance and long-press isn't discoverable.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _closeButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reliable exit: pop back into the app if possible; if the visualizer is
  // somehow the only route, drop to the OS rather than trap the user.
  void _exit() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      SystemNavigator.pop();
    }
  }

  Widget _closeButton() {
    return GestureDetector(
      onTap: _exit,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(120),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_back,
          color: Colors.white.withAlpha(230),
          size: 22,
        ),
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
              'Tap = next preset · back arrow (top-left) or long-press to exit',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(160),
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (_knobsEnabled) ..._tuningOverlay(),
        ],
      );
    }
    return Center(child: _statusPlaceholder());
  }

  // Live tuning overlay: a gear handle that toggles a right-side slider
  // panel. Both absorb their own taps so they don't trigger next-preset.
  List<Widget> _tuningOverlay() {
    return [
      // Gear handle, only while the panel is closed (the open panel sits
      // on top and carries its own close button).
      if (!_panelOpen)
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () => setState(() => _panelOpen = true),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.tune,
                color: Colors.white.withAlpha(220),
                size: 22,
              ),
            ),
          ),
        ),
      if (_panelOpen)
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 340,
          child: GestureDetector(
            // Absorb taps so the parent's next-preset handler doesn't fire.
            onTap: () {},
            child: Container(
              color: Colors.black.withAlpha(190),
              child: SafeArea(child: _tuningPanelContent()),
            ),
          ),
        ),
    ];
  }

  Widget _tuningPanelContent() {
    final shaderName = _shaderKey != null ? _prettyShaderName(_shaderKey!) : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tuning',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _resetTuning,
                child: Text('Reset',
                    style: TextStyle(color: VelvetColors.primary)),
              ),
              IconButton(
                onPressed: () => setState(() => _panelOpen = false),
                icon: Icon(Icons.close, color: Colors.white70, size: 20),
                tooltip: 'Close',
              ),
            ],
          ),
          Expanded(
            child: ListView(
              children: [
                _panelSectionLabel('Response curve · all shaders'),
                for (var i = 0;
                    i < _globalValues.length && i < _globalLabels.length;
                    i++)
                  _globalSlider(i),
                const SizedBox(height: 10),
                _panelSectionLabel(shaderName.isEmpty ? 'Shader' : shaderName),
                if (_shaderParams.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'This shader exposes no knobs.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                for (var i = 0; i < _shaderParams.length; i++)
                  _shaderSlider(i),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelSectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: VelvetColors.primary,
            fontSize: 11,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _globalSlider(int i) {
    final range = _globalRanges[i];
    final v = _globalValues[i].clamp(range[0], range[1]).toDouble();
    return _sliderRow(
      label: _globalLabels[i],
      value: v,
      min: range[0],
      max: range[1],
      onChanged: (nv) {
        setState(() => _globalValues[i] = nv);
        _pushTuning();
      },
      onChangeEnd: (_) => _persistGlobal(),
    );
  }

  Widget _shaderSlider(int i) {
    final p = _shaderParams[i];
    final v = _paramValues[i].clamp(p.min, p.max).toDouble();
    return _sliderRow(
      label: p.name,
      value: v,
      min: p.min,
      max: p.max,
      onChanged: (nv) {
        setState(() => _paramValues[i] = nv);
        _pushTuning();
      },
      onChangeEnd: (_) => _persistShader(),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            activeTrackColor: VelvetColors.primary,
            inactiveTrackColor: Colors.white24,
            thumbColor: VelvetColors.primary,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }

  // assets/shaders/05-hex-marching.glsl -> "hex marching"
  String _prettyShaderName(String path) {
    var n = path.split('/').last;
    n = n.replaceAll('.glsl', '');
    n = n.replaceFirst(RegExp(r'^\d+-'), '');
    n = n.replaceAll('-', ' ');
    return n;
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
