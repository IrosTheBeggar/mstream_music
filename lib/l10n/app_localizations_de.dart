// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get languageSystemDefault => 'Systemstandard';

  @override
  String get settingsLanguageSubtitle =>
      'Die Anzeigesprache der App. \"Systemstandard\" folgt deinem Gerät.';

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
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'Shaders';

  @override
  String get visualizerSourceSynthesized => 'Synthetisiert';

  @override
  String get visualizerSourceReal => 'Echtes Audio';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String downloadProgress(String progress) {
    return 'Fortschritt: $progress%';
  }

  @override
  String get songInfoTitle => 'Songinfo';

  @override
  String get eqTitle => 'Equalizer';

  @override
  String get eqOnlyAndroid => 'Der Equalizer ist nur unter Android verfügbar.';

  @override
  String get eqNeedsPlayback =>
      'Starte einen Song, um den Equalizer einzurichten.\n\nAndroids nativer Equalizer wird mit der Audiositzung initialisiert, daher muss die Wiedergabe aktiv sein, bevor wir das Band-Layout auslesen können.';

  @override
  String eqInitFailed(String error) {
    return 'Equalizer konnte nicht initialisiert werden:\n$error';
  }

  @override
  String get eqNoBands =>
      'Der Audiotreiber dieses Geräts meldet keine Equalizer-Bänder.';

  @override
  String get eqEnabledOn => 'Ein – Verstärkung auf Wiedergabe angewendet';

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
  String get settingsSectionBrowse => 'Durchsuchen';

  @override
  String get settingsSectionAbout => 'Über';

  @override
  String get settingsTheme => 'Design';

  @override
  String get themeSubtitleVelvet =>
      'Marineblau und Violett – das charakteristische dunkle Design.';

  @override
  String get themeSubtitleDark =>
      'Neutrales Dunkel mit bernsteinfarbenen Akzenten.';

  @override
  String get themeSubtitleLight =>
      'Heller Hintergrund mit dunkler App-Leiste und bernsteinfarbenen Akzenten – passt zum älteren mitgelieferten Design.';

  @override
  String get settingsTranscode => 'Audio transkodieren';

  @override
  String get settingsTranscodeSubtitle =>
      'Streame eine transkodierte Kopie vom Server (kleinere Dateien, etwas langsamerer Start). Aus spielt Originaldateien ab.';

  @override
  String get settingsTapBehavior => 'Beim Antippen eines Songs';

  @override
  String get tapSubtitleAddToQueue =>
      'Beim Antippen wird der Song an die Warteschlange angehängt. Ist die Warteschlange leer, startet die Wiedergabe automatisch.';

  @override
  String get tapSubtitlePlayFromHere =>
      'Beim Antippen wird die Warteschlange durch die Songs der aktuellen Ansicht ersetzt und die Wiedergabe beim angetippten Song gestartet.';

  @override
  String get tapSubtitleAppendAndJump =>
      'Beim Antippen wird der Song an die Warteschlange angehängt und die Wiedergabe springt dorthin, was gerade läuft, wird unterbrochen.';

  @override
  String get settingsEqSubtitle =>
      'Bass, Mitten und Höhen anpassen. Nur Android.';

  @override
  String get settingsVisualizerEngine => 'Visualizer-Engine';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'Milkdrop-Presets über projectM (Standard). Reichhaltigere Effekte, höhere GPU-Last.';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Fragment-Shader im Shadertoy-Stil. Leichter, modular – lege .glsl-Dateien in assets/shaders/ ab, um den Katalog zu erweitern.';

  @override
  String get settingsVisualizerSource => 'Visualizer-Audioquelle';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'Standard. Der Visualizer reagiert nur auf das Wiedergabe-Timing – keine Mikrofonberechtigung erforderlich.';

  @override
  String get visualizerSourceSubtitleReal =>
      'Der Visualizer reagiert auf die tatsächliche Audioausgabe. Erfordert die RECORD_AUDIO-Berechtigung unter Android.';

  @override
  String get settingsAlbumGrid => 'Album-Rasteransicht';

  @override
  String get settingsAlbumGridSubtitle =>
      'Alben als Raster von Karten mit Cover-Art statt als einfache Liste anzeigen.';

  @override
  String get settingsFileMetadata => 'Song-Metadaten im Datei-Explorer lesen';

  @override
  String get settingsFileMetadataSubtitle =>
      'Titel, Interpret und Album-Art für jeden Song beim Durchsuchen von Serverdateien abrufen. Aus zeigt rohe Dateinamen (schneller bei großen Ordnern).';

  @override
  String get settingsLetterStrip => 'Schwellenwert für Buchstaben-Scrubber';

  @override
  String get settingsLetterStripSubtitle =>
      'Den A-Z-Schnellscrubber anzeigen, wenn eine Liste mindestens so viele Einträge hat. Darunter wird der Streifen ausgeblendet und lange Ordner-/Dateinamen werden auf mehrere Zeilen umgebrochen statt abgeschnitten. Auf 0 setzen, um den Streifen immer anzuzeigen.';

  @override
  String get settingsReset => 'Auf Standard zurücksetzen';

  @override
  String get settingsResetSubtitle =>
      'Alle Einstellungen auf diesem Bildschirm auf die Standardwerte zurücksetzen. Server und Downloads sind nicht betroffen.';

  @override
  String get settingsResetDone => 'Einstellungen auf Standard zurückgesetzt';

  @override
  String get realAudioDialogTitle => 'Echtes Audio verwenden?';

  @override
  String get realAudioDialogBody =>
      'Der Echtaudio-Modus liest die Wellenform der Musik, die dein Telefon abspielt, damit der Visualizer darauf reagieren kann. Android erfordert dafür die RECORD_AUDIO-Berechtigung – die App nimmt kein Audio auf und sendet es nirgendwohin. Du kannst jederzeit zu synthetisiert zurückwechseln.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Berechtigung dauerhaft verweigert. Aktiviere sie in den Systemeinstellungen, um echtes Audio zu verwenden.';

  @override
  String get realAudioPermDenied =>
      'Berechtigung verweigert. Es wird bei synthetisiertem Audio geblieben.';

  @override
  String get visualizerTapHint =>
      'Tippen = nächstes Preset · lange drücken zum Schließen';

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
      'Erstelle eine über die Schaltfläche \"Neue Playlist\" und fülle sie dann mit der Wischaktion \"Zur Playlist hinzufügen\" in der Warteschlange.';

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
    return 'Der Server \"$name\" ist nicht mehr in deiner Serverliste. Füge ihn erneut hinzu, um seine Warteschlange zu teilen.';
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
  String get fieldSdCard => 'Auf SD-Karte herunterladen';

  @override
  String get sdCardSubtitle =>
      'Heruntergeladene Musik auf der austauschbaren SD-Karte statt im internen Speicher sichern.';

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
  String get testCouldNotConnect =>
      'Verbindung fehlgeschlagen. Überprüfe die URL und versuche es erneut.';

  @override
  String get testTimedOut => 'Zeitüberschreitung bei der Verbindung.';

  @override
  String get connectFailedSnack =>
      'Verbindung zum Server fehlgeschlagen. Überprüfe die URL und versuche es erneut.';

  @override
  String get connectionSuccessful => 'Verbindung erfolgreich!';

  @override
  String get couldNotReachServer =>
      'Server nicht erreichbar. Falls eine Anmeldung erforderlich ist, deaktiviere \"Öffentlicher Zugriff\" und füge Zugangsdaten hinzu.';

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
  String get autoDjAddServerFirst => 'Füge zuerst einen Server hinzu.';

  @override
  String get autoDjSectionServer => 'Server';

  @override
  String get autoDjSectionSources => 'Quellen';

  @override
  String get autoDjSectionContinuity => 'Kontinuität';

  @override
  String get autoDjSectionFilters => 'Filter';

  @override
  String get autoDjBpmTitle => 'BPM-Kontinuität';

  @override
  String get autoDjBpmSubtitle =>
      'Bevorzugt Titel innerhalb eines Tempofensters des aktuellen Songs. Berücksichtigt Halb-/Doppeltempo-Äquivalenz.';

  @override
  String get autoDjTolerance => 'Toleranz';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Harmonisches Mixen';

  @override
  String get autoDjHarmonicSubtitle =>
      'Bevorzugt Titel in Tonarten, die gut zum gesperrten Song passen (Camelot-Rad-Nachbarn).';

  @override
  String get autoDjStatusOn => 'Auto DJ ist an';

  @override
  String get autoDjStatusOff => 'Auto DJ ist aus';

  @override
  String get autoDjStatusOffDetail =>
      'Tippe unten zum Starten. Die Bibliothek des aktuellen Servers wird verwendet.';

  @override
  String get autoDjStart => 'Auto DJ starten';

  @override
  String get autoDjStop => 'Auto DJ stoppen';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'Songs werden aus $url ausgewählt, wenn die Warteschlange zur Neige geht.';
  }

  @override
  String get autoDjActiveSource => 'Aktive Quelle';

  @override
  String get autoDjActiveSourceTap => 'Aktive Quelle – zum Wechseln tippen';

  @override
  String get autoDjSwitch => 'Wechseln';

  @override
  String get autoDjOneSourceRequired =>
      'Mindestens eine Quelle ist erforderlich.';

  @override
  String get autoDjMinRating => 'Mindestbewertung';

  @override
  String get autoDjMinRatingSubtitle =>
      'Nur Songs mit dieser Bewertung oder höher auswählen.';

  @override
  String get autoDjRatingAny => 'Beliebig';

  @override
  String get autoDjGenreTitle => 'Genre-Filter';

  @override
  String get autoDjGenreSubtitle =>
      'Whitelist spielt nur passende Titel; Blacklist überspringt sie.';

  @override
  String get autoDjWhitelist => 'Whitelist';

  @override
  String get autoDjBlacklist => 'Blacklist';

  @override
  String get autoDjNoGenres =>
      'Keine Genres ausgewählt. Tippe auf \"Genres auswählen\".';

  @override
  String get autoDjPickGenres => 'Genres auswählen';

  @override
  String get autoDjGenreLoadError => 'Genres konnten nicht geladen werden';

  @override
  String get autoDjKeywordTitle => 'Stichwort-Filter';

  @override
  String get autoDjKeywordSubtitle =>
      'Überspringt Titel, deren Name, Interpret, Album oder Dateipfad eines dieser Wörter enthält.';

  @override
  String get autoDjNoKeywords =>
      'Keine Stichwörter. Füge unten Wörter hinzu, um zu filtern.';

  @override
  String get autoDjKeywordHint => 'z. B. \"live\" oder \"remix\"';

  @override
  String get autoDjSearchGenres => 'Genres suchen…';

  @override
  String get autoDjNoGenresOnServer =>
      'Keine Genres auf diesem Server gefunden.';

  @override
  String autoDjSelectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return 'Keine Genres passen zu \"$query\".';
  }

  @override
  String get download => 'Herunterladen';

  @override
  String get addAll => 'Alle hinzufügen';

  @override
  String get browserConfirmDeletePlaylist => 'Playlist-Löschung bestätigen';

  @override
  String get browserConfirmDeleteFolder => 'Ordner-Löschung bestätigen';

  @override
  String get browserSearchHint => 'Datenbank durchsuchen';

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
  String get visualizerTitle => 'Visualizer';

  @override
  String get mainClearQueue => 'Warteschlange leeren';

  @override
  String get mainSync => 'Synchronisieren';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel in der Warteschlange',
      one: '1 Titel in der Warteschlange',
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
  String get testConnectedSignedIn => 'Verbunden — erfolgreich angemeldet.';

  @override
  String get testSignInFailed =>
      'Server erreicht, aber die Anmeldung ist fehlgeschlagen — überprüfe Benutzername und Passwort.';

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
  String get browserRecent => 'Neueste';

  @override
  String get browserRated => 'Bewertet';

  @override
  String get browserSearch => 'Suchen';

  @override
  String get browserWelcomeTitle => 'Willkommen bei mStream';

  @override
  String get browserWelcomeSubtitle =>
      'Hier tippen, um einen Server hinzuzufügen';

  @override
  String get settingsVisualizerKnobs => 'Visualizer-Regler';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      'Zeigt Live-Regler über dem Visualizer, um die Audio-Reaktivität jedes Shaders anzupassen. Nur Shader-Engine.';

  @override
  String get visualizerTuningTitle => 'Abstimmung';

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
  String get commonOn => 'Ein';

  @override
  String get commonOff => 'Aus';

  @override
  String get settingsCastQuality => 'Cast-Visualizer-Qualität';

  @override
  String get settingsCastQualitySubtitle720 =>
      'Auflösung, mit der der Visualizer auf einen Fernseher gestreamt wird. 720p – am schonendsten für das Telefon.';

  @override
  String get settingsCastQualitySubtitle1080 =>
      'Auflösung, mit der der Visualizer auf einen Fernseher gestreamt wird. 1080p – scharf auf jedem Chromecast (Standard).';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Auflösung, mit der der Visualizer auf einen Fernseher gestreamt wird. 4K – benötigt einen 4K-Chromecast; deutlich höhere Last für das Telefon.';

  @override
  String get eqCasting =>
      'Der Equalizer passt das Audio auf diesem Gerät an, daher ist er beim Streamen nicht verfügbar. Trenne die Verbindung, um ihn zu verwenden.';

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
    return 'Keine Treffer für \"$query\"';
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
      'Speicherort nicht verfügbar – verbinde die SD-Karte erneut oder ändere den Speicherort dieses Servers unter \"Server bearbeiten\".';

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
  String get storageHelpAppLocal =>
      'Innerhalb der App gespeichert. Wird beim Deinstallieren oder Leeren der App gelöscht.';

  @override
  String get storageHelpPermanent =>
      'In einem von dir gewählten Ordner gespeichert. Übersteht das Deinstallieren der App. Erfordert \"Zugriff auf alle Dateien\".';

  @override
  String get storageHelpSdCard =>
      'In einem von dir gewählten Ordner auf der SD-Karte gespeichert. Kann nicht mehr verfügbar sein, wenn die Karte entfernt wird. Manche Geräte lassen Apps nicht auf SD-Karten schreiben – falls die Ordnerauswahl immer wieder fehlschlägt, verwende Dauerhaft oder App-intern.';

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
      'Dateien werden in ein Verzeichnis \'media/<folder>\' auf diesem Gerät heruntergeladen. Den Ordner eines früheren Servers erneut zu verwenden, behält dessen heruntergeladene Songs, wenn du einen verlorenen Server erneut hinzufügst.';

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
      'Gewähre \"Zugriff auf alle Dateien\", um Downloads dauerhaft zu speichern, und wähle dann den Modus erneut.';

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
  String get castVisualizer => 'Visualizer streamen';

  @override
  String get castVisualizerSubtitle =>
      'Den Visualizer auf den Fernseher streamen · nur Chromecast';

  @override
  String get visualizerNoKnobs => 'Dieser Shader bietet keine Regler.';
}
