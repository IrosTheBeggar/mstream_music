// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get mainRemove => 'Remove';

  @override
  String get playlistActionFailed =>
      'Couldn\'t save the playlist — the name may already be in use.';

  @override
  String get queueAddNext => 'Add next';

  @override
  String get queuePlayNow => 'Play now';

  @override
  String get queueAddToEnd => 'Add to end of queue';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get variousArtists => 'Various Artists';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get settingsLanguageSubtitle =>
      'The app\'s display language. \"System default\" follows your device.';

  @override
  String couldNotOpen(String url) {
    return 'Could not open $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
      zero: 'No tracks',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Reset';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get tapAddToQueue => 'Add to queue';

  @override
  String get tapPlayFromHere => 'Play from here';

  @override
  String get tapAppendAndJump => 'Add and play';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'Shaders';

  @override
  String get visualizerSourceSynthesized => 'Synthesized';

  @override
  String get visualizerSourceReal => 'Real audio';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String downloadProgress(String progress) {
    return 'progress: $progress%';
  }

  @override
  String get songInfoTitle => 'Song Info';

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsEmpty => 'No lyrics found for this song';

  @override
  String get lyricsError => 'Couldn\'t load lyrics';

  @override
  String get lyricsRetry => 'Retry';

  @override
  String get eqTitle => 'Equalizer';

  @override
  String get eqOnlyAndroid => 'Equalizer is only available on Android.';

  @override
  String get eqNeedsPlayback =>
      'Start a song to configure the EQ.\n\nAndroid\'s native equalizer initializes with the audio session, so we need playback to be active before we can read the band layout.';

  @override
  String eqInitFailed(String error) {
    return 'Could not initialize equalizer:\n$error';
  }

  @override
  String get eqNoBands =>
      'No EQ bands reported by this device\'s audio driver.';

  @override
  String get eqDisabledHint => 'Turn on the equalizer to adjust the bands.';

  @override
  String get eqEnabledOn => 'On — gains applied to playback';

  @override
  String get eqEnabledOff => 'Off — bypass mode';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get openSettings => 'Open settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionPlayback => 'Playback';

  @override
  String get settingsSectionBrowse => 'Browse';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSubtitleVelvet =>
      'Navy and purple — the signature dark theme.';

  @override
  String get themeSubtitleDark => 'Neutral dark with amber accents.';

  @override
  String get themeSubtitleLight =>
      'Light body with a dark app bar and amber accents — matches the older shipped theme.';

  @override
  String get settingsTranscode => 'Transcode audio';

  @override
  String get settingsTranscodeSubtitle =>
      'Stream a transcoded copy from the server (smaller files, slightly slower start). Off plays original files.';

  @override
  String get transcodeTitle => 'Transcoding';

  @override
  String get transcodeCodec => 'Codec';

  @override
  String get transcodeBitrate => 'Bitrate';

  @override
  String get transcodeAuto => 'Server default';

  @override
  String get transcodeUnavailable =>
      'This server doesn\'t have transcoding enabled — its tracks stream in original quality.';

  @override
  String get transcodeReloadQueue => 'Apply to current queue';

  @override
  String get transcodeReloadQueueSubtitle =>
      'When you change transcoding settings — checked: reload the whole queue now (the playing track briefly re-buffers); unchecked: only upcoming tracks change, the current one finishes as-is.';

  @override
  String get settingsTapBehavior => 'When you tap a song';

  @override
  String get settingsStartupPage => 'Startup page';

  @override
  String get settingsStartupPageSubtitle =>
      'Open the app to this browser view; Back returns to the browser.';

  @override
  String get tapSubtitleAddToQueue =>
      'Tapping a song appends it to the queue. If the queue is empty, playback starts automatically.';

  @override
  String get tapSubtitlePlayFromHere =>
      'Tapping a song replaces the queue with the songs in the current view and starts playback at the tapped song.';

  @override
  String get tapSubtitleAppendAndJump =>
      'Tapping a song appends it to the queue and jumps playback to it, interrupting whatever was playing.';

  @override
  String get settingsEqSubtitle => 'Tune bass, mids, and treble. Android only.';

  @override
  String get settingsVisualizerEngine => 'Visualizer engine';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'Milkdrop presets via projectM (default). Richer effects, heavier on the GPU.';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Shadertoy-style fragment shaders. Lighter, modular — drop .glsl files in assets/shaders/ to extend the catalog.';

  @override
  String get settingsVisualizerSource => 'Visualizer audio source';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'Default. Visualizer reacts to playback timing only — no microphone permission required.';

  @override
  String get visualizerSourceSubtitleReal =>
      'Visualizer reacts to actual audio output. Requires the RECORD_AUDIO permission on Android.';

  @override
  String get settingsAlbumGrid => 'Album grid view';

  @override
  String get settingsAlbumGridSubtitle =>
      'Show albums as a grid of cards with cover art instead of a plain list.';

  @override
  String get settingsFileMetadata => 'Read song metadata in file explorer';

  @override
  String get settingsFileMetadataSubtitle =>
      'Fetch title, artist, and album art for each song when browsing server files. Off shows raw filenames (faster for huge folders).';

  @override
  String get settingsLetterStrip => 'Letter scrubber threshold';

  @override
  String get settingsLetterStripSubtitle =>
      'Show the A-Z quick-scrub strip when a list has this many items or more. Below this size the strip is hidden and long folder/file names wrap to multiple lines instead of being truncated. Set 0 to always show the strip.';

  @override
  String get settingsLetterStripSide => 'Scrubber side';

  @override
  String get settingsLetterStripSideSubtitle =>
      'Which edge the A–Z strip sits on.';

  @override
  String get settingsLetterStripLeft => 'Left';

  @override
  String get settingsLetterStripRight => 'Right';

  @override
  String get settingsReset => 'Reset to defaults';

  @override
  String get settingsResetSubtitle =>
      'Restore all settings on this screen to their default values. Servers and downloads are not affected.';

  @override
  String get settingsResetDone => 'Settings restored to defaults';

  @override
  String get realAudioDialogTitle => 'Use real audio?';

  @override
  String get realAudioDialogBody =>
      'Real audio mode reads the waveform of music your phone is playing so the visualizer can react to it. Android requires the RECORD_AUDIO permission for this — the app does not record or send any audio anywhere. You can switch back to synthesized at any time.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Permission permanently denied. Enable it in system settings to use real audio.';

  @override
  String get realAudioPermDenied =>
      'Permission denied. Staying on synthesized audio.';

  @override
  String get visualizerTapHint =>
      'Tap = next preset · back arrow (top-left) or long-press to exit';

  @override
  String get visualizerFailed => 'Visualizer failed to start';

  @override
  String get visualizerBringingUp => 'Bringing up renderer…';

  @override
  String get visualizerReady => 'Visualizer ready';

  @override
  String get visualizerBridgeFailed => 'Bridge failed to start';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Audio source: $source';
  }

  @override
  String get visualizerTapToClose => 'Tap anywhere to close';

  @override
  String get visualizerUnsupported =>
      'Visualizer is currently only supported on Android.';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutBuiltBy(String name) {
    return 'Built by $name';
  }

  @override
  String get linkDiscordSubtitle => 'Community chat';

  @override
  String get linkGithubSubtitle => 'mStream server source';

  @override
  String get linkHomepageSubtitle => 'Project homepage';

  @override
  String get aboutAttributions => 'Attributions';

  @override
  String get aboutAttributionsSubtitle =>
      'License, shader credits, and open-source notices.';

  @override
  String get aboutSponsor => 'Sponsor mStream';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get info => 'Info';

  @override
  String get makeDefault => 'Make Default';

  @override
  String get goBack => 'Go Back';

  @override
  String get play => 'Play';

  @override
  String get playAll => 'Play all';

  @override
  String get rename => 'Rename';

  @override
  String get create => 'Create';

  @override
  String get copy => 'Copy';

  @override
  String get done => 'Done';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get attributionsTitle => 'Attributions';

  @override
  String get attributionsSectionLicense => 'License';

  @override
  String get attributionsSectionShaders => 'Visualizer shaders';

  @override
  String get attributionsSectionLibraries => 'Native libraries';

  @override
  String get attributionsSectionEverythingElse => 'Everything else';

  @override
  String get attributionsLicenseBody =>
      'Free software under the GNU General Public License v3.0. You may use, study, share, and modify it under those terms.';

  @override
  String get attributionsPackages => 'Open-source package licenses';

  @override
  String get attributionsPackagesSubtitle =>
      'Full license texts for all bundled Flutter/Dart packages.';

  @override
  String get manageServersTitle => 'Manage Servers';

  @override
  String get manageServerInfo => 'Server Info';

  @override
  String get manageServerDownloadFolder => 'Download Folder:';

  @override
  String get manageServerCopyPath => 'Copy Download Path';

  @override
  String get manageServerPathCopied => 'Path Copied to Clipboard';

  @override
  String get confirmRemoveServerTitle => 'Confirm Remove Server';

  @override
  String get removeSyncedFiles => 'Remove synced files from device?';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistsNew => 'New playlist';

  @override
  String get playlistsEmptyTitle => 'No playlists yet';

  @override
  String get playlistsEmptyBody =>
      'Create one with the New playlist button, then use the queue\'s Add-to-playlist swipe action to fill it.';

  @override
  String get playlistNameHint => 'Name';

  @override
  String get playlistsRename => 'Rename playlist';

  @override
  String get playlistFallbackTitle => 'Playlist';

  @override
  String get playlistEmptyDetail =>
      'Playlist is empty.\nAdd tracks via the queue.';

  @override
  String get shareEmptyTitle => 'Empty queue';

  @override
  String get shareEmptyBody => 'Add songs to the queue before sharing.';

  @override
  String get shareBlockedTitle => 'Can\'t share this queue';

  @override
  String get shareLocalOnlyBody =>
      'The queue contains songs that are only on this device (not on any server). Sharing only works when every song in the queue comes from a single server.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'The queue mixes songs from $count servers ($names). Sharing only works when every song comes from a single server.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'The server \"$name\" is no longer in your server list. Re-add it to share its queue.';
  }

  @override
  String get shareTitle => 'Share Playlist';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0 from $url';
  }

  @override
  String get shareLinkExpires => 'Link expires';

  @override
  String get shareExpireNever => 'Never';

  @override
  String get shareExpire1Day => 'After 1 day';

  @override
  String get shareExpire7Days => 'After 7 days';

  @override
  String get shareExpire30Days => 'After 30 days';

  @override
  String get shareAction => 'Share';

  @override
  String get shareDoneTitle => 'Playlist shared';

  @override
  String get shareDoneBody => 'Anyone with this link can play the queue:';

  @override
  String get save => 'Save';

  @override
  String get start => 'Start';

  @override
  String get addServerTitle => 'Add Server';

  @override
  String get editServerTitle => 'Edit Server';

  @override
  String get fieldServerUrl => 'Server URL';

  @override
  String get fieldPublicAccess => 'Public access';

  @override
  String get publicAccessSubtitle =>
      'Server is publicly accessible — no username or password needed.';

  @override
  String get fieldUsername => 'Username';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldSdCard => 'Download to SD Card';

  @override
  String get sdCardSubtitle =>
      'Save downloaded music to the removable SD card instead of internal storage.';

  @override
  String get testConnectionButton => 'Test Connection';

  @override
  String get testing => 'Testing…';

  @override
  String get connecting => 'Connecting…';

  @override
  String get validatorUrlNeeded => 'Server URL is needed';

  @override
  String get validatorUrlParse => 'Cannot parse URL';

  @override
  String get testEnterUrl => 'Enter a server URL first.';

  @override
  String get testParseUrl => 'Could not parse URL.';

  @override
  String get testTimedOut => 'Connection timed out.';

  @override
  String get connectionSuccessful => 'Connection Successful!';

  @override
  String get couldNotReachServer =>
      'Could not reach server. If it requires login, turn off \"Public access\" and add credentials.';

  @override
  String get failedToLogin => 'Failed to Login';

  @override
  String testConnected(String version) {
    return 'Connected — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'Could not connect: $error';
  }

  @override
  String get sleepTimerTitle => 'Sleep timer';

  @override
  String get sleepTimerHint => 'Pick a duration to pause playback after.';

  @override
  String get sleepTimerCustom => 'Custom';

  @override
  String get sleepTimerCustomHint => 'minutes (1–600)';

  @override
  String get sleepTimerCancel => 'Cancel timer';

  @override
  String get sleepTimerInvalid => 'Enter a number between 1 and 600 minutes';

  @override
  String sleepTimerPausesIn(String time) {
    return 'Pauses in $time';
  }

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String sleepTimerSet(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Sleep timer set for $minutes minutes',
      one: 'Sleep timer set for 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Add';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String get autoDjAddServerFirst => 'Add a server first.';

  @override
  String get autoDjSectionServer => 'Server';

  @override
  String get autoDjSectionSources => 'Sources';

  @override
  String get autoDjSectionContinuity => 'Continuity';

  @override
  String get autoDjSectionFilters => 'Filters';

  @override
  String get autoDjBpmTitle => 'BPM continuity';

  @override
  String get autoDjBpmSubtitle =>
      'Prefer picks within a tempo window of the current song. Honours half/double-tempo equivalence.';

  @override
  String get autoDjTolerance => 'Tolerance';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Harmonic mixing';

  @override
  String get autoDjHarmonicSubtitle =>
      'Prefer picks in keys that mix well with the locked song (Camelot wheel neighbours).';

  @override
  String get autoDjDurationTitle => 'Track length';

  @override
  String get autoDjDurationSubtitle =>
      'Skip interludes and long mixes by only picking tracks in a length range';

  @override
  String get autoDjDurationRange => 'Length';

  @override
  String get autoDjDurationAny => 'Any length';

  @override
  String autoDjDurationOver(String min) {
    return 'Over $min';
  }

  @override
  String autoDjDurationUnder(String max) {
    return 'Under $max';
  }

  @override
  String autoDjDurationBetween(String min, String max) {
    return '$min to $max';
  }

  @override
  String get autoDjDurationAllowUnknown => 'Include tracks of unknown length';

  @override
  String get autoDjDurationAllowUnknownSub =>
      'Tracks your server has not read a length for are skipped otherwise';

  @override
  String get autoDjStatusOn => 'Auto DJ is on';

  @override
  String get autoDjStatusOff => 'Auto DJ is off';

  @override
  String get autoDjStatusOffDetail =>
      'Tap below to start. The current server\'s library will be used.';

  @override
  String get autoDjStart => 'Start Auto DJ';

  @override
  String get autoDjStop => 'Stop Auto DJ';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'Songs are picked from $url when the queue runs low.';
  }

  @override
  String get autoDjOneSourceRequired => 'At least one source is required.';

  @override
  String get autoDjMinRating => 'Minimum rating';

  @override
  String get autoDjMinRatingSubtitle =>
      'Only pick songs at or above this rating.';

  @override
  String get autoDjRatingAny => 'Any';

  @override
  String get autoDjGenreTitle => 'Genre filter';

  @override
  String get autoDjGenreSubtitle =>
      'Whitelist plays only matching tracks; blacklist skips them.';

  @override
  String get autoDjWhitelist => 'Whitelist';

  @override
  String get autoDjBlacklist => 'Blacklist';

  @override
  String get autoDjNoGenres =>
      'No genres selected. Tap \"Pick genres\" to choose.';

  @override
  String get autoDjPickGenres => 'Pick genres';

  @override
  String get autoDjGenreLoadError => 'Could not load genres';

  @override
  String get autoDjKeywordTitle => 'Keyword filter';

  @override
  String get autoDjKeywordSubtitle =>
      'Skip picks whose title, artist, album, or filepath contains any of these words.';

  @override
  String get autoDjNoKeywords =>
      'No keywords. Add words below to start filtering.';

  @override
  String get autoDjKeywordHint => 'e.g. \"live\" or \"remix\"';

  @override
  String get autoDjSearchGenres => 'Search genres…';

  @override
  String get autoDjNoGenresOnServer => 'No genres found on this server.';

  @override
  String autoDjSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return 'No genres match \"$query\".';
  }

  @override
  String get download => 'Download';

  @override
  String get addAll => 'Add All';

  @override
  String get browserMoreActions => 'More actions';

  @override
  String get browserConfirmDeletePlaylist => 'Confirm Delete Playlist';

  @override
  String get browserConfirmDeleteFolder => 'Confirm Delete Folder';

  @override
  String get browserSearchHint => 'Search Database';

  @override
  String get searchCategoriesTooltip => 'What to search';

  @override
  String get searchCategoriesHeader => 'Search in';

  @override
  String get searchCategoryArtists => 'Artists';

  @override
  String get searchCategoryAlbums => 'Albums';

  @override
  String get searchCategorySongs => 'Songs';

  @override
  String get searchCategoryFiles => 'Files';

  @override
  String get searchCategoryLyrics => 'Lyrics';

  @override
  String searchSubheaderResults(String term) {
    return 'Results for “$term”';
  }

  @override
  String searchSubheaderCategories(String categories) {
    return 'Searching: $categories';
  }

  @override
  String browserDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads started',
      one: '1 download started',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs added to queue',
      one: '1 song added to queue',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Browser';

  @override
  String get tabQueue => 'Queue';

  @override
  String get drawerTagline => 'Personal music streaming';

  @override
  String get mainFailedToConnect => 'Failed To Connect To Server';

  @override
  String get mainQueueEmpty => 'Queue is empty';

  @override
  String get visualizerTitle => 'Visualizer';

  @override
  String get mainClearQueue => 'Clear queue';

  @override
  String get mainSync => 'Sync';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ Enabled';

  @override
  String get autoDjDisabled => 'Auto DJ Disabled';

  @override
  String autoDjEnabledFor(String url) {
    return 'Auto DJ Enabled For $url';
  }

  @override
  String get addToPlaylistTitle => 'Add to playlist';

  @override
  String get addToPlaylistEmpty => 'No playlists yet — tap + to create one.';

  @override
  String addedToPlaylist(String name) {
    return 'Added to $name';
  }

  @override
  String get testConnectedSignedIn => 'Connected — signed in successfully.';

  @override
  String get testSignInFailed =>
      'Server reached, but sign-in failed — check your username and password.';

  @override
  String get browserFileExplorer => 'File Explorer';

  @override
  String get browserLocalFiles => 'Local Files';

  @override
  String get browserPlaylists => 'Playlists';

  @override
  String get browserAlbums => 'Albums';

  @override
  String get browserArtists => 'Artists';

  @override
  String get browserRecent => 'Recent';

  @override
  String get browserRated => 'Rated';

  @override
  String get browserSearch => 'Search';

  @override
  String get browserWelcomeTitle => 'Welcome to mStream';

  @override
  String get browserWelcomeSubtitle => 'Tap here to add a server';

  @override
  String get settingsVisualizerKnobs => 'Visualizer tuning knobs';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      'Show live sliders over the visualizer to tweak each shader\'s audio reactivity. Shader engine only.';

  @override
  String get visualizerTuningTitle => 'Tuning';

  @override
  String get close => 'Close';

  @override
  String get migMoveStopped =>
      'Move stopped — not enough space, or the location is unavailable.';

  @override
  String get migMoveComplete => 'Move complete';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Move complete — $count files skipped (unsupported on the destination)',
      one: 'Move complete — 1 file skipped (unsupported on the destination)',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'Moving downloads… $progress — keep the app open';
  }

  @override
  String get migRetry => 'Retry';

  @override
  String get queueDownloadAll => 'Download all';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks will be downloaded for offline playback.',
      one: '1 track will be downloaded for offline playback.',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'More';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get settingsCastQuality => 'Cast visualizer quality';

  @override
  String get settingsCastQualitySubtitle720 =>
      'Resolution the visualizer streams to a TV at. 720p — lightest on the phone.';

  @override
  String get settingsCastQualitySubtitle1080 =>
      'Resolution the visualizer streams to a TV at. 1080p — sharp on any Chromecast (default).';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Resolution the visualizer streams to a TV at. 4K — needs a 4K Chromecast; much heavier on the phone.';

  @override
  String get eqCasting =>
      'The equalizer adjusts audio on this device, so it’s unavailable while casting. Disconnect to use it.';

  @override
  String get browserNothingToDownload => 'Nothing to download in this list';

  @override
  String get browserDownloadAllTitle => 'Download all';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files will be downloaded.',
      one: '1 file will be downloaded.',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => 'Close search';

  @override
  String get browserSearchThisList => 'Search this list';

  @override
  String get browserSearchList => 'Search list';

  @override
  String browserNoMatches(String query) {
    return 'No matches for \"$query\"';
  }

  @override
  String get clear => 'Clear';

  @override
  String get dlLocationUnavailable => 'Download location unavailable';

  @override
  String get dlLocationUnavailableServer =>
      'Download location unavailable for this server.';

  @override
  String get dlFailed => 'A download failed — check your connection.';

  @override
  String get dlFatSkip =>
      'Some tracks can\'t be saved on this card — their names aren\'t supported. They stream instead.';

  @override
  String get dlServerGone => 'That server is no longer configured.';

  @override
  String get dlStorageUnavailable =>
      'Storage location unavailable — reconnect the SD card or change this server\'s storage location in Edit Server.';

  @override
  String get dlCouldNotStart =>
      'Could not start download — storage unavailable.';

  @override
  String get storageLocationLabel => 'Storage location';

  @override
  String get storageAppLocal => 'App local';

  @override
  String get storagePermanent => 'Permanent';

  @override
  String get storageSdCard => 'SD card';

  @override
  String get storageSdSwitchTitle => 'Save to SD card';

  @override
  String get storageSdSwitchSubtitle =>
      'Stored in the SD card\'s app folder — no permission needed, but removed if you uninstall the app.';

  @override
  String get storageHelpAppLocal =>
      'Saved inside the app. Deleted when you uninstall or clear the app.';

  @override
  String get storageHelpPermanent =>
      'Saved to a folder you choose. Survives uninstalling the app. Requires \"All files access\".';

  @override
  String get storageHelpSdCard =>
      'Saved to a folder on the SD card you choose. May become unavailable if the card is removed. Some devices don\'t let apps write to SD cards — if folder selection keeps failing, use Permanent or App local.';

  @override
  String get storageChooseFolder => 'Choose folder';

  @override
  String get storageNoFolderChosen => 'No folder chosen yet';

  @override
  String get storageDownloadFolderLabel => 'Download folder';

  @override
  String get storageDownloadFolderHint => 'folder name';

  @override
  String get storageBrowse => 'Browse';

  @override
  String get storageDownloadFolderHelp =>
      'Files download to a \'media/<folder>\' directory on this device. Re-using a previous server\'s folder keeps its downloaded songs when you re-add a lost server.';

  @override
  String get storageNoStorageAvailable => 'No storage available';

  @override
  String get storageNoDownloadFolders => 'No existing download folders found';

  @override
  String get storageExistingFolders => 'Existing download folders';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'Grant \"All files access\" to store downloads permanently, then pick the mode again.';

  @override
  String get storageSettings => 'Settings';

  @override
  String get storageNoVolume => 'Could not locate a storage volume';

  @override
  String get storageNotWritable =>
      'That folder isn\'t writable — pick another.';

  @override
  String get storageNewFolder => 'New folder';

  @override
  String get storageFolderNameHint => 'Folder name';

  @override
  String get storageCouldNotCreateFolder => 'Could not create folder';

  @override
  String get storageNoSubfolders => 'No subfolders here';

  @override
  String get storageUseThisFolder => 'Use this folder';

  @override
  String get storageMovedToNewFolder =>
      'Moved downloaded files to the new folder.';

  @override
  String get storageMoveAlreadyRunning =>
      'A move is already running — let it finish first.';

  @override
  String get storageMigrateTitle => 'Different storage volume';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This server’s $count downloaded files ($size) are on a different storage volume from the new location. Choose what to do:',
      one:
          'This server’s 1 downloaded file ($size) is on a different storage volume from the new location. Choose what to do:',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return 'Not enough free space at the destination ($free free). A move may fail partway — free up space first.';
  }

  @override
  String get storageMigrateMove => 'Move them';

  @override
  String get storageMigrateMoveBody =>
      'Copy to the new location in the background, deleting each old copy as it goes. Keep the app open until it finishes.';

  @override
  String get storageMigrateLeave => 'Leave them';

  @override
  String get storageMigrateLeaveBody =>
      'Switch now; the old downloads stay where they are and re-download at the new location.';

  @override
  String get storageMigrateDelete => 'Delete old downloads';

  @override
  String get storageMigrateDeleteBody =>
      'Switch now and remove the old files; they\'ll re-download at the new location.';

  @override
  String get storageMovingBackground =>
      'Moving your downloads in the background — keep the app open.';

  @override
  String get storageChooseFolderFirst => 'Choose a download folder first.';

  @override
  String get storageChooseSdFolderFirst =>
      'Choose a folder on the SD card first. If every folder is rejected, your device may not let apps write to the card — use Permanent or App local instead.';

  @override
  String get castPlayOn => 'Play on';

  @override
  String get castPlayOnTooltip => 'Play on…';

  @override
  String get castSearching => 'Searching for cast devices…';

  @override
  String get castNotSeeing =>
      'Don\'t see your device? Make sure it\'s on the same Wi-Fi.';

  @override
  String get castVisualizer => 'Cast visualizer';

  @override
  String get castVisualizerSubtitle =>
      'Stream the visualizer to the TV · Chromecast only';

  @override
  String get visualizerNoKnobs => 'This shader exposes no knobs.';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get playerLayoutSmall => 'Small';

  @override
  String get playerLayoutMedium => 'Medium';

  @override
  String get playerLayoutLarge => 'Large';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => 'Slim bar — maximum queue';

  @override
  String get playerLayoutMediumDesc => 'Banner — balanced (default)';

  @override
  String get playerLayoutLargeDesc => 'Compact — centered art';

  @override
  String get playerLayoutXlDesc => 'Hero — full album art';

  @override
  String get queueNothingToDownloadEmpty =>
      'Queue is empty — nothing to download';

  @override
  String get queueNothingToDownloadSaved =>
      'Nothing to download — tracks are already saved';

  @override
  String get settingsAccentColor => 'Accent color';

  @override
  String get settingsAccentColorSubtitle =>
      'The highlight color used across the app.';

  @override
  String get accentThemeDefault => 'Theme default';

  @override
  String get accentCustom => 'Custom';

  @override
  String get lanOnYourNetwork => 'Servers on your local network';

  @override
  String get lanSearching => 'Searching for servers…';

  @override
  String get lanRefresh => 'Refresh';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return 'Sign in to $name';
  }

  @override
  String get lanUnreachable => 'Couldn\'t reach this server on the network.';

  @override
  String get lanNoCode =>
      'Quick Connect is on for this server, but it didn\'t share a pairing code. Sign in as an admin, or ask the operator to enable code sharing.';

  @override
  String get settingsResumeQueue => 'Resume queue on launch';

  @override
  String get settingsResumeQueueSubtitle =>
      'Save the play queue and your place, and restore them when you reopen the app.';

  @override
  String get settingsOfflineQueue => 'Keep queue available offline';

  @override
  String get settingsOfflineQueueSubtitle =>
      'Automatically download queued tracks to this device so playback survives losing the connection.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Download on Wi-Fi only';

  @override
  String get settingsOfflineQueueWifiOnlySubtitle =>
      'Wait for Wi-Fi before downloading queued tracks.';

  @override
  String get settingsAutoDownloadCap => 'Auto-download limit';

  @override
  String get settingsAutoDownloadCapSubtitle =>
      'Cache this many songs ahead of the one playing; songs left behind are removed as you go.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Cache the whole queue (no limit).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unlimited';

  @override
  String get settingsAutoDownloadCapField => 'Number of tracks';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'How many queued songs to keep downloaded, counting from the one playing. As playback moves on, songs that fall behind are deleted. Set to 0 to cache the whole queue.';

  @override
  String get downloadWaitingWifi => 'Waiting for Wi-Fi';

  @override
  String get settingsRatingHalf => 'Half-star ratings';

  @override
  String get settingsRatingHalfSubtitle =>
      'Rate songs in half-star steps (long-press a star).';

  @override
  String get ratingTitle => 'Rate';

  @override
  String get ratingFailed => 'Could not save rating';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get diagnosticsEnable => 'Enable logging';

  @override
  String get diagnosticsHint =>
      'Logs stay on your device. Tokens are hidden before copying or sharing.';

  @override
  String get diagnosticsVerbose => 'Verbose logging';

  @override
  String get diagnosticsVerboseHint =>
      'Also logs high-frequency events like app focus changes. Only needed when diagnosing a playback issue.';

  @override
  String get diagnosticsCopy => 'Copy';

  @override
  String get diagnosticsShare => 'Share';

  @override
  String get diagnosticsClear => 'Clear';

  @override
  String get diagnosticsCopied => 'Logs copied to clipboard';

  @override
  String get diagnosticsEmpty => 'No logs yet';

  @override
  String get storageAppExternal => 'App external';

  @override
  String get storageAppSdCard => 'App SD card';

  @override
  String get selfSignedTitle => 'Allow self-signed certificate';

  @override
  String get selfSignedSubtitle =>
      'Skip TLS validation for this server. Only enable on a network you trust.';

  @override
  String get importedShadersTitle => 'Imported shaders';

  @override
  String get importedShadersSettingsSubtitle =>
      'Add your own .glsl files to the Shader engine rotation.';

  @override
  String get importedShadersRescan => 'Rescan folder';

  @override
  String get importedShadersDropHint =>
      'Drop .glsl files in this folder, then Rescan:';

  @override
  String get importedShadersCopyPath => 'Copy path';

  @override
  String get importedShadersReachableHint =>
      'Reachable over USB or a file manager (under Android/data). Imported shaders join the rotation when the Shader engine is active.';

  @override
  String get importedShadersRemove => 'Remove';

  @override
  String get importedShadersEmptyTitle => 'No shaders in the folder yet';

  @override
  String get importedShadersEmptyBody =>
      'Copy Shadertoy-style .glsl files into the folder above, then tap Rescan.';

  @override
  String get importedShadersInvalid =>
      'May not be a valid shader — no mainImage/main entry point.';

  @override
  String get importedShadersImportDownloads => 'Import .glsl from Downloads';

  @override
  String importedShadersDownloadsImported(int count) {
    return 'Imported $count shader(s) from Downloads';
  }

  @override
  String get importedShadersDownloadsNone => 'No new .glsl files in Downloads';

  @override
  String get importedShadersDownloadsNoPermission =>
      'Storage permission is needed to read Downloads';

  @override
  String get addServerTabUrl => 'Server URL';

  @override
  String get addServerTabQuickConnect => 'Quick Connect';

  @override
  String get irohPairingHeader => 'Connect with a pairing code';

  @override
  String get irohPairingBody =>
      'Enable Remote Access on the server, then paste its pairing code or scan the QR.';

  @override
  String get irohOneServerLimit =>
      'Only one peer-to-peer (iroh) server is supported. Remove the existing one to connect a different server.';

  @override
  String get irohPairingCodeLabel => 'Pairing code';

  @override
  String get irohPairingCodeHint =>
      'Paste the code from the server Remote Access panel';

  @override
  String get irohShowPairingCode => 'Show pairing code';

  @override
  String get irohQrBody =>
      'Scan with the mStream app on another device to connect it to this server, or copy the code and paste it there.';

  @override
  String get irohQrCaution =>
      'Anyone with this code can connect to your server.';

  @override
  String get irohScanQr => 'Scan QR';

  @override
  String get irohPaste => 'Paste';

  @override
  String get irohTestConnection => 'Test connection';

  @override
  String get irohTesting => 'Testing…';

  @override
  String get irohScannerTitle => 'Scan pairing QR';

  @override
  String get irohQrAndroidOnly =>
      'QR scanning isn\'t available on this device.';

  @override
  String get irohAndroidOnly =>
      'Quick Connect isn\'t available on this device.';

  @override
  String get irohCameraPermission =>
      'Camera permission is needed to scan a code.';

  @override
  String get irohPasteFirst => 'Paste or scan a pairing code first.';

  @override
  String get irohTestFirst => 'Test the connection first.';

  @override
  String get irohTestConnected => 'Connected through the iroh tunnel';

  @override
  String irohTestConnectedVersion(String version) {
    return 'Connected through the iroh tunnel — mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · direct';

  @override
  String get irohPathSuffixRelay => ' · via relay';

  @override
  String get irohTunnelTimeout =>
      'Tunnel opened but the server did not respond in time.';

  @override
  String irohTunnelTestFailed(String error) {
    return 'Tunnel test failed: $error';
  }

  @override
  String get irohSignInHeader => 'Sign in';

  @override
  String get irohSigningIn => 'Signing in…';

  @override
  String get irohSignInSave => 'Sign in & save';

  @override
  String get irohSignInTimeout => 'Sign-in timed out.';

  @override
  String irohSignInFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return 'Sign-in failed (HTTP $status). Check your username and password.';
  }

  @override
  String get irohBannerConnecting => 'Connecting to server…';

  @override
  String get irohBannerReconnecting => 'Reconnecting to server…';

  @override
  String get irohBannerDisconnected => 'Disconnected from server.';

  @override
  String get irohBannerRelay => 'Connected via relay — slower path.';

  @override
  String get irohBannerRepair =>
      'Server pairing changed — re-pair to reconnect.';

  @override
  String get irohRepairAction => 'Re-pair';

  @override
  String get irohRetry => 'Retry';

  @override
  String get irohRepairTitle => 'Re-pair server';

  @override
  String get irohRepairBody =>
      'This server\'s pairing code changed (its secret was rotated). Paste or scan the new code from the server\'s Remote Access panel.';

  @override
  String get irohRepairFailed =>
      'Couldn\'t connect with that code — check it and try again.';

  @override
  String get irohPathDirect => 'Direct';

  @override
  String get irohPathRelay => 'Relay';

  @override
  String get irohCastUnavailable =>
      'Casting to external devices isn\'t available for peer-to-peer (iroh) servers — playback stays on this device.';

  @override
  String get irohShareUnavailable =>
      'Sharing isn\'t available for peer-to-peer (iroh) servers — they have no public URL to link to.';

  @override
  String get discoverTitle => 'Discover';

  @override
  String get discoverMatchedBySound => 'Matched by sound';

  @override
  String get discoverSimilarTracks => 'Similar tracks';

  @override
  String get discoverSimilarArtists => 'Similar artists';

  @override
  String get discoverFromNetwork => 'From the network';

  @override
  String get discoverFromPeers => 'From your peers';

  @override
  String get discoverQueueAll => 'Queue all';

  @override
  String get discoverNewArtistsOnly => 'New artists only';

  @override
  String get discoverNotAnalyzed =>
      'This song hasn\'t been analyzed yet — similar songs appear once the discovery scan reaches it.';

  @override
  String get discoverScanPendingTitle => 'Nothing analyzed yet';

  @override
  String get discoverScanPendingBody =>
      'This server has sonic discovery switched on, but hasn\'t analyzed any music yet. Similar songs appear once the discovery scan has run.';

  @override
  String get discoverCheckAgain => 'Check again';

  @override
  String get discoverTurnedOff =>
      'Sonic discovery has been switched off on this server.';

  @override
  String get pathScanPending =>
      'This server hasn\'t analyzed any music yet, so there\'s nothing to build a path through. It works once the discovery scan has run.';

  @override
  String get discoverNothingFound => 'No matches found.';

  @override
  String get discoverNoSeed => 'Play a song to discover similar music.';

  @override
  String get discoverLeadCopied => 'Copied — go find it!';

  @override
  String get discoverOpenMusicBrainz => 'Open on MusicBrainz';

  @override
  String get discoverNetworkWarmingUp =>
      'No network data yet — peer libraries download in the background once other servers are heard.';

  @override
  String get discoverNetworkNothingNew =>
      'Nothing new for this song — the network has no unfamiliar matches.';

  @override
  String get discoverPeersUnreachable =>
      'Your peers didn\'t answer — they may be offline right now.';

  @override
  String get discoverPeersNothingNew =>
      'Nothing new for this song on your peers\' servers.';

  @override
  String get autoDjSonicTitle => 'Sonic similarity';

  @override
  String get autoDjSonicSubtitle =>
      'Only pick songs that sound like the session, using the server\'s audio analysis.';

  @override
  String get autoDjSonicUnavailable =>
      'This server doesn\'t have discovery data — picks stay random.';

  @override
  String get autoDjSonicStrictness => 'Match strictness';

  @override
  String autoDjSonicStrictnessValue(int pct) {
    return '$pct% or closer';
  }

  @override
  String get autoDjSonicSeedLabel => 'Seed song';

  @override
  String get autoDjSonicSeedNone =>
      'No seed — the playing song anchors the session.';

  @override
  String get autoDjSonicSeedBanner =>
      'Pick the seed song — tap a track anywhere in the library';

  @override
  String get autoDjSonicSeedSearchHint => 'Search for a song…';

  @override
  String get autoDjSonicSeedRandom => 'Random song';

  @override
  String get autoDjSonicSeedRemove => 'Remove seed song';

  @override
  String get autoDjSonicSeedFailed => 'Couldn\'t fetch a song from the server.';

  @override
  String get autoDjSeedNoMatch =>
      'No songs match your Auto DJ filters — try loosening them';

  @override
  String get discoverFindSimilar => 'Find similar';

  @override
  String get discoverStartSession => 'Start a sonic session';

  @override
  String get discoverStartSessionSubtitle =>
      'Endless music that sounds like this — replaces your queue.';

  @override
  String get discoverStartSessionSubtitleRandom =>
      'Endless music from a random starting song — replaces your queue.';

  @override
  String get discoverSessionStarted => 'Sonic session started — Auto DJ is on.';

  @override
  String get autoDjSonicAnchorLabel => 'Anchor';

  @override
  String get autoDjSonicAnchorRolling => 'Follow the vibe';

  @override
  String get autoDjSonicAnchorLocked => 'Stay on seed';

  @override
  String get autoDjSonicAnchorRollingHint =>
      'Each pick follows the session\'s recent sound — it can slowly evolve.';

  @override
  String get autoDjSonicAnchorLockedHint =>
      'Every pick stays close to the seed song for the whole session.';

  @override
  String get trackAddToPlaylist => 'Add to playlist';

  @override
  String get trackAddToPlaylistFailed => 'Couldn\'t add to the playlist.';

  @override
  String get discoverPlayPathTo => 'Play a path to…';

  @override
  String get pathScreenTitle => 'Sonic path';

  @override
  String get pathStartNotAnalyzed =>
      'The starting song hasn\'t been analyzed yet — wait for the discovery scan or pick another.';

  @override
  String get pathEndNotAnalyzed =>
      'The destination song hasn\'t been analyzed yet — wait for the discovery scan or pick another.';

  @override
  String get pathStartSong => 'Start song';

  @override
  String get pathEndSong => 'End song';

  @override
  String get pathLength => 'Length';

  @override
  String get pathRegenerate => 'Regenerate';

  @override
  String get pathSaveAsPlaylist => 'Save as playlist';

  @override
  String get pathSetupHint =>
      'Pick a start and an end song — the journey between them fills itself.';

  @override
  String get pathNotSet => 'Not set';

  @override
  String get pathUsePlaying => 'Use playing song';

  @override
  String get pathSearchSong => 'Search';

  @override
  String get pathBrowseLibrary => 'Browse library';

  @override
  String get pathBuild => 'Build the journey';

  @override
  String get pathStartOver => 'Start over';

  @override
  String get pathPickBannerStart =>
      'Pick the start song — tap a track anywhere in the library';

  @override
  String get pathPickBannerEnd =>
      'Pick the end song — tap a track anywhere in the library';

  @override
  String get pathNothingPlaying => 'Nothing is playing';

  @override
  String pathPickOnServer(String server) {
    return 'Pick a track on $server';
  }

  @override
  String get welcomeTranslationNote =>
      'This language was machine-translated and may read awkwardly.';

  @override
  String get welcomeTranslationCta => 'Help translate mStream';

  @override
  String get setupTitle => 'Quick setup';

  @override
  String get setupSkip => 'Skip';

  @override
  String get setupNext => 'Next';

  @override
  String get setupFinish => 'Finish';

  @override
  String get setupBack => 'Back';

  @override
  String get setupAccentTitle => 'Pick your color';

  @override
  String get setupAccentBody =>
      'The accent color highlights buttons, sliders and the player controls. Tap one to try it.';

  @override
  String get setupVisualizerTitle => 'Real audio for the visualizer';

  @override
  String get setupVisualizerBody =>
      'The visualizer uses synthesized data until this is enabled.';

  @override
  String get setupVisualizerWarning =>
      'Turning this on asks for the microphone permission — Android requires this for apps that decode the device\'s audio stream (which the visualizer does).';

  @override
  String get setupPlaybackTitle => 'When you tap a song';

  @override
  String get setupOfflineTitle => 'Keep your queue offline';

  @override
  String get setupVisualizerNoMic => 'mStream never uses your microphone.';

  @override
  String get playlistEmpty => 'Playlist is empty';

  @override
  String get trackRating => 'Rating';

  @override
  String albumDiscNumber(int n) {
    return 'Disc $n';
  }

  @override
  String get autoDjStartTitle => 'Start Auto DJ with what?';

  @override
  String get autoDjStartSubtitle =>
      'Nothing is queued, so the DJ needs an opening track. With a queue it just follows what you already have.';

  @override
  String get autoDjStartRandom => 'Surprise me';

  @override
  String get autoDjStartRandomSub =>
      'Pick a random song from the library and build outward from it.';

  @override
  String get autoDjStartPick => 'Let me choose';

  @override
  String get autoDjStartPickSub =>
      'Open the library and pick the opening track yourself.';

  @override
  String get autoDjStartRemember => 'Remember this';

  @override
  String get autoDjStartRememberSub =>
      'Skip this question next time and always start this way.';

  @override
  String get autoDjStartPickBanner =>
      'Pick the opening song — tap a track anywhere in the library';

  @override
  String get autoDjOnEmptyQueue => 'On an empty queue';

  @override
  String get autoDjOnEmptyQueueSub =>
      'What Auto DJ does when you switch it on with nothing queued.';

  @override
  String get autoDjStartAskShort => 'Ask';

  @override
  String serverVersionLabel(String version) {
    return 'Server v$version';
  }

  @override
  String get serverVersionUnknown => 'Server version unknown';

  @override
  String get serverUpdateUrgent => 'Update your server';

  @override
  String get serverUpdateAvailable => 'Server update available';

  @override
  String serverTooOldWarning(String version) {
    return 'This server is v$version. Some features need v5.5 or newer and will be unavailable.';
  }

  @override
  String get autoDjNeedsNewerServer =>
      'BPM continuity, harmonic mixing and the genre filter need a newer server. Update to get them.';

  @override
  String get autoDjSonicNeedsNewerServer => 'Needs server 6.15.2 or newer';

  @override
  String get torrentScreenTitle => 'Add torrent';

  @override
  String get torrentNoServer => 'No server is configured.';

  @override
  String get torrentServerLabel => 'Server';

  @override
  String get torrentLibraryLabel => 'Library';

  @override
  String get torrentNoLibraries => 'No libraries on this server';

  @override
  String get torrentSourceLabel => 'Source';

  @override
  String get torrentChooseFile => 'Choose .torrent file';

  @override
  String get torrentOr => 'or';

  @override
  String get torrentMagnetLabel => 'Magnet link';

  @override
  String get torrentMagnetInvalid => 'Not a valid magnet link';

  @override
  String torrentNotATorrent(String name) {
    return '“$name” is not a .torrent file';
  }

  @override
  String get torrentOpenWith => 'Open in another app';

  @override
  String get torrentOpenWithNone =>
      'No app on this device can open a .torrent file';

  @override
  String get torrentOpenWithFailed =>
      'Could not hand the torrent to another app';

  @override
  String get torrentIntentTitle => 'Torrent received';

  @override
  String get torrentIntentBody =>
      'Add it to a library on your mStream server, or hand it to another app.';

  @override
  String get torrentIntentAdd => 'Add to mStream';

  @override
  String get torrentIntentDontAsk => 'Always add to mStream, don’t ask again';

  @override
  String get settingsTorrentAskTitle => 'Ask what to do with torrents';

  @override
  String get settingsTorrentAskSub =>
      'When a torrent is opened with mStream, offer to hand it to another app';

  @override
  String get settingsTorrentDefaultTitle => 'Default app for torrents';

  @override
  String get settingsTorrentDefaultSub =>
      'Opens Android settings, where you can choose which app handles torrents and magnet links';

  @override
  String get settingsTorrentDefaultFailed => 'Could not open Android settings';

  @override
  String get torrentAutoDetect => 'Auto-detect metadata';

  @override
  String get torrentDetecting => 'Detecting…';

  @override
  String get torrentDetectNoMetadata =>
      'Not enough metadata — fill the fields in manually';

  @override
  String get torrentDetected => 'Metadata detected';

  @override
  String get torrentDetectGuess =>
      'Best-effort guess — please verify the fields';

  @override
  String get torrentMetadataLabel => 'Metadata';

  @override
  String get torrentArtistLabel => 'Artist';

  @override
  String get torrentAlbumLabel => 'Album';

  @override
  String get torrentYearLabel => 'Year';

  @override
  String get torrentDestinationLabel => 'Destination';

  @override
  String get torrentPathLabel => 'Path in library';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹no library›/$path';
  }

  @override
  String get torrentPreviewContents => '‹torrent contents›';

  @override
  String get torrentRenameRoot => 'Rename the torrent\'s root folder';

  @override
  String get torrentRenameRootSub => 'Match the destination folder name';

  @override
  String get torrentForceFresh => 'Force fresh download';

  @override
  String get torrentForceFreshSub =>
      'Skip checking for files already on the server';

  @override
  String get torrentSubmit => 'Add torrent';

  @override
  String get torrentSubmitting => 'Adding…';

  @override
  String get torrentUnavailable => 'Torrents are unavailable on this server.';

  @override
  String get torrentPickLibrary => 'Pick a library';

  @override
  String get torrentOneSource => 'Add a magnet link or a .torrent file (one)';

  @override
  String get torrentPathEmpty => 'Destination path is empty';

  @override
  String get torrentSeeded => 'Already on disk — seeding it now';

  @override
  String get torrentAlreadyInClient => 'Already in the torrent client';

  @override
  String get torrentInvalidFile => 'Invalid torrent file';

  @override
  String get torrentSeedCheckFailed =>
      'Couldn\'t check for existing files — downloading fresh';

  @override
  String get torrentPartialTitle => 'Some files already exist';

  @override
  String get torrentPartialBody =>
      'Point the torrent at an existing copy to seed it and download only what is missing.';

  @override
  String torrentPartialCount(String matched, String total) {
    return '$matched/$total files here';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · $missing to download';
  }

  @override
  String get torrentDownloadFresh => 'Download fresh anyway';

  @override
  String get torrentMatchNoFolder =>
      'That match has no folder name — use \'Download fresh\' instead';

  @override
  String torrentAdded(String name) {
    return 'Added \"$name\"';
  }

  @override
  String torrentDuplicate(String name) {
    return '\"$name\" is already in the client';
  }

  @override
  String serverPickerVia(String parent) {
    return 'via $parent';
  }

  @override
  String get browserFederatedReadOnly => 'Read-only server';

  @override
  String get browserFederatedReadOnlyNote =>
      'Playlists and ratings stay on your own';

  @override
  String get federatedAutoDjUnavailable =>
      'Auto DJ can\'t run on a shared server. Switch to one of your own servers first.';

  @override
  String get federatedShareUnavailable =>
      'Tracks on a shared server can\'t be shared from here — they live in someone else\'s library.';

  @override
  String get federatedForget => 'Forget';

  @override
  String get federatedHide => 'Hide from the picker';

  @override
  String get federatedShow => 'Show in the picker';

  @override
  String federatedNoLongerListed(String parent) {
    return 'No longer shared by $parent';
  }

  @override
  String get adminLogOut => 'Log out';

  @override
  String get adminConfigGroup => 'Config';

  @override
  String get adminDirectories => 'Directories';

  @override
  String get adminUsers => 'Users';

  @override
  String get adminDLNA => 'DLNA';

  @override
  String get adminTorrent => 'Torrent';

  @override
  String get adminFederation => 'Federation';

  @override
  String get adminServerGroup => 'Server';

  @override
  String get adminAbout => 'About';

  @override
  String get adminSettings => 'Settings';

  @override
  String get adminDatabase => 'Database';

  @override
  String get adminBackups => 'Backups';

  @override
  String get adminTranscoding => 'Transcoding';

  @override
  String get adminLogs => 'Logs';

  @override
  String get adminAccess => 'Admin Access';

  @override
  String adminAppBarTitle(String label) {
    return 'mStream Admin · $label';
  }

  @override
  String get adminPanelTitle => 'mStream Admin';

  @override
  String get adminLoginErrorRequired => 'Server and username are required';

  @override
  String get adminLoginServerURL => 'Server URL';

  @override
  String get adminLoginUsername => 'Username';

  @override
  String get adminLoginPassword => 'Password';

  @override
  String get adminLoginSignIn => 'Sign in';

  @override
  String get adminRetry => 'Retry';

  @override
  String get adminSaved => 'Saved';

  @override
  String get adminSave => 'Save';

  @override
  String get adminClose => 'Close';

  @override
  String get adminPanelMenuItem => 'Admin panel';

  @override
  String get adminNoLibrariesYetTitle => 'No libraries yet';

  @override
  String get adminAddDirectoryHint =>
      'Add a directory to start scanning music into the library.';

  @override
  String get adminAddDirectoryButton => 'Add directory';

  @override
  String adminRemoveDirectoryTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get adminRemoveDirectoryWarning =>
      'This removes the library and its scanned tracks from the database. Files on disk are left untouched.';

  @override
  String get adminCancel => 'Cancel';

  @override
  String get adminRemove => 'Remove';

  @override
  String get adminLibraryRemovedToast => 'Library removed';

  @override
  String get adminDirectoryPathLabel => 'Path';

  @override
  String get adminDirectoryTypeLabel => 'Type';

  @override
  String get adminFollowSymlinksTitle => 'Follow symlinks';

  @override
  String get adminFollowSymlinksSubtitle => 'Takes effect on the next scan';

  @override
  String get adminPickFolderAndNameError => 'Pick a folder and enter a name';

  @override
  String get adminDirectoryAddedToast => 'Directory added — scanning started';

  @override
  String get adminAddDirectoryDialogTitle => 'Add directory';

  @override
  String get adminChooseFolderButton => 'Choose folder on server…';

  @override
  String get adminLibraryNameLabel => 'Library name (vpath)';

  @override
  String get adminLibraryNameHelper => 'Letters, numbers and dashes';

  @override
  String get adminGrantAllUsersAccessTitle => 'Grant all users access';

  @override
  String get adminAudiobookLibraryTitle => 'Audiobook library';

  @override
  String get adminAdd => 'Add';

  @override
  String get adminChooseFolderTitle => 'Choose a folder';

  @override
  String get adminSelectFolderButton => 'Select this folder';

  @override
  String get adminNoUsersTitle => 'No users';

  @override
  String get adminNoUsersSubtitle =>
      'With no users the server runs in open/public mode. Add one to require login.';

  @override
  String get adminAddUserButton => 'Add user';

  @override
  String get adminLibraryAccessDialogTitle => 'Library access';

  @override
  String get adminLibraryAccessUpdatedToast => 'Library access updated';

  @override
  String get adminSetPasswordTitle => 'Set password';

  @override
  String get adminPasswordUpdatedToast => 'Password updated';

  @override
  String adminDeleteUserTitle(String username) {
    return 'Delete $username?';
  }

  @override
  String get adminDeleteUserWarning =>
      'This permanently removes the user account.';

  @override
  String get adminDelete => 'Delete';

  @override
  String get adminUserDeletedToast => 'User deleted';

  @override
  String get adminStatusPillLabel => 'admin';

  @override
  String get adminDeleteUserMenuItem => 'Delete user';

  @override
  String get adminNoLibraryAccessLabel => 'No library access';

  @override
  String get adminLibrariesButton => 'Libraries';

  @override
  String get adminAdminToggleTitle => 'Admin';

  @override
  String get adminMakeDirsToggleTitle => 'Make dirs';

  @override
  String get adminUploadToggleTitle => 'Upload';

  @override
  String get adminModifyFilesToggleTitle => 'Modify files';

  @override
  String get adminServerAudioToggleTitle => 'Server audio';

  @override
  String get adminAddUserDialogTitle => 'Add user';

  @override
  String get adminUsername => 'Username';

  @override
  String get adminPassword => 'Password';

  @override
  String get adminLibraryAccessHeader => 'Library access';

  @override
  String get adminUsernamePasswordRequiredError =>
      'Username and password are required';

  @override
  String get adminUserCreatedToast => 'User created';

  @override
  String get adminAdministratorToggleTitle => 'Administrator';

  @override
  String get adminAllowMakeDirectoriesTitle => 'Allow make directories';

  @override
  String get adminAllowUploadTitle => 'Allow upload';

  @override
  String get adminAllowServerAudioTitle => 'Allow server audio';

  @override
  String get adminCreate => 'Create';

  @override
  String get adminNoLibrariesConfigured => 'No libraries configured.';

  @override
  String get adminNewPasswordLabel => 'New password';

  @override
  String get adminLibraryTitle => 'Library';

  @override
  String get adminTracksInDatabase => 'Tracks in database';

  @override
  String get adminScanAllButton => 'Scan all';

  @override
  String get adminScanStarted => 'Scan started';

  @override
  String get adminForceRescan => 'Force rescan';

  @override
  String get adminFullRescanStarted => 'Full rescan started';

  @override
  String get adminCompressImages => 'Compress images';

  @override
  String get adminImageCompressionStarted => 'Image compression started';

  @override
  String get adminScanOptions => 'Scan options';

  @override
  String get adminScanInterval => 'Scan interval (hours, 0 = off)';

  @override
  String get adminBootScanDelay => 'Boot scan delay (seconds)';

  @override
  String get adminScanCommitInterval => 'Scan commit interval (1–1000)';

  @override
  String get adminScanThreads => 'Scan threads (0 = auto)';

  @override
  String get adminSkipImageExtraction => 'Skip image extraction';

  @override
  String get adminCompressEmbeddedImages => 'Compress embedded images';

  @override
  String get adminGenerateWaveforms => 'Generate waveforms after scan';

  @override
  String get adminAnalyzeBpm => 'Analyze BPM/key (deprecated, no-op)';

  @override
  String get adminAutomaticAlbumArt => 'Automatic album art';

  @override
  String get adminDownloadMissingAlbumArt => 'Download missing album art';

  @override
  String get adminTargetLabel => 'Target';

  @override
  String get adminMissingOnly => 'Missing only';

  @override
  String get adminAllAlbums => 'All albums';

  @override
  String get adminAlbumsPerRun => 'Albums per run (1–10000)';

  @override
  String get adminAutoDownloadedArtWriteFolder =>
      'Auto-downloaded art → write into folder';

  @override
  String get adminManualArtWriteFolder => 'Manual set-art → write into folder';

  @override
  String get adminManualArtEmbedTag => 'Manual set-art → embed into file tag';

  @override
  String get adminArtServices => 'Art services';

  @override
  String get adminArtServicesUpdated => 'Art services updated';

  @override
  String get adminSharedPlaylists => 'Shared playlists';

  @override
  String get adminDeleteExpired => 'Delete expired';

  @override
  String get adminExpiredSharesDeleted => 'Expired shares deleted';

  @override
  String get adminDeleteNeverExpiring => 'Delete never-expiring';

  @override
  String get adminEternalSharesDeleted => 'Eternal shares deleted';

  @override
  String get adminNoSharedPlaylists => 'No shared playlists';

  @override
  String adminSharedPlaylistSubtitle(String user, int count, String expiry) {
    return 'by $user · $count tracks · expires $expiry';
  }

  @override
  String get adminShareDeleted => 'Share deleted';

  @override
  String get adminNetwork => 'Network';

  @override
  String get adminNetworkSubtitle => 'Changing these soft-reboots the server.';

  @override
  String get adminBindAddress => 'Bind address';

  @override
  String get adminPort => 'Port';

  @override
  String get adminTrustProxyHeaders => 'Trust proxy headers';

  @override
  String get adminTrustProxyHeadersSubtitle =>
      'Enable when behind a reverse proxy (X-Forwarded-*)';

  @override
  String get adminPermissions => 'Permissions';

  @override
  String get adminAllowUploads => 'Allow uploads';

  @override
  String get adminAllowMakingDirectories => 'Allow making directories';

  @override
  String get adminAllowModifyingFiles => 'Allow modifying files';

  @override
  String get adminMaxRequestSize => 'Max request size';

  @override
  String get adminMaxRequestSizeHelper => 'e.g. 50MB or 512KB';

  @override
  String get adminHttpUi => 'HTTP & UI';

  @override
  String get adminResponseCompression => 'Response compression';

  @override
  String get adminCompressionNone => 'None';

  @override
  String get adminCompressionGzip => 'gzip';

  @override
  String get adminCompressionBrotli => 'brotli';

  @override
  String get adminWebUi => 'Web UI';

  @override
  String get adminUiDefault => 'Default';

  @override
  String get adminUiVelvet => 'Velvet';

  @override
  String get adminDatabaseTuning => 'Database tuning';

  @override
  String get adminSqliteSynchronous => 'SQLite synchronous';

  @override
  String get adminSyncFull => 'FULL (safest)';

  @override
  String get adminSyncNormal => 'NORMAL (faster)';

  @override
  String get adminCacheSize => 'Cache size (MB, 1–2048)';

  @override
  String get adminLogging => 'Logging';

  @override
  String get adminWriteLogsToDisk => 'Write logs to disk';

  @override
  String get adminLogBufferSize => 'Log buffer size (0–10000, 0 = disabled)';

  @override
  String get adminServerAudio => 'Server audio';

  @override
  String get adminAutoBootServerAudio => 'Auto-boot server audio (Rust player)';

  @override
  String get adminRustPlayerPort => 'Rust player port';

  @override
  String get adminActiveBackend => 'Active backend';

  @override
  String get adminPlayer => 'Player';

  @override
  String get adminDetectedCliPlayers => 'Detected CLI players';

  @override
  String get adminNone => 'none';

  @override
  String get adminReDetectPlayers => 'Re-detect players';

  @override
  String get adminReProbedCliPlayers => 'Re-probed CLI players';

  @override
  String get adminSslHttps => 'SSL / HTTPS';

  @override
  String get adminEnabled => 'Enabled';

  @override
  String get adminDisabled => 'Disabled';

  @override
  String get adminReplaceCertificate => 'Replace certificate';

  @override
  String get adminSetCertificate => 'Set certificate';

  @override
  String get adminSetSslCertificateDialog => 'Set SSL certificate';

  @override
  String get adminCertificatePath => 'Certificate path';

  @override
  String get adminKeyPath => 'Key path';

  @override
  String get adminSslConfigured => 'SSL configured — reboot to apply';

  @override
  String get adminRemoveSsl => 'Remove SSL';

  @override
  String get adminSslRemoved => 'SSL removed';

  @override
  String get adminSecurity => 'Security';

  @override
  String get adminJwtSecretLast4 => 'JWT secret (last 4)';

  @override
  String get adminRegenerateSecret => 'Regenerate secret';

  @override
  String get adminSecretRegenerated =>
      'Secret regenerated — all sessions invalidated';

  @override
  String get adminRegenerateJwtSecretDialog => 'Regenerate JWT secret?';

  @override
  String get adminRegenerateJwtSecretDialogBody =>
      'This invalidates every existing login (including this one). Everyone must sign in again.';

  @override
  String get adminRegenerateButton => 'Regenerate';

  @override
  String get adminAllNetworks => 'All networks';

  @override
  String get adminLocalhostOnly => 'Localhost only';

  @override
  String get adminIpWhitelist => 'IP whitelist';

  @override
  String get adminNoneLockAdmin => 'None (lock admin)';

  @override
  String get adminNetworkAccess => 'Network access';

  @override
  String get adminNetworkAccessSubtitle =>
      'Restrict which networks may reach the admin API.';

  @override
  String get adminMode => 'Mode';

  @override
  String get adminWhitelistedIps => 'Whitelisted IPs / CIDRs';

  @override
  String get adminNoneYet => 'None yet';

  @override
  String get adminAddIpOrCidr => 'Add IP or CIDR';

  @override
  String get adminCidrExample => '192.168.1.0/24';

  @override
  String get adminApply => 'Apply';

  @override
  String get adminDangerZone => 'Danger zone';

  @override
  String get adminLockAdminApi => 'Lock admin API';

  @override
  String get adminLockAdminApiSubtitle =>
      'Disable the entire admin API. Cannot be undone from here.';

  @override
  String get adminLockButton => 'Lock';

  @override
  String get adminLockAdminApiDialog => 'Lock the admin API?';

  @override
  String get adminLockAdminApiDialogBody =>
      'This disables the entire /admin API for everyone. You will not be able to undo it from this panel — it requires editing the server config file and restarting. Continue?';

  @override
  String get adminAdminApiLocked => 'Admin API locked';

  @override
  String get adminAccessUpdated => 'Admin access updated';

  @override
  String get adminTranscodingFFmpegTitle => 'FFmpeg';

  @override
  String get adminFFmpegStatusReady => 'Ready';

  @override
  String get adminFFmpegStatusNotDownloaded => 'Not downloaded';

  @override
  String get adminFFmpegDownloadButton => 'Download / update ffmpeg';

  @override
  String get adminFFmpegDownloadedToast => 'ffmpeg downloaded';

  @override
  String get adminFFmpegAutoUpdateTitle => 'Auto-update ffmpeg';

  @override
  String get adminFFmpegAutoUpdateSubtitle =>
      'Keep the bundled ffmpeg up to date automatically';

  @override
  String get adminTranscodingDefaultsTitle => 'Defaults';

  @override
  String get adminDefaultCodecLabel => 'Default codec';

  @override
  String get adminDefaultBitrateLabel => 'Default bitrate';

  @override
  String get adminLogsResumeButton => 'Resume';

  @override
  String get adminLogsPauseButton => 'Pause';

  @override
  String get adminClear => 'Clear';

  @override
  String get adminLogsAutoScrollTitle => 'Auto-scroll';

  @override
  String adminLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String get adminLogsDownloadZipButton => 'Download zip';

  @override
  String get adminLogsNoEntriesHint => 'No log entries yet';

  @override
  String get adminDlnaModeDisabled => 'Disabled';

  @override
  String get adminSamePortAsHttp => 'Same port as HTTP';

  @override
  String get adminSeparatePort => 'Separate port';

  @override
  String get adminDlnaBrowseFlat => 'Flat (all tracks)';

  @override
  String get adminDlnaBrowseDirectories => 'Directories';

  @override
  String get adminDlnaBrowseArtist => 'By artist';

  @override
  String get adminDlnaBrowseAlbum => 'By album';

  @override
  String get adminDlnaBrowseGenre => 'By genre';

  @override
  String get adminDlnaServerTitle => 'Server';

  @override
  String get adminDlnaIdentityTitle => 'Identity';

  @override
  String get adminDlnaFriendlyNameLabel => 'Friendly name';

  @override
  String get adminDlnaDeviceUuidLabel => 'Device UUID';

  @override
  String get adminDlnaDeviceUuidHelper => 'Canonical GUID';

  @override
  String get adminDlnaBrowseLayoutTitle => 'Browse layout';

  @override
  String get adminDlnaStructureLabel => 'Structure';

  @override
  String get adminTestConnection => 'Test connection';

  @override
  String get adminKeyNameLabel => 'Key name / label';

  @override
  String get adminMintKey => 'Mint key';

  @override
  String get adminTorrentClient => 'Client';

  @override
  String get adminActiveClient => 'Active client';

  @override
  String get adminTransmission => 'Transmission';

  @override
  String get adminQbittorrent => 'qBittorrent';

  @override
  String get adminDeluge => 'Deluge';

  @override
  String get adminEnabledFor => 'Enabled for';

  @override
  String get adminAllUsers => 'All users';

  @override
  String get adminWhitelistedUsers => 'Whitelisted users';

  @override
  String get adminHost => 'Host';

  @override
  String get adminPasswordUnchangedIfBlank => 'unchanged if blank';

  @override
  String get adminRpcPath => 'RPC path';

  @override
  String get adminUseHttps => 'Use HTTPS';

  @override
  String get adminTest => 'Test';

  @override
  String adminReachable(String version) {
    return 'Reachable$version';
  }

  @override
  String adminConnectionFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get adminConnectAndSave => 'Connect & save';

  @override
  String adminSaveFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get adminConnectedAndSaved => 'Connected & saved';

  @override
  String get adminDisconnect => 'Disconnect';

  @override
  String get adminDisconnected => 'Disconnected';

  @override
  String get adminConfigured => 'Configured';

  @override
  String get adminNotConfigured => 'Not configured';

  @override
  String get adminTorrents => 'Torrents';

  @override
  String get adminConnected => 'Connected';

  @override
  String get adminNoTorrents => 'No torrents';

  @override
  String get adminMstream => 'mStream';

  @override
  String get adminTorrentRemoved => 'Torrent removed';

  @override
  String get adminLibraryDaemonPathMapping => 'Library → daemon path mapping';

  @override
  String get adminLibraryDaemonPathMappingSubtitle =>
      'Maps each library to its path as the torrent daemon sees it.';

  @override
  String get adminAutoDetectAll => 'Auto-detect all';

  @override
  String get adminAutoDetectionComplete => 'Auto-detection complete';

  @override
  String get adminVerified => 'verified';

  @override
  String get adminUnverified => 'unverified';

  @override
  String get adminSetManually => 'Set manually';

  @override
  String adminDaemonPathFor(String name) {
    return 'Daemon path for \"$name\"';
  }

  @override
  String get adminPathOnDaemonHost => 'Path on daemon host';

  @override
  String get adminVerifyAndSave => 'Verify & save';

  @override
  String get adminVpathVerified => 'Verified';

  @override
  String get adminVpathSavedUnverified => 'Saved (unverified)';

  @override
  String get adminDownloadPathTemplates => 'Download path templates';

  @override
  String adminPathTemplateVars(String vars) {
    return 'Vars: $vars';
  }

  @override
  String get adminNoLibraries => 'No libraries';

  @override
  String adminSuggestedTemplate(String template) {
    return 'Suggested: $template';
  }

  @override
  String get adminTemplateSaved => 'Template saved';

  @override
  String get adminNoBackupDestinations => 'No backup destinations';

  @override
  String get adminBackupDestinationInfo =>
      'Add a destination to mirror a library to another folder.';

  @override
  String get adminAddDestination => 'Add destination';

  @override
  String get adminAddLibraryFirst => 'Add a library first';

  @override
  String get adminBackupQueue => 'Backup queue';

  @override
  String adminTasksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks queued',
      one: '1 task queued',
    );
    return '$_temp0';
  }

  @override
  String adminBackingUp(String library) {
    return 'Backing up: $library';
  }

  @override
  String get adminRunning => 'running';

  @override
  String adminBackupStats(int done, String total, String stats) {
    return '$done files$total$stats';
  }

  @override
  String get adminBackupDisabled => 'disabled';

  @override
  String get adminDestination => 'Destination';

  @override
  String get adminTrigger => 'Trigger';

  @override
  String adminDailyTriggerTime(String trigger, String hour) {
    return '$trigger @ $hour:00';
  }

  @override
  String get adminRetention => 'Retention';

  @override
  String adminRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get adminLastRun => 'Last run';

  @override
  String adminLastRunStatus(String status, int files) {
    return '$status · $files copied';
  }

  @override
  String get adminRunNow => 'Run now';

  @override
  String get adminBackupQueued => 'Backup queued';

  @override
  String get adminAlreadyRunningSkipped => 'Already running — skipped';

  @override
  String get adminHistory => 'History';

  @override
  String get adminEdit => 'Edit';

  @override
  String get adminDestinationDeleted => 'Destination deleted';

  @override
  String get adminBackupHistory => 'Backup history';

  @override
  String get adminNoHistoryYet => 'No history yet';

  @override
  String get adminEditDestination => 'Edit destination';

  @override
  String get adminAddBackupDestination => 'Add backup destination';

  @override
  String get adminDestinationPath => 'Destination path';

  @override
  String get adminBrowseServer => 'Browse server';

  @override
  String get adminCheckPath => 'Check path';

  @override
  String get adminTriggerField => 'Trigger';

  @override
  String get adminAfterEachScan => 'After each scan';

  @override
  String get adminDaily => 'Daily';

  @override
  String get adminManualOnly => 'Manual only';

  @override
  String get adminRunAtHour => 'Run at hour: ';

  @override
  String get adminRetentionFieldLabel => 'Retention (days, 0 = keep all)';

  @override
  String get adminEnabledToggle => 'Enabled';

  @override
  String get adminDestinationUpdated => 'Destination updated';

  @override
  String get adminDestinationCreated => 'Destination created';

  @override
  String get adminPickLibrary => 'Pick a library';

  @override
  String get adminPickDestinationPath => 'Pick a destination path';

  @override
  String adminAboutTitle(String version) {
    return 'mStream v$version';
  }

  @override
  String get adminAboutPort => 'Port';

  @override
  String get adminSSL => 'SSL';

  @override
  String get adminUI => 'UI';

  @override
  String get adminCompression => 'Compression';

  @override
  String get adminTrustProxy => 'Trust proxy';

  @override
  String get adminYes => 'Yes';

  @override
  String get adminNo => 'No';

  @override
  String get adminSecretLast4 => 'Secret (last 4)';

  @override
  String get adminUploads => 'Uploads';

  @override
  String get adminMakeDirs => 'Make dirs';

  @override
  String get adminFileModify => 'File modify';

  @override
  String get adminSynchronous => 'Synchronous';

  @override
  String get adminCacheSizeLabel => 'Cache size';

  @override
  String adminCacheSizeMb(int size) {
    return '$size MB';
  }

  @override
  String get adminFederationDescription =>
      'Pair with other mStream servers: issue keys so they can read your libraries, or add their tickets to read theirs.';

  @override
  String get adminAllowed => 'Allowed';

  @override
  String get adminBackupEnabled => 'enabled';

  @override
  String get adminNotAvailable => 'Not available';

  @override
  String get adminNotMapped => 'not mapped';

  @override
  String get adminExpiryNever => 'never';

  @override
  String get adminUnknownUser => 'unknown';

  @override
  String get adminFederationEnableTitle => 'Enable federation';

  @override
  String get adminFederationEnableSubtitle =>
      'Let this server pair with other mStream servers';

  @override
  String get adminFederationEndpointId => 'Endpoint ID';

  @override
  String get adminFederationRelay => 'Relay';

  @override
  String get adminFederationOnline => 'Online';

  @override
  String get adminFederationOffline => 'Offline';

  @override
  String get adminFederationStopped => 'Stopped';

  @override
  String get adminFederationUnsupportedTitle => 'Not supported here';

  @override
  String get adminFederationUnsupportedBody =>
      'This build has no federation endpoint for your platform, so it cannot run here.';

  @override
  String get adminFederationCopy => 'Copy';

  @override
  String get adminFederationCopied => 'Copied';

  @override
  String get adminFederationKeysTitle => 'Keys you issued';

  @override
  String get adminFederationKeysSubtitle =>
      'Credentials other servers use to read from this one';

  @override
  String get adminFederationNoKeys => 'No keys issued yet';

  @override
  String get adminFederationMintTitle => 'Mint a key';

  @override
  String get adminFederationCopyTicket => 'Show ticket';

  @override
  String get adminFederationTicketTitle => 'Ticket';

  @override
  String get adminFederationTicketBody =>
      'Hand this to the other server’s admin. It is shown once.';

  @override
  String get adminFederationNoTicket => 'No ticket available for this key';

  @override
  String get adminFederationEditLimits => 'Edit limits';

  @override
  String get adminFederationLimitsTitle => 'Limits';

  @override
  String get adminFederationLimitsSaved => 'Limits saved';

  @override
  String get adminFederationStreamKbps => 'Stream ceiling (kbps)';

  @override
  String get adminFederationDailyMb => 'Daily cap (MB)';

  @override
  String get adminFederationMaxStreams => 'Concurrent streams';

  @override
  String get adminFederationUnlimitedHint => '0 means unlimited';

  @override
  String get adminFederationUnlimited => 'unlimited';

  @override
  String adminFederationKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String adminFederationMbPerDay(int mb) {
    return '$mb MB/day';
  }

  @override
  String adminFederationStreams(int count) {
    return '$count streams';
  }

  @override
  String adminFederationUsageToday(String used) {
    return 'Today: $used';
  }

  @override
  String get adminFederationExpired => 'Expired';

  @override
  String get adminFederationBound => 'bound';

  @override
  String get adminFederationUnbound => 'not bound';

  @override
  String get adminFederationResetBinding => 'Reset binding';

  @override
  String get adminFederationResetBindingDone => 'Binding reset';

  @override
  String get adminFederationRevoke => 'Revoke';

  @override
  String adminFederationRevokeTitle(String name) {
    return 'Revoke $name?';
  }

  @override
  String get adminFederationRevokeBody =>
      'Any streams currently using this key are cut immediately.';

  @override
  String get adminFederationRevoked => 'Key revoked';

  @override
  String get adminFederationPeersTitle => 'Servers you read';

  @override
  String get adminFederationPeersSubtitle =>
      'Servers that gave you a ticket, which you can read from';

  @override
  String get adminFederationNoPeers => 'No peers added yet';

  @override
  String get adminFederationAddPeer => 'Add peer';

  @override
  String get adminFederationAddPeerBody =>
      'Paste the ticket the other server gave you. It carries their address and the key that grants access.';

  @override
  String get adminFederationTicketLabel => 'Ticket';

  @override
  String get adminFederationPeerNameLabel => 'Name (optional)';

  @override
  String get adminFederationPeerAdded => 'Peer added';

  @override
  String get adminFederationPeerRemoved => 'Peer removed';

  @override
  String adminFederationRemovePeerTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get adminFederationTestOk => 'Peer reachable';

  @override
  String adminFederationLastSeen(String when) {
    return 'Last seen $when';
  }

  @override
  String get adminFederationNeverSeen => 'Never reached';

  @override
  String get adminFederationUseDiscovery => 'Send discovery queries';

  @override
  String get adminFederationUseDiscoverySubtitle =>
      'Shares what you are listening to with this peer';
}
