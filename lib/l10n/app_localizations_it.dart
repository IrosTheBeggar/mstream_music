// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get mainRemove => 'Rimuovi';

  @override
  String get playlistActionFailed =>
      'Impossibile salvare la playlist: il nome potrebbe essere già in uso.';

  @override
  String get queueAddNext => 'Aggiungi dopo';

  @override
  String get queuePlayNow => 'Riproduci ora';

  @override
  String get queueAddToEnd => 'Aggiungi alla fine della coda';

  @override
  String get shuffle => 'Casuale';

  @override
  String get variousArtists => 'Artisti vari';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get languageSystemDefault => 'Predefinita di sistema';

  @override
  String get settingsLanguageSubtitle =>
      'La lingua di visualizzazione dell’app. \"Predefinita di sistema\" segue quella del dispositivo.';

  @override
  String couldNotOpen(String url) {
    return 'Impossibile aprire $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
      zero: 'Nessun brano',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Reimposta';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Scuro';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get tapAddToQueue => 'Aggiungi alla coda';

  @override
  String get tapPlayFromHere => 'Riproduci da qui';

  @override
  String get tapAppendAndJump => 'Aggiungi e riproduci';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'Shader';

  @override
  String get visualizerSourceSynthesized => 'Sintetizzato';

  @override
  String get visualizerSourceReal => 'Audio reale';

  @override
  String get downloadsTitle => 'Download';

  @override
  String downloadProgress(String progress) {
    return 'avanzamento: $progress%';
  }

  @override
  String get songInfoTitle => 'Informazioni brano';

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsEmpty => 'No lyrics found for this song';

  @override
  String get lyricsError => 'Couldn\'t load lyrics';

  @override
  String get lyricsRetry => 'Retry';

  @override
  String get eqTitle => 'Equalizzatore';

  @override
  String get eqOnlyAndroid => 'L’equalizzatore è disponibile solo su Android.';

  @override
  String get eqNeedsPlayback =>
      'Avvia un brano per configurare l’equalizzatore.\n\nL’equalizzatore nativo di Android si inizializza con la sessione audio, quindi la riproduzione deve essere attiva prima di poter leggere la disposizione delle bande.';

  @override
  String eqInitFailed(String error) {
    return 'Impossibile inizializzare l’equalizzatore:\n$error';
  }

  @override
  String get eqNoBands =>
      'Il driver audio di questo dispositivo non segnala bande di equalizzazione.';

  @override
  String get eqDisabledHint => 'Attiva l\'equalizzatore per regolare le bande.';

  @override
  String get eqEnabledOn => 'Attivo — guadagni applicati alla riproduzione';

  @override
  String get eqEnabledOff => 'Disattivo — modalità bypass';

  @override
  String get cancel => 'Annulla';

  @override
  String get continueLabel => 'Continua';

  @override
  String get openSettings => 'Apri impostazioni';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsSectionAppearance => 'Aspetto';

  @override
  String get settingsSectionPlayback => 'Riproduzione';

  @override
  String get settingsSectionBrowse => 'Esplora';

  @override
  String get settingsSectionAbout => 'Informazioni';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSubtitleVelvet =>
      'Blu navy e viola — il tema scuro distintivo.';

  @override
  String get themeSubtitleDark => 'Scuro neutro con dettagli ambra.';

  @override
  String get themeSubtitleLight =>
      'Corpo chiaro con barra dell’app scura e dettagli ambra — corrisponde al vecchio tema.';

  @override
  String get settingsTranscode => 'Transcodifica audio';

  @override
  String get settingsTranscodeSubtitle =>
      'Trasmetti una copia transcodificata dal server (file più piccoli, avvio leggermente più lento). Disattivato riproduce i file originali.';

  @override
  String get transcodeTitle => 'Transcodifica';

  @override
  String get transcodeCodec => 'Codec';

  @override
  String get transcodeBitrate => 'Bitrate';

  @override
  String get transcodeAuto => 'Predefinito del server';

  @override
  String get transcodeUnavailable =>
      'Questo server non ha la transcodifica abilitata: i suoi brani vengono trasmessi in qualità originale.';

  @override
  String get transcodeReloadQueue => 'Applica alla coda attuale';

  @override
  String get transcodeReloadQueueSubtitle =>
      'Quando cambi le impostazioni di transcodifica — selezionato: ricarica subito l\'intera coda (il brano in riproduzione si ricarica brevemente); deselezionato: cambiano solo i brani successivi, quello attuale termina invariato.';

  @override
  String get settingsTapBehavior => 'Quando tocchi un brano';

  @override
  String get settingsStartupPage => 'Schermata iniziale';

  @override
  String get settingsStartupPageSubtitle =>
      'Apri l’app su questa vista del browser; Indietro torna al browser.';

  @override
  String get tapSubtitleAddToQueue =>
      'Toccando un brano lo aggiungi alla coda. Se la coda è vuota, la riproduzione si avvia automaticamente.';

  @override
  String get tapSubtitlePlayFromHere =>
      'Toccando un brano sostituisci la coda con i brani della vista corrente e la riproduzione inizia dal brano toccato.';

  @override
  String get tapSubtitleAppendAndJump =>
      'Toccando un brano lo aggiungi alla coda e la riproduzione passa a esso, interrompendo ciò che era in riproduzione.';

  @override
  String get settingsEqSubtitle =>
      'Regola bassi, medi e alti. Solo su Android.';

  @override
  String get settingsVisualizerEngine => 'Motore del visualizzatore';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'Preset di Milkdrop tramite projectM (predefinito). Effetti più ricchi, più impegnativi per la GPU.';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Shader di frammento in stile Shadertoy. Più leggeri e modulari — inserisci file .glsl in assets/shaders/ per ampliare il catalogo.';

  @override
  String get settingsVisualizerSource => 'Sorgente audio del visualizzatore';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'Predefinito. Il visualizzatore reagisce solo alla temporizzazione della riproduzione — non richiede il permesso del microfono.';

  @override
  String get visualizerSourceSubtitleReal =>
      'Il visualizzatore reagisce all’uscita audio reale. Richiede il permesso RECORD_AUDIO su Android.';

  @override
  String get settingsAlbumGrid => 'Vista a griglia degli album';

  @override
  String get settingsAlbumGridSubtitle =>
      'Mostra gli album come una griglia di schede con la copertina invece di un semplice elenco.';

  @override
  String get settingsFileMetadata =>
      'Leggi i metadati dei brani nell’esplora file';

  @override
  String get settingsFileMetadataSubtitle =>
      'Recupera titolo, artista e copertina di ogni brano durante l’esplorazione dei file del server. Disattivato mostra i nomi di file grezzi (più veloce per cartelle enormi).';

  @override
  String get settingsLetterStrip => 'Soglia dello scorrimento alfabetico';

  @override
  String get settingsLetterStripSubtitle =>
      'Mostra la barra di scorrimento rapido A-Z quando un elenco ha questo numero di elementi o più. Sotto questa dimensione la barra è nascosta e i nomi lunghi di cartelle/file vanno a capo su più righe invece di essere troncati. Imposta 0 per mostrare sempre la barra.';

  @override
  String get settingsReset => 'Ripristina valori predefiniti';

  @override
  String get settingsResetSubtitle =>
      'Ripristina tutte le impostazioni di questa schermata ai valori predefiniti. Server e download non vengono modificati.';

  @override
  String get settingsResetDone =>
      'Impostazioni ripristinate ai valori predefiniti';

  @override
  String get realAudioDialogTitle => 'Usare l’audio reale?';

  @override
  String get realAudioDialogBody =>
      'La modalità audio reale legge la forma d’onda della musica riprodotta dal telefono affinché il visualizzatore possa reagire. Android richiede il permesso RECORD_AUDIO per questo — l’app non registra né invia alcun audio da nessuna parte. Puoi tornare all’audio sintetizzato in qualsiasi momento.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Permesso negato definitivamente. Attivalo nelle impostazioni di sistema per usare l’audio reale.';

  @override
  String get realAudioPermDenied =>
      'Permesso negato. Si resta sull’audio sintetizzato.';

  @override
  String get visualizerTapHint =>
      'Tocca = preset successivo · freccia indietro (in alto a sinistra) o tieni premuto per uscire';

  @override
  String get visualizerFailed => 'Avvio del visualizzatore non riuscito';

  @override
  String get visualizerBringingUp => 'Avvio del renderer…';

  @override
  String get visualizerReady => 'Visualizzatore pronto';

  @override
  String get visualizerBridgeFailed => 'Avvio del bridge non riuscito';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Sorgente audio: $source';
  }

  @override
  String get visualizerTapToClose => 'Tocca un punto qualsiasi per chiudere';

  @override
  String get visualizerUnsupported =>
      'Il visualizzatore è attualmente supportato solo su Android.';

  @override
  String get aboutTitle => 'Informazioni';

  @override
  String aboutBuiltBy(String name) {
    return 'Creato da $name';
  }

  @override
  String get linkDiscordSubtitle => 'Chat della community';

  @override
  String get linkGithubSubtitle => 'Codice sorgente del server mStream';

  @override
  String get linkHomepageSubtitle => 'Pagina del progetto';

  @override
  String get aboutAttributions => 'Riconoscimenti';

  @override
  String get aboutAttributionsSubtitle =>
      'Licenza, crediti degli shader e avvisi open source.';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Elimina';

  @override
  String get edit => 'Modifica';

  @override
  String get info => 'Informazioni';

  @override
  String get makeDefault => 'Imposta come predefinito';

  @override
  String get goBack => 'Indietro';

  @override
  String get play => 'Riproduci';

  @override
  String get playAll => 'Riproduci tutto';

  @override
  String get rename => 'Rinomina';

  @override
  String get create => 'Crea';

  @override
  String get copy => 'Copia';

  @override
  String get done => 'Fatto';

  @override
  String get copiedToClipboard => 'Copiato negli appunti';

  @override
  String get attributionsTitle => 'Riconoscimenti';

  @override
  String get attributionsSectionLicense => 'Licenza';

  @override
  String get attributionsSectionShaders => 'Shader del visualizzatore';

  @override
  String get attributionsSectionLibraries => 'Librerie native';

  @override
  String get attributionsSectionEverythingElse => 'Tutto il resto';

  @override
  String get attributionsLicenseBody =>
      'Software libero sotto la GNU General Public License v3.0. Puoi usarlo, studiarlo, condividerlo e modificarlo secondo tali termini.';

  @override
  String get attributionsPackages => 'Licenze dei pacchetti open source';

  @override
  String get attributionsPackagesSubtitle =>
      'Testi completi delle licenze di tutti i pacchetti Flutter/Dart inclusi.';

  @override
  String get manageServersTitle => 'Gestisci server';

  @override
  String get manageServerInfo => 'Informazioni server';

  @override
  String get manageServerDownloadFolder => 'Cartella di download:';

  @override
  String get manageServerCopyPath => 'Copia percorso di download';

  @override
  String get manageServerPathCopied => 'Percorso copiato negli appunti';

  @override
  String get confirmRemoveServerTitle => 'Conferma rimozione server';

  @override
  String get removeSyncedFiles =>
      'Rimuovere i file sincronizzati dal dispositivo?';

  @override
  String get playlistsTitle => 'Playlist';

  @override
  String get playlistsNew => 'Nuova playlist';

  @override
  String get playlistsEmptyTitle => 'Ancora nessuna playlist';

  @override
  String get playlistsEmptyBody =>
      'Creane una con il pulsante Nuova playlist, poi usa l’azione di scorrimento Aggiungi a playlist della coda per riempirla.';

  @override
  String get playlistNameHint => 'Nome';

  @override
  String get playlistsRename => 'Rinomina playlist';

  @override
  String get playlistFallbackTitle => 'Playlist';

  @override
  String get playlistEmptyDetail =>
      'La playlist è vuota.\nAggiungi brani dalla coda.';

  @override
  String get shareEmptyTitle => 'Coda vuota';

  @override
  String get shareEmptyBody => 'Aggiungi brani alla coda prima di condividere.';

  @override
  String get shareBlockedTitle => 'Impossibile condividere questa coda';

  @override
  String get shareLocalOnlyBody =>
      'La coda contiene brani presenti solo su questo dispositivo (non su alcun server). La condivisione funziona solo quando ogni brano della coda proviene da un singolo server.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'La coda mescola brani di $count server ($names). La condivisione funziona solo quando ogni brano proviene da un singolo server.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'Il server \"$name\" non è più nel tuo elenco di server. Aggiungilo di nuovo per condividerne la coda.';
  }

  @override
  String get shareTitle => 'Condividi playlist';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return '$_temp0 da $url';
  }

  @override
  String get shareLinkExpires => 'Il link scade';

  @override
  String get shareExpireNever => 'Mai';

  @override
  String get shareExpire1Day => 'Dopo 1 giorno';

  @override
  String get shareExpire7Days => 'Dopo 7 giorni';

  @override
  String get shareExpire30Days => 'Dopo 30 giorni';

  @override
  String get shareAction => 'Condividi';

  @override
  String get shareDoneTitle => 'Playlist condivisa';

  @override
  String get shareDoneBody =>
      'Chiunque abbia questo link può riprodurre la coda:';

  @override
  String get save => 'Salva';

  @override
  String get start => 'Avvia';

  @override
  String get addServerTitle => 'Aggiungi server';

  @override
  String get editServerTitle => 'Modifica server';

  @override
  String get fieldServerUrl => 'URL del server';

  @override
  String get fieldPublicAccess => 'Accesso pubblico';

  @override
  String get publicAccessSubtitle =>
      'Il server è ad accesso pubblico — non servono nome utente o password.';

  @override
  String get fieldUsername => 'Nome utente';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldSdCard => 'Scarica su scheda SD';

  @override
  String get sdCardSubtitle =>
      'Salva la musica scaricata sulla scheda SD rimovibile invece che nell’archiviazione interna.';

  @override
  String get testConnectionButton => 'Prova connessione';

  @override
  String get testing => 'Prova in corso…';

  @override
  String get connecting => 'Connessione…';

  @override
  String get validatorUrlNeeded => 'È necessario l’URL del server';

  @override
  String get validatorUrlParse => 'Impossibile analizzare l’URL';

  @override
  String get testEnterUrl => 'Inserisci prima l’URL di un server.';

  @override
  String get testParseUrl => 'Impossibile analizzare l’URL.';

  @override
  String get testTimedOut => 'Connessione scaduta.';

  @override
  String get connectionSuccessful => 'Connessione riuscita!';

  @override
  String get couldNotReachServer =>
      'Impossibile raggiungere il server. Se richiede l’accesso, disattiva \"Accesso pubblico\" e aggiungi le credenziali.';

  @override
  String get failedToLogin => 'Accesso non riuscito';

  @override
  String testConnected(String version) {
    return 'Connesso — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'Impossibile connettersi: $error';
  }

  @override
  String get sleepTimerTitle => 'Timer di spegnimento';

  @override
  String get sleepTimerHint =>
      'Scegli una durata dopo la quale mettere in pausa la riproduzione.';

  @override
  String get sleepTimerCustom => 'Personalizzato';

  @override
  String get sleepTimerCustomHint => 'minuti (1–600)';

  @override
  String get sleepTimerCancel => 'Annulla timer';

  @override
  String get sleepTimerInvalid => 'Inserisci un numero tra 1 e 600 minuti';

  @override
  String sleepTimerPausesIn(String time) {
    return 'In pausa tra $time';
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
      other: 'Timer di spegnimento impostato per $minutes minuti',
      one: 'Timer di spegnimento impostato per 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Aggiungi';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String get autoDjAddServerFirst => 'Aggiungi prima un server.';

  @override
  String get autoDjSectionServer => 'Server';

  @override
  String get autoDjSectionSources => 'Sorgenti';

  @override
  String get autoDjSectionContinuity => 'Continuità';

  @override
  String get autoDjSectionFilters => 'Filtri';

  @override
  String get autoDjBpmTitle => 'Continuità dei BPM';

  @override
  String get autoDjBpmSubtitle =>
      'Preferisci scelte entro un intervallo di tempo rispetto al brano corrente. Rispetta l’equivalenza di tempo dimezzato/raddoppiato.';

  @override
  String get autoDjTolerance => 'Tolleranza';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Mixaggio armonico';

  @override
  String get autoDjHarmonicSubtitle =>
      'Preferisci scelte in tonalità che si mixano bene con il brano bloccato (vicini sulla ruota Camelot).';

  @override
  String get autoDjStatusOn => 'Auto DJ è attivo';

  @override
  String get autoDjStatusOff => 'Auto DJ è disattivo';

  @override
  String get autoDjStatusOffDetail =>
      'Tocca sotto per avviare. Verrà usata la libreria del server corrente.';

  @override
  String get autoDjStart => 'Avvia Auto DJ';

  @override
  String get autoDjStop => 'Ferma Auto DJ';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'I brani vengono scelti da $url quando la coda si sta esaurendo.';
  }

  @override
  String get autoDjActiveSource => 'Sorgente attiva';

  @override
  String get autoDjActiveSourceTap => 'Sorgente attiva — tocca per cambiare';

  @override
  String get autoDjSwitch => 'Cambia';

  @override
  String get autoDjOneSourceRequired => 'È richiesta almeno una sorgente.';

  @override
  String get autoDjMinRating => 'Valutazione minima';

  @override
  String get autoDjMinRatingSubtitle =>
      'Scegli solo i brani con questa valutazione o superiore.';

  @override
  String get autoDjRatingAny => 'Qualsiasi';

  @override
  String get autoDjGenreTitle => 'Filtro per genere';

  @override
  String get autoDjGenreSubtitle =>
      'La whitelist riproduce solo i brani corrispondenti; la blacklist li salta.';

  @override
  String get autoDjWhitelist => 'Whitelist';

  @override
  String get autoDjBlacklist => 'Blacklist';

  @override
  String get autoDjNoGenres =>
      'Nessun genere selezionato. Tocca \"Scegli generi\" per scegliere.';

  @override
  String get autoDjPickGenres => 'Scegli generi';

  @override
  String get autoDjGenreLoadError => 'Impossibile caricare i generi';

  @override
  String get autoDjKeywordTitle => 'Filtro per parole chiave';

  @override
  String get autoDjKeywordSubtitle =>
      'Salta le scelte il cui titolo, artista, album o percorso file contiene una di queste parole.';

  @override
  String get autoDjNoKeywords =>
      'Nessuna parola chiave. Aggiungi parole sotto per iniziare a filtrare.';

  @override
  String get autoDjKeywordHint => 'es. \"live\" o \"remix\"';

  @override
  String get autoDjSearchGenres => 'Cerca generi…';

  @override
  String get autoDjNoGenresOnServer =>
      'Nessun genere trovato su questo server.';

  @override
  String autoDjSelectedCount(int count) {
    return '$count selezionati';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return 'Nessun genere corrisponde a \"$query\".';
  }

  @override
  String get download => 'Scarica';

  @override
  String get addAll => 'Aggiungi tutto';

  @override
  String get browserConfirmDeletePlaylist => 'Conferma eliminazione playlist';

  @override
  String get browserConfirmDeleteFolder => 'Conferma eliminazione cartella';

  @override
  String get browserSearchHint => 'Cerca nel database';

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
      other: '$count download avviati',
      one: '1 download avviato',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani aggiunti alla coda',
      one: '1 brano aggiunto alla coda',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Esplora';

  @override
  String get tabQueue => 'Coda';

  @override
  String get drawerTagline => 'Streaming musicale personale';

  @override
  String get mainFailedToConnect => 'Connessione al server non riuscita';

  @override
  String get mainQueueEmpty => 'La coda è vuota';

  @override
  String get visualizerTitle => 'Visualizzatore';

  @override
  String get mainClearQueue => 'Svuota la coda';

  @override
  String get mainSync => 'Sincronizza';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani in coda',
      one: '1 brano in coda',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ attivato';

  @override
  String get autoDjDisabled => 'Auto DJ disattivato';

  @override
  String autoDjEnabledFor(String url) {
    return 'Auto DJ attivato per $url';
  }

  @override
  String get addToPlaylistTitle => 'Aggiungi a playlist';

  @override
  String get addToPlaylistEmpty =>
      'Ancora nessuna playlist — tocca + per crearne una.';

  @override
  String addedToPlaylist(String name) {
    return 'Aggiunto a $name';
  }

  @override
  String get testConnectedSignedIn =>
      'Connesso — accesso effettuato con successo.';

  @override
  String get testSignInFailed =>
      'Server raggiunto, ma l’accesso non è riuscito — controlla nome utente e password.';

  @override
  String get browserFileExplorer => 'Esplora file';

  @override
  String get browserLocalFiles => 'File locali';

  @override
  String get browserPlaylists => 'Playlist';

  @override
  String get browserAlbums => 'Album';

  @override
  String get browserArtists => 'Artisti';

  @override
  String get browserRecent => 'Recenti';

  @override
  String get browserRated => 'Valutati';

  @override
  String get browserSearch => 'Cerca';

  @override
  String get browserWelcomeTitle => 'Benvenuto in mStream';

  @override
  String get browserWelcomeSubtitle => 'Tocca qui per aggiungere un server';

  @override
  String get settingsVisualizerKnobs =>
      'Manopole di regolazione del visualizzatore';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      'Mostra cursori in tempo reale sopra il visualizzatore per regolare la reattività audio di ogni shader. Solo con il motore shader.';

  @override
  String get visualizerTuningTitle => 'Regolazione';

  @override
  String get close => 'Chiudi';

  @override
  String get migMoveStopped =>
      'Spostamento interrotto — spazio insufficiente o posizione non disponibile.';

  @override
  String get migMoveComplete => 'Spostamento completato';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Spostamento completato — $count file saltati (non supportati nella destinazione)',
      one:
          'Spostamento completato — 1 file saltato (non supportato nella destinazione)',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'Spostamento dei download… $progress — tieni l’app aperta';
  }

  @override
  String get migRetry => 'Riprova';

  @override
  String get queueDownloadAll => 'Scarica tutto';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani verranno scaricati per la riproduzione offline.',
      one: '1 brano verrà scaricato per la riproduzione offline.',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'Altro';

  @override
  String get commonOn => 'Attivo';

  @override
  String get commonOff => 'Disattivo';

  @override
  String get settingsCastQuality =>
      'Qualità del visualizzatore in trasmissione';

  @override
  String get settingsCastQualitySubtitle720 =>
      'Risoluzione con cui il visualizzatore viene trasmesso a una TV. 720p — la più leggera per il telefono.';

  @override
  String get settingsCastQualitySubtitle1080 =>
      'Risoluzione con cui il visualizzatore viene trasmesso a una TV. 1080p — nitida su qualsiasi Chromecast (predefinita).';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Risoluzione con cui il visualizzatore viene trasmesso a una TV. 4K — richiede un Chromecast 4K; molto più impegnativa per il telefono.';

  @override
  String get eqCasting =>
      'L’equalizzatore regola l’audio su questo dispositivo, quindi non è disponibile durante la trasmissione. Disconnetti per usarlo.';

  @override
  String get browserNothingToDownload => 'Niente da scaricare in questo elenco';

  @override
  String get browserDownloadAllTitle => 'Scarica tutto';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verranno scaricati $count file.',
      one: 'Verrà scaricato 1 file.',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => 'Chiudi ricerca';

  @override
  String get browserSearchThisList => 'Cerca in questo elenco';

  @override
  String get browserSearchList => 'Cerca nell’elenco';

  @override
  String browserNoMatches(String query) {
    return 'Nessun risultato per \"$query\"';
  }

  @override
  String get clear => 'Cancella';

  @override
  String get dlLocationUnavailable => 'Posizione di download non disponibile';

  @override
  String get dlLocationUnavailableServer =>
      'Posizione di download non disponibile per questo server.';

  @override
  String get dlFailed =>
      'Un download non è riuscito — controlla la connessione.';

  @override
  String get dlFatSkip =>
      'Alcuni brani non possono essere salvati su questa scheda — i loro nomi non sono supportati. Vengono trasmessi in streaming.';

  @override
  String get dlServerGone => 'Quel server non è più configurato.';

  @override
  String get dlStorageUnavailable =>
      'Posizione di archiviazione non disponibile — ricollega la scheda SD o cambia la posizione di archiviazione di questo server in Modifica server.';

  @override
  String get dlCouldNotStart =>
      'Impossibile avviare il download — archiviazione non disponibile.';

  @override
  String get storageLocationLabel => 'Posizione di archiviazione';

  @override
  String get storageAppLocal => 'Locale dell’app';

  @override
  String get storagePermanent => 'Permanente';

  @override
  String get storageSdCard => 'Scheda SD';

  @override
  String get storageSdSwitchTitle => 'Save to SD card';

  @override
  String get storageSdSwitchSubtitle =>
      'Stored in the SD card\'s app folder — no permission needed, but removed if you uninstall the app.';

  @override
  String get storageHelpAppLocal =>
      'Salvato dentro l’app. Eliminato quando disinstalli o cancelli i dati dell’app.';

  @override
  String get storageHelpPermanent =>
      'Salvato in una cartella a tua scelta. Sopravvive alla disinstallazione dell’app. Richiede l’\"Accesso a tutti i file\".';

  @override
  String get storageHelpSdCard =>
      'Salvato in una cartella della scheda SD a tua scelta. Può diventare non disponibile se la scheda viene rimossa. Alcuni dispositivi non permettono alle app di scrivere sulle schede SD — se la selezione della cartella continua a non riuscire, usa Permanente o Locale dell’app.';

  @override
  String get storageChooseFolder => 'Scegli cartella';

  @override
  String get storageNoFolderChosen => 'Ancora nessuna cartella scelta';

  @override
  String get storageDownloadFolderLabel => 'Cartella di download';

  @override
  String get storageDownloadFolderHint => 'nome della cartella';

  @override
  String get storageBrowse => 'Sfoglia';

  @override
  String get storageDownloadFolderHelp =>
      'I file vengono scaricati in una directory \'media/<folder>\' su questo dispositivo. Riutilizzare la cartella di un server precedente conserva i suoi brani scaricati quando riaggiungi un server perso.';

  @override
  String get storageNoStorageAvailable => 'Nessuna archiviazione disponibile';

  @override
  String get storageNoDownloadFolders =>
      'Nessuna cartella di download esistente trovata';

  @override
  String get storageExistingFolders => 'Cartelle di download esistenti';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'Concedi l’\"Accesso a tutti i file\" per archiviare i download in modo permanente, poi scegli di nuovo la modalità.';

  @override
  String get storageSettings => 'Impostazioni';

  @override
  String get storageNoVolume =>
      'Impossibile individuare un volume di archiviazione';

  @override
  String get storageNotWritable =>
      'Quella cartella non è scrivibile — scegline un’altra.';

  @override
  String get storageNewFolder => 'Nuova cartella';

  @override
  String get storageFolderNameHint => 'Nome della cartella';

  @override
  String get storageCouldNotCreateFolder => 'Impossibile creare la cartella';

  @override
  String get storageNoSubfolders => 'Nessuna sottocartella qui';

  @override
  String get storageUseThisFolder => 'Usa questa cartella';

  @override
  String get storageMovedToNewFolder =>
      'File scaricati spostati nella nuova cartella.';

  @override
  String get storageMoveAlreadyRunning =>
      'Uno spostamento è già in corso — lascialo finire prima.';

  @override
  String get storageMigrateTitle => 'Volume di archiviazione diverso';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'I $count file scaricati di questo server ($size) si trovano su un volume di archiviazione diverso da quello della nuova posizione. Scegli cosa fare:',
      one:
          'Il file scaricato di questo server ($size) si trova su un volume di archiviazione diverso da quello della nuova posizione. Scegli cosa fare:',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return 'Spazio libero insufficiente nella destinazione ($free liberi). Uno spostamento potrebbe non riuscire a metà — libera prima dello spazio.';
  }

  @override
  String get storageMigrateMove => 'Spostali';

  @override
  String get storageMigrateMoveBody =>
      'Copia nella nuova posizione in background, eliminando ogni vecchia copia man mano. Tieni l’app aperta finché non finisce.';

  @override
  String get storageMigrateLeave => 'Lasciali';

  @override
  String get storageMigrateLeaveBody =>
      'Cambia ora; i vecchi download restano dove sono e vengono riscaricati nella nuova posizione.';

  @override
  String get storageMigrateDelete => 'Elimina vecchi download';

  @override
  String get storageMigrateDeleteBody =>
      'Cambia ora ed elimina i vecchi file; verranno riscaricati nella nuova posizione.';

  @override
  String get storageMovingBackground =>
      'Spostamento dei tuoi download in background — tieni l’app aperta.';

  @override
  String get storageChooseFolderFirst =>
      'Scegli prima una cartella di download.';

  @override
  String get storageChooseSdFolderFirst =>
      'Scegli prima una cartella sulla scheda SD. Se ogni cartella viene rifiutata, il dispositivo potrebbe non permettere alle app di scrivere sulla scheda — usa invece Permanente o Locale dell’app.';

  @override
  String get castPlayOn => 'Riproduci su';

  @override
  String get castPlayOnTooltip => 'Riproduci su…';

  @override
  String get castSearching => 'Ricerca di dispositivi di trasmissione…';

  @override
  String get castNotSeeing =>
      'Non vedi il tuo dispositivo? Assicurati che sia sulla stessa rete Wi-Fi.';

  @override
  String get castVisualizer => 'Trasmetti il visualizzatore';

  @override
  String get castVisualizerSubtitle =>
      'Trasmetti il visualizzatore alla TV · solo Chromecast';

  @override
  String get visualizerNoKnobs => 'Questo shader non espone alcuna manopola.';

  @override
  String get nowPlaying => 'In riproduzione';

  @override
  String get playerLayoutSmall => 'Piccolo';

  @override
  String get playerLayoutMedium => 'Medio';

  @override
  String get playerLayoutLarge => 'Grande';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => 'Barra sottile — coda massima';

  @override
  String get playerLayoutMediumDesc => 'Banner — bilanciato (predefinito)';

  @override
  String get playerLayoutLargeDesc => 'Compatto — copertina centrata';

  @override
  String get playerLayoutXlDesc => 'In evidenza — copertina intera';

  @override
  String get queueNothingToDownloadEmpty =>
      'La coda è vuota — niente da scaricare';

  @override
  String get queueNothingToDownloadSaved =>
      'Niente da scaricare — i brani sono già salvati';

  @override
  String get settingsAccentColor => 'Colore d\'accento';

  @override
  String get settingsAccentColorSubtitle =>
      'Il colore di evidenziazione usato in tutta l\'app.';

  @override
  String get accentThemeDefault => 'Predefinito del tema';

  @override
  String get accentCustom => 'Personalizzato';

  @override
  String get lanOnYourNetwork => 'Server sulla tua rete locale';

  @override
  String get lanSearching => 'Ricerca server…';

  @override
  String get lanRefresh => 'Aggiorna';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return 'Accedi a $name';
  }

  @override
  String get lanUnreachable =>
      'Impossibile raggiungere questo server sulla rete.';

  @override
  String get lanNoCode =>
      'Quick Connect è attivo su questo server, ma non ha condiviso un codice di associazione. Accedi come amministratore o chiedi all\'operatore di attivare la condivisione del codice.';

  @override
  String get settingsResumeQueue => 'Riprendi la coda all\'avvio';

  @override
  String get settingsResumeQueueSubtitle =>
      'Salva la coda di riproduzione e la tua posizione e le ripristina alla riapertura dell\'app.';

  @override
  String get settingsOfflineQueue => 'Mantieni la coda disponibile offline';

  @override
  String get settingsOfflineQueueSubtitle =>
      'Scarica automaticamente i brani in coda su questo dispositivo così la riproduzione sopravvive alla perdita di connessione.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Scarica solo tramite Wi-Fi';

  @override
  String get settingsOfflineQueueWifiOnlySubtitle =>
      'Attende una connessione Wi-Fi prima di scaricare i brani in coda.';

  @override
  String get settingsAutoDownloadCap => 'Auto-download limit';

  @override
  String get settingsAutoDownloadCapSubtitle =>
      'Keep the newest this many auto-downloads; older ones no longer in your queue are removed.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Keep every auto-downloaded track (no limit).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unlimited';

  @override
  String get settingsAutoDownloadCapField => 'Number of tracks';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Automatically downloaded tracks kept for offline play. When you go over, the oldest ones that aren\'t in your queue are deleted. Set to 0 to keep everything.';

  @override
  String get downloadWaitingWifi => 'In attesa del Wi-Fi';

  @override
  String get settingsRatingHalf => 'Valutazioni a mezza stella';

  @override
  String get settingsRatingHalfSubtitle =>
      'Valuta i brani a mezza stella (tieni premuta una stella).';

  @override
  String get ratingTitle => 'Valuta';

  @override
  String get ratingFailed => 'Impossibile salvare la valutazione';

  @override
  String get diagnosticsTitle => 'Diagnostica';

  @override
  String get diagnosticsEnable => 'Abilita registrazione';

  @override
  String get diagnosticsHint =>
      'I log restano sul tuo dispositivo. I token vengono nascosti prima di copiare o condividere.';

  @override
  String get diagnosticsVerbose => 'Verbose logging';

  @override
  String get diagnosticsVerboseHint =>
      'Also logs high-frequency events like app focus changes. Only needed when diagnosing a playback issue.';

  @override
  String get diagnosticsCopy => 'Copia';

  @override
  String get diagnosticsShare => 'Condividi';

  @override
  String get diagnosticsClear => 'Cancella';

  @override
  String get diagnosticsCopied => 'Log copiati negli appunti';

  @override
  String get diagnosticsEmpty => 'Nessun log ancora';

  @override
  String get storageAppExternal => 'App esterna';

  @override
  String get selfSignedTitle => 'Consenti certificato autofirmato';

  @override
  String get selfSignedSubtitle =>
      'Salta la convalida TLS per questo server. Attiva solo su una rete affidabile.';

  @override
  String get importedShadersTitle => 'Shader importati';

  @override
  String get importedShadersSettingsSubtitle =>
      'Aggiungi i tuoi file .glsl alla rotazione del motore Shader.';

  @override
  String get importedShadersRescan => 'Riscansiona cartella';

  @override
  String get importedShadersDropHint =>
      'Inserisci file .glsl in questa cartella, poi Riscansiona:';

  @override
  String get importedShadersCopyPath => 'Copia percorso';

  @override
  String get importedShadersReachableHint =>
      'Raggiungibile via USB o con un file manager (sotto Android/data). Gli shader importati entrano nella rotazione quando il motore Shader è attivo.';

  @override
  String get importedShadersRemove => 'Rimuovi';

  @override
  String get importedShadersEmptyTitle =>
      'Ancora nessuno shader nella cartella';

  @override
  String get importedShadersEmptyBody =>
      'Copia file .glsl in stile Shadertoy nella cartella sopra, poi tocca Riscansiona.';

  @override
  String get importedShadersInvalid =>
      'Potrebbe non essere uno shader valido — nessun punto d’ingresso mainImage/main.';

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
  String get irohPairingHeader => 'Connect with a pairing code';

  @override
  String get irohConnectBody =>
      'Reach your server from anywhere — no port-forwarding, DNS, or public IP needed.';

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
  String get discoverTitle => 'Scopri';

  @override
  String get discoverMatchedBySound => 'Corrispondenze sonore';

  @override
  String get discoverSimilarTracks => 'Brani simili';

  @override
  String get discoverSimilarArtists => 'Artisti simili';

  @override
  String get discoverFromNetwork => 'Dalla rete';

  @override
  String get discoverFromPeers => 'Dai tuoi peer';

  @override
  String get discoverQueueAll => 'Accoda tutto';

  @override
  String get discoverNewArtistsOnly => 'Solo artisti nuovi';

  @override
  String get discoverNotAnalyzed =>
      'Questo brano non è ancora stato analizzato — i brani simili appariranno quando la scansione di scoperta lo raggiungerà.';

  @override
  String get discoverNothingFound => 'Nessuna corrispondenza trovata.';

  @override
  String get discoverNoSeed => 'Riproduci un brano per scoprire musica simile.';

  @override
  String get discoverLeadCopied => 'Copiato — vai a cercarlo!';

  @override
  String get discoverOpenMusicBrainz => 'Apri su MusicBrainz';

  @override
  String get discoverNetworkWarmingUp =>
      'Ancora nessun dato dalla rete — le librerie dei peer si scaricano in background quando vengono rilevati altri server.';

  @override
  String get discoverNetworkNothingNew =>
      'Niente di nuovo per questo brano — la rete non ha corrispondenze sconosciute.';

  @override
  String get discoverPeersUnreachable =>
      'I tuoi peer non hanno risposto — potrebbero essere offline in questo momento.';

  @override
  String get discoverPeersNothingNew =>
      'Niente di nuovo per questo brano sui server dei tuoi peer.';

  @override
  String get autoDjSonicTitle => 'Somiglianza sonora';

  @override
  String get autoDjSonicSubtitle =>
      'Sceglie solo brani che suonano come la sessione, usando l\'analisi audio del server.';

  @override
  String get autoDjSonicUnavailable =>
      'Questo server non ha dati di scoperta — la selezione resta casuale.';

  @override
  String get autoDjSonicStrictness => 'Soglia di somiglianza';

  @override
  String autoDjSonicStrictnessValue(int pct) {
    return '$pct % o più simile';
  }

  @override
  String get autoDjSonicSeedLabel => 'Brano di partenza';

  @override
  String get autoDjSonicSeedNone =>
      'Nessun brano di partenza — il brano in riproduzione àncora la sessione.';

  @override
  String get autoDjSonicSeedSearchHint => 'Cerca un brano…';

  @override
  String get autoDjSonicSeedRandom => 'Brano casuale';

  @override
  String get autoDjSonicSeedRemove => 'Rimuovi brano di partenza';

  @override
  String get autoDjSonicSeedFailed =>
      'Impossibile recuperare un brano dal server.';

  @override
  String get discoverFindSimilar => 'Trova simili';

  @override
  String get discoverStartSession => 'Avvia una sessione sonora';

  @override
  String get discoverStartSessionSubtitle =>
      'Musica senza fine che suona come questa — sostituisce la coda.';

  @override
  String get discoverStartSessionSubtitleRandom =>
      'Musica senza fine da un brano iniziale casuale — sostituisce la coda.';

  @override
  String get discoverSessionStarted =>
      'Sessione sonora avviata — Auto DJ attivo.';

  @override
  String get autoDjSonicAnchorLabel => 'Ancora';

  @override
  String get autoDjSonicAnchorRolling => 'Segui l\'atmosfera';

  @override
  String get autoDjSonicAnchorLocked => 'Resta sul brano di partenza';

  @override
  String get autoDjSonicAnchorRollingHint =>
      'Ogni brano segue il suono recente della sessione — può evolvere lentamente.';

  @override
  String get autoDjSonicAnchorLockedHint =>
      'Ogni brano resta vicino al brano di partenza per tutta la sessione.';
}
