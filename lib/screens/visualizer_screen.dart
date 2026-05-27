// Full-screen Milkdrop-style visualizer. Currently a placeholder —
// the projectM FFI bridge and Kotlin texture renderer (see
// ~/.claude/plans/add-visualizer.md, phases 1 and 2) land here once
// the native side is wired up. The audio-source toggle (synthesized
// vs real AndroidVisualizer with RECORD_AUDIO) is already in
// Settings, and the value persists, so this screen only has to swap
// its body when the native renderer arrives.

import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';

class VisualizerScreen extends StatelessWidget {
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
        onTap: () => Navigator.of(context).maybePop(),
        child: Center(
          child: supported ? _placeholder(context) : _unsupported(),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final source = SettingsManager().visualizerAudioSource;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 72, color: VelvetColors.primary),
          const SizedBox(height: 20),
          Text(
            'Visualizer coming soon',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        'Visualizer is currently only supported on Android.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: VelvetColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}
