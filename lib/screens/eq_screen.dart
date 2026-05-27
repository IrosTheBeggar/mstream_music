import 'package:flutter/material.dart';

// Placeholder stub. The UI agent owns this file and will replace it
// with the real graphic equalizer (band sliders + presets, reading
// MediaManager().audioHandler.equalizer and persisting via
// SettingsManager().setEqBandGains / setEqEnabled). This stub exists
// only so settings_screen.dart can import EqScreen and the project
// compiles while the UI work is in flight.
class EqScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equalizer')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Equalizer UI not yet implemented.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
