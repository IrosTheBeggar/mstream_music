import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';

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
    Locale('pt'),
  ];

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

  /// VisualizerEngine option label.
  ///
  /// In en, this message translates to:
  /// **'Milkdrop'**
  String get visualizerEngineMilkdrop;

  /// No description provided for @visualizerEngineShaders.
  ///
  /// In en, this message translates to:
  /// **'Shaders'**
  String get visualizerEngineShaders;

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
  /// **'Start a song to configure the EQ.\n\nAndroid\'s native equalizer initializes with the audio session, so we need playback to be active before we can read the band layout.'**
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

  /// Tap-behavior picker row label + per-mode subtitles.
  ///
  /// In en, this message translates to:
  /// **'When you tap a song'**
  String get settingsTapBehavior;

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

  /// Subtitle on the Equalizer row in Settings.
  ///
  /// In en, this message translates to:
  /// **'Tune bass, mids, and treble. Android only.'**
  String get settingsEqSubtitle;

  /// Visualizer-engine picker row label + per-engine subtitles.
  ///
  /// In en, this message translates to:
  /// **'Visualizer engine'**
  String get settingsVisualizerEngine;

  /// No description provided for @visualizerEngineSubtitleMilkdrop.
  ///
  /// In en, this message translates to:
  /// **'Milkdrop presets via projectM (default). Richer effects, heavier on the GPU.'**
  String get visualizerEngineSubtitleMilkdrop;

  /// No description provided for @visualizerEngineSubtitleShaders.
  ///
  /// In en, this message translates to:
  /// **'Shadertoy-style fragment shaders. Lighter, modular — drop .glsl files in assets/shaders/ to extend the catalog.'**
  String get visualizerEngineSubtitleShaders;

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

  /// RECORD_AUDIO consent dialog + denial snackbars.
  ///
  /// In en, this message translates to:
  /// **'Use real audio?'**
  String get realAudioDialogTitle;

  /// No description provided for @realAudioDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Real audio mode reads the waveform of music your phone is playing so the visualizer can react to it. Android requires the RECORD_AUDIO permission for this — the app does not record or send any audio anywhere. You can switch back to synthesized at any time.'**
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

  /// No description provided for @testCouldNotConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check the URL and try again.'**
  String get testCouldNotConnect;

  /// No description provided for @testTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out.'**
  String get testTimedOut;

  /// No description provided for @connectFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to server. Check the URL and try again.'**
  String get connectFailedSnack;

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

  /// Server-picker + sources section.
  ///
  /// In en, this message translates to:
  /// **'Active source'**
  String get autoDjActiveSource;

  /// No description provided for @autoDjActiveSourceTap.
  ///
  /// In en, this message translates to:
  /// **'Active source — tap to switch'**
  String get autoDjActiveSourceTap;

  /// No description provided for @autoDjSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get autoDjSwitch;

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

  /// No description provided for @visualizerTitle.
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get visualizerTitle;

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
  /// **'{count, plural, =1{1 track in queue} other{{count} tracks in queue}}'**
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
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'pt'].contains(locale.languageCode);

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
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
