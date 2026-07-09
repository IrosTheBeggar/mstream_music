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
  String get autoDjActiveSource => 'Active source';

  @override
  String get autoDjActiveSourceTap => 'Active source — tap to switch';

  @override
  String get autoDjSwitch => 'Switch';

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
      other: '$count tracks in queue',
      one: '1 track in queue',
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
  String get irohConnectHeader => 'Connect peer-to-peer';

  @override
  String get irohConnectBody =>
      'Reach your server from anywhere — no port-forwarding or public IP. Enable Remote Access on the server, then paste its pairing code or scan the QR.';

  @override
  String get irohOneServerLimit =>
      'Only one peer-to-peer (iroh) server is supported. Remove the existing one to connect a different server.';

  @override
  String get irohPairingCodeLabel => 'Pairing code';

  @override
  String get irohPairingCodeHint =>
      'Paste the code from the server Remote Access panel';

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
}
