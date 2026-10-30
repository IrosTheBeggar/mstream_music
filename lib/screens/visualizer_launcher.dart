import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../singletons/settings.dart';
import '../util/real_audio_permission.dart';
import '../visualizer/shader_visualizer_screen.dart';
import 'visualizer_screen.dart';

/// Opens [engine]'s visualizer — what the drawer's "Milkdrop Visualizer" and
/// "ShaderToy Visualizer" entries do.
///
/// On Android real audio needs RECORD_AUDIO, so until that permission is
/// granted every open first asks whether to use real audio, unless the user
/// ticked "Don't ask again". Either button opens the visualizer; dismissing
/// the dialog opens nothing. iOS and desktop never need the microphone (they
/// decode the stream themselves), so nothing is asked there.
Future<void> openVisualizer(
    BuildContext context, VisualizerEngine engine) async {
  final settings = SettingsManager();
  // A visualizer cast renders whichever engine was opened last.
  unawaited(settings.setVisualizerEngine(engine));

  if (Platform.isAndroid &&
      !settings.realAudioPromptDismissed &&
      !await Permission.microphone.isGranted) {
    if (!context.mounted) return;
    final answer = await askForRealAudio(context, offerDontAskAgain: true);
    if (answer == null) return;
    if (answer.dontAskAgain) await settings.setRealAudioPromptDismissed(true);
    // Recorded as chosen even when Android then refuses: VisualizerAudio
    // falls back to synthesized until the permission arrives, and a grant
    // made later in system settings takes effect with no further questions.
    await settings.setVisualizerAudioSource(answer.wantsReal
        ? VisualizerAudioSource.real
        : VisualizerAudioSource.synthesized);
  }

  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Platform.isAndroid
          ? VisualizerScreen(engine: engine)
          : const ShaderVisualizerScreen()));
}
