// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get mainRemove => 'Entfernen';

  @override
  String get playlistActionFailed =>
      'Playlist konnte nicht gespeichert werden – der Name ist möglicherweise bereits vergeben.';

  @override
  String get queueAddNext => 'Als Nächstes';

  @override
  String get queuePlayNow => 'Jetzt abspielen';

  @override
  String get queueAddToEnd => 'Ans Ende der Warteschlange';

  @override
  String get shuffle => 'Zufallswiedergabe';

  @override
  String get variousArtists => 'Verschiedene Interpreten';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get languageSystemDefault => 'Systemstandard';

  @override
  String couldNotOpen(String url) {
    return '$url konnte nicht geöffnet werden';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
      zero: 'Keine Titel',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeLight => 'Hell';

  @override
  String get tapAddToQueue => 'Zur Warteschlange hinzufügen';

  @override
  String get tapPlayFromHere => 'Ab hier abspielen';

  @override
  String get tapAppendAndJump => 'Hinzufügen und abspielen';

  @override
  String get visualizerSourceSynthesized => 'Synthetisiert';

  @override
  String get visualizerSourceReal => 'Echtes Audio';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String downloadProgress(String progress) {
    return 'Fortschritt: $progress %';
  }

  @override
  String get songInfoTitle => 'Songinfo';

  @override
  String get lyricsTitle => 'Songtext';

  @override
  String get lyricsEmpty => 'Kein Songtext für diesen Song gefunden';

  @override
  String get lyricsError => 'Songtext konnte nicht geladen werden';

  @override
  String get lyricsRetry => 'Erneut versuchen';

  @override
  String get eqTitle => 'Equalizer';

  @override
  String get eqOnlyAndroid => 'Der Equalizer ist nur unter Android verfügbar.';

  @override
  String get eqNeedsPlayback =>
      'Der Equalizer dieses Telefons meldet seine Bänder erst, wenn Audio läuft. Dein gespeichertes Preset wird angewendet, sobald sie erscheinen.';

  @override
  String eqInitFailed(String error) {
    return 'Equalizer konnte nicht initialisiert werden:\n$error';
  }

  @override
  String get eqNoBands =>
      'Der Audiotreiber dieses Geräts meldet keine Equalizer-Bänder.';

  @override
  String get eqPresetFlat => 'Flach';

  @override
  String get eqPresetNormal => 'Normal';

  @override
  String get eqPresetClassical => 'Klassik';

  @override
  String get eqPresetDance => 'Dance';

  @override
  String get eqPresetFolk => 'Folk';

  @override
  String get eqPresetHeavyMetal => 'Heavy Metal';

  @override
  String get eqPresetHipHop => 'Hip-Hop';

  @override
  String get eqPresetJazz => 'Jazz';

  @override
  String get eqPresetPop => 'Pop';

  @override
  String get eqPresetRock => 'Rock';

  @override
  String get eqPresetCustom => 'Eigene';

  @override
  String get eqSaveAsPreset => 'Als Preset speichern';

  @override
  String get eqSavePresetTitle => 'Preset speichern';

  @override
  String get eqRenamePresetTitle => 'Preset umbenennen';

  @override
  String get eqPresetNameLabel => 'Name';

  @override
  String get eqSavePresetHint =>
      'Wird auf diesem Telefon gespeichert, hinter den eingebauten Presets. Halte den Chip später gedrückt, um ihn umzubenennen oder zu löschen.';

  @override
  String get eqReplacePreset => 'Ersetzen';

  @override
  String get eqPresetNameTaken =>
      'Ein anderes gespeichertes Preset hat diesen Namen bereits.';

  @override
  String eqDeletePresetConfirm(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get eqHoldToCompare => 'Zum Vergleichen halten';

  @override
  String get eqHoldToCompareHint =>
      'Gedrückt halten, um den Klang ohne Equalizer zu hören.';

  @override
  String get eqOptionsTitle => 'Equalizer-Optionen';

  @override
  String get eqPreventClipping => 'Übersteuern verhindern';

  @override
  String get eqPreventClippingHint =>
      'Begrenzt Pegelspitzen, wenn Bänder angehoben werden.';

  @override
  String get eqShowValues => 'Bandwerte immer anzeigen';

  @override
  String get eqShowValuesHint =>
      'Über jedem Band eine Zahl, nicht nur beim Ziehen.';

  @override
  String get eqOutputsTitle => 'Ausgabegeräte';

  @override
  String get eqOutputsRowOff => 'Aus — eine Kurve für alle Ausgabegeräte';

  @override
  String eqOutputsNow(String name) {
    return 'Jetzt: $name';
  }

  @override
  String get eqOutputsSwitch => 'Automatisch wechseln';

  @override
  String get eqOutputsSwitchHint =>
      'Wechselt das Ausgabegerät, wird seine Kurve angewendet. Ziehen auf der Equalizer-Seite bearbeitet das Gerät, das gerade spielt.';

  @override
  String get eqOutputsRemembered => 'Gemerkte Ausgabegeräte';

  @override
  String get eqOutputSpeaker => 'Telefonlautsprecher';

  @override
  String get eqOutputWired => 'Kabelkopfhörer';

  @override
  String get eqOutputUsb => 'USB-Audio';

  @override
  String get eqOutputHdmi => 'HDMI';

  @override
  String get eqOutputBluetooth => 'Bluetooth';

  @override
  String get eqOutputOther => 'Anderes Ausgabegerät';

  @override
  String get eqOutputPlayingNow => 'spielt gerade';

  @override
  String eqOutputLastUsed(String date) {
    return 'zuletzt $date';
  }

  @override
  String get eqOutputsEmpty =>
      'Ausgabegeräte erscheinen hier, sobald du darüber hörst.';

  @override
  String eqOutputForgetConfirm(String name) {
    return '„$name“ vergessen? Beim nächsten Verbinden erscheint es wieder als neues Gerät.';
  }

  @override
  String get eqOutputForget => 'Vergessen';

  @override
  String eqOutputPickPreset(String name) {
    return 'Preset für $name';
  }

  @override
  String get eqOutputsHint =>
      'Tippe auf ein Gerät, um sein Preset zu wählen. Wische es weg, um es zu vergessen.';

  @override
  String eqEnabledOnOutput(String name) {
    return 'An — $name';
  }

  @override
  String get eqOutputNowPill => 'Jetzt';

  @override
  String get eqNeedsPlaybackTitle =>
      'Starte einen Song, um die Bänder einzurichten';

  @override
  String get eqPlayQueue => 'Warteschlange abspielen';

  @override
  String eqPlayQueueHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
    );
    return 'Setzt dort fort, wo du aufgehört hast · $_temp0';
  }

  @override
  String get eqDisabledHint =>
      'Schalte den Equalizer ein, um die Bänder anzupassen.';

  @override
  String get eqEnabledOn => 'An – Verstärkung auf Wiedergabe angewendet';

  @override
  String get eqEnabledOff => 'Aus – Bypass-Modus';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get continueLabel => 'Weiter';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSectionAppearance => 'Darstellung';

  @override
  String get settingsSectionPlayback => 'Wiedergabe';

  @override
  String get settingsSectionBrowse => 'Bibliothek';

  @override
  String get settingsTheme => 'Design';

  @override
  String get settingsTranscode => 'Audio transkodieren';

  @override
  String get settingsTranscodeSubtitle =>
      'Streame eine transkodierte Kopie vom Server (kleinere Dateien, etwas langsamerer Start). Aus spielt Originaldateien ab.';

  @override
  String get transcodeTitle => 'Transkodierung';

  @override
  String get transcodeCodec => 'Codec';

  @override
  String get transcodeBitrate => 'Bitrate';

  @override
  String get transcodeAuto => 'Serverstandard';

  @override
  String get transcodeUnavailable =>
      'Auf diesem Server ist Transkodierung nicht aktiviert – seine Titel werden in Originalqualität gestreamt.';

  @override
  String get transcodeReloadQueue => 'Auf aktuelle Warteschlange anwenden';

  @override
  String get transcodeReloadQueueSubtitle =>
      'Wenn du Transkodierungseinstellungen änderst – aktiviert: die ganze Warteschlange jetzt neu laden (der laufende Titel puffert kurz neu); deaktiviert: nur kommende Titel ändern sich, der aktuelle wird unverändert zu Ende gespielt.';

  @override
  String get settingsTapBehavior => 'Beim Antippen eines Songs';

  @override
  String get settingsStartupPage => 'Startbildschirm';

  @override
  String get tapSubtitleAddToQueue => 'Setzt ihn ans Ende der Warteschlange';

  @override
  String get tapSubtitlePlayFromHere =>
      'Ersetzt die Warteschlange und spielt ab diesem Song';

  @override
  String get tapSubtitleAppendAndJump =>
      'Setzt ihn ans Ende der Warteschlange und spielt ihn sofort';

  @override
  String get settingsVisualizerSource => 'Audioquelle';

  @override
  String get visualizerSourceSubtitleSynthesized => 'Keine Berechtigung nötig';

  @override
  String get visualizerSourceSubtitleReal =>
      'Braucht die Mikrofonberechtigung, nutzt das Mikrofon aber nie';

  @override
  String get settingsAlbumGrid => 'Album-Raster';

  @override
  String get settingsFileMetadata => 'Songinfos im Datei-Explorer';

  @override
  String get settingsLetterStrip => 'A–Z-Leiste';

  @override
  String get settingsLetterStripSide => 'Seite';

  @override
  String get settingsLetterStripLeft => 'Links';

  @override
  String get settingsLetterStripRight => 'Rechts';

  @override
  String get settingsReset => 'Einstellungen zurücksetzen';

  @override
  String get settingsResetDone => 'Einstellungen zurückgesetzt';

  @override
  String get realAudioDialogTitle => 'Echtes Audio verwenden?';

  @override
  String get realAudioDialogBody =>
      'Um auf den laufenden Song zu reagieren, liest der Visualizer mStreams eigene Audioausgabe – und das erlaubt Android nur mit der Mikrofonberechtigung.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Berechtigung dauerhaft verweigert. Aktiviere sie in den Systemeinstellungen, um echtes Audio zu verwenden.';

  @override
  String get realAudioPermDenied =>
      'Berechtigung verweigert. Es bleibt bei synthetisiertem Audio.';

  @override
  String get visualizerTapHint =>
      'Tippen = nächstes Preset · Zurück-Pfeil (oben links) oder lange drücken zum Schließen';

  @override
  String get visualizerFailed => 'Visualizer konnte nicht gestartet werden';

  @override
  String get visualizerBringingUp => 'Renderer wird gestartet…';

  @override
  String get visualizerReady => 'Visualizer bereit';

  @override
  String get visualizerBridgeFailed => 'Bridge konnte nicht gestartet werden';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Audioquelle: $source';
  }

  @override
  String get visualizerTapToClose => 'Zum Schließen irgendwo tippen';

  @override
  String get visualizerClose => 'Visualizer schließen';

  @override
  String get visualizerPreviousPreset => 'Vorheriges Preset';

  @override
  String get visualizerNextPreset => 'Nächstes Preset';

  @override
  String get visualizerUnsupported =>
      'Der Visualizer wird derzeit nur unter Android unterstützt.';

  @override
  String get aboutTitle => 'Über';

  @override
  String aboutBuiltBy(String name) {
    return 'Entwickelt von $name';
  }

  @override
  String get linkDiscordSubtitle => 'Community-Chat';

  @override
  String get linkGithubSubtitle => 'Quellcode des mStream-Servers';

  @override
  String get linkHomepageSubtitle => 'Projekt-Homepage';

  @override
  String get aboutAttributions => 'Danksagungen';

  @override
  String get aboutAttributionsSubtitle =>
      'Lizenz, Shader-Credits und Open-Source-Hinweise.';

  @override
  String get aboutSponsor => 'mStream unterstützen';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get info => 'Info';

  @override
  String get makeDefault => 'Als Standard festlegen';

  @override
  String get goBack => 'Zurück';

  @override
  String get play => 'Abspielen';

  @override
  String get playAll => 'Alle abspielen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get create => 'Erstellen';

  @override
  String get copy => 'Kopieren';

  @override
  String get done => 'Fertig';

  @override
  String get copiedToClipboard => 'In Zwischenablage kopiert';

  @override
  String get attributionsTitle => 'Danksagungen';

  @override
  String get attributionsSectionLicense => 'Lizenz';

  @override
  String get attributionsSectionShaders => 'Visualizer-Shader';

  @override
  String get attributionsSectionLibraries => 'Native Bibliotheken';

  @override
  String get attributionsSectionEverythingElse => 'Alles Weitere';

  @override
  String get attributionsLicenseBody =>
      'Freie Software unter der GNU General Public License v3.0. Du darfst sie unter diesen Bedingungen nutzen, studieren, teilen und verändern.';

  @override
  String get attributionsPackages => 'Open-Source-Paketlizenzen';

  @override
  String get attributionsPackagesSubtitle =>
      'Vollständige Lizenztexte für alle gebündelten Flutter/Dart-Pakete.';

  @override
  String get manageServersTitle => 'Server verwalten';

  @override
  String get manageServerInfo => 'Serverinfo';

  @override
  String get manageServerDownloadFolder => 'Download-Ordner:';

  @override
  String get manageServerCopyPath => 'Download-Pfad kopieren';

  @override
  String get manageServerPathCopied => 'Pfad in Zwischenablage kopiert';

  @override
  String get confirmRemoveServerTitle => 'Serverentfernung bestätigen';

  @override
  String get removeSyncedFiles =>
      'Synchronisierte Dateien vom Gerät entfernen?';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistsNew => 'Neue Playlist';

  @override
  String get playlistsEmptyTitle => 'Noch keine Playlists';

  @override
  String get playlistsEmptyBody =>
      'Erstelle eine über die Schaltfläche „Neue Playlist“ und fülle sie dann mit der Wischaktion „Zur Playlist hinzufügen“ in der Warteschlange.';

  @override
  String get playlistNameHint => 'Name';

  @override
  String get playlistsRename => 'Playlist umbenennen';

  @override
  String get playlistFallbackTitle => 'Playlist';

  @override
  String get playlistEmptyDetail =>
      'Playlist ist leer.\nFüge Titel über die Warteschlange hinzu.';

  @override
  String get shareEmptyTitle => 'Leere Warteschlange';

  @override
  String get shareEmptyBody =>
      'Füge Songs zur Warteschlange hinzu, bevor du teilst.';

  @override
  String get shareBlockedTitle =>
      'Diese Warteschlange kann nicht geteilt werden';

  @override
  String get shareLocalOnlyBody =>
      'Die Warteschlange enthält Songs, die nur auf diesem Gerät sind (auf keinem Server). Teilen funktioniert nur, wenn jeder Song in der Warteschlange von einem einzigen Server stammt.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'Die Warteschlange mischt Songs von $count Servern ($names). Teilen funktioniert nur, wenn jeder Song von einem einzigen Server stammt.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'Der Server „$name“ ist nicht mehr in deiner Serverliste. Füge ihn erneut hinzu, um seine Warteschlange zu teilen.';
  }

  @override
  String get shareTitle => 'Playlist teilen';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
    );
    return '$_temp0 von $url';
  }

  @override
  String get shareLinkExpires => 'Link läuft ab';

  @override
  String get shareExpireNever => 'Nie';

  @override
  String get shareExpire1Day => 'Nach 1 Tag';

  @override
  String get shareExpire7Days => 'Nach 7 Tagen';

  @override
  String get shareExpire30Days => 'Nach 30 Tagen';

  @override
  String get shareAction => 'Teilen';

  @override
  String get shareDoneTitle => 'Playlist geteilt';

  @override
  String get shareDoneBody =>
      'Jeder mit diesem Link kann die Warteschlange abspielen:';

  @override
  String get save => 'Speichern';

  @override
  String get start => 'Start';

  @override
  String get addServerTitle => 'Server hinzufügen';

  @override
  String get editServerTitle => 'Server bearbeiten';

  @override
  String get fieldServerUrl => 'Server-URL';

  @override
  String get fieldPublicAccess => 'Öffentlicher Zugriff';

  @override
  String get publicAccessSubtitle =>
      'Server ist öffentlich zugänglich – kein Benutzername oder Passwort erforderlich.';

  @override
  String get fieldUsername => 'Benutzername';

  @override
  String get fieldPassword => 'Passwort';

  @override
  String get fieldPasswordShow => 'Passwort anzeigen';

  @override
  String get fieldPasswordHide => 'Passwort ausblenden';

  @override
  String get fieldSdCard => 'Auf SD-Karte herunterladen';

  @override
  String get sdCardSubtitle =>
      'Heruntergeladene Musik auf der austauschbaren SD-Karte statt im internen Speicher speichern.';

  @override
  String get testConnectionButton => 'Verbindung testen';

  @override
  String get testing => 'Wird getestet…';

  @override
  String get connecting => 'Verbinden…';

  @override
  String get validatorUrlNeeded => 'Server-URL ist erforderlich';

  @override
  String get validatorUrlParse => 'URL kann nicht verarbeitet werden';

  @override
  String get testEnterUrl => 'Gib zuerst eine Server-URL ein.';

  @override
  String get testParseUrl => 'URL konnte nicht verarbeitet werden.';

  @override
  String get testTimedOut => 'Zeitüberschreitung bei der Verbindung.';

  @override
  String get connectionSuccessful => 'Verbindung erfolgreich!';

  @override
  String get couldNotReachServer =>
      'Server nicht erreichbar. Falls eine Anmeldung erforderlich ist, deaktiviere „Öffentlicher Zugriff“ und füge Zugangsdaten hinzu.';

  @override
  String get failedToLogin => 'Anmeldung fehlgeschlagen';

  @override
  String testConnected(String version) {
    return 'Verbunden – mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'Verbindung fehlgeschlagen: $error';
  }

  @override
  String get sleepTimerTitle => 'Sleep-Timer';

  @override
  String get sleepTimerHint =>
      'Wähle eine Dauer, nach der die Wiedergabe pausiert wird.';

  @override
  String get sleepTimerCustom => 'Benutzerdefiniert';

  @override
  String get sleepTimerCustomHint => 'Minuten (1–600)';

  @override
  String get sleepTimerCancel => 'Timer abbrechen';

  @override
  String get sleepTimerInvalid =>
      'Gib eine Zahl zwischen 1 und 600 Minuten ein';

  @override
  String sleepTimerPausesIn(String time) {
    return 'Pausiert in $time';
  }

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String sleepTimerSet(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Sleep-Timer auf $minutes Minuten gesetzt',
      one: 'Sleep-Timer auf 1 Minute gesetzt',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Hinzufügen';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String autoDjSongsPerFetchValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Harmonisches Mixen';

  @override
  String get autoDjHarmonicHint => 'Nächster Song in einer passenden Tonart';

  @override
  String get autoDjDurationRange => 'Länge';

  @override
  String get autoDjMoodTitle => 'Intelligente Filter';

  @override
  String get autoDjGenreLoadError => 'Genres konnten nicht geladen werden';

  @override
  String get download => 'Herunterladen';

  @override
  String get addAll => 'Alle hinzufügen';

  @override
  String get browserMoreActions => 'Weitere Aktionen';

  @override
  String get browserConfirmDeletePlaylist => 'Playlist-Löschung bestätigen';

  @override
  String get browserConfirmDeleteFolder => 'Ordner-Löschung bestätigen';

  @override
  String get browserSearchHint => 'Datenbank durchsuchen';

  @override
  String get searchCategoriesTooltip => 'Suchbereiche';

  @override
  String get searchCategoriesHeader => 'Suchen in';

  @override
  String get searchCategoryArtists => 'Künstler';

  @override
  String get searchCategoryAlbums => 'Alben';

  @override
  String get searchCategorySongs => 'Songs';

  @override
  String get searchCategoryFiles => 'Dateien';

  @override
  String get searchCategoryLyrics => 'Songtexte';

  @override
  String searchSubheaderResults(String term) {
    return 'Ergebnisse für „$term“';
  }

  @override
  String searchSubheaderCategories(String categories) {
    return 'Suche in: $categories';
  }

  @override
  String browserDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Downloads gestartet',
      one: '1 Download gestartet',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs zur Warteschlange hinzugefügt',
      one: '1 Song zur Warteschlange hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Mediathek';

  @override
  String get tabQueue => 'Warteschlange';

  @override
  String get drawerTagline => 'Persönliches Musikstreaming';

  @override
  String get mainFailedToConnect => 'Verbindung zum Server fehlgeschlagen';

  @override
  String get mainQueueEmpty => 'Warteschlange ist leer';

  @override
  String get queueEmptyDjHint => 'Auto DJ ist an und braucht einen Starttitel.';

  @override
  String get queueEmptyDjRandom => 'Zufälligen Titel wählen';

  @override
  String get queueEmptyDjChoose => 'Titel auswählen';

  @override
  String get mainClearQueue => 'Warteschlange leeren';

  @override
  String get mainSync => 'Synchronisieren';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ aktiviert';

  @override
  String get autoDjDisabled => 'Auto DJ deaktiviert';

  @override
  String autoDjEnabledFor(String url) {
    return 'Auto DJ aktiviert für $url';
  }

  @override
  String get addToPlaylistTitle => 'Zur Playlist hinzufügen';

  @override
  String get addToPlaylistEmpty =>
      'Noch keine Playlists – tippe auf +, um eine zu erstellen.';

  @override
  String addedToPlaylist(String name) {
    return 'Zu $name hinzugefügt';
  }

  @override
  String get testConnectedSignedIn => 'Verbunden – erfolgreich angemeldet.';

  @override
  String get testSignInFailed =>
      'Server erreicht, aber die Anmeldung ist fehlgeschlagen – überprüfe Benutzernamen und Passwort.';

  @override
  String get browserFileExplorer => 'Datei-Explorer';

  @override
  String get browserLocalFiles => 'Lokale Dateien';

  @override
  String get browserPlaylists => 'Playlists';

  @override
  String get browserAlbums => 'Alben';

  @override
  String get browserArtists => 'Künstler';

  @override
  String get browserGenres => 'Genres';

  @override
  String get genreSourceTags => 'Tags';

  @override
  String get genreSourceGenerated => 'Generiert';

  @override
  String get genreSourceBoth => 'Beide';

  @override
  String get genreSourceMixed => 'Gemischt';

  @override
  String get genreSourceLabel => 'Genre-Quelle';

  @override
  String get moodFilters => 'Filter';

  @override
  String get moodValenceGroup => 'Fröhlich, neutral oder traurig';

  @override
  String get moodEnergyGroup => 'Entspannt, neutral oder aggressiv';

  @override
  String get moodVoiceGroup => 'Instrumental oder Gesang';

  @override
  String get moodTagsGroup => 'Tags';

  @override
  String get moodHappy => 'Fröhlich';

  @override
  String get moodNeutral => 'Neutral';

  @override
  String get moodSad => 'Traurig';

  @override
  String get moodRelaxed => 'Entspannt';

  @override
  String get moodAggressive => 'Aggressiv';

  @override
  String get moodInstrumental => 'Instrumental';

  @override
  String get moodVocals => 'Gesang';

  @override
  String get moodAcoustic => 'Akustisch';

  @override
  String get moodParty => 'Party';

  @override
  String get moodDanceable => 'Tanzbar';

  @override
  String get moodStrict => 'Streng';

  @override
  String get moodStandard => 'Standard';

  @override
  String get moodLoose => 'Locker';

  @override
  String get moodStrictnessGroup => 'Streng, Standard oder locker';

  @override
  String get moodSort => 'Sortieren';

  @override
  String get moodSortRating => 'Bewertung';

  @override
  String get moodSortNewest => 'Neueste';

  @override
  String get moodSortMatch => 'Treffer';

  @override
  String get browserRecent => 'Neueste';

  @override
  String get browserRated => 'Bewertet';

  @override
  String get browserSectionLibrary => 'Bibliothek';

  @override
  String get browserSectionListen => 'Hören';

  @override
  String get browserSectionNetwork => 'Netzwerk';

  @override
  String get browserSectionServer => 'Server';

  @override
  String get browserFederation => 'Föderation';

  @override
  String get browserAutoDjOn => 'An';

  @override
  String get browserAutoDjOff => 'Aus';

  @override
  String browserSharedLibraries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count geteilte Bibliotheken',
      one: '1 geteilte Bibliothek',
    );
    return '$_temp0';
  }

  @override
  String get browserSearch => 'Suchen';

  @override
  String get browserWelcomeTitle => 'Willkommen bei mStream';

  @override
  String get browserWelcomeSubtitle =>
      'Hier tippen, um einen Server hinzuzufügen';

  @override
  String get settingsVisualizerKnobs => 'Regler zur Feinabstimmung';

  @override
  String get settingsVisualizerKnobsSubtitle => 'Nur ShaderToy';

  @override
  String get visualizerTuningTitle => 'Feinabstimmung';

  @override
  String get close => 'Schließen';

  @override
  String get migMoveStopped =>
      'Verschieben gestoppt – nicht genug Speicherplatz oder der Speicherort ist nicht verfügbar.';

  @override
  String get migMoveComplete => 'Verschieben abgeschlossen';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Verschieben abgeschlossen – $count Dateien übersprungen (am Zielort nicht unterstützt)',
      one:
          'Verschieben abgeschlossen – 1 Datei übersprungen (am Zielort nicht unterstützt)',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'Downloads werden verschoben… $progress – lass die App geöffnet';
  }

  @override
  String get migRetry => 'Erneut versuchen';

  @override
  String get queueDownloadAll => 'Alle herunterladen';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel werden für die Offline-Wiedergabe heruntergeladen.',
      one: '1 Titel wird für die Offline-Wiedergabe heruntergeladen.',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'Mehr';

  @override
  String get commonOn => 'An';

  @override
  String get commonOff => 'Aus';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Braucht einen 4K-Chromecast; höchste Last fürs Telefon';

  @override
  String get eqCasting =>
      'Der Equalizer passt das Audio auf diesem Gerät an, daher ist er während der Übertragung auf ein Cast-Gerät nicht verfügbar. Trenne die Verbindung, um ihn zu verwenden.';

  @override
  String get browserNothingToDownload =>
      'In dieser Liste gibt es nichts zum Herunterladen';

  @override
  String get browserDownloadAllTitle => 'Alle herunterladen';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien werden heruntergeladen.',
      one: '1 Datei wird heruntergeladen.',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => 'Suche schließen';

  @override
  String get browserSearchThisList => 'Diese Liste durchsuchen';

  @override
  String get browserSearchList => 'Liste durchsuchen';

  @override
  String browserNoMatches(String query) {
    return 'Keine Treffer für „$query“';
  }

  @override
  String get clear => 'Leeren';

  @override
  String get dlLocationUnavailable => 'Download-Speicherort nicht verfügbar';

  @override
  String get dlLocationUnavailableServer =>
      'Download-Speicherort für diesen Server nicht verfügbar.';

  @override
  String get dlFailed =>
      'Ein Download ist fehlgeschlagen – überprüfe deine Verbindung.';

  @override
  String get dlFatSkip =>
      'Einige Titel können auf dieser Karte nicht gespeichert werden – ihre Namen werden nicht unterstützt. Sie werden stattdessen gestreamt.';

  @override
  String get dlServerGone => 'Dieser Server ist nicht mehr konfiguriert.';

  @override
  String get dlStorageUnavailable =>
      'Speicherort nicht verfügbar – verbinde die SD-Karte erneut oder ändere den Speicherort dieses Servers unter „Server bearbeiten“.';

  @override
  String get dlCouldNotStart =>
      'Download konnte nicht gestartet werden – Speicher nicht verfügbar.';

  @override
  String get storageLocationLabel => 'Speicherort';

  @override
  String get storageAppLocal => 'App-intern';

  @override
  String get storagePermanent => 'Dauerhaft';

  @override
  String get storageSdCard => 'SD-Karte';

  @override
  String get storageSdSwitchTitle => 'Auf SD-Karte speichern';

  @override
  String get storageSdSwitchSubtitle =>
      'Im App-Ordner der SD-Karte gespeichert – keine Berechtigung nötig, wird aber beim Deinstallieren der App entfernt.';

  @override
  String get storageHelpAppLocal =>
      'Innerhalb der App gespeichert. Wird beim Deinstallieren der App oder Löschen der App-Daten gelöscht.';

  @override
  String get storageHelpPermanent =>
      'In einem von dir gewählten Ordner gespeichert. Übersteht das Deinstallieren der App. Erfordert „Zugriff auf alle Dateien“.';

  @override
  String get storageHelpSdCard =>
      'In einem von dir gewählten Ordner auf der SD-Karte gespeichert. Ist möglicherweise nicht mehr verfügbar, wenn die Karte entfernt wird. Manche Geräte lassen Apps nicht auf SD-Karten schreiben – falls die Ordnerauswahl immer wieder fehlschlägt, verwende Dauerhaft oder App-intern.';

  @override
  String get storageChooseFolder => 'Ordner wählen';

  @override
  String get storageNoFolderChosen => 'Noch kein Ordner gewählt';

  @override
  String get storageDownloadFolderLabel => 'Download-Ordner';

  @override
  String get storageDownloadFolderHint => 'Ordnername';

  @override
  String get storageBrowse => 'Durchsuchen';

  @override
  String get storageDownloadFolderHelp =>
      'Dateien werden in ein Verzeichnis \'media/<folder>\' auf diesem Gerät heruntergeladen. Wenn du den Ordner eines früheren Servers wiederverwendest, bleiben dessen heruntergeladene Songs erhalten, sobald du einen verlorenen Server erneut hinzufügst.';

  @override
  String get storageNoStorageAvailable => 'Kein Speicher verfügbar';

  @override
  String get storageNoDownloadFolders =>
      'Keine vorhandenen Download-Ordner gefunden';

  @override
  String get storageExistingFolders => 'Vorhandene Download-Ordner';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente',
      one: '1 Element',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'Gewähre „Zugriff auf alle Dateien“, um Downloads dauerhaft zu speichern, und wähle dann den Modus erneut.';

  @override
  String get storageSettings => 'Einstellungen';

  @override
  String get storageNoVolume => 'Es konnte kein Speichervolume gefunden werden';

  @override
  String get storageNotWritable =>
      'In diesen Ordner kann nicht geschrieben werden – wähle einen anderen.';

  @override
  String get storageNewFolder => 'Neuer Ordner';

  @override
  String get storageFolderNameHint => 'Ordnername';

  @override
  String get storageCouldNotCreateFolder =>
      'Ordner konnte nicht erstellt werden';

  @override
  String get storageNoSubfolders => 'Hier gibt es keine Unterordner';

  @override
  String get storageUseThisFolder => 'Diesen Ordner verwenden';

  @override
  String get storageMovedToNewFolder =>
      'Heruntergeladene Dateien in den neuen Ordner verschoben.';

  @override
  String get storageMoveAlreadyRunning =>
      'Ein Verschiebevorgang läuft bereits – lass ihn zuerst abschließen.';

  @override
  String get storageMigrateTitle => 'Anderes Speichervolume';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Die $count heruntergeladenen Dateien dieses Servers ($size) befinden sich auf einem anderen Speichervolume als der neue Speicherort. Wähle, was geschehen soll:',
      one:
          'Die 1 heruntergeladene Datei dieses Servers ($size) befindet sich auf einem anderen Speichervolume als der neue Speicherort. Wähle, was geschehen soll:',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return 'Nicht genug freier Speicherplatz am Zielort ($free frei). Ein Verschieben kann mittendrin fehlschlagen – gib zuerst Speicherplatz frei.';
  }

  @override
  String get storageMigrateMove => 'Verschieben';

  @override
  String get storageMigrateMoveBody =>
      'Im Hintergrund an den neuen Speicherort kopieren und dabei jede alte Kopie löschen. Lass die App geöffnet, bis der Vorgang abgeschlossen ist.';

  @override
  String get storageMigrateLeave => 'Belassen';

  @override
  String get storageMigrateLeaveBody =>
      'Jetzt wechseln; die alten Downloads bleiben, wo sie sind, und werden am neuen Speicherort erneut heruntergeladen.';

  @override
  String get storageMigrateDelete => 'Alte Downloads löschen';

  @override
  String get storageMigrateDeleteBody =>
      'Jetzt wechseln und die alten Dateien entfernen; sie werden am neuen Speicherort erneut heruntergeladen.';

  @override
  String get storageMovingBackground =>
      'Deine Downloads werden im Hintergrund verschoben – lass die App geöffnet.';

  @override
  String get storageChooseFolderFirst => 'Wähle zuerst einen Download-Ordner.';

  @override
  String get storageChooseSdFolderFirst =>
      'Wähle zuerst einen Ordner auf der SD-Karte. Falls jeder Ordner abgelehnt wird, lässt dein Gerät Apps möglicherweise nicht auf die Karte schreiben – verwende stattdessen Dauerhaft oder App-intern.';

  @override
  String get castPlayOn => 'Abspielen auf';

  @override
  String get castPlayOnTooltip => 'Abspielen auf…';

  @override
  String get castSearching => 'Suche nach Cast-Geräten…';

  @override
  String get castNotSeeing =>
      'Dein Gerät wird nicht angezeigt? Stelle sicher, dass es im selben WLAN ist.';

  @override
  String get castVisualizer => 'Visualizer übertragen';

  @override
  String get castVisualizerSubtitle => 'Nur Chromecast';

  @override
  String get castThisDevice => 'Dieses Gerät';

  @override
  String get visualizerNoKnobs => 'Dieser Shader hat keine Regler.';

  @override
  String get nowPlaying => 'Aktuelle Wiedergabe';

  @override
  String get settingsPlayerLayout => 'Layout von „Aktuelle Wiedergabe“';

  @override
  String get playerLayoutSmall => 'Klein';

  @override
  String get playerLayoutMedium => 'Mittel';

  @override
  String get playerLayoutLarge => 'Groß';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get queueNothingToDownloadEmpty =>
      'Warteschlange ist leer – nichts herunterzuladen';

  @override
  String get queueNothingToDownloadSaved =>
      'Nichts herunterzuladen – Titel sind bereits gespeichert';

  @override
  String get settingsAccentColor => 'Akzentfarbe';

  @override
  String get accentThemeDefault => 'Design-Standard';

  @override
  String get accentCustom => 'Benutzerdefiniert';

  @override
  String get lanOnYourNetwork => 'Server in deinem lokalen Netzwerk';

  @override
  String get lanSearching => 'Suche nach Servern…';

  @override
  String get lanRefresh => 'Aktualisieren';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return 'Bei $name anmelden';
  }

  @override
  String get lanUnreachable =>
      'Dieser Server ist im Netzwerk nicht erreichbar.';

  @override
  String get lanNoCode =>
      'Schnellverbindung ist auf diesem Server aktiviert, aber es wurde kein Kopplungscode geteilt. Melde dich als Admin an oder bitte den Betreiber, die Code-Freigabe zu aktivieren.';

  @override
  String get settingsResumeQueue => 'Warteschlange beim Start fortsetzen';

  @override
  String get settingsOfflineQueue => 'Warteschlange herunterladen';

  @override
  String get settingsOfflineQueueSubtitle =>
      'Die Wiedergabe läuft auch ohne Verbindung weiter.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Nur über WLAN';

  @override
  String get settingsAutoDownloadCap => 'Download-Limit';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unbegrenzt';

  @override
  String get settingsAutoDownloadCapField => 'Anzahl Titel';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Wie viele Titel ab dem laufenden heruntergeladen bleiben. Ältere, die herausfallen, werden gelöscht, sobald neue dazukommen.';

  @override
  String get downloadWaitingWifi => 'Wartet auf WLAN';

  @override
  String get settingsRatingHalf => 'Halbsterne-Bewertungen';

  @override
  String get settingsRatingHalfSubtitle => 'Stern lange drücken';

  @override
  String get ratingTitle => 'Bewerten';

  @override
  String get ratingFailed => 'Bewertung konnte nicht gespeichert werden';

  @override
  String get diagnosticsTitle => 'Diagnose';

  @override
  String get diagnosticsEnable => 'Protokollierung aktivieren';

  @override
  String get diagnosticsHint =>
      'Protokolle bleiben auf deinem Gerät. Tokens werden vor dem Kopieren oder Teilen ausgeblendet.';

  @override
  String get diagnosticsVerbose => 'Ausführliche Protokollierung';

  @override
  String get diagnosticsVerboseHint =>
      'Protokolliert auch häufige Ereignisse wie Fokuswechsel der App. Nur bei der Diagnose eines Wiedergabeproblems nötig.';

  @override
  String get diagnosticsCopy => 'Kopieren';

  @override
  String get diagnosticsShare => 'Teilen';

  @override
  String get diagnosticsClear => 'Löschen';

  @override
  String get diagnosticsCopied => 'Protokolle in die Zwischenablage kopiert';

  @override
  String get diagnosticsEmpty => 'Noch keine Protokolle';

  @override
  String get storageAppExternal => 'App-extern';

  @override
  String get storageAppSdCard => 'App-SD-Karte';

  @override
  String get selfSignedTitle => 'Selbstsigniertes Zertifikat zulassen';

  @override
  String get selfSignedSubtitle =>
      'Überspringt die TLS-Prüfung für diesen Server. Nur in einem vertrauenswürdigen Netzwerk aktivieren.';

  @override
  String get importedShadersTitle => 'Importierte Shader';

  @override
  String get importedShadersRescan => 'Ordner neu scannen';

  @override
  String get importedShadersDropHint =>
      'Lege .glsl-Dateien in diesen Ordner und scanne dann neu:';

  @override
  String get importedShadersCopyPath => 'Pfad kopieren';

  @override
  String get importedShadersReachableHint =>
      'Über USB erreichbar. Wird beim Deinstallieren von mStream gelöscht.';

  @override
  String get importedShadersRemove => 'Löschen';

  @override
  String get importedShadersEmptyTitle => 'Noch keine Shader';

  @override
  String get importedShadersEmptyBody =>
      'Kopiere .glsl-Dateien im Shadertoy-Stil in den Ordner oben und tippe dann auf „Ordner neu scannen“.';

  @override
  String get importedShadersInvalid =>
      'Läuft vielleicht nicht: kein mainImage oder main';

  @override
  String get importedShadersImportDownloads =>
      '.glsl aus Downloads importieren';

  @override
  String importedShadersDownloadsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Shader importiert',
      one: '$count Shader importiert',
    );
    return '$_temp0';
  }

  @override
  String get importedShadersDownloadsNone =>
      'Keine neuen .glsl-Dateien in Downloads';

  @override
  String get importedShadersDownloadsNoPermission =>
      'Zum Lesen von Downloads wird die Speicherberechtigung benötigt';

  @override
  String get addServerTabUrl => 'Server-URL';

  @override
  String get addServerTabQuickConnect => 'Schnellverbindung';

  @override
  String get irohPairingHeader => 'Mit Kopplungscode verbinden';

  @override
  String get irohPairingBody =>
      'Aktiviere „Remote Access“ auf dem Server und füge dann den Kopplungscode ein oder scanne den QR-Code.';

  @override
  String get irohPairingCodeLabel => 'Kopplungscode';

  @override
  String get irohPairingCodeHint =>
      'Code aus dem Remote-Access-Bereich des Servers einfügen';

  @override
  String get irohShowPairingCode => 'Kopplungscode anzeigen';

  @override
  String get irohQrBody =>
      'Scanne den Code mit der mStream-App auf einem anderen Gerät, um es mit diesem Server zu verbinden – oder kopiere den Code und füge ihn dort ein.';

  @override
  String get irohQrCaution =>
      'Jeder mit diesem Code kann sich mit deinem Server verbinden.';

  @override
  String get irohScanQr => 'QR scannen';

  @override
  String get irohPaste => 'Einfügen';

  @override
  String get irohTestConnection => 'Verbindung testen';

  @override
  String get irohTesting => 'Wird getestet…';

  @override
  String get irohScannerTitle => 'Kopplungs-QR scannen';

  @override
  String get irohQrAndroidOnly =>
      'QR-Scan ist auf diesem Gerät nicht verfügbar.';

  @override
  String get irohAndroidOnly =>
      'Schnellverbindung ist auf diesem Gerät nicht verfügbar.';

  @override
  String get irohCameraPermission =>
      'Zum Scannen eines Codes wird die Kamera-Berechtigung benötigt.';

  @override
  String get irohPasteFirst =>
      'Füge zuerst einen Kopplungscode ein oder scanne ihn.';

  @override
  String get irohTestFirst => 'Teste zuerst die Verbindung.';

  @override
  String get irohTestConnected => 'Über den iroh-Tunnel verbunden';

  @override
  String irohTestConnectedVersion(String version) {
    return 'Über den iroh-Tunnel verbunden – mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · direkt';

  @override
  String get irohPathSuffixRelay => ' · über Relay';

  @override
  String get irohTunnelNoAnswer =>
      'The tunnel connected, but the server closed the request without answering. On the server, check the bind address and port mStream listens on (the tunnel reaches it at 127.0.0.1), then try again.';

  @override
  String get irohTunnelTimeout =>
      'Tunnel geöffnet, aber der Server hat nicht rechtzeitig geantwortet.';

  @override
  String irohTunnelTestFailed(String error) {
    return 'Tunneltest fehlgeschlagen: $error';
  }

  @override
  String get irohSignInHeader => 'Anmelden';

  @override
  String get irohSigningIn => 'Anmeldung läuft…';

  @override
  String get irohSignInSave => 'Anmelden & speichern';

  @override
  String get irohSignInTimeout => 'Zeitüberschreitung bei der Anmeldung.';

  @override
  String irohSignInFailed(String error) {
    return 'Anmeldung fehlgeschlagen: $error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return 'Anmeldung fehlgeschlagen (HTTP $status). Prüfe Benutzernamen und Passwort.';
  }

  @override
  String get irohBannerConnecting => 'Verbindung zum Server wird hergestellt…';

  @override
  String get irohBannerReconnecting =>
      'Verbindung zum Server wird wiederhergestellt…';

  @override
  String get irohBannerDisconnected => 'Verbindung zum Server getrennt.';

  @override
  String get irohBannerRelay => 'Über Relay verbunden – langsamerer Pfad.';

  @override
  String get irohBannerRepair =>
      'Server-Kopplung geändert – zum erneuten Verbinden neu koppeln.';

  @override
  String get irohRepairAction => 'Neu koppeln';

  @override
  String get irohRetry => 'Erneut versuchen';

  @override
  String get irohRepairTitle => 'Server neu koppeln';

  @override
  String get irohRepairBody =>
      'Der Kopplungscode dieses Servers hat sich geändert (sein geheimer Schlüssel wurde erneuert). Füge den neuen Code aus dem Remote-Access-Bereich des Servers ein oder scanne ihn.';

  @override
  String get irohRepairFailed =>
      'Verbindung mit diesem Code nicht möglich – prüfe ihn und versuche es erneut.';

  @override
  String get irohPathDirect => 'Direkt';

  @override
  String get irohPathRelay => 'Relay';

  @override
  String get irohCastUnavailable =>
      'Übertragen auf externe Geräte ist bei Peer-to-Peer-Servern (iroh) nicht verfügbar – die Wiedergabe bleibt auf diesem Gerät.';

  @override
  String get irohShareUnavailable =>
      'Teilen ist bei Peer-to-Peer-Servern (iroh) nicht verfügbar – sie haben keine öffentliche URL zum Verlinken.';

  @override
  String get discoverTitle => 'Mehr davon';

  @override
  String get discoverPageTitle => 'Entdecken';

  @override
  String discoverPageWindowDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get discoverPageWindowAll => 'Gesamt';

  @override
  String discoverPageWidened(String window) {
    return 'In den letzten $window war nichts dabei, deshalb stammen diese von früher.';
  }

  @override
  String get discoverPageBasedOn => 'Basierend auf';

  @override
  String get discoverPageBasedOnLast => 'Basierend auf den letzten';

  @override
  String get discoverPageBasedOnAllTime => 'Zeitraum';

  @override
  String get discoverPageMoreOptions => 'Weitere Optionen';

  @override
  String get discoverPageNewSeeds => 'Neue Ausgangstitel';

  @override
  String get discoverPageAlbumsLibrary => 'Alben aus deiner Bibliothek';

  @override
  String discoverPageAlbumsPeer(String name) {
    return 'Alben von $name';
  }

  @override
  String get discoverPageAlbumsPeers => 'Alben von verbundenen Servern';

  @override
  String get discoverPageSongsLibrary => 'Titel aus deiner Bibliothek';

  @override
  String discoverPageSongsPeer(String name) {
    return 'Titel von $name';
  }

  @override
  String get discoverPageSongsPeers => 'Titel von verbundenen Servern';

  @override
  String get discoverPageLibraryNothing =>
      'Nichts Neues in deiner Bibliothek klingt wie diese Titel.';

  @override
  String get discoverPagePeersQuiet =>
      'Gerade nichts von deinen verbundenen Servern.';

  @override
  String get discoverPagePeersFailed =>
      'Deine verbundenen Server waren nicht erreichbar.';

  @override
  String get discoverPageSaveAsPlaylist => 'Als Playlist speichern';

  @override
  String get discoverPageBrowseLibrary => 'Bibliothek durchstöbern';

  @override
  String get discoverPageAgoToday => 'heute';

  @override
  String get discoverPageAgoYesterday => 'gestern';

  @override
  String discoverPageAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Monaten',
      one: 'vor 1 Monat',
    );
    return '$_temp0';
  }

  @override
  String discoverPageAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Jahren',
      one: 'vor 1 Jahr',
    );
    return '$_temp0';
  }

  @override
  String get discoverPageRandomTitle =>
      'Hör ein paar Titel zu Ende, dann lernt diese Seite deinen Geschmack';

  @override
  String get discoverPageRandomBody =>
      'Entdecken richtet sich nach Titeln, die du zu Ende hörst. Übersprungene zählen nie. Bis es welche gibt, siehst du hier Vorschläge rund um einen Zufallstitel aus deiner Bibliothek.';

  @override
  String get discoverPageAnotherPick => 'Anderer Titel';

  @override
  String get discoverPageChooseSong => 'Titel wählen…';

  @override
  String get discoverPageError =>
      'Entdecken konnte nicht geladen werden. Prüfe die Verbindung und versuch es erneut.';

  @override
  String get discoverPageRetry => 'Erneut versuchen';

  @override
  String get discoverPagePickedHeader => 'Für diesen Besuch gewählt';

  @override
  String get discoverPageRandomHeader => 'Zufällige Auswahl';

  @override
  String get discoverPageDroppedHeader => 'Ausgelassen';

  @override
  String get discoverPageDroppedNote => 'einschalten, um ihn zurückzuholen';

  @override
  String discoverPagePlayedTimes(int count) {
    return '$count× gehört';
  }

  @override
  String get discoverPageListenedTo => 'angehört';

  @override
  String get discoverPageNotAnalyzed => 'noch nicht analysiert';

  @override
  String get discoverPageAddOwn => 'Eigenen hinzufügen';

  @override
  String get discoverPageAddOwnSub => 'ein Titel, von dem du mehr willst';

  @override
  String get discoverPagePickSong => 'Titel auswählen…';

  @override
  String get discoverPagePickSongSub =>
      'Bibliothek durchsuchen oder einen Zufallstitel nehmen';

  @override
  String discoverPageUseThese(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Diese $count verwenden',
      one: 'Diesen 1 verwenden',
    );
    return '$_temp0';
  }

  @override
  String get discoverMatchedBySound => 'Nach Klang gefunden';

  @override
  String get discoverSimilarTracks => 'Ähnliche Titel';

  @override
  String get discoverSimilarArtists => 'Ähnliche Künstler';

  @override
  String get discoverFromNetwork => 'Aus dem Netzwerk';

  @override
  String get discoverFromPeers => 'Von deinen Peers';

  @override
  String get discoverQueueAll => 'Alle einreihen';

  @override
  String get discoverNewArtistsOnly => 'Nur neue Künstler';

  @override
  String get discoverNotAnalyzed =>
      'Dieser Titel wurde noch nicht analysiert – ähnliche Titel erscheinen, sobald der Discovery-Scan ihn erreicht.';

  @override
  String get discoverScanPendingTitle => 'Noch nichts analysiert';

  @override
  String get discoverScanPendingBody =>
      'Auf diesem Server ist Discovery aktiviert, es wurde aber noch keine Musik analysiert. Ähnliche Titel erscheinen, sobald der Discovery-Scan gelaufen ist.';

  @override
  String get discoverCheckAgain => 'Erneut prüfen';

  @override
  String get discoverTurnedOff =>
      'Discovery wurde auf diesem Server deaktiviert.';

  @override
  String get pathScanPending =>
      'Dieser Server hat noch keine Musik analysiert, daher gibt es nichts, durch das ein Pfad führen könnte. Das funktioniert, sobald der Discovery-Scan gelaufen ist.';

  @override
  String get discoverNothingFound => 'Keine Treffer gefunden.';

  @override
  String get discoverNoSeed =>
      'Spiele einen Titel ab, um ähnliche Musik zu entdecken.';

  @override
  String get discoverLeadCopied => 'Kopiert – viel Erfolg beim Suchen!';

  @override
  String get discoverOpenMusicBrainz => 'Auf MusicBrainz öffnen';

  @override
  String get discoverNetworkWarmingUp =>
      'Noch keine Netzwerkdaten – Peer-Bibliotheken werden im Hintergrund geladen, sobald andere Server gefunden werden.';

  @override
  String get discoverNetworkNothingNew =>
      'Nichts Neues für diesen Titel – das Netzwerk hat keine unbekannten Treffer.';

  @override
  String get discoverPeersUnreachable =>
      'Deine Peers haben nicht geantwortet – sie sind möglicherweise gerade offline.';

  @override
  String get discoverPeersNothingNew =>
      'Nichts Neues für diesen Titel auf den Servern deiner Peers.';

  @override
  String get autoDjSonicTitle => 'Klangliche Ähnlichkeit';

  @override
  String get autoDjSonicSeedLabel => 'Ausgangssong';

  @override
  String get autoDjSonicSeedNone =>
      'Kein Ausgangssong – der laufende Titel verankert die Session.';

  @override
  String get autoDjSonicSeedBanner =>
      'Ausgangssong wählen – tippe irgendwo in der Bibliothek auf einen Titel';

  @override
  String get autoDjSonicSeedSearchHint => 'Nach einem Titel suchen…';

  @override
  String get autoDjSonicSeedRandom => 'Zufälliger Titel';

  @override
  String get autoDjSonicSeedRemove => 'Ausgangssong entfernen';

  @override
  String get autoDjSonicSeedFailed => 'Kein Song abrufbar';

  @override
  String get autoDjSeedNoMatch => 'Keine Songs passen zu deinen Filtern';

  @override
  String get discoverFindSimilar => 'Ähnliches finden';

  @override
  String get discoverStartSession => 'Klang-Session starten';

  @override
  String get discoverStartSessionSubtitle =>
      'Endlose Musik, die so klingt wie dieser Titel – ersetzt deine Warteschlange.';

  @override
  String get discoverStartSessionSubtitleRandom =>
      'Endlose Musik ab einem zufälligen Starttitel – ersetzt deine Warteschlange.';

  @override
  String get discoverSessionStarted =>
      'Klang-Session gestartet – Auto DJ ist an.';

  @override
  String get autoDjSonicAnchorRolling => 'Der Stimmung folgen';

  @override
  String get autoDjSonicAnchorLocked => 'Beim Ausgangssong bleiben';

  @override
  String get autoDjSonicAnchorRollingHint =>
      'Jeder Titel folgt dem aktuellen Klang der Session – sie kann sich langsam entwickeln.';

  @override
  String get autoDjSonicAnchorLockedHint =>
      'Jeder Titel bleibt die ganze Session über nah am Ausgangssong.';

  @override
  String get trackAddToPlaylist => 'Zur Playlist hinzufügen';

  @override
  String get trackAddToPlaylistFailed =>
      'Konnte nicht zur Playlist hinzugefügt werden.';

  @override
  String get discoverPlayPathTo => 'Einen Pfad spielen zu…';

  @override
  String get pathScreenTitle => 'Klangpfad';

  @override
  String get pathStartNotAnalyzed =>
      'Der Startsong wurde noch nicht analysiert – warte auf den Discovery-Scan oder wähle einen anderen.';

  @override
  String get pathEndNotAnalyzed =>
      'Der Zielsong wurde noch nicht analysiert – warte auf den Discovery-Scan oder wähle einen anderen.';

  @override
  String get pathStartSong => 'Startsong';

  @override
  String get pathEndSong => 'Zielsong';

  @override
  String get pathLength => 'Länge';

  @override
  String get pathRegenerate => 'Neu generieren';

  @override
  String get pathSaveAsPlaylist => 'Als Playlist speichern';

  @override
  String get pathSetupHint =>
      'Wähle einen Start- und einen Zielsong – die Reise dazwischen füllt sich von selbst.';

  @override
  String get pathNotSet => 'Nicht gewählt';

  @override
  String get pathUsePlaying => 'Laufenden Song verwenden';

  @override
  String get pathSearchSong => 'Suchen';

  @override
  String get pathBrowseLibrary => 'Bibliothek durchsuchen';

  @override
  String get pathBuild => 'Reise erstellen';

  @override
  String get pathStartOver => 'Neu beginnen';

  @override
  String get pathPickBannerStart =>
      'Startsong wählen – tippe irgendwo in der Bibliothek auf einen Titel';

  @override
  String get pathPickBannerEnd =>
      'Zielsong wählen – tippe irgendwo in der Bibliothek auf einen Titel';

  @override
  String get pathNothingPlaying => 'Es läuft gerade nichts';

  @override
  String pathPickOnServer(String server) {
    return 'Wähle einen Titel auf $server';
  }

  @override
  String get welcomeTranslationNote =>
      'Diese Sprache wurde maschinell übersetzt und klingt möglicherweise holprig.';

  @override
  String get welcomeTranslationCta => 'Hilf mit, mStream zu übersetzen';

  @override
  String get setupTitle => 'Schnelleinrichtung';

  @override
  String get setupSkip => 'Überspringen';

  @override
  String get setupNext => 'Weiter';

  @override
  String get setupFinish => 'Fertig';

  @override
  String get setupBack => 'Zurück';

  @override
  String get setupAccentTitle => 'Wähle deine Farbe';

  @override
  String get setupAccentBody =>
      'Die Akzentfarbe hebt Schaltflächen, Regler und die Player-Steuerung hervor. Tippe eine an, um sie auszuprobieren.';

  @override
  String get setupPlaybackTitle => 'Beim Antippen eines Songs';

  @override
  String get setupOfflineTitle => 'Warteschlange offline behalten';

  @override
  String get realAudioNoMic => 'mStream verwendet niemals dein Mikrofon.';

  @override
  String get playlistEmpty => 'Playlist ist leer';

  @override
  String get trackRating => 'Bewertung';

  @override
  String albumDiscNumber(int n) {
    return 'CD $n';
  }

  @override
  String get autoDjStartPickBanner =>
      'Starttitel wählen – tippe irgendwo in der Bibliothek auf einen Titel';

  @override
  String get autoDjStartAskShort => 'Fragen';

  @override
  String serverVersionLabel(String version) {
    return 'Server v$version';
  }

  @override
  String get serverVersionUnknown => 'Serverversion unbekannt';

  @override
  String get serverUpdateUrgent => 'Server aktualisieren';

  @override
  String get serverUpdateAvailable => 'Server-Update verfügbar';

  @override
  String serverTooOldWarning(String version) {
    return 'Dieser Server läuft mit v$version. Einige Funktionen benötigen v5.5 oder neuer und sind nicht verfügbar.';
  }

  @override
  String get torrentScreenTitle => 'Torrent hinzufügen';

  @override
  String get torrentNoServer => 'Kein Server eingerichtet.';

  @override
  String get torrentServerLabel => 'Server';

  @override
  String get torrentLibraryLabel => 'Bibliothek';

  @override
  String get torrentNoLibraries => 'Keine Bibliotheken auf diesem Server';

  @override
  String get torrentSourceLabel => 'Quelle';

  @override
  String get torrentChooseFile => '.torrent-Datei wählen';

  @override
  String get torrentOr => 'oder';

  @override
  String get torrentMagnetLabel => 'Magnet-Link';

  @override
  String get torrentMagnetInvalid => 'Kein gültiger Magnet-Link';

  @override
  String torrentNotATorrent(String name) {
    return '„$name“ ist keine .torrent-Datei';
  }

  @override
  String get torrentOpenWith => 'In anderer App öffnen';

  @override
  String get torrentOpenWithNone =>
      'Keine App auf diesem Gerät kann eine .torrent-Datei öffnen';

  @override
  String get torrentOpenWithFailed =>
      'Torrent konnte nicht an eine andere App übergeben werden';

  @override
  String get torrentIntentTitle => 'Torrent empfangen';

  @override
  String get torrentIntentBody =>
      'Zu einer Bibliothek auf deinem mStream-Server hinzufügen oder an eine andere App übergeben.';

  @override
  String get torrentIntentAdd => 'Zu mStream hinzufügen';

  @override
  String get torrentIntentDontAsk =>
      'Immer zu mStream hinzufügen, nicht mehr fragen';

  @override
  String get settingsTorrentAskTitle => 'Bei Torrents nachfragen';

  @override
  String get settingsTorrentDefaultTitle => 'Standard-App für Torrents';

  @override
  String get settingsTorrentDefaultSub => 'Öffnet die Android-Einstellungen';

  @override
  String get settingsTorrentDefaultFailed =>
      'Android-Einstellungen konnten nicht geöffnet werden';

  @override
  String get torrentAutoDetect => 'Metadaten automatisch erkennen';

  @override
  String get torrentDetecting => 'Wird erkannt…';

  @override
  String get torrentDetectNoMetadata =>
      'Zu wenig Metadaten – bitte Felder von Hand ausfüllen';

  @override
  String get torrentDetected => 'Metadaten erkannt';

  @override
  String get torrentDetectGuess => 'Unsichere Erkennung – bitte Felder prüfen';

  @override
  String get torrentMetadataLabel => 'Metadaten';

  @override
  String get torrentArtistLabel => 'Künstler';

  @override
  String get torrentAlbumLabel => 'Album';

  @override
  String get torrentYearLabel => 'Jahr';

  @override
  String get torrentDestinationLabel => 'Ziel';

  @override
  String get torrentPathLabel => 'Pfad in der Bibliothek';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹keine Bibliothek›/$path';
  }

  @override
  String get torrentPreviewContents => '‹Torrent-Inhalt›';

  @override
  String get torrentRenameRoot => 'Stammordner des Torrents umbenennen';

  @override
  String get torrentRenameRootSub => 'An den Zielordnernamen angleichen';

  @override
  String get torrentForceFresh => 'Neu herunterladen erzwingen';

  @override
  String get torrentForceFreshSub =>
      'Nicht nach bereits vorhandenen Dateien suchen';

  @override
  String get torrentSubmit => 'Torrent hinzufügen';

  @override
  String get torrentSubmitting => 'Wird hinzugefügt…';

  @override
  String get torrentUnavailable =>
      'Torrents sind auf diesem Server nicht verfügbar.';

  @override
  String get torrentPickLibrary => 'Bibliothek wählen';

  @override
  String get torrentOneSource =>
      'Magnet-Link oder .torrent-Datei angeben (eines von beiden)';

  @override
  String get torrentPathEmpty => 'Zielpfad ist leer';

  @override
  String get torrentSeeded =>
      'Bereits auf der Festplatte – wird jetzt geseedet';

  @override
  String get torrentAlreadyInClient => 'Bereits im Torrent-Client';

  @override
  String get torrentInvalidFile => 'Ungültige Torrent-Datei';

  @override
  String get torrentSeedCheckFailed =>
      'Prüfung auf vorhandene Dateien fehlgeschlagen – wird neu heruntergeladen';

  @override
  String get torrentPartialTitle => 'Einige Dateien existieren bereits';

  @override
  String get torrentPartialBody =>
      'Verknüpfe den Torrent mit einer vorhandenen Kopie, um sie zu seeden und nur Fehlendes herunterzuladen.';

  @override
  String torrentPartialCount(String matched, String total) {
    return '$matched/$total Dateien hier';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · $missing herunterzuladen';
  }

  @override
  String get torrentDownloadFresh => 'Trotzdem neu herunterladen';

  @override
  String get torrentMatchNoFolder =>
      'Dieser Treffer hat keinen Ordnernamen – nutze stattdessen \'Trotzdem neu herunterladen\'';

  @override
  String torrentAdded(String name) {
    return '„$name“ hinzugefügt';
  }

  @override
  String torrentDuplicate(String name) {
    return '„$name“ ist bereits im Client';
  }

  @override
  String serverPickerVia(String parent) {
    return 'über $parent';
  }

  @override
  String get browserFederatedReadOnly => 'Schreibgeschützter Server';

  @override
  String get browserFederatedReadOnlyNote =>
      'Playlists und Bewertungen bleiben auf deinem eigenen Server';

  @override
  String get federatedShareUnavailable =>
      'Titel auf einem geteilten Server können von hier nicht geteilt werden – sie liegen in der Bibliothek von jemand anderem.';

  @override
  String get federatedForget => 'Vergessen';

  @override
  String get federatedHide => 'In der Auswahl ausblenden';

  @override
  String get federatedShow => 'In der Auswahl anzeigen';

  @override
  String federatedNoLongerListed(String parent) {
    return 'Wird von $parent nicht mehr geteilt';
  }

  @override
  String get federationTitle => 'Föderation';

  @override
  String get federationStatusOn => 'An · mit Relay verbunden';

  @override
  String get federationStatusConnecting => 'An · verbindet…';

  @override
  String get federationStatusOff => 'Aus';

  @override
  String get federationStatusUnavailable =>
      'Auf dieser Plattform nicht verfügbar';

  @override
  String get federationSharedWithYou => 'Mit dir geteilt';

  @override
  String get federationRequestsSection => 'Anfragen';

  @override
  String get federationYourSharedLibraries => 'Deine geteilten Bibliotheken';

  @override
  String get federationAddPeer => 'Peer hinzufügen';

  @override
  String get federationShareLibrary => 'Bibliothek teilen';

  @override
  String get federationNoPeersYet =>
      'Mit diesem Server wird noch nichts geteilt.';

  @override
  String get federationNoKeysYet =>
      'Noch keine Tickets – teile eine Bibliothek, um eins zu erstellen.';

  @override
  String get federationNoRequests =>
      'Noch keine Anfragen – Server im Discovery-Netzwerk finden dich hier.';

  @override
  String get federationClipboardTicket => 'Ticket in der Zwischenablage';

  @override
  String federationTicketPreview(String name, String libraries) {
    return '$name · teilt $libraries';
  }

  @override
  String federationTicketPreviewNoLibraries(String name) {
    return '$name';
  }

  @override
  String get federationUnnamedServer => 'Unbenannter Server';

  @override
  String get federationAddPeerAction => 'Peer hinzufügen';

  @override
  String get federationPeerLive => 'live';

  @override
  String get federationPeerConnecting => 'verbindet…';

  @override
  String get federationPeerDirectTunnel => 'direkter Tunnel';

  @override
  String federationPeerViaParent(String parent) {
    return 'über $parent';
  }

  @override
  String federationPeerViaTunnel(String parent) {
    return 'über den Tunnel von $parent';
  }

  @override
  String get federationPeerMissing => 'nicht mehr geteilt';

  @override
  String get federationPeerHidden => 'in der Auswahl ausgeblendet';

  @override
  String federationMemberNote(String server) {
    return 'Teilen ist Admin-Sache. Tickets erstellen, Peers hinzufügen und Kopplungsanfragen beantworten erfordern eine Admin-Anmeldung auf $server – dieselbe, die das Admin-Panel öffnet.';
  }

  @override
  String get federationRestrictedNote =>
      'Dieser Server nimmt Admin-Aufrufe nur aus seinem eigenen Netzwerk an. Verbinde dich von zu Hause, um das Teilen hier zu verwalten.';

  @override
  String get federationDisabledNote =>
      'Die Admin-API ist auf diesem Server abgeschaltet.';

  @override
  String get federationUnsupportedNote =>
      'Dieser Server ist zu alt, um die Föderation aus der App zu verwalten. Aktualisiere mStream.';

  @override
  String get federationLoadFailed => 'Server nicht erreichbar.';

  @override
  String get federationRetry => 'Erneut versuchen';

  @override
  String get federationOffTitle =>
      'Bibliotheken mit den Servern von Freunden teilen';

  @override
  String get federationOffBody =>
      'Kopple zwei mStream-Server, um gegenseitig Musik zu hören. Getauscht werden Tickets – per Textnachricht, per Scan, per Einfügen.';

  @override
  String get federationOffPoint1Title =>
      'Nur lesen, Ende-zu-Ende-verschlüsselt';

  @override
  String get federationOffPoint1Body =>
      'Playlists und Bewertungen verlassen deinen Server nie';

  @override
  String get federationOffPoint2Title => 'Keine Portweiterleitung, kein DNS';

  @override
  String get federationOffPoint2Body =>
      'iroh findet den Weg – direkt, wenn es geht, sonst über ein Relay';

  @override
  String get federationOffPoint3Title => 'Tickets, die du widerrufen kannst';

  @override
  String get federationOffPoint3Body =>
      'Jedes wird einmal eingelöst und lässt sich jederzeit sperren';

  @override
  String get federationOffAdminOnly =>
      'Nur der Server-Admin kann das einschalten.';

  @override
  String federationOffMemberNote(String server) {
    return 'Die Föderation ist auf $server aus. Der Admin kann sie einschalten.';
  }

  @override
  String get federationTurnOn => 'Föderation einschalten';

  @override
  String get federationUnavailableNote =>
      'Die iroh-Komponente hat keinen Build für das Betriebssystem/die CPU dieses Servers, daher kann der Föderations-Endpunkt hier nicht laufen.';

  @override
  String get federationTurnedOn => 'Föderation ist an';

  @override
  String get federationTurnedOff => 'Föderation ist aus';

  @override
  String get federationToggleFailed =>
      'Die Föderationseinstellung konnte nicht geändert werden.';

  @override
  String get federationSettingsTitle => 'Föderationseinstellungen';

  @override
  String get federationSwitchSubtitle =>
      'Peer-to-Peer, Ende-zu-Ende-verschlüsselt. Keine Portweiterleitung, kein DNS.';

  @override
  String get federationStatusSection => 'Status';

  @override
  String get federationConnectedRelay => 'Mit Relay verbunden';

  @override
  String get federationNotRunning => 'Endpunkt läuft nicht';

  @override
  String get federationEndpointId => 'Endpunkt-ID';

  @override
  String get federationEndpointCopied => 'Endpunkt-ID kopiert';

  @override
  String get federationPairingRequestsSection => 'Kopplungsanfragen';

  @override
  String get federationRequestsInboxTitle =>
      'Anfragen aus dem Discovery-Netzwerk annehmen';

  @override
  String get federationRequestsInboxSubtitle =>
      'Standardmäßig aus. Ist die Option aus, werden neue Anfragen schon auf Transportebene abgewiesen; Antworten auf deine eigenen Anfragen kommen trotzdem an.';

  @override
  String get federationInboxFailed =>
      'Der Anfragen-Eingang konnte nicht geändert werden.';

  @override
  String get federationDefaultsSection => 'Vorgaben für neue Tickets';

  @override
  String get federationDefaultsNote =>
      'Aus der Server-Konfiguration – jedes Ticket kann sie ändern';

  @override
  String get federationOffWarning =>
      'Wird die Föderation ausgeschaltet, brechen alle Peer-Verbindungen ab und deine Tickets sind verborgen, bis sie wieder an ist. Peers behalten ihre Tickets.';

  @override
  String federationRequestWantsToPair(String name) {
    return '$name möchte koppeln';
  }

  @override
  String federationRequestToName(String name) {
    return 'Anfrage an $name';
  }

  @override
  String federationRequestOffers(String libraries) {
    return 'Bietet $libraries';
  }

  @override
  String get federationRequestOffersNothing => 'Bietet nichts';

  @override
  String federationRequestYouOffered(String libraries) {
    return 'Du hast $libraries angeboten';
  }

  @override
  String get federationRequestYouOfferedNothing => 'Du hast nichts angeboten';

  @override
  String get federationReqSending => 'wird gesendet…';

  @override
  String get federationReqWaiting => 'wartet auf Antwort';

  @override
  String get federationReqSharingBack => 'teilt zurück…';

  @override
  String get federationReqNeedsAnswer => 'braucht deine Antwort';

  @override
  String get federationReqSendingTicket => 'dein Ticket wird gesendet…';

  @override
  String get federationReqWaitingShare => 'wartet auf ihre Freigabe';

  @override
  String get federationReqDeclined => 'abgelehnt';

  @override
  String get federationReqYouDeclined => 'von dir abgelehnt';

  @override
  String get federationReqInboxClosed => 'ihr Eingang ist geschlossen';

  @override
  String get federationReqFederated => 'föderiert';

  @override
  String get federationReqWithdrawn => 'zurückgezogen';

  @override
  String get federationReqExpired => 'abgelaufen';

  @override
  String get federationAccept => 'Annehmen…';

  @override
  String get federationAcceptAndShare => 'Annehmen & teilen';

  @override
  String get federationDecline => 'Ablehnen';

  @override
  String get federationCancelRequest => 'Anfrage zurückziehen';

  @override
  String get federationDismiss => 'Ausblenden';

  @override
  String get federationRequestTitle => 'Kopplungsanfrage';

  @override
  String federationRequestReceived(String ago) {
    return 'Empfangen $ago über das Discovery-Netzwerk';
  }

  @override
  String federationRequestSent(String ago) {
    return 'Gesendet $ago über das Discovery-Netzwerk';
  }

  @override
  String get federationShareBack => 'Zurückteilen';

  @override
  String get federationShareBackNote =>
      'Bis du annimmst, ändert sich nichts. Sie erhalten Lesezugriff auf die Bibliotheken, die du anhakst – mindestens eine.';

  @override
  String get federationTheirLimits => 'Limits für den anderen Server';

  @override
  String get federationChange => 'Ändern';

  @override
  String get federationRequestIgnored =>
      'Anfragen von diesem Server werden 7 Tage lang ignoriert';

  @override
  String get federationRequestAccepted => 'Anfrage angenommen';

  @override
  String get federationRequestDeclined => 'Anfrage abgelehnt';

  @override
  String get federationRequestCancelled => 'Anfrage zurückgezogen';

  @override
  String get federationRequestActionFailed =>
      'Die Anfrage konnte nicht aktualisiert werden.';

  @override
  String get federationTicketNameLabel => 'Für wen ist das?';

  @override
  String get federationTicketNameHint =>
      'Nur du siehst diesen Namen – er beschriftet das Ticket in deiner Liste.';

  @override
  String get federationLibrariesTheyCanRead =>
      'Bibliotheken, die sie lesen dürfen';

  @override
  String get federationLimitsSection => 'Limits';

  @override
  String get federationExactNumbers => 'Genaue Werte';

  @override
  String get federationPresets => 'Voreinstellungen';

  @override
  String get federationLimitStreamRate => 'Streamrate';

  @override
  String get federationLimitPerDay => 'Pro Tag';

  @override
  String get federationLimitStreams => 'Gleichzeitige Streams';

  @override
  String get federationLimitExpires => 'Läuft ab';

  @override
  String get federationUnlimited => 'Unbegrenzt';

  @override
  String get federationNever => 'Nie';

  @override
  String federationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get federationOneYear => '1 Jahr';

  @override
  String federationKbps(int n) {
    return '$n kbit/s';
  }

  @override
  String federationMbps(int n) {
    return '$n Mbit/s';
  }

  @override
  String federationMbPerDay(int n) {
    return '$n MB pro Tag';
  }

  @override
  String federationGbPerDay(int n) {
    return '$n GB pro Tag';
  }

  @override
  String federationStreamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Streams',
      one: '1 Stream',
    );
    return '$_temp0';
  }

  @override
  String get federationNeverExpires => 'läuft nie ab';

  @override
  String federationExpiresIn(String when) {
    return 'läuft ab $when';
  }

  @override
  String get federationExpired => 'abgelaufen';

  @override
  String federationInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Tagen',
      one: 'in 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String federationInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Stunden',
      one: 'in 1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String get federationStreamRateField => 'Streamrate (kbit/s, 0 = unbegrenzt)';

  @override
  String get federationPerDayField => 'Tageskontingent (MB, 0 = unbegrenzt)';

  @override
  String get federationStreamsField => 'Max. Streams (0 = unbegrenzt)';

  @override
  String get federationExpiresField => 'Läuft ab in Tagen (0 = nie)';

  @override
  String get federationCreateTicket => 'Ticket erstellen';

  @override
  String get federationMintFailed => 'Das Ticket konnte nicht erstellt werden.';

  @override
  String get federationNoLibraries =>
      'Dieser Server hat keine Bibliotheken zum Teilen.';

  @override
  String get federationTicketTitle => 'Dein Ticket';

  @override
  String federationTicketFor(String name) {
    return 'Ticket für $name';
  }

  @override
  String federationTicketReads(String libraries) {
    return 'Liest $libraries';
  }

  @override
  String get federationTicketQrHint => 'Im selben Raum? Lass es scannen.';

  @override
  String get federationTicketWarning =>
      'Wer dieses Ticket besitzt, kann diese Bibliotheken lesen, bis es eingelöst oder widerrufen wird. Verschicke es über einen privaten Kanal – der erste Server, der es benutzt, löst es ein.';

  @override
  String get federationCopyTicket => 'Ticket kopieren';

  @override
  String get federationTicketCopied => 'Ticket kopiert';

  @override
  String get federationSendByText => 'Als Nachricht senden…';

  @override
  String get federationTicketRevokeNote =>
      'Widerrufe es jederzeit unter Föderation. Nach einer Neuinstallation lässt „Einlösung zurücksetzen“ das Ticket erneut einlösen.';

  @override
  String get federationTicketNotRunning =>
      'Der Föderations-Endpunkt läuft nicht, daher gibt es noch kein Ticket zum Senden. Schalte die Föderation ein und komm zurück.';

  @override
  String federationShareMessage(String libraries, String ticket) {
    return 'Ich teile meine mStream-Musikbibliothek mit dir – $libraries, nur lesend. Öffne in der mStream-App Föderation → Peer hinzufügen und füge dieses Ticket ein:\n\n$ticket\n\nEs funktioniert einmal – ich kann es jederzeit widerrufen.';
  }

  @override
  String get federationShareSubject => 'mStream-Föderationsticket';

  @override
  String get federationKeyClaimed => 'eingelöst';

  @override
  String get federationKeyNotClaimed => 'noch nicht eingelöst';

  @override
  String federationKeyTodayUsage(String amount) {
    return '$amount heute';
  }

  @override
  String federationKeyLastUsed(String ago) {
    return 'Zuletzt benutzt $ago';
  }

  @override
  String get federationKeyNeverUsed => 'Nie benutzt';

  @override
  String federationKeyClaimedAgo(String ago) {
    return 'Eingelöst $ago';
  }

  @override
  String get federationResetBinding => 'Einlösung zurücksetzen';

  @override
  String get federationResetBindingNote =>
      'Freund hat neu installiert? Lass das Ticket erneut einlösen.';

  @override
  String get federationBindingReset =>
      'Das Ticket kann erneut eingelöst werden';

  @override
  String get federationRevoke => 'Widerrufen';

  @override
  String federationRevokeConfirm(String name) {
    return 'Dieses Ticket widerrufen? $name verliert sofort den Zugriff.';
  }

  @override
  String get federationRevoked => 'Ticket widerrufen';

  @override
  String get federationSaveLimits => 'Limits speichern';

  @override
  String get federationLimitsSaved => 'Limits gespeichert';

  @override
  String get federationLimitsFailed =>
      'Die Limits konnten nicht gespeichert werden.';

  @override
  String get federationSend => 'Senden';

  @override
  String get federationKeyTitle => 'Geteilte Bibliothek';

  @override
  String federationActionFailed(String error) {
    return 'Das hat nicht geklappt: $error';
  }

  @override
  String get federationTheirTicket => 'Ticket des anderen Servers';

  @override
  String get federationScanQr => 'QR-Code scannen';

  @override
  String get federationScannerTitle => 'Föderationsticket scannen';

  @override
  String get federationPaste => 'Einfügen';

  @override
  String get federationTicketPasted => 'Aus der Zwischenablage eingefügt.';

  @override
  String get federationNotATicket =>
      'Das sieht nicht nach einem Föderationsticket aus.';

  @override
  String get federationTicketTooNew =>
      'Dieses Ticket stammt von einem neueren mStream, als diese App versteht.';

  @override
  String get federationTicketExpiredNote => 'Dieses Ticket ist abgelaufen.';

  @override
  String get federationDisplayName => 'Anzeigename';

  @override
  String get federationDisplayNameHint =>
      'Optional – so erscheint es in deiner Serverauswahl.';

  @override
  String federationSharesLibraries(String libraries) {
    return 'Teilt $libraries';
  }

  @override
  String get federationSharesUnknown =>
      'Bibliotheken stehen nicht auf dem Ticket';

  @override
  String federationValidUntil(String date) {
    return 'gültig bis $date';
  }

  @override
  String federationAddPeerShowsUnder(String server) {
    return 'Erscheint unter $server';
  }

  @override
  String federationAddPeerReadOnly(String branch, String name) {
    return 'Nur lesen · $branch $name in der Auswahl';
  }

  @override
  String get federationAddPeerDials => 'Dein Server wählt es über iroh an';

  @override
  String get federationAddPeerEncrypted =>
      'Ende-zu-Ende-verschlüsselt · keine Portweiterleitung';

  @override
  String get federationAddPeerNoTicket =>
      'Noch kein Ticket? Bitte darum, dir eins zu schicken.';

  @override
  String federationPeerAdded(String name) {
    return '$name hinzugefügt';
  }

  @override
  String get federationAddPeerFailed =>
      'Der Peer konnte nicht hinzugefügt werden.';

  @override
  String get federationPeerAlreadyAdded =>
      'Dieses Ticket ist bereits als Peer hinzugefügt.';

  @override
  String get federationLibrariesYouCanRead =>
      'Bibliotheken, die du lesen kannst';

  @override
  String get federationDiscoverySection => 'Entdecken';

  @override
  String get federationAskPeerSimilar =>
      'Diesen Peer nach ähnlicher Musik fragen';

  @override
  String get federationAskPeerSimilarNote =>
      'Sendet, was du gerade hörst – nur an diesen Peer.';

  @override
  String get federationAutoDjSection => 'Auto DJ';

  @override
  String get federationAutoDjParticipates =>
      'Nimmt am Multi-Server-Auto-DJ teil';

  @override
  String get federationAutoDjParticipatesNote =>
      'Antwortet mit der eigenen Bibliothek, wenn der DJ läuft';

  @override
  String get federationAutoDjNotCandidate => 'Kein Auto-DJ-Kandidat';

  @override
  String get federationAutoDjNotCandidateNote =>
      'Braucht einen Server, der Anfragen nach klanglich ähnlichen Titeln beantworten kann';

  @override
  String get federationTest => 'Testen';

  @override
  String get federationTesting => 'Wird getestet…';

  @override
  String get federationTestOk => 'Erreichbar';

  @override
  String federationTestFailed(String error) {
    return 'Nicht erreichbar: $error';
  }

  @override
  String federationCheckedAgo(String ago) {
    return 'Geprüft $ago';
  }

  @override
  String get federationNeverTested => 'Nie getestet';

  @override
  String federationLastSeen(String ago) {
    return 'Zuletzt gesehen $ago';
  }

  @override
  String get federationBrowseLibrary => 'Diese Bibliothek durchsuchen';

  @override
  String get federationRemovePeer => 'Peer entfernen';

  @override
  String federationRemovePeerConfirm(String name) {
    return '$name entfernen? Daraus eingereihte Titel hören auf zu spielen.';
  }

  @override
  String federationPeerRemoved(String name) {
    return '$name entfernt';
  }

  @override
  String get federationShowInPicker => 'In der Serverauswahl anzeigen';

  @override
  String get federationShowInPickerNote =>
      'Ausgeblendete Peers spielen weiter, was du von ihnen eingereiht hast.';

  @override
  String get federationPeerReadOnlyNote =>
      'Nur lesen – Playlists und Bewertungen bleiben auf deinem eigenen Server.';

  @override
  String get federationPeerLibrariesUnknown =>
      'Noch nicht aufgelistet – einmal öffnen, um die Bibliotheken zu laden.';

  @override
  String get federationTransportDirect => 'Direkter Tunnel von diesem Telefon';

  @override
  String get federationTransportRelay => 'Relay in Bereitschaft';

  @override
  String federationTransportViaParent(String parent) {
    return 'Über $parent';
  }

  @override
  String federationTransportViaParentTunnel(String parent) {
    return 'Über $parent durch dessen Tunnel';
  }

  @override
  String get federationDiscoveryFailed =>
      'Die Entdecken-Einstellung konnte nicht geändert werden.';

  @override
  String get agoJustNow => 'gerade eben';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Min.',
      one: 'vor 1 Min.',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Std.',
      one: 'vor 1 Std.',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get browserP2pNetwork => 'P2P-Netzwerk';

  @override
  String get browserP2pOn => 'An';

  @override
  String get browserP2pOff => 'Aus';

  @override
  String get p2pTitle => 'P2P-Netzwerk';

  @override
  String get p2pStatusConnected => 'Verbunden';

  @override
  String p2pNeighborsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachbarn',
      one: '1 Nachbar',
    );
    return '$_temp0';
  }

  @override
  String p2pAnnouncingAs(String name) {
    return 'kündigt sich als $name an';
  }

  @override
  String get p2pStatusSearching => 'Beigetreten · wartet auf Nachbarn';

  @override
  String p2pStatusReconnecting(int n) {
    return 'Verbindet neu · Versuch $n';
  }

  @override
  String get p2pStatusNotJoined => 'Noch nicht beigetreten';

  @override
  String get p2pStatusOff => 'Aus';

  @override
  String get p2pStatusUnavailable => 'Auf dieser Plattform nicht verfügbar';

  @override
  String get p2pStatNeighbors => 'Mesh-Nachbarn';

  @override
  String get p2pStatNeighborsSub => 'aktive Gossip-Verbindungen';

  @override
  String get p2pStatKnown => 'bekannte Server';

  @override
  String p2pStatKnownSub(int hidden, int blocked) {
    return '$hidden ausgeblendet · $blocked blockiert';
  }

  @override
  String get p2pStatHeld => 'gespeicherte Snapshots';

  @override
  String p2pStatHeldOf(int held, int max) {
    return '$held von $max';
  }

  @override
  String p2pStatStorage(String used, String cap) {
    return '$used von $cap';
  }

  @override
  String get p2pStatTracks => 'Peer-Titel';

  @override
  String p2pStatTracksSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'durchsuchbar, $count Bibliotheken',
      one: 'durchsuchbar, 1 Bibliothek',
    );
    return '$_temp0';
  }

  @override
  String get p2pActivity => 'Aktivität';

  @override
  String get p2pActivitySubtitle => 'Neueste zuerst · nur im Speicher';

  @override
  String get p2pActivityEmpty =>
      'Noch nichts – Mesh-Beitritte, Snapshot-Downloads, Rotation und Wiederherstellung erscheinen hier, sobald sie passieren.';

  @override
  String get p2pActivityNote =>
      'Die vollständige Historie steht in den Server-Logs.';

  @override
  String get p2pFromNetwork => 'Aus dem Netzwerk';

  @override
  String get p2pFindSimilar => 'Ähnliche Musik im Netzwerk finden';

  @override
  String p2pFindSimilarSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Öffnet „Mehr davon“ für den laufenden Titel · Vorschläge aus $count heruntergeladenen Bibliotheken',
      one:
          'Öffnet „Mehr davon“ für den laufenden Titel · Vorschläge aus 1 heruntergeladenen Bibliothek',
    );
    return '$_temp0';
  }

  @override
  String get p2pFindSimilarNothingPlaying =>
      'Spiel zuerst etwas ab – „Mehr davon“ folgt dem laufenden Titel';

  @override
  String get p2pNewArtistsOnlySub =>
      'Vorschläge zu Künstlern ausblenden, die schon in dieser Bibliothek sind';

  @override
  String get p2pServersYouFollow => 'Server, denen du folgst';

  @override
  String get p2pServersOnNetwork => 'Server im Netzwerk';

  @override
  String get p2pNoServersYet =>
      'Noch keine Server entdeckt – füge einen mit dem Ticket eines Freundes als Freund hinzu oder gib dem Gossip eine Minute.';

  @override
  String p2pHiddenIncompatible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Server ausgeblendet – inkompatibles Modell',
      one: '1 Server ausgeblendet – inkompatibles Modell',
    );
    return '$_temp0';
  }

  @override
  String get p2pShow => 'Anzeigen';

  @override
  String get p2pHide => 'Ausblenden';

  @override
  String get p2pBefriend => 'Server als Freund hinzufügen';

  @override
  String get p2pOnline => 'online';

  @override
  String p2pOfflineFor(String ago) {
    return 'offline $ago';
  }

  @override
  String p2pTracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String p2pSeedersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Seeder',
      one: '1 Seeder',
    );
    return '$_temp0';
  }

  @override
  String get p2pChipDownloaded => 'heruntergeladen';

  @override
  String get p2pChipUpdate => 'Update verfügbar';

  @override
  String get p2pChipNotDownloaded => 'nicht heruntergeladen';

  @override
  String get p2pChipPinned => 'angepinnt';

  @override
  String get p2pChipIncompatible => 'inkompatibles Modell';

  @override
  String get p2pChipFederated => 'föderiert';

  @override
  String get p2pChipTheyAsked => 'Anfrage an dich';

  @override
  String get p2pChipRequestSent => 'Anfrage gesendet';

  @override
  String get p2pSearchingTitle => 'Suche nach Peers';

  @override
  String get p2pSearchingBody =>
      'Das Mesh baut sich in etwa einer Minute auf. Dieser Bildschirm aktualisiert sich selbst.';

  @override
  String get p2pReconnectingTitle => 'Verbindet neu';

  @override
  String p2pReconnectingBody(int n) {
    return 'Der Sidecar ist abgestürzt und wird neu gestartet (Versuch $n) – nichts zu tun.';
  }

  @override
  String get p2pJoinTitle => 'Empfehlungen aus den Bibliotheken anderer';

  @override
  String get p2pWhatShared => 'Was geteilt wird';

  @override
  String get p2pShared1 => 'Ein Snapshot nur mit Metadaten';

  @override
  String get p2pShared1Sub =>
      'Künstler, Titel, Dauer, Klang-Fingerabdrücke – nie Audiodateien';

  @override
  String get p2pShared2 => 'Name und Beschreibung deines Servers';

  @override
  String get p2pShared2Sub =>
      'Für alle im Netzwerk sichtbar, standardmäßig im öffentlichen Community-Netzwerk';

  @override
  String get p2pHowYouAppear => 'So erscheinst du';

  @override
  String get p2pServerName => 'Servername';

  @override
  String get p2pServerNameHint =>
      '„mStream“ neben 18.000 anderen mStreams ist das Erste, was man ändern will.';

  @override
  String get p2pDescription => 'Beschreibung';

  @override
  String get p2pDescriptionHint => '180 Zeichen, optional.';

  @override
  String get p2pAlsoAcceptRequests => 'Auch Föderationsanfragen annehmen';

  @override
  String get p2pAlsoAcceptRequestsSub =>
      'Einladungen, Bibliotheken zu teilen – geteilt wird nur, was du einzeln bestätigst. Schaltet die Föderation ein.';

  @override
  String get p2pJoin => 'Dem Netzwerk beitreten';

  @override
  String get p2pJoining => 'Beitritt läuft…';

  @override
  String get p2pJoined =>
      'Dem Discovery-Netzwerk beigetreten – gib dem Mesh eine Minute.';

  @override
  String p2pJoinFailed(String error) {
    return 'Beitritt fehlgeschlagen: $error';
  }

  @override
  String p2pInboxFailed(String error) {
    return 'Discovery ist an, aber der Anfragen-Eingang startete nicht: $error';
  }

  @override
  String get p2pUnavailableNote =>
      'Der p2p-sidecar wurde für diese Plattform nicht gefunden und es gibt keinen Download – das Netzwerk ist nicht verfügbar.';

  @override
  String get p2pWillDownloadNote =>
      'Der Sidecar ist noch nicht installiert; der Beitritt lädt ihn zuerst herunter.';

  @override
  String get p2pAdminOnlyNote => 'Nur der Server-Admin kann beitreten.';

  @override
  String p2pMemberOffNote(String server) {
    return 'Das Discovery-Netzwerk ist auf $server aus. Der Admin kann beitreten.';
  }

  @override
  String p2pMemberNote(String server) {
    return 'Beitreten, Einladen und Snapshots sind Admin-Sache. Melde dich auf $server als Admin an, um das Netzwerk hier zu verwalten.';
  }

  @override
  String get p2pSnapshotSection => 'Snapshot';

  @override
  String p2pDownloadedSize(String size) {
    return 'Heruntergeladen · $size';
  }

  @override
  String p2pSnapshotSeq(int seq) {
    return 'Snapshot $seq';
  }

  @override
  String p2pNewerAnnounced(int seq) {
    return 'ein neuerer ($seq) ist angekündigt';
  }

  @override
  String get p2pNotDownloaded => 'Nicht heruntergeladen';

  @override
  String get p2pNotDownloadedSub =>
      'Lade ihn herunter, um ihn über Entdecken zu durchsuchen';

  @override
  String get p2pDownload => 'Herunterladen';

  @override
  String get p2pUpdate => 'Aktualisieren';

  @override
  String get p2pDownloading => 'Wird heruntergeladen…';

  @override
  String get p2pDownloaded => 'Snapshot heruntergeladen';

  @override
  String p2pDownloadFailed(String error) {
    return 'Snapshot konnte nicht heruntergeladen werden: $error';
  }

  @override
  String get p2pPin => 'Diesen Snapshot anpinnen';

  @override
  String p2pPinSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Die Rotation gibt nach $count Tagen die am wenigsten genutzten Snapshots frei; ein angepinnter bleibt.',
      one:
          'Die Rotation gibt nach 1 Tag die am wenigsten genutzten Snapshots frei; ein angepinnter bleibt.',
    );
    return '$_temp0';
  }

  @override
  String get p2pPinSubNoRotation =>
      'Die Rotation ist aus; ein angepinnter Snapshot übersteht auch Platzmangel.';

  @override
  String get p2pRemoveSnapshot => 'Snapshot entfernen';

  @override
  String get p2pSnapshotRemoved => 'Snapshot entfernt';

  @override
  String get p2pHeldSince => 'gespeichert seit';

  @override
  String get p2pTracksLabel => 'Titel';

  @override
  String get p2pSeedersLabel => 'Seeder';

  @override
  String get p2pSeedersSub => 'liefern den Snapshot';

  @override
  String get p2pFederatedWithYou => 'Mit dir föderiert';

  @override
  String get p2pFederatedWithYouSub =>
      'Öffne Föderation, um zu sehen, was ihr voneinander lest';

  @override
  String get p2pTheyAskedYou => 'Bittet um Föderation';

  @override
  String get p2pTheyAskedYouSub => 'Prüfe die Anfrage unter Föderation';

  @override
  String get p2pRequestSentTitle => 'Anfrage gesendet';

  @override
  String get p2pRequestSentSub =>
      'Wartet auf Antwort · verfolge sie unter Föderation';

  @override
  String get p2pAskToFederate => 'Um geteilte Bibliotheken bitten';

  @override
  String get p2pAskToFederateSub =>
      'Sendet eine Anfrage über das Netzwerk – jetzt ändert sich noch nichts';

  @override
  String get p2pOpen => 'Öffnen';

  @override
  String get p2pReview => 'Prüfen';

  @override
  String get p2pForget => 'Diesen Server vergessen';

  @override
  String get p2pForgetSub =>
      'Offline und nichts heruntergeladen; er kehrt zurück, sobald er wieder auftaucht';

  @override
  String p2pForgotten(String name) {
    return '$name vergessen';
  }

  @override
  String get p2pBlockServer => 'Server blockieren';

  @override
  String p2pBlockConfirm(String name) {
    return '$name blockieren? Seine Ankündigungen werden ignoriert und sein Snapshot entfernt.';
  }

  @override
  String p2pBlocked(String name) {
    return '$name blockiert';
  }

  @override
  String get p2pUnblock => 'Blockierung aufheben';

  @override
  String get p2pUnblocked => 'Blockierung aufgehoben';

  @override
  String get p2pIncompatibleNote =>
      'Inkompatibles Embedding-Modell – seine Bibliothek kann die Ähnlichkeitssuche dieses Servers nicht speisen.';

  @override
  String get p2pCompatible => 'kompatibles Modell';

  @override
  String get p2pModelUnknown => 'Modell unbekannt';

  @override
  String get p2pNoDescription => 'Keine Beschreibung.';

  @override
  String get p2pUnnamedServer => 'Unbenannter Server';

  @override
  String get p2pFederateTitle => 'Um Föderation bitten';

  @override
  String get p2pFederateNote =>
      'Sendet eine Anfrage über das Discovery-Netzwerk. Jetzt wird kein Zugriff ausgetauscht – sie sehen deinen Namen, deine Nachricht und dein Angebot; Bibliotheken werden nur geteilt, wenn sie annehmen.';

  @override
  String get p2pMessage => 'Nachricht';

  @override
  String p2pMessageHint(int n) {
    return 'Optional · $n / 500';
  }

  @override
  String get p2pShareBackLibraries =>
      'Bibliotheken, die du zurückteilst, wenn sie annehmen';

  @override
  String get p2pShareBackNote =>
      'Alles abwählen für eine einseitige Anfrage – du würdest nur ihre lesen.';

  @override
  String get p2pSendRequest => 'Anfrage senden';

  @override
  String get p2pRequestSent =>
      'Anfrage gesendet – verfolge sie unter Föderation';

  @override
  String p2pRequestFailed(String error) {
    return 'Die Anfrage konnte nicht gesendet werden: $error';
  }

  @override
  String get p2pTheirTicket => 'Ticket des anderen Servers';

  @override
  String get p2pTheirTicketHint =>
      'Freunde finden ihres unter „Freund einladen“ auf ihrem P2P-Netzwerk-Bildschirm.';

  @override
  String get p2pTicketPasted => 'Aus der Zwischenablage eingefügt.';

  @override
  String get p2pRememberFriend => 'Diesen Freund merken';

  @override
  String get p2pRememberFriendSub =>
      'In der Server-Konfiguration gespeichert, damit die Freundschaft Neustarts übersteht.';

  @override
  String get p2pJoinFriend => 'Beitreten';

  @override
  String get p2pJoinedFriend =>
      'Beigetreten – das Mesh baut sich in etwa einer Minute auf';

  @override
  String p2pJoinFriendFailed(String error) {
    return 'Beitritt fehlgeschlagen: $error';
  }

  @override
  String get p2pNotATicket => 'Das sieht nicht nach einem Endpunkt-Ticket aus.';

  @override
  String get p2pScanQr => 'QR-Code scannen';

  @override
  String get p2pScannerTitle => 'Netzwerk-Ticket scannen';

  @override
  String get p2pInviteFriend => 'Freund einladen';

  @override
  String p2pYourTicketNote(String name) {
    return 'Dein Ticket – ein Freund fügt es auf seinem Telefon hier ein, um $name hinzuzufügen. Es ist eine Adresse, kein Zugangsschlüssel.';
  }

  @override
  String get p2pTicketCopied => 'Ticket kopiert';

  @override
  String p2pShareMessage(String ticket) {
    return 'Füge meinen mStream-Server im Discovery-Netzwerk als Freund hinzu – öffne in der mStream-App P2P-Netzwerk → Server als Freund hinzufügen und füge dieses Ticket ein:\n\n$ticket';
  }

  @override
  String get p2pShareSubject => 'mStream-Ticket für das Discovery-Netzwerk';

  @override
  String get p2pTicketNotReady =>
      'Der Sidecar läuft noch nicht, daher gibt es noch kein Ticket zum Teilen.';

  @override
  String get p2pSettingsTitle => 'Netzwerkeinstellungen';

  @override
  String get p2pSwitchTitle => 'Discovery-Netzwerk';

  @override
  String get p2pSwitchSub =>
      'Kündigt einen reinen Metadaten-Snapshot im Netzwerk an. Ausschalten heißt verlassen – gesammelte Daten bleiben lokal.';

  @override
  String get p2pLeaveConfirm =>
      'Das Discovery-Netzwerk verlassen? Dein Server hört auf, Snapshots anzukündigen und herunterzuladen. Die lokale Discovery funktioniert weiter.';

  @override
  String get p2pLeave => 'Verlassen';

  @override
  String get p2pLeft => 'Discovery-Netzwerk verlassen';

  @override
  String p2pLeaveFailed(String error) {
    return 'Verlassen fehlgeschlagen: $error';
  }

  @override
  String get p2pEditIdentity => 'Name und Beschreibung';

  @override
  String get p2pIdentitySaved => 'Gespeichert – im Netzwerk angekündigt';

  @override
  String p2pSaveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get p2pSnapshotsSection => 'Snapshots';

  @override
  String get p2pAutoDownload => 'Automatisch herunterladen bis zu';

  @override
  String p2pServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Server',
      one: '1 Server',
    );
    return '$_temp0';
  }

  @override
  String get p2pStorageCap => 'Speicherlimit';

  @override
  String get p2pRotate => 'Downloads rotieren';

  @override
  String get p2pForgetOffline => 'Offline-Server vergessen';

  @override
  String get p2pMeshSection => 'Mesh';

  @override
  String get p2pCommunitySeeds => 'Community-Seeds';

  @override
  String get p2pCommunitySeedsOn =>
      'Einstieg über die öffentlichen Seed-Server';

  @override
  String get p2pCommunitySeedsOff =>
      'Aus – nur hinzugefügte Server; in der Server-Konfiguration festgelegt';

  @override
  String p2pBlockedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blockierte Server',
      one: '1 blockierter Server',
      zero: 'Keine blockierten Server',
    );
    return '$_temp0';
  }

  @override
  String get p2pBlockedSub =>
      'Ankündigungen ignoriert, Snapshots nie heruntergeladen';

  @override
  String get p2pBlockedTitle => 'Blockierte Server';

  @override
  String get p2pSaved => 'Gespeichert';

  @override
  String get p2pOff => 'Aus';

  @override
  String get p2pSave => 'Speichern';

  @override
  String get p2pSearchServers => 'Server suchen – Name oder Beschreibung';

  @override
  String federationInboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Föderationsanfragen warten',
      one: '1 Föderationsanfrage wartet',
    );
    return '$_temp0';
  }

  @override
  String get federationInboxBannerSub =>
      'Antippen, um anzunehmen oder abzulehnen';

  @override
  String federationInboxNotificationTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Föderationsanfragen warten',
      one: 'Eine Föderationsanfrage wartet',
    );
    return '$_temp0';
  }

  @override
  String federationInboxNotificationBody(String server) {
    return 'Auf $server. Öffnen, um anzunehmen oder abzulehnen.';
  }

  @override
  String get federationInboxChannelName => 'Föderationsanfragen';

  @override
  String get federationInboxChannelDescription =>
      'Auf einem deiner Server ist eine Anfrage zum Teilen von Bibliotheken eingegangen';

  @override
  String get federationNotifyTitle => 'Bei Anfragen benachrichtigen';

  @override
  String get federationNotifySubtitle =>
      'Eine Benachrichtigung auf dem Telefon, wenn eine Anfrage eingeht, während die App offen ist oder Musik spielt';

  @override
  String get autoRecentlyPlayed => 'Zuletzt gehört';

  @override
  String get settingsHistoryEnabled => 'Wiedergaben aufzeichnen';

  @override
  String get settingsHistorySend => 'Wiedergaben an Server senden';

  @override
  String get settingsHistoryClear => 'Verlauf leeren';

  @override
  String settingsHistoryClearConfirm(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Das löscht den Hörverlauf dieses Telefons ($size), einschließlich $count noch nicht synchronisierter Wiedergaben. Server behalten ihren eigenen.',
      one:
          'Das löscht den Hörverlauf dieses Telefons ($size), einschließlich $count noch nicht synchronisierter Wiedergabe. Server behalten ihren eigenen.',
      zero:
          'Das löscht den Hörverlauf dieses Telefons ($size). Server behalten ihren eigenen.',
    );
    return '$_temp0';
  }

  @override
  String get settingsHistoryCleared => 'Hörverlauf gelöscht';

  @override
  String songInfoServerPlays(num count, Object server) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wiedergaben auf $server',
      one: '1 Wiedergabe auf $server',
    );
    return '$_temp0';
  }

  @override
  String songInfoDevicePlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wiedergaben auf diesem Telefon',
      one: '1 Wiedergabe auf diesem Telefon',
    );
    return '$_temp0';
  }

  @override
  String songInfoLastPlayed(Object ago) {
    return 'zuletzt $ago';
  }

  @override
  String get listeningTitle => 'Hörstatistik';

  @override
  String get listeningScopeThisPhone => 'Dieses Telefon';

  @override
  String get listeningScopeSheetTitle => 'Was angezeigt wird';

  @override
  String get listeningScopeSheetDevice =>
      'Was dieses Telefon abgespielt hat: jeder Server, lokale Dateien, offline. Bleibt auf diesem Gerät.';

  @override
  String get listeningScopeSheetServer =>
      'Deine Wiedergaben auf diesem Server aus jeder App – dem Web-Player, anderen Telefonen und diesem Telefon, sobald es synchronisiert ist.';

  @override
  String get listeningScopeSheetLegacy =>
      'Noch keine Hörstatistik – benötigt mStream 6.27 oder neuer.';

  @override
  String listeningScopeSheetPeer(Object server) {
    return 'Gezählt auf $server: die Titel eines Peers zählen dort, wo dein Konto liegt.';
  }

  @override
  String get listeningProvenanceDevice =>
      'Was dieses Telefon abgespielt hat, auf jedem Server und bei lokalen Dateien. Bleibt auf diesem Gerät.';

  @override
  String listeningProvenanceServer(Object server) {
    return 'Deine Wiedergaben auf $server aus jeder App, einschließlich der Titel seiner Peers.';
  }

  @override
  String listeningProvenancePeer(Object peer, Object server) {
    return 'Deine Wiedergaben der Titel von $peer, gezählt auf $server.';
  }

  @override
  String listeningProvenanceFallback(Object server) {
    return '$server hat nicht geantwortet – angezeigt werden die Wiedergaben dieses Telefons darauf.';
  }

  @override
  String listeningProvenanceLegacy(Object server) {
    return '$server hat noch keine Hörstatistik (mStream 6.27+) – angezeigt werden die Wiedergaben dieses Telefons darauf.';
  }

  @override
  String listeningUnsynced(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wiedergaben noch nicht synchronisiert',
      one: '1 Wiedergabe noch nicht synchronisiert',
    );
    return '$_temp0';
  }

  @override
  String get listeningPeriodWeek => 'Diese Woche';

  @override
  String get listeningPeriodMonth => 'Dieser Monat';

  @override
  String get listeningPeriodQuarter => 'Dieses Quartal';

  @override
  String get listeningPeriodYear => 'Dieses Jahr';

  @override
  String get listeningPeriodAll => 'Gesamt';

  @override
  String get listeningTilePlays => 'Wiedergaben';

  @override
  String get listeningTileTime => 'Hörzeit';

  @override
  String get listeningTileTracks => 'Titel';

  @override
  String get listeningTileSkips => 'Übersprungen';

  @override
  String get listeningTileStreak => 'Serie';

  @override
  String get listeningTileSessions => 'Sitzungen';

  @override
  String listeningDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get listeningTileSubCounted => 'gezählte Wiedergaben';

  @override
  String get listeningTileSubTracks => 'verschiedene Titel';

  @override
  String listeningTileSubSkips(Object pct) {
    return '$pct % der Starts';
  }

  @override
  String listeningTileSubStreak(Object count) {
    return 'längste $count';
  }

  @override
  String listeningTileSubSessions(Object duration) {
    return 'etwa $duration pro Sitzung';
  }

  @override
  String get listeningWhenYouListen => 'Wann du hörst';

  @override
  String listeningMostAround(Object hour) {
    return 'Am meisten gegen $hour';
  }

  @override
  String get listeningTop => 'Top';

  @override
  String get listeningTopTracks => 'Titel';

  @override
  String get listeningTopArtists => 'Künstler';

  @override
  String get listeningTopAlbums => 'Alben';

  @override
  String get listeningByPlays => 'Wiedergaben';

  @override
  String get listeningByTime => 'Zeit';

  @override
  String listeningPlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wiedergaben',
      one: '1 Wiedergabe',
    );
    return '$_temp0';
  }

  @override
  String listeningTracksCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String get listeningRecent => 'Zuletzt gehört';

  @override
  String get listeningLoadMore => 'Mehr laden';

  @override
  String get listeningEmptyTitle => 'Noch keine Wiedergaben';

  @override
  String get listeningEmptyDevice =>
      'Wiedergaben landen hier, während du hörst. Dieses Telefon führt seine eigene Aufzeichnung; dein Server führt deine über alle Apps hinweg.';

  @override
  String listeningEmptyServer(Object server) {
    return 'An $server wurde noch nichts gemeldet. Wiedergaben dieses Telefons kommen an, sobald sie synchronisiert sind.';
  }

  @override
  String get listeningEmptyPeriod => 'Nichts in diesem Zeitraum.';

  @override
  String get listeningOutcomeCompleted => 'Abgeschlossen';

  @override
  String get listeningOutcomeSkipped => 'Übersprungen';

  @override
  String get listeningOutcomeStopped => 'Gestoppt';

  @override
  String listeningOutcomeAt(Object outcome, Object position) {
    return '$outcome bei $position';
  }

  @override
  String get listeningNotCounted => 'nicht gezählt';

  @override
  String listeningVia(Object peer) {
    return 'über $peer';
  }

  @override
  String listeningRepeats(Object count) {
    return '×$count';
  }

  @override
  String get listeningLocalFile => 'Lokale Datei';

  @override
  String get listeningHistoryOff =>
      'Der Hörverlauf ist aus. Schalte ihn in den Einstellungen ein, um Wiedergaben auf diesem Telefon aufzuzeichnen.';

  @override
  String listeningError(Object message) {
    return 'Konnte nicht laden: $message';
  }

  @override
  String get listeningRetry => 'Erneut versuchen';

  @override
  String get listeningToday => 'Heute';

  @override
  String get listeningYesterday => 'Gestern';

  @override
  String get listeningPlaysPerDay => 'Wiedergaben pro Tag';

  @override
  String get listeningPlaysPerMonth => 'Wiedergaben pro Monat';

  @override
  String listeningMostOnDay(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Am meisten am $date: $count Wiedergaben',
      one: 'Am meisten am $date: 1 Wiedergabe',
    );
    return '$_temp0';
  }

  @override
  String listeningMostInMonth(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Am meisten im $month: $count Wiedergaben',
      one: 'Am meisten im $month: 1 Wiedergabe',
    );
    return '$_temp0';
  }

  @override
  String get settingsHomeWidget => 'Widget für den Startbildschirm';

  @override
  String get settingsHomeWidgetSubtitleIos =>
      'Halte den Startbildschirm gedrückt, füge ein Widget hinzu und wähle mStream Music.';

  @override
  String get homeWidgetPickSize => 'Größe wählen';

  @override
  String get homeWidgetPinUnsupported =>
      'Dieser Launcher kann von hier aus keine Widgets hinzufügen. Verwende seine eigene Widget-Auswahl.';

  @override
  String discoverSheetPeerOnline(String name) {
    return '$name online';
  }

  @override
  String discoverSheetPeerNotAnswering(String name) {
    return '$name antwortet nicht';
  }

  @override
  String discoverSheetSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String discoverSheetAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Alben',
      one: '1 Album',
    );
    return '$_temp0';
  }

  @override
  String get discoverSheetNotInLibrary => 'nicht in deiner Bibliothek';

  @override
  String get discoverSheetInLibrary => 'in deiner Bibliothek';

  @override
  String discoverSheetYouHaveAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'du hast $count Alben',
      one: 'du hast 1 Album',
    );
    return '$_temp0';
  }

  @override
  String get discoverSheetOpenAlbum => 'Album öffnen';

  @override
  String get discoverSheetQueueAlbum => 'Album einreihen';

  @override
  String get discoverSheetPlayAlbum => 'Album abspielen';

  @override
  String get discoverSheetOpenArtist => 'Künstler öffnen';

  @override
  String get discoverSheetListen => 'Anhören';

  @override
  String get discoverSheetKeepCopy => 'Kopie behalten';

  @override
  String get discoverSheetOpenElsewhere => 'Woanders öffnen';

  @override
  String discoverSheetBrowsePeer(String name) {
    return '$name durchsuchen';
  }

  @override
  String get discoverSheetDownloadToPhone => 'Auf dieses Telefon laden';

  @override
  String get discoverSheetDownloadToPhoneSub =>
      'Zum Offline-Hören auf diesem Gerät';

  @override
  String discoverSheetAlbumFailed(String name) {
    return 'Dieses Album konnte nicht von $name geladen werden';
  }

  @override
  String discoverAlbumCardMore(String album) {
    return 'Mehr zu $album';
  }

  @override
  String get discoverKeepThisSong => 'Dieser Titel';

  @override
  String get discoverKeepAlbum => 'Album';

  @override
  String get discoverKeepArtist => 'Künstler';

  @override
  String get discoverKeepWhat => 'Was behalten';

  @override
  String discoverKeepYouHave(int count) {
    return 'du hast $count';
  }

  @override
  String discoverKeepOnlyMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nur die $count Alben, die dir fehlen',
      one: 'Nur das 1 Album, das dir fehlt',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepFilesGoTo => 'Dateien landen in';

  @override
  String discoverKeepPathTooLong(int max) {
    return 'Der Pfad dieser Kopie wäre länger als $max Zeichen – mehr, als der Server annimmt';
  }

  @override
  String get discoverKeepFolderPerAlbum => 'ein Ordner pro Album';

  @override
  String get discoverKeepChange => 'Ändern';

  @override
  String get discoverKeepChangeHint => 'Ziel für Kopien ändern';

  @override
  String get discoverKeepAddSong => 'Titel hinzufügen';

  @override
  String get discoverKeepAddAlbum => 'Album hinzufügen';

  @override
  String get discoverKeepAddEveryAlbum => 'Alle Alben hinzufügen';

  @override
  String discoverKeepAddAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Alben hinzufügen',
      one: '1 Album hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepAddMissing => 'Fehlende Alben hinzufügen';

  @override
  String get discoverKeepUploadsOff =>
      'Dein Konto kann diesem Server keine Dateien hinzufügen';

  @override
  String get discoverKeepNoLibrary =>
      'Keine Bibliothek auf deinem Server nimmt neue Dateien an';

  @override
  String get discoverKeepStartFailed =>
      'Dein Server war nicht erreichbar. Versuch es noch einmal.';

  @override
  String get discoverKeepDestChanged =>
      'Wo Dateien landen, hat sich seit dem Öffnen geändert. Prüf den Pfad oben und füge erneut hinzu.';

  @override
  String get discoverKeepDestChangedTryAgain =>
      'Wo Dateien landen, hat sich seit dem Öffnen geändert. Prüf den Pfad oben und versuch es noch einmal.';

  @override
  String discoverKeepRetryAddsTo(String path) {
    return '„Erneut versuchen“ landet jetzt in $path, deinem gespeicherten Ort';
  }

  @override
  String discoverKeepAddAgainAddsTo(String path) {
    return '„Erneut hinzufügen“ landet jetzt in $path, deinem gespeicherten Ort';
  }

  @override
  String discoverKeepConfirmTitle(int count, String peer) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Alben von $peer kopieren?',
      one: '1 Album von $peer kopieren?',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepConfirmEveryTitle(String artist, String peer) {
    return 'Alle Alben von $artist aus $peer kopieren?';
  }

  @override
  String discoverKeepConfirmBody(String path) {
    return 'Sie landen auf deinem Server in $path, ein Ordner pro Album. Titel, die du schon hast, werden übersprungen.';
  }

  @override
  String discoverKeepConfirmBodyFlat(String path) {
    return 'Sie landen auf deinem Server in $path. Titel, die du schon hast, werden übersprungen.';
  }

  @override
  String discoverKeepConfirmAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Alben kopieren',
      one: '1 Album kopieren',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepConfirmEveryAction => 'Alle Alben kopieren';

  @override
  String get discoverJobQueued => 'Wartet auf einen freien Platz';

  @override
  String get discoverJobQueuedSub => 'Startet von selbst';

  @override
  String get discoverJobCopying => 'Wird kopiert';

  @override
  String get discoverJobStarting => 'Startet…';

  @override
  String get discoverJobStopping => 'Wird angehalten…';

  @override
  String get discoverJobInCollection => 'In deiner Sammlung';

  @override
  String get discoverJobOwned => 'Hast du schon';

  @override
  String get discoverJobOwnedSub => 'Deine Bibliothek hat diesen Titel';

  @override
  String get discoverJobSkipped => 'Übersprungen · dort liegt schon eine Datei';

  @override
  String discoverJobExistsSub(String path) {
    return 'Unter $path liegt schon eine Datei · nichts wurde überschrieben';
  }

  @override
  String get discoverJobFailed => 'Kopieren fehlgeschlagen';

  @override
  String get discoverJobFailedSub => 'Die Kopie wurde nicht fertig';

  @override
  String get discoverJobNothingCopiedLead => 'Nichts kopiert';

  @override
  String get discoverJobNothingCopied => 'nichts kopiert';

  @override
  String get discoverJobStopped => 'Angehalten';

  @override
  String discoverJobStoppedQuota(String peer) {
    return 'Das Übertragungslimit von $peer hat es gestoppt';
  }

  @override
  String discoverJobStoppedBusy(String peer) {
    return '$peer bedient gerade zu viele Streams';
  }

  @override
  String discoverJobStoppedPeer(String peer) {
    return '$peer ist nicht mehr erreichbar';
  }

  @override
  String discoverJobStoppedRefused(String peer) {
    return '$peer erlaubt mit dem Schlüssel deines Servers keine Kopien';
  }

  @override
  String get discoverJobCancelledNothing => 'Angehalten · nichts wurde kopiert';

  @override
  String discoverJobCancelledSome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Angehalten · $count kopiert',
      one: 'Angehalten · 1 kopiert',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobCancelledSub => 'Du hast es abgebrochen';

  @override
  String discoverJobCancelledStay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Du hast es abgebrochen · die $count Titel bleiben in deiner Sammlung',
      one: 'Du hast es abgebrochen · der Titel bleibt in deiner Sammlung',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobNothingAll => 'Du hast schon alles';

  @override
  String discoverJobNothingFrom(String peer) {
    return 'Nichts von $peer zu kopieren';
  }

  @override
  String get discoverJobOnlyGuest => 'Nichts Eigenes zu kopieren';

  @override
  String discoverJobOnlyGuestSub(String artist, String peer) {
    return '$artist ist auf den Alben von $peer nur Gast';
  }

  @override
  String discoverJobFromOther(String peer) {
    return 'Wird von $peer kopiert';
  }

  @override
  String discoverJobComesBack(String action) {
    return '„$action“ ist wieder da, wenn diese Kopie fertig ist';
  }

  @override
  String get discoverJobDone => 'Fertig';

  @override
  String discoverJobCopiedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kopiert',
    );
    return '$_temp0';
  }

  @override
  String discoverJobOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hattest du schon',
    );
    return '$_temp0';
  }

  @override
  String discoverJobFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fehlgeschlagen',
    );
    return '$_temp0';
  }

  @override
  String discoverJobAlbumsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Alben fehlgeschlagen',
      one: '1 Album fehlgeschlagen',
    );
    return '$_temp0';
  }

  @override
  String discoverJobAlbumsLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Alben ausgelassen',
      one: '1 Album ausgelassen',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobRetry => 'Erneut versuchen';

  @override
  String get discoverJobAddAgain => 'Erneut hinzufügen';

  @override
  String get discoverJobAddToQueue => 'Zur Warteschlange hinzufügen';

  @override
  String get discoverMarkWaiting => 'wartet';

  @override
  String get discoverMarkCopying => 'wird kopiert…';

  @override
  String discoverMarkCopyingCount(int done, int total) {
    return 'kopiert $done von $total';
  }

  @override
  String get discoverMarkStopping => 'wird angehalten…';

  @override
  String get discoverMarkInCollection => 'in deiner Sammlung';

  @override
  String get discoverMarkAlreadyYours => 'hast du schon';

  @override
  String get discoverMarkStopped => 'angehalten';

  @override
  String get discoverMarkRefused => 'abgelehnt';

  @override
  String get discoverMarkFailed => 'fehlgeschlagen';

  @override
  String get discoverMarkSkipped => 'übersprungen';

  @override
  String discoverCopiesCopying(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count werden kopiert',
      one: '1 wird kopiert',
    );
    return '$_temp0';
  }

  @override
  String discoverCopiesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fehlgeschlagen',
    );
    return '$_temp0';
  }

  @override
  String discoverCopiesLabel(String summary) {
    return 'Kopien: $summary';
  }

  @override
  String get discoverCopiesTitle => 'Kopien';

  @override
  String get discoverCopiesSectionCopying => 'Wird kopiert';

  @override
  String get discoverCopiesSectionAttention => 'Angehalten oder fehlgeschlagen';

  @override
  String get discoverCopiesSectionFinished => 'Gerade fertig';

  @override
  String get discoverCopiesClearFinished => 'Erledigte entfernen';

  @override
  String get discoverCopiesEmpty => 'Nichts wird kopiert';

  @override
  String get discoverCopiesEmptySub =>
      'Halte auf „Entdecken“ einen Titel oder ein Album eines verbundenen Servers gedrückt, um eine Kopie zu behalten.';

  @override
  String get discoverCopiesOpenDiscover => '„Entdecken“ öffnen';

  @override
  String get discoverCopiesLoadFailed =>
      'Deine Kopien konnten nicht geladen werden';

  @override
  String get discoverCopiesLoadFailedSub =>
      'Dein Server hat nicht geantwortet. Die Kopien laufen dort weiter.';

  @override
  String get discoverCopiesLoading => 'Deine Kopien werden geladen';

  @override
  String get discoverCopiesKindSong => 'Titel';

  @override
  String get discoverCopiesKindAlbum => 'Album';

  @override
  String get discoverCopiesKindEvery => 'Alle Alben';

  @override
  String get discoverCopiesKindMissing => 'Was dir fehlt';

  @override
  String discoverCopiesFrom(String peer) {
    return 'von $peer';
  }

  @override
  String discoverCopiesEveryAlbumBy(String artist) {
    return 'Alle Alben von $artist';
  }

  @override
  String discoverCopiesMissingOf(String artist) {
    return '$artist · Alben, die dir fehlen';
  }

  @override
  String get discoverCopiesAlreadyFinished =>
      'Schon fertig · nichts abzubrechen';

  @override
  String get discoverCopiesCancelFailed =>
      'Abbrechen hat nicht geklappt. Versuch es noch einmal.';

  @override
  String get discoverCopiesDestChanged =>
      'Start nicht möglich: Wo Dateien landen, hat sich geändert — versuch es über „Kopie behalten“ erneut';

  @override
  String discoverToastCopying(String title, String peer) {
    return '$title wird von $peer kopiert';
  }

  @override
  String discoverToastCopyingEvery(String artist, String peer) {
    return 'Alle Alben von $artist werden von $peer kopiert';
  }

  @override
  String discoverToastCopyingMissing(String artist, String peer) {
    return 'Die Alben von $artist, die dir fehlen, werden von $peer kopiert';
  }

  @override
  String get discoverToastAdded => 'Zu deiner Sammlung hinzugefügt';

  @override
  String get discoverToastAlreadyYours => 'Schon in deiner Bibliothek';

  @override
  String discoverToastFailed(String reason) {
    return 'Kopieren fehlgeschlagen: $reason';
  }

  @override
  String discoverToastStopped(String reason) {
    return 'Vorzeitig angehalten: $reason';
  }

  @override
  String get discoverToastLinkFailed => 'Der Link ließ sich nicht öffnen';

  @override
  String discoverToastSaved(String path) {
    return 'Gespeichert · Kopien landen in $path';
  }

  @override
  String get discoverDestTitle => 'Wo Kopien landen';

  @override
  String get discoverDestSub =>
      'Eine Einstellung für dein Konto · jede Kopie nutzt sie';

  @override
  String get discoverDestTagDefault => 'Bibliotheksstandard';

  @override
  String get discoverDestTagYours => 'deine';

  @override
  String discoverDestLandsAt(String title) {
    return '$title landet in';
  }

  @override
  String get discoverDestFixLayout =>
      'Korrigiere das Layout, um zu sehen, wo Dateien landen';

  @override
  String discoverDestPathTooLong(int max) {
    return 'Der Pfad dieses Songs wäre länger als $max Zeichen – mehr, als der Server annimmt';
  }

  @override
  String get discoverDestLibrary => 'Bibliothek';

  @override
  String get discoverDestLayout => 'Layout';

  @override
  String get discoverDestPresetArtistAlbum => 'Künstler / Album';

  @override
  String get discoverDestPresetServer => 'Server / Künstler / Album';

  @override
  String get discoverDestPresetServerFolders =>
      'Dieselben Ordner wie auf dem Server';

  @override
  String get discoverDestPresetLibrary => 'Layout der Bibliothek';

  @override
  String get discoverDestPresetCustom => 'Eigenes';

  @override
  String get discoverDestCustomSub => 'Eigenen Pfad eingeben';

  @override
  String get discoverDestCustomField => 'Eigenes Layout';

  @override
  String discoverDestCustomHint(String example) {
    return 'z. B. Von Freunden oder $example';
  }

  @override
  String get discoverDestCustomHelp =>
      'Ordner mit / trennen. Variablen sortieren Kopien nach Künstler, Album…; ein fester Name legt jede Kopie in denselben Ordner.';

  @override
  String get discoverDestCustomEmpty =>
      'Gib einen Pfad ein, um zu sehen, wo Dateien landen';

  @override
  String get discoverDestInsertArtist => 'Künstler einfügen';

  @override
  String get discoverDestInsertAlbum => 'Album einfügen';

  @override
  String get discoverDestInsertYear => 'Jahr einfügen';

  @override
  String get discoverDestInsertGenre => 'Genre einfügen';

  @override
  String get discoverDestInsertAlbumArtist => 'Albumkünstler einfügen';

  @override
  String get discoverDestInsertPeer => 'Servername einfügen';

  @override
  String get discoverDestInsertServerFolder => 'Serverordner einfügen';

  @override
  String discoverDestErrUnknownVar(String name, String vars) {
    return 'Unbekannte Variable $name. Verwende $vars.';
  }

  @override
  String discoverDestErrBraces(String example) {
    return 'Eine Klammer steht falsch – Variablen schreibt man wie $example.';
  }

  @override
  String discoverDestErrBaseBraces(String folder) {
    return '„$folder“ ist ein Ordner, der auf einem anderen Gerät festgelegt wurde – in einem Layout gilt der Name aber als Variable. Benenne ihn hier um oder wähle ein Layout.';
  }

  @override
  String get discoverDestErrAbsolute =>
      'Ein Layout darf nicht mit / beginnen – es startet in der Bibliothek.';

  @override
  String get discoverDestErrTraversal =>
      'Ein Pfad darf keine „..“-Ordner enthalten.';

  @override
  String get discoverDestErrEmpty =>
      'Daraus entsteht kein Ordner – füge einen Namen oder eine Variable hinzu.';

  @override
  String get discoverDestErrHome =>
      'Ein Pfad darf weder ~ noch \$HOME enthalten.';

  @override
  String get discoverDestErrGeneric =>
      'Dieser Pfad kann nicht verwendet werden.';

  @override
  String get discoverDestErrDrive =>
      'Ein Pfad darf keinen Laufwerksbuchstaben wie C: enthalten.';

  @override
  String discoverDestErrTooLong(int max) {
    return 'Ein Layout darf höchstens $max Zeichen lang sein.';
  }

  @override
  String get discoverDestErrControl =>
      'Ein Pfad darf keine Tabulatoren oder anderen Steuerzeichen enthalten.';

  @override
  String discoverDestMissing(String vars) {
    return 'Für diesen Song leer, daher nicht im Pfad: $vars';
  }

  @override
  String get discoverDestGenreSlot => 'Genre';

  @override
  String get discoverDestArtistSlot => 'Künstler';

  @override
  String get discoverDestYearSlot => 'Jahr';

  @override
  String get discoverDestServerFolderSlot => 'Serverordner';

  @override
  String discoverKeepSlotNote(int count, String slots) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots kommen aus den Tags jedes Songs, daher können diese Songs in mehr als einem Ordner landen.',
      one:
          '$slots kommt aus den Tags jedes Songs, daher können diese Songs in mehr als einem Ordner landen.',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteGenre(int count, String slots) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots kommen aus den Tags jedes Songs, daher können diese Songs in mehr als einem Ordner landen (bei einem Song ohne Genre entfällt dieser Ordner).',
      one:
          '$slots kommt aus den Tags jedes Songs, daher können diese Songs in mehr als einem Ordner landen (bei einem Song ohne Genre entfällt dieser Ordner).',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteSong(String slots) {
    return '$slots kommt aus den Tags des Songs (bei einem Song ohne Genre entfällt dieser Ordner).';
  }

  @override
  String discoverKeepSlotNoteServer(String server) {
    return '$server ergibt sich daraus, wo jeder Song auf dem Server liegt, daher können diese Songs in mehr als einem Ordner landen.';
  }

  @override
  String discoverKeepSlotNoteServerTags(
    int count,
    String slots,
    String server,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots kommen aus den Tags jedes Songs und $server daraus, wo er auf dem Server liegt, daher können diese Songs in mehr als einem Ordner landen.',
      one:
          '$slots kommt aus den Tags jedes Songs und $server daraus, wo er auf dem Server liegt, daher können diese Songs in mehr als einem Ordner landen.',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteServerTagsGenre(
    int count,
    String slots,
    String server,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots kommen aus den Tags jedes Songs und $server daraus, wo er auf dem Server liegt, daher können diese Songs in mehr als einem Ordner landen (bei einem Song ohne Genre entfällt dieser Ordner).',
      one:
          '$slots kommt aus den Tags jedes Songs und $server daraus, wo er auf dem Server liegt, daher können diese Songs in mehr als einem Ordner landen (bei einem Song ohne Genre entfällt dieser Ordner).',
    );
    return '$_temp0';
  }

  @override
  String get discoverDestUseDefault => 'Bibliotheksstandard verwenden';

  @override
  String get discoverDestSaving => 'Wird gespeichert…';

  @override
  String get discoverDestLoadFailed =>
      'Der Speicherort der Kopien konnte nicht geladen werden';

  @override
  String get discoverDestLoading => 'Speicherort der Kopien wird geladen';

  @override
  String get discoverKeepFirstUse =>
      'Kopien landen auf deinem Server, nicht auf diesem Telefon. Prüf vor der ersten, wo sie landen.';

  @override
  String get discoverElsewhereExact => 'Genaue Seiten';

  @override
  String get discoverElsewhereSearch => 'Suche';

  @override
  String get discoverElsewhereMbRecording => 'MusicBrainz-Aufnahme';

  @override
  String get discoverElsewhereMbReleaseGroup =>
      'MusicBrainz-Veröffentlichungsgruppe';

  @override
  String get discoverElsewhereMbIsrc => 'MusicBrainz-ISRC';

  @override
  String get discoverElsewhereEmpty => 'Keine Links für diesen Titel';

  @override
  String get discoverElsewhereEmptySub =>
      'Er hat keine MusicBrainz-IDs und weder Titel noch Künstler zum Suchen.';

  @override
  String get discoverElsewhereFailed =>
      'Links konnten gerade nicht abgerufen werden';

  @override
  String get discoverElsewhereLoading => 'Links werden gesucht';

  @override
  String get discoverElsewhereOpensOutside => 'Öffnet sich außerhalb der App';

  @override
  String get visualizerMilkdropTitle => 'Milkdrop-Visualizer';

  @override
  String get visualizerShadertoyTitle => 'ShaderToy-Visualizer';

  @override
  String get realAudioSynthesizedNote =>
      'Ohne die Berechtigung verwendet der Visualizer stattdessen synthetisierte Daten.';

  @override
  String get realAudioDontAskAgain => 'Nicht mehr fragen';

  @override
  String get realAudioUseSynthesized => 'Synthetisierte Daten verwenden';

  @override
  String get realAudioUseReal => 'Echtes Audio verwenden';

  @override
  String get queueSharePlaylist => 'Playlist teilen';

  @override
  String get autoDjStopShort => 'Stopp';

  @override
  String get autoDjPlayFrom => 'Abspielen von';

  @override
  String get autoDjAllServers => 'Alle Server';

  @override
  String autoDjServersTakingPart(int count, int total) {
    return '$count von $total';
  }

  @override
  String get autoDjQuickSettings => 'Schnelleinstellungen für Auto DJ';

  @override
  String get autoDjAllSettings => 'Alle Einstellungen für Auto DJ';

  @override
  String autoDjServerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Server',
      one: '1 Server',
    );
    return '$_temp0';
  }

  @override
  String get autoDjFirstSong => 'Erster Song';

  @override
  String get autoDjFirstSongRandom => 'Zufällig';

  @override
  String get autoDjFirstSongChoose => 'Auswählen';

  @override
  String get autoDjMustMatch => 'Muss passen';

  @override
  String get autoDjPrefer => 'Bevorzugen';

  @override
  String autoDjPercent(int pct) {
    return '$pct %';
  }

  @override
  String get autoDjDrift => 'Treiben lassen';

  @override
  String get autoDjStayClose => 'Nah bleiben';

  @override
  String get autoDjGenres => 'Genres';

  @override
  String get autoDjGenresOnly => 'Nur';

  @override
  String get autoDjGenresSkip => 'Auslassen';

  @override
  String autoDjGenresSkipValue(String genres) {
    return 'Ohne $genres';
  }

  @override
  String get autoDjRating => 'Bewertung';

  @override
  String autoDjRatingValue(String stars) {
    return '$stars★+';
  }

  @override
  String get autoDjAny => 'Beliebig';

  @override
  String autoDjLengthOver(String min) {
    return '$min+';
  }

  @override
  String autoDjLengthUnder(String max) {
    return 'Unter $max';
  }

  @override
  String autoDjLengthBetween(String min, String max) {
    return '$min–$max';
  }

  @override
  String get autoDjIncludeUnknown => 'Unbekannte einbeziehen';

  @override
  String get autoDjLengthShortest => 'Mindestens';

  @override
  String get autoDjLengthLongest => 'Höchstens';

  @override
  String get autoDjWheelHours => 'Std.';

  @override
  String get autoDjTempo => 'Beatmatching';

  @override
  String get autoDjSkipWords => 'Ausschlusswörter';

  @override
  String get autoDjBatch => 'Stapel';

  @override
  String get autoDjVaries => 'Unterschiedlich';

  @override
  String autoDjMax(int count) {
    return 'max. $count';
  }

  @override
  String autoDjNeedsServer(String version) {
    return 'Ab Server $version';
  }

  @override
  String get autoDjDiscoveryOff => 'Discovery aus';

  @override
  String get autoDjStillScanning => 'Scan läuft noch';

  @override
  String get autoDjTooStrict => 'Zu streng';

  @override
  String get autoDjNotOnPeers => 'Nicht bei Peers';

  @override
  String get autoDjNoMoodData => 'Keine Stimmungsdaten';

  @override
  String get autoDjOtherModel => 'Anderes Audiomodell';

  @override
  String get autoDjUnreachable => 'Nicht erreichbar';

  @override
  String get autoDjRemember => 'Merken';

  @override
  String get autoDjGenresNone => 'Keine Genres';

  @override
  String get autoDjNoMatches => 'Keine Treffer';

  @override
  String get autoDjRecentlyPlayed => 'Zuletzt gehört';

  @override
  String get autoDjFirstSongRecent => 'Zuletzt gehört';

  @override
  String get browseLoadFailed =>
      'Couldn\'t load this from the server. Check the connection and try again.';

  @override
  String get settingsSectionVisualizer => 'Visualizer';

  @override
  String get settingsOfflineQueueFooter =>
      'Nur für Downloads der Warteschlange. Eigene Downloads bleiben immer erhalten.';

  @override
  String settingsAutoDownloadCapValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '$count Titel',
    );
    return '$_temp0';
  }

  @override
  String get settingsAutoDownloadCapHint => '0 = unbegrenzt';

  @override
  String get settingsStartupRecentHint => 'Zuletzt hinzugefügt';

  @override
  String settingsLetterStripValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count+ Einträge',
      one: '$count+ Einträge',
      zero: 'Immer',
    );
    return '$_temp0';
  }

  @override
  String get settingsLetterStripHint =>
      'In A–Z-Listen. Kürzere Listen brechen lange Namen stattdessen um.';

  @override
  String get settingsHistoryFooter =>
      'Server scrobbeln nur an Last.fm, wenn du dort ein Konto verknüpft hast.';

  @override
  String get settingsHistoryEmpty => 'Leer';

  @override
  String get settingsHistoryOffTitle => 'Aufzeichnung beenden?';

  @override
  String settingsHistoryOffBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Das löscht den Hörverlauf dieses Telefons, einschließlich $count noch nicht synchronisierter Wiedergaben. Server behalten ihren eigenen.',
      one:
          'Das löscht den Hörverlauf dieses Telefons, einschließlich $count noch nicht synchronisierter Wiedergabe. Server behalten ihren eigenen.',
      zero:
          'Das löscht den Hörverlauf dieses Telefons. Server behalten ihren eigenen.',
    );
    return '$_temp0';
  }

  @override
  String get settingsHistoryOffConfirm => 'Ausschalten';

  @override
  String get settingsHistoryClearTitle => 'Verlauf leeren?';

  @override
  String get settingsResetTitle => 'Einstellungen zurücksetzen?';

  @override
  String get settingsResetBody =>
      'Setzt auch Equalizer, Transkodierung und einige Optionen außerhalb der Einstellungen zurück. Server, Downloads, Hörverlauf und gespeicherte Presets bleiben erhalten.';

  @override
  String get settingsResetBodyIos =>
      'Setzt auch Transkodierung und einige Optionen außerhalb der Einstellungen zurück. Server, Downloads und Hörverlauf bleiben erhalten.';

  @override
  String get ytdlTitle => 'Von YouTube hinzufügen';

  @override
  String ytdlHomeAdding(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in Arbeit',
    );
    return '$_temp0';
  }

  @override
  String ytdlHomeAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fertig',
    );
    return '$_temp0';
  }

  @override
  String ytdlHomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fehler',
    );
    return '$_temp0';
  }

  @override
  String get ytdlPasteHint => 'YouTube-Link einfügen';

  @override
  String get ytdlPasteFromClipboard => 'Aus Zwischenablage einfügen';

  @override
  String ytdlLandsIn(String path) {
    return 'Landet in $path';
  }

  @override
  String get ytdlLimits =>
      'Ein Video pro Link · der Server stoppt bei 500 MB oder nach einer Stunde · keine Livestreams oder Playlists';

  @override
  String get ytdlEmptyTitle =>
      'Füge einen Link ein, um einen Song zu deiner Bibliothek hinzuzufügen.';

  @override
  String get ytdlEmptyWebApp =>
      'Songs, die über die Web-App hinzugefügt wurden, erscheinen auch hier.';

  @override
  String ytdlLinkShortSent(String link) {
    return 'Kurzlink: gesendet als $link';
  }

  @override
  String ytdlLinkSentAs(String link) {
    return 'Gesendet als $link';
  }

  @override
  String get ytdlLinkNotYoutube =>
      'Das ist kein YouTube-Link. Füge einen von youtube.com oder youtu.be ein.';

  @override
  String get ytdlLinkPlaylist =>
      'Das ist eine Playlist. Öffne ein einzelnes Video daraus und kopiere dessen Link.';

  @override
  String get ytdlLinkInPlaylist => 'Nur dieses Video, nicht die Playlist.';

  @override
  String get ytdlLinkLive =>
      'Livestreams lassen sich nicht speichern. Ist dieser schon vorbei, klappt es vielleicht trotzdem.';

  @override
  String get ytdlLinkLiveOlder =>
      'Dieser Server lehnt Livestreams nicht ab. Füge diesen nur hinzu, wenn er vorbei ist.';

  @override
  String get ytdlLookupReading => 'Video wird gelesen…';

  @override
  String get ytdlLookupSlow =>
      'Suche läuft noch – YouTube ist manchmal langsam.';

  @override
  String get ytdlLookupEnterYourself => 'Details selbst eingeben';

  @override
  String get ytdlLookupFailed =>
      'Die Details dieses Videos konnten nicht gelesen werden. Es ist vielleicht privat, altersbeschränkt oder für den Server gesperrt.';

  @override
  String get ytdlLookupTimedOut =>
      'Der Server hat zu lange gebraucht – vielleicht richtet er yt-dlp noch ein. Versuch es in einer Minute noch einmal.';

  @override
  String get ytdlLookupEnterDetails => 'Details eingeben';

  @override
  String get ytdlLookupNoTags =>
      'Noch keine Tags, daher landet der Song im Stammordner der Bibliothek.';

  @override
  String get ytdlLookupFailedUsingYours =>
      'Die Details dieses Videos konnten nicht gelesen werden · Deine Angaben werden verwendet.';

  @override
  String get ytdlLateFound => 'Details zu diesem Video gefunden';

  @override
  String get ytdlLateUseThem => 'Übernehmen';

  @override
  String get ytdlLateEditsStay => 'Deine Änderungen bleiben erhalten.';

  @override
  String get ytdlOffline =>
      'Du bist offline – die Suche läuft, sobald du wieder online bist.';

  @override
  String get ytdlYtdlpMissing =>
      'Dieser Server kann noch nichts von YouTube holen. Bitte den Admin, yt-dlp einzurichten.';

  @override
  String get ytdlCardNoAlbum => 'Kein Album';

  @override
  String get ytdlSourceMusic => 'Tags von YouTube Music';

  @override
  String get ytdlSourceSplit => 'Künstler und Titel aus dem Videotitel';

  @override
  String get ytdlSourceSplitAgrees =>
      'Künstler und Titel aus dem Videotitel · passt zum Künstler bei YouTube';

  @override
  String get ytdlSourceChannel =>
      'Künstler ist vielleicht der Kanalname – bitte prüfen';

  @override
  String ytdlCleanedFrom(String title) {
    return 'Bereinigt aus „$title“';
  }

  @override
  String get ytdlUndoAll => 'Alles rückgängig';

  @override
  String get ytdlEditTags => 'Tags bearbeiten';

  @override
  String get ytdlFieldTitle => 'Titel';

  @override
  String get ytdlHelpMusic => 'Von YouTube Music';

  @override
  String get ytdlHelpVideoTitle => 'Aus dem Videotitel';

  @override
  String get ytdlHelpVideoTitleCleaned => 'Aus dem Videotitel, bereinigt';

  @override
  String get ytdlHelpYoutubeArtist => 'Aus dem Künstlerfeld von YouTube';

  @override
  String get ytdlHelpYoutubeArtistCheck =>
      'Aus dem Künstlerfeld von YouTube – bitte prüfen';

  @override
  String ytdlHelpYoutubeArtistStripped(String removed) {
    return 'Aus dem Künstlerfeld von YouTube, „$removed“ entfernt – bitte prüfen';
  }

  @override
  String get ytdlHelpEdited => 'Bearbeitet';

  @override
  String get ytdlBlankTitle =>
      'Leer: Die Datei bekommt den Originaltitel des Videos.';

  @override
  String get ytdlBlankArtistMusic =>
      'Leer: Die Datei behält den Künstler von YouTube Music.';

  @override
  String ytdlBlankArtistGuess(String name) {
    return 'Leer: Die Datei bekommt YouTubes eigene Vermutung zum Künstler, oft einfach den Kanalnamen (hier „$name“).';
  }

  @override
  String get ytdlBlankArtistGuessUnnamed =>
      'Leer: Die Datei bekommt YouTubes eigene Vermutung zum Künstler, oft einfach den Kanalnamen.';

  @override
  String get ytdlBlankAlbumSingle => 'Für eine Single leer lassen';

  @override
  String get ytdlBlankAlbumKeeps =>
      'Leer: Der Album-Tag von YouTube bleibt erhalten';

  @override
  String get ytdlBlankYear =>
      'Leer: Die Datei bekommt das Upload-Jahr von YouTube.';

  @override
  String get ytdlYearInvalid => 'Ein Jahr hat 4 Ziffern, z. B. 2001';

  @override
  String ytdlRestoreSplit(String separator) {
    return 'Getrennt bei $separator';
  }

  @override
  String ytdlOrYoutubeArtist(String name) {
    return 'Oder Künstler laut YouTube: $name';
  }

  @override
  String get ytdlSwap => 'Künstler und Titel tauschen';

  @override
  String get ytdlSavesTo => 'Wird gespeichert in';

  @override
  String get ytdlSavesHere => 'Wird hier gespeichert';

  @override
  String get ytdlNewTag => 'neu';

  @override
  String get ytdlSampleFile => 'Datei';

  @override
  String get ytdlSampleFileStem => 'Videotitel';

  @override
  String ytdlFileAbout(String name) {
    return 'voraussichtlich $name';
  }

  @override
  String ytdlFileAboutLettersDropped(String name) {
    return 'voraussichtlich $name · Buchstaben außerhalb von A–Z fallen in Dateinamen weg';
  }

  @override
  String get ytdlCheckFailed => 'Dieser Ordner konnte nicht geprüft werden';

  @override
  String get ytdlJustThisSong => 'Nur dieser Song';

  @override
  String get ytdlUndo => 'Rückgängig';

  @override
  String ytdlClash(String name) {
    return 'Etwas wie „$name“ scheint schon in diesem Ordner zu liegen. Der Server ersetzt es nicht, daher würde das wohl fehlschlagen.';
  }

  @override
  String get ytdlClashChangeFormat =>
      'Format ändern – ein anderes Format ergibt eine andere Datei';

  @override
  String ytdlClashOlder(String name) {
    return 'Eine Datei namens „$name“ liegt schon in diesem Ordner. Dieser Server würde sie neu taggen, statt eine neue hinzuzufügen.';
  }

  @override
  String get ytdlChangeFormat => 'Format ändern';

  @override
  String get ytdlAddToLibrary => 'Zur Bibliothek hinzufügen';

  @override
  String get ytdlAddHere => 'Hier hinzufügen';

  @override
  String get ytdlAddAnyway => 'Trotzdem hinzufügen';

  @override
  String get ytdlAlreadyAdding => 'Wird schon zu diesem Ordner hinzugefügt';

  @override
  String get ytdlFormatMenuTitle => 'Bestes Audio des Videos, gespeichert als';

  @override
  String ytdlFormatRemembered(String server) {
    return 'Gemerkt für $server';
  }

  @override
  String get ytdlFormatMp3Help => 'Läuft überall';

  @override
  String get ytdlFormatM4aHelp => 'Gut für Apple-Geräte';

  @override
  String get ytdlFormatOpusHelp =>
      'Meist YouTubes eigenes Audio, ohne Umwandlung';

  @override
  String get ytdlFormatFlacHelp =>
      'Größer, aber nicht besser als der Ton des Videos';

  @override
  String get ytdlFormatWavHelp => 'Am größten, ohne Cover';

  @override
  String get ytdlErrFfmpeg =>
      'Der Server kann gerade kein Audio umwandeln. Versuch es später noch einmal oder frag den Admin.';

  @override
  String get ytdlErrUploadsOff =>
      'Dein Konto kann diesem Server keine Dateien hinzufügen.';

  @override
  String ytdlErrLibraryGone(String library) {
    return 'Du kannst „$library“ keine Dateien mehr hinzufügen. Wähle eine andere Bibliothek.';
  }

  @override
  String ytdlErrLibraryGoneSheet(String library) {
    return 'Du kannst „$library“ keine Dateien mehr hinzufügen.';
  }

  @override
  String get ytdlErrNoRoute =>
      'Dieser Server bietet „Von YouTube hinzufügen“ nicht an.';

  @override
  String ytdlErrFormatOff(String format) {
    return 'Dieser Server speichert kein $format mehr';
  }

  @override
  String get ytdlErrPickAnother => 'ein anderes wählen';

  @override
  String get ytdlErrBadRequest =>
      'Etwas an diesem Link hat dem Server nicht gepasst. Versuch es noch einmal.';

  @override
  String get ytdlErrServer => 'Auf dem Server ist etwas schiefgelaufen.';

  @override
  String ytdlErrOther(String message) {
    return 'Der Server meldet: „$message“';
  }

  @override
  String ytdlErrMkdir(String folder) {
    return 'Der Ordner „$folder“ konnte nicht erstellt werden.';
  }

  @override
  String get ytdlSectionAdding => 'Wird hinzugefügt';

  @override
  String get ytdlSectionAddingNote =>
      'Läuft auf dem Server · lässt sich in der App nicht anhalten';

  @override
  String get ytdlSectionNeedsLook => 'Bitte prüfen';

  @override
  String get ytdlSectionAdded => 'Hinzugefügt';

  @override
  String ytdlRowAdding(int minutes, String format) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Wird hinzugefügt · $minutes Min. · $format',
    );
    return '$_temp0';
  }

  @override
  String get ytdlRowStartUnsure =>
      'Startet… der Server hat noch nicht geantwortet';

  @override
  String get ytdlRowNotSureStarted => 'Unklar, ob es gestartet ist';

  @override
  String get ytdlRowNotFound => 'Nicht auf dem Server gefunden';

  @override
  String get ytdlRowClash =>
      'Fehlgeschlagen · eine Datei mit diesem Namen scheint schon dort zu liegen. Nichts wurde ersetzt.';

  @override
  String get ytdlRowFailed =>
      'Fehlgeschlagen · der Server hat keinen Grund genannt. Häufige Ursachen: ein Livestream, YouTube weist den Server ab, 500 MB oder eine Stunde.';

  @override
  String get ytdlRowFailedOlder =>
      'Fehlgeschlagen · der Server hat keinen Grund genannt. Vielleicht hat YouTube den Server abgewiesen.';

  @override
  String get ytdlRowNotSureFinished =>
      'Unklar, ob es fertig wurde · es endete, während die App nicht aktiv war, und der Server hat keinen Eintrag dazu';

  @override
  String get ytdlRowWaiting => 'Wartet auf Verbindung';

  @override
  String get ytdlRowFileMissing => 'Datei fehlt';

  @override
  String get ytdlRowHide => 'Aus dieser Liste ausblenden';

  @override
  String get ytdlRowChangeFormatRetry => 'Format ändern und erneut versuchen';

  @override
  String get ytdlRowShowFolder => 'Ordner anzeigen';

  @override
  String get ytdlRowShowInFolder => 'Im Ordner anzeigen';

  @override
  String get ytdlShowEarlier => 'Ältere anzeigen';

  @override
  String get ytdlWhereTitle => 'Wo neue Songs landen';

  @override
  String ytdlWhereSub(String server) {
    return 'Auf diesem Telefon für $server gespeichert · Kopien aus „Entdecken“ haben ihre eigene Einstellung.';
  }

  @override
  String ytdlWhereLandsAt(String title) {
    return '„$title“ landet in';
  }

  @override
  String get ytdlWhereLandsAtSample => 'Ein Song landet in';

  @override
  String get ytdlWhereSampleNote =>
      'Mit Beispielwörtern gezeigt, bis du einen Link einfügst.';

  @override
  String ytdlWhereFileNote(String title) {
    return 'Der Dateiname kommt aus dem Videotitel; deine Bibliothek zeigt „$title“.';
  }

  @override
  String ytdlWhereAlwaysEmpty(String vars) {
    return 'Bei YouTube-Songs immer leer, daher nicht im Pfad: $vars';
  }

  @override
  String get ytdlWhereSetByDiscover => 'Von „Entdecken“ festgelegt';

  @override
  String get ytdlLayoutTop => 'Direkt in die Bibliothek';

  @override
  String get ytdlLayoutTopSub => 'Keine Ordner';

  @override
  String get ytdlLayoutDiscover => 'Wie bei „Entdecken“';

  @override
  String get ytdlWhereUseForSong => 'Für diesen Song verwenden';

  @override
  String get ytdlWhereNoMkdir =>
      'Dein Konto kann keine Ordner erstellen, daher gehen nur Ordner, die es schon gibt. „Direkt in die Bibliothek“ geht immer.';

  @override
  String get ytdlCustomHelp =>
      'Ordner mit / trennen. TITLE gibt es nicht – der Dateiname kommt immer aus dem Videotitel.';

  @override
  String ytdlErrNeverVar(String name, String vars) {
    return '$name ist bei YouTube-Songs immer leer. Verwende $vars.';
  }

  @override
  String get ytdlErrBadChars =>
      'Ein Ordnername darf kein : * ? \" < > oder | enthalten.';

  @override
  String ytdlTrapEmpty(String folder) {
    return 'Für diesen Ordner fehlen alle Tags, daher heißt er „$folder“. Füge ein Album und ein Jahr hinzu oder wähle ein anderes Layout.';
  }

  @override
  String ytdlTrapNoYear(String folder) {
    return 'Kein Jahr für diesen Song, daher heißt der Ordner „$folder“. Die Datei bekommt trotzdem das Upload-Jahr von YouTube als Tag.';
  }

  @override
  String ytdlTrapOther(String folder) {
    return 'Ein Tag ist leer, daher heißt der Ordner „$folder“. Füll die Tags aus oder wähle ein anderes Layout.';
  }

  @override
  String get ytdlTrapAddYear => 'Jahr hinzufügen';

  @override
  String ytdlNoMkdirNew(String folder) {
    return '„$folder“ gibt es noch nicht, und dein Konto kann keine Ordner erstellen.';
  }

  @override
  String get ytdlNoMkdirUnchecked =>
      'Dein Konto kann keine Ordner erstellen, und dieser Ordner konnte nicht geprüft werden.';

  @override
  String ytdlSaveToInstead(String path) {
    return 'Stattdessen in $path speichern';
  }

  @override
  String get ytdlChooseFolderLink => 'Ordner wählen…';

  @override
  String get ytdlChooseTitle => 'Ordner wählen';

  @override
  String get ytdlChooseSub =>
      'Dein Konto kann keine Ordner erstellen, wähle also einen, den es schon gibt.';

  @override
  String get ytdlChooseEmpty => 'Hier gibt es keine Ordner.';

  @override
  String get ytdlExplorerEntry => 'Hier von YouTube hinzufügen';

  @override
  String ytdlSheetInto(String path) {
    return 'In $path';
  }

  @override
  String get ytdlSortSubfolders => 'In Unterordner sortieren…';

  @override
  String get ytdlSubfoldersTitle => 'In Unterordner sortieren';

  @override
  String get ytdlSubfoldersHere => 'Der Ordner, in dem du bist';

  @override
  String get ytdlSubfoldersRightHere => 'Genau hier';

  @override
  String get ytdlSubfoldersNone => 'Keine Unterordner';

  @override
  String ytdlSubfoldersNew(int count, String folders) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Ordner werden erstellt: $folders',
      one: '$count neuer Ordner wird erstellt: $folders',
    );
    return '$_temp0';
  }

  @override
  String ytdlStripAdding(String title) {
    return '„$title“ wird hinzugefügt…';
  }

  @override
  String ytdlStripAddingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos werden hinzugefügt…',
      one: '$count Video wird hinzugefügt…',
    );
    return '$_temp0';
  }

  @override
  String get ytdlStripSeeAll => 'Alle ansehen';

  @override
  String get ytdlStripDetails => 'Details';

  @override
  String ytdlToastAdded(String title, String path) {
    return '„$title“ zu $path hinzugefügt';
  }

  @override
  String ytdlCouldntAdd(String title) {
    return '„$title“ konnte nicht hinzugefügt werden';
  }

  @override
  String ytdlToastSaved(String path) {
    return 'Gespeichert · neue Songs landen in $path';
  }

  @override
  String get ytdlToastHidden => 'Ausgeblendet. Der Server macht weiter.';

  @override
  String get ytdlA11yLinkField => 'YouTube-Link';

  @override
  String get ytdlA11yClearLink => 'Link löschen';

  @override
  String ytdlA11yFormat(String format) {
    return 'Format, $format';
  }

  @override
  String ytdlA11yPutBack(String fragment) {
    return '$fragment wieder einfügen';
  }

  @override
  String get ytdlA11yUndoSplit => 'Trennung am Strich aufheben';

  @override
  String get ytdlA11yUndoSplitColon => 'Trennung am Doppelpunkt aufheben';

  @override
  String ytdlA11yMoreFor(String title) {
    return 'Mehr zu $title';
  }

  @override
  String get ytdlA11yAdding => 'Wird hinzugefügt';

  @override
  String get ytdlA11yNewFolder => 'ein neuer Ordner';

  @override
  String ytdlCrumbThen(String previous, String next) {
    return '$previous, dann $next';
  }

  @override
  String ytdlCrumbNew(String folder) {
    return '$folder, ein neuer Ordner';
  }

  @override
  String ytdlCrumbFile(String path, String file) {
    return '$path, Datei $file';
  }

  @override
  String get ytdlCrumbEmptyBrackets => 'leere Klammern';

  @override
  String ytdlCrumbWithEmptyBrackets(String folder) {
    return '$folder mit leeren Klammern';
  }

  @override
  String ytdlA11yVarUsed(String name) {
    return '$name, bereits verwendet';
  }

  @override
  String get ytdlA11yInsertVariable => 'Variable einfügen';

  @override
  String get ytdlA11yLocked => 'Gesperrt';

  @override
  String get ytdlA11yFolderPath => 'Ordnerpfad';

  @override
  String ytdlA11yUpTo(String folder) {
    return 'Hoch zu $folder';
  }

  @override
  String get ytdlA11yCover => 'Cover';

  @override
  String ytdlSummaryBy(String title, String artist) {
    return '$title, von $artist';
  }

  @override
  String ytdlSummaryAlbum(String album) {
    return 'Album $album';
  }

  @override
  String get ytdlSummaryNoAlbum => 'kein Album';

  @override
  String ytdlSummary(String details, String source, String path) {
    return '$details. $source. Wird gespeichert in $path.';
  }

  @override
  String get ytdlErrAddOffline =>
      'Du bist offline – versuch es noch einmal, wenn du wieder online bist.';

  @override
  String get ytdlHelpVideoRelease =>
      'Aus dem Veröffentlichungsdatum des Videos';

  @override
  String get ytdlChooseLoading => 'Ordner werden geladen';

  @override
  String get ytdlRowNoConnection =>
      'Nicht gestartet · das Telefon hat den Server nicht erreicht';

  @override
  String ytdlServerUnreachable(String server) {
    return 'Der Server $server ist nicht erreichbar. Prüfe, ob er läuft, und versuch es dann noch einmal.';
  }

  @override
  String ytdlErrAddUnreachable(String server) {
    return 'Der Server $server ist nicht erreichbar – prüfe, ob er läuft, und versuch es dann noch einmal.';
  }
}
