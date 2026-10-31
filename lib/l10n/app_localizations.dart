import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('ja'),
    Locale('pl'),
    Locale('pt'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// No description provided for @mainRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get mainRemove;

  /// Toast shown when creating or renaming a playlist fails (often a duplicate name).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the playlist — the name may already be in use.'**
  String get playlistActionFailed;

  /// Track row menu: insert after the current track.
  ///
  /// In en, this message translates to:
  /// **'Add next'**
  String get queueAddNext;

  /// Track row menu: play this track immediately.
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get queuePlayNow;

  /// Track row menu: append to the end of the queue.
  ///
  /// In en, this message translates to:
  /// **'Add to end of queue'**
  String get queueAddToEnd;

  /// Shuffle-play button on the album detail screen.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// Shown as the album artist when an album's tracks span multiple artists.
  ///
  /// In en, this message translates to:
  /// **'Various Artists'**
  String get variousArtists;

  /// Application title (brand name; not translated).
  ///
  /// In en, this message translates to:
  /// **'mStream Music'**
  String get appTitle;

  /// Settings row label for the language picker.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// First entry in the language picker: follow the OS locale.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// Subtitle under the language picker row in Settings.
  ///
  /// In en, this message translates to:
  /// **'The app\'s display language. \"System default\" follows your device.'**
  String get settingsLanguageSubtitle;

  /// Snackbar when a URL fails to launch.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String couldNotOpen(String url);

  /// Subtitle showing how many tracks a playlist has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tracks} =1{1 track} other{{count} tracks}}'**
  String trackCount(int count);

  /// Generic Reset button label.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// AppTheme option label.
  ///
  /// In en, this message translates to:
  /// **'Velvet'**
  String get themeVelvet;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// TapBehavior option: append to queue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get tapAddToQueue;

  /// No description provided for @tapPlayFromHere.
  ///
  /// In en, this message translates to:
  /// **'Play from here'**
  String get tapPlayFromHere;

  /// No description provided for @tapAppendAndJump.
  ///
  /// In en, this message translates to:
  /// **'Add and play'**
  String get tapAppendAndJump;

  /// VisualizerAudioSource option label.
  ///
  /// In en, this message translates to:
  /// **'Synthesized'**
  String get visualizerSourceSynthesized;

  /// No description provided for @visualizerSourceReal.
  ///
  /// In en, this message translates to:
  /// **'Real audio'**
  String get visualizerSourceReal;

  /// Downloads screen app bar title.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTitle;

  /// Per-file download progress subtitle.
  ///
  /// In en, this message translates to:
  /// **'progress: {progress}%'**
  String downloadProgress(String progress);

  /// Metadata screen app bar title.
  ///
  /// In en, this message translates to:
  /// **'Song Info'**
  String get songInfoTitle;

  /// Lyrics page app bar title and the Song Info lyrics badge label.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyricsTitle;

  /// Empty state on the lyrics page when the server has no lyrics.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found for this song'**
  String get lyricsEmpty;

  /// Error state on the lyrics page when the fetch fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load lyrics'**
  String get lyricsError;

  /// Button to retry loading lyrics after an error.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get lyricsRetry;

  /// Equalizer screen title / switch label.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get eqTitle;

  /// Shown when the EQ is opened on a non-Android platform.
  ///
  /// In en, this message translates to:
  /// **'Equalizer is only available on Android.'**
  String get eqOnlyAndroid;

  /// Shown when the EQ band layout can't be read because nothing is playing.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s equalizer reports its bands only once audio is playing. Your saved preset is applied the moment they appear.'**
  String get eqNeedsPlayback;

  /// Shown when the native equalizer throws while initializing.
  ///
  /// In en, this message translates to:
  /// **'Could not initialize equalizer:\n{error}'**
  String eqInitFailed(String error);

  /// Shown when the device reports zero EQ bands.
  ///
  /// In en, this message translates to:
  /// **'No EQ bands reported by this device\'s audio driver.'**
  String get eqNoBands;

  /// EQ preset chip: every band at 0 dB (what Reset applies).
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get eqPresetFlat;

  /// EQ preset chip: Android's default curve, a touch of bass and treble.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get eqPresetNormal;

  /// EQ preset chip (genre curve).
  ///
  /// In en, this message translates to:
  /// **'Classical'**
  String get eqPresetClassical;

  /// EQ preset chip (genre curve).
  ///
  /// In en, this message translates to:
  /// **'Dance'**
  String get eqPresetDance;

  /// EQ preset chip (genre curve).
  ///
  /// In en, this message translates to:
  /// **'Folk'**
  String get eqPresetFolk;

  /// EQ preset chip (genre curve).
  ///
  /// In en, this message translates to:
  /// **'Heavy Metal'**
  String get eqPresetHeavyMetal;

  /// EQ preset chip (genre curve).
  ///
  /// In en, this message translates to:
  /// **'Hip Hop'**
  String get eqPresetHipHop;

  /// EQ preset chip (genre curve).
  ///
  /// In en, this message translates to:
  /// **'Jazz'**
  String get eqPresetJazz;

  /// EQ preset chip (genre curve).
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get eqPresetPop;

  /// EQ preset chip (genre curve).
  ///
  /// In en, this message translates to:
  /// **'Rock'**
  String get eqPresetRock;

  /// EQ preset chip shown first when the gains match no preset.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get eqPresetCustom;

  /// Button under the EQ bands that saves the current curve as a user preset.
  ///
  /// In en, this message translates to:
  /// **'Save as preset'**
  String get eqSaveAsPreset;

  /// Title of the sheet that names a new EQ preset.
  ///
  /// In en, this message translates to:
  /// **'Save preset'**
  String get eqSavePresetTitle;

  /// Title of the sheet that renames a saved EQ preset.
  ///
  /// In en, this message translates to:
  /// **'Rename preset'**
  String get eqRenamePresetTitle;

  /// Label of the preset name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get eqPresetNameLabel;

  /// Helper text under the preset name field when saving.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone, after the built-in presets. Long-press its chip later to rename or delete it.'**
  String get eqSavePresetHint;

  /// Save-sheet button when a saved preset of that name exists and will be overwritten.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get eqReplacePreset;

  /// Helper text when renaming to a name another saved preset has.
  ///
  /// In en, this message translates to:
  /// **'Another saved preset already has this name.'**
  String get eqPresetNameTaken;

  /// Confirmation when deleting a saved EQ preset.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String eqDeletePresetConfirm(String name);

  /// Button under the EQ bands: while held, the equalizer is bypassed.
  ///
  /// In en, this message translates to:
  /// **'Hold to compare'**
  String get eqHoldToCompare;

  /// Accessibility hint for the Hold to compare button.
  ///
  /// In en, this message translates to:
  /// **'Hold to hear the sound without the equalizer.'**
  String get eqHoldToCompareHint;

  /// Title of the EQ options sheet and tooltip of the app-bar button that opens it.
  ///
  /// In en, this message translates to:
  /// **'Equalizer options'**
  String get eqOptionsTitle;

  /// Options switch: the ten-band engine's limiter.
  ///
  /// In en, this message translates to:
  /// **'Prevent clipping'**
  String get eqPreventClipping;

  /// Subtitle of the Prevent clipping switch.
  ///
  /// In en, this message translates to:
  /// **'Limits peaks when bands are boosted.'**
  String get eqPreventClippingHint;

  /// Options switch: a dB readout over every band.
  ///
  /// In en, this message translates to:
  /// **'Always show band values'**
  String get eqShowValues;

  /// Subtitle of the Always show band values switch.
  ///
  /// In en, this message translates to:
  /// **'A number over every band, not only while dragging.'**
  String get eqShowValuesHint;

  /// Title of the Outputs page and of the options-sheet row that opens it.
  ///
  /// In en, this message translates to:
  /// **'Outputs'**
  String get eqOutputsTitle;

  /// Options-sheet row subtitle while per-output curves are off.
  ///
  /// In en, this message translates to:
  /// **'Off — one curve for every output'**
  String get eqOutputsRowOff;

  /// Options-sheet row subtitle naming the output in use.
  ///
  /// In en, this message translates to:
  /// **'{name} now'**
  String eqOutputsNow(String name);

  /// Outputs page: the switch that makes the EQ follow the output.
  ///
  /// In en, this message translates to:
  /// **'Switch automatically'**
  String get eqOutputsSwitch;

  /// Subtitle of that switch.
  ///
  /// In en, this message translates to:
  /// **'When the output changes, its curve is applied. Dragging on the Equalizer page edits the output playing now.'**
  String get eqOutputsSwitchHint;

  /// Section label over the remembered outputs.
  ///
  /// In en, this message translates to:
  /// **'Remembered outputs'**
  String get eqOutputsRemembered;

  /// Output kind.
  ///
  /// In en, this message translates to:
  /// **'Phone speaker'**
  String get eqOutputSpeaker;

  /// Output kind.
  ///
  /// In en, this message translates to:
  /// **'Wired headphones'**
  String get eqOutputWired;

  /// Output kind.
  ///
  /// In en, this message translates to:
  /// **'USB audio'**
  String get eqOutputUsb;

  /// Output kind.
  ///
  /// In en, this message translates to:
  /// **'HDMI'**
  String get eqOutputHdmi;

  /// Output kind (Bluetooth devices are shown by their own name; this word is the kind).
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get eqOutputBluetooth;

  /// Output kind.
  ///
  /// In en, this message translates to:
  /// **'Other output'**
  String get eqOutputOther;

  /// Row subtitle part for the output in use.
  ///
  /// In en, this message translates to:
  /// **'playing now'**
  String get eqOutputPlayingNow;

  /// Row subtitle part with a short date.
  ///
  /// In en, this message translates to:
  /// **'last used {date}'**
  String eqOutputLastUsed(String date);

  /// Outputs page when nothing is remembered yet.
  ///
  /// In en, this message translates to:
  /// **'Outputs appear here as you listen on them.'**
  String get eqOutputsEmpty;

  /// Confirmation when swiping an output away.
  ///
  /// In en, this message translates to:
  /// **'Forget “{name}”? It comes back as a new output the next time it connects.'**
  String eqOutputForgetConfirm(String name);

  /// Confirm button of that dialog.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get eqOutputForget;

  /// Title of the preset picker for one output.
  ///
  /// In en, this message translates to:
  /// **'Preset for {name}'**
  String eqOutputPickPreset(String name);

  /// Footer hint on the Outputs page.
  ///
  /// In en, this message translates to:
  /// **'Tap an output to pick its preset. Swipe one away to forget it.'**
  String get eqOutputsHint;

  /// EQ enable switch subtitle when on and the curve follows the named output.
  ///
  /// In en, this message translates to:
  /// **'On — {name}'**
  String eqEnabledOnOutput(String name);

  /// Small pill on the output in use.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get eqOutputNowPill;

  /// Heading of the EQ state that waits for playback (five-band engine).
  ///
  /// In en, this message translates to:
  /// **'Start a song to set up the bands'**
  String get eqNeedsPlaybackTitle;

  /// Button in that state that plays the restored queue.
  ///
  /// In en, this message translates to:
  /// **'Play the queue'**
  String get eqPlayQueue;

  /// Caption under that button, with the queue length.
  ///
  /// In en, this message translates to:
  /// **'Resumes where you left off · {count, plural, =1{1 song} other{{count} songs}}'**
  String eqPlayQueueHint(int count);

  /// No description provided for @eqDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on the equalizer to adjust the bands.'**
  String get eqDisabledHint;

  /// EQ enable switch subtitle when on.
  ///
  /// In en, this message translates to:
  /// **'On — gains applied to playback'**
  String get eqEnabledOn;

  /// No description provided for @eqEnabledOff.
  ///
  /// In en, this message translates to:
  /// **'Off — bypass mode'**
  String get eqEnabledOff;

  /// Generic Cancel button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Generic Continue button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Snackbar action to open the OS app settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// Settings screen app bar title and section headers.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsSectionPlayback;

  /// No description provided for @settingsSectionBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get settingsSectionBrowse;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// Theme picker row label + per-theme subtitles.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeSubtitleVelvet.
  ///
  /// In en, this message translates to:
  /// **'Navy and purple — the signature dark theme.'**
  String get themeSubtitleVelvet;

  /// No description provided for @themeSubtitleDark.
  ///
  /// In en, this message translates to:
  /// **'Neutral dark with amber accents.'**
  String get themeSubtitleDark;

  /// No description provided for @themeSubtitleLight.
  ///
  /// In en, this message translates to:
  /// **'Light body with a dark app bar and amber accents — matches the older shipped theme.'**
  String get themeSubtitleLight;

  /// Transcode toggle row.
  ///
  /// In en, this message translates to:
  /// **'Transcode audio'**
  String get settingsTranscode;

  /// No description provided for @settingsTranscodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stream a transcoded copy from the server (smaller files, slightly slower start). Off plays original files.'**
  String get settingsTranscodeSubtitle;

  /// No description provided for @transcodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcoding'**
  String get transcodeTitle;

  /// No description provided for @transcodeCodec.
  ///
  /// In en, this message translates to:
  /// **'Codec'**
  String get transcodeCodec;

  /// No description provided for @transcodeBitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get transcodeBitrate;

  /// No description provided for @transcodeAuto.
  ///
  /// In en, this message translates to:
  /// **'Server default'**
  String get transcodeAuto;

  /// No description provided for @transcodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This server doesn\'t have transcoding enabled — its tracks stream in original quality.'**
  String get transcodeUnavailable;

  /// No description provided for @transcodeReloadQueue.
  ///
  /// In en, this message translates to:
  /// **'Apply to current queue'**
  String get transcodeReloadQueue;

  /// No description provided for @transcodeReloadQueueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When you change transcoding settings — checked: reload the whole queue now (the playing track briefly re-buffers); unchecked: only upcoming tracks change, the current one finishes as-is.'**
  String get transcodeReloadQueueSubtitle;

  /// Tap-behavior picker row label + per-mode subtitles.
  ///
  /// In en, this message translates to:
  /// **'When you tap a song'**
  String get settingsTapBehavior;

  /// No description provided for @settingsStartupPage.
  ///
  /// In en, this message translates to:
  /// **'Startup page'**
  String get settingsStartupPage;

  /// No description provided for @settingsStartupPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the app to this browser view; Back returns to the browser.'**
  String get settingsStartupPageSubtitle;

  /// No description provided for @tapSubtitleAddToQueue.
  ///
  /// In en, this message translates to:
  /// **'Tapping a song appends it to the queue. If the queue is empty, playback starts automatically.'**
  String get tapSubtitleAddToQueue;

  /// No description provided for @tapSubtitlePlayFromHere.
  ///
  /// In en, this message translates to:
  /// **'Tapping a song replaces the queue with the songs in the current view and starts playback at the tapped song.'**
  String get tapSubtitlePlayFromHere;

  /// No description provided for @tapSubtitleAppendAndJump.
  ///
  /// In en, this message translates to:
  /// **'Tapping a song appends it to the queue and jumps playback to it, interrupting whatever was playing.'**
  String get tapSubtitleAppendAndJump;

  /// Visualizer audio-source picker row label + per-source subtitles.
  ///
  /// In en, this message translates to:
  /// **'Visualizer audio source'**
  String get settingsVisualizerSource;

  /// No description provided for @visualizerSourceSubtitleSynthesized.
  ///
  /// In en, this message translates to:
  /// **'Default. Visualizer reacts to playback timing only — no microphone permission required.'**
  String get visualizerSourceSubtitleSynthesized;

  /// No description provided for @visualizerSourceSubtitleReal.
  ///
  /// In en, this message translates to:
  /// **'Visualizer reacts to actual audio output. Requires the RECORD_AUDIO permission on Android.'**
  String get visualizerSourceSubtitleReal;

  /// Album-grid toggle row.
  ///
  /// In en, this message translates to:
  /// **'Album grid view'**
  String get settingsAlbumGrid;

  /// No description provided for @settingsAlbumGridSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show albums as a grid of cards with cover art instead of a plain list.'**
  String get settingsAlbumGridSubtitle;

  /// File-explorer metadata toggle row.
  ///
  /// In en, this message translates to:
  /// **'Read song metadata in file explorer'**
  String get settingsFileMetadata;

  /// No description provided for @settingsFileMetadataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fetch title, artist, and album art for each song when browsing server files. Off shows raw filenames (faster for huge folders).'**
  String get settingsFileMetadataSubtitle;

  /// Letter-scrubber threshold slider row.
  ///
  /// In en, this message translates to:
  /// **'Letter scrubber threshold'**
  String get settingsLetterStrip;

  /// No description provided for @settingsLetterStripSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the A-Z quick-scrub strip when a list has this many items or more. Below this size the strip is hidden and long folder/file names wrap to multiple lines instead of being truncated. Set 0 to always show the strip.'**
  String get settingsLetterStripSubtitle;

  /// Label for the setting choosing which screen edge the A-Z scrubber sits on.
  ///
  /// In en, this message translates to:
  /// **'Scrubber side'**
  String get settingsLetterStripSide;

  /// Explains the scrubber-side setting.
  ///
  /// In en, this message translates to:
  /// **'Which edge the A–Z strip sits on.'**
  String get settingsLetterStripSideSubtitle;

  /// Segmented-button option: scrubber on the left edge.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get settingsLetterStripLeft;

  /// Segmented-button option: scrubber on the right edge.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get settingsLetterStripRight;

  /// Reset-to-defaults row + confirmation snackbar.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get settingsReset;

  /// No description provided for @settingsResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore all settings on this screen to their default values. Servers and downloads are not affected.'**
  String get settingsResetSubtitle;

  /// No description provided for @settingsResetDone.
  ///
  /// In en, this message translates to:
  /// **'Settings restored to defaults'**
  String get settingsResetDone;

  /// Real-audio consent dialog — shown when a visualizer opens without the microphone permission, and from Settings › Visualizer audio source — plus the denial snackbars.
  ///
  /// In en, this message translates to:
  /// **'Use real audio?'**
  String get realAudioDialogTitle;

  /// No description provided for @realAudioDialogBody.
  ///
  /// In en, this message translates to:
  /// **'To react to the song that\'s playing, the visualizer reads mStream\'s own audio output, and Android only allows that with the microphone permission.'**
  String get realAudioDialogBody;

  /// No description provided for @realAudioPermPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission permanently denied. Enable it in system settings to use real audio.'**
  String get realAudioPermPermanentlyDenied;

  /// No description provided for @realAudioPermDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied. Staying on synthesized audio.'**
  String get realAudioPermDenied;

  /// Overlay hint while the visualizer is rendering.
  ///
  /// In en, this message translates to:
  /// **'Tap = next preset · back arrow (top-left) or long-press to exit'**
  String get visualizerTapHint;

  /// Visualizer status placeholder headings.
  ///
  /// In en, this message translates to:
  /// **'Visualizer failed to start'**
  String get visualizerFailed;

  /// No description provided for @visualizerBringingUp.
  ///
  /// In en, this message translates to:
  /// **'Bringing up renderer…'**
  String get visualizerBringingUp;

  /// No description provided for @visualizerReady.
  ///
  /// In en, this message translates to:
  /// **'Visualizer ready'**
  String get visualizerReady;

  /// No description provided for @visualizerBridgeFailed.
  ///
  /// In en, this message translates to:
  /// **'Bridge failed to start'**
  String get visualizerBridgeFailed;

  /// Status line showing the active visualizer audio source (already-lowercased).
  ///
  /// In en, this message translates to:
  /// **'Audio source: {source}'**
  String visualizerAudioSourceLine(String source);

  /// Hint on the visualizer status placeholder.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to close'**
  String get visualizerTapToClose;

  /// Tooltip on the shader visualizer's close (X) button.
  ///
  /// In en, this message translates to:
  /// **'Close visualizer'**
  String get visualizerClose;

  /// Tooltip on the shader visualizer's previous-preset arrow.
  ///
  /// In en, this message translates to:
  /// **'Previous preset'**
  String get visualizerPreviousPreset;

  /// Tooltip on the shader visualizer's next-preset arrow.
  ///
  /// In en, this message translates to:
  /// **'Next preset'**
  String get visualizerNextPreset;

  /// Shown when the visualizer runs on a non-Android platform.
  ///
  /// In en, this message translates to:
  /// **'Visualizer is currently only supported on Android.'**
  String get visualizerUnsupported;

  /// About screen app bar title.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// Author attribution on the About screen.
  ///
  /// In en, this message translates to:
  /// **'Built by {name}'**
  String aboutBuiltBy(String name);

  /// Subtitles for the external links on the About screen.
  ///
  /// In en, this message translates to:
  /// **'Community chat'**
  String get linkDiscordSubtitle;

  /// No description provided for @linkGithubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'mStream server source'**
  String get linkGithubSubtitle;

  /// No description provided for @linkHomepageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Project homepage'**
  String get linkHomepageSubtitle;

  /// Attributions row on the About screen.
  ///
  /// In en, this message translates to:
  /// **'Attributions'**
  String get aboutAttributions;

  /// No description provided for @aboutAttributionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'License, shader credits, and open-source notices.'**
  String get aboutAttributionsSubtitle;

  /// Button on the About page linking to GitHub Sponsors
  ///
  /// In en, this message translates to:
  /// **'Sponsor mStream'**
  String get aboutSponsor;

  /// Generic action labels reused across dialogs/menus.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @makeDefault.
  ///
  /// In en, this message translates to:
  /// **'Make Default'**
  String get makeDefault;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playAll;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Attributions screen labels (credit data itself stays English).
  ///
  /// In en, this message translates to:
  /// **'Attributions'**
  String get attributionsTitle;

  /// No description provided for @attributionsSectionLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get attributionsSectionLicense;

  /// No description provided for @attributionsSectionShaders.
  ///
  /// In en, this message translates to:
  /// **'Visualizer shaders'**
  String get attributionsSectionShaders;

  /// No description provided for @attributionsSectionLibraries.
  ///
  /// In en, this message translates to:
  /// **'Native libraries'**
  String get attributionsSectionLibraries;

  /// No description provided for @attributionsSectionEverythingElse.
  ///
  /// In en, this message translates to:
  /// **'Everything else'**
  String get attributionsSectionEverythingElse;

  /// No description provided for @attributionsLicenseBody.
  ///
  /// In en, this message translates to:
  /// **'Free software under the GNU General Public License v3.0. You may use, study, share, and modify it under those terms.'**
  String get attributionsLicenseBody;

  /// No description provided for @attributionsPackages.
  ///
  /// In en, this message translates to:
  /// **'Open-source package licenses'**
  String get attributionsPackages;

  /// No description provided for @attributionsPackagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full license texts for all bundled Flutter/Dart packages.'**
  String get attributionsPackagesSubtitle;

  /// Manage Servers screen + server info/remove dialogs.
  ///
  /// In en, this message translates to:
  /// **'Manage Servers'**
  String get manageServersTitle;

  /// No description provided for @manageServerInfo.
  ///
  /// In en, this message translates to:
  /// **'Server Info'**
  String get manageServerInfo;

  /// No description provided for @manageServerDownloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Download Folder:'**
  String get manageServerDownloadFolder;

  /// No description provided for @manageServerCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy Download Path'**
  String get manageServerCopyPath;

  /// No description provided for @manageServerPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path Copied to Clipboard'**
  String get manageServerPathCopied;

  /// No description provided for @confirmRemoveServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Remove Server'**
  String get confirmRemoveServerTitle;

  /// No description provided for @removeSyncedFiles.
  ///
  /// In en, this message translates to:
  /// **'Remove synced files from device?'**
  String get removeSyncedFiles;

  /// Playlists list + detail screens.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlistsTitle;

  /// No description provided for @playlistsNew.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlistsNew;

  /// No description provided for @playlistsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get playlistsEmptyTitle;

  /// No description provided for @playlistsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create one with the New playlist button, then use the queue\'s Add-to-playlist swipe action to fill it.'**
  String get playlistsEmptyBody;

  /// No description provided for @playlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get playlistNameHint;

  /// No description provided for @playlistsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get playlistsRename;

  /// No description provided for @playlistFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlistFallbackTitle;

  /// No description provided for @playlistEmptyDetail.
  ///
  /// In en, this message translates to:
  /// **'Playlist is empty.\nAdd tracks via the queue.'**
  String get playlistEmptyDetail;

  /// No description provided for @shareEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty queue'**
  String get shareEmptyTitle;

  /// No description provided for @shareEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add songs to the queue before sharing.'**
  String get shareEmptyBody;

  /// No description provided for @shareBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t share this queue'**
  String get shareBlockedTitle;

  /// No description provided for @shareLocalOnlyBody.
  ///
  /// In en, this message translates to:
  /// **'The queue contains songs that are only on this device (not on any server). Sharing only works when every song in the queue comes from a single server.'**
  String get shareLocalOnlyBody;

  /// Blocker shown when the queue spans multiple servers.
  ///
  /// In en, this message translates to:
  /// **'The queue mixes songs from {count} servers ({names}). Sharing only works when every song comes from a single server.'**
  String shareMultiServerBody(int count, String names);

  /// Blocker shown when the queue's server was removed.
  ///
  /// In en, this message translates to:
  /// **'The server \"{name}\" is no longer in your server list. Re-add it to share its queue.'**
  String shareServerGoneBody(String name);

  /// Share Playlist dialog labels.
  ///
  /// In en, this message translates to:
  /// **'Share Playlist'**
  String get shareTitle;

  /// Header in the share dialog: how many songs and which server.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}} from {url}'**
  String shareSongCount(int count, String url);

  /// No description provided for @shareLinkExpires.
  ///
  /// In en, this message translates to:
  /// **'Link expires'**
  String get shareLinkExpires;

  /// No description provided for @shareExpireNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get shareExpireNever;

  /// No description provided for @shareExpire1Day.
  ///
  /// In en, this message translates to:
  /// **'After 1 day'**
  String get shareExpire1Day;

  /// No description provided for @shareExpire7Days.
  ///
  /// In en, this message translates to:
  /// **'After 7 days'**
  String get shareExpire7Days;

  /// No description provided for @shareExpire30Days.
  ///
  /// In en, this message translates to:
  /// **'After 30 days'**
  String get shareExpire30Days;

  /// No description provided for @shareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAction;

  /// No description provided for @shareDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist shared'**
  String get shareDoneTitle;

  /// No description provided for @shareDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this link can play the queue:'**
  String get shareDoneBody;

  /// Generic Save / Start button labels.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// Add/Edit Server form labels, validators, and connection-test messages.
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get addServerTitle;

  /// No description provided for @editServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Server'**
  String get editServerTitle;

  /// No description provided for @fieldServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get fieldServerUrl;

  /// No description provided for @fieldPublicAccess.
  ///
  /// In en, this message translates to:
  /// **'Public access'**
  String get fieldPublicAccess;

  /// No description provided for @publicAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server is publicly accessible — no username or password needed.'**
  String get publicAccessSubtitle;

  /// No description provided for @fieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get fieldUsername;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// Tooltip and screen-reader label for the eye button on a password field while the password is hidden; tapping it reveals the text.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get fieldPasswordShow;

  /// Tooltip and screen-reader label for the eye button on a password field while the password is visible; tapping it obscures the text again.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get fieldPasswordHide;

  /// No description provided for @fieldSdCard.
  ///
  /// In en, this message translates to:
  /// **'Download to SD Card'**
  String get fieldSdCard;

  /// No description provided for @sdCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save downloaded music to the removable SD card instead of internal storage.'**
  String get sdCardSubtitle;

  /// No description provided for @testConnectionButton.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnectionButton;

  /// No description provided for @testing.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get testing;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @validatorUrlNeeded.
  ///
  /// In en, this message translates to:
  /// **'Server URL is needed'**
  String get validatorUrlNeeded;

  /// No description provided for @validatorUrlParse.
  ///
  /// In en, this message translates to:
  /// **'Cannot parse URL'**
  String get validatorUrlParse;

  /// No description provided for @testEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a server URL first.'**
  String get testEnterUrl;

  /// No description provided for @testParseUrl.
  ///
  /// In en, this message translates to:
  /// **'Could not parse URL.'**
  String get testParseUrl;

  /// No description provided for @testTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out.'**
  String get testTimedOut;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connection Successful!'**
  String get connectionSuccessful;

  /// No description provided for @couldNotReachServer.
  ///
  /// In en, this message translates to:
  /// **'Could not reach server. If it requires login, turn off \"Public access\" and add credentials.'**
  String get couldNotReachServer;

  /// No description provided for @failedToLogin.
  ///
  /// In en, this message translates to:
  /// **'Failed to Login'**
  String get failedToLogin;

  /// Test-connection success banner with the detected server version.
  ///
  /// In en, this message translates to:
  /// **'Connected — mStream v{version}'**
  String testConnected(String version);

  /// Test-connection failure banner with the raw error.
  ///
  /// In en, this message translates to:
  /// **'Could not connect: {error}'**
  String testConnectFailed(String error);

  /// Sleep-timer bottom sheet labels.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimerTitle;

  /// No description provided for @sleepTimerHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a duration to pause playback after.'**
  String get sleepTimerHint;

  /// No description provided for @sleepTimerCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get sleepTimerCustom;

  /// No description provided for @sleepTimerCustomHint.
  ///
  /// In en, this message translates to:
  /// **'minutes (1–600)'**
  String get sleepTimerCustomHint;

  /// No description provided for @sleepTimerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel timer'**
  String get sleepTimerCancel;

  /// No description provided for @sleepTimerInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between 1 and 600 minutes'**
  String get sleepTimerInvalid;

  /// Countdown line in the sleep-timer sheet.
  ///
  /// In en, this message translates to:
  /// **'Pauses in {time}'**
  String sleepTimerPausesIn(String time);

  /// Preset chip label, e.g. '30 min'.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sleepTimerMinutes(int minutes);

  /// Confirmation snackbar after starting the sleep timer.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Sleep timer set for 1 minute} other{Sleep timer set for {minutes} minutes}}'**
  String sleepTimerSet(int minutes);

  /// Generic Add button label.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Auto DJ screen title + section headers.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ'**
  String get autoDjTitle;

  /// No description provided for @autoDjAddServerFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a server first.'**
  String get autoDjAddServerFirst;

  /// No description provided for @autoDjSectionServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get autoDjSectionServer;

  /// No description provided for @autoDjSectionSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get autoDjSectionSources;

  /// No description provided for @autoDjSectionContinuity.
  ///
  /// In en, this message translates to:
  /// **'Continuity'**
  String get autoDjSectionContinuity;

  /// No description provided for @autoDjSectionFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get autoDjSectionFilters;

  /// Switch enabling cross-server Auto DJ.
  ///
  /// In en, this message translates to:
  /// **'Play from every server'**
  String get autoDjMultiServerTitle;

  /// Subtitle for that switch.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ picks from every server at once, matching the sound of what is playing'**
  String get autoDjMultiServerSubtitle;

  /// Warning under the multi-server switch when sonic similarity is off (the mode only runs on sonic picks).
  ///
  /// In en, this message translates to:
  /// **'Needs Sonic similarity switched on, below'**
  String get autoDjMultiServerNeedsSonic;

  /// Header for settings that apply to every server.
  ///
  /// In en, this message translates to:
  /// **'The session'**
  String get autoDjSectionShared;

  /// Header for settings that differ per server.
  ///
  /// In en, this message translates to:
  /// **'Each library'**
  String get autoDjSectionPerServer;

  /// Label above the dropdown choosing whose settings are shown.
  ///
  /// In en, this message translates to:
  /// **'Settings for'**
  String get autoDjEditingServer;

  /// Readout when every server can take part.
  ///
  /// In en, this message translates to:
  /// **'{count} servers are taking part'**
  String autoDjMultiServerAllIn(int count);

  /// Second line of the participants readout: how many tunnel servers are still dialing.
  ///
  /// In en, this message translates to:
  /// **'{count} still connecting'**
  String autoDjMultiServerConnecting(int count);

  /// Readout when some servers cannot take part, and why.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} servers are taking part — the rest lack discovery, a matching embedding model or a new enough server version'**
  String autoDjMultiServerSomeExcluded(int count, int total);

  /// Header for how Auto DJ fills the queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get autoDjSectionQueue;

  /// Songs-per-fetch row: how many songs one Auto DJ turn queues.
  ///
  /// In en, this message translates to:
  /// **'Songs per fetch'**
  String get autoDjSongsPerFetchTitle;

  /// Songs-per-fetch row subtitle.
  ///
  /// In en, this message translates to:
  /// **'How many songs Auto DJ queues each time it runs. Continuity filters judge the whole batch against the song playing when it was fetched.'**
  String get autoDjSongsPerFetchSubtitle;

  /// Songs-per-fetch readout beside the slider.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String autoDjSongsPerFetchValue(int count);

  /// BPM continuity row.
  ///
  /// In en, this message translates to:
  /// **'BPM continuity'**
  String get autoDjBpmTitle;

  /// No description provided for @autoDjBpmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prefer picks within a tempo window of the current song. Honours half/double-tempo equivalence.'**
  String get autoDjBpmSubtitle;

  /// No description provided for @autoDjTolerance.
  ///
  /// In en, this message translates to:
  /// **'Tolerance'**
  String get autoDjTolerance;

  /// BPM tolerance readout.
  ///
  /// In en, this message translates to:
  /// **'± {bpm} BPM'**
  String autoDjBpmTolerance(int bpm);

  /// Harmonic mixing row.
  ///
  /// In en, this message translates to:
  /// **'Harmonic mixing'**
  String get autoDjHarmonicTitle;

  /// No description provided for @autoDjHarmonicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prefer picks in keys that mix well with the locked song (Camelot wheel neighbours).'**
  String get autoDjHarmonicSubtitle;

  /// Auto DJ track-length filter switch title.
  ///
  /// In en, this message translates to:
  /// **'Track length'**
  String get autoDjDurationTitle;

  /// Subtitle for that switch.
  ///
  /// In en, this message translates to:
  /// **'Skip interludes and long mixes by only picking tracks in a length range'**
  String get autoDjDurationSubtitle;

  /// Label beside the length range slider.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get autoDjDurationRange;

  /// Range readout when neither bound is set.
  ///
  /// In en, this message translates to:
  /// **'Any length'**
  String get autoDjDurationAny;

  /// Range readout with only a minimum, e.g. Over 2:00.
  ///
  /// In en, this message translates to:
  /// **'Over {min}'**
  String autoDjDurationOver(String min);

  /// Range readout with only a maximum, e.g. Under 6:00.
  ///
  /// In en, this message translates to:
  /// **'Under {max}'**
  String autoDjDurationUnder(String max);

  /// Range readout with both bounds, e.g. 2:00 to 6:00.
  ///
  /// In en, this message translates to:
  /// **'{min} to {max}'**
  String autoDjDurationBetween(String min, String max);

  /// Sub-switch letting unknown-length tracks through.
  ///
  /// In en, this message translates to:
  /// **'Include tracks of unknown length'**
  String get autoDjDurationAllowUnknown;

  /// Subtitle for that sub-switch.
  ///
  /// In en, this message translates to:
  /// **'Tracks your server has not read a length for are skipped otherwise'**
  String get autoDjDurationAllowUnknownSub;

  /// Auto DJ status block + enable button.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ is on'**
  String get autoDjStatusOn;

  /// No description provided for @autoDjStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ is off'**
  String get autoDjStatusOff;

  /// No description provided for @autoDjStatusOffDetail.
  ///
  /// In en, this message translates to:
  /// **'Tap below to start. The current server\'s library will be used.'**
  String get autoDjStatusOffDetail;

  /// No description provided for @autoDjStart.
  ///
  /// In en, this message translates to:
  /// **'Start Auto DJ'**
  String get autoDjStart;

  /// No description provided for @autoDjStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Auto DJ'**
  String get autoDjStop;

  /// Auto DJ on-state detail line.
  ///
  /// In en, this message translates to:
  /// **'Songs are picked from {url} when the queue runs low.'**
  String autoDjStatusOnDetail(String url);

  /// No description provided for @autoDjOneSourceRequired.
  ///
  /// In en, this message translates to:
  /// **'At least one source is required.'**
  String get autoDjOneSourceRequired;

  /// Minimum-rating filter row ('Any' = no minimum).
  ///
  /// In en, this message translates to:
  /// **'Minimum rating'**
  String get autoDjMinRating;

  /// No description provided for @autoDjMinRatingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only pick songs at or above this rating.'**
  String get autoDjMinRatingSubtitle;

  /// No description provided for @autoDjRatingAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get autoDjRatingAny;

  /// Genre filter section.
  ///
  /// In en, this message translates to:
  /// **'Genre filter'**
  String get autoDjGenreTitle;

  /// No description provided for @autoDjGenreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Whitelist plays only matching tracks; blacklist skips them.'**
  String get autoDjGenreSubtitle;

  /// No description provided for @autoDjWhitelist.
  ///
  /// In en, this message translates to:
  /// **'Whitelist'**
  String get autoDjWhitelist;

  /// No description provided for @autoDjBlacklist.
  ///
  /// In en, this message translates to:
  /// **'Blacklist'**
  String get autoDjBlacklist;

  /// No description provided for @autoDjNoGenres.
  ///
  /// In en, this message translates to:
  /// **'No genres selected. Tap \"Pick genres\" to choose.'**
  String get autoDjNoGenres;

  /// No description provided for @autoDjPickGenres.
  ///
  /// In en, this message translates to:
  /// **'Pick genres'**
  String get autoDjPickGenres;

  /// No description provided for @autoDjGenreLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load genres'**
  String get autoDjGenreLoadError;

  /// Keyword filter section.
  ///
  /// In en, this message translates to:
  /// **'Keyword filter'**
  String get autoDjKeywordTitle;

  /// No description provided for @autoDjKeywordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip picks whose title, artist, album, or filepath contains any of these words.'**
  String get autoDjKeywordSubtitle;

  /// No description provided for @autoDjNoKeywords.
  ///
  /// In en, this message translates to:
  /// **'No keywords. Add words below to start filtering.'**
  String get autoDjNoKeywords;

  /// No description provided for @autoDjKeywordHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"live\" or \"remix\"'**
  String get autoDjKeywordHint;

  /// Genre picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Search genres…'**
  String get autoDjSearchGenres;

  /// No description provided for @autoDjNoGenresOnServer.
  ///
  /// In en, this message translates to:
  /// **'No genres found on this server.'**
  String get autoDjNoGenresOnServer;

  /// Count of selected genres in the picker header.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String autoDjSelectedCount(int count);

  /// Empty-search state in the genre picker.
  ///
  /// In en, this message translates to:
  /// **'No genres match \"{query}\".'**
  String autoDjNoGenresMatch(String query);

  /// Generic Download / Add All action labels (browser toolbar + swipe actions).
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @addAll.
  ///
  /// In en, this message translates to:
  /// **'Add All'**
  String get addAll;

  /// Tooltip for the browser toolbar's overflow (⋮) menu holding Search list / Download / Add All.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get browserMoreActions;

  /// Browser delete-confirmation dialog titles + search hint.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete Playlist'**
  String get browserConfirmDeletePlaylist;

  /// No description provided for @browserConfirmDeleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete Folder'**
  String get browserConfirmDeleteFolder;

  /// No description provided for @browserSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Database'**
  String get browserSearchHint;

  /// Search-category checkbox dropdown: tooltip on the icon button, the menu header, and the five category labels (which categories the DB search queries — the user ticks any combination).
  ///
  /// In en, this message translates to:
  /// **'What to search'**
  String get searchCategoriesTooltip;

  /// No description provided for @searchCategoriesHeader.
  ///
  /// In en, this message translates to:
  /// **'Search in'**
  String get searchCategoriesHeader;

  /// No description provided for @searchCategoryArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get searchCategoryArtists;

  /// No description provided for @searchCategoryAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get searchCategoryAlbums;

  /// No description provided for @searchCategorySongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get searchCategorySongs;

  /// No description provided for @searchCategoryFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get searchCategoryFiles;

  /// No description provided for @searchCategoryLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get searchCategoryLyrics;

  /// Thin subheader on the search-results page echoing the submitted query.
  ///
  /// In en, this message translates to:
  /// **'Results for “{term}”'**
  String searchSubheaderResults(String term);

  /// Thin subheader shown while the server-search field is focused, previewing which categories (e.g. "Artists · Albums") a search will cover.
  ///
  /// In en, this message translates to:
  /// **'Searching: {categories}'**
  String searchSubheaderCategories(String categories);

  /// Snackbar after queueing downloads from the browser.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 download started} other{{count} downloads started}}'**
  String browserDownloadsStarted(int count);

  /// Snackbar after Add-All from the browser.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song added to queue} other{{count} songs added to queue}}'**
  String browserSongsAdded(int count);

  /// Main scaffold: tabs, drawer header, queue header, toolbar.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get tabBrowser;

  /// No description provided for @tabQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get tabQueue;

  /// No description provided for @drawerTagline.
  ///
  /// In en, this message translates to:
  /// **'Personal music streaming'**
  String get drawerTagline;

  /// No description provided for @mainFailedToConnect.
  ///
  /// In en, this message translates to:
  /// **'Failed To Connect To Server'**
  String get mainFailedToConnect;

  /// No description provided for @mainQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get mainQueueEmpty;

  /// Empty-queue placeholder line under "Queue is empty" while Auto DJ is armed; the two buttons below give it an opening song.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ is on and needs an opening song.'**
  String get queueEmptyDjHint;

  /// Empty-queue button: seed the armed Auto DJ with a random (filtered) song.
  ///
  /// In en, this message translates to:
  /// **'Pick a random song'**
  String get queueEmptyDjRandom;

  /// Empty-queue button: browse the library and pick the Auto DJ opening song.
  ///
  /// In en, this message translates to:
  /// **'Choose a song'**
  String get queueEmptyDjChoose;

  /// No description provided for @mainClearQueue.
  ///
  /// In en, this message translates to:
  /// **'Clear queue'**
  String get mainClearQueue;

  /// No description provided for @mainSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get mainSync;

  /// Queue tab header count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String mainQueueCount(int count);

  /// Bottom-bar Auto DJ toggle snackbars.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ Enabled'**
  String get autoDjEnabled;

  /// No description provided for @autoDjDisabled.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ Disabled'**
  String get autoDjDisabled;

  /// Bottom-bar Auto DJ enable snackbar naming the server.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ Enabled For {url}'**
  String autoDjEnabledFor(String url);

  /// Add-to-playlist bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylistTitle;

  /// No description provided for @addToPlaylistEmpty.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet — tap + to create one.'**
  String get addToPlaylistEmpty;

  /// Snackbar after adding a track to a playlist.
  ///
  /// In en, this message translates to:
  /// **'Added to {name}'**
  String addedToPlaylist(String name);

  /// Test-connection results after a credentialed login attempt.
  ///
  /// In en, this message translates to:
  /// **'Connected — signed in successfully.'**
  String get testConnectedSignedIn;

  /// No description provided for @testSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Server reached, but sign-in failed — check your username and password.'**
  String get testSignInFailed;

  /// Built-in browser node names + tab/breadcrumb labels. Server folder names are NOT translated.
  ///
  /// In en, this message translates to:
  /// **'File Explorer'**
  String get browserFileExplorer;

  /// No description provided for @browserLocalFiles.
  ///
  /// In en, this message translates to:
  /// **'Local Files'**
  String get browserLocalFiles;

  /// No description provided for @browserPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get browserPlaylists;

  /// No description provided for @browserAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get browserAlbums;

  /// No description provided for @browserArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get browserArtists;

  /// Browser home card and list title: the server's genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get browserGenres;

  /// Genre list switch: genres from the files' own tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get genreSourceTags;

  /// Genre list switch: genres the server's discovery model generated.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get genreSourceGenerated;

  /// Genre list switch: tag and generated genres together.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get genreSourceBoth;

  /// Accessibility label for the genre list's Tags / Generated / Both switch.
  ///
  /// In en, this message translates to:
  /// **'Genre source'**
  String get genreSourceLabel;

  /// Albums, Artists and Discover: the button that shows the mood filters, and its tooltip.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get moodFilters;

  /// Accessibility label for the happy / neutral / sad mood choice.
  ///
  /// In en, this message translates to:
  /// **'Happy, neutral or sad'**
  String get moodValenceGroup;

  /// Accessibility label for the relaxed / neutral / aggressive mood choice.
  ///
  /// In en, this message translates to:
  /// **'Relaxed, neutral or aggressive'**
  String get moodEnergyGroup;

  /// Accessibility label for the instrumental / vocals choice.
  ///
  /// In en, this message translates to:
  /// **'Instrumental or vocals'**
  String get moodVoiceGroup;

  /// Accessibility label for the acoustic / party / danceable mood tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get moodTagsGroup;

  /// Mood filter: songs that sound happy.
  ///
  /// In en, this message translates to:
  /// **'Happy'**
  String get moodHappy;

  /// Mood filter: neither end of its scale (neither happy nor sad, or neither relaxed nor aggressive).
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get moodNeutral;

  /// Mood filter: songs that sound sad.
  ///
  /// In en, this message translates to:
  /// **'Sad'**
  String get moodSad;

  /// Mood filter: songs that sound relaxed.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get moodRelaxed;

  /// Mood filter: songs that sound aggressive.
  ///
  /// In en, this message translates to:
  /// **'Aggressive'**
  String get moodAggressive;

  /// Mood filter: songs without vocals.
  ///
  /// In en, this message translates to:
  /// **'Instrumental'**
  String get moodInstrumental;

  /// Mood filter: songs with vocals.
  ///
  /// In en, this message translates to:
  /// **'Vocals'**
  String get moodVocals;

  /// Mood filter tag: acoustic songs.
  ///
  /// In en, this message translates to:
  /// **'Acoustic'**
  String get moodAcoustic;

  /// Mood filter tag: party songs.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get moodParty;

  /// Mood filter tag: songs you can dance to.
  ///
  /// In en, this message translates to:
  /// **'Danceable'**
  String get moodDanceable;

  /// No description provided for @browserRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get browserRecent;

  /// No description provided for @browserRated.
  ///
  /// In en, this message translates to:
  /// **'Rated'**
  String get browserRated;

  /// Home screen group header: the browse destinations.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get browserSectionLibrary;

  /// Home screen group header: Auto DJ and Sonic path.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get browserSectionListen;

  /// Home screen group header: libraries shared by other servers.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get browserSectionNetwork;

  /// Home screen group header: what the server does for you (torrents).
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get browserSectionServer;

  /// Home card: the libraries other servers share with this one.
  ///
  /// In en, this message translates to:
  /// **'Federation'**
  String get browserFederation;

  /// Auto DJ card subtext while the DJ is armed.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get browserAutoDjOn;

  /// Auto DJ card subtext while the DJ is off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get browserAutoDjOff;

  /// Federation card subtext: how many peers share a library with this server.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 shared library} other{{count} shared libraries}}'**
  String browserSharedLibraries(int count);

  /// No description provided for @browserSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get browserSearch;

  /// No description provided for @browserWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to mStream'**
  String get browserWelcomeTitle;

  /// No description provided for @browserWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap here to add a server'**
  String get browserWelcomeSubtitle;

  /// Visualizer tuning-knobs toggle + overlay chrome (DSP param labels stay English).
  ///
  /// In en, this message translates to:
  /// **'Visualizer tuning knobs'**
  String get settingsVisualizerKnobs;

  /// No description provided for @settingsVisualizerKnobsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show live sliders over the visualizer to tweak each shader\'s audio reactivity. ShaderToy Visualizer only.'**
  String get settingsVisualizerKnobsSubtitle;

  /// No description provided for @visualizerTuningTitle.
  ///
  /// In en, this message translates to:
  /// **'Tuning'**
  String get visualizerTuningTitle;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @migMoveStopped.
  ///
  /// In en, this message translates to:
  /// **'Move stopped — not enough space, or the location is unavailable.'**
  String get migMoveStopped;

  /// No description provided for @migMoveComplete.
  ///
  /// In en, this message translates to:
  /// **'Move complete'**
  String get migMoveComplete;

  /// Migration banner: move finished, N files skipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Move complete — 1 file skipped (unsupported on the destination)} other{Move complete — {count} files skipped (unsupported on the destination)}}'**
  String migMoveCompleteSkipped(int count);

  /// Migration banner while a move runs; {progress} is a percent or M/T string.
  ///
  /// In en, this message translates to:
  /// **'Moving downloads… {progress} — keep the app open'**
  String migMoving(String progress);

  /// No description provided for @migRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get migRetry;

  /// No description provided for @queueDownloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get queueDownloadAll;

  /// Queue download-all confirm dialog body.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track will be downloaded for offline playback.} other{{count} tracks will be downloaded for offline playback.}}'**
  String queueDownloadAllBody(int count);

  /// No description provided for @mainMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get mainMore;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @settingsCastQuality.
  ///
  /// In en, this message translates to:
  /// **'Cast visualizer quality'**
  String get settingsCastQuality;

  /// No description provided for @settingsCastQualitySubtitle720.
  ///
  /// In en, this message translates to:
  /// **'Resolution the visualizer streams to a TV at. 720p — lightest on the phone.'**
  String get settingsCastQualitySubtitle720;

  /// No description provided for @settingsCastQualitySubtitle1080.
  ///
  /// In en, this message translates to:
  /// **'Resolution the visualizer streams to a TV at. 1080p — sharp on any Chromecast (default).'**
  String get settingsCastQualitySubtitle1080;

  /// No description provided for @settingsCastQualitySubtitle4k.
  ///
  /// In en, this message translates to:
  /// **'Resolution the visualizer streams to a TV at. 4K — needs a 4K Chromecast; much heavier on the phone.'**
  String get settingsCastQualitySubtitle4k;

  /// No description provided for @eqCasting.
  ///
  /// In en, this message translates to:
  /// **'The equalizer adjusts audio on this device, so it’s unavailable while casting. Disconnect to use it.'**
  String get eqCasting;

  /// No description provided for @browserNothingToDownload.
  ///
  /// In en, this message translates to:
  /// **'Nothing to download in this list'**
  String get browserNothingToDownload;

  /// No description provided for @browserDownloadAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get browserDownloadAllTitle;

  /// Browser download-all confirm dialog body.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file will be downloaded.} other{{count} files will be downloaded.}}'**
  String browserDownloadAllConfirm(int count);

  /// No description provided for @browserCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get browserCloseSearch;

  /// No description provided for @browserSearchThisList.
  ///
  /// In en, this message translates to:
  /// **'Search this list'**
  String get browserSearchThisList;

  /// No description provided for @browserSearchList.
  ///
  /// In en, this message translates to:
  /// **'Search list'**
  String get browserSearchList;

  /// Browser local-search empty state.
  ///
  /// In en, this message translates to:
  /// **'No matches for \"{query}\"'**
  String browserNoMatches(String query);

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @dlLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Download location unavailable'**
  String get dlLocationUnavailable;

  /// No description provided for @dlLocationUnavailableServer.
  ///
  /// In en, this message translates to:
  /// **'Download location unavailable for this server.'**
  String get dlLocationUnavailableServer;

  /// No description provided for @dlFailed.
  ///
  /// In en, this message translates to:
  /// **'A download failed — check your connection.'**
  String get dlFailed;

  /// No description provided for @dlFatSkip.
  ///
  /// In en, this message translates to:
  /// **'Some tracks can\'t be saved on this card — their names aren\'t supported. They stream instead.'**
  String get dlFatSkip;

  /// No description provided for @dlServerGone.
  ///
  /// In en, this message translates to:
  /// **'That server is no longer configured.'**
  String get dlServerGone;

  /// No description provided for @dlStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Storage location unavailable — reconnect the SD card or change this server\'s storage location in Edit Server.'**
  String get dlStorageUnavailable;

  /// No description provided for @dlCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Could not start download — storage unavailable.'**
  String get dlCouldNotStart;

  /// No description provided for @storageLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Storage location'**
  String get storageLocationLabel;

  /// No description provided for @storageAppLocal.
  ///
  /// In en, this message translates to:
  /// **'App local'**
  String get storageAppLocal;

  /// No description provided for @storagePermanent.
  ///
  /// In en, this message translates to:
  /// **'Permanent'**
  String get storagePermanent;

  /// No description provided for @storageSdCard.
  ///
  /// In en, this message translates to:
  /// **'SD card'**
  String get storageSdCard;

  /// No description provided for @storageSdSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Save to SD card'**
  String get storageSdSwitchTitle;

  /// No description provided for @storageSdSwitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stored in the SD card\'s app folder — no permission needed, but removed if you uninstall the app.'**
  String get storageSdSwitchSubtitle;

  /// No description provided for @storageHelpAppLocal.
  ///
  /// In en, this message translates to:
  /// **'Saved inside the app. Deleted when you uninstall or clear the app.'**
  String get storageHelpAppLocal;

  /// No description provided for @storageHelpPermanent.
  ///
  /// In en, this message translates to:
  /// **'Saved to a folder you choose. Survives uninstalling the app. Requires \"All files access\".'**
  String get storageHelpPermanent;

  /// No description provided for @storageHelpSdCard.
  ///
  /// In en, this message translates to:
  /// **'Saved to a folder on the SD card you choose. May become unavailable if the card is removed. Some devices don\'t let apps write to SD cards — if folder selection keeps failing, use Permanent or App local.'**
  String get storageHelpSdCard;

  /// No description provided for @mirrorRootLabel.
  ///
  /// In en, this message translates to:
  /// **'Local copy folder (optional)'**
  String get mirrorRootLabel;

  /// No description provided for @mirrorRootHelp.
  ///
  /// In en, this message translates to:
  /// **'A folder that already holds a copy of this library, kept in sync by another tool (Syncthing, rclone, a NAS). Files found there play from disk. The app never writes to it.'**
  String get mirrorRootHelp;

  /// No description provided for @libraryCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'Library copy'**
  String get libraryCopyTitle;

  /// No description provided for @libraryCopyKeepSection.
  ///
  /// In en, this message translates to:
  /// **'Keep a full copy on this device'**
  String get libraryCopyKeepSection;

  /// No description provided for @libraryCopyKeepHelp.
  ///
  /// In en, this message translates to:
  /// **'Every track is downloaded in original quality and kept in sync: new files arrive, changed files are replaced, and files deleted on the server move to a trash folder for a while.'**
  String get libraryCopyKeepHelp;

  /// No description provided for @libraryCopyUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This server does not offer library sync. It needs mStream 6.27 or newer.'**
  String get libraryCopyUnsupported;

  /// No description provided for @libraryCopyNoLibraries.
  ///
  /// In en, this message translates to:
  /// **'No libraries reported yet — open the server once, then come back.'**
  String get libraryCopyNoLibraries;

  /// No description provided for @libraryCopyNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get libraryCopyNeverSynced;

  /// No description provided for @libraryCopyStatus.
  ///
  /// In en, this message translates to:
  /// **'Last synced {when} · {files} files · {size}'**
  String libraryCopyStatus(String when, int files, String size);

  /// No description provided for @libraryCopySyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing… {done} of {total}'**
  String libraryCopySyncing(int done, int total);

  /// No description provided for @libraryCopyPreparing.
  ///
  /// In en, this message translates to:
  /// **'Checking the server…'**
  String get libraryCopyPreparing;

  /// No description provided for @libraryCopySyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get libraryCopySyncNow;

  /// No description provided for @libraryCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'{n} files failed'**
  String libraryCopyFailed(int n);

  /// No description provided for @libraryCopyFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed files'**
  String get libraryCopyFailedTitle;

  /// No description provided for @libraryCopyLastRunError.
  ///
  /// In en, this message translates to:
  /// **'Last sync failed: {error}'**
  String libraryCopyLastRunError(String error);

  /// No description provided for @libraryCopyRetention.
  ///
  /// In en, this message translates to:
  /// **'Keep deleted files for'**
  String get libraryCopyRetention;

  /// No description provided for @libraryCopyRetentionDays.
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String libraryCopyRetentionDays(int n);

  /// No description provided for @libraryCopyRetentionForever.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get libraryCopyRetentionForever;

  /// No description provided for @libraryCopyWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
  String get libraryCopyWifiOnly;

  /// No description provided for @libraryCopyDesktopNote.
  ///
  /// In en, this message translates to:
  /// **'Syncs while the app is open.'**
  String get libraryCopyDesktopNote;

  /// No description provided for @offlineBrowseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No library index yet — sync once while the server is reachable.'**
  String get offlineBrowseUnavailable;

  /// No description provided for @offlineChip.
  ///
  /// In en, this message translates to:
  /// **'Offline copy'**
  String get offlineChip;

  /// No description provided for @storageChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get storageChooseFolder;

  /// No description provided for @storageNoFolderChosen.
  ///
  /// In en, this message translates to:
  /// **'No folder chosen yet'**
  String get storageNoFolderChosen;

  /// No description provided for @storageDownloadFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get storageDownloadFolderLabel;

  /// No description provided for @storageDownloadFolderHint.
  ///
  /// In en, this message translates to:
  /// **'folder name'**
  String get storageDownloadFolderHint;

  /// No description provided for @storageBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get storageBrowse;

  /// No description provided for @storageDownloadFolderHelp.
  ///
  /// In en, this message translates to:
  /// **'Files download to a \'media/<folder>\' directory on this device. Re-using a previous server\'s folder keeps its downloaded songs when you re-add a lost server.'**
  String get storageDownloadFolderHelp;

  /// No description provided for @storageNoStorageAvailable.
  ///
  /// In en, this message translates to:
  /// **'No storage available'**
  String get storageNoStorageAvailable;

  /// No description provided for @storageNoDownloadFolders.
  ///
  /// In en, this message translates to:
  /// **'No existing download folders found'**
  String get storageNoDownloadFolders;

  /// No description provided for @storageExistingFolders.
  ///
  /// In en, this message translates to:
  /// **'Existing download folders'**
  String get storageExistingFolders;

  /// Existing-folders list: item count for a folder.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String storageItemCount(int count);

  /// No description provided for @storageAllFilesAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant \"All files access\" to store downloads permanently, then pick the mode again.'**
  String get storageAllFilesAccess;

  /// No description provided for @storageSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get storageSettings;

  /// No description provided for @storageNoVolume.
  ///
  /// In en, this message translates to:
  /// **'Could not locate a storage volume'**
  String get storageNoVolume;

  /// No description provided for @storageNotWritable.
  ///
  /// In en, this message translates to:
  /// **'That folder isn\'t writable — pick another.'**
  String get storageNotWritable;

  /// No description provided for @storageNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get storageNewFolder;

  /// No description provided for @storageFolderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get storageFolderNameHint;

  /// No description provided for @storageCouldNotCreateFolder.
  ///
  /// In en, this message translates to:
  /// **'Could not create folder'**
  String get storageCouldNotCreateFolder;

  /// No description provided for @storageNoSubfolders.
  ///
  /// In en, this message translates to:
  /// **'No subfolders here'**
  String get storageNoSubfolders;

  /// No description provided for @storageUseThisFolder.
  ///
  /// In en, this message translates to:
  /// **'Use this folder'**
  String get storageUseThisFolder;

  /// No description provided for @storageMovedToNewFolder.
  ///
  /// In en, this message translates to:
  /// **'Moved downloaded files to the new folder.'**
  String get storageMovedToNewFolder;

  /// No description provided for @storageMoveAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'A move is already running — let it finish first.'**
  String get storageMoveAlreadyRunning;

  /// No description provided for @storageMigrateTitle.
  ///
  /// In en, this message translates to:
  /// **'Different storage volume'**
  String get storageMigrateTitle;

  /// Cross-volume migration dialog body.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This server’s 1 downloaded file ({size}) is on a different storage volume from the new location. Choose what to do:} other{This server’s {count} downloaded files ({size}) are on a different storage volume from the new location. Choose what to do:}}'**
  String storageMigrateBody(int count, String size);

  /// Migration dialog low-space warning.
  ///
  /// In en, this message translates to:
  /// **'Not enough free space at the destination ({free} free). A move may fail partway — free up space first.'**
  String storageMigrateNoSpace(String free);

  /// No description provided for @storageMigrateMove.
  ///
  /// In en, this message translates to:
  /// **'Move them'**
  String get storageMigrateMove;

  /// No description provided for @storageMigrateMoveBody.
  ///
  /// In en, this message translates to:
  /// **'Copy to the new location in the background, deleting each old copy as it goes. Keep the app open until it finishes.'**
  String get storageMigrateMoveBody;

  /// No description provided for @storageMigrateLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave them'**
  String get storageMigrateLeave;

  /// No description provided for @storageMigrateLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Switch now; the old downloads stay where they are and re-download at the new location.'**
  String get storageMigrateLeaveBody;

  /// No description provided for @storageMigrateDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete old downloads'**
  String get storageMigrateDelete;

  /// No description provided for @storageMigrateDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Switch now and remove the old files; they\'ll re-download at the new location.'**
  String get storageMigrateDeleteBody;

  /// No description provided for @storageMovingBackground.
  ///
  /// In en, this message translates to:
  /// **'Moving your downloads in the background — keep the app open.'**
  String get storageMovingBackground;

  /// No description provided for @storageChooseFolderFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a download folder first.'**
  String get storageChooseFolderFirst;

  /// No description provided for @storageChooseSdFolderFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder on the SD card first. If every folder is rejected, your device may not let apps write to the card — use Permanent or App local instead.'**
  String get storageChooseSdFolderFirst;

  /// No description provided for @castPlayOn.
  ///
  /// In en, this message translates to:
  /// **'Play on'**
  String get castPlayOn;

  /// No description provided for @castPlayOnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play on…'**
  String get castPlayOnTooltip;

  /// No description provided for @castSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for cast devices…'**
  String get castSearching;

  /// No description provided for @castNotSeeing.
  ///
  /// In en, this message translates to:
  /// **'Don\'t see your device? Make sure it\'s on the same Wi-Fi.'**
  String get castNotSeeing;

  /// No description provided for @castVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Cast visualizer'**
  String get castVisualizer;

  /// No description provided for @castVisualizerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stream the visualizer to the TV · Chromecast only'**
  String get castVisualizerSubtitle;

  /// The local (phone) target in the cast picker — playback stays on this device instead of a Chromecast/DLNA renderer.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get castThisDevice;

  /// No description provided for @visualizerNoKnobs.
  ///
  /// In en, this message translates to:
  /// **'This shader exposes no knobs.'**
  String get visualizerNoKnobs;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// Settings row title for the Now Playing panel size picker (Small / Medium / Large / XL).
  ///
  /// In en, this message translates to:
  /// **'Now Playing layout'**
  String get settingsPlayerLayout;

  /// No description provided for @playerLayoutSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get playerLayoutSmall;

  /// No description provided for @playerLayoutMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get playerLayoutMedium;

  /// No description provided for @playerLayoutLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get playerLayoutLarge;

  /// No description provided for @playerLayoutXl.
  ///
  /// In en, this message translates to:
  /// **'XL'**
  String get playerLayoutXl;

  /// No description provided for @playerLayoutSmallDesc.
  ///
  /// In en, this message translates to:
  /// **'Slim bar — maximum queue'**
  String get playerLayoutSmallDesc;

  /// No description provided for @playerLayoutMediumDesc.
  ///
  /// In en, this message translates to:
  /// **'Banner — balanced (default)'**
  String get playerLayoutMediumDesc;

  /// No description provided for @playerLayoutLargeDesc.
  ///
  /// In en, this message translates to:
  /// **'Compact — centered art'**
  String get playerLayoutLargeDesc;

  /// No description provided for @playerLayoutXlDesc.
  ///
  /// In en, this message translates to:
  /// **'Hero — full album art'**
  String get playerLayoutXlDesc;

  /// No description provided for @queueNothingToDownloadEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty — nothing to download'**
  String get queueNothingToDownloadEmpty;

  /// No description provided for @queueNothingToDownloadSaved.
  ///
  /// In en, this message translates to:
  /// **'Nothing to download — tracks are already saved'**
  String get queueNothingToDownloadSaved;

  /// No description provided for @settingsAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get settingsAccentColor;

  /// No description provided for @settingsAccentColorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The highlight color used across the app.'**
  String get settingsAccentColorSubtitle;

  /// No description provided for @accentThemeDefault.
  ///
  /// In en, this message translates to:
  /// **'Theme default'**
  String get accentThemeDefault;

  /// No description provided for @accentCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get accentCustom;

  /// No description provided for @lanOnYourNetwork.
  ///
  /// In en, this message translates to:
  /// **'Servers on your local network'**
  String get lanOnYourNetwork;

  /// No description provided for @lanSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for servers…'**
  String get lanSearching;

  /// No description provided for @lanRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get lanRefresh;

  /// No description provided for @lanServerVersion.
  ///
  /// In en, this message translates to:
  /// **'mStream v{version}'**
  String lanServerVersion(String version);

  /// No description provided for @lanLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {name}'**
  String lanLoginTitle(String name);

  /// No description provided for @lanUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach this server on the network.'**
  String get lanUnreachable;

  /// No description provided for @lanNoCode.
  ///
  /// In en, this message translates to:
  /// **'Quick Connect is on for this server, but it didn\'t share a pairing code. Sign in as an admin, or ask the operator to enable code sharing.'**
  String get lanNoCode;

  /// No description provided for @settingsResumeQueue.
  ///
  /// In en, this message translates to:
  /// **'Resume queue on launch'**
  String get settingsResumeQueue;

  /// No description provided for @settingsResumeQueueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save the play queue and your place, and restore them when you reopen the app.'**
  String get settingsResumeQueueSubtitle;

  /// No description provided for @settingsOfflineQueue.
  ///
  /// In en, this message translates to:
  /// **'Keep queue available offline'**
  String get settingsOfflineQueue;

  /// No description provided for @settingsOfflineQueueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically download queued tracks to this device so playback survives losing the connection.'**
  String get settingsOfflineQueueSubtitle;

  /// No description provided for @settingsOfflineQueueWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Download on Wi-Fi only'**
  String get settingsOfflineQueueWifiOnly;

  /// No description provided for @settingsOfflineQueueWifiOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wait for Wi-Fi before downloading queued tracks.'**
  String get settingsOfflineQueueWifiOnlySubtitle;

  /// Title of the keep-queue-offline retention-cap setting.
  ///
  /// In en, this message translates to:
  /// **'Auto-download limit'**
  String get settingsAutoDownloadCap;

  /// Subtitle when a finite auto-download cap is set.
  ///
  /// In en, this message translates to:
  /// **'Cache this many songs ahead of the one playing; songs left behind are removed as you go.'**
  String get settingsAutoDownloadCapSubtitle;

  /// Subtitle when the auto-download cap is unlimited (0).
  ///
  /// In en, this message translates to:
  /// **'Cache the whole queue (no limit).'**
  String get settingsAutoDownloadCapSubtitleUnlimited;

  /// Shown as the auto-download cap value when there's no limit.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get settingsAutoDownloadCapUnlimited;

  /// Text field label in the auto-download limit dialog.
  ///
  /// In en, this message translates to:
  /// **'Number of tracks'**
  String get settingsAutoDownloadCapField;

  /// Explainer in the auto-download limit dialog.
  ///
  /// In en, this message translates to:
  /// **'How many queued songs to keep downloaded, counting from the one playing. As playback moves on, songs that fall behind are deleted. Set to 0 to cache the whole queue.'**
  String get settingsAutoDownloadCapDialogBody;

  /// No description provided for @downloadWaitingWifi.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi'**
  String get downloadWaitingWifi;

  /// No description provided for @settingsRatingHalf.
  ///
  /// In en, this message translates to:
  /// **'Half-star ratings'**
  String get settingsRatingHalf;

  /// No description provided for @settingsRatingHalfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rate songs in half-star steps (long-press a star).'**
  String get settingsRatingHalfSubtitle;

  /// No description provided for @ratingTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get ratingTitle;

  /// No description provided for @ratingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save rating'**
  String get ratingFailed;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable logging'**
  String get diagnosticsEnable;

  /// No description provided for @diagnosticsHint.
  ///
  /// In en, this message translates to:
  /// **'Logs stay on your device. Tokens are hidden before copying or sharing.'**
  String get diagnosticsHint;

  /// No description provided for @diagnosticsVerbose.
  ///
  /// In en, this message translates to:
  /// **'Verbose logging'**
  String get diagnosticsVerbose;

  /// No description provided for @diagnosticsVerboseHint.
  ///
  /// In en, this message translates to:
  /// **'Also logs high-frequency events like app focus changes. Only needed when diagnosing a playback issue.'**
  String get diagnosticsVerboseHint;

  /// No description provided for @diagnosticsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get diagnosticsCopy;

  /// No description provided for @diagnosticsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get diagnosticsShare;

  /// No description provided for @diagnosticsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get diagnosticsClear;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied to clipboard'**
  String get diagnosticsCopied;

  /// No description provided for @diagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get diagnosticsEmpty;

  /// No description provided for @storageAppExternal.
  ///
  /// In en, this message translates to:
  /// **'App external'**
  String get storageAppExternal;

  /// Storage-location option: the SD card's own app folder (no permission needed, removed on uninstall). Only offered when a card is present.
  ///
  /// In en, this message translates to:
  /// **'App SD card'**
  String get storageAppSdCard;

  /// No description provided for @selfSignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow self-signed certificate'**
  String get selfSignedTitle;

  /// No description provided for @selfSignedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip TLS validation for this server. Only enable on a network you trust.'**
  String get selfSignedSubtitle;

  /// Title of the Imported Shaders screen and its Settings entry.
  ///
  /// In en, this message translates to:
  /// **'Imported shaders'**
  String get importedShadersTitle;

  /// Subtitle under the Imported shaders entry in Settings.
  ///
  /// In en, this message translates to:
  /// **'Add your own .glsl files to the ShaderToy Visualizer\'s rotation.'**
  String get importedShadersSettingsSubtitle;

  /// Tooltip for the button that re-scans the shader folder for new files.
  ///
  /// In en, this message translates to:
  /// **'Rescan folder'**
  String get importedShadersRescan;

  /// Instruction shown above the shader folder path.
  ///
  /// In en, this message translates to:
  /// **'Drop .glsl files in this folder, then Rescan:'**
  String get importedShadersDropHint;

  /// Tooltip for the button that copies the shader folder path to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get importedShadersCopyPath;

  /// Help text explaining where the shader folder is and when imported shaders are used.
  ///
  /// In en, this message translates to:
  /// **'Reachable over USB or a file manager (under Android/data). Imported shaders join the ShaderToy Visualizer\'s rotation.'**
  String get importedShadersReachableHint;

  /// Tooltip for the button that deletes an imported shader file.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get importedShadersRemove;

  /// Empty-state title when the shader folder has no files.
  ///
  /// In en, this message translates to:
  /// **'No shaders in the folder yet'**
  String get importedShadersEmptyTitle;

  /// Empty-state body when the shader folder has no files.
  ///
  /// In en, this message translates to:
  /// **'Copy Shadertoy-style .glsl files into the folder above, then tap Rescan.'**
  String get importedShadersEmptyBody;

  /// Warning subtitle when an imported file does not look like a fragment shader.
  ///
  /// In en, this message translates to:
  /// **'May not be a valid shader — no mainImage/main entry point.'**
  String get importedShadersInvalid;

  /// Button that copies .glsl shaders found in the device Downloads folder into the shader folder.
  ///
  /// In en, this message translates to:
  /// **'Import .glsl from Downloads'**
  String get importedShadersImportDownloads;

  /// Snackbar after copying shaders in from the Downloads folder.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} shader(s) from Downloads'**
  String importedShadersDownloadsImported(int count);

  /// Snackbar when the Downloads folder has no new shaders to import.
  ///
  /// In en, this message translates to:
  /// **'No new .glsl files in Downloads'**
  String get importedShadersDownloadsNone;

  /// Snackbar when all-files access is denied, so Downloads can't be read.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is needed to read Downloads'**
  String get importedShadersDownloadsNoPermission;

  /// Add-server form: tab label for the classic HTTP URL connection (paired with the 'Quick Connect' tab).
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get addServerTabUrl;

  /// Add-server form: tab label for the iroh peer-to-peer pairing flow (paired with the 'Server URL' tab).
  ///
  /// In en, this message translates to:
  /// **'Quick Connect'**
  String get addServerTabQuickConnect;

  /// Header of the manual pairing-code section on the Quick Connect tab.
  ///
  /// In en, this message translates to:
  /// **'Connect with a pairing code'**
  String get irohPairingHeader;

  /// Explainer under the pairing-code section header on the Quick Connect tab.
  ///
  /// In en, this message translates to:
  /// **'Enable Remote Access on the server, then paste its pairing code or scan the QR.'**
  String get irohPairingBody;

  /// Text field label for the iroh pairing code (add-server iroh tab and the re-pair sheet).
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get irohPairingCodeLabel;

  /// Hint text inside the iroh pairing-code field.
  ///
  /// In en, this message translates to:
  /// **'Paste the code from the server Remote Access panel'**
  String get irohPairingCodeHint;

  /// Server ⋮ menu action that displays the stored iroh pairing code as a QR.
  ///
  /// In en, this message translates to:
  /// **'Show pairing code'**
  String get irohShowPairingCode;

  /// Body text of the pairing-code QR sheet.
  ///
  /// In en, this message translates to:
  /// **'Scan with the mStream app on another device to connect it to this server, or copy the code and paste it there.'**
  String get irohQrBody;

  /// Caution line under the pairing QR — the code is a credential.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this code can connect to your server.'**
  String get irohQrCaution;

  /// Button that opens the camera to scan an iroh pairing QR code.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get irohScanQr;

  /// Button that pastes an iroh pairing code from the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get irohPaste;

  /// Button that tests the iroh tunnel to the server.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get irohTestConnection;

  /// Busy label on the iroh Test-connection button while the test runs.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get irohTesting;

  /// App-bar title of the full-screen iroh QR scanner.
  ///
  /// In en, this message translates to:
  /// **'Scan pairing QR'**
  String get irohScannerTitle;

  /// Shown when QR scanning is attempted where the iroh native lib is unavailable (desktop, or a 32-bit Android device without libiroh_tunnel.so).
  ///
  /// In en, this message translates to:
  /// **'QR scanning isn\'t available on this device.'**
  String get irohQrAndroidOnly;

  /// Shown in the Quick Connect tab (and on a test-connection attempt) where the iroh native lib is unavailable (desktop, or a 32-bit Android device without libiroh_tunnel.so).
  ///
  /// In en, this message translates to:
  /// **'Quick Connect isn\'t available on this device.'**
  String get irohAndroidOnly;

  /// Shown when the camera permission is denied while trying to scan an iroh QR.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is needed to scan a code.'**
  String get irohCameraPermission;

  /// Validation shown when testing the iroh connection with no pairing code entered.
  ///
  /// In en, this message translates to:
  /// **'Paste or scan a pairing code first.'**
  String get irohPasteFirst;

  /// Validation shown when trying to sign in before a successful iroh test connection.
  ///
  /// In en, this message translates to:
  /// **'Test the connection first.'**
  String get irohTestFirst;

  /// Result shown when the iroh test connection succeeds (server version unknown).
  ///
  /// In en, this message translates to:
  /// **'Connected through the iroh tunnel'**
  String get irohTestConnected;

  /// Result shown when the iroh test connection succeeds and the server reported its version.
  ///
  /// In en, this message translates to:
  /// **'Connected through the iroh tunnel — mStream v{version}'**
  String irohTestConnectedVersion(String version);

  /// Suffix appended to the iroh test result when the path is a direct (hole-punched) connection.
  ///
  /// In en, this message translates to:
  /// **' · direct'**
  String get irohPathSuffixDirect;

  /// Suffix appended to the iroh test result when the connection is routed through a relay.
  ///
  /// In en, this message translates to:
  /// **' · via relay'**
  String get irohPathSuffixRelay;

  /// Shown when the iroh tunnel connects but the server's HTTP reply times out.
  ///
  /// In en, this message translates to:
  /// **'Tunnel opened but the server did not respond in time.'**
  String get irohTunnelTimeout;

  /// Shown when the iroh tunnel test fails; {error} is the raw error text.
  ///
  /// In en, this message translates to:
  /// **'Tunnel test failed: {error}'**
  String irohTunnelTestFailed(String error);

  /// Header of the sign-in step on the iroh tab (after a successful test).
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get irohSignInHeader;

  /// Busy label on the iroh 'Sign in & save' button while signing in.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get irohSigningIn;

  /// Button that signs in through the iroh tunnel and saves the server.
  ///
  /// In en, this message translates to:
  /// **'Sign in & save'**
  String get irohSignInSave;

  /// Shown when signing in through the iroh tunnel times out.
  ///
  /// In en, this message translates to:
  /// **'Sign-in timed out.'**
  String get irohSignInTimeout;

  /// Shown when iroh sign-in fails unexpectedly; {error} is the raw error text.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String irohSignInFailed(String error);

  /// Shown when iroh sign-in returns an HTTP error; {status} is the HTTP status code.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed (HTTP {status}). Check your username and password.'**
  String irohSignInFailedHttp(int status);

  /// Banner while the iroh tunnel is making its first connection.
  ///
  /// In en, this message translates to:
  /// **'Connecting to server…'**
  String get irohBannerConnecting;

  /// Banner while the iroh tunnel is re-dialing after a drop.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to server…'**
  String get irohBannerReconnecting;

  /// Banner when the iroh tunnel is down; paired with a Retry action.
  ///
  /// In en, this message translates to:
  /// **'Disconnected from server.'**
  String get irohBannerDisconnected;

  /// Banner when the iroh tunnel is connected but routed through a relay (not direct).
  ///
  /// In en, this message translates to:
  /// **'Connected via relay — slower path.'**
  String get irohBannerRelay;

  /// Banner when the server's connect secret was rotated; paired with a Re-pair action.
  ///
  /// In en, this message translates to:
  /// **'Server pairing changed — re-pair to reconnect.'**
  String get irohBannerRepair;

  /// Action button to re-pair an iroh server (banner) and confirm in the re-pair sheet.
  ///
  /// In en, this message translates to:
  /// **'Re-pair'**
  String get irohRepairAction;

  /// Action button to retry connecting a down iroh tunnel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get irohRetry;

  /// Title of the iroh re-pair bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Re-pair server'**
  String get irohRepairTitle;

  /// Explainer in the iroh re-pair sheet.
  ///
  /// In en, this message translates to:
  /// **'This server\'s pairing code changed (its secret was rotated). Paste or scan the new code from the server\'s Remote Access panel.'**
  String get irohRepairBody;

  /// Snackbar in the re-pair sheet when the new pairing code fails to connect; the previous code is kept.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect with that code — check it and try again.'**
  String get irohRepairFailed;

  /// Chip label on the active iroh server's tile when the connection is direct (hole-punched).
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get irohPathDirect;

  /// Chip label on the active iroh server's tile when the connection is routed through a relay.
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get irohPathRelay;

  /// Note in the cast picker when the active server is an iroh (peer-to-peer) server.
  ///
  /// In en, this message translates to:
  /// **'Casting to external devices isn\'t available for peer-to-peer (iroh) servers — playback stays on this device.'**
  String get irohCastUnavailable;

  /// Shown when trying to share tracks from an iroh (peer-to-peer) server.
  ///
  /// In en, this message translates to:
  /// **'Sharing isn\'t available for peer-to-peer (iroh) servers — they have no public URL to link to.'**
  String get irohShareUnavailable;

  /// Title of the Discover screen (sonic-similarity recommendations seeded by the playing track) and its entry in the player's more-actions sheet. Retitled "More like this" by the Discover page plan §2.12: the history-seeded page alone is called "Discover" (discoverPageTitle).
  ///
  /// In en, this message translates to:
  /// **'More like this'**
  String get discoverTitle;

  /// Title of the Discover page (recommendations seeded by the user's play history on one server: library songs and albums, network leads, peers' songs) and its card under Listen on the server home.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discoverPageTitle;

  /// A seed window length in days (segmented control label and app-bar subtitle part).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String discoverPageWindowDays(int count);

  /// The all-time seed window (segmented control label and app-bar subtitle part).
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get discoverPageWindowAll;

  /// Seeds sheet note when the chosen window had no plays and the server looked further back. {window} is like "30 days".
  ///
  /// In en, this message translates to:
  /// **'Nothing in the last {window}, so these come from further back.'**
  String discoverPageWidened(String window);

  /// Title of the Discover page's seeds sheet (opened from More options): the songs the page is seeded from.
  ///
  /// In en, this message translates to:
  /// **'Based on'**
  String get discoverPageBasedOn;

  /// Label in the Discover page's configuration bar, directly before the window chooser, which shows "7 days" / "30 days" / "90 days" / "All time" (discoverPageWindowDays / discoverPageWindowAll). Reads as one phrase: "Based on the last [30 days ▾]".
  ///
  /// In en, this message translates to:
  /// **'Based on the last'**
  String get discoverPageBasedOnLast;

  /// Label in the Discover page's configuration bar before the window chooser when the window is all time (discoverPageWindowAll), where "Based on the last" would read wrong: "Based on [All time ▾]". Any wording that reads as one phrase with the all-time label works, e.g. "Period".
  ///
  /// In en, this message translates to:
  /// **'Based on'**
  String get discoverPageBasedOnAllTime;

  /// Link at the right of the Discover page's configuration bar; opens the seeds sheet (which songs the page is based on: drop one, bring one back, pin a song).
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get discoverPageMoreOptions;

  /// Tooltip of the refresh button on the Discover page's top bar (where other lists have search): asks again, and the server answers from a new random batch of the songs you finished.
  ///
  /// In en, this message translates to:
  /// **'New seeds'**
  String get discoverPageNewSeeds;

  /// Discover section header (shown in small caps): albums from the user's own library.
  ///
  /// In en, this message translates to:
  /// **'Albums from your library'**
  String get discoverPageAlbumsLibrary;

  /// Discover section header (shown in small caps): albums from the one connected (federated) server that answered. {name} is that server's name.
  ///
  /// In en, this message translates to:
  /// **'Albums from {name}'**
  String discoverPageAlbumsPeer(String name);

  /// Discover section header (shown in small caps): albums from several connected (federated) servers.
  ///
  /// In en, this message translates to:
  /// **'Albums from connected servers'**
  String get discoverPageAlbumsPeers;

  /// Discover section header (shown in small caps): songs from the user's own library.
  ///
  /// In en, this message translates to:
  /// **'Songs from your library'**
  String get discoverPageSongsLibrary;

  /// Discover section header (shown in small caps): songs from the one connected (federated) server that answered. {name} is that server's name.
  ///
  /// In en, this message translates to:
  /// **'Songs from {name}'**
  String discoverPageSongsPeer(String name);

  /// Discover section header (shown in small caps): songs from several connected (federated) servers.
  ///
  /// In en, this message translates to:
  /// **'Songs from connected servers'**
  String get discoverPageSongsPeers;

  /// One line under "Songs from your library" when the library has no suggestions.
  ///
  /// In en, this message translates to:
  /// **'Nothing new in your library sounds like these songs.'**
  String get discoverPageLibraryNothing;

  /// One line under the connected servers' songs header when they had nothing playable.
  ///
  /// In en, this message translates to:
  /// **'Nothing from your connected servers right now.'**
  String get discoverPagePeersQuiet;

  /// One line under the connected servers' songs header when asking them failed; a Try again button follows it.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach your connected servers.'**
  String get discoverPagePeersFailed;

  /// Button under Discover's library songs: save them as a server playlist.
  ///
  /// In en, this message translates to:
  /// **'Save as playlist'**
  String get discoverPageSaveAsPlaylist;

  /// Button on Discover's nothing-finished card: open the server's File Explorer.
  ///
  /// In en, this message translates to:
  /// **'Browse your library'**
  String get discoverPageBrowseLibrary;

  /// Relative time: today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get discoverPageAgoToday;

  /// Relative time: yesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get discoverPageAgoYesterday;

  /// Relative time in months.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month ago} other{{count} months ago}}'**
  String discoverPageAgoMonths(int count);

  /// Relative time in years.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year ago} other{{count} years ago}}'**
  String discoverPageAgoYears(int count);

  /// Card title when nothing has been finished yet.
  ///
  /// In en, this message translates to:
  /// **'Finish a few songs and this page learns your taste'**
  String get discoverPageRandomTitle;

  /// Card body under that title.
  ///
  /// In en, this message translates to:
  /// **'Discover seeds itself from songs you play to the end. Skipped songs never count. Until there are some, here are suggestions around a random pick from your library.'**
  String get discoverPageRandomBody;

  /// Button on the nothing-finished card: seed from another random song.
  ///
  /// In en, this message translates to:
  /// **'Another pick'**
  String get discoverPageAnotherPick;

  /// Button on the nothing-finished card: pick the seed song yourself.
  ///
  /// In en, this message translates to:
  /// **'Choose a song…'**
  String get discoverPageChooseSong;

  /// Shown when the Discover page could not load and has nothing to show.
  ///
  /// In en, this message translates to:
  /// **'Discover couldn\'t load. Check the connection and try again.'**
  String get discoverPageError;

  /// Button: try loading again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get discoverPageRetry;

  /// Seeds sheet group: songs pinned for this visit (now playing at open, songs picked).
  ///
  /// In en, this message translates to:
  /// **'Picked for this visit'**
  String get discoverPagePickedHeader;

  /// Group header in the Discover page's seeds sheet over the random seed the server picked because nothing was finished yet (in place of "Finished recently").
  ///
  /// In en, this message translates to:
  /// **'Random pick'**
  String get discoverPageRandomHeader;

  /// Seeds sheet group: seeds the user switched off (left out for the rest of this visit).
  ///
  /// In en, this message translates to:
  /// **'Left out'**
  String get discoverPageDroppedHeader;

  /// Small note next to that header.
  ///
  /// In en, this message translates to:
  /// **'switch one on to bring it back'**
  String get discoverPageDroppedNote;

  /// Seed row detail: how many times the seed was played.
  ///
  /// In en, this message translates to:
  /// **'played {count}×'**
  String discoverPagePlayedTimes(int count);

  /// Seed row detail: the seed was listened to past half but not to the end.
  ///
  /// In en, this message translates to:
  /// **'listened to'**
  String get discoverPageListenedTo;

  /// Seed row detail: the seed has not been analyzed yet, so it steers nothing.
  ///
  /// In en, this message translates to:
  /// **'not analyzed yet'**
  String get discoverPageNotAnalyzed;

  /// Seeds sheet group: add a seed yourself.
  ///
  /// In en, this message translates to:
  /// **'Add your own'**
  String get discoverPageAddOwn;

  /// Small note next to that header.
  ///
  /// In en, this message translates to:
  /// **'a song you want more of'**
  String get discoverPageAddOwnSub;

  /// Seeds sheet row: opens the song picker.
  ///
  /// In en, this message translates to:
  /// **'Pick a song…'**
  String get discoverPagePickSong;

  /// Subtitle of that row.
  ///
  /// In en, this message translates to:
  /// **'search your library, or take a random one'**
  String get discoverPagePickSongSub;

  /// Seeds sheet primary button: apply the seeds that are switched on.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Use this 1} other{Use these {count}}}'**
  String discoverPageUseThese(int count);

  /// Subtitle under the Discover screen title: results are audio-similarity matches, not genre-tag matches.
  ///
  /// In en, this message translates to:
  /// **'Matched by sound'**
  String get discoverMatchedBySound;

  /// Discover section header: library tracks that sound like the playing one.
  ///
  /// In en, this message translates to:
  /// **'Similar tracks'**
  String get discoverSimilarTracks;

  /// Discover section header: library artists whose sound is closest to the playing track's artist.
  ///
  /// In en, this message translates to:
  /// **'Similar artists'**
  String get discoverSimilarArtists;

  /// Discover section header: leads from public P2P peers' libraries (not playable).
  ///
  /// In en, this message translates to:
  /// **'From the network'**
  String get discoverFromNetwork;

  /// Discover section header: leads from paired federation servers (not playable).
  ///
  /// In en, this message translates to:
  /// **'From your peers'**
  String get discoverFromPeers;

  /// Button in the Similar tracks section header: append every listed track to the play queue.
  ///
  /// In en, this message translates to:
  /// **'Queue all'**
  String get discoverQueueAll;

  /// Switch above the network/peers sections: only show artists not already in the library.
  ///
  /// In en, this message translates to:
  /// **'New artists only'**
  String get discoverNewArtistsOnly;

  /// Hint when the playing track has no audio embedding yet (server-side analysis still pending).
  ///
  /// In en, this message translates to:
  /// **'This song hasn\'t been analyzed yet — similar songs appear once the discovery scan reaches it.'**
  String get discoverNotAnalyzed;

  /// Header of the Discover card shown when the server has discovery enabled but no analyzed music yet.
  ///
  /// In en, this message translates to:
  /// **'Nothing analyzed yet'**
  String get discoverScanPendingTitle;

  /// Body of that card. The server answers the same 403 for 'feature off' and 'enabled but no index', so this is what the app can honestly say.
  ///
  /// In en, this message translates to:
  /// **'This server has sonic discovery switched on, but hasn\'t analyzed any music yet. Similar songs appear once the discovery scan has run.'**
  String get discoverScanPendingBody;

  /// Button that re-pings the server and retries the discovery requests.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get discoverCheckAgain;

  /// Shown when a re-check reveals discovery was switched off server-side while the screen was open.
  ///
  /// In en, this message translates to:
  /// **'Sonic discovery has been switched off on this server.'**
  String get discoverTurnedOff;

  /// Sonic path build failed with a 403 and a re-ping confirmed discovery is still enabled: the server has no index yet.
  ///
  /// In en, this message translates to:
  /// **'This server hasn\'t analyzed any music yet, so there\'s nothing to build a path through. It works once the discovery scan has run.'**
  String get pathScanPending;

  /// Empty state for a Discover section that returned no results.
  ///
  /// In en, this message translates to:
  /// **'No matches found.'**
  String get discoverNothingFound;

  /// Discover screen body when nothing is playing (recommendations are seeded by the current track).
  ///
  /// In en, this message translates to:
  /// **'Play a song to discover similar music.'**
  String get discoverNoSeed;

  /// Snackbar after tapping a network/peer lead: "Artist - Title" was copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied — go find it!'**
  String get discoverLeadCopied;

  /// Tooltip on a lead row's link icon: open the recording's MusicBrainz page in the browser.
  ///
  /// In en, this message translates to:
  /// **'Open on MusicBrainz'**
  String get discoverOpenMusicBrainz;

  /// Empty state for the network section when no P2P peer snapshots have been fetched yet.
  ///
  /// In en, this message translates to:
  /// **'No network data yet — peer libraries download in the background once other servers are heard.'**
  String get discoverNetworkWarmingUp;

  /// Empty state for the network section when the new-artists-only filter removed every match.
  ///
  /// In en, this message translates to:
  /// **'Nothing new for this song — the network has no unfamiliar matches.'**
  String get discoverNetworkNothingNew;

  /// Empty state for the peers section when every federation peer was unreachable.
  ///
  /// In en, this message translates to:
  /// **'Your peers didn\'t answer — they may be offline right now.'**
  String get discoverPeersUnreachable;

  /// Empty state for the peers section when peers answered but had no (new) matches.
  ///
  /// In en, this message translates to:
  /// **'Nothing new for this song on your peers\' servers.'**
  String get discoverPeersNothingNew;

  /// Auto DJ continuity toggle: pick the next track by audio similarity to the playing one.
  ///
  /// In en, this message translates to:
  /// **'Sonic similarity'**
  String get autoDjSonicTitle;

  /// Subtitle under the sonic similarity toggle when the server supports it. The pool is a hard constraint — no random fallback.
  ///
  /// In en, this message translates to:
  /// **'Only pick songs that sound like the session, using the server\'s audio analysis.'**
  String get autoDjSonicSubtitle;

  /// Subtitle under the (disabled) sonic similarity toggle when the server lacks the discovery capability.
  ///
  /// In en, this message translates to:
  /// **'This server doesn\'t have discovery data — picks stay random.'**
  String get autoDjSonicUnavailable;

  /// Sonic similarity subtitle when discovery is on but the scan has produced no vectors yet (server features.discoveryReady false).
  ///
  /// In en, this message translates to:
  /// **'Discovery is on but the scan hasn\'t produced data yet — picks stay random until it does.'**
  String get autoDjSonicNotReady;

  /// Label for the sonic similarity threshold slider (raw cosine threshold sent as minSimilarity).
  ///
  /// In en, this message translates to:
  /// **'Match strictness'**
  String get autoDjSonicStrictness;

  /// Value readout next to the strictness slider: picks must match at least this percentage.
  ///
  /// In en, this message translates to:
  /// **'{pct}% or closer'**
  String autoDjSonicStrictnessValue(int pct);

  /// Label for the sonic seed row and the seed-picker sheet title: the song the session starts from.
  ///
  /// In en, this message translates to:
  /// **'Seed song'**
  String get autoDjSonicSeedLabel;

  /// Seed row value when no explicit seed is set.
  ///
  /// In en, this message translates to:
  /// **'No seed — the playing song anchors the session.'**
  String get autoDjSonicSeedNone;

  /// Browse-to-pick banner shown while the Auto DJ seed capture is armed
  ///
  /// In en, this message translates to:
  /// **'Pick the seed song — tap a track anywhere in the library'**
  String get autoDjSonicSeedBanner;

  /// Hint in the seed-picker sheet's search field.
  ///
  /// In en, this message translates to:
  /// **'Search for a song…'**
  String get autoDjSonicSeedSearchHint;

  /// Seed-picker action (and dice-button tooltip): use a random library song as the seed.
  ///
  /// In en, this message translates to:
  /// **'Random song'**
  String get autoDjSonicSeedRandom;

  /// Tooltip on the clear button next to a set seed.
  ///
  /// In en, this message translates to:
  /// **'Remove seed song'**
  String get autoDjSonicSeedRemove;

  /// Error when the random-seed request fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t fetch a song from the server.'**
  String get autoDjSonicSeedFailed;

  /// Snackbar when the Auto DJ filters exclude every track, so no opening song can be picked.
  ///
  /// In en, this message translates to:
  /// **'No songs match your Auto DJ filters — try loosening them'**
  String get autoDjSeedNoMatch;

  /// Context action on a track (album rows, Song Info chip, browser long-press): open Discover pinned to that track.
  ///
  /// In en, this message translates to:
  /// **'Find similar'**
  String get discoverFindSimilar;

  /// Card title on the Discover screen: one tap enables sonic Auto DJ seeded by the screen's track and starts endless playback.
  ///
  /// In en, this message translates to:
  /// **'Start a sonic session'**
  String get discoverStartSession;

  /// Session card subtitle when the screen has a seed track. Must warn that the queue is replaced.
  ///
  /// In en, this message translates to:
  /// **'Endless music that sounds like this — replaces your queue.'**
  String get discoverStartSessionSubtitle;

  /// Session card subtitle in the no-seed state (nothing playing): a random library song seeds the session.
  ///
  /// In en, this message translates to:
  /// **'Endless music from a random starting song — replaces your queue.'**
  String get discoverStartSessionSubtitleRandom;

  /// Toast after the session card starts playback (sonic Auto DJ was enabled and seeded).
  ///
  /// In en, this message translates to:
  /// **'Sonic session started — Auto DJ is on.'**
  String get discoverSessionStarted;

  /// Label above the sonic anchor-mode selector (rolling vs locked).
  ///
  /// In en, this message translates to:
  /// **'Anchor'**
  String get autoDjSonicAnchorLabel;

  /// Rolling anchor mode: sonic seeds are the session's recent DJ picks.
  ///
  /// In en, this message translates to:
  /// **'Follow the vibe'**
  String get autoDjSonicAnchorRolling;

  /// Locked anchor mode: one pinned song seeds every pick for the whole session.
  ///
  /// In en, this message translates to:
  /// **'Stay on seed'**
  String get autoDjSonicAnchorLocked;

  /// Explanation under the anchor selector while rolling mode is selected.
  ///
  /// In en, this message translates to:
  /// **'Each pick follows the session\'s recent sound — it can slowly evolve.'**
  String get autoDjSonicAnchorRollingHint;

  /// Explanation under the anchor selector while locked mode is selected.
  ///
  /// In en, this message translates to:
  /// **'Every pick stays close to the seed song for the whole session.'**
  String get autoDjSonicAnchorLockedHint;

  /// Track context sheet action + playlist-picker title: append this track to a server playlist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get trackAddToPlaylist;

  /// Toast when the playlist add-song request fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add to the playlist.'**
  String get trackAddToPlaylistFailed;

  /// Discover screen action + destination-picker title: build a queue that gradually morphs from the seed track's sound to a chosen destination song.
  ///
  /// In en, this message translates to:
  /// **'Play a path to…'**
  String get discoverPlayPathTo;

  /// Title of the sonic path preview screen (the ordered journey between two tracks).
  ///
  /// In en, this message translates to:
  /// **'Sonic path'**
  String get pathScreenTitle;

  /// Path screen hint when the start seed has no embedding yet.
  ///
  /// In en, this message translates to:
  /// **'The starting song hasn\'t been analyzed yet — wait for the discovery scan or pick another.'**
  String get pathStartNotAnalyzed;

  /// Path screen hint when the destination seed has no embedding yet.
  ///
  /// In en, this message translates to:
  /// **'The destination song hasn\'t been analyzed yet — wait for the discovery scan or pick another.'**
  String get pathEndNotAnalyzed;

  /// Song-picker title when re-choosing the path start endpoint.
  ///
  /// In en, this message translates to:
  /// **'Start song'**
  String get pathStartSong;

  /// Song-picker title when re-choosing the path destination endpoint.
  ///
  /// In en, this message translates to:
  /// **'End song'**
  String get pathEndSong;

  /// Label of the path-length slider (total songs including both endpoints).
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get pathLength;

  /// Tooltip of the refresh button that rebuilds the path with the current endpoints and length.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get pathRegenerate;

  /// Tooltip/toast name of the action saving the generated path as a server playlist.
  ///
  /// In en, this message translates to:
  /// **'Save as playlist'**
  String get pathSaveAsPlaylist;

  /// Explainer line at the top of the sonic path setup stage.
  ///
  /// In en, this message translates to:
  /// **'Pick a start and an end song — the journey between them fills itself.'**
  String get pathSetupHint;

  /// Placeholder in an empty endpoint card before a song is chosen.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get pathNotSet;

  /// Endpoint-card button that fills the card with the currently playing track.
  ///
  /// In en, this message translates to:
  /// **'Use playing song'**
  String get pathUsePlaying;

  /// Endpoint-card button that opens the song search sheet.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get pathSearchSong;

  /// Endpoint-card button that arms browse-to-pick: the user browses the library and the next tapped track fills the card.
  ///
  /// In en, this message translates to:
  /// **'Browse library'**
  String get pathBrowseLibrary;

  /// Primary setup-stage button that fetches the path between the two chosen endpoints.
  ///
  /// In en, this message translates to:
  /// **'Build the journey'**
  String get pathBuild;

  /// Results-stage action that clears the journey and endpoints and returns to a pristine setup stage.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get pathStartOver;

  /// Home-browser banner while browse-to-pick is armed for the start endpoint.
  ///
  /// In en, this message translates to:
  /// **'Pick the start song — tap a track anywhere in the library'**
  String get pathPickBannerStart;

  /// Home-browser banner while browse-to-pick is armed for the end endpoint.
  ///
  /// In en, this message translates to:
  /// **'Pick the end song — tap a track anywhere in the library'**
  String get pathPickBannerEnd;

  /// Toast when Use-playing-song is tapped with an empty player.
  ///
  /// In en, this message translates to:
  /// **'Nothing is playing'**
  String get pathNothingPlaying;

  /// Toast when a browse-to-pick tap lands on a local file or another server's track; names the server the pick must come from.
  ///
  /// In en, this message translates to:
  /// **'Pick a track on {server}'**
  String pathPickOnServer(String server);

  /// Shown on the first-run screen only when the UI language is not English.
  ///
  /// In en, this message translates to:
  /// **'This language was machine-translated and may read awkwardly.'**
  String get welcomeTranslationNote;

  /// Tappable link under the machine-translation note; opens the project on GitHub.
  ///
  /// In en, this message translates to:
  /// **'Help translate mStream'**
  String get welcomeTranslationCta;

  /// App bar title of the first-run setup flow shown after the first server is added.
  ///
  /// In en, this message translates to:
  /// **'Quick setup'**
  String get setupTitle;

  /// Setup flow: dismisses the whole flow without visiting the remaining pages.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get setupSkip;

  /// Setup flow: advances to the next page.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get setupNext;

  /// Setup flow: primary button on the LAST page; closes the flow.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get setupFinish;

  /// Setup flow: returns to the previous page.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get setupBack;

  /// Setup flow page 1 title (accent colour).
  ///
  /// In en, this message translates to:
  /// **'Pick your color'**
  String get setupAccentTitle;

  /// Setup flow page 1 body copy.
  ///
  /// In en, this message translates to:
  /// **'The accent color highlights buttons, sliders and the player controls. Tap one to try it.'**
  String get setupAccentBody;

  /// Setup flow page 3 title (tap behaviour).
  ///
  /// In en, this message translates to:
  /// **'When you tap a song'**
  String get setupPlaybackTitle;

  /// Setup flow final page title (auto-download of queued tracks + how many to keep).
  ///
  /// In en, this message translates to:
  /// **'Keep your queue offline'**
  String get setupOfflineTitle;

  /// Real-audio consent dialog: the reassurance closing the explanation (realAudioDialogBody). Rendered BOLD, so it is a separate string rather than part of that one.
  ///
  /// In en, this message translates to:
  /// **'mStream never uses your microphone.'**
  String get realAudioNoMic;

  /// Shown in the browser body when an opened playlist has no songs.
  ///
  /// In en, this message translates to:
  /// **'Playlist is empty'**
  String get playlistEmpty;

  /// Label on the track sheet's rating row, beside the stars.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get trackRating;

  /// Separator above each disc's tracks in the album view; only shown when an album spans more than one disc.
  ///
  /// In en, this message translates to:
  /// **'Disc {n}'**
  String albumDiscNumber(int n);

  /// Auto DJ empty-queue start chooser
  ///
  /// In en, this message translates to:
  /// **'Start Auto DJ with what?'**
  String get autoDjStartTitle;

  /// Auto DJ empty-queue start chooser
  ///
  /// In en, this message translates to:
  /// **'Nothing is queued, so the DJ needs an opening track. With a queue it just follows what you already have.'**
  String get autoDjStartSubtitle;

  /// Auto DJ empty-queue start chooser
  ///
  /// In en, this message translates to:
  /// **'Surprise me'**
  String get autoDjStartRandom;

  /// Auto DJ empty-queue start chooser
  ///
  /// In en, this message translates to:
  /// **'Pick a random song from the library and build outward from it.'**
  String get autoDjStartRandomSub;

  /// Auto DJ empty-queue start chooser
  ///
  /// In en, this message translates to:
  /// **'Let me choose'**
  String get autoDjStartPick;

  /// Auto DJ empty-queue start chooser
  ///
  /// In en, this message translates to:
  /// **'Open the library and pick the opening track yourself.'**
  String get autoDjStartPickSub;

  /// Auto DJ empty-queue start chooser
  ///
  /// In en, this message translates to:
  /// **'Remember this'**
  String get autoDjStartRemember;

  /// Auto DJ empty-queue start chooser
  ///
  /// In en, this message translates to:
  /// **'Skip this question next time and always start this way.'**
  String get autoDjStartRememberSub;

  /// Auto DJ empty-queue start chooser
  ///
  /// In en, this message translates to:
  /// **'Pick the opening song — tap a track anywhere in the library'**
  String get autoDjStartPickBanner;

  /// Auto DJ empty-queue start chooser
  ///
  /// In en, this message translates to:
  /// **'On an empty queue'**
  String get autoDjOnEmptyQueue;

  /// Auto DJ empty-queue start chooser
  ///
  /// In en, this message translates to:
  /// **'What Auto DJ does when you switch it on with nothing queued.'**
  String get autoDjOnEmptyQueueSub;

  /// Segmented-button label: ask each time
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get autoDjStartAskShort;

  /// Server version / update flags
  ///
  /// In en, this message translates to:
  /// **'Server v{version}'**
  String serverVersionLabel(String version);

  /// Server version / update flags
  ///
  /// In en, this message translates to:
  /// **'Server version unknown'**
  String get serverVersionUnknown;

  /// Server version / update flags
  ///
  /// In en, this message translates to:
  /// **'Update your server'**
  String get serverUpdateUrgent;

  /// Server version / update flags
  ///
  /// In en, this message translates to:
  /// **'Server update available'**
  String get serverUpdateAvailable;

  /// Server version / update flags
  ///
  /// In en, this message translates to:
  /// **'This server is v{version}. Some features need v5.5 or newer and will be unavailable.'**
  String serverTooOldWarning(String version);

  /// Auto DJ server-version gating notes
  ///
  /// In en, this message translates to:
  /// **'BPM continuity, harmonic mixing and the genre filter need a newer server. Update to get them.'**
  String get autoDjNeedsNewerServer;

  /// Auto DJ server-version gating notes
  ///
  /// In en, this message translates to:
  /// **'Needs server 6.15.2 or newer'**
  String get autoDjSonicNeedsNewerServer;

  /// Drawer entry + screen title for adding a torrent to the server's client.
  ///
  /// In en, this message translates to:
  /// **'Add torrent'**
  String get torrentScreenTitle;

  /// Add-torrent empty state when the app has no servers.
  ///
  /// In en, this message translates to:
  /// **'No server is configured.'**
  String get torrentNoServer;

  /// Section label over the server dropdown (shown with 2+ servers).
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get torrentServerLabel;

  /// Section label over the destination-library (vpath) dropdown.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get torrentLibraryLabel;

  /// Shown instead of the library dropdown when the server reports no vpaths.
  ///
  /// In en, this message translates to:
  /// **'No libraries on this server'**
  String get torrentNoLibraries;

  /// Section label over the .torrent-file / magnet inputs.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get torrentSourceLabel;

  /// Button that opens the .torrent file picker.
  ///
  /// In en, this message translates to:
  /// **'Choose .torrent file'**
  String get torrentChooseFile;

  /// Divider word between the file button and the magnet field.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get torrentOr;

  /// Label of the magnet-URI text field.
  ///
  /// In en, this message translates to:
  /// **'Magnet link'**
  String get torrentMagnetLabel;

  /// Error under the magnet field when the pasted text is not a usable magnet link.
  ///
  /// In en, this message translates to:
  /// **'Not a valid magnet link'**
  String get torrentMagnetInvalid;

  /// Snackbar when the picked file fails the bencode check.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is not a .torrent file'**
  String torrentNotATorrent(String name);

  /// Button handing the picked .torrent to another app instead of adding it.
  ///
  /// In en, this message translates to:
  /// **'Open in another app'**
  String get torrentOpenWith;

  /// Snackbar when nothing on the device handles torrents.
  ///
  /// In en, this message translates to:
  /// **'No app on this device can open a .torrent file'**
  String get torrentOpenWithNone;

  /// Snackbar when the hand-off to another app errored.
  ///
  /// In en, this message translates to:
  /// **'Could not hand the torrent to another app'**
  String get torrentOpenWithFailed;

  /// Title of the sheet shown when a torrent is opened with mStream.
  ///
  /// In en, this message translates to:
  /// **'Torrent received'**
  String get torrentIntentTitle;

  /// Body of that sheet, explaining the two choices.
  ///
  /// In en, this message translates to:
  /// **'Add it to a library on your mStream server, or hand it to another app.'**
  String get torrentIntentBody;

  /// Sheet button: keep the torrent and open the Add Torrent screen.
  ///
  /// In en, this message translates to:
  /// **'Add to mStream'**
  String get torrentIntentAdd;

  /// Sheet checkbox suppressing the sheet from now on.
  ///
  /// In en, this message translates to:
  /// **'Always add to mStream, don’t ask again'**
  String get torrentIntentDontAsk;

  /// Settings switch re-enabling the torrent chooser sheet.
  ///
  /// In en, this message translates to:
  /// **'Ask what to do with torrents'**
  String get settingsTorrentAskTitle;

  /// Subtitle for that settings switch.
  ///
  /// In en, this message translates to:
  /// **'When a torrent is opened with mStream, offer to hand it to another app'**
  String get settingsTorrentAskSub;

  /// Settings row opening Android per-app default-handler settings.
  ///
  /// In en, this message translates to:
  /// **'Default app for torrents'**
  String get settingsTorrentDefaultTitle;

  /// Subtitle for that row.
  ///
  /// In en, this message translates to:
  /// **'Opens Android settings, where you can choose which app handles torrents and magnet links'**
  String get settingsTorrentDefaultSub;

  /// Snackbar when no settings screen would open.
  ///
  /// In en, this message translates to:
  /// **'Could not open Android settings'**
  String get settingsTorrentDefaultFailed;

  /// Button asking the server to detect artist/album/year from the .torrent.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect metadata'**
  String get torrentAutoDetect;

  /// Auto-detect button label while the server request runs.
  ///
  /// In en, this message translates to:
  /// **'Detecting…'**
  String get torrentDetecting;

  /// Toast when server auto-detect could not identify the release.
  ///
  /// In en, this message translates to:
  /// **'Not enough metadata — fill the fields in manually'**
  String get torrentDetectNoMetadata;

  /// Toast when server auto-detect succeeded with high confidence.
  ///
  /// In en, this message translates to:
  /// **'Metadata detected'**
  String get torrentDetected;

  /// Toast when server auto-detect returned a low-confidence result.
  ///
  /// In en, this message translates to:
  /// **'Best-effort guess — please verify the fields'**
  String get torrentDetectGuess;

  /// Section label over the artist/album/year fields.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get torrentMetadataLabel;

  /// Label of the artist text field.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get torrentArtistLabel;

  /// Label of the album text field.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get torrentAlbumLabel;

  /// Label of the year text field.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get torrentYearLabel;

  /// Section label over the path-in-library field.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get torrentDestinationLabel;

  /// Label of the destination-path text field.
  ///
  /// In en, this message translates to:
  /// **'Path in library'**
  String get torrentPathLabel;

  /// Destination preview line when no library is selected.
  ///
  /// In en, this message translates to:
  /// **'‹no library›/{path}'**
  String torrentPreviewNoLibrary(String path);

  /// Placeholder tail of the destination preview standing in for the torrent's files.
  ///
  /// In en, this message translates to:
  /// **'‹torrent contents›'**
  String get torrentPreviewContents;

  /// Toggle: rename the torrent's top folder to the destination folder name.
  ///
  /// In en, this message translates to:
  /// **'Rename the torrent\'s root folder'**
  String get torrentRenameRoot;

  /// Subtitle of the rename-root toggle.
  ///
  /// In en, this message translates to:
  /// **'Match the destination folder name'**
  String get torrentRenameRootSub;

  /// Toggle: skip the seed-existing pre-check and download everything.
  ///
  /// In en, this message translates to:
  /// **'Force fresh download'**
  String get torrentForceFresh;

  /// Subtitle of the force-fresh toggle.
  ///
  /// In en, this message translates to:
  /// **'Skip checking for files already on the server'**
  String get torrentForceFreshSub;

  /// Primary submit button.
  ///
  /// In en, this message translates to:
  /// **'Add torrent'**
  String get torrentSubmit;

  /// Submit button label while the add request runs.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get torrentSubmitting;

  /// Fallback reason banner when preflight fails without a server-provided reason.
  ///
  /// In en, this message translates to:
  /// **'Torrents are unavailable on this server.'**
  String get torrentUnavailable;

  /// Toast when submitting without a destination library selected.
  ///
  /// In en, this message translates to:
  /// **'Pick a library'**
  String get torrentPickLibrary;

  /// Toast when neither or both of magnet/file are provided.
  ///
  /// In en, this message translates to:
  /// **'Add a magnet link or a .torrent file (one)'**
  String get torrentOneSource;

  /// Toast when the destination path resolves to nothing.
  ///
  /// In en, this message translates to:
  /// **'Destination path is empty'**
  String get torrentPathEmpty;

  /// Toast when the seed-existing check found all files and started seeding in place.
  ///
  /// In en, this message translates to:
  /// **'Already on disk — seeding it now'**
  String get torrentSeeded;

  /// Toast when the torrent is already loaded in the server's client.
  ///
  /// In en, this message translates to:
  /// **'Already in the torrent client'**
  String get torrentAlreadyInClient;

  /// Toast when the uploaded .torrent cannot be parsed.
  ///
  /// In en, this message translates to:
  /// **'Invalid torrent file'**
  String get torrentInvalidFile;

  /// Toast when the seed-existing pre-check errored; the add continues as a fresh download.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for existing files — downloading fresh'**
  String get torrentSeedCheckFailed;

  /// Title of the partial-match sheet (some of the torrent's files are already on the server).
  ///
  /// In en, this message translates to:
  /// **'Some files already exist'**
  String get torrentPartialTitle;

  /// Explainer under the partial-match sheet title.
  ///
  /// In en, this message translates to:
  /// **'Point the torrent at an existing copy to seed it and download only what is missing.'**
  String get torrentPartialBody;

  /// Per-match line: how many of the torrent's files exist at this location.
  ///
  /// In en, this message translates to:
  /// **'{matched}/{total} files here'**
  String torrentPartialCount(String matched, String total);

  /// Appended to the per-match line: how many files would still download. Leading separator included.
  ///
  /// In en, this message translates to:
  /// **' · {missing} to download'**
  String torrentPartialMissing(String missing);

  /// Partial-match sheet action that ignores the matches and downloads everything.
  ///
  /// In en, this message translates to:
  /// **'Download fresh anyway'**
  String get torrentDownloadFresh;

  /// Toast when a partial match's path has no usable folder segment.
  ///
  /// In en, this message translates to:
  /// **'That match has no folder name — use \'Download fresh\' instead'**
  String get torrentMatchNoFolder;

  /// Toast after a successful torrent add.
  ///
  /// In en, this message translates to:
  /// **'Added \"{name}\"'**
  String torrentAdded(String name);

  /// Toast when the add found the torrent already present.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is already in the client'**
  String torrentDuplicate(String name);

  /// Subtitle under a federated peer in the server picker, naming the server it is reached through.
  ///
  /// In en, this message translates to:
  /// **'via {parent}'**
  String serverPickerVia(String parent);

  /// Title of the note row on a federated peer's section list.
  ///
  /// In en, this message translates to:
  /// **'Read-only server'**
  String get browserFederatedReadOnly;

  /// Subtitle of the note row explaining what a federated peer cannot do.
  ///
  /// In en, this message translates to:
  /// **'Playlists and ratings stay on your own'**
  String get browserFederatedReadOnlyNote;

  /// No description provided for @federatedShareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Tracks on a shared server can\'t be shared from here — they live in someone else\'s library.'**
  String get federatedShareUnavailable;

  /// No description provided for @federatedForget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get federatedForget;

  /// No description provided for @federatedHide.
  ///
  /// In en, this message translates to:
  /// **'Hide from the picker'**
  String get federatedHide;

  /// No description provided for @federatedShow.
  ///
  /// In en, this message translates to:
  /// **'Show in the picker'**
  String get federatedShow;

  /// No description provided for @federatedNoLongerListed.
  ///
  /// In en, this message translates to:
  /// **'No longer shared by {parent}'**
  String federatedNoLongerListed(String parent);

  /// Title of the Federation screen (libraries shared between servers).
  ///
  /// In en, this message translates to:
  /// **'Federation'**
  String get federationTitle;

  /// Federation status line when the endpoint is up and reachable.
  ///
  /// In en, this message translates to:
  /// **'On · connected to relay'**
  String get federationStatusOn;

  /// Federation status line while the endpoint is still reaching its relay.
  ///
  /// In en, this message translates to:
  /// **'On · connecting…'**
  String get federationStatusConnecting;

  /// Federation status line when the feature is switched off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get federationStatusOff;

  /// Federation status line when the server cannot run the iroh component.
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform'**
  String get federationStatusUnavailable;

  /// Section header: the peers whose libraries this server can read.
  ///
  /// In en, this message translates to:
  /// **'Shared with you'**
  String get federationSharedWithYou;

  /// Section header: pairing requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get federationRequestsSection;

  /// Section header: the tickets this admin minted.
  ///
  /// In en, this message translates to:
  /// **'Your shared libraries'**
  String get federationYourSharedLibraries;

  /// Row and screen title: add a friend's server by ticket.
  ///
  /// In en, this message translates to:
  /// **'Add a peer'**
  String get federationAddPeer;

  /// Primary action and screen title: mint a ticket for one of this server's libraries.
  ///
  /// In en, this message translates to:
  /// **'Share a library'**
  String get federationShareLibrary;

  /// Empty state for the Shared with you section.
  ///
  /// In en, this message translates to:
  /// **'Nothing is shared with this server yet.'**
  String get federationNoPeersYet;

  /// Empty state for the tickets section (admin).
  ///
  /// In en, this message translates to:
  /// **'No tickets yet — share a library to mint one.'**
  String get federationNoKeysYet;

  /// Empty state for the requests section when the inbox is open.
  ///
  /// In en, this message translates to:
  /// **'No requests yet — servers on the discovery network can find you here.'**
  String get federationNoRequests;

  /// Banner title when a federation ticket is found on the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Ticket on your clipboard'**
  String get federationClipboardTicket;

  /// One-line preview of a ticket: the server name and the libraries it grants.
  ///
  /// In en, this message translates to:
  /// **'{name} · shares {libraries}'**
  String federationTicketPreview(String name, String libraries);

  /// One-line preview of a ticket that lists no libraries.
  ///
  /// In en, this message translates to:
  /// **'{name}'**
  String federationTicketPreviewNoLibraries(String name);

  /// Stand-in for a ticket or request without a server name.
  ///
  /// In en, this message translates to:
  /// **'Unnamed server'**
  String get federationUnnamedServer;

  /// Button: add the peer.
  ///
  /// In en, this message translates to:
  /// **'Add peer'**
  String get federationAddPeerAction;

  /// Peer state: its tunnel is up.
  ///
  /// In en, this message translates to:
  /// **'live'**
  String get federationPeerLive;

  /// Peer state: its tunnel is still dialing.
  ///
  /// In en, this message translates to:
  /// **'connecting…'**
  String get federationPeerConnecting;

  /// Peer transport: this phone dials the peer itself.
  ///
  /// In en, this message translates to:
  /// **'direct tunnel'**
  String get federationPeerDirectTunnel;

  /// Peer transport: reached through the parent server's proxy.
  ///
  /// In en, this message translates to:
  /// **'via {parent}'**
  String federationPeerViaParent(String parent);

  /// Peer transport: reached through the parent's Quick Connect tunnel.
  ///
  /// In en, this message translates to:
  /// **'via {parent}\'s tunnel'**
  String federationPeerViaTunnel(String parent);

  /// Peer state: the parent stopped listing it.
  ///
  /// In en, this message translates to:
  /// **'no longer shared'**
  String get federationPeerMissing;

  /// Peer state: the user hid it from the server picker.
  ///
  /// In en, this message translates to:
  /// **'hidden from the picker'**
  String get federationPeerHidden;

  /// Note for a non-admin user on the Federation screen.
  ///
  /// In en, this message translates to:
  /// **'Sharing is an admin job. Minting tickets, adding peers and answering pairing requests need an admin sign-in on {server} — the same one that opens the admin panel.'**
  String federationMemberNote(String server);

  /// Note when the admin API is restricted to the local network.
  ///
  /// In en, this message translates to:
  /// **'This server only takes admin calls from its own network. Connect from home to manage sharing here.'**
  String get federationRestrictedNote;

  /// Note when the admin API is disabled server-side.
  ///
  /// In en, this message translates to:
  /// **'The admin API is switched off on this server.'**
  String get federationDisabledNote;

  /// Note when the server lacks the federation admin routes.
  ///
  /// In en, this message translates to:
  /// **'This server is too old to manage federation from the app. Update mStream.'**
  String get federationUnsupportedNote;

  /// Error line when the federation screen cannot load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server.'**
  String get federationLoadFailed;

  /// Button: retry loading.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get federationRetry;

  /// Headline of the Federation screen while the feature is off.
  ///
  /// In en, this message translates to:
  /// **'Share libraries with friends\' servers'**
  String get federationOffTitle;

  /// Explainer under the headline while federation is off.
  ///
  /// In en, this message translates to:
  /// **'Pair two mStream servers to read each other\'s music. Tickets are what you swap — text one, scan one, paste one.'**
  String get federationOffBody;

  /// Selling point 1 title (federation off).
  ///
  /// In en, this message translates to:
  /// **'Read-only, end-to-end encrypted'**
  String get federationOffPoint1Title;

  /// Selling point 1 body.
  ///
  /// In en, this message translates to:
  /// **'Playlists and ratings never leave your server'**
  String get federationOffPoint1Body;

  /// Selling point 2 title.
  ///
  /// In en, this message translates to:
  /// **'No port forwarding or DNS'**
  String get federationOffPoint2Title;

  /// Selling point 2 body.
  ///
  /// In en, this message translates to:
  /// **'iroh finds a path — direct when it can, relay when it must'**
  String get federationOffPoint2Body;

  /// Selling point 3 title.
  ///
  /// In en, this message translates to:
  /// **'Tickets you can revoke'**
  String get federationOffPoint3Title;

  /// Selling point 3 body.
  ///
  /// In en, this message translates to:
  /// **'Each one is claimed once and cut off any time'**
  String get federationOffPoint3Body;

  /// Note under the selling points for admins.
  ///
  /// In en, this message translates to:
  /// **'Only the server admin can turn this on.'**
  String get federationOffAdminOnly;

  /// Note for a non-admin when federation is off.
  ///
  /// In en, this message translates to:
  /// **'Federation is off on {server}. Its admin can turn it on.'**
  String federationOffMemberNote(String server);

  /// Button: enable federation.
  ///
  /// In en, this message translates to:
  /// **'Turn on federation'**
  String get federationTurnOn;

  /// Note when the server platform cannot run federation.
  ///
  /// In en, this message translates to:
  /// **'The iroh component has no build for this server\'s OS/CPU, so the federation endpoint can\'t run here.'**
  String get federationUnavailableNote;

  /// Toast after enabling federation.
  ///
  /// In en, this message translates to:
  /// **'Federation is on'**
  String get federationTurnedOn;

  /// Toast after disabling federation.
  ///
  /// In en, this message translates to:
  /// **'Federation is off'**
  String get federationTurnedOff;

  /// Toast when the on/off switch fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the federation setting.'**
  String get federationToggleFailed;

  /// Title of the federation settings screen.
  ///
  /// In en, this message translates to:
  /// **'Federation settings'**
  String get federationSettingsTitle;

  /// Subtitle of the federation on/off switch.
  ///
  /// In en, this message translates to:
  /// **'Peer-to-peer, end-to-end encrypted. No port forwarding, no DNS.'**
  String get federationSwitchSubtitle;

  /// Section header: endpoint status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get federationStatusSection;

  /// Status row: the endpoint reached its relay.
  ///
  /// In en, this message translates to:
  /// **'Connected to relay'**
  String get federationConnectedRelay;

  /// Status row: federation is on but the endpoint is down.
  ///
  /// In en, this message translates to:
  /// **'Endpoint not running'**
  String get federationNotRunning;

  /// Label of the server's iroh endpoint id.
  ///
  /// In en, this message translates to:
  /// **'Endpoint id'**
  String get federationEndpointId;

  /// Toast after copying the endpoint id.
  ///
  /// In en, this message translates to:
  /// **'Endpoint id copied'**
  String get federationEndpointCopied;

  /// Section header in settings: the requests inbox switch.
  ///
  /// In en, this message translates to:
  /// **'Pairing requests'**
  String get federationPairingRequestsSection;

  /// Switch: let discovery peers send pairing requests.
  ///
  /// In en, this message translates to:
  /// **'Accept requests from the discovery network'**
  String get federationRequestsInboxTitle;

  /// Subtitle of the requests inbox switch.
  ///
  /// In en, this message translates to:
  /// **'Off by default. When off, new requests are refused at the transport; answers to your own requests still arrive.'**
  String get federationRequestsInboxSubtitle;

  /// Toast when the inbox switch fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the requests inbox.'**
  String get federationInboxFailed;

  /// Section header: the limit defaults from the server config.
  ///
  /// In en, this message translates to:
  /// **'Defaults for new tickets'**
  String get federationDefaultsSection;

  /// Subtitle under the limit defaults row.
  ///
  /// In en, this message translates to:
  /// **'From the server config — every ticket can change them'**
  String get federationDefaultsNote;

  /// Warning note in settings.
  ///
  /// In en, this message translates to:
  /// **'Turning federation off drops every peer bridge and hides your tickets until it is back on. Peers keep their tickets.'**
  String get federationOffWarning;

  /// Request row title (inbound).
  ///
  /// In en, this message translates to:
  /// **'{name} wants to pair'**
  String federationRequestWantsToPair(String name);

  /// Request row title (outbound).
  ///
  /// In en, this message translates to:
  /// **'Request to {name}'**
  String federationRequestToName(String name);

  /// Request row: what the other server offers.
  ///
  /// In en, this message translates to:
  /// **'Offers {libraries}'**
  String federationRequestOffers(String libraries);

  /// Request row: the other server offers no library.
  ///
  /// In en, this message translates to:
  /// **'Offers nothing'**
  String get federationRequestOffersNothing;

  /// Outbound request row: what this server offered.
  ///
  /// In en, this message translates to:
  /// **'You offered {libraries}'**
  String federationRequestYouOffered(String libraries);

  /// Outbound request row: nothing offered.
  ///
  /// In en, this message translates to:
  /// **'You offered nothing'**
  String get federationRequestYouOfferedNothing;

  /// Request state chip: the request is being delivered.
  ///
  /// In en, this message translates to:
  /// **'sending…'**
  String get federationReqSending;

  /// Request state chip: delivered, no answer yet.
  ///
  /// In en, this message translates to:
  /// **'waiting on them'**
  String get federationReqWaiting;

  /// Request state chip: granting our share after they accepted.
  ///
  /// In en, this message translates to:
  /// **'sharing back…'**
  String get federationReqSharingBack;

  /// Request state chip: an inbound request awaiting the admin.
  ///
  /// In en, this message translates to:
  /// **'needs your answer'**
  String get federationReqNeedsAnswer;

  /// Request state chip: accepted, the ticket is being sent.
  ///
  /// In en, this message translates to:
  /// **'sending your ticket…'**
  String get federationReqSendingTicket;

  /// Request state chip: waiting for the other side's grant.
  ///
  /// In en, this message translates to:
  /// **'waiting on their share'**
  String get federationReqWaitingShare;

  /// Request state chip: they declined.
  ///
  /// In en, this message translates to:
  /// **'declined'**
  String get federationReqDeclined;

  /// Request state chip: this admin declined.
  ///
  /// In en, this message translates to:
  /// **'you declined'**
  String get federationReqYouDeclined;

  /// Request state chip: refused at the transport.
  ///
  /// In en, this message translates to:
  /// **'their inbox is closed'**
  String get federationReqInboxClosed;

  /// Request state chip: completed.
  ///
  /// In en, this message translates to:
  /// **'federated'**
  String get federationReqFederated;

  /// Request state chip: cancelled.
  ///
  /// In en, this message translates to:
  /// **'withdrawn'**
  String get federationReqWithdrawn;

  /// Request state chip: expired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get federationReqExpired;

  /// Button: open the accept screen for a request.
  ///
  /// In en, this message translates to:
  /// **'Accept…'**
  String get federationAccept;

  /// Button: accept the request and share back.
  ///
  /// In en, this message translates to:
  /// **'Accept & share'**
  String get federationAcceptAndShare;

  /// Button: reject a request.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get federationDecline;

  /// Button: withdraw an outbound request.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get federationCancelRequest;

  /// Button: remove a finished request from the list.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get federationDismiss;

  /// Title of the pairing request screen.
  ///
  /// In en, this message translates to:
  /// **'Pairing request'**
  String get federationRequestTitle;

  /// Line under a request: when it arrived.
  ///
  /// In en, this message translates to:
  /// **'Received {ago} over the discovery network'**
  String federationRequestReceived(String ago);

  /// Line under an outbound request: when it was sent.
  ///
  /// In en, this message translates to:
  /// **'Sent {ago} over the discovery network'**
  String federationRequestSent(String ago);

  /// Section header: libraries to share in return.
  ///
  /// In en, this message translates to:
  /// **'Share back'**
  String get federationShareBack;

  /// Note under the share-back list.
  ///
  /// In en, this message translates to:
  /// **'Nothing changes hands until you accept. They get read-only access to the libraries you tick — at least one.'**
  String get federationShareBackNote;

  /// Section header: the limits the accepted peer will get.
  ///
  /// In en, this message translates to:
  /// **'Their limits'**
  String get federationTheirLimits;

  /// Link: edit the limits.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get federationChange;

  /// Note under a declined inbound request.
  ///
  /// In en, this message translates to:
  /// **'Requests from this server are ignored for 7 days'**
  String get federationRequestIgnored;

  /// Toast after accepting a request.
  ///
  /// In en, this message translates to:
  /// **'Request accepted'**
  String get federationRequestAccepted;

  /// Toast after declining a request.
  ///
  /// In en, this message translates to:
  /// **'Request declined'**
  String get federationRequestDeclined;

  /// Toast after cancelling an outbound request.
  ///
  /// In en, this message translates to:
  /// **'Request withdrawn'**
  String get federationRequestCancelled;

  /// Toast when a request action fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the request.'**
  String get federationRequestActionFailed;

  /// Field label: the name of the person the ticket is for.
  ///
  /// In en, this message translates to:
  /// **'Who is this for?'**
  String get federationTicketNameLabel;

  /// Hint under the ticket name field.
  ///
  /// In en, this message translates to:
  /// **'Only you see this name — it labels the ticket in your list.'**
  String get federationTicketNameHint;

  /// Section header: libraries to grant.
  ///
  /// In en, this message translates to:
  /// **'Libraries they can read'**
  String get federationLibrariesTheyCanRead;

  /// Section header: bandwidth limits.
  ///
  /// In en, this message translates to:
  /// **'Limits'**
  String get federationLimitsSection;

  /// Link: switch the limits editor to numeric fields.
  ///
  /// In en, this message translates to:
  /// **'Exact numbers'**
  String get federationExactNumbers;

  /// Link: switch the limits editor back to preset chips.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get federationPresets;

  /// Limit label: bitrate cap.
  ///
  /// In en, this message translates to:
  /// **'Stream rate'**
  String get federationLimitStreamRate;

  /// Limit label: daily quota.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get federationLimitPerDay;

  /// Limit label: concurrent streams.
  ///
  /// In en, this message translates to:
  /// **'Streams at once'**
  String get federationLimitStreams;

  /// Limit label: ticket expiry.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get federationLimitExpires;

  /// Chip: no limit.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get federationUnlimited;

  /// Chip: the ticket never expires.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get federationNever;

  /// Chip: expiry in N days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String federationDays(int count);

  /// Chip: expiry in one year.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get federationOneYear;

  /// Bitrate in kilobits per second.
  ///
  /// In en, this message translates to:
  /// **'{n} kbps'**
  String federationKbps(int n);

  /// Bitrate in megabits per second.
  ///
  /// In en, this message translates to:
  /// **'{n} Mbps'**
  String federationMbps(int n);

  /// Daily quota in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{n} MB a day'**
  String federationMbPerDay(int n);

  /// Daily quota in gigabytes.
  ///
  /// In en, this message translates to:
  /// **'{n} GB a day'**
  String federationGbPerDay(int n);

  /// Concurrent stream cap.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stream} other{{count} streams}}'**
  String federationStreamsCount(int count);

  /// Ticket has no expiry.
  ///
  /// In en, this message translates to:
  /// **'never expires'**
  String get federationNeverExpires;

  /// Ticket expiry, relative or dated.
  ///
  /// In en, this message translates to:
  /// **'expires {when}'**
  String federationExpiresIn(String when);

  /// Ticket past its expiry.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get federationExpired;

  /// Relative future time in days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 day} other{in {count} days}}'**
  String federationInDays(int count);

  /// Relative future time in hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 hour} other{in {count} hours}}'**
  String federationInHours(int count);

  /// Numeric field label.
  ///
  /// In en, this message translates to:
  /// **'Stream rate (kbps, 0 = unlimited)'**
  String get federationStreamRateField;

  /// Numeric field label.
  ///
  /// In en, this message translates to:
  /// **'Daily quota (MB, 0 = unlimited)'**
  String get federationPerDayField;

  /// Numeric field label.
  ///
  /// In en, this message translates to:
  /// **'Max streams (0 = unlimited)'**
  String get federationStreamsField;

  /// Numeric field label.
  ///
  /// In en, this message translates to:
  /// **'Expires in days (0 = never)'**
  String get federationExpiresField;

  /// Button: mint the ticket.
  ///
  /// In en, this message translates to:
  /// **'Create ticket'**
  String get federationCreateTicket;

  /// Toast when minting fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the ticket.'**
  String get federationMintFailed;

  /// Empty state of the library list in the mint form.
  ///
  /// In en, this message translates to:
  /// **'This server has no libraries to share.'**
  String get federationNoLibraries;

  /// Title of the ticket screen.
  ///
  /// In en, this message translates to:
  /// **'Your ticket'**
  String get federationTicketTitle;

  /// Ticket card title.
  ///
  /// In en, this message translates to:
  /// **'Ticket for {name}'**
  String federationTicketFor(String name);

  /// Ticket card: the libraries it grants.
  ///
  /// In en, this message translates to:
  /// **'Reads {libraries}'**
  String federationTicketReads(String libraries);

  /// Caption under the QR code.
  ///
  /// In en, this message translates to:
  /// **'Same room? Let them scan this.'**
  String get federationTicketQrHint;

  /// Credential warning on the ticket screen.
  ///
  /// In en, this message translates to:
  /// **'Anyone holding this ticket can read those libraries until it is claimed or revoked. Send it over a private channel — the first server to use it claims it.'**
  String get federationTicketWarning;

  /// Button: copy the ticket text.
  ///
  /// In en, this message translates to:
  /// **'Copy ticket'**
  String get federationCopyTicket;

  /// Toast after copying the ticket.
  ///
  /// In en, this message translates to:
  /// **'Ticket copied'**
  String get federationTicketCopied;

  /// Primary button: open the share sheet with the ticket.
  ///
  /// In en, this message translates to:
  /// **'Send by text…'**
  String get federationSendByText;

  /// Note at the bottom of the ticket screen.
  ///
  /// In en, this message translates to:
  /// **'Revoke it any time from Federation. If they reinstall, Reset claim lets the ticket be claimed again.'**
  String get federationTicketRevokeNote;

  /// Note when a key has no ticket because the endpoint is down.
  ///
  /// In en, this message translates to:
  /// **'The federation endpoint isn\'t running, so there is no ticket to send yet. Turn federation on and come back.'**
  String get federationTicketNotRunning;

  /// The text message composed around a ticket for the share sheet.
  ///
  /// In en, this message translates to:
  /// **'I\'m sharing my mStream music library with you — {libraries}, read-only. In the mStream app open Federation → Add a peer and paste this ticket:\n\n{ticket}\n\nIt works once — I can revoke it any time.'**
  String federationShareMessage(String libraries, String ticket);

  /// Subject line for the share sheet.
  ///
  /// In en, this message translates to:
  /// **'mStream federation ticket'**
  String get federationShareSubject;

  /// Key state: the ticket was redeemed.
  ///
  /// In en, this message translates to:
  /// **'claimed'**
  String get federationKeyClaimed;

  /// Key state: the ticket has not been redeemed.
  ///
  /// In en, this message translates to:
  /// **'not claimed yet'**
  String get federationKeyNotClaimed;

  /// Bytes served to a key today.
  ///
  /// In en, this message translates to:
  /// **'{amount} today'**
  String federationKeyTodayUsage(String amount);

  /// Key row: last use.
  ///
  /// In en, this message translates to:
  /// **'Last used {ago}'**
  String federationKeyLastUsed(String ago);

  /// Key row: never used.
  ///
  /// In en, this message translates to:
  /// **'Never used'**
  String get federationKeyNeverUsed;

  /// Key row: when the ticket was redeemed.
  ///
  /// In en, this message translates to:
  /// **'Claimed {ago}'**
  String federationKeyClaimedAgo(String ago);

  /// Button: let the ticket be claimed again.
  ///
  /// In en, this message translates to:
  /// **'Reset claim'**
  String get federationResetBinding;

  /// Subtitle of the reset-claim row.
  ///
  /// In en, this message translates to:
  /// **'Friend reinstalled? Let the ticket be claimed again.'**
  String get federationResetBindingNote;

  /// Toast after resetting a key's binding.
  ///
  /// In en, this message translates to:
  /// **'The ticket can be claimed again'**
  String get federationBindingReset;

  /// Button: revoke a ticket.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get federationRevoke;

  /// Confirm dialog before revoking.
  ///
  /// In en, this message translates to:
  /// **'Revoke this ticket? {name} loses access right away.'**
  String federationRevokeConfirm(String name);

  /// Toast after revoking.
  ///
  /// In en, this message translates to:
  /// **'Ticket revoked'**
  String get federationRevoked;

  /// Button: save edited limits.
  ///
  /// In en, this message translates to:
  /// **'Save limits'**
  String get federationSaveLimits;

  /// Toast after saving limits.
  ///
  /// In en, this message translates to:
  /// **'Limits saved'**
  String get federationLimitsSaved;

  /// Toast when saving limits fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the limits.'**
  String get federationLimitsFailed;

  /// Short button: send the ticket.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get federationSend;

  /// Title of the key detail screen.
  ///
  /// In en, this message translates to:
  /// **'Shared library'**
  String get federationKeyTitle;

  /// Generic failure toast with the server's message.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work: {error}'**
  String federationActionFailed(String error);

  /// Field label: the pasted ticket.
  ///
  /// In en, this message translates to:
  /// **'Their ticket'**
  String get federationTheirTicket;

  /// Button: open the scanner.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get federationScanQr;

  /// Title of the QR scanner for tickets.
  ///
  /// In en, this message translates to:
  /// **'Scan a federation ticket'**
  String get federationScannerTitle;

  /// Button: paste from the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get federationPaste;

  /// Hint after pasting a ticket.
  ///
  /// In en, this message translates to:
  /// **'Pasted from your clipboard.'**
  String get federationTicketPasted;

  /// Error under the ticket field.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a federation ticket.'**
  String get federationNotATicket;

  /// Error for a ticket with a newer version.
  ///
  /// In en, this message translates to:
  /// **'This ticket comes from a newer mStream than this app understands.'**
  String get federationTicketTooNew;

  /// Error for an expired ticket.
  ///
  /// In en, this message translates to:
  /// **'This ticket has expired.'**
  String get federationTicketExpiredNote;

  /// Field label: optional peer name.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get federationDisplayName;

  /// Hint under the display name field.
  ///
  /// In en, this message translates to:
  /// **'Optional — how it shows in your server picker.'**
  String get federationDisplayNameHint;

  /// Preview: libraries the ticket grants.
  ///
  /// In en, this message translates to:
  /// **'Shares {libraries}'**
  String federationSharesLibraries(String libraries);

  /// Preview: the ticket names no libraries.
  ///
  /// In en, this message translates to:
  /// **'Libraries not listed on the ticket'**
  String get federationSharesUnknown;

  /// Preview: ticket expiry.
  ///
  /// In en, this message translates to:
  /// **'valid until {date}'**
  String federationValidUntil(String date);

  /// Explainer row title on the add-peer screen.
  ///
  /// In en, this message translates to:
  /// **'Shows up under {server}'**
  String federationAddPeerShowsUnder(String server);

  /// Explainer row body: how the peer will appear.
  ///
  /// In en, this message translates to:
  /// **'Read-only · {branch} {name} in the picker'**
  String federationAddPeerReadOnly(String branch, String name);

  /// Explainer row title.
  ///
  /// In en, this message translates to:
  /// **'Your server dials it over iroh'**
  String get federationAddPeerDials;

  /// Explainer row body.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted · no port forwarding'**
  String get federationAddPeerEncrypted;

  /// Note at the bottom of the add-peer screen.
  ///
  /// In en, this message translates to:
  /// **'No ticket yet? Ask them to text you one.'**
  String get federationAddPeerNoTicket;

  /// Toast after adding a peer.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String federationPeerAdded(String name);

  /// Toast when adding fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the peer.'**
  String get federationAddPeerFailed;

  /// Error when the ticket was already used here.
  ///
  /// In en, this message translates to:
  /// **'This ticket is already added as a peer.'**
  String get federationPeerAlreadyAdded;

  /// Section header on the peer screen.
  ///
  /// In en, this message translates to:
  /// **'Libraries you can read'**
  String get federationLibrariesYouCanRead;

  /// Section header on the peer screen.
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get federationDiscoverySection;

  /// Switch: send discovery queries to this peer.
  ///
  /// In en, this message translates to:
  /// **'Ask this peer for similar music'**
  String get federationAskPeerSimilar;

  /// Subtitle of the discovery switch.
  ///
  /// In en, this message translates to:
  /// **'Sends what you\'re listening to — to this peer only.'**
  String get federationAskPeerSimilarNote;

  /// Section header on the peer screen.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ'**
  String get federationAutoDjSection;

  /// Row: the peer is a fan-out candidate.
  ///
  /// In en, this message translates to:
  /// **'Takes part in multi-server Auto DJ'**
  String get federationAutoDjParticipates;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Answers with its own library when the DJ is on'**
  String get federationAutoDjParticipatesNote;

  /// Row: the peer cannot join the DJ fan-out.
  ///
  /// In en, this message translates to:
  /// **'Not an Auto DJ candidate'**
  String get federationAutoDjNotCandidate;

  /// Row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Needs a server that can answer sonic picks'**
  String get federationAutoDjNotCandidateNote;

  /// Button: test the connection to a peer.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get federationTest;

  /// Button while a test runs.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get federationTesting;

  /// Result: the peer answered.
  ///
  /// In en, this message translates to:
  /// **'Reachable'**
  String get federationTestOk;

  /// Result: the peer did not answer.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach it: {error}'**
  String federationTestFailed(String error);

  /// Peer status: when the server last tested it.
  ///
  /// In en, this message translates to:
  /// **'Checked {ago}'**
  String federationCheckedAgo(String ago);

  /// Peer status: no test yet.
  ///
  /// In en, this message translates to:
  /// **'Never tested'**
  String get federationNeverTested;

  /// Peer status: last successful contact.
  ///
  /// In en, this message translates to:
  /// **'Last seen {ago}'**
  String federationLastSeen(String ago);

  /// Primary button on the peer screen.
  ///
  /// In en, this message translates to:
  /// **'Browse this library'**
  String get federationBrowseLibrary;

  /// Button: remove a peer from the server.
  ///
  /// In en, this message translates to:
  /// **'Remove peer'**
  String get federationRemovePeer;

  /// Confirm dialog before removing a peer.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}? Tracks queued from it stop playing.'**
  String federationRemovePeerConfirm(String name);

  /// Toast after removing a peer.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String federationPeerRemoved(String name);

  /// Switch: unhide the peer.
  ///
  /// In en, this message translates to:
  /// **'Show in server picker'**
  String get federationShowInPicker;

  /// Subtitle of the show-in-picker switch.
  ///
  /// In en, this message translates to:
  /// **'Hidden peers keep playing what you queued from them.'**
  String get federationShowInPickerNote;

  /// Note under the libraries list on the peer screen.
  ///
  /// In en, this message translates to:
  /// **'Read-only — playlists and ratings stay on your own server.'**
  String get federationPeerReadOnlyNote;

  /// Empty state of the peer's library list.
  ///
  /// In en, this message translates to:
  /// **'Not listed yet — open it once to load its libraries.'**
  String get federationPeerLibrariesUnknown;

  /// Peer transport line.
  ///
  /// In en, this message translates to:
  /// **'Direct tunnel from this phone'**
  String get federationTransportDirect;

  /// Peer transport secondary line.
  ///
  /// In en, this message translates to:
  /// **'Relay standing by'**
  String get federationTransportRelay;

  /// Peer transport line: proxied by the parent.
  ///
  /// In en, this message translates to:
  /// **'Through {parent}'**
  String federationTransportViaParent(String parent);

  /// Peer transport line: proxied over the parent's tunnel.
  ///
  /// In en, this message translates to:
  /// **'Through {parent} over its tunnel'**
  String federationTransportViaParentTunnel(String parent);

  /// Toast when the discovery switch fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the discovery setting.'**
  String get federationDiscoveryFailed;

  /// Relative time: under two minutes.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get agoJustNow;

  /// Relative time in minutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min ago} other{{count} min ago}}'**
  String agoMinutes(int count);

  /// Relative time in hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 h ago} other{{count} h ago}}'**
  String agoHours(int count);

  /// Relative time in days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String agoDays(int count);

  /// Home card: the discovery network screen.
  ///
  /// In en, this message translates to:
  /// **'P2P Network'**
  String get browserP2pNetwork;

  /// P2P card subtext: the server is on the discovery network.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get browserP2pOn;

  /// P2P card subtext: the discovery network is off on this server.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get browserP2pOff;

  /// Title of the P2P Network screen.
  ///
  /// In en, this message translates to:
  /// **'P2P Network'**
  String get p2pTitle;

  /// Mesh state: at least one neighbor.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get p2pStatusConnected;

  /// Mesh neighbor count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 neighbor} other{{count} neighbors}}'**
  String p2pNeighborsCount(int count);

  /// Status line: the name this server announces.
  ///
  /// In en, this message translates to:
  /// **'announcing as {name}'**
  String p2pAnnouncingAs(String name);

  /// Mesh state: joined, no neighbor yet.
  ///
  /// In en, this message translates to:
  /// **'Joined · waiting for neighbors'**
  String get p2pStatusSearching;

  /// Mesh state: crash recovery is replaying the sidecar.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting · attempt {n}'**
  String p2pStatusReconnecting(int n);

  /// Mesh state: enabled but the sidecar has not joined.
  ///
  /// In en, this message translates to:
  /// **'Not joined yet'**
  String get p2pStatusNotJoined;

  /// Network state: disabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get p2pStatusOff;

  /// Network state: no sidecar binary.
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform'**
  String get p2pStatusUnavailable;

  /// Stat tile label.
  ///
  /// In en, this message translates to:
  /// **'mesh neighbors'**
  String get p2pStatNeighbors;

  /// Stat tile detail.
  ///
  /// In en, this message translates to:
  /// **'live gossip links'**
  String get p2pStatNeighborsSub;

  /// Stat tile label.
  ///
  /// In en, this message translates to:
  /// **'servers known'**
  String get p2pStatKnown;

  /// Stat tile detail.
  ///
  /// In en, this message translates to:
  /// **'{hidden} hidden · {blocked} blocked'**
  String p2pStatKnownSub(int hidden, int blocked);

  /// Stat tile label.
  ///
  /// In en, this message translates to:
  /// **'snapshots held'**
  String get p2pStatHeld;

  /// Stat tile value: held snapshots out of the auto-fetch count.
  ///
  /// In en, this message translates to:
  /// **'{held} of {max}'**
  String p2pStatHeldOf(int held, int max);

  /// Stat tile detail: snapshot storage used of the cap.
  ///
  /// In en, this message translates to:
  /// **'{used} of {cap}'**
  String p2pStatStorage(String used, String cap);

  /// Stat tile label.
  ///
  /// In en, this message translates to:
  /// **'peer tracks'**
  String get p2pStatTracks;

  /// Stat tile detail.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{searchable, 1 library} other{searchable, {count} libraries}}'**
  String p2pStatTracksSub(int count);

  /// Activity screen title and the link to it.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get p2pActivity;

  /// Activity screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'newest first · held in memory'**
  String get p2pActivitySubtitle;

  /// Activity empty state.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet — mesh joins, snapshot fetches, rotation and recovery events land here as they happen.'**
  String get p2pActivityEmpty;

  /// Note under the activity list.
  ///
  /// In en, this message translates to:
  /// **'The full history lives in the server logs.'**
  String get p2pActivityNote;

  /// Section header: the listener payoff.
  ///
  /// In en, this message translates to:
  /// **'From the network'**
  String get p2pFromNetwork;

  /// Row: opens Discover's network section.
  ///
  /// In en, this message translates to:
  /// **'Find similar music on the network'**
  String get p2pFindSimilar;

  /// Row subtitle. Retitled "More like this" by the Discover page plan §2.12: the history-seeded page alone is called "Discover" (discoverPageTitle).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Opens More like this for the track playing now · leads from 1 downloaded library} other{Opens More like this for the track playing now · leads from {count} downloaded libraries}}'**
  String p2pFindSimilarSub(int count);

  /// Row subtitle when nothing is playing. Retitled "More like this" by the Discover page plan §2.12: the history-seeded page alone is called "Discover" (discoverPageTitle).
  ///
  /// In en, this message translates to:
  /// **'Play something first — More like this follows the current track'**
  String get p2pFindSimilarNothingPlaying;

  /// Subtitle of the new-artists-only switch.
  ///
  /// In en, this message translates to:
  /// **'Hide leads for artists already in this library'**
  String get p2pNewArtistsOnlySub;

  /// Section header (admin).
  ///
  /// In en, this message translates to:
  /// **'Servers you follow'**
  String get p2pServersYouFollow;

  /// Section header (member).
  ///
  /// In en, this message translates to:
  /// **'Servers on the network'**
  String get p2pServersOnNetwork;

  /// Catalog empty state.
  ///
  /// In en, this message translates to:
  /// **'No servers heard yet — befriend one with a friend\'s ticket, or give gossip a minute.'**
  String get p2pNoServersYet;

  /// Footer: hidden incompatible servers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 server hidden — incompatible model} other{{count} servers hidden — incompatible model}}'**
  String p2pHiddenIncompatible(int count);

  /// Link: show hidden servers.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get p2pShow;

  /// Link: hide incompatible servers again.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get p2pHide;

  /// Row and screen title: join a friend's server by ticket.
  ///
  /// In en, this message translates to:
  /// **'Befriend a server'**
  String get p2pBefriend;

  /// Peer state.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get p2pOnline;

  /// Peer state with the last-heard time.
  ///
  /// In en, this message translates to:
  /// **'offline {ago}'**
  String p2pOfflineFor(String ago);

  /// Track count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String p2pTracksCount(int count);

  /// Seeder count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seeder} other{{count} seeders}}'**
  String p2pSeedersCount(int count);

  /// Snapshot chip.
  ///
  /// In en, this message translates to:
  /// **'downloaded'**
  String get p2pChipDownloaded;

  /// Snapshot chip.
  ///
  /// In en, this message translates to:
  /// **'update available'**
  String get p2pChipUpdate;

  /// Snapshot chip.
  ///
  /// In en, this message translates to:
  /// **'not downloaded'**
  String get p2pChipNotDownloaded;

  /// Snapshot chip.
  ///
  /// In en, this message translates to:
  /// **'pinned'**
  String get p2pChipPinned;

  /// Peer chip.
  ///
  /// In en, this message translates to:
  /// **'incompatible model'**
  String get p2pChipIncompatible;

  /// Relationship chip.
  ///
  /// In en, this message translates to:
  /// **'federated'**
  String get p2pChipFederated;

  /// Relationship chip.
  ///
  /// In en, this message translates to:
  /// **'they asked you'**
  String get p2pChipTheyAsked;

  /// Relationship chip.
  ///
  /// In en, this message translates to:
  /// **'request sent'**
  String get p2pChipRequestSent;

  /// Card title while alone on the mesh.
  ///
  /// In en, this message translates to:
  /// **'Searching for peers'**
  String get p2pSearchingTitle;

  /// Card body while alone on the mesh.
  ///
  /// In en, this message translates to:
  /// **'The mesh weaves in over a minute or so. This screen updates itself.'**
  String get p2pSearchingBody;

  /// Card title during crash recovery.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get p2pReconnectingTitle;

  /// Card body during crash recovery.
  ///
  /// In en, this message translates to:
  /// **'The sidecar died and is being replayed (attempt {n}) — no action needed.'**
  String p2pReconnectingBody(int n);

  /// Join screen headline.
  ///
  /// In en, this message translates to:
  /// **'Recommendations from other people\'s libraries'**
  String get p2pJoinTitle;

  /// Section header on the join screen.
  ///
  /// In en, this message translates to:
  /// **'What gets shared'**
  String get p2pWhatShared;

  /// Shared item 1.
  ///
  /// In en, this message translates to:
  /// **'A metadata-only snapshot'**
  String get p2pShared1;

  /// Shared item 1 detail.
  ///
  /// In en, this message translates to:
  /// **'Artist, title, duration, sound fingerprints — never audio files'**
  String get p2pShared1Sub;

  /// Shared item 2.
  ///
  /// In en, this message translates to:
  /// **'Your server\'s name and description'**
  String get p2pShared2;

  /// Shared item 2 detail.
  ///
  /// In en, this message translates to:
  /// **'Visible to everyone on the network, by default the public community network'**
  String get p2pShared2Sub;

  /// Section header: identity.
  ///
  /// In en, this message translates to:
  /// **'How you appear'**
  String get p2pHowYouAppear;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Server name'**
  String get p2pServerName;

  /// Field hint.
  ///
  /// In en, this message translates to:
  /// **'“mStream” next to 18,000 other mStreams is the first thing to change.'**
  String get p2pServerNameHint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get p2pDescription;

  /// Field hint.
  ///
  /// In en, this message translates to:
  /// **'180 characters, optional.'**
  String get p2pDescriptionHint;

  /// Switch on the join screen.
  ///
  /// In en, this message translates to:
  /// **'Also accept federation requests'**
  String get p2pAlsoAcceptRequests;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Invitations to share libraries — nothing is shared unless you approve each one. Turns federation on.'**
  String get p2pAlsoAcceptRequestsSub;

  /// Button: enable the discovery network.
  ///
  /// In en, this message translates to:
  /// **'Join the network'**
  String get p2pJoin;

  /// Button while enabling.
  ///
  /// In en, this message translates to:
  /// **'Joining…'**
  String get p2pJoining;

  /// Toast after joining.
  ///
  /// In en, this message translates to:
  /// **'Joined the discovery network — give the mesh a minute to weave in.'**
  String get p2pJoined;

  /// Toast when joining fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t join the network: {error}'**
  String p2pJoinFailed(String error);

  /// Toast when the federation half of joining fails.
  ///
  /// In en, this message translates to:
  /// **'Discovery is on, but the request inbox didn\'t start: {error}'**
  String p2pInboxFailed(String error);

  /// Note when the sidecar is missing.
  ///
  /// In en, this message translates to:
  /// **'The p2p-sidecar binary was not found for this platform and no downloadable build is published — the network is unavailable.'**
  String get p2pUnavailableNote;

  /// Note when the sidecar can be fetched.
  ///
  /// In en, this message translates to:
  /// **'The sidecar is not installed yet; joining downloads it first.'**
  String get p2pWillDownloadNote;

  /// Note for admins on the join screen.
  ///
  /// In en, this message translates to:
  /// **'Only the server admin can join.'**
  String get p2pAdminOnlyNote;

  /// Member note when the network is off.
  ///
  /// In en, this message translates to:
  /// **'The discovery network is off on {server}. Its admin can join it.'**
  String p2pMemberOffNote(String server);

  /// Member note.
  ///
  /// In en, this message translates to:
  /// **'Joining, inviting and snapshots are admin jobs. Sign in to {server} as an admin to manage the network here.'**
  String p2pMemberNote(String server);

  /// Section header on the peer screen.
  ///
  /// In en, this message translates to:
  /// **'Snapshot'**
  String get p2pSnapshotSection;

  /// Snapshot row title.
  ///
  /// In en, this message translates to:
  /// **'Downloaded · {size}'**
  String p2pDownloadedSize(String size);

  /// Snapshot row detail.
  ///
  /// In en, this message translates to:
  /// **'Snapshot {seq}'**
  String p2pSnapshotSeq(int seq);

  /// Snapshot row detail when stale.
  ///
  /// In en, this message translates to:
  /// **'a newer one ({seq}) is announced'**
  String p2pNewerAnnounced(int seq);

  /// Snapshot row title.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get p2pNotDownloaded;

  /// Snapshot row detail.
  ///
  /// In en, this message translates to:
  /// **'Download it to search it from Discover'**
  String get p2pNotDownloadedSub;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get p2pDownload;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get p2pUpdate;

  /// Button while fetching.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get p2pDownloading;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Snapshot downloaded'**
  String get p2pDownloaded;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the snapshot: {error}'**
  String p2pDownloadFailed(String error);

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Pin this snapshot'**
  String get p2pPin;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Rotation frees the least-used snapshots after 1 day; a pinned one stays.} other{Rotation frees the least-used snapshots after {count} days; a pinned one stays.}}'**
  String p2pPinSub(int count);

  /// Switch subtitle when rotation is off.
  ///
  /// In en, this message translates to:
  /// **'Rotation is off; a pinned snapshot also survives a storage squeeze.'**
  String get p2pPinSubNoRotation;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Remove snapshot'**
  String get p2pRemoveSnapshot;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Snapshot removed'**
  String get p2pSnapshotRemoved;

  /// Stat tile label.
  ///
  /// In en, this message translates to:
  /// **'held since'**
  String get p2pHeldSince;

  /// Stat tile label.
  ///
  /// In en, this message translates to:
  /// **'tracks'**
  String get p2pTracksLabel;

  /// Stat tile label.
  ///
  /// In en, this message translates to:
  /// **'seeders'**
  String get p2pSeedersLabel;

  /// Stat tile detail.
  ///
  /// In en, this message translates to:
  /// **'serving the snapshot'**
  String get p2pSeedersSub;

  /// Relationship row title.
  ///
  /// In en, this message translates to:
  /// **'Federated with you'**
  String get p2pFederatedWithYou;

  /// Relationship row detail.
  ///
  /// In en, this message translates to:
  /// **'Open Federation to see what you read from each other'**
  String get p2pFederatedWithYouSub;

  /// Relationship row title.
  ///
  /// In en, this message translates to:
  /// **'They asked to federate'**
  String get p2pTheyAskedYou;

  /// Relationship row detail.
  ///
  /// In en, this message translates to:
  /// **'Review the request under Federation'**
  String get p2pTheyAskedYouSub;

  /// Relationship row title.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get p2pRequestSentTitle;

  /// Relationship row detail.
  ///
  /// In en, this message translates to:
  /// **'Waiting on them · track it under Federation'**
  String get p2pRequestSentSub;

  /// Relationship row title.
  ///
  /// In en, this message translates to:
  /// **'Ask to share libraries'**
  String get p2pAskToFederate;

  /// Relationship row detail.
  ///
  /// In en, this message translates to:
  /// **'Sends a request over the network — nothing changes hands now'**
  String get p2pAskToFederateSub;

  /// Link.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get p2pOpen;

  /// Link.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get p2pReview;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Forget this server'**
  String get p2pForget;

  /// Button detail.
  ///
  /// In en, this message translates to:
  /// **'Offline with nothing downloaded; it comes back if heard again'**
  String get p2pForgetSub;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'{name} forgotten'**
  String p2pForgotten(String name);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Block server'**
  String get p2pBlockServer;

  /// Confirm dialog.
  ///
  /// In en, this message translates to:
  /// **'Block {name}? Its announcements are ignored and its snapshot removed.'**
  String p2pBlockConfirm(String name);

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'{name} blocked'**
  String p2pBlocked(String name);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get p2pUnblock;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Server unblocked'**
  String get p2pUnblocked;

  /// Note on an incompatible peer.
  ///
  /// In en, this message translates to:
  /// **'Incompatible embedding model — its library can\'t power this server\'s similar-search.'**
  String get p2pIncompatibleNote;

  /// Peer subtitle piece.
  ///
  /// In en, this message translates to:
  /// **'compatible model'**
  String get p2pCompatible;

  /// Peer subtitle piece.
  ///
  /// In en, this message translates to:
  /// **'model unknown'**
  String get p2pModelUnknown;

  /// Peer description empty state.
  ///
  /// In en, this message translates to:
  /// **'No description.'**
  String get p2pNoDescription;

  /// Stand-in for a server without a name.
  ///
  /// In en, this message translates to:
  /// **'Unnamed server'**
  String get p2pUnnamedServer;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Ask to federate'**
  String get p2pFederateTitle;

  /// Explainer note.
  ///
  /// In en, this message translates to:
  /// **'Sends a request over the discovery network. No access is exchanged now — they see your name, message and offer; libraries are only shared if they accept.'**
  String get p2pFederateNote;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get p2pMessage;

  /// Field hint with the character count.
  ///
  /// In en, this message translates to:
  /// **'Optional · {n} / 500'**
  String p2pMessageHint(int n);

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Libraries you\'ll share back if they accept'**
  String get p2pShareBackLibraries;

  /// Note under the list.
  ///
  /// In en, this message translates to:
  /// **'Uncheck everything for a one-way ask — you would only read theirs.'**
  String get p2pShareBackNote;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get p2pSendRequest;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Request sent — track it under Federation'**
  String get p2pRequestSent;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the request: {error}'**
  String p2pRequestFailed(String error);

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Their ticket'**
  String get p2pTheirTicket;

  /// Field hint.
  ///
  /// In en, this message translates to:
  /// **'A friend finds theirs under Invite a friend on their P2P Network screen.'**
  String get p2pTheirTicketHint;

  /// Field hint after pasting.
  ///
  /// In en, this message translates to:
  /// **'Pasted from your clipboard.'**
  String get p2pTicketPasted;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Remember this friend'**
  String get p2pRememberFriend;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved to the server config so the friendship survives restarts.'**
  String get p2pRememberFriendSub;

  /// Button: join the friend's server.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get p2pJoinFriend;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Joined — the mesh weaves in over a minute'**
  String get p2pJoinedFriend;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t join: {error}'**
  String p2pJoinFriendFailed(String error);

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like an endpoint ticket.'**
  String get p2pNotATicket;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get p2pScanQr;

  /// Scanner title.
  ///
  /// In en, this message translates to:
  /// **'Scan a network ticket'**
  String get p2pScannerTitle;

  /// Section header and share subject.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get p2pInviteFriend;

  /// Note above your own ticket.
  ///
  /// In en, this message translates to:
  /// **'Your ticket — a friend pastes it here on their phone to befriend {name}. It is an address, not a credential.'**
  String p2pYourTicketNote(String name);

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Ticket copied'**
  String get p2pTicketCopied;

  /// Share-sheet message.
  ///
  /// In en, this message translates to:
  /// **'Befriend my mStream server on the discovery network — in the mStream app open P2P Network → Befriend a server and paste this ticket:\n\n{ticket}'**
  String p2pShareMessage(String ticket);

  /// Share-sheet subject.
  ///
  /// In en, this message translates to:
  /// **'mStream discovery-network ticket'**
  String get p2pShareSubject;

  /// Note when the endpoint ticket is missing.
  ///
  /// In en, this message translates to:
  /// **'The sidecar isn\'t running yet, so there is no ticket to share.'**
  String get p2pTicketNotReady;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Network settings'**
  String get p2pSettingsTitle;

  /// Switch title.
  ///
  /// In en, this message translates to:
  /// **'Discovery network'**
  String get p2pSwitchTitle;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Announcing a metadata-only snapshot to the network. Switch off to leave — collected data stays local.'**
  String get p2pSwitchSub;

  /// Confirm dialog.
  ///
  /// In en, this message translates to:
  /// **'Leave the discovery network? Your server stops announcing and downloading snapshots. Local discovery keeps working.'**
  String get p2pLeaveConfirm;

  /// Confirm button.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get p2pLeave;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Left the discovery network'**
  String get p2pLeft;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t leave the network: {error}'**
  String p2pLeaveFailed(String error);

  /// Screen title for editing the identity.
  ///
  /// In en, this message translates to:
  /// **'Name and description'**
  String get p2pEditIdentity;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Saved — announced to the network'**
  String get p2pIdentitySaved;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {error}'**
  String p2pSaveFailed(String error);

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Snapshots'**
  String get p2pSnapshotsSection;

  /// Chip row label.
  ///
  /// In en, this message translates to:
  /// **'Auto-download up to'**
  String get p2pAutoDownload;

  /// Chip label.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 server} other{{count} servers}}'**
  String p2pServersCount(int count);

  /// Chip row label.
  ///
  /// In en, this message translates to:
  /// **'Storage cap'**
  String get p2pStorageCap;

  /// Chip row label.
  ///
  /// In en, this message translates to:
  /// **'Rotate downloads'**
  String get p2pRotate;

  /// Chip row label.
  ///
  /// In en, this message translates to:
  /// **'Forget offline servers'**
  String get p2pForgetOffline;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Mesh'**
  String get p2pMeshSection;

  /// Row title.
  ///
  /// In en, this message translates to:
  /// **'Community seeds'**
  String get p2pCommunitySeeds;

  /// Row detail when on.
  ///
  /// In en, this message translates to:
  /// **'Bootstrapping through the public seed servers'**
  String get p2pCommunitySeedsOn;

  /// Row detail when off.
  ///
  /// In en, this message translates to:
  /// **'Off — only befriended servers; set in the server config'**
  String get p2pCommunitySeedsOff;

  /// Row title.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No blocked servers} =1{1 blocked server} other{{count} blocked servers}}'**
  String p2pBlockedServers(int count);

  /// Row detail.
  ///
  /// In en, this message translates to:
  /// **'Announcements ignored, snapshots never fetched'**
  String get p2pBlockedSub;

  /// Screen title.
  ///
  /// In en, this message translates to:
  /// **'Blocked servers'**
  String get p2pBlockedTitle;

  /// Toast.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get p2pSaved;

  /// Chip: none.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get p2pOff;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get p2pSave;

  /// Placeholder of the catalog filter field.
  ///
  /// In en, this message translates to:
  /// **'Search servers — name or description'**
  String get p2pSearchServers;

  /// Home banner headline: requests waiting on this operator.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 federation request waiting} other{{count} federation requests waiting}}'**
  String federationInboxBanner(int count);

  /// Home banner second line.
  ///
  /// In en, this message translates to:
  /// **'Tap to accept or reject'**
  String get federationInboxBannerSub;

  /// Phone notification title.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A federation request is waiting} other{{count} federation requests are waiting}}'**
  String federationInboxNotificationTitle(int count);

  /// Phone notification body; {server} is the server's name or address.
  ///
  /// In en, this message translates to:
  /// **'On {server}. Open to accept or reject.'**
  String federationInboxNotificationBody(String server);

  /// Android notification channel name.
  ///
  /// In en, this message translates to:
  /// **'Federation requests'**
  String get federationInboxChannelName;

  /// Android notification channel description.
  ///
  /// In en, this message translates to:
  /// **'A request to share libraries arrived on one of your servers'**
  String get federationInboxChannelDescription;

  /// Federation settings switch.
  ///
  /// In en, this message translates to:
  /// **'Notify me about requests'**
  String get federationNotifyTitle;

  /// Federation settings switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'A phone notification when a request arrives while the app is open or playing'**
  String get federationNotifySubtitle;

  /// Android Auto / CarPlay tab: this phone's recent plays of the server's tracks.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get autoRecentlyPlayed;

  /// Settings section header.
  ///
  /// In en, this message translates to:
  /// **'Listening history'**
  String get settingsSectionListening;

  /// Settings switch.
  ///
  /// In en, this message translates to:
  /// **'Keep listening history'**
  String get settingsHistoryEnabled;

  /// Settings switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Record what this phone plays, on every server and for local files. Kept on this device only.'**
  String get settingsHistoryEnabledSubtitle;

  /// Settings switch.
  ///
  /// In en, this message translates to:
  /// **'Send plays to your servers'**
  String get settingsHistorySend;

  /// Settings switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Each play goes to the server the track lives on (a peer\'s track to its parent), so your stats include this phone. Servers forward to Last.fm only if you linked an account there.'**
  String get settingsHistorySendSubtitle;

  /// Settings action row title and its confirm button.
  ///
  /// In en, this message translates to:
  /// **'Clear listening history'**
  String get settingsHistoryClear;

  /// Settings action row subtitle; {size} is a formatted byte count like '1.2 MB'.
  ///
  /// In en, this message translates to:
  /// **'Removes this phone\'s record ({size}). Your servers keep theirs.'**
  String settingsHistoryClearSubtitle(Object size);

  /// Confirm dialog body.
  ///
  /// In en, this message translates to:
  /// **'Delete this phone\'s listening history? Plays already sent to a server stay there.'**
  String get settingsHistoryClearConfirm;

  /// Snackbar after clearing.
  ///
  /// In en, this message translates to:
  /// **'Listening history cleared'**
  String get settingsHistoryCleared;

  /// Settings line under the send switch: outbox size.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Everything is synced} =1{1 play waiting to be sent} other{{count} plays waiting to be sent}}'**
  String settingsHistoryUnsynced(num count);

  /// Song Info stats line, server counts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play on {server}} other{{count} plays on {server}}}'**
  String songInfoServerPlays(num count, Object server);

  /// Song Info stats line, device counts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play on this phone} other{{count} plays on this phone}}'**
  String songInfoDevicePlays(num count);

  /// Song Info stats line suffix; {ago} is a relative time like '3 h ago'.
  ///
  /// In en, this message translates to:
  /// **'last {ago}'**
  String songInfoLastPlayed(Object ago);

  /// Drawer entry + app bar title of the listening stats page.
  ///
  /// In en, this message translates to:
  /// **'Listening Stats'**
  String get listeningTitle;

  /// Scope pill: the device's own record.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get listeningScopeThisPhone;

  /// Scope bottom sheet title.
  ///
  /// In en, this message translates to:
  /// **'What to show'**
  String get listeningScopeSheetTitle;

  /// Scope sheet: device row subtitle.
  ///
  /// In en, this message translates to:
  /// **'What this phone played: every server, local files, offline. Kept on this device.'**
  String get listeningScopeSheetDevice;

  /// Scope sheet: server row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your plays on this server from every app — the web player, other phones, this phone once synced.'**
  String get listeningScopeSheetServer;

  /// Scope sheet: server without the capability.
  ///
  /// In en, this message translates to:
  /// **'No listening stats yet — needs mStream 6.27 or later.'**
  String get listeningScopeSheetLegacy;

  /// Scope sheet: peer row subtitle; {server} is the parent's name.
  ///
  /// In en, this message translates to:
  /// **'Counted on {server}: a peer\'s tracks count where your account lives.'**
  String listeningScopeSheetPeer(Object server);

  /// Provenance line, device scope.
  ///
  /// In en, this message translates to:
  /// **'What this phone played, on every server and local files. Kept on this device.'**
  String get listeningProvenanceDevice;

  /// Provenance line, server scope.
  ///
  /// In en, this message translates to:
  /// **'Your plays on {server} from every app, including tracks from its peers.'**
  String listeningProvenanceServer(Object server);

  /// Provenance line, peer scope.
  ///
  /// In en, this message translates to:
  /// **'Your plays of {peer}\'s tracks, counted on {server}.'**
  String listeningProvenancePeer(Object peer, Object server);

  /// Provenance line when the server is unreachable.
  ///
  /// In en, this message translates to:
  /// **'{server} did not answer — showing this phone\'s plays on it.'**
  String listeningProvenanceFallback(Object server);

  /// Provenance line for a server without the capability.
  ///
  /// In en, this message translates to:
  /// **'{server} has no listening stats yet (mStream 6.27+) — showing this phone\'s plays on it.'**
  String listeningProvenanceLegacy(Object server);

  /// Sync line under the provenance.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play not synced yet} other{{count} plays not synced yet}}'**
  String listeningUnsynced(num count);

  /// Period chip.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get listeningPeriodWeek;

  /// Period chip.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get listeningPeriodMonth;

  /// Period chip.
  ///
  /// In en, this message translates to:
  /// **'This quarter'**
  String get listeningPeriodQuarter;

  /// Period chip.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get listeningPeriodYear;

  /// Period chip.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get listeningPeriodAll;

  /// Summary tile label.
  ///
  /// In en, this message translates to:
  /// **'Plays'**
  String get listeningTilePlays;

  /// Summary tile label.
  ///
  /// In en, this message translates to:
  /// **'Listening time'**
  String get listeningTileTime;

  /// Summary tile label.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get listeningTileTracks;

  /// Summary tile label.
  ///
  /// In en, this message translates to:
  /// **'Skips'**
  String get listeningTileSkips;

  /// Summary tile label.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get listeningTileStreak;

  /// Summary tile label.
  ///
  /// In en, this message translates to:
  /// **'Sittings'**
  String get listeningTileSessions;

  /// Streak tile value.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String listeningDays(num count);

  /// Tile subtitle.
  ///
  /// In en, this message translates to:
  /// **'counted plays'**
  String get listeningTileSubCounted;

  /// Tile subtitle.
  ///
  /// In en, this message translates to:
  /// **'different tracks'**
  String get listeningTileSubTracks;

  /// Tile subtitle; {pct} is a whole number.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of starts'**
  String listeningTileSubSkips(Object pct);

  /// Tile subtitle; {count} days.
  ///
  /// In en, this message translates to:
  /// **'longest {count}'**
  String listeningTileSubStreak(Object count);

  /// Tile subtitle; {duration} formatted like '24 min'.
  ///
  /// In en, this message translates to:
  /// **'about {duration} each'**
  String listeningTileSubSessions(Object duration);

  /// Hour-of-day card title.
  ///
  /// In en, this message translates to:
  /// **'When you listen'**
  String get listeningWhenYouListen;

  /// Hour-of-day card note; {hour} like '20:00'.
  ///
  /// In en, this message translates to:
  /// **'Most around {hour}'**
  String listeningMostAround(Object hour);

  /// Top card title.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get listeningTop;

  /// Top entity chip.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get listeningTopTracks;

  /// Top entity chip.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get listeningTopArtists;

  /// Top entity chip.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get listeningTopAlbums;

  /// Top metric chip.
  ///
  /// In en, this message translates to:
  /// **'Plays'**
  String get listeningByPlays;

  /// Top metric chip.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get listeningByTime;

  /// Row count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play} other{{count} plays}}'**
  String listeningPlays(num count);

  /// Row count for artists/albums.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String listeningTracksCount(num count);

  /// History card title.
  ///
  /// In en, this message translates to:
  /// **'Recent plays'**
  String get listeningRecent;

  /// History card button.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get listeningLoadMore;

  /// Empty state title.
  ///
  /// In en, this message translates to:
  /// **'No plays yet'**
  String get listeningEmptyTitle;

  /// Empty state copy, device scope.
  ///
  /// In en, this message translates to:
  /// **'Plays land here as you listen. This phone keeps its own record; your server keeps yours across every app.'**
  String get listeningEmptyDevice;

  /// Empty state copy, server scope.
  ///
  /// In en, this message translates to:
  /// **'Nothing reported to {server} yet. Plays from this phone arrive once they sync.'**
  String listeningEmptyServer(Object server);

  /// Empty period copy.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this period.'**
  String get listeningEmptyPeriod;

  /// History row outcome.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get listeningOutcomeCompleted;

  /// History row outcome.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get listeningOutcomeSkipped;

  /// History row outcome.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get listeningOutcomeStopped;

  /// History row outcome with the position, e.g. 'Skipped at 1:20'.
  ///
  /// In en, this message translates to:
  /// **'{outcome} at {position}'**
  String listeningOutcomeAt(Object outcome, Object position);

  /// History row suffix.
  ///
  /// In en, this message translates to:
  /// **'not counted'**
  String get listeningNotCounted;

  /// Row suffix naming the peer.
  ///
  /// In en, this message translates to:
  /// **'via {peer}'**
  String listeningVia(Object peer);

  /// History row repeat badge.
  ///
  /// In en, this message translates to:
  /// **'×{count}'**
  String listeningRepeats(Object count);

  /// History row subtitle for a device-only file.
  ///
  /// In en, this message translates to:
  /// **'Local file'**
  String get listeningLocalFile;

  /// Banner when history is disabled.
  ///
  /// In en, this message translates to:
  /// **'Listening history is off. Turn it on in Settings to record plays on this phone.'**
  String get listeningHistoryOff;

  /// Error state.
  ///
  /// In en, this message translates to:
  /// **'Could not load: {message}'**
  String listeningError(Object message);

  /// Error state button.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get listeningRetry;

  /// Day label.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get listeningToday;

  /// Day label.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get listeningYesterday;

  /// Section title of the plays-per-day bars (week, month, quarter).
  ///
  /// In en, this message translates to:
  /// **'Plays per day'**
  String get listeningPlaysPerDay;

  /// Section title of the same bars per month (year, all time).
  ///
  /// In en, this message translates to:
  /// **'Plays per month'**
  String get listeningPlaysPerMonth;

  /// Under the plays-per-day bars; {date} is a short date like 'Sep 3'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Most on {date}: 1 play} other{Most on {date}: {count} plays}}'**
  String listeningMostOnDay(int count, String date);

  /// Under the plays-per-month bars; {month} is a month and year like 'September 2026'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Most in {month}: 1 play} other{Most in {month}: {count} plays}}'**
  String listeningMostInMonth(int count, String month);

  /// Settings row title: adding the app's Now Playing home-screen widget.
  ///
  /// In en, this message translates to:
  /// **'Home screen widget'**
  String get settingsHomeWidget;

  /// Subtitle of that row on Android, where a tap opens the size sheet.
  ///
  /// In en, this message translates to:
  /// **'Add the Now Playing widget to your home screen in one of five sizes.'**
  String get settingsHomeWidgetSubtitle;

  /// Subtitle of that row on iOS, where the system's gallery is the only way; no tap.
  ///
  /// In en, this message translates to:
  /// **'Long-press the home screen, add a widget, and pick mStream Music.'**
  String get settingsHomeWidgetSubtitleIos;

  /// Title of the Android size sheet under the row.
  ///
  /// In en, this message translates to:
  /// **'Choose a size'**
  String get homeWidgetPickSize;

  /// Snackbar / sheet text when the Android launcher refuses pin requests.
  ///
  /// In en, this message translates to:
  /// **'This launcher can\'t add widgets from here. Use its own widget picker.'**
  String get homeWidgetPinUnsupported;

  /// Connected-server song/album sheet: the status line under the header while that server answers (a green dot before it). {name} is the connected server's name.
  ///
  /// In en, this message translates to:
  /// **'{name} online'**
  String discoverSheetPeerOnline(String name);

  /// Connected-server sheet: the status line when that server did not answer (a grey dot before it). {name} is the server's name.
  ///
  /// In en, this message translates to:
  /// **'{name} not answering'**
  String discoverSheetPeerNotAnswering(String name);

  /// Connected-server sheets: how many songs an album has on that server (the album line, the Album choice's size).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String discoverSheetSongCount(int count);

  /// Connected-server sheets: a number of albums (the artist line, the Artist choice's size, a finished copy's line).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 album} other{{count} albums}}'**
  String discoverSheetAlbumCount(int count);

  /// Connected-server song sheet, album line: the user's own library has no album of this name by the artist.
  ///
  /// In en, this message translates to:
  /// **'not in your library'**
  String get discoverSheetNotInLibrary;

  /// Connected-server song sheet, album line: the user's own library already has an album of this name by the artist.
  ///
  /// In en, this message translates to:
  /// **'in your library'**
  String get discoverSheetInLibrary;

  /// Connected-server song sheet, artist line when that server did not answer: how many albums by the artist the user's own library has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{you have 1 album} other{you have {count} albums}}'**
  String discoverSheetYouHaveAlbums(int count);

  /// Connected-server sheets: button/row that opens the album (through that server).
  ///
  /// In en, this message translates to:
  /// **'Open album'**
  String get discoverSheetOpenAlbum;

  /// Connected-server sheets: button/row that adds the album's songs to the end of the queue.
  ///
  /// In en, this message translates to:
  /// **'Queue album'**
  String get discoverSheetQueueAlbum;

  /// Connected-server album sheet: row that plays the album now.
  ///
  /// In en, this message translates to:
  /// **'Play album'**
  String get discoverSheetPlayAlbum;

  /// Connected-server song sheet, artist line: button that opens the artist's albums on that server.
  ///
  /// In en, this message translates to:
  /// **'Open artist'**
  String get discoverSheetOpenArtist;

  /// Connected-server album sheet: small-caps label over the play/queue/open rows.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get discoverSheetListen;

  /// Connected-server sheets: small-caps label over the card that copies the song/album/artist from that server into a library on the user's OWN server (not onto the phone).
  ///
  /// In en, this message translates to:
  /// **'Keep a copy'**
  String get discoverSheetKeepCopy;

  /// Connected-server song sheet: row that lists links to this song on other services (MusicBrainz, Deezer, …).
  ///
  /// In en, this message translates to:
  /// **'Open elsewhere'**
  String get discoverSheetOpenElsewhere;

  /// Connected-server song sheet: row that switches the app to browsing that server's library. {name} is the server's name.
  ///
  /// In en, this message translates to:
  /// **'Browse {name}'**
  String discoverSheetBrowsePeer(String name);

  /// Connected-server song sheet, last row: saves the song file onto THIS phone for offline play (the old Download, renamed so it is never confused with Keep a copy, which copies to the server).
  ///
  /// In en, this message translates to:
  /// **'Download to this phone'**
  String get discoverSheetDownloadToPhone;

  /// Second line under 'Download to this phone'.
  ///
  /// In en, this message translates to:
  /// **'For offline play on this device'**
  String get discoverSheetDownloadToPhoneSub;

  /// Toast when Play album / Queue album could not get the album's songs from the connected server. {name} is that server's name.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this album from {name}'**
  String discoverSheetAlbumFailed(String name);

  /// Accessible name of the ⋯ button on a connected server's album card on Discover (opens the album sheet). {album} is the album name.
  ///
  /// In en, this message translates to:
  /// **'More for {album}'**
  String discoverAlbumCardMore(String album);

  /// Keep a copy card: choice that copies only this song.
  ///
  /// In en, this message translates to:
  /// **'This song'**
  String get discoverKeepThisSong;

  /// Keep a copy card: choice that copies the song's whole album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get discoverKeepAlbum;

  /// Keep a copy card: choice that copies the artist's albums.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get discoverKeepArtist;

  /// Accessible name of the Keep a copy choices (This song / Album / Artist).
  ///
  /// In en, this message translates to:
  /// **'What to keep'**
  String get discoverKeepWhat;

  /// Keep a copy card, under the Artist choice after the album count ('1 album · you have 3'): albums by the artist the user's own library already has.
  ///
  /// In en, this message translates to:
  /// **'you have {count}'**
  String discoverKeepYouHave(int count);

  /// Keep a copy card, checkbox under the Artist choice: copy only the artist's albums the user's library lacks (matched by album name).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Only the 1 album you don\'t have} other{Only the {count} albums you don\'t have}}'**
  String discoverKeepOnlyMissing(int count);

  /// Keep a copy card: start of the line naming where the copied files land ('Files go to copies › Artist › Album').
  ///
  /// In en, this message translates to:
  /// **'Files go to'**
  String get discoverKeepFilesGoTo;

  /// Keep a copy card, in place of 'Files go to …' (and of 'Retry adds to …'): the layout would render a path longer than the server takes for this copy (long tags, deep folders on the connected server), so the server would refuse it; {max} is the limit (500).
  ///
  /// In en, this message translates to:
  /// **'This copy\'s path would pass {max} characters, more than the server takes'**
  String discoverKeepPathTooLong(int max);

  /// Keep a copy card: end of the destination line for an artist copy (each album lands in its own folder).
  ///
  /// In en, this message translates to:
  /// **'one folder per album'**
  String get discoverKeepFolderPerAlbum;

  /// Keep a copy card: link after the destination line that opens the destination picker.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get discoverKeepChange;

  /// Accessible name of the Keep a copy card's Change link.
  ///
  /// In en, this message translates to:
  /// **'Change where copies go'**
  String get discoverKeepChangeHint;

  /// Keep a copy card's main button with This song chosen: copies the song to the user's server.
  ///
  /// In en, this message translates to:
  /// **'Add song'**
  String get discoverKeepAddSong;

  /// Keep a copy card's main button with Album chosen.
  ///
  /// In en, this message translates to:
  /// **'Add album'**
  String get discoverKeepAddAlbum;

  /// Keep a copy card's main button with Artist chosen (every album by the artist on that server).
  ///
  /// In en, this message translates to:
  /// **'Add every album'**
  String get discoverKeepAddEveryAlbum;

  /// Keep a copy card's main button with Artist chosen and 'only the albums you don't have' ticked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 album} other{Add {count} albums}}'**
  String discoverKeepAddAlbums(int count);

  /// Keep a copy card's main button when only the missing albums can be copied and their number is not known yet.
  ///
  /// In en, this message translates to:
  /// **'Add the albums you don\'t have'**
  String get discoverKeepAddMissing;

  /// Keep a copy card's only line when the user's account may not upload to their server.
  ///
  /// In en, this message translates to:
  /// **'Your account can\'t add files to this server'**
  String get discoverKeepUploadsOff;

  /// Keep a copy card's only line when uploads are allowed but no library on the user's server accepts new files.
  ///
  /// In en, this message translates to:
  /// **'No library on your server takes new files'**
  String get discoverKeepNoLibrary;

  /// Keep a copy card: the copy could not be started and the server gave no words of its own (a network failure).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach your server. Try again.'**
  String get discoverKeepStartFailed;

  /// Keep a copy card: a copy was not started because where the account's copies land changed since the card opened (on another device, or in the webapp). The 'Files go to' line above already shows the new place; the user checks it and presses Add again.
  ///
  /// In en, this message translates to:
  /// **'Where files land changed since this opened. Check the path above and add again.'**
  String get discoverKeepDestChanged;

  /// Keep a copy card, under a finished copy's line: its Retry or Add again was not started because where the account's copies land changed since the card opened (on another device, or in the webapp). A 'Files go to' line with the new place is drawn just above; the user checks it and presses the verb again.
  ///
  /// In en, this message translates to:
  /// **'Where files land changed since this opened. Check the path above and try again.'**
  String get discoverKeepDestChangedTryAgain;

  /// Keep a copy card, under a finished copy that ran somewhere else than where copies land now: where its Retry would put the files. {path} is the library and folders, e.g. 'copies › Boukmanflow › Borrowed Tapes'.
  ///
  /// In en, this message translates to:
  /// **'Retry adds to {path}, your saved place now'**
  String discoverKeepRetryAddsTo(String path);

  /// Keep a copy card, under a cancelled copy that ran somewhere else than where copies land now: where its Add again would put the files. {path} is the library and folders, e.g. 'copies › Boukmanflow › Borrowed Tapes'.
  ///
  /// In en, this message translates to:
  /// **'Add again adds to {path}, your saved place now'**
  String discoverKeepAddAgainAddsTo(String path);

  /// Confirmation title before copying several albums by an artist from a connected server. {peer} is that server's name.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Copy 1 album from {peer}?} other{Copy {count} albums from {peer}?}}'**
  String discoverKeepConfirmTitle(int count, String peer);

  /// Confirmation title before copying every album by an artist when their number is not known yet. {artist} is the artist, {peer} the connected server.
  ///
  /// In en, this message translates to:
  /// **'Copy every album by {artist} from {peer}?'**
  String discoverKeepConfirmEveryTitle(String artist, String peer);

  /// Body of the confirmation before an artist copy whose layout gives each album its own folder (discoverKeepConfirmBodyFlat when it does not). {path} is where the files land on the user's server, like 'copies › Boukmanflow'.
  ///
  /// In en, this message translates to:
  /// **'They land on your server in {path}, one folder per album. Songs you already have are skipped.'**
  String discoverKeepConfirmBody(String path);

  /// Body of the confirmation before an artist copy whose layout names no album folder (every album lands in the same folder). {path} is where the files land on the user's server, like 'copies › From friends › Boukmanflow'.
  ///
  /// In en, this message translates to:
  /// **'They land on your server in {path}. Songs you already have are skipped.'**
  String discoverKeepConfirmBodyFlat(String path);

  /// The confirmation's yes button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Copy 1 album} other{Copy {count} albums}}'**
  String discoverKeepConfirmAction(int count);

  /// The every-album confirmation's yes button (count not known).
  ///
  /// In en, this message translates to:
  /// **'Copy every album'**
  String get discoverKeepConfirmEveryAction;

  /// Keep a copy card: the copy is queued behind another one on the server.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a free slot'**
  String get discoverJobQueued;

  /// Under 'Waiting for a free slot': nothing to do, it starts by itself.
  ///
  /// In en, this message translates to:
  /// **'Starts on its own'**
  String get discoverJobQueuedSub;

  /// Keep a copy card: the copy is running (a progress bar and the server's status line follow).
  ///
  /// In en, this message translates to:
  /// **'Copying'**
  String get discoverJobCopying;

  /// Keep a copy card: running but the server has not said anything yet.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get discoverJobStarting;

  /// Keep a copy card: the user cancelled a running copy; it stops at its next check.
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get discoverJobStopping;

  /// Keep a copy card: the copy landed in a library on the user's server.
  ///
  /// In en, this message translates to:
  /// **'In your collection'**
  String get discoverJobInCollection;

  /// Keep a copy card: nothing was copied because the user's library already had it.
  ///
  /// In en, this message translates to:
  /// **'Already yours'**
  String get discoverJobOwned;

  /// Under 'Already yours' for one song (the library file's path may follow).
  ///
  /// In en, this message translates to:
  /// **'Your library has this song'**
  String get discoverJobOwnedSub;

  /// Keep a copy card: the song was not copied because a file already exists where it would land.
  ///
  /// In en, this message translates to:
  /// **'Skipped · a file is already there'**
  String get discoverJobSkipped;

  /// Under the skipped line. {path} is where the song would have landed.
  ///
  /// In en, this message translates to:
  /// **'A file is already at {path} · nothing was overwritten'**
  String discoverJobExistsSub(String path);

  /// Keep a copy card: the copy failed (the server's own words follow).
  ///
  /// In en, this message translates to:
  /// **'Copy failed'**
  String get discoverJobFailed;

  /// Under 'Copy failed' when the server said nothing more.
  ///
  /// In en, this message translates to:
  /// **'The copy did not finish'**
  String get discoverJobFailedSub;

  /// Start of a failed album copy's line ('Nothing copied · 3 failed').
  ///
  /// In en, this message translates to:
  /// **'Nothing copied'**
  String get discoverJobNothingCopiedLead;

  /// End of a stopped copy's line after its reason ('… · nothing copied').
  ///
  /// In en, this message translates to:
  /// **'nothing copied'**
  String get discoverJobNothingCopied;

  /// Keep a copy card: the copy ended early (its reason follows).
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get discoverJobStopped;

  /// Why a copy stopped: the connected server's daily transfer limit. {peer} is its name.
  ///
  /// In en, this message translates to:
  /// **'{peer}\'s transfer limit stopped it'**
  String discoverJobStoppedQuota(String peer);

  /// Why a copy stopped: the connected server is busy. {peer} is its name.
  ///
  /// In en, this message translates to:
  /// **'{peer} is serving too many streams right now'**
  String discoverJobStoppedBusy(String peer);

  /// Why a copy stopped: the connected server stopped answering. {peer} is its name.
  ///
  /// In en, this message translates to:
  /// **'{peer} went away'**
  String discoverJobStoppedPeer(String peer);

  /// Why a copy stopped: the connected server refuses copies to the user's server (no Retry). {peer} is its name.
  ///
  /// In en, this message translates to:
  /// **'{peer} does not allow copies with your server\'s key'**
  String discoverJobStoppedRefused(String peer);

  /// Keep a copy card: the user cancelled the copy before anything landed.
  ///
  /// In en, this message translates to:
  /// **'Stopped · nothing was copied'**
  String get discoverJobCancelledNothing;

  /// Keep a copy card: the user cancelled an album copy after some songs landed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Stopped · 1 copied} other{Stopped · {count} copied}}'**
  String discoverJobCancelledSome(int count);

  /// Under a cancelled copy.
  ///
  /// In en, this message translates to:
  /// **'You cancelled it'**
  String get discoverJobCancelledSub;

  /// Under a cancelled album copy: the songs that already landed stay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You cancelled it · the song stays in your collection} other{You cancelled it · the {count} songs stay in your collection}}'**
  String discoverJobCancelledStay(int count);

  /// Keep a copy card: an album/artist copy found nothing to copy — the user already has everything.
  ///
  /// In en, this message translates to:
  /// **'You have it all'**
  String get discoverJobNothingAll;

  /// Under 'You have it all'. {peer} is the connected server.
  ///
  /// In en, this message translates to:
  /// **'Nothing to copy from {peer}'**
  String discoverJobNothingFrom(String peer);

  /// Keep a copy card: an artist copy found the artist only as a guest on that server's albums.
  ///
  /// In en, this message translates to:
  /// **'Nothing of theirs to copy'**
  String get discoverJobOnlyGuest;

  /// Under 'Nothing of theirs to copy'. {artist} is the artist, {peer} the connected server.
  ///
  /// In en, this message translates to:
  /// **'{artist} only appears as a guest on {peer}\'s albums'**
  String discoverJobOnlyGuestSub(String artist, String peer);

  /// Keep a copy card: the same album/artist is being copied from ANOTHER connected server. {peer} is that other server.
  ///
  /// In en, this message translates to:
  /// **'Copying from {peer}'**
  String discoverJobFromOther(String peer);

  /// Under 'Copying from …'. {action} is the card's button label ('Add album').
  ///
  /// In en, this message translates to:
  /// **'{action} comes back when that copy ends'**
  String discoverJobComesBack(String action);

  /// Keep a copy card: a copy finished in a way this app cannot read in detail.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get discoverJobDone;

  /// Part of a finished album copy's line: songs copied.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} copied}}'**
  String discoverJobCopiedCount(int count);

  /// Part of a finished album copy's line: songs skipped because the library already had them.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} already yours}}'**
  String discoverJobOwnedCount(int count);

  /// Part of a finished album copy's line: songs that failed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} failed}}'**
  String discoverJobFailedCount(int count);

  /// Part of a finished artist copy's line: albums whose listing failed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 album failed} other{{count} albums failed}}'**
  String discoverJobAlbumsFailed(int count);

  /// Part of a finished artist copy's line: albums not copied (already owned, or the artist only guests on them).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 album left out} other{{count} albums left out}}'**
  String discoverJobAlbumsLeftOut(int count);

  /// Keep a copy card: start the same copy again (it takes only what is still missing).
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get discoverJobRetry;

  /// Keep a copy card: start a cancelled copy again.
  ///
  /// In en, this message translates to:
  /// **'Add again'**
  String get discoverJobAddAgain;

  /// Keep a copy card: queue the copied song (the new library file).
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get discoverJobAddToQueue;

  /// Discover, on a connected server's song row or album card: the user's copy of it is queued. Lowercase, a word only.
  ///
  /// In en, this message translates to:
  /// **'waiting'**
  String get discoverMarkWaiting;

  /// Discover row/card marker: the copy is running.
  ///
  /// In en, this message translates to:
  /// **'copying…'**
  String get discoverMarkCopying;

  /// Discover album card marker while its album copies: songs done of the album's total.
  ///
  /// In en, this message translates to:
  /// **'copying {done} of {total}'**
  String discoverMarkCopyingCount(int done, int total);

  /// Discover row/card marker: the copy was cancelled and is stopping.
  ///
  /// In en, this message translates to:
  /// **'stopping…'**
  String get discoverMarkStopping;

  /// Discover row/card marker: the copy landed on the user's server.
  ///
  /// In en, this message translates to:
  /// **'in your collection'**
  String get discoverMarkInCollection;

  /// Discover row/card marker: nothing was copied, the library already had it.
  ///
  /// In en, this message translates to:
  /// **'already yours'**
  String get discoverMarkAlreadyYours;

  /// Discover row/card marker: the copy ended early (limit, busy, server gone).
  ///
  /// In en, this message translates to:
  /// **'stopped'**
  String get discoverMarkStopped;

  /// Discover row/card marker: the connected server refuses copies to the user's server.
  ///
  /// In en, this message translates to:
  /// **'refused'**
  String get discoverMarkRefused;

  /// Discover row/card marker: the copy failed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get discoverMarkFailed;

  /// Discover row/card marker: not copied because a file already exists where it would land.
  ///
  /// In en, this message translates to:
  /// **'skipped'**
  String get discoverMarkSkipped;

  /// Discover's Copies strip under the configuration bar: copies running or waiting on the user's server.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{Copying {count}}}'**
  String discoverCopiesCopying(int count);

  /// Discover's Copies strip: copies that failed or stopped and still want the user (Retry / Clear finished).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} failed}}'**
  String discoverCopiesFailed(int count);

  /// Accessible name of Discover's Copies strip (opens the Copies list). {summary} is the strip's text, e.g. 'Copying 2, 1 failed'.
  ///
  /// In en, this message translates to:
  /// **'Copies: {summary}'**
  String discoverCopiesLabel(String summary);

  /// Title of the Copies sheet, and the name of the home SERVER card listing what the user's own server is copying for them from connected servers (Discover's Keep a copy).
  ///
  /// In en, this message translates to:
  /// **'Copies'**
  String get discoverCopiesTitle;

  /// Copies sheet section header (drawn in capitals): copies running or waiting for a free slot.
  ///
  /// In en, this message translates to:
  /// **'Copying'**
  String get discoverCopiesSectionCopying;

  /// Copies sheet section header (drawn in capitals): copies that failed or stopped early and still want Retry or Clear finished.
  ///
  /// In en, this message translates to:
  /// **'Stopped or failed'**
  String get discoverCopiesSectionAttention;

  /// Copies sheet section header (drawn in capitals): copies the phone saw end since it opened (landed, already yours, cancelled).
  ///
  /// In en, this message translates to:
  /// **'Just finished'**
  String get discoverCopiesSectionFinished;

  /// Copies sheet button pinned at the bottom: removes the finished copies from the list (on the user's server).
  ///
  /// In en, this message translates to:
  /// **'Clear finished'**
  String get discoverCopiesClearFinished;

  /// Copies sheet empty state: the server is copying nothing and nothing failed.
  ///
  /// In en, this message translates to:
  /// **'Nothing copying'**
  String get discoverCopiesEmpty;

  /// Copies sheet empty state: how a copy starts.
  ///
  /// In en, this message translates to:
  /// **'Long-press a connected server\'s song or album on Discover to keep a copy.'**
  String get discoverCopiesEmptySub;

  /// Copies sheet empty state (opened from the home): a pill that opens the Discover page.
  ///
  /// In en, this message translates to:
  /// **'Open Discover'**
  String get discoverCopiesOpenDiscover;

  /// Copies sheet error state: the list of copies could not be read from the user's server.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your copies'**
  String get discoverCopiesLoadFailed;

  /// Copies sheet error state's second line when the server sent no words of its own (copies run on the server, not the phone).
  ///
  /// In en, this message translates to:
  /// **'Your server didn\'t answer. Copies keep running there.'**
  String get discoverCopiesLoadFailedSub;

  /// Accessible label of the Copies sheet's loading placeholders.
  ///
  /// In en, this message translates to:
  /// **'Loading your copies'**
  String get discoverCopiesLoading;

  /// Copies sheet row: what a copy takes (first part of 'Song · Artist · from Server').
  ///
  /// In en, this message translates to:
  /// **'Song'**
  String get discoverCopiesKindSong;

  /// Copies sheet row: what a copy takes (first part of 'Album · Artist · from Server').
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get discoverCopiesKindAlbum;

  /// Copies sheet row: a copy of every album by an artist (first part of 'Every album · from Server').
  ///
  /// In en, this message translates to:
  /// **'Every album'**
  String get discoverCopiesKindEvery;

  /// Copies sheet row: a copy of only the artist's albums the library lacks (first part of 'What you're missing · from Server').
  ///
  /// In en, this message translates to:
  /// **'What you\'re missing'**
  String get discoverCopiesKindMissing;

  /// Copies sheet row: the connected server a copy comes from (last part of 'Song · Artist · from Server').
  ///
  /// In en, this message translates to:
  /// **'from {peer}'**
  String discoverCopiesFrom(String peer);

  /// Copies sheet row title for a copy of every album by an artist.
  ///
  /// In en, this message translates to:
  /// **'Every album by {artist}'**
  String discoverCopiesEveryAlbumBy(String artist);

  /// Copies sheet row title for a copy of only the artist's albums the library lacks.
  ///
  /// In en, this message translates to:
  /// **'{artist} · albums you don\'t have'**
  String discoverCopiesMissingOf(String artist);

  /// Toast when Cancel reached the server after the copy had already ended (the row turns into its outcome).
  ///
  /// In en, this message translates to:
  /// **'Already finished · nothing to cancel'**
  String get discoverCopiesAlreadyFinished;

  /// Toast when a copy's Cancel could not reach the user's server.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel. Try again.'**
  String get discoverCopiesCancelFailed;

  /// Toast when a Retry or Add again from the Copies list was not started because where the account's copies land changed since that copy ran. Keep a copy (on the song or album sheet) shows the new place.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start: where files land changed — retry it from Keep a copy'**
  String get discoverCopiesDestChanged;

  /// Toast once the sheet that started a copy closes: the song or album title, and the connected server it is copied from.
  ///
  /// In en, this message translates to:
  /// **'Copying {title} from {peer}'**
  String discoverToastCopying(String title, String peer);

  /// Toast once the sheet that started an every-album copy closes.
  ///
  /// In en, this message translates to:
  /// **'Copying every album by {artist} from {peer}'**
  String discoverToastCopyingEvery(String artist, String peer);

  /// Toast once the sheet that started an only-the-albums-you-don't-have copy closes.
  ///
  /// In en, this message translates to:
  /// **'Copying the albums by {artist} you don\'t have from {peer}'**
  String discoverToastCopyingMissing(String artist, String peer);

  /// Toast when a copy the phone saw running ends with something copied into the user's library.
  ///
  /// In en, this message translates to:
  /// **'Added to your collection'**
  String get discoverToastAdded;

  /// Toast when a copy ends having copied nothing because the library already had it all.
  ///
  /// In en, this message translates to:
  /// **'Already in your library'**
  String get discoverToastAlreadyYours;

  /// Toast when a copy fails; {reason} is the server's own words (or what the counts say).
  ///
  /// In en, this message translates to:
  /// **'Copy failed: {reason}'**
  String discoverToastFailed(String reason);

  /// Toast when a copy ends early (the connected server's transfer limit, busy, gone, or refusing copies); {reason} says which.
  ///
  /// In en, this message translates to:
  /// **'Stopped early: {reason}'**
  String discoverToastStopped(String reason);

  /// Toast when an Open elsewhere link could not be opened outside the app.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open that link'**
  String get discoverToastLinkFailed;

  /// Toast after the destination picker saved: {path} is the library and the folders every copy lands in whatever its tags (the layout's leading folders that name no variable), e.g. 'copies › From peers'.
  ///
  /// In en, this message translates to:
  /// **'Saved · copies land in {path}'**
  String discoverToastSaved(String path);

  /// Title of the destination picker sheet (where on the user's server copies from connected servers are put).
  ///
  /// In en, this message translates to:
  /// **'Where copies land'**
  String get discoverDestTitle;

  /// Destination picker subtitle: the destination is one setting per account, shared by every copy.
  ///
  /// In en, this message translates to:
  /// **'One setting for your account · every copy uses it'**
  String get discoverDestSub;

  /// Destination picker tag beside the title: the library's own default destination is in force.
  ///
  /// In en, this message translates to:
  /// **'library default'**
  String get discoverDestTagDefault;

  /// Destination picker tag beside the title: the account's own saved destination is in force.
  ///
  /// In en, this message translates to:
  /// **'yours'**
  String get discoverDestTagYours;

  /// Destination picker preview label above the path where this song would be copied; {title} is the song's title.
  ///
  /// In en, this message translates to:
  /// **'{title} lands at'**
  String discoverDestLandsAt(String title);

  /// Destination picker preview while the chosen layout would be refused.
  ///
  /// In en, this message translates to:
  /// **'Fix the layout to see where files land'**
  String get discoverDestFixLayout;

  /// Destination picker preview: the layout is fine, but for this song (long tags, deep folders on the connected server) it would render a path longer than the server takes, so the server would refuse the copy; {max} is the limit (500).
  ///
  /// In en, this message translates to:
  /// **'This song\'s path would pass {max} characters, more than the server takes'**
  String discoverDestPathTooLong(int max);

  /// Destination picker section label (drawn in capitals): the libraries this account can add files to.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get discoverDestLibrary;

  /// Destination picker section label (drawn in capitals): how folders are made from the tags.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get discoverDestLayout;

  /// Destination picker layout preset: a folder per artist, then per album.
  ///
  /// In en, this message translates to:
  /// **'Artist / Album'**
  String get discoverDestPresetArtistAlbum;

  /// Destination picker layout preset: a folder named after the connected server, then artist, then album.
  ///
  /// In en, this message translates to:
  /// **'Server / Artist / Album'**
  String get discoverDestPresetServer;

  /// Destination picker layout preset: each copied song goes into the same folders it sits in on the connected server (that server's library itself left out), like 'Boukmanflow › Borrowed Tapes'.
  ///
  /// In en, this message translates to:
  /// **'Same folders as the server'**
  String get discoverDestPresetServerFolders;

  /// Destination picker layout preset: the chosen library's own path template (shown only when it has one).
  ///
  /// In en, this message translates to:
  /// **'Library layout'**
  String get discoverDestPresetLibrary;

  /// Destination picker layout choice: a layout the user types by hand (its text field opens under it). Also chosen when the layout in force is none of the presets.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get discoverDestPresetCustom;

  /// Destination picker: the line under the Custom layout choice.
  ///
  /// In en, this message translates to:
  /// **'Type your own path'**
  String get discoverDestCustomSub;

  /// Accessible name of the destination picker's custom layout text field.
  ///
  /// In en, this message translates to:
  /// **'Custom layout'**
  String get discoverDestCustomField;

  /// Destination picker custom layout field placeholder: a plain folder name (translate it) or {example}, a layout with variables kept as is (like {{ARTIST}}/{{ALBUM}}).
  ///
  /// In en, this message translates to:
  /// **'e.g. From friends or {example}'**
  String discoverDestCustomHint(String example);

  /// Destination picker help under the custom layout field: "/" makes folders; variables (the buttons above it) sort copies by their tags; plain text is the same folder for every copy.
  ///
  /// In en, this message translates to:
  /// **'Use / between folders. Variables sort copies by artist, album…; a plain name puts every copy in the same folder.'**
  String get discoverDestCustomHelp;

  /// Destination picker preview while the custom layout field is empty.
  ///
  /// In en, this message translates to:
  /// **'Type a path to see where files land'**
  String get discoverDestCustomEmpty;

  /// Accessible name of the destination picker button that inserts the artist variable into the custom layout.
  ///
  /// In en, this message translates to:
  /// **'Insert artist'**
  String get discoverDestInsertArtist;

  /// Accessible name of the destination picker button that inserts the album variable into the custom layout.
  ///
  /// In en, this message translates to:
  /// **'Insert album'**
  String get discoverDestInsertAlbum;

  /// Accessible name of the destination picker button that inserts the year variable into the custom layout.
  ///
  /// In en, this message translates to:
  /// **'Insert year'**
  String get discoverDestInsertYear;

  /// Accessible name of the destination picker button that inserts the genre variable into the custom layout.
  ///
  /// In en, this message translates to:
  /// **'Insert genre'**
  String get discoverDestInsertGenre;

  /// Accessible name of the destination picker button that inserts the album artist variable (the album's credit) into the custom layout.
  ///
  /// In en, this message translates to:
  /// **'Insert album artist'**
  String get discoverDestInsertAlbumArtist;

  /// Accessible name of the destination picker button that inserts the variable for the name of the connected server the copy comes from.
  ///
  /// In en, this message translates to:
  /// **'Insert server name'**
  String get discoverDestInsertPeer;

  /// Accessible name of the destination picker button that inserts the variable for the folders the song sits in on the connected server the copy comes from (it can be several folders).
  ///
  /// In en, this message translates to:
  /// **'Insert server folder'**
  String get discoverDestInsertServerFolder;

  /// Destination picker, under the custom layout field: it names a variable that does not exist; {name} is it in its braces (like {{ARTST}}), {vars} the variables there are (like ARTIST, ALBUM).
  ///
  /// In en, this message translates to:
  /// **'Unknown variable {name}. Use {vars}.'**
  String discoverDestErrUnknownVar(String name, String vars);

  /// Destination picker, under the custom layout field: a single or unmatched brace; {example} is a variable in its double braces (like {{ARTIST}}).
  ///
  /// In en, this message translates to:
  /// **'A brace is out of place — variables are written like {example}.'**
  String discoverDestErrBraces(String example);

  /// Destination picker, under the custom layout field: a base folder saved on the web app or the terminal (the phone holds it at the start of the layout) has a brace in its name, like {{PEER}}, which a layout reads as a variable — saved as it is, copies would land elsewhere, so Save waits until it is renamed or a preset layout is chosen. {folder} is that folder's name.
  ///
  /// In en, this message translates to:
  /// **'“{folder}” is a folder set on another device, but in a layout it reads as a variable. Rename it here, or choose a layout.'**
  String discoverDestErrBaseBraces(String folder);

  /// Destination picker, under the custom layout field: it starts with a slash; a layout is relative to the chosen library.
  ///
  /// In en, this message translates to:
  /// **'A layout can\'t start with / — it begins inside the library.'**
  String get discoverDestErrAbsolute;

  /// Destination picker, under the custom layout field: it has a ".." segment (a folder that climbs out).
  ///
  /// In en, this message translates to:
  /// **'A path can\'t contain .. folders.'**
  String get discoverDestErrTraversal;

  /// Destination picker, under the custom layout field: it renders to no folder at all (only spaces or slashes).
  ///
  /// In en, this message translates to:
  /// **'That makes no folder — add a name or a variable.'**
  String get discoverDestErrEmpty;

  /// Destination picker, under the custom layout field: it contains a tilde or $HOME (a home folder reference), which the server refuses. Keep ~ and $HOME as they are.
  ///
  /// In en, this message translates to:
  /// **'A path can\'t contain ~ or \$HOME.'**
  String get discoverDestErrHome;

  /// Destination picker, under the custom layout field: the server would refuse it for another reason.
  ///
  /// In en, this message translates to:
  /// **'That path can\'t be used.'**
  String get discoverDestErrGeneric;

  /// Destination picker, under the custom layout field: it starts a folder with a Windows drive letter (like C:), which the server refuses.
  ///
  /// In en, this message translates to:
  /// **'A path can\'t use a drive letter like C:.'**
  String get discoverDestErrDrive;

  /// Destination picker, under the custom layout field: it is longer than the server takes; {max} is the limit (500).
  ///
  /// In en, this message translates to:
  /// **'A layout can be at most {max} characters.'**
  String discoverDestErrTooLong(int max);

  /// Destination picker, under the custom layout field: it contains a tab, a line break or another control character (usually pasted).
  ///
  /// In en, this message translates to:
  /// **'A path can\'t contain tabs or other control characters.'**
  String get discoverDestErrControl;

  /// Destination picker preview, under the path: the layout's variables that this song has no tag for, so their part of the path is left out; {vars} lists them as typed (like {{YEAR}}, {{ALBUM}}).
  ///
  /// In en, this message translates to:
  /// **'No value for this song, so left out of the path: {vars}'**
  String discoverDestMissing(String vars);

  /// Keep a copy paths not landed yet (Files go to, Retry adds to, the every-album question, the destination picker preview): the word that stands in for the genre folder, shown between ‹ › marks ('copies › ‹genre› › Boukmanflow'). Each song files under its own file's genre tag, which the phone cannot always tell.
  ///
  /// In en, this message translates to:
  /// **'genre'**
  String get discoverDestGenreSlot;

  /// Keep a copy paths not landed yet: the word that stands in for the artist folder, shown between ‹ › marks ('copies › From friends › ‹artist›'), when the songs a copy takes are by different artists (a compilation) — each song files under its own artist tag.
  ///
  /// In en, this message translates to:
  /// **'artist'**
  String get discoverDestArtistSlot;

  /// Keep a copy paths not landed yet: the word that stands in for the year folder, shown between ‹ › marks ('copies › Boukmanflow › ‹year›'), when the songs a copy takes carry different years — each song files under its own year tag.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get discoverDestYearSlot;

  /// Keep a copy paths not landed yet: the words that stand in for the folders a song sits in on the connected server, shown between ‹ › marks ('copies › ‹server folder›'), when the songs a copy takes sit in different folders there — each song lands in its own server folder.
  ///
  /// In en, this message translates to:
  /// **'server folder'**
  String get discoverDestServerFolderSlot;

  /// Keep a copy, one quiet line under a path not landed yet that shows stand-ins: {slots} lists them as shown, joined with ', ' (like '‹artist›' or '‹artist›, ‹year›'); {count} is how many. The server files each song by its own tags, so the copy can land in several folders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{slots} comes from each song\'s own tags, so these songs can land in more than one folder.} other{{slots} come from each song\'s own tags, so these songs can land in more than one folder.}}'**
  String discoverKeepSlotNote(int count, String slots);

  /// The same line as discoverKeepSlotNote when the stand-ins include the genre (like '‹genre›' or '‹artist›, ‹genre›'): a song whose file has no genre tag files without the genre folder.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{slots} comes from each song\'s own tags, so these songs can land in more than one folder (a song with none leaves that folder out).} other{{slots} come from each song\'s own tags, so these songs can land in more than one folder (a song with none leaves that folder out).}}'**
  String discoverKeepSlotNoteGenre(int count, String slots);

  /// The same line as discoverKeepSlotNote for a copy of ONE song (This song, and the destination picker's preview of one song): only the genre can stand in there, and one song lands in one folder. {slots} is the stand-in as shown (like '‹genre›'); a song whose file has no genre tag files without the genre folder.
  ///
  /// In en, this message translates to:
  /// **'{slots} comes from the song\'s own tags (a song with none leaves that folder out).'**
  String discoverKeepSlotNoteSong(String slots);

  /// The same line as discoverKeepSlotNote when the only stand-in is the server folder: {server} is it as shown (like '‹server folder›'). Each song lands in the folders it sits in on the connected server, so the copy can land in several folders.
  ///
  /// In en, this message translates to:
  /// **'{server} comes from where each song sits on the server, so these songs can land in more than one folder.'**
  String discoverKeepSlotNoteServer(String server);

  /// The same line as discoverKeepSlotNote when the stand-ins are some of the tags AND the server folder: {slots} lists the tag ones as shown, joined with ', ' (like '‹artist›' or '‹artist›, ‹year›'), {count} is how many of those; {server} is the server folder's stand-in as shown (like '‹server folder›').
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{slots} comes from each song\'s own tags and {server} from where it sits on the server, so these songs can land in more than one folder.} other{{slots} come from each song\'s own tags and {server} from where it sits on the server, so these songs can land in more than one folder.}}'**
  String discoverKeepSlotNoteServerTags(int count, String slots, String server);

  /// The same line as discoverKeepSlotNoteServerTags when the tag stand-ins include the genre: a song whose file has no genre tag files without the genre folder.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{slots} comes from each song\'s own tags and {server} from where it sits on the server, so these songs can land in more than one folder (a song with none leaves that folder out).} other{{slots} come from each song\'s own tags and {server} from where it sits on the server, so these songs can land in more than one folder (a song with none leaves that folder out).}}'**
  String discoverKeepSlotNoteServerTagsGenre(
    int count,
    String slots,
    String server,
  );

  /// Destination picker text button: drops the account's saved destination and goes back to the library default.
  ///
  /// In en, this message translates to:
  /// **'Use the library default'**
  String get discoverDestUseDefault;

  /// Destination picker Save button while the save is in flight.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get discoverDestSaving;

  /// Destination picker error state: the destination could not be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load where copies land'**
  String get discoverDestLoadFailed;

  /// Accessible label of the destination picker's loading placeholders.
  ///
  /// In en, this message translates to:
  /// **'Loading where copies land'**
  String get discoverDestLoading;

  /// Keep a copy card's first-use note above the destination line, shown until the first copy starts or a destination is saved.
  ///
  /// In en, this message translates to:
  /// **'Copies go to your server, not this phone. Check where they land before the first one.'**
  String get discoverKeepFirstUse;

  /// Open elsewhere section label (drawn in capitals): pages for this exact recording on MusicBrainz.
  ///
  /// In en, this message translates to:
  /// **'Exact pages'**
  String get discoverElsewhereExact;

  /// Open elsewhere section label (drawn in capitals): searches on other catalogues (the rows are the catalogues' own names).
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get discoverElsewhereSearch;

  /// Open elsewhere row: the MusicBrainz page of this recording.
  ///
  /// In en, this message translates to:
  /// **'MusicBrainz recording'**
  String get discoverElsewhereMbRecording;

  /// Open elsewhere row: the MusicBrainz page of the release group (the album).
  ///
  /// In en, this message translates to:
  /// **'MusicBrainz release group'**
  String get discoverElsewhereMbReleaseGroup;

  /// Open elsewhere row: the MusicBrainz page of the recording's ISRC code.
  ///
  /// In en, this message translates to:
  /// **'MusicBrainz ISRC'**
  String get discoverElsewhereMbIsrc;

  /// Open elsewhere empty state.
  ///
  /// In en, this message translates to:
  /// **'No links for this song'**
  String get discoverElsewhereEmpty;

  /// Open elsewhere empty state: why there are no links.
  ///
  /// In en, this message translates to:
  /// **'It has no MusicBrainz ids, and no title or artist to search for.'**
  String get discoverElsewhereEmptySub;

  /// Open elsewhere error state; the server's own words, when it sent some, show under it.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t look up links right now'**
  String get discoverElsewhereFailed;

  /// Accessible label of Open elsewhere's loading placeholders.
  ///
  /// In en, this message translates to:
  /// **'Looking up links'**
  String get discoverElsewhereLoading;

  /// Accessibility hint on an Open elsewhere row.
  ///
  /// In en, this message translates to:
  /// **'Opens outside the app'**
  String get discoverElsewhereOpensOutside;

  /// Drawer entries that open each visualizer. Milkdrop and ShaderToy are product names: keep them as written.
  ///
  /// In en, this message translates to:
  /// **'Milkdrop Visualizer'**
  String get visualizerMilkdropTitle;

  /// No description provided for @visualizerShadertoyTitle.
  ///
  /// In en, this message translates to:
  /// **'ShaderToy Visualizer'**
  String get visualizerShadertoyTitle;

  /// Real-audio consent dialog: the line under the explanation, then the checkbox (offered only when a visualizer is being opened) and the two buttons.
  ///
  /// In en, this message translates to:
  /// **'Without the permission, the visualizer runs on synthesized data instead.'**
  String get realAudioSynthesizedNote;

  /// No description provided for @realAudioDontAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again'**
  String get realAudioDontAskAgain;

  /// No description provided for @realAudioUseSynthesized.
  ///
  /// In en, this message translates to:
  /// **'Use synthesized data'**
  String get realAudioUseSynthesized;

  /// No description provided for @realAudioUseReal.
  ///
  /// In en, this message translates to:
  /// **'Use real audio'**
  String get realAudioUseReal;

  /// Now-playing queue ⋮ menu: opens the Share Playlist dialog for the queue. Sentence case like the menu's other rows.
  ///
  /// In en, this message translates to:
  /// **'Share playlist'**
  String get queueSharePlaylist;

  /// No description provided for @keepOffline.
  ///
  /// In en, this message translates to:
  /// **'Keep offline'**
  String get keepOffline;

  /// No description provided for @keepOfflineOn.
  ///
  /// In en, this message translates to:
  /// **'Kept offline'**
  String get keepOfflineOn;

  /// No description provided for @keepOfflineHelp.
  ///
  /// In en, this message translates to:
  /// **'Downloaded and kept in sync on this device.'**
  String get keepOfflineHelp;

  /// No description provided for @keepRatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep rated songs offline'**
  String get keepRatedTitle;

  /// No description provided for @keepRatedStars.
  ///
  /// In en, this message translates to:
  /// **'{n} stars and up'**
  String keepRatedStars(int n);

  /// No description provided for @keepRatedFiveStars.
  ///
  /// In en, this message translates to:
  /// **'5 stars'**
  String get keepRatedFiveStars;

  /// No description provided for @keptOfflineSection.
  ///
  /// In en, this message translates to:
  /// **'Also kept offline'**
  String get keptOfflineSection;

  /// No description provided for @keptOfflineNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. \"Keep offline\" lives on albums, artists, playlists and folders.'**
  String get keptOfflineNone;

  /// No description provided for @keepQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Quality of kept items'**
  String get keepQualityTitle;

  /// No description provided for @keepQualityHelp.
  ///
  /// In en, this message translates to:
  /// **'Albums, artists, playlists, folders and rated songs kept offline are stored at this quality. Whole-library copies always keep the original files.'**
  String get keepQualityHelp;

  /// No description provided for @keepQualityOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original files'**
  String get keepQualityOriginal;

  /// No description provided for @keepQualityTier.
  ///
  /// In en, this message translates to:
  /// **'{codec} · {kbps} kbps'**
  String keepQualityTier(String codec, int kbps);

  /// No description provided for @browserSectionOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get browserSectionOffline;

  /// No description provided for @browserBrowseOffline.
  ///
  /// In en, this message translates to:
  /// **'Browse offline'**
  String get browserBrowseOffline;

  /// No description provided for @browserBackOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get browserBackOnline;

  /// No description provided for @browserOfflineReady.
  ///
  /// In en, this message translates to:
  /// **'Local copy'**
  String get browserOfflineReady;

  /// No description provided for @browserOfflineNone.
  ///
  /// In en, this message translates to:
  /// **'No copy yet'**
  String get browserOfflineNone;

  /// No description provided for @browserOfflineOn.
  ///
  /// In en, this message translates to:
  /// **'Using the local copy'**
  String get browserOfflineOn;

  /// No description provided for @browserOfflineAuto.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable'**
  String get browserOfflineAuto;

  /// No description provided for @offlineHeaderStatus.
  ///
  /// In en, this message translates to:
  /// **'{files} files · {size}'**
  String offlineHeaderStatus(int files, String size);

  /// No description provided for @keepFolderHelp.
  ///
  /// In en, this message translates to:
  /// **'This folder and everything in it, kept in sync on this device.'**
  String get keepFolderHelp;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'ja',
    'pl',
    'pt',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
