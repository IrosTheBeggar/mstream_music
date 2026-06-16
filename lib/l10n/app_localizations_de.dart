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
      'Wiedergabeliste konnte nicht gespeichert werden — der Name ist möglicherweise bereits vergeben.';

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
  String get settingsStartupPageSubtitle =>
      'Die App in dieser Browser-Ansicht öffnen; Zurück kehrt zum Browser zurück.';

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

  @override
  String get nowPlaying => 'Aktuelle Wiedergabe';

  @override
  String get playerLayoutSmall => 'Klein';

  @override
  String get playerLayoutMedium => 'Mittel';

  @override
  String get playerLayoutLarge => 'Groß';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => 'Schmale Leiste — maximale Warteschlange';

  @override
  String get playerLayoutMediumDesc => 'Banner — ausgewogen (Standard)';

  @override
  String get playerLayoutLargeDesc => 'Kompakt — zentriertes Cover';

  @override
  String get playerLayoutXlDesc => 'Großformat — volles Cover';

  @override
  String get queueNothingToDownloadEmpty =>
      'Warteschlange ist leer — nichts herunterzuladen';

  @override
  String get queueNothingToDownloadSaved =>
      'Nichts herunterzuladen — Titel sind bereits gespeichert';

  @override
  String get settingsAccentColor => 'Akzentfarbe';

  @override
  String get settingsAccentColorSubtitle =>
      'Die Hervorhebungsfarbe, die in der gesamten App verwendet wird.';

  @override
  String get accentThemeDefault => 'Theme-Standard';

  @override
  String get accentCustom => 'Benutzerdefiniert';

  @override
  String get settingsResumeQueue => 'Warteschlange beim Start fortsetzen';

  @override
  String get settingsResumeQueueSubtitle =>
      'Speichert die Wiedergabeliste und deine Position und stellt sie beim erneuten Öffnen der App wieder her.';

  @override
  String get settingsRatingHalf => 'Halbe-Sterne-Bewertungen';

  @override
  String get settingsRatingHalfSubtitle =>
      'Songs in Halbstern-Schritten bewerten (Stern lange drücken).';

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
  String get storageAppExternal => 'App extern';

  @override
  String get selfSignedTitle => 'Selbstsigniertes Zertifikat zulassen';

  @override
  String get selfSignedSubtitle =>
      'Überspringt die TLS-Prüfung für diesen Server. Nur in einem vertrauenswürdigen Netzwerk aktivieren.';

  @override
  String get importedShadersTitle => 'Importierte Shader';

  @override
  String get importedShadersSettingsSubtitle =>
      'Füge deine eigenen .glsl-Dateien zur Rotation der Shader-Engine hinzu.';

  @override
  String get importedShadersRescan => 'Ordner neu scannen';

  @override
  String get importedShadersDropHint =>
      'Lege .glsl-Dateien in diesen Ordner und scanne dann neu:';

  @override
  String get importedShadersCopyPath => 'Pfad kopieren';

  @override
  String get importedShadersReachableHint =>
      'Über USB oder einen Dateimanager erreichbar (unter Android/data). Importierte Shader werden Teil der Rotation, wenn die Shader-Engine aktiv ist.';

  @override
  String get importedShadersRemove => 'Entfernen';

  @override
  String get importedShadersEmptyTitle => 'Noch keine Shader im Ordner';

  @override
  String get importedShadersEmptyBody =>
      'Kopiere .glsl-Dateien im Shadertoy-Stil in den Ordner oben und tippe dann auf Neu scannen.';

  @override
  String get importedShadersInvalid =>
      'Ist möglicherweise kein gültiger Shader — kein mainImage/main-Einstiegspunkt.';

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
  String get adminLogOut => 'Abmelden';

  @override
  String get adminConfigGroup => 'Konfiguration';

  @override
  String get adminDirectories => 'Verzeichnisse';

  @override
  String get adminUsers => 'Benutzer';

  @override
  String get adminDLNA => 'DLNA';

  @override
  String get adminSubsonicAPI => 'Subsonic-API';

  @override
  String get adminMP3Player => 'MP3-Player';

  @override
  String get adminTorrent => 'Torrent';

  @override
  String get adminFederation => 'Föderation';

  @override
  String get adminServerGroup => 'Server';

  @override
  String get adminAbout => 'Über';

  @override
  String get adminSettings => 'Einstellungen';

  @override
  String get adminDatabase => 'Datenbank';

  @override
  String get adminBackups => 'Backups';

  @override
  String get adminTranscoding => 'Transcoding';

  @override
  String get adminLogs => 'Protokolle';

  @override
  String get adminAccess => 'Admin-Zugriff';

  @override
  String adminAppBarTitle(String label) {
    return 'mStream Admin · $label';
  }

  @override
  String get adminPanelTitle => 'mStream Admin';

  @override
  String get adminLoginErrorRequired =>
      'Server und Benutzername sind erforderlich';

  @override
  String get adminLoginServerURL => 'Server-URL';

  @override
  String get adminLoginUsername => 'Benutzername';

  @override
  String get adminLoginPassword => 'Passwort';

  @override
  String get adminLoginSignIn => 'Anmelden';

  @override
  String get adminRetry => 'Wiederholen';

  @override
  String get adminSaved => 'Gespeichert';

  @override
  String get adminSave => 'Speichern';

  @override
  String get adminClose => 'Schließen';

  @override
  String get adminPanelMenuItem => 'Admin-Panel';

  @override
  String get adminNoLibrariesYetTitle => 'Noch keine Bibliotheken';

  @override
  String get adminAddDirectoryHint =>
      'Füge ein Verzeichnis hinzu, um Musik in die Bibliothek einzulesen.';

  @override
  String get adminAddDirectoryButton => 'Verzeichnis hinzufügen';

  @override
  String adminRemoveDirectoryTitle(String name) {
    return '$name entfernen?';
  }

  @override
  String get adminRemoveDirectoryWarning =>
      'Dadurch werden die Bibliothek und ihre eingelesenen Titel aus der Datenbank entfernt. Dateien auf dem Datenträger bleiben unangetastet.';

  @override
  String get adminCancel => 'Abbrechen';

  @override
  String get adminRemove => 'Entfernen';

  @override
  String get adminLibraryRemovedToast => 'Bibliothek entfernt';

  @override
  String get adminDirectoryPathLabel => 'Pfad';

  @override
  String get adminDirectoryTypeLabel => 'Typ';

  @override
  String get adminFollowSymlinksTitle => 'Symlinks folgen';

  @override
  String get adminFollowSymlinksSubtitle => 'Wird beim nächsten Scan wirksam';

  @override
  String get adminPickFolderAndNameError =>
      'Ordner auswählen und Namen eingeben';

  @override
  String get adminDirectoryAddedToast =>
      'Verzeichnis hinzugefügt – Scan gestartet';

  @override
  String get adminAddDirectoryDialogTitle => 'Verzeichnis hinzufügen';

  @override
  String get adminChooseFolderButton => 'Ordner auf dem Server wählen…';

  @override
  String get adminLibraryNameLabel => 'Bibliotheksname (vpath)';

  @override
  String get adminLibraryNameHelper => 'Buchstaben, Zahlen und Bindestriche';

  @override
  String get adminGrantAllUsersAccessTitle =>
      'Allen Benutzern Zugriff gewähren';

  @override
  String get adminAudiobookLibraryTitle => 'Hörbuch-Bibliothek';

  @override
  String get adminAdd => 'Hinzufügen';

  @override
  String get adminChooseFolderTitle => 'Ordner wählen';

  @override
  String get adminSelectFolderButton => 'Diesen Ordner wählen';

  @override
  String get adminNoUsersTitle => 'Keine Benutzer';

  @override
  String get adminNoUsersSubtitle =>
      'Ohne Benutzer läuft der Server im offenen/öffentlichen Modus. Füge einen hinzu, um eine Anmeldung zu erfordern.';

  @override
  String get adminAddUserButton => 'Benutzer hinzufügen';

  @override
  String get adminLibraryAccessDialogTitle => 'Bibliothekszugriff';

  @override
  String get adminLibraryAccessUpdatedToast =>
      'Bibliothekszugriff aktualisiert';

  @override
  String get adminSetSubsonicPasswordTitle => 'Subsonic-Passwort festlegen';

  @override
  String get adminSetPasswordTitle => 'Passwort festlegen';

  @override
  String get adminPasswordUpdatedToast => 'Passwort aktualisiert';

  @override
  String adminDeleteUserTitle(String username) {
    return '$username löschen?';
  }

  @override
  String get adminDeleteUserWarning =>
      'Dadurch wird das Benutzerkonto dauerhaft entfernt.';

  @override
  String get adminDelete => 'Löschen';

  @override
  String get adminUserDeletedToast => 'Benutzer gelöscht';

  @override
  String get adminStatusPillLabel => 'admin';

  @override
  String get adminDeleteUserMenuItem => 'Benutzer löschen';

  @override
  String get adminNoLibraryAccessLabel => 'Kein Bibliothekszugriff';

  @override
  String get adminLibrariesButton => 'Bibliotheken';

  @override
  String get adminAdminToggleTitle => 'Admin';

  @override
  String get adminMakeDirsToggleTitle => 'Ordner erstellen';

  @override
  String get adminUploadToggleTitle => 'Hochladen';

  @override
  String get adminModifyFilesToggleTitle => 'Dateien ändern';

  @override
  String get adminServerAudioToggleTitle => 'Server-Audio';

  @override
  String get adminAddUserDialogTitle => 'Benutzer hinzufügen';

  @override
  String get adminUsername => 'Benutzername';

  @override
  String get adminPassword => 'Passwort';

  @override
  String get adminSubsonicPasswordLabel => 'Subsonic-Passwort (optional)';

  @override
  String get adminLibraryAccessHeader => 'Bibliothekszugriff';

  @override
  String get adminUsernamePasswordRequiredError =>
      'Benutzername und Passwort sind erforderlich';

  @override
  String get adminUserCreatedToast => 'Benutzer erstellt';

  @override
  String get adminAdministratorToggleTitle => 'Administrator';

  @override
  String get adminAllowMakeDirectoriesTitle => 'Ordner erstellen erlauben';

  @override
  String get adminAllowUploadTitle => 'Hochladen erlauben';

  @override
  String get adminAllowServerAudioTitle => 'Server-Audio erlauben';

  @override
  String get adminCreate => 'Erstellen';

  @override
  String get adminNoLibrariesConfigured => 'Keine Bibliotheken konfiguriert.';

  @override
  String get adminNewPasswordLabel => 'Neues Passwort';

  @override
  String get adminLibraryTitle => 'Bibliothek';

  @override
  String get adminTracksInDatabase => 'Titel in der Datenbank';

  @override
  String get adminScanAllButton => 'Alle scannen';

  @override
  String get adminScanStarted => 'Scan gestartet';

  @override
  String get adminForceRescan => 'Erneuten Scan erzwingen';

  @override
  String get adminFullRescanStarted => 'Vollständiger Scan gestartet';

  @override
  String get adminCompressImages => 'Bilder komprimieren';

  @override
  String get adminImageCompressionStarted => 'Bildkomprimierung gestartet';

  @override
  String get adminScanOptions => 'Scan-Optionen';

  @override
  String get adminScanInterval => 'Scan-Intervall (Stunden, 0 = aus)';

  @override
  String get adminBootScanDelay => 'Verzögerung des Boot-Scans (Sekunden)';

  @override
  String get adminScanCommitInterval => 'Scan-Commit-Intervall (1–1000)';

  @override
  String get adminScanThreads => 'Scan-Threads (0 = automatisch)';

  @override
  String get adminSkipImageExtraction => 'Bildextraktion überspringen';

  @override
  String get adminCompressEmbeddedImages => 'Eingebettete Bilder komprimieren';

  @override
  String get adminGenerateWaveforms => 'Wellenformen nach dem Scan erzeugen';

  @override
  String get adminAnalyzeBpm =>
      'BPM/Tonart analysieren (veraltet, ohne Funktion)';

  @override
  String get adminAutomaticAlbumArt => 'Automatisches Album-Cover';

  @override
  String get adminDownloadMissingAlbumArt =>
      'Fehlende Album-Cover herunterladen';

  @override
  String get adminTargetLabel => 'Ziel';

  @override
  String get adminMissingOnly => 'Nur fehlende';

  @override
  String get adminAllAlbums => 'Alle Alben';

  @override
  String get adminAlbumsPerRun => 'Alben pro Durchlauf (1–10000)';

  @override
  String get adminAutoDownloadedArtWriteFolder =>
      'Auto-heruntergeladenes Cover → in Ordner schreiben';

  @override
  String get adminManualArtWriteFolder =>
      'Manuell gesetztes Cover → in Ordner schreiben';

  @override
  String get adminManualArtEmbedTag =>
      'Manuell gesetztes Cover → in Datei-Tag einbetten';

  @override
  String get adminArtServices => 'Cover-Dienste';

  @override
  String get adminArtServicesUpdated => 'Cover-Dienste aktualisiert';

  @override
  String get adminSharedPlaylists => 'Geteilte Wiedergabelisten';

  @override
  String get adminDeleteExpired => 'Abgelaufene löschen';

  @override
  String get adminExpiredSharesDeleted => 'Abgelaufene Freigaben gelöscht';

  @override
  String get adminDeleteNeverExpiring => 'Nie ablaufende löschen';

  @override
  String get adminEternalSharesDeleted => 'Ewige Freigaben gelöscht';

  @override
  String get adminNoSharedPlaylists => 'Keine geteilten Wiedergabelisten';

  @override
  String adminSharedPlaylistSubtitle(String user, int count, String expiry) {
    return 'von $user · $count Titel · läuft ab $expiry';
  }

  @override
  String get adminShareDeleted => 'Freigabe gelöscht';

  @override
  String get adminNetwork => 'Netzwerk';

  @override
  String get adminNetworkSubtitle =>
      'Eine Änderung bewirkt einen Soft-Neustart des Servers.';

  @override
  String get adminBindAddress => 'Bind-Adresse';

  @override
  String get adminPort => 'Port';

  @override
  String get adminTrustProxyHeaders => 'Proxy-Header vertrauen';

  @override
  String get adminTrustProxyHeadersSubtitle =>
      'Aktivieren, wenn hinter einem Reverse-Proxy (X-Forwarded-*)';

  @override
  String get adminPermissions => 'Berechtigungen';

  @override
  String get adminAllowUploads => 'Uploads erlauben';

  @override
  String get adminAllowMakingDirectories => 'Ordnererstellung erlauben';

  @override
  String get adminAllowModifyingFiles => 'Dateiänderung erlauben';

  @override
  String get adminMaxRequestSize => 'Maximale Anfragegröße';

  @override
  String get adminMaxRequestSizeHelper => 'z. B. 50MB oder 512KB';

  @override
  String get adminHttpUi => 'HTTP & UI';

  @override
  String get adminResponseCompression => 'Antwortkomprimierung';

  @override
  String get adminCompressionNone => 'Keine';

  @override
  String get adminCompressionGzip => 'gzip';

  @override
  String get adminCompressionBrotli => 'brotli';

  @override
  String get adminWebUi => 'Web-UI';

  @override
  String get adminUiDefault => 'Standard';

  @override
  String get adminUiVelvet => 'Velvet';

  @override
  String get adminUiSubsonic => 'Subsonic';

  @override
  String get adminDatabaseTuning => 'Datenbank-Tuning';

  @override
  String get adminSqliteSynchronous => 'SQLite synchronous';

  @override
  String get adminSyncFull => 'FULL (safest)';

  @override
  String get adminSyncNormal => 'NORMAL (faster)';

  @override
  String get adminCacheSize => 'Cache-Größe (MB, 1–2048)';

  @override
  String get adminLogging => 'Protokollierung';

  @override
  String get adminWriteLogsToDisk => 'Protokolle auf Datenträger schreiben';

  @override
  String get adminLogBufferSize =>
      'Protokollpuffergröße (0–10000, 0 = deaktiviert)';

  @override
  String get adminServerAudio => 'Server-Audio';

  @override
  String get adminAutoBootServerAudio =>
      'Server-Audio automatisch starten (Rust-Player)';

  @override
  String get adminRustPlayerPort => 'Rust-Player-Port';

  @override
  String get adminActiveBackend => 'Aktives Backend';

  @override
  String get adminPlayer => 'Player';

  @override
  String get adminDetectedCliPlayers => 'Erkannte CLI-Player';

  @override
  String get adminNone => 'keine';

  @override
  String get adminReDetectPlayers => 'Player neu erkennen';

  @override
  String get adminReProbedCliPlayers => 'CLI-Player neu geprüft';

  @override
  String get adminSslHttps => 'SSL / HTTPS';

  @override
  String get adminEnabled => 'Aktiviert';

  @override
  String get adminDisabled => 'Deaktiviert';

  @override
  String get adminReplaceCertificate => 'Zertifikat ersetzen';

  @override
  String get adminSetCertificate => 'Zertifikat festlegen';

  @override
  String get adminSetSslCertificateDialog => 'SSL-Zertifikat festlegen';

  @override
  String get adminCertificatePath => 'Zertifikatspfad';

  @override
  String get adminKeyPath => 'Schlüsselpfad';

  @override
  String get adminSslConfigured => 'SSL konfiguriert – Neustart zum Anwenden';

  @override
  String get adminRemoveSsl => 'SSL entfernen';

  @override
  String get adminSslRemoved => 'SSL entfernt';

  @override
  String get adminSecurity => 'Sicherheit';

  @override
  String get adminJwtSecretLast4 => 'JWT-Secret (letzte 4)';

  @override
  String get adminRegenerateSecret => 'Secret neu erzeugen';

  @override
  String get adminSecretRegenerated =>
      'Secret neu erzeugt – alle Sitzungen ungültig';

  @override
  String get adminRegenerateJwtSecretDialog => 'JWT-Secret neu erzeugen?';

  @override
  String get adminRegenerateJwtSecretDialogBody =>
      'Dadurch wird jede bestehende Anmeldung (einschließlich dieser) ungültig. Alle müssen sich erneut anmelden.';

  @override
  String get adminRegenerateButton => 'Neu erzeugen';

  @override
  String get adminAllNetworks => 'Alle Netzwerke';

  @override
  String get adminLocalhostOnly => 'Nur Localhost';

  @override
  String get adminIpWhitelist => 'IP-Whitelist';

  @override
  String get adminNoneLockAdmin => 'Keine (Admin sperren)';

  @override
  String get adminNetworkAccess => 'Netzwerkzugriff';

  @override
  String get adminNetworkAccessSubtitle =>
      'Einschränken, welche Netzwerke die Admin-API erreichen dürfen.';

  @override
  String get adminMode => 'Modus';

  @override
  String get adminWhitelistedIps => 'Whitelist-IPs / -CIDRs';

  @override
  String get adminNoneYet => 'Noch keine';

  @override
  String get adminAddIpOrCidr => 'IP oder CIDR hinzufügen';

  @override
  String get adminCidrExample => '192.168.1.0/24';

  @override
  String get adminApply => 'Anwenden';

  @override
  String get adminDangerZone => 'Gefahrenzone';

  @override
  String get adminLockAdminApi => 'Admin-API sperren';

  @override
  String get adminLockAdminApiSubtitle =>
      'Die gesamte Admin-API deaktivieren. Von hier aus nicht rückgängig zu machen.';

  @override
  String get adminLockButton => 'Sperren';

  @override
  String get adminLockAdminApiDialog => 'Admin-API sperren?';

  @override
  String get adminLockAdminApiDialogBody =>
      'Dies deaktiviert die gesamte /admin-API für alle. Du kannst es über dieses Panel nicht rückgängig machen – dafür musst du die Server-Konfigurationsdatei bearbeiten und neu starten. Fortfahren?';

  @override
  String get adminAdminApiLocked => 'Admin-API gesperrt';

  @override
  String get adminAccessUpdated => 'Admin-Zugriff aktualisiert';

  @override
  String get adminTranscodingFFmpegTitle => 'FFmpeg';

  @override
  String get adminFFmpegStatusReady => 'Bereit';

  @override
  String get adminFFmpegStatusNotDownloaded => 'Nicht heruntergeladen';

  @override
  String get adminFFmpegDownloadButton =>
      'ffmpeg herunterladen / aktualisieren';

  @override
  String get adminFFmpegDownloadedToast => 'ffmpeg heruntergeladen';

  @override
  String get adminFFmpegAutoUpdateTitle => 'ffmpeg automatisch aktualisieren';

  @override
  String get adminFFmpegAutoUpdateSubtitle =>
      'Das gebündelte ffmpeg automatisch aktuell halten';

  @override
  String get adminTranscodingDefaultsTitle => 'Standardwerte';

  @override
  String get adminDefaultCodecLabel => 'Standard-Codec';

  @override
  String get adminDefaultBitrateLabel => 'Standard-Bitrate';

  @override
  String get adminLogsResumeButton => 'Fortsetzen';

  @override
  String get adminLogsPauseButton => 'Pausieren';

  @override
  String get adminClear => 'Leeren';

  @override
  String get adminLogsAutoScrollTitle => 'Automatisch scrollen';

  @override
  String adminLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen',
      one: '1 Zeile',
    );
    return '$_temp0';
  }

  @override
  String get adminLogsDownloadZipButton => 'Zip herunterladen';

  @override
  String get adminLogsNoEntriesHint => 'Noch keine Protokolleinträge';

  @override
  String get adminDlnaModeDisabled => 'Deaktiviert';

  @override
  String get adminSamePortAsHttp => 'Gleicher Port wie HTTP';

  @override
  String get adminSeparatePort => 'Separater Port';

  @override
  String get adminDlnaBrowseFlat => 'Flach (alle Titel)';

  @override
  String get adminDlnaBrowseDirectories => 'Verzeichnisse';

  @override
  String get adminDlnaBrowseArtist => 'Nach Interpret';

  @override
  String get adminDlnaBrowseAlbum => 'Nach Album';

  @override
  String get adminDlnaBrowseGenre => 'Nach Genre';

  @override
  String get adminDlnaServerTitle => 'Server';

  @override
  String get adminDlnaIdentityTitle => 'Identität';

  @override
  String get adminDlnaFriendlyNameLabel => 'Anzeigename';

  @override
  String get adminDlnaDeviceUuidLabel => 'Geräte-UUID';

  @override
  String get adminDlnaDeviceUuidHelper => 'Kanonische GUID';

  @override
  String get adminDlnaBrowseLayoutTitle => 'Durchsuch-Layout';

  @override
  String get adminDlnaStructureLabel => 'Struktur';

  @override
  String get adminMdnsLocalNetworkDiscoveryTitle => 'Lokale Netzwerkerkennung';

  @override
  String get adminMdnsLocalNetworkDiscoverySubtitle =>
      'Bewirbt diesen Server als _mstream._tcp mDNS-Dienst. Veröffentlicht nur Metadaten – legt keine Bibliotheksdaten oder neue Routen offen.';

  @override
  String get adminMdnsEnableAdvertisingTitle => 'Bewerbung aktivieren';

  @override
  String get adminMdnsFriendlyNameLabel => 'Anzeigename';

  @override
  String get adminMdnsFriendlyNameHelper =>
      'Leer = aus Hostnamen ableiten (max. 63 Bytes)';

  @override
  String get adminMdnsInstanceIdLabel => 'Instanz-ID';

  @override
  String get adminSubsonicApiTitle => 'Subsonic-API';

  @override
  String get adminTestConnection => 'Verbindung testen';

  @override
  String adminSubsonicTestSuccess(String version, String latency) {
    return 'OK · $version · ${latency}ms';
  }

  @override
  String adminSubsonicTestFailed(String reason) {
    return 'Fehlgeschlagen: $reason';
  }

  @override
  String get adminStatus => 'Status';

  @override
  String get adminMethodsImplemented => 'Implementierte Methoden';

  @override
  String get adminFullStub => 'Vollständig / Stub';

  @override
  String get adminNowPlaying => 'Aktuelle Wiedergabe';

  @override
  String get adminNobody => 'niemand';

  @override
  String get adminLyricsLrclib => 'Liedtexte (LRCLib)';

  @override
  String get adminLrclibFallback => 'LRCLib-Fallback';

  @override
  String get adminWriteLrcSidecarFiles => '.lrc-Begleitdateien schreiben';

  @override
  String get adminCache => 'Cache';

  @override
  String get adminPurgeCache => 'Cache leeren';

  @override
  String get adminLyricsCachePurged => 'Liedtext-Cache geleert';

  @override
  String get adminRetryFailed => 'Fehlgeschlagene wiederholen';

  @override
  String get adminTransientLyricsEntriesCleared =>
      'Temporäre Liedtext-Einträge gelöscht';

  @override
  String get adminJukebox => 'Jukebox';

  @override
  String get adminAvailable => 'Verfügbar';

  @override
  String get adminUnavailable => 'Nicht verfügbar';

  @override
  String get adminState => 'Status';

  @override
  String get adminPlaying => 'spielt';

  @override
  String get adminPaused => 'pausiert';

  @override
  String get adminIdle => 'inaktiv';

  @override
  String get adminCurrent => 'Aktuell';

  @override
  String get adminQueue => 'Warteschlange';

  @override
  String adminQueueTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String get adminVolume => 'Lautstärke';

  @override
  String adminVolumePercent(int percent) {
    return '$percent%';
  }

  @override
  String get adminTokenAuthFailures => 'Token-Auth-Fehler';

  @override
  String get adminTokenAuthFailuresSubtitle =>
      'Clients, die ohne Subsonic-Passwort auf Token-Auth zurückfallen.';

  @override
  String get adminNoRecentFailures => 'Keine kürzlichen Fehler';

  @override
  String get adminCleared => 'Geleert';

  @override
  String get adminMintApiKey => 'API-Schlüssel erzeugen';

  @override
  String get adminMintApiKeySubtitle =>
      'Einen Subsonic-apiKey für einen Benutzer erzeugen (nur einmal angezeigt).';

  @override
  String get adminKeyNameLabel => 'Schlüsselname / Bezeichnung';

  @override
  String get adminMintKey => 'Schlüssel erzeugen';

  @override
  String get adminUsernameAndNameRequired =>
      'Benutzername und Name erforderlich';

  @override
  String get adminTorrentClient => 'Client';

  @override
  String get adminActiveClient => 'Aktiver Client';

  @override
  String get adminTransmission => 'Transmission';

  @override
  String get adminQbittorrent => 'qBittorrent';

  @override
  String get adminDeluge => 'Deluge';

  @override
  String get adminEnabledFor => 'Aktiviert für';

  @override
  String get adminAllUsers => 'Alle Benutzer';

  @override
  String get adminWhitelistedUsers => 'Whitelist-Benutzer';

  @override
  String get adminHost => 'Host';

  @override
  String get adminPasswordUnchangedIfBlank => 'unverändert, wenn leer';

  @override
  String get adminRpcPath => 'RPC-Pfad';

  @override
  String get adminUseHttps => 'HTTPS verwenden';

  @override
  String get adminTest => 'Testen';

  @override
  String adminReachable(String version) {
    return 'Erreichbar$version';
  }

  @override
  String adminConnectionFailed(String error) {
    return 'Fehlgeschlagen: $error';
  }

  @override
  String get adminConnectAndSave => 'Verbinden & speichern';

  @override
  String adminSaveFailed(String error) {
    return 'Fehlgeschlagen: $error';
  }

  @override
  String get adminConnectedAndSaved => 'Verbunden & gespeichert';

  @override
  String get adminDisconnect => 'Trennen';

  @override
  String get adminDisconnected => 'Getrennt';

  @override
  String get adminConfigured => 'Konfiguriert';

  @override
  String get adminNotConfigured => 'Nicht konfiguriert';

  @override
  String get adminTorrents => 'Torrents';

  @override
  String get adminConnected => 'Verbunden';

  @override
  String get adminNoTorrents => 'Keine Torrents';

  @override
  String get adminMstream => 'mStream';

  @override
  String get adminTorrentRemoved => 'Torrent entfernt';

  @override
  String get adminLibraryDaemonPathMapping =>
      'Bibliothek → Daemon-Pfadzuordnung';

  @override
  String get adminLibraryDaemonPathMappingSubtitle =>
      'Ordnet jede Bibliothek ihrem Pfad zu, wie der Torrent-Daemon ihn sieht.';

  @override
  String get adminAutoDetectAll => 'Alle automatisch erkennen';

  @override
  String get adminAutoDetectionComplete =>
      'Automatische Erkennung abgeschlossen';

  @override
  String get adminVerified => 'verifiziert';

  @override
  String get adminUnverified => 'nicht verifiziert';

  @override
  String get adminSetManually => 'Manuell festlegen';

  @override
  String adminDaemonPathFor(String name) {
    return 'Daemon-Pfad für \"$name\"';
  }

  @override
  String get adminPathOnDaemonHost => 'Pfad auf dem Daemon-Host';

  @override
  String get adminVerifyAndSave => 'Verifizieren & speichern';

  @override
  String get adminVpathVerified => 'Verifiziert';

  @override
  String get adminVpathSavedUnverified => 'Gespeichert (nicht verifiziert)';

  @override
  String get adminDownloadPathTemplates => 'Download-Pfadvorlagen';

  @override
  String adminPathTemplateVars(String vars) {
    return 'Variablen: $vars';
  }

  @override
  String get adminNoLibraries => 'Keine Bibliotheken';

  @override
  String adminSuggestedTemplate(String template) {
    return 'Vorschlag: $template';
  }

  @override
  String get adminTemplateSaved => 'Vorlage gespeichert';

  @override
  String get adminNoBackupDestinations => 'Keine Backup-Ziele';

  @override
  String get adminBackupDestinationInfo =>
      'Füge ein Ziel hinzu, um eine Bibliothek in einen anderen Ordner zu spiegeln.';

  @override
  String get adminAddDestination => 'Ziel hinzufügen';

  @override
  String get adminAddLibraryFirst => 'Zuerst eine Bibliothek hinzufügen';

  @override
  String get adminBackupQueue => 'Backup-Warteschlange';

  @override
  String adminTasksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben in der Warteschlange',
      one: '1 Aufgabe in der Warteschlange',
    );
    return '$_temp0';
  }

  @override
  String adminBackingUp(String library) {
    return 'Backup läuft: $library';
  }

  @override
  String get adminRunning => 'läuft';

  @override
  String adminBackupStats(int done, String total, String stats) {
    return '$done Dateien$total$stats';
  }

  @override
  String get adminBackupDisabled => 'deaktiviert';

  @override
  String get adminDestination => 'Ziel';

  @override
  String get adminTrigger => 'Auslöser';

  @override
  String adminDailyTriggerTime(String trigger, String hour) {
    return '$trigger @ $hour:00';
  }

  @override
  String get adminRetention => 'Aufbewahrung';

  @override
  String adminRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get adminLastRun => 'Letzter Lauf';

  @override
  String adminLastRunStatus(String status, int files) {
    return '$status · $files kopiert';
  }

  @override
  String get adminRunNow => 'Jetzt ausführen';

  @override
  String get adminBackupQueued => 'Backup eingereiht';

  @override
  String get adminAlreadyRunningSkipped => 'Läuft bereits – übersprungen';

  @override
  String get adminHistory => 'Verlauf';

  @override
  String get adminEdit => 'Bearbeiten';

  @override
  String get adminDestinationDeleted => 'Ziel gelöscht';

  @override
  String get adminBackupHistory => 'Backup-Verlauf';

  @override
  String get adminNoHistoryYet => 'Noch kein Verlauf';

  @override
  String get adminEditDestination => 'Ziel bearbeiten';

  @override
  String get adminAddBackupDestination => 'Backup-Ziel hinzufügen';

  @override
  String get adminDestinationPath => 'Zielpfad';

  @override
  String get adminBrowseServer => 'Server durchsuchen';

  @override
  String get adminCheckPath => 'Pfad prüfen';

  @override
  String get adminTriggerField => 'Auslöser';

  @override
  String get adminAfterEachScan => 'Nach jedem Scan';

  @override
  String get adminDaily => 'Täglich';

  @override
  String get adminManualOnly => 'Nur manuell';

  @override
  String get adminRunAtHour => 'Zur Stunde ausführen: ';

  @override
  String get adminRetentionFieldLabel =>
      'Aufbewahrung (Tage, 0 = alle behalten)';

  @override
  String get adminEnabledToggle => 'Aktiviert';

  @override
  String get adminDestinationUpdated => 'Ziel aktualisiert';

  @override
  String get adminDestinationCreated => 'Ziel erstellt';

  @override
  String get adminPickLibrary => 'Eine Bibliothek auswählen';

  @override
  String get adminPickDestinationPath => 'Einen Zielpfad auswählen';

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
  String get adminCompression => 'Komprimierung';

  @override
  String get adminTrustProxy => 'Proxy vertrauen';

  @override
  String get adminYes => 'Ja';

  @override
  String get adminNo => 'Nein';

  @override
  String get adminSecretLast4 => 'Secret (letzte 4)';

  @override
  String get adminUploads => 'Uploads';

  @override
  String get adminMakeDirs => 'Ordner erstellen';

  @override
  String get adminFileModify => 'Dateiänderung';

  @override
  String get adminSynchronous => 'Synchronous';

  @override
  String get adminCacheSizeLabel => 'Cache-Größe';

  @override
  String adminCacheSizeMb(int size) {
    return '$size MB';
  }

  @override
  String get adminFederationUnavailable => 'Nicht verfügbar';

  @override
  String get adminFederationDescription =>
      'Die Föderation wird rund um das neue lokale Backup-Konzept neu aufgebaut und ist derzeit auf dem Server nicht verfügbar. Der Endpunkt bleibt eingebunden, damit ältere Clients einen klaren Status statt eines 404 erhalten.';

  @override
  String get adminCheckStatus => 'Status prüfen';

  @override
  String get adminAllowed => 'Erlaubt';

  @override
  String get adminBackupEnabled => 'aktiviert';

  @override
  String get adminNotAvailable => 'Nicht verfügbar';

  @override
  String get adminNotMapped => 'nicht zugeordnet';

  @override
  String get adminExpiryNever => 'nie';

  @override
  String get adminUnknownUser => 'unbekannt';
}
