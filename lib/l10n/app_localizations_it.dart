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
  String get settingsLetterStripSide => 'Lato della barra';

  @override
  String get settingsLetterStripSideSubtitle =>
      'Su quale bordo si trova la barra A–Z.';

  @override
  String get settingsLetterStripLeft => 'Sinistra';

  @override
  String get settingsLetterStripRight => 'Destra';

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
  String get aboutSponsor => 'Sostieni mStream';

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
  String get autoDjDurationTitle => 'Durata del brano';

  @override
  String get autoDjDurationSubtitle =>
      'Salta intermezzi e lunghi mix scegliendo solo brani entro un intervallo di durata';

  @override
  String get autoDjDurationRange => 'Durata';

  @override
  String get autoDjDurationAny => 'Qualsiasi durata';

  @override
  String autoDjDurationOver(String min) {
    return 'Oltre $min';
  }

  @override
  String autoDjDurationUnder(String max) {
    return 'Meno di $max';
  }

  @override
  String autoDjDurationBetween(String min, String max) {
    return 'Da $min a $max';
  }

  @override
  String get autoDjDurationAllowUnknown =>
      'Includi brani di durata sconosciuta';

  @override
  String get autoDjDurationAllowUnknownSub =>
      'I brani di cui il server non ha letto la durata vengono altrimenti saltati';

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
  String get browserMoreActions => 'Altre azioni';

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
      other: '$count brani',
      one: '1 brano',
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
      'Memorizza questo numero di brani a partire da quello in riproduzione; quelli superati vengono rimossi.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Memorizza l\'intera coda (nessun limite).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unlimited';

  @override
  String get settingsAutoDownloadCapField => 'Number of tracks';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Quanti brani della coda restano scaricati, a partire da quello in riproduzione. Man mano che si va avanti, quelli superati vengono eliminati. 0 per l\'intera coda.';

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
  String get storageAppSdCard => 'Scheda SD dell\'app';

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
  String get discoverScanPendingTitle => 'Non è ancora stato analizzato nulla';

  @override
  String get discoverScanPendingBody =>
      'Su questo server la scoperta è attiva, ma non è ancora stata analizzata alcuna musica. I brani simili appariranno quando la scansione di scoperta sarà stata eseguita.';

  @override
  String get discoverCheckAgain => 'Controlla di nuovo';

  @override
  String get discoverTurnedOff =>
      'La scoperta è stata disattivata su questo server.';

  @override
  String get pathScanPending =>
      'Questo server non ha ancora analizzato alcuna musica, quindi non c\'è nulla attraverso cui costruire un percorso. Funzionerà quando la scansione di scoperta sarà stata eseguita.';

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
  String get autoDjSonicSeedBanner =>
      'Scegli il brano di partenza — tocca una traccia ovunque nella libreria';

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
  String get autoDjSeedNoMatch =>
      'Nessun brano corrisponde ai filtri di Auto DJ — prova ad allentarli';

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

  @override
  String get trackAddToPlaylist => 'Aggiungi alla playlist';

  @override
  String get trackAddToPlaylistFailed =>
      'Impossibile aggiungere alla playlist.';

  @override
  String get discoverPlayPathTo => 'Riproduci un percorso verso…';

  @override
  String get pathScreenTitle => 'Percorso sonoro';

  @override
  String get pathStartNotAnalyzed =>
      'Il brano di partenza non è ancora stato analizzato — attendi la scansione di scoperta o scegline un altro.';

  @override
  String get pathEndNotAnalyzed =>
      'Il brano di destinazione non è ancora stato analizzato — attendi la scansione di scoperta o scegline un altro.';

  @override
  String get pathStartSong => 'Brano iniziale';

  @override
  String get pathEndSong => 'Brano finale';

  @override
  String get pathLength => 'Lunghezza';

  @override
  String get pathRegenerate => 'Rigenera';

  @override
  String get pathSaveAsPlaylist => 'Salva come playlist';

  @override
  String get pathSetupHint =>
      'Scegli un brano di partenza e uno di arrivo — il viaggio tra i due si riempie da solo.';

  @override
  String get pathNotSet => 'Non impostato';

  @override
  String get pathUsePlaying => 'Usa il brano in riproduzione';

  @override
  String get pathSearchSong => 'Cerca';

  @override
  String get pathBrowseLibrary => 'Sfoglia la libreria';

  @override
  String get pathBuild => 'Crea il viaggio';

  @override
  String get pathStartOver => 'Ricomincia';

  @override
  String get pathPickBannerStart =>
      'Scegli il brano di partenza — tocca una traccia ovunque nella libreria';

  @override
  String get pathPickBannerEnd =>
      'Scegli il brano di arrivo — tocca una traccia ovunque nella libreria';

  @override
  String get pathNothingPlaying => 'Nessuna riproduzione in corso';

  @override
  String pathPickOnServer(String server) {
    return 'Scegli una traccia su $server';
  }

  @override
  String get welcomeTranslationNote =>
      'Questa lingua è stata tradotta automaticamente e potrebbe suonare strana.';

  @override
  String get welcomeTranslationCta => 'Aiutaci a tradurre mStream';

  @override
  String get setupTitle => 'Configurazione rapida';

  @override
  String get setupSkip => 'Salta';

  @override
  String get setupNext => 'Avanti';

  @override
  String get setupFinish => 'Fine';

  @override
  String get setupBack => 'Indietro';

  @override
  String get setupAccentTitle => 'Scegli il tuo colore';

  @override
  String get setupAccentBody =>
      'Il colore d\'accento evidenzia pulsanti, cursori e i comandi del player. Toccane uno per provarlo.';

  @override
  String get setupVisualizerTitle => 'Audio reale per il visualizzatore';

  @override
  String get setupVisualizerBody =>
      'Il visualizzatore usa dati sintetizzati finché questa opzione non viene attivata.';

  @override
  String get setupVisualizerWarning =>
      'Attivarlo richiede il permesso del microfono: Android lo esige dalle app che decodificano il flusso audio del dispositivo (cosa che fa il visualizzatore).';

  @override
  String get setupPlaybackTitle => 'Quando tocchi un brano';

  @override
  String get setupOfflineTitle => 'Tieni la coda offline';

  @override
  String get setupVisualizerNoMic => 'mStream non usa mai il tuo microfono.';

  @override
  String get playlistEmpty => 'La playlist è vuota';

  @override
  String get trackRating => 'Valutazione';

  @override
  String albumDiscNumber(int n) {
    return 'Disco $n';
  }

  @override
  String get autoDjStartTitle => 'Avviare Auto DJ con cosa?';

  @override
  String get autoDjStartSubtitle =>
      'La coda è vuota, quindi al DJ serve un brano iniziale. Con una coda segue semplicemente ciò che c\'è già.';

  @override
  String get autoDjStartRandom => 'Sorprendimi';

  @override
  String get autoDjStartRandomSub =>
      'Scegliere un brano a caso dalla libreria e costruire da lì.';

  @override
  String get autoDjStartPick => 'Scelgo io';

  @override
  String get autoDjStartPickSub =>
      'Aprire la libreria e scegliere tu il brano iniziale.';

  @override
  String get autoDjStartRemember => 'Ricorda';

  @override
  String get autoDjStartRememberSub =>
      'Salta questa domanda la prossima volta e parti sempre così.';

  @override
  String get autoDjStartPickBanner =>
      'Scegli il brano iniziale — tocca una traccia ovunque nella libreria';

  @override
  String get autoDjOnEmptyQueue => 'Con la coda vuota';

  @override
  String get autoDjOnEmptyQueueSub =>
      'Cosa fa Auto DJ quando lo attivi senza nulla in coda.';

  @override
  String get autoDjStartAskShort => 'Chiedi';

  @override
  String serverVersionLabel(String version) {
    return 'Server v$version';
  }

  @override
  String get serverVersionUnknown => 'Versione del server sconosciuta';

  @override
  String get serverUpdateUrgent => 'Aggiorna il server';

  @override
  String get serverUpdateAvailable => 'Aggiornamento del server disponibile';

  @override
  String serverTooOldWarning(String version) {
    return 'Questo server è alla versione v$version. Alcune funzioni richiedono la v5.5 o successiva e non saranno disponibili.';
  }

  @override
  String get autoDjNeedsNewerServer =>
      'Continuità BPM, mix armonico e filtro per generi richiedono un server più recente. Aggiorna per averli.';

  @override
  String get autoDjSonicNeedsNewerServer =>
      'Richiede server 6.15.2 o successivo';

  @override
  String get torrentScreenTitle => 'Aggiungi torrent';

  @override
  String get torrentNoServer => 'Nessun server configurato.';

  @override
  String get torrentServerLabel => 'Server';

  @override
  String get torrentLibraryLabel => 'Libreria';

  @override
  String get torrentNoLibraries => 'Nessuna libreria su questo server';

  @override
  String get torrentSourceLabel => 'Sorgente';

  @override
  String get torrentChooseFile => 'Scegli file .torrent';

  @override
  String get torrentOr => 'o';

  @override
  String get torrentMagnetLabel => 'Link magnet';

  @override
  String get torrentMagnetInvalid => 'Link magnet non valido';

  @override
  String torrentNotATorrent(String name) {
    return '«$name» non è un file .torrent';
  }

  @override
  String get torrentOpenWith => 'Apri in un’altra app';

  @override
  String get torrentOpenWithNone =>
      'Nessuna app su questo dispositivo può aprire un file .torrent';

  @override
  String get torrentOpenWithFailed =>
      'Impossibile passare il torrent a un’altra app';

  @override
  String get torrentIntentTitle => 'Torrent ricevuto';

  @override
  String get torrentIntentBody =>
      'Aggiungilo a una libreria sul tuo server mStream, oppure passalo a un’altra app.';

  @override
  String get torrentIntentAdd => 'Aggiungi a mStream';

  @override
  String get torrentIntentDontAsk =>
      'Aggiungi sempre a mStream, non chiedere più';

  @override
  String get settingsTorrentAskTitle => 'Chiedi cosa fare con i torrent';

  @override
  String get settingsTorrentAskSub =>
      'Quando un torrent viene aperto con mStream, proponi di passarlo a un’altra app';

  @override
  String get settingsTorrentDefaultTitle => 'App predefinita per i torrent';

  @override
  String get settingsTorrentDefaultSub =>
      'Apre le impostazioni di Android, dove puoi scegliere quale app apre torrent e link magnet';

  @override
  String get settingsTorrentDefaultFailed =>
      'Impossibile aprire le impostazioni di Android';

  @override
  String get torrentAutoDetect => 'Rileva metadati';

  @override
  String get torrentDetecting => 'Rilevamento…';

  @override
  String get torrentDetectNoMetadata =>
      'Metadati insufficienti — compila i campi a mano';

  @override
  String get torrentDetected => 'Metadati rilevati';

  @override
  String get torrentDetectGuess => 'Stima approssimativa — verifica i campi';

  @override
  String get torrentMetadataLabel => 'Metadati';

  @override
  String get torrentArtistLabel => 'Artista';

  @override
  String get torrentAlbumLabel => 'Album';

  @override
  String get torrentYearLabel => 'Anno';

  @override
  String get torrentDestinationLabel => 'Destinazione';

  @override
  String get torrentPathLabel => 'Percorso nella libreria';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹nessuna libreria›/$path';
  }

  @override
  String get torrentPreviewContents => '‹contenuto del torrent›';

  @override
  String get torrentRenameRoot => 'Rinomina la cartella radice del torrent';

  @override
  String get torrentRenameRootSub =>
      'Allineala al nome della cartella di destinazione';

  @override
  String get torrentForceFresh => 'Forza download da zero';

  @override
  String get torrentForceFreshSub =>
      'Non controllare i file già presenti sul server';

  @override
  String get torrentSubmit => 'Aggiungi torrent';

  @override
  String get torrentSubmitting => 'Aggiunta…';

  @override
  String get torrentUnavailable =>
      'I torrent non sono disponibili su questo server.';

  @override
  String get torrentPickLibrary => 'Scegli una libreria';

  @override
  String get torrentOneSource =>
      'Aggiungi un link magnet o un file .torrent (uno solo)';

  @override
  String get torrentPathEmpty => 'Il percorso di destinazione è vuoto';

  @override
  String get torrentSeeded => 'Già su disco — seeding in corso';

  @override
  String get torrentAlreadyInClient => 'Già nel client torrent';

  @override
  String get torrentInvalidFile => 'File torrent non valido';

  @override
  String get torrentSeedCheckFailed =>
      'Impossibile controllare i file esistenti — download da zero';

  @override
  String get torrentPartialTitle => 'Alcuni file esistono già';

  @override
  String get torrentPartialBody =>
      'Punta il torrent a una copia esistente per farne il seeding e scaricare solo ciò che manca.';

  @override
  String torrentPartialCount(String matched, String total) {
    return '$matched/$total file qui';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · $missing da scaricare';
  }

  @override
  String get torrentDownloadFresh => 'Scarica comunque da zero';

  @override
  String get torrentMatchNoFolder =>
      'Questa corrispondenza non ha un nome di cartella — usa \'Scarica comunque da zero\'';

  @override
  String torrentAdded(String name) {
    return '\"$name\" aggiunto';
  }

  @override
  String torrentDuplicate(String name) {
    return '\"$name\" è già nel client';
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
  String get adminLogOut => 'Esci';

  @override
  String get adminConfigGroup => 'Configurazione';

  @override
  String get adminDirectories => 'Cartelle';

  @override
  String get adminUsers => 'Utenti';

  @override
  String get adminDLNA => 'DLNA';

  @override
  String get adminTorrent => 'Torrent';

  @override
  String get adminFederation => 'Federazione';

  @override
  String get adminServerGroup => 'Server';

  @override
  String get adminAbout => 'Informazioni';

  @override
  String get adminSettings => 'Impostazioni';

  @override
  String get adminDatabase => 'Database';

  @override
  String get adminBackups => 'Backup';

  @override
  String get adminTranscoding => 'Transcodifica';

  @override
  String get adminLogs => 'Log';

  @override
  String get adminAccess => 'Accesso admin';

  @override
  String adminAppBarTitle(String label) {
    return 'mStream Admin · $label';
  }

  @override
  String get adminPanelTitle => 'mStream Admin';

  @override
  String get adminLoginErrorRequired => 'Server e nome utente sono obbligatori';

  @override
  String get adminLoginServerURL => 'URL del server';

  @override
  String get adminLoginUsername => 'Nome utente';

  @override
  String get adminLoginPassword => 'Password';

  @override
  String get adminLoginSignIn => 'Accedi';

  @override
  String get adminRetry => 'Riprova';

  @override
  String get adminSaved => 'Salvato';

  @override
  String get adminSave => 'Salva';

  @override
  String get adminClose => 'Chiudi';

  @override
  String get adminPanelMenuItem => 'Pannello admin';

  @override
  String get adminNoLibrariesYetTitle => 'Nessuna libreria';

  @override
  String get adminAddDirectoryHint =>
      'Aggiungi una cartella per iniziare a scansionare la musica nella libreria.';

  @override
  String get adminAddDirectoryButton => 'Aggiungi cartella';

  @override
  String adminRemoveDirectoryTitle(String name) {
    return 'Rimuovere $name?';
  }

  @override
  String get adminRemoveDirectoryWarning =>
      'Questo rimuove la libreria e i brani scansionati dal database. I file su disco restano intatti.';

  @override
  String get adminCancel => 'Annulla';

  @override
  String get adminRemove => 'Rimuovi';

  @override
  String get adminLibraryRemovedToast => 'Libreria rimossa';

  @override
  String get adminDirectoryPathLabel => 'Percorso';

  @override
  String get adminDirectoryTypeLabel => 'Tipo';

  @override
  String get adminFollowSymlinksTitle => 'Segui i link simbolici';

  @override
  String get adminFollowSymlinksSubtitle =>
      'Ha effetto alla prossima scansione';

  @override
  String get adminPickFolderAndNameError =>
      'Scegli una cartella e inserisci un nome';

  @override
  String get adminDirectoryAddedToast =>
      'Cartella aggiunta — scansione avviata';

  @override
  String get adminAddDirectoryDialogTitle => 'Aggiungi cartella';

  @override
  String get adminChooseFolderButton => 'Scegli cartella sul server…';

  @override
  String get adminLibraryNameLabel => 'Nome libreria (vpath)';

  @override
  String get adminLibraryNameHelper => 'Lettere, numeri e trattini';

  @override
  String get adminGrantAllUsersAccessTitle =>
      'Concedi l\'accesso a tutti gli utenti';

  @override
  String get adminAudiobookLibraryTitle => 'Libreria di audiolibri';

  @override
  String get adminAdd => 'Aggiungi';

  @override
  String get adminChooseFolderTitle => 'Scegli una cartella';

  @override
  String get adminSelectFolderButton => 'Seleziona questa cartella';

  @override
  String get adminNoUsersTitle => 'Nessun utente';

  @override
  String get adminNoUsersSubtitle =>
      'Senza utenti il server funziona in modalità aperta/pubblica. Aggiungine uno per richiedere l\'accesso.';

  @override
  String get adminAddUserButton => 'Aggiungi utente';

  @override
  String get adminLibraryAccessDialogTitle => 'Accesso alle librerie';

  @override
  String get adminLibraryAccessUpdatedToast =>
      'Accesso alle librerie aggiornato';

  @override
  String get adminSetPasswordTitle => 'Imposta password';

  @override
  String get adminPasswordUpdatedToast => 'Password aggiornata';

  @override
  String adminDeleteUserTitle(String username) {
    return 'Eliminare $username?';
  }

  @override
  String get adminDeleteUserWarning =>
      'Questo rimuove definitivamente l\'account utente.';

  @override
  String get adminDelete => 'Elimina';

  @override
  String get adminUserDeletedToast => 'Utente eliminato';

  @override
  String get adminStatusPillLabel => 'admin';

  @override
  String get adminDeleteUserMenuItem => 'Elimina utente';

  @override
  String get adminNoLibraryAccessLabel => 'Nessun accesso alle librerie';

  @override
  String get adminLibrariesButton => 'Librerie';

  @override
  String get adminAdminToggleTitle => 'Admin';

  @override
  String get adminMakeDirsToggleTitle => 'Crea cartelle';

  @override
  String get adminUploadToggleTitle => 'Carica';

  @override
  String get adminModifyFilesToggleTitle => 'Modifica file';

  @override
  String get adminServerAudioToggleTitle => 'Audio server';

  @override
  String get adminAddUserDialogTitle => 'Aggiungi utente';

  @override
  String get adminUsername => 'Nome utente';

  @override
  String get adminPassword => 'Password';

  @override
  String get adminLibraryAccessHeader => 'Accesso alle librerie';

  @override
  String get adminUsernamePasswordRequiredError =>
      'Nome utente e password sono obbligatori';

  @override
  String get adminUserCreatedToast => 'Utente creato';

  @override
  String get adminAdministratorToggleTitle => 'Amministratore';

  @override
  String get adminAllowMakeDirectoriesTitle => 'Consenti creazione cartelle';

  @override
  String get adminAllowUploadTitle => 'Consenti caricamento';

  @override
  String get adminAllowServerAudioTitle => 'Consenti audio server';

  @override
  String get adminCreate => 'Crea';

  @override
  String get adminNoLibrariesConfigured => 'Nessuna libreria configurata.';

  @override
  String get adminNewPasswordLabel => 'Nuova password';

  @override
  String get adminLibraryTitle => 'Libreria';

  @override
  String get adminTracksInDatabase => 'Brani nel database';

  @override
  String get adminScanAllButton => 'Scansiona tutto';

  @override
  String get adminScanStarted => 'Scansione avviata';

  @override
  String get adminForceRescan => 'Forza nuova scansione';

  @override
  String get adminFullRescanStarted => 'Scansione completa avviata';

  @override
  String get adminCompressImages => 'Comprimi immagini';

  @override
  String get adminImageCompressionStarted => 'Compressione immagini avviata';

  @override
  String get adminScanOptions => 'Opzioni di scansione';

  @override
  String get adminScanInterval => 'Intervallo scansione (ore, 0 = disattivato)';

  @override
  String get adminBootScanDelay => 'Ritardo scansione all\'avvio (secondi)';

  @override
  String get adminScanCommitInterval => 'Intervallo commit scansione (1–1000)';

  @override
  String get adminScanThreads => 'Thread di scansione (0 = automatico)';

  @override
  String get adminSkipImageExtraction => 'Salta estrazione immagini';

  @override
  String get adminCompressEmbeddedImages => 'Comprimi immagini incorporate';

  @override
  String get adminGenerateWaveforms => 'Genera forme d\'onda dopo la scansione';

  @override
  String get adminAnalyzeBpm => 'Analizza BPM/tonalità (deprecato, inattivo)';

  @override
  String get adminAutomaticAlbumArt => 'Copertine automatiche';

  @override
  String get adminDownloadMissingAlbumArt => 'Scarica le copertine mancanti';

  @override
  String get adminTargetLabel => 'Destinazione';

  @override
  String get adminMissingOnly => 'Solo mancanti';

  @override
  String get adminAllAlbums => 'Tutti gli album';

  @override
  String get adminAlbumsPerRun => 'Album per esecuzione (1–10000)';

  @override
  String get adminAutoDownloadedArtWriteFolder =>
      'Copertina scaricata automaticamente → scrivi nella cartella';

  @override
  String get adminManualArtWriteFolder =>
      'Copertina impostata manualmente → scrivi nella cartella';

  @override
  String get adminManualArtEmbedTag =>
      'Copertina impostata manualmente → incorpora nel tag del file';

  @override
  String get adminArtServices => 'Servizi di copertine';

  @override
  String get adminArtServicesUpdated => 'Servizi di copertine aggiornati';

  @override
  String get adminSharedPlaylists => 'Playlist condivise';

  @override
  String get adminDeleteExpired => 'Elimina scadute';

  @override
  String get adminExpiredSharesDeleted => 'Condivisioni scadute eliminate';

  @override
  String get adminDeleteNeverExpiring => 'Elimina senza scadenza';

  @override
  String get adminEternalSharesDeleted =>
      'Condivisioni senza scadenza eliminate';

  @override
  String get adminNoSharedPlaylists => 'Nessuna playlist condivisa';

  @override
  String adminSharedPlaylistSubtitle(String user, int count, String expiry) {
    return 'di $user · $count brani · scade il $expiry';
  }

  @override
  String get adminShareDeleted => 'Condivisione eliminata';

  @override
  String get adminNetwork => 'Rete';

  @override
  String get adminNetworkSubtitle =>
      'La modifica riavvia il server in modo soft.';

  @override
  String get adminBindAddress => 'Indirizzo di bind';

  @override
  String get adminPort => 'Porta';

  @override
  String get adminTrustProxyHeaders => 'Considera attendibili gli header proxy';

  @override
  String get adminTrustProxyHeadersSubtitle =>
      'Attiva se dietro un reverse proxy (X-Forwarded-*)';

  @override
  String get adminPermissions => 'Autorizzazioni';

  @override
  String get adminAllowUploads => 'Consenti caricamenti';

  @override
  String get adminAllowMakingDirectories => 'Consenti creazione cartelle';

  @override
  String get adminAllowModifyingFiles => 'Consenti modifica file';

  @override
  String get adminMaxRequestSize => 'Dimensione max richiesta';

  @override
  String get adminMaxRequestSizeHelper => 'es. 50MB o 512KB';

  @override
  String get adminHttpUi => 'HTTP e UI';

  @override
  String get adminResponseCompression => 'Compressione risposte';

  @override
  String get adminCompressionNone => 'Nessuna';

  @override
  String get adminCompressionGzip => 'gzip';

  @override
  String get adminCompressionBrotli => 'brotli';

  @override
  String get adminWebUi => 'Interfaccia web';

  @override
  String get adminUiDefault => 'Predefinita';

  @override
  String get adminUiVelvet => 'Velvet';

  @override
  String get adminDatabaseTuning => 'Ottimizzazione database';

  @override
  String get adminSqliteSynchronous => 'Synchronous SQLite';

  @override
  String get adminSyncFull => 'FULL (safest)';

  @override
  String get adminSyncNormal => 'NORMAL (faster)';

  @override
  String get adminCacheSize => 'Dimensione cache (MB, 1–2048)';

  @override
  String get adminLogging => 'Registrazione log';

  @override
  String get adminWriteLogsToDisk => 'Scrivi i log su disco';

  @override
  String get adminLogBufferSize =>
      'Dimensione buffer log (0–10000, 0 = disattivato)';

  @override
  String get adminServerAudio => 'Audio server';

  @override
  String get adminAutoBootServerAudio =>
      'Avvio automatico audio server (lettore Rust)';

  @override
  String get adminRustPlayerPort => 'Porta lettore Rust';

  @override
  String get adminActiveBackend => 'Backend attivo';

  @override
  String get adminPlayer => 'Lettore';

  @override
  String get adminDetectedCliPlayers => 'Lettori CLI rilevati';

  @override
  String get adminNone => 'nessuno';

  @override
  String get adminReDetectPlayers => 'Rileva di nuovo i lettori';

  @override
  String get adminReProbedCliPlayers => 'Lettori CLI rilevati di nuovo';

  @override
  String get adminSslHttps => 'SSL / HTTPS';

  @override
  String get adminEnabled => 'Abilitato';

  @override
  String get adminDisabled => 'Disabilitato';

  @override
  String get adminReplaceCertificate => 'Sostituisci certificato';

  @override
  String get adminSetCertificate => 'Imposta certificato';

  @override
  String get adminSetSslCertificateDialog => 'Imposta certificato SSL';

  @override
  String get adminCertificatePath => 'Percorso certificato';

  @override
  String get adminKeyPath => 'Percorso chiave';

  @override
  String get adminSslConfigured => 'SSL configurato — riavvia per applicare';

  @override
  String get adminRemoveSsl => 'Rimuovi SSL';

  @override
  String get adminSslRemoved => 'SSL rimosso';

  @override
  String get adminSecurity => 'Sicurezza';

  @override
  String get adminJwtSecretLast4 => 'Segreto JWT (ultimi 4)';

  @override
  String get adminRegenerateSecret => 'Rigenera segreto';

  @override
  String get adminSecretRegenerated =>
      'Segreto rigenerato — tutte le sessioni invalidate';

  @override
  String get adminRegenerateJwtSecretDialog => 'Rigenerare il segreto JWT?';

  @override
  String get adminRegenerateJwtSecretDialogBody =>
      'Questo invalida ogni accesso esistente (incluso questo). Tutti dovranno accedere di nuovo.';

  @override
  String get adminRegenerateButton => 'Rigenera';

  @override
  String get adminAllNetworks => 'Tutte le reti';

  @override
  String get adminLocalhostOnly => 'Solo localhost';

  @override
  String get adminIpWhitelist => 'Whitelist IP';

  @override
  String get adminNoneLockAdmin => 'Nessuna (blocca admin)';

  @override
  String get adminNetworkAccess => 'Accesso di rete';

  @override
  String get adminNetworkAccessSubtitle =>
      'Limita quali reti possono raggiungere l\'API admin.';

  @override
  String get adminMode => 'Modalità';

  @override
  String get adminWhitelistedIps => 'IP / CIDR in whitelist';

  @override
  String get adminNoneYet => 'Ancora nessuno';

  @override
  String get adminAddIpOrCidr => 'Aggiungi IP o CIDR';

  @override
  String get adminCidrExample => '192.168.1.0/24';

  @override
  String get adminApply => 'Applica';

  @override
  String get adminDangerZone => 'Zona pericolosa';

  @override
  String get adminLockAdminApi => 'Blocca API admin';

  @override
  String get adminLockAdminApiSubtitle =>
      'Disabilita l\'intera API admin. Non annullabile da qui.';

  @override
  String get adminLockButton => 'Blocca';

  @override
  String get adminLockAdminApiDialog => 'Bloccare l\'API admin?';

  @override
  String get adminLockAdminApiDialogBody =>
      'Questo disabilita l\'intera API /admin per tutti. Non potrai annullarlo da questo pannello — richiede la modifica del file di configurazione del server e il riavvio. Continuare?';

  @override
  String get adminAdminApiLocked => 'API admin bloccata';

  @override
  String get adminAccessUpdated => 'Accesso admin aggiornato';

  @override
  String get adminTranscodingFFmpegTitle => 'FFmpeg';

  @override
  String get adminFFmpegStatusReady => 'Pronto';

  @override
  String get adminFFmpegStatusNotDownloaded => 'Non scaricato';

  @override
  String get adminFFmpegDownloadButton => 'Scarica / aggiorna ffmpeg';

  @override
  String get adminFFmpegDownloadedToast => 'ffmpeg scaricato';

  @override
  String get adminFFmpegAutoUpdateTitle => 'Aggiorna ffmpeg automaticamente';

  @override
  String get adminFFmpegAutoUpdateSubtitle =>
      'Mantieni aggiornato automaticamente l\'ffmpeg incluso';

  @override
  String get adminTranscodingDefaultsTitle => 'Predefiniti';

  @override
  String get adminDefaultCodecLabel => 'Codec predefinito';

  @override
  String get adminDefaultBitrateLabel => 'Bitrate predefinito';

  @override
  String get adminLogsResumeButton => 'Riprendi';

  @override
  String get adminLogsPauseButton => 'Pausa';

  @override
  String get adminClear => 'Cancella';

  @override
  String get adminLogsAutoScrollTitle => 'Scorrimento automatico';

  @override
  String adminLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count righe',
      one: '1 riga',
    );
    return '$_temp0';
  }

  @override
  String get adminLogsDownloadZipButton => 'Scarica zip';

  @override
  String get adminLogsNoEntriesHint => 'Nessuna voce di log';

  @override
  String get adminDlnaModeDisabled => 'Disabilitato';

  @override
  String get adminSamePortAsHttp => 'Stessa porta di HTTP';

  @override
  String get adminSeparatePort => 'Porta separata';

  @override
  String get adminDlnaBrowseFlat => 'Piatto (tutti i brani)';

  @override
  String get adminDlnaBrowseDirectories => 'Cartelle';

  @override
  String get adminDlnaBrowseArtist => 'Per artista';

  @override
  String get adminDlnaBrowseAlbum => 'Per album';

  @override
  String get adminDlnaBrowseGenre => 'Per genere';

  @override
  String get adminDlnaServerTitle => 'Server';

  @override
  String get adminDlnaIdentityTitle => 'Identità';

  @override
  String get adminDlnaFriendlyNameLabel => 'Nome descrittivo';

  @override
  String get adminDlnaDeviceUuidLabel => 'UUID dispositivo';

  @override
  String get adminDlnaDeviceUuidHelper => 'GUID canonico';

  @override
  String get adminDlnaBrowseLayoutTitle => 'Layout di navigazione';

  @override
  String get adminDlnaStructureLabel => 'Struttura';

  @override
  String get adminTestConnection => 'Prova connessione';

  @override
  String get adminKeyNameLabel => 'Nome / etichetta chiave';

  @override
  String get adminMintKey => 'Genera chiave';

  @override
  String get adminTorrentClient => 'Client';

  @override
  String get adminActiveClient => 'Client attivo';

  @override
  String get adminTransmission => 'Transmission';

  @override
  String get adminQbittorrent => 'qBittorrent';

  @override
  String get adminDeluge => 'Deluge';

  @override
  String get adminEnabledFor => 'Abilitato per';

  @override
  String get adminAllUsers => 'Tutti gli utenti';

  @override
  String get adminWhitelistedUsers => 'Utenti in whitelist';

  @override
  String get adminHost => 'Host';

  @override
  String get adminPasswordUnchangedIfBlank => 'invariata se vuota';

  @override
  String get adminRpcPath => 'Percorso RPC';

  @override
  String get adminUseHttps => 'Usa HTTPS';

  @override
  String get adminTest => 'Prova';

  @override
  String adminReachable(String version) {
    return 'Raggiungibile$version';
  }

  @override
  String adminConnectionFailed(String error) {
    return 'Non riuscito: $error';
  }

  @override
  String get adminConnectAndSave => 'Connetti e salva';

  @override
  String adminSaveFailed(String error) {
    return 'Non riuscito: $error';
  }

  @override
  String get adminConnectedAndSaved => 'Connesso e salvato';

  @override
  String get adminDisconnect => 'Disconnetti';

  @override
  String get adminDisconnected => 'Disconnesso';

  @override
  String get adminConfigured => 'Configurato';

  @override
  String get adminNotConfigured => 'Non configurato';

  @override
  String get adminTorrents => 'Torrent';

  @override
  String get adminConnected => 'Connesso';

  @override
  String get adminNoTorrents => 'Nessun torrent';

  @override
  String get adminMstream => 'mStream';

  @override
  String get adminTorrentRemoved => 'Torrent rimosso';

  @override
  String get adminLibraryDaemonPathMapping =>
      'Mappatura percorsi libreria → daemon';

  @override
  String get adminLibraryDaemonPathMappingSubtitle =>
      'Mappa ogni libreria al percorso così come lo vede il daemon torrent.';

  @override
  String get adminAutoDetectAll => 'Rileva tutto automaticamente';

  @override
  String get adminAutoDetectionComplete => 'Rilevamento automatico completato';

  @override
  String get adminVerified => 'verificato';

  @override
  String get adminUnverified => 'non verificato';

  @override
  String get adminSetManually => 'Imposta manualmente';

  @override
  String adminDaemonPathFor(String name) {
    return 'Percorso daemon per \"$name\"';
  }

  @override
  String get adminPathOnDaemonHost => 'Percorso sull\'host del daemon';

  @override
  String get adminVerifyAndSave => 'Verifica e salva';

  @override
  String get adminVpathVerified => 'Verificato';

  @override
  String get adminVpathSavedUnverified => 'Salvato (non verificato)';

  @override
  String get adminDownloadPathTemplates => 'Modelli di percorso download';

  @override
  String adminPathTemplateVars(String vars) {
    return 'Variabili: $vars';
  }

  @override
  String get adminNoLibraries => 'Nessuna libreria';

  @override
  String adminSuggestedTemplate(String template) {
    return 'Suggerito: $template';
  }

  @override
  String get adminTemplateSaved => 'Modello salvato';

  @override
  String get adminNoBackupDestinations => 'Nessuna destinazione di backup';

  @override
  String get adminBackupDestinationInfo =>
      'Aggiungi una destinazione per replicare una libreria in un\'altra cartella.';

  @override
  String get adminAddDestination => 'Aggiungi destinazione';

  @override
  String get adminAddLibraryFirst => 'Aggiungi prima una libreria';

  @override
  String get adminBackupQueue => 'Coda di backup';

  @override
  String adminTasksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attività in coda',
      one: '1 attività in coda',
    );
    return '$_temp0';
  }

  @override
  String adminBackingUp(String library) {
    return 'Backup in corso: $library';
  }

  @override
  String get adminRunning => 'in esecuzione';

  @override
  String adminBackupStats(int done, String total, String stats) {
    return '$done file$total$stats';
  }

  @override
  String get adminBackupDisabled => 'disabilitata';

  @override
  String get adminDestination => 'Destinazione';

  @override
  String get adminTrigger => 'Trigger';

  @override
  String adminDailyTriggerTime(String trigger, String hour) {
    return '$trigger alle $hour:00';
  }

  @override
  String get adminRetention => 'Conservazione';

  @override
  String adminRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String get adminLastRun => 'Ultima esecuzione';

  @override
  String adminLastRunStatus(String status, int files) {
    return '$status · $files copiati';
  }

  @override
  String get adminRunNow => 'Esegui ora';

  @override
  String get adminBackupQueued => 'Backup in coda';

  @override
  String get adminAlreadyRunningSkipped => 'Già in esecuzione — saltato';

  @override
  String get adminHistory => 'Cronologia';

  @override
  String get adminEdit => 'Modifica';

  @override
  String get adminDestinationDeleted => 'Destinazione eliminata';

  @override
  String get adminBackupHistory => 'Cronologia backup';

  @override
  String get adminNoHistoryYet => 'Ancora nessuna cronologia';

  @override
  String get adminEditDestination => 'Modifica destinazione';

  @override
  String get adminAddBackupDestination => 'Aggiungi destinazione di backup';

  @override
  String get adminDestinationPath => 'Percorso destinazione';

  @override
  String get adminBrowseServer => 'Esplora server';

  @override
  String get adminCheckPath => 'Verifica percorso';

  @override
  String get adminTriggerField => 'Trigger';

  @override
  String get adminAfterEachScan => 'Dopo ogni scansione';

  @override
  String get adminDaily => 'Giornaliero';

  @override
  String get adminManualOnly => 'Solo manuale';

  @override
  String get adminRunAtHour => 'Esegui all\'ora: ';

  @override
  String get adminRetentionFieldLabel =>
      'Conservazione (giorni, 0 = mantieni tutto)';

  @override
  String get adminEnabledToggle => 'Abilitata';

  @override
  String get adminDestinationUpdated => 'Destinazione aggiornata';

  @override
  String get adminDestinationCreated => 'Destinazione creata';

  @override
  String get adminPickLibrary => 'Scegli una libreria';

  @override
  String get adminPickDestinationPath => 'Scegli un percorso di destinazione';

  @override
  String adminAboutTitle(String version) {
    return 'mStream v$version';
  }

  @override
  String get adminAboutPort => 'Porta';

  @override
  String get adminSSL => 'SSL';

  @override
  String get adminUI => 'UI';

  @override
  String get adminCompression => 'Compressione';

  @override
  String get adminTrustProxy => 'Proxy attendibile';

  @override
  String get adminYes => 'Sì';

  @override
  String get adminNo => 'No';

  @override
  String get adminSecretLast4 => 'Segreto (ultimi 4)';

  @override
  String get adminUploads => 'Caricamenti';

  @override
  String get adminMakeDirs => 'Crea cartelle';

  @override
  String get adminFileModify => 'Modifica file';

  @override
  String get adminSynchronous => 'Synchronous';

  @override
  String get adminCacheSizeLabel => 'Dimensione cache';

  @override
  String adminCacheSizeMb(int size) {
    return '$size MB';
  }

  @override
  String get adminFederationDescription =>
      'Abbina altri server mStream: emetti chiavi perché leggano le tue librerie, oppure aggiungi i loro ticket per leggere le loro.';

  @override
  String get adminAllowed => 'Consentito';

  @override
  String get adminBackupEnabled => 'attivo';

  @override
  String get adminNotAvailable => 'Non disponibile';

  @override
  String get adminNotMapped => 'non mappato';

  @override
  String get adminExpiryNever => 'mai';

  @override
  String get adminUnknownUser => 'sconosciuto';

  @override
  String get adminFederationEnableTitle => 'Abilita la federazione';

  @override
  String get adminFederationEnableSubtitle =>
      'Consenti a questo server di abbinarsi ad altri server mStream';

  @override
  String get adminFederationEndpointId => 'ID endpoint';

  @override
  String get adminFederationRelay => 'Relay';

  @override
  String get adminFederationOnline => 'Online';

  @override
  String get adminFederationOffline => 'Offline';

  @override
  String get adminFederationStopped => 'Fermo';

  @override
  String get adminFederationUnsupportedTitle => 'Non supportato qui';

  @override
  String get adminFederationUnsupportedBody =>
      'Questa build non ha un endpoint di federazione per la tua piattaforma, quindi non può funzionare qui.';

  @override
  String get adminFederationCopy => 'Copia';

  @override
  String get adminFederationCopied => 'Copiato';

  @override
  String get adminFederationKeysTitle => 'Chiavi emesse';

  @override
  String get adminFederationKeysSubtitle =>
      'Credenziali che altri server usano per leggere da questo';

  @override
  String get adminFederationNoKeys => 'Nessuna chiave emessa';

  @override
  String get adminFederationMintTitle => 'Emetti una chiave';

  @override
  String get adminFederationCopyTicket => 'Mostra ticket';

  @override
  String get adminFederationTicketTitle => 'Ticket';

  @override
  String get adminFederationTicketBody =>
      'Consegnalo all’amministratore dell’altro server. Viene mostrato una sola volta.';

  @override
  String get adminFederationNoTicket =>
      'Nessun ticket disponibile per questa chiave';

  @override
  String get adminFederationEditLimits => 'Modifica i limiti';

  @override
  String get adminFederationLimitsTitle => 'Limiti';

  @override
  String get adminFederationLimitsSaved => 'Limiti salvati';

  @override
  String get adminFederationStreamKbps => 'Tetto per stream (kbps)';

  @override
  String get adminFederationDailyMb => 'Limite giornaliero (MB)';

  @override
  String get adminFederationMaxStreams => 'Stream simultanei';

  @override
  String get adminFederationUnlimitedHint => '0 significa illimitato';

  @override
  String get adminFederationUnlimited => 'illimitato';

  @override
  String adminFederationKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String adminFederationMbPerDay(int mb) {
    return '$mb MB/giorno';
  }

  @override
  String adminFederationStreams(int count) {
    return '$count stream';
  }

  @override
  String adminFederationUsageToday(String used) {
    return 'Oggi: $used';
  }

  @override
  String get adminFederationExpired => 'Scaduta';

  @override
  String get adminFederationBound => 'vincolata';

  @override
  String get adminFederationUnbound => 'non vincolata';

  @override
  String get adminFederationResetBinding => 'Reimposta il vincolo';

  @override
  String get adminFederationResetBindingDone => 'Vincolo reimpostato';

  @override
  String get adminFederationRevoke => 'Revoca';

  @override
  String adminFederationRevokeTitle(String name) {
    return 'Revocare $name?';
  }

  @override
  String get adminFederationRevokeBody =>
      'Gli stream che stanno usando questa chiave verranno interrotti subito.';

  @override
  String get adminFederationRevoked => 'Chiave revocata';

  @override
  String get adminFederationPeersTitle => 'Server che leggi';

  @override
  String get adminFederationPeersSubtitle =>
      'Server che ti hanno dato un ticket e da cui puoi leggere';

  @override
  String get adminFederationNoPeers => 'Nessun peer aggiunto';

  @override
  String get adminFederationAddPeer => 'Aggiungi peer';

  @override
  String get adminFederationAddPeerBody =>
      'Incolla il ticket che ti ha dato l’altro server. Contiene il suo indirizzo e la chiave di accesso.';

  @override
  String get adminFederationTicketLabel => 'Ticket';

  @override
  String get adminFederationPeerNameLabel => 'Nome (facoltativo)';

  @override
  String get adminFederationPeerAdded => 'Peer aggiunto';

  @override
  String get adminFederationPeerRemoved => 'Peer rimosso';

  @override
  String adminFederationRemovePeerTitle(String name) {
    return 'Rimuovere $name?';
  }

  @override
  String get adminFederationTestOk => 'Peer raggiungibile';

  @override
  String adminFederationLastSeen(String when) {
    return 'Visto l’ultima volta $when';
  }

  @override
  String get adminFederationNeverSeen => 'Mai raggiunto';

  @override
  String get adminFederationUseDiscovery => 'Invia query di scoperta';

  @override
  String get adminFederationUseDiscoverySubtitle =>
      'Condivide con questo peer ciò che stai ascoltando';
}
