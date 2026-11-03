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
  String get lyricsTitle => 'Testo';

  @override
  String get lyricsEmpty => 'Nessun testo trovato per questo brano';

  @override
  String get lyricsError => 'Impossibile caricare il testo';

  @override
  String get lyricsRetry => 'Riprova';

  @override
  String get eqTitle => 'Equalizzatore';

  @override
  String get eqOnlyAndroid => 'L’equalizzatore è disponibile solo su Android.';

  @override
  String get eqNeedsPlayback =>
      'L\'equalizzatore di questo telefono comunica le sue bande solo quando l\'audio è in riproduzione. Il preset salvato viene applicato appena compaiono.';

  @override
  String eqInitFailed(String error) {
    return 'Impossibile inizializzare l’equalizzatore:\n$error';
  }

  @override
  String get eqNoBands =>
      'Il driver audio di questo dispositivo non segnala bande di equalizzazione.';

  @override
  String get eqPresetFlat => 'Piatto';

  @override
  String get eqPresetNormal => 'Normale';

  @override
  String get eqPresetClassical => 'Classica';

  @override
  String get eqPresetDance => 'Dance';

  @override
  String get eqPresetFolk => 'Folk';

  @override
  String get eqPresetHeavyMetal => 'Heavy metal';

  @override
  String get eqPresetHipHop => 'Hip hop';

  @override
  String get eqPresetJazz => 'Jazz';

  @override
  String get eqPresetPop => 'Pop';

  @override
  String get eqPresetRock => 'Rock';

  @override
  String get eqPresetCustom => 'Personalizzato';

  @override
  String get eqSaveAsPreset => 'Salva come preset';

  @override
  String get eqSavePresetTitle => 'Salva preset';

  @override
  String get eqRenamePresetTitle => 'Rinomina preset';

  @override
  String get eqPresetNameLabel => 'Nome';

  @override
  String get eqSavePresetHint =>
      'Salvato su questo telefono, dopo i preset integrati. Tieni premuto il suo chip in seguito per rinominarlo o eliminarlo.';

  @override
  String get eqReplacePreset => 'Sostituisci';

  @override
  String get eqPresetNameTaken => 'Un altro preset salvato ha già questo nome.';

  @override
  String eqDeletePresetConfirm(String name) {
    return 'Eliminare “$name”?';
  }

  @override
  String get eqHoldToCompare => 'Tieni premuto per confrontare';

  @override
  String get eqHoldToCompareHint =>
      'Tieni premuto per sentire il suono senza l\'equalizzatore.';

  @override
  String get eqOptionsTitle => 'Opzioni dell\'equalizzatore';

  @override
  String get eqPreventClipping => 'Evita la distorsione';

  @override
  String get eqPreventClippingHint =>
      'Limita i picchi quando le bande vengono alzate.';

  @override
  String get eqShowValues => 'Mostra sempre i valori delle bande';

  @override
  String get eqShowValuesHint =>
      'Un numero sopra ogni banda, non solo durante il trascinamento.';

  @override
  String get eqOutputsTitle => 'Uscite';

  @override
  String get eqOutputsRowOff => 'Disattivato: una curva per tutte le uscite';

  @override
  String eqOutputsNow(String name) {
    return '$name adesso';
  }

  @override
  String get eqOutputsSwitch => 'Cambia automaticamente';

  @override
  String get eqOutputsSwitchHint =>
      'Quando cambia l\'uscita, viene applicata la sua curva. Trascinare nella pagina dell\'equalizzatore modifica l\'uscita in riproduzione.';

  @override
  String get eqOutputsRemembered => 'Uscite memorizzate';

  @override
  String get eqOutputSpeaker => 'Altoparlante del telefono';

  @override
  String get eqOutputWired => 'Cuffie con filo';

  @override
  String get eqOutputUsb => 'Audio USB';

  @override
  String get eqOutputHdmi => 'HDMI';

  @override
  String get eqOutputBluetooth => 'Bluetooth';

  @override
  String get eqOutputOther => 'Altra uscita';

  @override
  String get eqOutputPlayingNow => 'in riproduzione';

  @override
  String eqOutputLastUsed(String date) {
    return 'ultimo uso $date';
  }

  @override
  String get eqOutputsEmpty =>
      'Le uscite compaiono qui man mano che le usi per ascoltare.';

  @override
  String eqOutputForgetConfirm(String name) {
    return 'Dimenticare “$name”? Tornerà come nuova uscita alla prossima connessione.';
  }

  @override
  String get eqOutputForget => 'Dimentica';

  @override
  String eqOutputPickPreset(String name) {
    return 'Preset per $name';
  }

  @override
  String get eqOutputsHint =>
      'Tocca un\'uscita per scegliere il suo preset. Scorrila via per dimenticarla.';

  @override
  String eqEnabledOnOutput(String name) {
    return 'Attivo — $name';
  }

  @override
  String get eqOutputNowPill => 'Adesso';

  @override
  String get eqNeedsPlaybackTitle => 'Avvia un brano per impostare le bande';

  @override
  String get eqPlayQueue => 'Riproduci la coda';

  @override
  String eqPlayQueueHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return 'Riprende da dove eri rimasto · $_temp0';
  }

  @override
  String get eqDisabledHint => 'Attiva l’equalizzatore per regolare le bande.';

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
  String get settingsSectionBrowse => 'Libreria';

  @override
  String get settingsTheme => 'Tema';

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
      'Quando cambi le impostazioni di transcodifica — selezionato: ricarica subito l’intera coda (il brano in riproduzione si ricarica brevemente); deselezionato: cambiano solo i brani successivi, quello attuale termina invariato.';

  @override
  String get settingsTapBehavior => 'Quando tocchi un brano';

  @override
  String get settingsStartupPage => 'Schermata iniziale';

  @override
  String get tapSubtitleAddToQueue => 'Lo aggiunge in fondo alla coda';

  @override
  String get tapSubtitlePlayFromHere =>
      'Sostituisce la coda e riproduce da quel brano';

  @override
  String get tapSubtitleAppendAndJump =>
      'Lo aggiunge in fondo alla coda e lo riproduce subito';

  @override
  String get settingsVisualizerSource => 'Sorgente audio';

  @override
  String get visualizerSourceSubtitleSynthesized => 'Nessun permesso richiesto';

  @override
  String get visualizerSourceSubtitleReal =>
      'Richiede il permesso del microfono, ma non lo usa mai';

  @override
  String get settingsAlbumGrid => 'Album a griglia';

  @override
  String get settingsFileMetadata => 'Info brani in Esplora file';

  @override
  String get settingsLetterStrip => 'Barra A–Z';

  @override
  String get settingsLetterStripSide => 'Lato';

  @override
  String get settingsLetterStripLeft => 'Sinistra';

  @override
  String get settingsLetterStripRight => 'Destra';

  @override
  String get settingsReset => 'Ripristina le impostazioni';

  @override
  String get settingsResetDone => 'Impostazioni ripristinate';

  @override
  String get realAudioDialogTitle => 'Usare l’audio reale?';

  @override
  String get realAudioDialogBody =>
      'Per reagire al brano in riproduzione, il visualizzatore legge l’uscita audio di mStream stesso: Android lo consente solo con il permesso del microfono.';

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
  String get visualizerClose => 'Chiudi visualizzatore';

  @override
  String get visualizerPreviousPreset => 'Preset precedente';

  @override
  String get visualizerNextPreset => 'Preset successivo';

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
  String get fieldPasswordShow => 'Mostra password';

  @override
  String get fieldPasswordHide => 'Nascondi password';

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
  String autoDjSongsPerFetchValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return '$_temp0';
  }

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Mixaggio armonico';

  @override
  String get autoDjHarmonicHint =>
      'Brano successivo in una tonalità compatibile';

  @override
  String get autoDjDurationRange => 'Durata';

  @override
  String get autoDjMoodTitle => 'Filtri intelligenti';

  @override
  String get autoDjGenreLoadError => 'Impossibile caricare i generi';

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
  String get searchCategoriesTooltip => 'Cosa cercare';

  @override
  String get searchCategoriesHeader => 'Cerca in';

  @override
  String get searchCategoryArtists => 'Artisti';

  @override
  String get searchCategoryAlbums => 'Album';

  @override
  String get searchCategorySongs => 'Brani';

  @override
  String get searchCategoryFiles => 'File';

  @override
  String get searchCategoryLyrics => 'Testi';

  @override
  String searchSubheaderResults(String term) {
    return 'Risultati per “$term”';
  }

  @override
  String searchSubheaderCategories(String categories) {
    return 'Ricerca in: $categories';
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
  String get queueEmptyDjHint =>
      'Auto DJ è attivo e ha bisogno di un brano iniziale.';

  @override
  String get queueEmptyDjRandom => 'Brano a caso';

  @override
  String get queueEmptyDjChoose => 'Scegli un brano';

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
  String get browserGenres => 'Generi';

  @override
  String get genreSourceTags => 'Tag';

  @override
  String get genreSourceGenerated => 'Generati';

  @override
  String get genreSourceBoth => 'Entrambi';

  @override
  String get genreSourceMixed => 'Misto';

  @override
  String get genreSourceLabel => 'Origine dei generi';

  @override
  String get moodFilters => 'Filtri';

  @override
  String get moodValenceGroup => 'Allegro, neutro o triste';

  @override
  String get moodEnergyGroup => 'Rilassato, neutro o aggressivo';

  @override
  String get moodVoiceGroup => 'Strumentale o voce';

  @override
  String get moodTagsGroup => 'Tag';

  @override
  String get moodHappy => 'Allegro';

  @override
  String get moodNeutral => 'Neutro';

  @override
  String get moodSad => 'Triste';

  @override
  String get moodRelaxed => 'Rilassato';

  @override
  String get moodAggressive => 'Aggressivo';

  @override
  String get moodInstrumental => 'Strumentale';

  @override
  String get moodVocals => 'Voce';

  @override
  String get moodAcoustic => 'Acustico';

  @override
  String get moodParty => 'Festa';

  @override
  String get moodDanceable => 'Ballabile';

  @override
  String get moodStrict => 'Rigoroso';

  @override
  String get moodStandard => 'Standard';

  @override
  String get moodLoose => 'Flessibile';

  @override
  String get moodStrictnessGroup => 'Rigoroso, standard o flessibile';

  @override
  String get moodSort => 'Ordina';

  @override
  String get moodSortRating => 'Valutazione';

  @override
  String get moodSortNewest => 'Più recenti';

  @override
  String get moodSortMatch => 'Corrispondenza';

  @override
  String get browserRecent => 'Recenti';

  @override
  String get browserRated => 'Valutati';

  @override
  String get browserSectionLibrary => 'Libreria';

  @override
  String get browserSectionListen => 'Ascolta';

  @override
  String get browserSectionNetwork => 'Rete';

  @override
  String get browserSectionServer => 'Server';

  @override
  String get browserFederation => 'Federazione';

  @override
  String get browserAutoDjOn => 'Attivo';

  @override
  String get browserAutoDjOff => 'Disattivo';

  @override
  String browserSharedLibraries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count librerie condivise',
      one: '1 libreria condivisa',
    );
    return '$_temp0';
  }

  @override
  String get browserSearch => 'Cerca';

  @override
  String get browserWelcomeTitle => 'Benvenuto in mStream';

  @override
  String get browserWelcomeSubtitle => 'Tocca qui per aggiungere un server';

  @override
  String get settingsVisualizerKnobs => 'Cursori di regolazione';

  @override
  String get settingsVisualizerKnobsSubtitle => 'Solo ShaderToy';

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
  String get settingsCastQualitySubtitle4k =>
      'Serve un Chromecast 4K; pesa di più sul telefono';

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
  String get storageSdSwitchTitle => 'Salva sulla scheda SD';

  @override
  String get storageSdSwitchSubtitle =>
      'Salvato nella cartella dell’app sulla scheda SD — nessun permesso richiesto, ma viene rimosso se disinstalli l’app.';

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
  String get castVisualizerSubtitle => 'Solo Chromecast';

  @override
  String get castThisDevice => 'Questo dispositivo';

  @override
  String get visualizerNoKnobs => 'Questo shader non ha cursori.';

  @override
  String get nowPlaying => 'In riproduzione';

  @override
  String get settingsPlayerLayout => 'Layout della schermata In riproduzione';

  @override
  String get playerLayoutSmall => 'Piccolo';

  @override
  String get playerLayoutMedium => 'Medio';

  @override
  String get playerLayoutLarge => 'Grande';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get queueNothingToDownloadEmpty =>
      'La coda è vuota — niente da scaricare';

  @override
  String get queueNothingToDownloadSaved =>
      'Niente da scaricare — i brani sono già salvati';

  @override
  String get settingsAccentColor => 'Colore d’accento';

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
      'Connessione rapida è attiva su questo server, ma non ha condiviso un codice di associazione. Accedi come amministratore o chiedi all’operatore di attivare la condivisione del codice.';

  @override
  String get settingsResumeQueue => 'Riprendi la coda all’avvio';

  @override
  String get settingsOfflineQueue => 'Scarica la coda';

  @override
  String get settingsOfflineQueueSubtitle =>
      'La riproduzione continua se cade la connessione.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Solo Wi-Fi';

  @override
  String get settingsAutoDownloadCap => 'Limite di download';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Illimitato';

  @override
  String get settingsAutoDownloadCapField => 'Brani';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Quanti brani tenere scaricati, contando da quello in riproduzione. I più vecchi fuori dal limite vengono eliminati quando ne arrivano di nuovi.';

  @override
  String get downloadWaitingWifi => 'In attesa del Wi-Fi';

  @override
  String get settingsRatingHalf => 'Valutazioni a mezza stella';

  @override
  String get settingsRatingHalfSubtitle => 'Tieni premuta una stella';

  @override
  String get ratingTitle => 'Valuta';

  @override
  String get ratingFailed => 'Impossibile salvare la valutazione';

  @override
  String get diagnosticsTitle => 'Diagnostica';

  @override
  String get diagnosticsEnable => 'Abilita i log';

  @override
  String get diagnosticsHint =>
      'I log restano sul tuo dispositivo. I token vengono nascosti prima di copiare o condividere.';

  @override
  String get diagnosticsVerbose => 'Log dettagliati';

  @override
  String get diagnosticsVerboseHint =>
      'Registra anche eventi molto frequenti, come i cambi di focus dell’app. Serve solo per diagnosticare un problema di riproduzione.';

  @override
  String get diagnosticsCopy => 'Copia';

  @override
  String get diagnosticsShare => 'Condividi';

  @override
  String get diagnosticsClear => 'Cancella';

  @override
  String get diagnosticsCopied => 'Log copiati negli appunti';

  @override
  String get diagnosticsEmpty => 'Ancora nessun log';

  @override
  String get storageAppExternal => 'Esterna dell’app';

  @override
  String get storageAppSdCard => 'Scheda SD dell’app';

  @override
  String get selfSignedTitle => 'Consenti certificato autofirmato';

  @override
  String get selfSignedSubtitle =>
      'Salta la convalida TLS per questo server. Attiva solo su una rete affidabile.';

  @override
  String get importedShadersTitle => 'Shader importati';

  @override
  String get importedShadersRescan => 'Riscansiona cartella';

  @override
  String get importedShadersDropHint =>
      'Inserisci file .glsl in questa cartella, poi Riscansiona:';

  @override
  String get importedShadersCopyPath => 'Copia percorso';

  @override
  String get importedShadersReachableHint =>
      'Raggiungibile via USB. Disinstallando mStream viene eliminata.';

  @override
  String get importedShadersRemove => 'Elimina';

  @override
  String get importedShadersEmptyTitle => 'Ancora nessuno shader';

  @override
  String get importedShadersEmptyBody =>
      'Copia file .glsl in stile Shadertoy nella cartella sopra, poi tocca Riscansiona.';

  @override
  String get importedShadersInvalid =>
      'Potrebbe non funzionare: manca mainImage o main';

  @override
  String get importedShadersImportDownloads => 'Importa .glsl da Download';

  @override
  String importedShadersDownloadsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shader importati',
      one: '$count shader importato',
    );
    return '$_temp0';
  }

  @override
  String get importedShadersDownloadsNone =>
      'Nessun nuovo file .glsl in Download';

  @override
  String get importedShadersDownloadsNoPermission =>
      'Serve il permesso di archiviazione per leggere Download';

  @override
  String get addServerTabUrl => 'URL del server';

  @override
  String get addServerTabQuickConnect => 'Connessione rapida';

  @override
  String get irohPairingHeader => 'Connetti con un codice di associazione';

  @override
  String get irohPairingBody =>
      'Attiva \"Remote Access\" (accesso remoto) sul server, poi incolla il suo codice di associazione o scansiona il QR.';

  @override
  String get irohPairingCodeLabel => 'Codice di associazione';

  @override
  String get irohPairingCodeHint =>
      'Incolla il codice dal pannello Remote Access del server';

  @override
  String get irohShowPairingCode => 'Mostra codice di associazione';

  @override
  String get irohQrBody =>
      'Scansionalo con l’app mStream su un altro dispositivo per collegarlo a questo server, oppure copia il codice e incollalo lì.';

  @override
  String get irohQrCaution =>
      'Chiunque abbia questo codice può connettersi al tuo server.';

  @override
  String get irohScanQr => 'Scansiona QR';

  @override
  String get irohPaste => 'Incolla';

  @override
  String get irohTestConnection => 'Prova connessione';

  @override
  String get irohTesting => 'Prova in corso…';

  @override
  String get irohScannerTitle => 'Scansiona QR di associazione';

  @override
  String get irohQrAndroidOnly =>
      'La scansione QR non è disponibile su questo dispositivo.';

  @override
  String get irohAndroidOnly =>
      'Connessione rapida non è disponibile su questo dispositivo.';

  @override
  String get irohCameraPermission =>
      'Per scansionare un codice serve il permesso della fotocamera.';

  @override
  String get irohPasteFirst =>
      'Prima incolla o scansiona un codice di associazione.';

  @override
  String get irohTestFirst => 'Prima prova la connessione.';

  @override
  String get irohTestConnected => 'Connesso tramite il tunnel iroh';

  @override
  String irohTestConnectedVersion(String version) {
    return 'Connesso tramite il tunnel iroh — mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · diretta';

  @override
  String get irohPathSuffixRelay => ' · tramite relay';

  @override
  String get irohTunnelNoAnswer =>
      'The tunnel connected, but the server closed the request without answering. On the server, check the bind address and port mStream listens on (the tunnel reaches it at 127.0.0.1), then try again.';

  @override
  String get irohTunnelTimeout =>
      'Tunnel aperto, ma il server non ha risposto in tempo.';

  @override
  String irohTunnelTestFailed(String error) {
    return 'Prova del tunnel non riuscita: $error';
  }

  @override
  String get irohSignInHeader => 'Accedi';

  @override
  String get irohSigningIn => 'Accesso in corso…';

  @override
  String get irohSignInSave => 'Accedi e salva';

  @override
  String get irohSignInTimeout => 'Tempo scaduto per l’accesso.';

  @override
  String irohSignInFailed(String error) {
    return 'Accesso non riuscito: $error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return 'Accesso non riuscito (HTTP $status). Controlla nome utente e password.';
  }

  @override
  String get irohBannerConnecting => 'Connessione al server…';

  @override
  String get irohBannerReconnecting => 'Riconnessione al server…';

  @override
  String get irohBannerDisconnected => 'Disconnesso dal server.';

  @override
  String get irohBannerRelay => 'Connesso tramite relay — percorso più lento.';

  @override
  String get irohBannerRepair =>
      'L’associazione del server è cambiata — riassocia per riconnetterti.';

  @override
  String get irohRepairAction => 'Riassocia';

  @override
  String get irohRetry => 'Riprova';

  @override
  String get irohRepairTitle => 'Riassocia server';

  @override
  String get irohRepairBody =>
      'Il codice di associazione di questo server è cambiato (il suo segreto è stato rinnovato). Incolla o scansiona il nuovo codice dal pannello Remote Access del server.';

  @override
  String get irohRepairFailed =>
      'Impossibile connettersi con quel codice — controllalo e riprova.';

  @override
  String get irohPathDirect => 'Diretta';

  @override
  String get irohPathRelay => 'Relay';

  @override
  String get irohCastUnavailable =>
      'La trasmissione a dispositivi esterni non è disponibile per i server peer-to-peer (iroh) — la riproduzione resta su questo dispositivo.';

  @override
  String get irohShareUnavailable =>
      'La condivisione non è disponibile per i server peer-to-peer (iroh) — non hanno un URL pubblico a cui collegarsi.';

  @override
  String get discoverTitle => 'Altri simili';

  @override
  String get discoverPageTitle => 'Scopri';

  @override
  String discoverPageWindowDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String get discoverPageWindowAll => 'Sempre';

  @override
  String discoverPageWidened(String window) {
    return 'Niente negli ultimi $window, quindi questi vengono da prima.';
  }

  @override
  String get discoverPageBasedOn => 'In base a';

  @override
  String get discoverPageBasedOnLast => 'In base agli ultimi';

  @override
  String get discoverPageBasedOnAllTime => 'Periodo';

  @override
  String get discoverPageMoreOptions => 'Altre opzioni';

  @override
  String get discoverPageNewSeeds => 'Nuovi brani di partenza';

  @override
  String get discoverPageAlbumsLibrary => 'Album dalla tua libreria';

  @override
  String discoverPageAlbumsPeer(String name) {
    return 'Album da $name';
  }

  @override
  String get discoverPageAlbumsPeers => 'Album dai server collegati';

  @override
  String get discoverPageSongsLibrary => 'Brani dalla tua libreria';

  @override
  String discoverPageSongsPeer(String name) {
    return 'Brani da $name';
  }

  @override
  String get discoverPageSongsPeers => 'Brani dai server collegati';

  @override
  String get discoverPageLibraryNothing =>
      'Niente di nuovo nella tua libreria somiglia a questi brani.';

  @override
  String get discoverPagePeersQuiet =>
      'Al momento niente dai tuoi server collegati.';

  @override
  String get discoverPagePeersFailed =>
      'Impossibile raggiungere i tuoi server collegati.';

  @override
  String get discoverPageSaveAsPlaylist => 'Salva come playlist';

  @override
  String get discoverPageBrowseLibrary => 'Sfoglia la libreria';

  @override
  String get discoverPageAgoToday => 'oggi';

  @override
  String get discoverPageAgoYesterday => 'ieri';

  @override
  String discoverPageAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesi fa',
      one: '1 mese fa',
    );
    return '$_temp0';
  }

  @override
  String discoverPageAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anni fa',
      one: '1 anno fa',
    );
    return '$_temp0';
  }

  @override
  String get discoverPageRandomTitle =>
      'Ascolta qualche brano fino in fondo e questa pagina imparerà i tuoi gusti';

  @override
  String get discoverPageRandomBody =>
      'Scopri si basa sui brani che ascolti fino in fondo. I brani saltati non contano mai. Finché non ce ne sono, ecco suggerimenti attorno a un brano a caso della tua libreria.';

  @override
  String get discoverPageAnotherPick => 'Un altro';

  @override
  String get discoverPageChooseSong => 'Scegli un brano…';

  @override
  String get discoverPageError =>
      'Impossibile caricare Scopri. Controlla la connessione e riprova.';

  @override
  String get discoverPageRetry => 'Riprova';

  @override
  String get discoverPagePickedHeader => 'Scelti per questa visita';

  @override
  String get discoverPageRandomHeader => 'Scelta casuale';

  @override
  String get discoverPageDroppedHeader => 'Esclusi';

  @override
  String get discoverPageDroppedNote => 'riattivane uno per riprenderlo';

  @override
  String discoverPagePlayedTimes(int count) {
    return 'ascoltato $count×';
  }

  @override
  String get discoverPageListenedTo => 'ascoltato';

  @override
  String get discoverPageNotAnalyzed => 'non ancora analizzato';

  @override
  String get discoverPageAddOwn => 'Aggiungi il tuo';

  @override
  String get discoverPageAddOwnSub => 'un brano di cui vuoi di più';

  @override
  String get discoverPagePickSong => 'Scegli un brano…';

  @override
  String get discoverPagePickSongSub =>
      'cerca nella libreria o prendine uno a caso';

  @override
  String discoverPageUseThese(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usa questi $count',
      one: 'Usa questo 1',
    );
    return '$_temp0';
  }

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
      'Questo server non ha ancora analizzato alcuna musica, quindi non c’è nulla attraverso cui costruire un percorso. Funzionerà quando la scansione di scoperta sarà stata eseguita.';

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
  String get autoDjSonicSeedLabel => 'Brano di partenza';

  @override
  String get autoDjSonicSeedNone =>
      'Nessun brano di partenza — il brano in riproduzione àncora la sessione.';

  @override
  String get autoDjSonicSeedBanner =>
      'Scegli il brano di partenza — tocca un brano ovunque nella libreria';

  @override
  String get autoDjSonicSeedSearchHint => 'Cerca un brano…';

  @override
  String get autoDjSonicSeedRandom => 'Brano casuale';

  @override
  String get autoDjSonicSeedRemove => 'Rimuovi brano di partenza';

  @override
  String get autoDjSonicSeedFailed => 'Impossibile ottenere un brano';

  @override
  String get autoDjSeedNoMatch => 'Nessun brano corrisponde ai filtri';

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
  String get autoDjSonicAnchorRolling => 'Segui l’atmosfera';

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
      'Scegli il brano di partenza — tocca un brano ovunque nella libreria';

  @override
  String get pathPickBannerEnd =>
      'Scegli il brano di arrivo — tocca un brano ovunque nella libreria';

  @override
  String get pathNothingPlaying => 'Nessuna riproduzione in corso';

  @override
  String pathPickOnServer(String server) {
    return 'Scegli un brano su $server';
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
      'Il colore d’accento evidenzia pulsanti, cursori e i comandi del player. Toccane uno per provarlo.';

  @override
  String get setupPlaybackTitle => 'Quando tocchi un brano';

  @override
  String get setupOfflineTitle => 'Tieni la coda disponibile offline';

  @override
  String get realAudioNoMic => 'mStream non usa mai il tuo microfono.';

  @override
  String get playlistEmpty => 'La playlist è vuota';

  @override
  String get trackRating => 'Valutazione';

  @override
  String albumDiscNumber(int n) {
    return 'Disco $n';
  }

  @override
  String get autoDjStartPickBanner =>
      'Scegli il brano iniziale — tocca un brano ovunque nella libreria';

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
    return '“$name” non è un file .torrent';
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
  String get settingsTorrentDefaultTitle => 'App predefinita per i torrent';

  @override
  String get settingsTorrentDefaultSub => 'Apre le impostazioni di Android';

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
    return 'tramite $parent';
  }

  @override
  String get browserFederatedReadOnly => 'Server in sola lettura';

  @override
  String get browserFederatedReadOnlyNote =>
      'Playlist e valutazioni restano sul tuo server';

  @override
  String get federatedShareUnavailable =>
      'I brani di un server condiviso non possono essere condivisi da qui — si trovano nella libreria di qualcun altro.';

  @override
  String get federatedForget => 'Dimentica';

  @override
  String get federatedHide => 'Nascondi dal selettore';

  @override
  String get federatedShow => 'Mostra nel selettore';

  @override
  String federatedNoLongerListed(String parent) {
    return 'Non più condiviso da $parent';
  }

  @override
  String get federationTitle => 'Federazione';

  @override
  String get federationStatusOn => 'Attiva · connessa al relay';

  @override
  String get federationStatusConnecting => 'Attiva · connessione…';

  @override
  String get federationStatusOff => 'Disattivata';

  @override
  String get federationStatusUnavailable =>
      'Non disponibile su questa piattaforma';

  @override
  String get federationSharedWithYou => 'Condiviso con te';

  @override
  String get federationRequestsSection => 'Richieste';

  @override
  String get federationYourSharedLibraries => 'Le tue librerie condivise';

  @override
  String get federationAddPeer => 'Aggiungi un peer';

  @override
  String get federationShareLibrary => 'Condividi una libreria';

  @override
  String get federationNoPeersYet =>
      'Nessuno condivide ancora nulla con questo server.';

  @override
  String get federationNoKeysYet =>
      'Ancora nessun ticket — condividi una libreria per crearne uno.';

  @override
  String get federationNoRequests =>
      'Ancora nessuna richiesta — i server della rete di scoperta possono trovarti qui.';

  @override
  String get federationClipboardTicket => 'Ticket negli appunti';

  @override
  String federationTicketPreview(String name, String libraries) {
    return '$name · condivide $libraries';
  }

  @override
  String federationTicketPreviewNoLibraries(String name) {
    return '$name';
  }

  @override
  String get federationUnnamedServer => 'Server senza nome';

  @override
  String get federationAddPeerAction => 'Aggiungi peer';

  @override
  String get federationPeerLive => 'attivo';

  @override
  String get federationPeerConnecting => 'connessione…';

  @override
  String get federationPeerDirectTunnel => 'tunnel diretto';

  @override
  String federationPeerViaParent(String parent) {
    return 'tramite $parent';
  }

  @override
  String federationPeerViaTunnel(String parent) {
    return 'tramite il tunnel di $parent';
  }

  @override
  String get federationPeerMissing => 'non più condiviso';

  @override
  String get federationPeerHidden => 'nascosto dal selettore';

  @override
  String federationMemberNote(String server) {
    return 'La condivisione spetta all’amministratore. Creare ticket, aggiungere peer e rispondere alle richieste di associazione richiede l’accesso come amministratore su $server — lo stesso che apre il pannello di amministrazione.';
  }

  @override
  String get federationRestrictedNote =>
      'Questo server accetta chiamate di amministrazione solo dalla propria rete. Collegati da casa per gestire la condivisione da qui.';

  @override
  String get federationDisabledNote =>
      'L’API di amministrazione è disattivata su questo server.';

  @override
  String get federationUnsupportedNote =>
      'Questo server è troppo vecchio per gestire la federazione dall’app. Aggiorna mStream.';

  @override
  String get federationLoadFailed => 'Impossibile raggiungere il server.';

  @override
  String get federationRetry => 'Riprova';

  @override
  String get federationOffTitle =>
      'Condividi librerie con i server dei tuoi amici';

  @override
  String get federationOffBody =>
      'Associa due server mStream per ascoltare la musica l’uno dell’altro. Ci si scambia dei ticket — inviati per messaggio, scansionati, incollati.';

  @override
  String get federationOffPoint1Title => 'Sola lettura, cifratura end-to-end';

  @override
  String get federationOffPoint1Body =>
      'Playlist e valutazioni non lasciano mai il tuo server';

  @override
  String get federationOffPoint2Title => 'Niente port forwarding né DNS';

  @override
  String get federationOffPoint2Body =>
      'iroh trova la strada — diretta quando può, tramite relay quando serve';

  @override
  String get federationOffPoint3Title => 'Ticket revocabili';

  @override
  String get federationOffPoint3Body =>
      'Ognuno si usa una volta sola e si può bloccare in qualsiasi momento';

  @override
  String get federationOffAdminOnly =>
      'Solo l’amministratore del server può attivarla.';

  @override
  String federationOffMemberNote(String server) {
    return 'La federazione è disattivata su $server. L’amministratore può attivarla.';
  }

  @override
  String get federationTurnOn => 'Attiva la federazione';

  @override
  String get federationUnavailableNote =>
      'Il componente iroh non ha una build per il sistema/CPU di questo server, quindi l’endpoint di federazione non può funzionare qui.';

  @override
  String get federationTurnedOn => 'La federazione è attiva';

  @override
  String get federationTurnedOff => 'La federazione è disattivata';

  @override
  String get federationToggleFailed =>
      'Impossibile modificare l’impostazione di federazione.';

  @override
  String get federationSettingsTitle => 'Impostazioni federazione';

  @override
  String get federationSwitchSubtitle =>
      'Peer-to-peer, cifrato end-to-end. Niente port forwarding, niente DNS.';

  @override
  String get federationStatusSection => 'Stato';

  @override
  String get federationConnectedRelay => 'Connesso al relay';

  @override
  String get federationNotRunning => 'Endpoint non attivo';

  @override
  String get federationEndpointId => 'ID endpoint';

  @override
  String get federationEndpointCopied => 'ID endpoint copiato';

  @override
  String get federationPairingRequestsSection => 'Richieste di associazione';

  @override
  String get federationRequestsInboxTitle =>
      'Accetta richieste dalla rete di scoperta';

  @override
  String get federationRequestsInboxSubtitle =>
      'Disattivato per impostazione predefinita. Se disattivato, le nuove richieste vengono rifiutate a livello di trasporto; le risposte alle tue richieste arrivano comunque.';

  @override
  String get federationInboxFailed =>
      'Impossibile modificare la casella delle richieste.';

  @override
  String get federationDefaultsSection =>
      'Valori predefiniti per i nuovi ticket';

  @override
  String get federationDefaultsNote =>
      'Dalla configurazione del server — ogni ticket può cambiarli';

  @override
  String get federationOffWarning =>
      'Disattivare la federazione interrompe tutti i collegamenti con i peer e nasconde i tuoi ticket finché non viene riattivata. I peer conservano i loro ticket.';

  @override
  String federationRequestWantsToPair(String name) {
    return '$name vuole associarsi';
  }

  @override
  String federationRequestToName(String name) {
    return 'Richiesta a $name';
  }

  @override
  String federationRequestOffers(String libraries) {
    return 'Offre $libraries';
  }

  @override
  String get federationRequestOffersNothing => 'Non offre nulla';

  @override
  String federationRequestYouOffered(String libraries) {
    return 'Hai offerto $libraries';
  }

  @override
  String get federationRequestYouOfferedNothing => 'Non hai offerto nulla';

  @override
  String get federationReqSending => 'invio…';

  @override
  String get federationReqWaiting => 'in attesa di risposta';

  @override
  String get federationReqSharingBack => 'condivisione in cambio…';

  @override
  String get federationReqNeedsAnswer => 'attende la tua risposta';

  @override
  String get federationReqSendingTicket => 'invio del tuo ticket…';

  @override
  String get federationReqWaitingShare => 'in attesa della loro condivisione';

  @override
  String get federationReqDeclined => 'rifiutata';

  @override
  String get federationReqYouDeclined => 'rifiutata da te';

  @override
  String get federationReqInboxClosed => 'la loro casella è chiusa';

  @override
  String get federationReqFederated => 'federato';

  @override
  String get federationReqWithdrawn => 'ritirata';

  @override
  String get federationReqExpired => 'scaduta';

  @override
  String get federationAccept => 'Accetta…';

  @override
  String get federationAcceptAndShare => 'Accetta e condividi';

  @override
  String get federationDecline => 'Rifiuta';

  @override
  String get federationCancelRequest => 'Annulla richiesta';

  @override
  String get federationDismiss => 'Ignora';

  @override
  String get federationRequestTitle => 'Richiesta di associazione';

  @override
  String federationRequestReceived(String ago) {
    return 'Ricevuta $ago tramite la rete di scoperta';
  }

  @override
  String federationRequestSent(String ago) {
    return 'Inviata $ago tramite la rete di scoperta';
  }

  @override
  String get federationShareBack => 'Condividi in cambio';

  @override
  String get federationShareBackNote =>
      'Nulla cambia finché non accetti. Avranno accesso in sola lettura alle librerie che spunti — almeno una.';

  @override
  String get federationTheirLimits => 'I loro limiti';

  @override
  String get federationChange => 'Modifica';

  @override
  String get federationRequestIgnored =>
      'Le richieste da questo server vengono ignorate per 7 giorni';

  @override
  String get federationRequestAccepted => 'Richiesta accettata';

  @override
  String get federationRequestDeclined => 'Richiesta rifiutata';

  @override
  String get federationRequestCancelled => 'Richiesta ritirata';

  @override
  String get federationRequestActionFailed =>
      'Impossibile aggiornare la richiesta.';

  @override
  String get federationTicketNameLabel => 'Per chi è?';

  @override
  String get federationTicketNameHint =>
      'Solo tu vedi questo nome — etichetta il ticket nel tuo elenco.';

  @override
  String get federationLibrariesTheyCanRead => 'Librerie che potranno leggere';

  @override
  String get federationLimitsSection => 'Limiti';

  @override
  String get federationExactNumbers => 'Valori esatti';

  @override
  String get federationPresets => 'Preset';

  @override
  String get federationLimitStreamRate => 'Bitrate di streaming';

  @override
  String get federationLimitPerDay => 'Al giorno';

  @override
  String get federationLimitStreams => 'Stream simultanei';

  @override
  String get federationLimitExpires => 'Scade';

  @override
  String get federationUnlimited => 'Illimitato';

  @override
  String get federationNever => 'Mai';

  @override
  String federationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String get federationOneYear => '1 anno';

  @override
  String federationKbps(int n) {
    return '$n kbps';
  }

  @override
  String federationMbps(int n) {
    return '$n Mbps';
  }

  @override
  String federationMbPerDay(int n) {
    return '$n MB al giorno';
  }

  @override
  String federationGbPerDay(int n) {
    return '$n GB al giorno';
  }

  @override
  String federationStreamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stream',
      one: '1 stream',
    );
    return '$_temp0';
  }

  @override
  String get federationNeverExpires => 'non scade mai';

  @override
  String federationExpiresIn(String when) {
    return 'scade $when';
  }

  @override
  String get federationExpired => 'scaduto';

  @override
  String federationInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tra $count giorni',
      one: 'tra 1 giorno',
    );
    return '$_temp0';
  }

  @override
  String federationInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tra $count ore',
      one: 'tra 1 ora',
    );
    return '$_temp0';
  }

  @override
  String get federationStreamRateField => 'Bitrate (kbps, 0 = illimitato)';

  @override
  String get federationPerDayField => 'Quota giornaliera (MB, 0 = illimitata)';

  @override
  String get federationStreamsField => 'Stream max (0 = illimitati)';

  @override
  String get federationExpiresField => 'Scadenza in giorni (0 = mai)';

  @override
  String get federationCreateTicket => 'Crea ticket';

  @override
  String get federationMintFailed => 'Impossibile creare il ticket.';

  @override
  String get federationNoLibraries =>
      'Questo server non ha librerie da condividere.';

  @override
  String get federationTicketTitle => 'Il tuo ticket';

  @override
  String federationTicketFor(String name) {
    return 'Ticket per $name';
  }

  @override
  String federationTicketReads(String libraries) {
    return 'Legge $libraries';
  }

  @override
  String get federationTicketQrHint =>
      'Nella stessa stanza? Fallo scansionare.';

  @override
  String get federationTicketWarning =>
      'Chiunque abbia questo ticket può leggere quelle librerie finché non viene usato o revocato. Invialo su un canale privato — il primo server che lo usa se lo prende.';

  @override
  String get federationCopyTicket => 'Copia ticket';

  @override
  String get federationTicketCopied => 'Ticket copiato';

  @override
  String get federationSendByText => 'Invia per messaggio…';

  @override
  String get federationTicketRevokeNote =>
      'Revocalo in qualsiasi momento da Federazione. Dopo una reinstallazione, \"Azzera utilizzo\" permette di usare di nuovo il ticket.';

  @override
  String get federationTicketNotRunning =>
      'L’endpoint di federazione non è attivo, quindi non c’è ancora un ticket da inviare. Attiva la federazione e torna qui.';

  @override
  String federationShareMessage(String libraries, String ticket) {
    return 'Condivido con te la mia libreria musicale mStream — $libraries, in sola lettura. Nell’app mStream apri Federazione → Aggiungi un peer e incolla questo ticket:\n\n$ticket\n\nFunziona una volta sola — posso revocarlo quando voglio.';
  }

  @override
  String get federationShareSubject => 'Ticket di federazione mStream';

  @override
  String get federationKeyClaimed => 'utilizzato';

  @override
  String get federationKeyNotClaimed => 'non ancora utilizzato';

  @override
  String federationKeyTodayUsage(String amount) {
    return '$amount oggi';
  }

  @override
  String federationKeyLastUsed(String ago) {
    return 'Ultimo uso $ago';
  }

  @override
  String get federationKeyNeverUsed => 'Mai usato';

  @override
  String federationKeyClaimedAgo(String ago) {
    return 'Utilizzato $ago';
  }

  @override
  String get federationResetBinding => 'Azzera utilizzo';

  @override
  String get federationResetBindingNote =>
      'Hanno reinstallato? Permetti di usare di nuovo il ticket.';

  @override
  String get federationBindingReset => 'Il ticket può essere usato di nuovo';

  @override
  String get federationRevoke => 'Revoca';

  @override
  String federationRevokeConfirm(String name) {
    return 'Revocare questo ticket? $name perde subito l’accesso.';
  }

  @override
  String get federationRevoked => 'Ticket revocato';

  @override
  String get federationSaveLimits => 'Salva limiti';

  @override
  String get federationLimitsSaved => 'Limiti salvati';

  @override
  String get federationLimitsFailed => 'Impossibile salvare i limiti.';

  @override
  String get federationSend => 'Invia';

  @override
  String get federationKeyTitle => 'Libreria condivisa';

  @override
  String federationActionFailed(String error) {
    return 'Non ha funzionato: $error';
  }

  @override
  String get federationTheirTicket => 'Il loro ticket';

  @override
  String get federationScanQr => 'Scansiona un codice QR';

  @override
  String get federationScannerTitle => 'Scansiona un ticket di federazione';

  @override
  String get federationPaste => 'Incolla';

  @override
  String get federationTicketPasted => 'Incollato dagli appunti.';

  @override
  String get federationNotATicket => 'Non sembra un ticket di federazione.';

  @override
  String get federationTicketTooNew =>
      'Questo ticket viene da un mStream più recente di quanto questa app comprenda.';

  @override
  String get federationTicketExpiredNote => 'Questo ticket è scaduto.';

  @override
  String get federationDisplayName => 'Nome visualizzato';

  @override
  String get federationDisplayNameHint =>
      'Facoltativo — come appare nel selettore dei server.';

  @override
  String federationSharesLibraries(String libraries) {
    return 'Condivide $libraries';
  }

  @override
  String get federationSharesUnknown => 'Librerie non indicate sul ticket';

  @override
  String federationValidUntil(String date) {
    return 'valido fino al $date';
  }

  @override
  String federationAddPeerShowsUnder(String server) {
    return 'Compare sotto $server';
  }

  @override
  String federationAddPeerReadOnly(String branch, String name) {
    return 'Sola lettura · $branch $name nel selettore';
  }

  @override
  String get federationAddPeerDials => 'Il tuo server lo contatta tramite iroh';

  @override
  String get federationAddPeerEncrypted =>
      'Cifrato end-to-end · niente port forwarding';

  @override
  String get federationAddPeerNoTicket =>
      'Ancora nessun ticket? Chiedi che te ne inviino uno per messaggio.';

  @override
  String federationPeerAdded(String name) {
    return '$name aggiunto';
  }

  @override
  String get federationAddPeerFailed => 'Impossibile aggiungere il peer.';

  @override
  String get federationPeerAlreadyAdded =>
      'Questo ticket è già aggiunto come peer.';

  @override
  String get federationLibrariesYouCanRead => 'Librerie che puoi leggere';

  @override
  String get federationDiscoverySection => 'Scoperta';

  @override
  String get federationAskPeerSimilar => 'Chiedi a questo peer musica simile';

  @override
  String get federationAskPeerSimilarNote =>
      'Invia ciò che stai ascoltando — solo a questo peer.';

  @override
  String get federationAutoDjSection => 'Auto DJ';

  @override
  String get federationAutoDjParticipates =>
      'Partecipa all’Auto DJ multi-server';

  @override
  String get federationAutoDjParticipatesNote =>
      'Risponde con la propria libreria quando il DJ è attivo';

  @override
  String get federationAutoDjNotCandidate => 'Non è un candidato per l’Auto DJ';

  @override
  String get federationAutoDjNotCandidateNote =>
      'Serve un server in grado di rispondere alle scelte per somiglianza sonora';

  @override
  String get federationTest => 'Prova';

  @override
  String get federationTesting => 'Prova in corso…';

  @override
  String get federationTestOk => 'Raggiungibile';

  @override
  String federationTestFailed(String error) {
    return 'Irraggiungibile: $error';
  }

  @override
  String federationCheckedAgo(String ago) {
    return 'Verificato $ago';
  }

  @override
  String get federationNeverTested => 'Mai provato';

  @override
  String federationLastSeen(String ago) {
    return 'Visto l’ultima volta $ago';
  }

  @override
  String get federationBrowseLibrary => 'Sfoglia questa libreria';

  @override
  String get federationRemovePeer => 'Rimuovi peer';

  @override
  String federationRemovePeerConfirm(String name) {
    return 'Rimuovere $name? I brani in coda provenienti da questo peer smetteranno di suonare.';
  }

  @override
  String federationPeerRemoved(String name) {
    return '$name rimosso';
  }

  @override
  String get federationShowInPicker => 'Mostra nel selettore dei server';

  @override
  String get federationShowInPickerNote =>
      'I peer nascosti continuano a riprodurre ciò che hai messo in coda da loro.';

  @override
  String get federationPeerReadOnlyNote =>
      'Sola lettura — playlist e valutazioni restano sul tuo server.';

  @override
  String get federationPeerLibrariesUnknown =>
      'Non ancora elencate — aprilo una volta per caricare le sue librerie.';

  @override
  String get federationTransportDirect => 'Tunnel diretto da questo telefono';

  @override
  String get federationTransportRelay => 'Relay in attesa';

  @override
  String federationTransportViaParent(String parent) {
    return 'Tramite $parent';
  }

  @override
  String federationTransportViaParentTunnel(String parent) {
    return 'Tramite $parent attraverso il suo tunnel';
  }

  @override
  String get federationDiscoveryFailed =>
      'Impossibile modificare l’impostazione di scoperta.';

  @override
  String get agoJustNow => 'proprio ora';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min fa',
      one: '1 min fa',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h fa',
      one: '1 h fa',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni fa',
      one: '1 giorno fa',
    );
    return '$_temp0';
  }

  @override
  String get browserP2pNetwork => 'Rete P2P';

  @override
  String get browserP2pOn => 'Attiva';

  @override
  String get browserP2pOff => 'Disattivata';

  @override
  String get p2pTitle => 'Rete P2P';

  @override
  String get p2pStatusConnected => 'Connesso';

  @override
  String p2pNeighborsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vicini',
      one: '1 vicino',
    );
    return '$_temp0';
  }

  @override
  String p2pAnnouncingAs(String name) {
    return 'si annuncia come $name';
  }

  @override
  String get p2pStatusSearching => 'Entrato · in attesa di vicini';

  @override
  String p2pStatusReconnecting(int n) {
    return 'Riconnessione · tentativo $n';
  }

  @override
  String get p2pStatusNotJoined => 'Non ancora entrato';

  @override
  String get p2pStatusOff => 'Disattivata';

  @override
  String get p2pStatusUnavailable => 'Non disponibile su questa piattaforma';

  @override
  String get p2pStatNeighbors => 'vicini nella mesh';

  @override
  String get p2pStatNeighborsSub => 'collegamenti gossip attivi';

  @override
  String get p2pStatKnown => 'server conosciuti';

  @override
  String p2pStatKnownSub(int hidden, int blocked) {
    return '$hidden nascosti · $blocked bloccati';
  }

  @override
  String get p2pStatHeld => 'snapshot conservati';

  @override
  String p2pStatHeldOf(int held, int max) {
    return '$held di $max';
  }

  @override
  String p2pStatStorage(String used, String cap) {
    return '$used di $cap';
  }

  @override
  String get p2pStatTracks => 'brani dei peer';

  @override
  String p2pStatTracksSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ricercabili, $count librerie',
      one: 'ricercabili, 1 libreria',
    );
    return '$_temp0';
  }

  @override
  String get p2pActivity => 'Attività';

  @override
  String get p2pActivitySubtitle => 'prima i più recenti · solo in memoria';

  @override
  String get p2pActivityEmpty =>
      'Ancora nulla — ingressi nella mesh, download di snapshot, rotazione e ripristini compaiono qui man mano.';

  @override
  String get p2pActivityNote => 'La cronologia completa è nei log del server.';

  @override
  String get p2pFromNetwork => 'Dalla rete';

  @override
  String get p2pFindSimilar => 'Trova musica simile nella rete';

  @override
  String p2pFindSimilarSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Apre Altri simili per il brano in riproduzione · suggerimenti da $count librerie scaricate',
      one:
          'Apre Altri simili per il brano in riproduzione · suggerimenti da 1 libreria scaricata',
    );
    return '$_temp0';
  }

  @override
  String get p2pFindSimilarNothingPlaying =>
      'Riproduci prima qualcosa — Altri simili segue il brano corrente';

  @override
  String get p2pNewArtistsOnlySub =>
      'Nascondi i suggerimenti di artisti già presenti in questa libreria';

  @override
  String get p2pServersYouFollow => 'Server che segui';

  @override
  String get p2pServersOnNetwork => 'Server nella rete';

  @override
  String get p2pNoServersYet =>
      'Nessun server rilevato finora — aggiungine uno con il ticket di un amico, oppure dai un minuto al gossip.';

  @override
  String p2pHiddenIncompatible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count server nascosti — modello incompatibile',
      one: '1 server nascosto — modello incompatibile',
    );
    return '$_temp0';
  }

  @override
  String get p2pShow => 'Mostra';

  @override
  String get p2pHide => 'Nascondi';

  @override
  String get p2pBefriend => 'Aggiungi un server amico';

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
      other: '$count brani',
      one: '1 brano',
    );
    return '$_temp0';
  }

  @override
  String p2pSeedersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seeder',
      one: '1 seeder',
    );
    return '$_temp0';
  }

  @override
  String get p2pChipDownloaded => 'scaricato';

  @override
  String get p2pChipUpdate => 'aggiornamento disponibile';

  @override
  String get p2pChipNotDownloaded => 'non scaricato';

  @override
  String get p2pChipPinned => 'fissato';

  @override
  String get p2pChipIncompatible => 'modello incompatibile';

  @override
  String get p2pChipFederated => 'federato';

  @override
  String get p2pChipTheyAsked => 'ti hanno chiesto';

  @override
  String get p2pChipRequestSent => 'richiesta inviata';

  @override
  String get p2pSearchingTitle => 'Ricerca di peer';

  @override
  String get p2pSearchingBody =>
      'La mesh si forma in circa un minuto. Questa schermata si aggiorna da sola.';

  @override
  String get p2pReconnectingTitle => 'Riconnessione';

  @override
  String p2pReconnectingBody(int n) {
    return 'Il sidecar si è interrotto e viene riavviato (tentativo $n) — nessuna azione richiesta.';
  }

  @override
  String get p2pJoinTitle => 'Consigli dalle librerie di altre persone';

  @override
  String get p2pWhatShared => 'Cosa viene condiviso';

  @override
  String get p2pShared1 => 'Uno snapshot di soli metadati';

  @override
  String get p2pShared1Sub =>
      'Artista, titolo, durata, impronte sonore — mai file audio';

  @override
  String get p2pShared2 => 'Nome e descrizione del tuo server';

  @override
  String get p2pShared2Sub =>
      'Visibili a tutti nella rete, per impostazione predefinita la rete pubblica della community';

  @override
  String get p2pHowYouAppear => 'Come appari';

  @override
  String get p2pServerName => 'Nome del server';

  @override
  String get p2pServerNameHint =>
      '“mStream” accanto ad altri 18.000 mStream è la prima cosa da cambiare.';

  @override
  String get p2pDescription => 'Descrizione';

  @override
  String get p2pDescriptionHint => '180 caratteri, facoltativa.';

  @override
  String get p2pAlsoAcceptRequests => 'Accetta anche richieste di federazione';

  @override
  String get p2pAlsoAcceptRequestsSub =>
      'Inviti a condividere librerie — nulla viene condiviso finché non approvi ciascuno. Attiva la federazione.';

  @override
  String get p2pJoin => 'Entra nella rete';

  @override
  String get p2pJoining => 'Ingresso…';

  @override
  String get p2pJoined =>
      'Entrato nella rete di scoperta — dai un minuto alla mesh.';

  @override
  String p2pJoinFailed(String error) {
    return 'Impossibile entrare nella rete: $error';
  }

  @override
  String p2pInboxFailed(String error) {
    return 'La scoperta è attiva, ma la casella delle richieste non è partita: $error';
  }

  @override
  String get p2pUnavailableNote =>
      'Il binario p2p-sidecar non è stato trovato per questa piattaforma e non ce n’è uno scaricabile — la rete non è disponibile.';

  @override
  String get p2pWillDownloadNote =>
      'Il sidecar non è ancora installato; entrando viene prima scaricato.';

  @override
  String get p2pAdminOnlyNote =>
      'Solo l’amministratore del server può entrare.';

  @override
  String p2pMemberOffNote(String server) {
    return 'La rete di scoperta è disattivata su $server. L’amministratore può entrarvi.';
  }

  @override
  String p2pMemberNote(String server) {
    return 'Entrare, invitare e gestire gli snapshot spetta all’amministratore. Accedi a $server come amministratore per gestire la rete da qui.';
  }

  @override
  String get p2pSnapshotSection => 'Snapshot';

  @override
  String p2pDownloadedSize(String size) {
    return 'Scaricato · $size';
  }

  @override
  String p2pSnapshotSeq(int seq) {
    return 'Snapshot $seq';
  }

  @override
  String p2pNewerAnnounced(int seq) {
    return 'ne è annunciato uno più recente ($seq)';
  }

  @override
  String get p2pNotDownloaded => 'Non scaricato';

  @override
  String get p2pNotDownloadedSub =>
      'Scaricalo per cercare al suo interno da Scopri';

  @override
  String get p2pDownload => 'Scarica';

  @override
  String get p2pUpdate => 'Aggiorna';

  @override
  String get p2pDownloading => 'Download…';

  @override
  String get p2pDownloaded => 'Snapshot scaricato';

  @override
  String p2pDownloadFailed(String error) {
    return 'Impossibile scaricare lo snapshot: $error';
  }

  @override
  String get p2pPin => 'Fissa questo snapshot';

  @override
  String p2pPinSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'La rotazione libera gli snapshot meno usati dopo $count giorni; uno fissato resta.',
      one:
          'La rotazione libera gli snapshot meno usati dopo 1 giorno; uno fissato resta.',
    );
    return '$_temp0';
  }

  @override
  String get p2pPinSubNoRotation =>
      'La rotazione è disattivata; uno snapshot fissato sopravvive anche alla mancanza di spazio.';

  @override
  String get p2pRemoveSnapshot => 'Rimuovi snapshot';

  @override
  String get p2pSnapshotRemoved => 'Snapshot rimosso';

  @override
  String get p2pHeldSince => 'conservato dal';

  @override
  String get p2pTracksLabel => 'brani';

  @override
  String get p2pSeedersLabel => 'seeder';

  @override
  String get p2pSeedersSub => 'servono lo snapshot';

  @override
  String get p2pFederatedWithYou => 'Federato con te';

  @override
  String get p2pFederatedWithYouSub =>
      'Apri Federazione per vedere cosa leggete l’uno dall’altro';

  @override
  String get p2pTheyAskedYou => 'Hanno chiesto di federarsi';

  @override
  String get p2pTheyAskedYouSub => 'Esamina la richiesta in Federazione';

  @override
  String get p2pRequestSentTitle => 'Richiesta inviata';

  @override
  String get p2pRequestSentSub =>
      'In attesa di risposta · seguila in Federazione';

  @override
  String get p2pAskToFederate => 'Chiedi di condividere librerie';

  @override
  String get p2pAskToFederateSub =>
      'Invia una richiesta attraverso la rete — per ora non cambia nulla';

  @override
  String get p2pOpen => 'Apri';

  @override
  String get p2pReview => 'Esamina';

  @override
  String get p2pForget => 'Dimentica questo server';

  @override
  String get p2pForgetSub =>
      'Offline e senza nulla di scaricato; torna se viene rilevato di nuovo';

  @override
  String p2pForgotten(String name) {
    return '$name dimenticato';
  }

  @override
  String get p2pBlockServer => 'Blocca server';

  @override
  String p2pBlockConfirm(String name) {
    return 'Bloccare $name? I suoi annunci vengono ignorati e il suo snapshot rimosso.';
  }

  @override
  String p2pBlocked(String name) {
    return '$name bloccato';
  }

  @override
  String get p2pUnblock => 'Sblocca';

  @override
  String get p2pUnblocked => 'Server sbloccato';

  @override
  String get p2pIncompatibleNote =>
      'Modello di embedding incompatibile — la sua libreria non può alimentare la ricerca di brani simili di questo server.';

  @override
  String get p2pCompatible => 'modello compatibile';

  @override
  String get p2pModelUnknown => 'modello sconosciuto';

  @override
  String get p2pNoDescription => 'Nessuna descrizione.';

  @override
  String get p2pUnnamedServer => 'Server senza nome';

  @override
  String get p2pFederateTitle => 'Chiedi di federarsi';

  @override
  String get p2pFederateNote =>
      'Invia una richiesta attraverso la rete di scoperta. Ora non viene scambiato alcun accesso — vedranno il tuo nome, il messaggio e l’offerta; le librerie vengono condivise solo se accettano.';

  @override
  String get p2pMessage => 'Messaggio';

  @override
  String p2pMessageHint(int n) {
    return 'Facoltativo · $n / 500';
  }

  @override
  String get p2pShareBackLibraries =>
      'Librerie che condividerai in cambio se accettano';

  @override
  String get p2pShareBackNote =>
      'Deseleziona tutto per una richiesta unilaterale — leggeresti soltanto le loro.';

  @override
  String get p2pSendRequest => 'Invia richiesta';

  @override
  String get p2pRequestSent => 'Richiesta inviata — seguila in Federazione';

  @override
  String p2pRequestFailed(String error) {
    return 'Impossibile inviare la richiesta: $error';
  }

  @override
  String get p2pTheirTicket => 'Il loro ticket';

  @override
  String get p2pTheirTicketHint =>
      'Un amico trova il suo sotto \"Invita un amico\" nella sua schermata Rete P2P.';

  @override
  String get p2pTicketPasted => 'Incollato dagli appunti.';

  @override
  String get p2pRememberFriend => 'Ricorda questo amico';

  @override
  String get p2pRememberFriendSub =>
      'Salvato nella configurazione del server, così l’amicizia sopravvive ai riavvii.';

  @override
  String get p2pJoinFriend => 'Entra';

  @override
  String get p2pJoinedFriend => 'Entrato — la mesh si forma in un minuto';

  @override
  String p2pJoinFriendFailed(String error) {
    return 'Impossibile entrare: $error';
  }

  @override
  String get p2pNotATicket => 'Non sembra un ticket di endpoint.';

  @override
  String get p2pScanQr => 'Scansiona un codice QR';

  @override
  String get p2pScannerTitle => 'Scansiona un ticket di rete';

  @override
  String get p2pInviteFriend => 'Invita un amico';

  @override
  String p2pYourTicketNote(String name) {
    return 'Il tuo ticket — un amico lo incolla qui sul suo telefono per aggiungere $name. È un indirizzo, non una credenziale.';
  }

  @override
  String get p2pTicketCopied => 'Ticket copiato';

  @override
  String p2pShareMessage(String ticket) {
    return 'Aggiungi il mio server mStream nella rete di scoperta — nell’app mStream apri Rete P2P → Aggiungi un server amico e incolla questo ticket:\n\n$ticket';
  }

  @override
  String get p2pShareSubject => 'Ticket della rete di scoperta mStream';

  @override
  String get p2pTicketNotReady =>
      'Il sidecar non è ancora in esecuzione, quindi non c’è ancora un ticket da condividere.';

  @override
  String get p2pSettingsTitle => 'Impostazioni di rete';

  @override
  String get p2pSwitchTitle => 'Rete di scoperta';

  @override
  String get p2pSwitchSub =>
      'Annuncia alla rete uno snapshot di soli metadati. Disattiva per uscire — i dati raccolti restano in locale.';

  @override
  String get p2pLeaveConfirm =>
      'Uscire dalla rete di scoperta? Il tuo server smette di annunciare e scaricare snapshot. La scoperta locale continua a funzionare.';

  @override
  String get p2pLeave => 'Esci';

  @override
  String get p2pLeft => 'Uscito dalla rete di scoperta';

  @override
  String p2pLeaveFailed(String error) {
    return 'Impossibile uscire dalla rete: $error';
  }

  @override
  String get p2pEditIdentity => 'Nome e descrizione';

  @override
  String get p2pIdentitySaved => 'Salvato — annunciato alla rete';

  @override
  String p2pSaveFailed(String error) {
    return 'Impossibile salvare: $error';
  }

  @override
  String get p2pSnapshotsSection => 'Snapshot';

  @override
  String get p2pAutoDownload => 'Download automatico fino a';

  @override
  String p2pServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count server',
      one: '1 server',
    );
    return '$_temp0';
  }

  @override
  String get p2pStorageCap => 'Limite di archiviazione';

  @override
  String get p2pRotate => 'Ruota i download';

  @override
  String get p2pForgetOffline => 'Dimentica i server offline';

  @override
  String get p2pMeshSection => 'Mesh';

  @override
  String get p2pCommunitySeeds => 'Seed della community';

  @override
  String get p2pCommunitySeedsOn => 'Avvio tramite i server seed pubblici';

  @override
  String get p2pCommunitySeedsOff =>
      'Disattivati — solo server amici; si imposta nella configurazione del server';

  @override
  String p2pBlockedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count server bloccati',
      one: '1 server bloccato',
      zero: 'Nessun server bloccato',
    );
    return '$_temp0';
  }

  @override
  String get p2pBlockedSub => 'Annunci ignorati, snapshot mai scaricati';

  @override
  String get p2pBlockedTitle => 'Server bloccati';

  @override
  String get p2pSaved => 'Salvato';

  @override
  String get p2pOff => 'Disattivata';

  @override
  String get p2pSave => 'Salva';

  @override
  String get p2pSearchServers => 'Cerca server — nome o descrizione';

  @override
  String federationInboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count richieste di federazione in attesa',
      one: '1 richiesta di federazione in attesa',
    );
    return '$_temp0';
  }

  @override
  String get federationInboxBannerSub => 'Tocca per accettare o rifiutare';

  @override
  String federationInboxNotificationTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count richieste di federazione sono in attesa',
      one: 'Una richiesta di federazione è in attesa',
    );
    return '$_temp0';
  }

  @override
  String federationInboxNotificationBody(String server) {
    return 'Su $server. Apri per accettare o rifiutare.';
  }

  @override
  String get federationInboxChannelName => 'Richieste di federazione';

  @override
  String get federationInboxChannelDescription =>
      'Su uno dei tuoi server è arrivata una richiesta di condivisione delle librerie';

  @override
  String get federationNotifyTitle => 'Avvisami delle richieste';

  @override
  String get federationNotifySubtitle =>
      'Una notifica sul telefono quando arriva una richiesta mentre l’app è aperta o in riproduzione';

  @override
  String get autoRecentlyPlayed => 'Ascoltati di recente';

  @override
  String get settingsHistoryEnabled => 'Registra le riproduzioni';

  @override
  String get settingsHistorySend => 'Invia le riproduzioni ai server';

  @override
  String get settingsHistoryClear => 'Cancella la cronologia';

  @override
  String settingsHistoryClearConfirm(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Verrà eliminata la cronologia di ascolto di questo telefono ($size), incluse $count riproduzioni non ancora sincronizzate. I server conservano la loro.',
      one:
          'Verrà eliminata la cronologia di ascolto di questo telefono ($size), inclusa $count riproduzione non ancora sincronizzata. I server conservano la loro.',
      zero:
          'Verrà eliminata la cronologia di ascolto di questo telefono ($size). I server conservano la loro.',
    );
    return '$_temp0';
  }

  @override
  String get settingsHistoryCleared => 'Cronologia di ascolto cancellata';

  @override
  String songInfoServerPlays(num count, Object server) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count riproduzioni su $server',
      one: '1 riproduzione su $server',
    );
    return '$_temp0';
  }

  @override
  String songInfoDevicePlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count riproduzioni su questo telefono',
      one: '1 riproduzione su questo telefono',
    );
    return '$_temp0';
  }

  @override
  String songInfoLastPlayed(Object ago) {
    return 'ultimo ascolto $ago';
  }

  @override
  String get listeningTitle => 'Statistiche di ascolto';

  @override
  String get listeningScopeThisPhone => 'Questo telefono';

  @override
  String get listeningScopeSheetTitle => 'Cosa mostrare';

  @override
  String get listeningScopeSheetDevice =>
      'Ciò che questo telefono ha riprodotto: ogni server, file locali, offline. Resta su questo dispositivo.';

  @override
  String get listeningScopeSheetServer =>
      'Le tue riproduzioni su questo server da ogni app: il lettore web, altri telefoni e questo telefono una volta sincronizzato.';

  @override
  String get listeningScopeSheetLegacy =>
      'Ancora nessuna statistica di ascolto: richiede mStream 6.27 o successivo.';

  @override
  String listeningScopeSheetPeer(Object server) {
    return 'Contate su $server: i brani di un peer contano dove vive il tuo account.';
  }

  @override
  String get listeningProvenanceDevice =>
      'Ciò che questo telefono ha riprodotto, su ogni server e per i file locali. Resta su questo dispositivo.';

  @override
  String listeningProvenanceServer(Object server) {
    return 'Le tue riproduzioni su $server da ogni app, inclusi i brani dei suoi peer.';
  }

  @override
  String listeningProvenancePeer(Object peer, Object server) {
    return 'Le tue riproduzioni dei brani di $peer, contate su $server.';
  }

  @override
  String listeningProvenanceFallback(Object server) {
    return '$server non ha risposto: vengono mostrate le riproduzioni di questo telefono su di esso.';
  }

  @override
  String listeningProvenanceLegacy(Object server) {
    return '$server non ha ancora statistiche di ascolto (mStream 6.27+): vengono mostrate le riproduzioni di questo telefono su di esso.';
  }

  @override
  String listeningUnsynced(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count riproduzioni non ancora sincronizzate',
      one: '1 riproduzione non ancora sincronizzata',
    );
    return '$_temp0';
  }

  @override
  String get listeningPeriodWeek => 'Questa settimana';

  @override
  String get listeningPeriodMonth => 'Questo mese';

  @override
  String get listeningPeriodQuarter => 'Questo trimestre';

  @override
  String get listeningPeriodYear => 'Quest\'anno';

  @override
  String get listeningPeriodAll => 'Da sempre';

  @override
  String get listeningTilePlays => 'Riproduzioni';

  @override
  String get listeningTileTime => 'Tempo di ascolto';

  @override
  String get listeningTileTracks => 'Brani';

  @override
  String get listeningTileSkips => 'Saltati';

  @override
  String get listeningTileStreak => 'Serie';

  @override
  String get listeningTileSessions => 'Sessioni';

  @override
  String listeningDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String get listeningTileSubCounted => 'riproduzioni contate';

  @override
  String get listeningTileSubTracks => 'brani diversi';

  @override
  String listeningTileSubSkips(Object pct) {
    return '$pct% degli avvii';
  }

  @override
  String listeningTileSubStreak(Object count) {
    return 'la più lunga: $count';
  }

  @override
  String listeningTileSubSessions(Object duration) {
    return 'circa $duration ciascuna';
  }

  @override
  String get listeningWhenYouListen => 'Quando ascolti';

  @override
  String listeningMostAround(Object hour) {
    return 'Soprattutto verso le $hour';
  }

  @override
  String get listeningTop => 'Top';

  @override
  String get listeningTopTracks => 'Brani';

  @override
  String get listeningTopArtists => 'Artisti';

  @override
  String get listeningTopAlbums => 'Album';

  @override
  String get listeningByPlays => 'Riproduzioni';

  @override
  String get listeningByTime => 'Tempo';

  @override
  String listeningPlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count riproduzioni',
      one: '1 riproduzione',
    );
    return '$_temp0';
  }

  @override
  String listeningTracksCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return '$_temp0';
  }

  @override
  String get listeningRecent => 'Riproduzioni recenti';

  @override
  String get listeningLoadMore => 'Carica altro';

  @override
  String get listeningEmptyTitle => 'Ancora nessuna riproduzione';

  @override
  String get listeningEmptyDevice =>
      'Le riproduzioni compaiono qui mentre ascolti. Questo telefono tiene il proprio registro; il tuo server tiene il tuo per ogni app.';

  @override
  String listeningEmptyServer(Object server) {
    return 'Nulla è ancora stato segnalato a $server. Le riproduzioni di questo telefono arrivano una volta sincronizzate.';
  }

  @override
  String get listeningEmptyPeriod => 'Niente in questo periodo.';

  @override
  String get listeningOutcomeCompleted => 'Completata';

  @override
  String get listeningOutcomeSkipped => 'Saltata';

  @override
  String get listeningOutcomeStopped => 'Interrotta';

  @override
  String listeningOutcomeAt(Object outcome, Object position) {
    return '$outcome a $position';
  }

  @override
  String get listeningNotCounted => 'non contata';

  @override
  String listeningVia(Object peer) {
    return 'via $peer';
  }

  @override
  String listeningRepeats(Object count) {
    return '×$count';
  }

  @override
  String get listeningLocalFile => 'File locale';

  @override
  String get listeningHistoryOff =>
      'La cronologia di ascolto è disattivata. Attivala nelle impostazioni per registrare le riproduzioni su questo telefono.';

  @override
  String listeningError(Object message) {
    return 'Impossibile caricare: $message';
  }

  @override
  String get listeningRetry => 'Riprova';

  @override
  String get listeningToday => 'Oggi';

  @override
  String get listeningYesterday => 'Ieri';

  @override
  String get listeningPlaysPerDay => 'Riproduzioni al giorno';

  @override
  String get listeningPlaysPerMonth => 'Riproduzioni al mese';

  @override
  String listeningMostOnDay(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Di più il $date: $count riproduzioni',
      one: 'Di più il $date: 1 riproduzione',
    );
    return '$_temp0';
  }

  @override
  String listeningMostInMonth(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Di più a $month: $count riproduzioni',
      one: 'Di più a $month: 1 riproduzione',
    );
    return '$_temp0';
  }

  @override
  String get settingsHomeWidget => 'Widget per la schermata Home';

  @override
  String get settingsHomeWidgetSubtitleIos =>
      'Tieni premuta la schermata Home, aggiungi un widget e scegli mStream Music.';

  @override
  String get homeWidgetPickSize => 'Scegli una dimensione';

  @override
  String get homeWidgetPinUnsupported =>
      'Questo launcher non può aggiungere widget da qui. Usa il suo selettore di widget.';

  @override
  String discoverSheetPeerOnline(String name) {
    return '$name online';
  }

  @override
  String discoverSheetPeerNotAnswering(String name) {
    return '$name non risponde';
  }

  @override
  String discoverSheetSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return '$_temp0';
  }

  @override
  String discoverSheetAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count album',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get discoverSheetNotInLibrary => 'non è nella tua libreria';

  @override
  String get discoverSheetInLibrary => 'nella tua libreria';

  @override
  String discoverSheetYouHaveAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hai $count album',
      one: 'hai 1 album',
    );
    return '$_temp0';
  }

  @override
  String get discoverSheetOpenAlbum => 'Apri album';

  @override
  String get discoverSheetQueueAlbum => 'Accoda album';

  @override
  String get discoverSheetPlayAlbum => 'Riproduci album';

  @override
  String get discoverSheetOpenArtist => 'Apri artista';

  @override
  String get discoverSheetListen => 'Ascolta';

  @override
  String get discoverSheetKeepCopy => 'Tieni una copia';

  @override
  String get discoverSheetOpenElsewhere => 'Apri altrove';

  @override
  String discoverSheetBrowsePeer(String name) {
    return 'Sfoglia $name';
  }

  @override
  String get discoverSheetDownloadToPhone => 'Scarica su questo telefono';

  @override
  String get discoverSheetDownloadToPhoneSub =>
      'Per l’ascolto offline su questo dispositivo';

  @override
  String discoverSheetAlbumFailed(String name) {
    return 'Impossibile caricare questo album da $name';
  }

  @override
  String discoverAlbumCardMore(String album) {
    return 'Altro per $album';
  }

  @override
  String get discoverKeepThisSong => 'Questo brano';

  @override
  String get discoverKeepAlbum => 'Album';

  @override
  String get discoverKeepArtist => 'Artista';

  @override
  String get discoverKeepWhat => 'Cosa tenere';

  @override
  String discoverKeepYouHave(int count) {
    return 'ne hai $count';
  }

  @override
  String discoverKeepOnlyMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Solo i $count album che non hai',
      one: 'Solo l’album che non hai',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepFilesGoTo => 'I file finiscono in';

  @override
  String discoverKeepPathTooLong(int max) {
    return 'Il percorso di questa copia supererebbe i $max caratteri, più di quanto il server accetti';
  }

  @override
  String get discoverKeepFolderPerAlbum => 'una cartella per album';

  @override
  String get discoverKeepChange => 'Cambia';

  @override
  String get discoverKeepChangeHint => 'Cambia dove vanno le copie';

  @override
  String get discoverKeepAddSong => 'Aggiungi brano';

  @override
  String get discoverKeepAddAlbum => 'Aggiungi album';

  @override
  String get discoverKeepAddEveryAlbum => 'Aggiungi tutti gli album';

  @override
  String discoverKeepAddAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aggiungi $count album',
      one: 'Aggiungi 1 album',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepAddMissing => 'Aggiungi gli album che non hai';

  @override
  String get discoverKeepUploadsOff =>
      'Il tuo account non può aggiungere file a questo server';

  @override
  String get discoverKeepNoLibrary =>
      'Nessuna libreria del tuo server accetta nuovi file';

  @override
  String get discoverKeepStartFailed =>
      'Impossibile raggiungere il tuo server. Riprova.';

  @override
  String get discoverKeepDestChanged =>
      'La destinazione dei file è cambiata da quando l’hai aperto. Controlla il percorso sopra e aggiungi di nuovo.';

  @override
  String get discoverKeepDestChangedTryAgain =>
      'La destinazione dei file è cambiata da quando l’hai aperto. Controlla il percorso sopra e riprova.';

  @override
  String discoverKeepRetryAddsTo(String path) {
    return 'Riprova salva in $path, la tua posizione salvata ora';
  }

  @override
  String discoverKeepAddAgainAddsTo(String path) {
    return 'Aggiungi di nuovo salva in $path, la tua posizione salvata ora';
  }

  @override
  String discoverKeepConfirmTitle(int count, String peer) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Copiare $count album da $peer?',
      one: 'Copiare 1 album da $peer?',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepConfirmEveryTitle(String artist, String peer) {
    return 'Copiare tutti gli album di $artist da $peer?';
  }

  @override
  String discoverKeepConfirmBody(String path) {
    return 'Finiscono sul tuo server in $path, una cartella per album. I brani che hai già vengono saltati.';
  }

  @override
  String discoverKeepConfirmBodyFlat(String path) {
    return 'Finiscono sul tuo server in $path. I brani che hai già vengono saltati.';
  }

  @override
  String discoverKeepConfirmAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Copia $count album',
      one: 'Copia 1 album',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepConfirmEveryAction => 'Copia tutti gli album';

  @override
  String get discoverJobQueued => 'In attesa di un posto libero';

  @override
  String get discoverJobQueuedSub => 'Parte da sola';

  @override
  String get discoverJobCopying => 'Copia in corso';

  @override
  String get discoverJobStarting => 'Avvio…';

  @override
  String get discoverJobStopping => 'Arresto in corso…';

  @override
  String get discoverJobInCollection => 'Nella tua collezione';

  @override
  String get discoverJobOwned => 'È già tuo';

  @override
  String get discoverJobOwnedSub => 'La tua libreria ha già questo brano';

  @override
  String get discoverJobSkipped => 'Saltato · c’è già un file lì';

  @override
  String discoverJobExistsSub(String path) {
    return 'C’è già un file in $path · non è stato sovrascritto nulla';
  }

  @override
  String get discoverJobFailed => 'Copia non riuscita';

  @override
  String get discoverJobFailedSub => 'La copia non è stata completata';

  @override
  String get discoverJobNothingCopiedLead => 'Nulla copiato';

  @override
  String get discoverJobNothingCopied => 'nulla copiato';

  @override
  String get discoverJobStopped => 'Interrotto';

  @override
  String discoverJobStoppedQuota(String peer) {
    return 'Il limite di trasferimento di $peer l’ha interrotta';
  }

  @override
  String discoverJobStoppedBusy(String peer) {
    return '$peer sta servendo troppi stream in questo momento';
  }

  @override
  String discoverJobStoppedPeer(String peer) {
    return '$peer non è più raggiungibile';
  }

  @override
  String discoverJobStoppedRefused(String peer) {
    return '$peer non consente copie con la chiave del tuo server';
  }

  @override
  String get discoverJobCancelledNothing =>
      'Interrotto · non è stato copiato nulla';

  @override
  String discoverJobCancelledSome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Interrotto · $count copiati',
      one: 'Interrotto · 1 copiato',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobCancelledSub => 'L’hai annullata';

  @override
  String discoverJobCancelledStay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'L’hai annullata · i $count brani restano nella tua collezione',
      one: 'L’hai annullata · il brano resta nella tua collezione',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobNothingAll => 'Hai già tutto';

  @override
  String discoverJobNothingFrom(String peer) {
    return 'Niente da copiare da $peer';
  }

  @override
  String get discoverJobOnlyGuest => 'Niente di suo da copiare';

  @override
  String discoverJobOnlyGuestSub(String artist, String peer) {
    return '$artist compare solo come ospite negli album di $peer';
  }

  @override
  String discoverJobFromOther(String peer) {
    return 'Copia da $peer';
  }

  @override
  String discoverJobComesBack(String action) {
    return '«$action» torna quando finisce quella copia';
  }

  @override
  String get discoverJobDone => 'Completato';

  @override
  String discoverJobCopiedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copiati',
      one: '1 copiato',
    );
    return '$_temp0';
  }

  @override
  String discoverJobOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erano già tuoi',
      one: '1 era già tuo',
    );
    return '$_temp0';
  }

  @override
  String discoverJobFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non riusciti',
      one: '1 non riuscito',
    );
    return '$_temp0';
  }

  @override
  String discoverJobAlbumsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count album non riusciti',
      one: '1 album non riuscito',
    );
    return '$_temp0';
  }

  @override
  String discoverJobAlbumsLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count album esclusi',
      one: '1 album escluso',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobRetry => 'Riprova';

  @override
  String get discoverJobAddAgain => 'Aggiungi di nuovo';

  @override
  String get discoverJobAddToQueue => 'Aggiungi alla coda';

  @override
  String get discoverMarkWaiting => 'in attesa';

  @override
  String get discoverMarkCopying => 'copia…';

  @override
  String discoverMarkCopyingCount(int done, int total) {
    return 'copia $done di $total';
  }

  @override
  String get discoverMarkStopping => 'arresto…';

  @override
  String get discoverMarkInCollection => 'nella tua collezione';

  @override
  String get discoverMarkAlreadyYours => 'già tuo';

  @override
  String get discoverMarkStopped => 'interrotto';

  @override
  String get discoverMarkRefused => 'rifiutato';

  @override
  String get discoverMarkFailed => 'non riuscito';

  @override
  String get discoverMarkSkipped => 'saltato';

  @override
  String discoverCopiesCopying(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In copia: $count',
    );
    return '$_temp0';
  }

  @override
  String discoverCopiesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non riuscite',
      one: '1 non riuscita',
    );
    return '$_temp0';
  }

  @override
  String discoverCopiesLabel(String summary) {
    return 'Copie: $summary';
  }

  @override
  String get discoverCopiesTitle => 'Copie';

  @override
  String get discoverCopiesSectionCopying => 'In corso';

  @override
  String get discoverCopiesSectionAttention => 'Interrotte o non riuscite';

  @override
  String get discoverCopiesSectionFinished => 'Appena finite';

  @override
  String get discoverCopiesClearFinished => 'Cancella le finite';

  @override
  String get discoverCopiesEmpty => 'Nessuna copia in corso';

  @override
  String get discoverCopiesEmptySub =>
      'Tieni premuto un brano o un album di un server collegato in Scopri per tenerne una copia.';

  @override
  String get discoverCopiesOpenDiscover => 'Apri Scopri';

  @override
  String get discoverCopiesLoadFailed => 'Impossibile caricare le tue copie';

  @override
  String get discoverCopiesLoadFailedSub =>
      'Il tuo server non ha risposto. Le copie continuano lì.';

  @override
  String get discoverCopiesLoading => 'Caricamento delle tue copie';

  @override
  String get discoverCopiesKindSong => 'Brano';

  @override
  String get discoverCopiesKindAlbum => 'Album';

  @override
  String get discoverCopiesKindEvery => 'Tutti gli album';

  @override
  String get discoverCopiesKindMissing => 'Quello che ti manca';

  @override
  String discoverCopiesFrom(String peer) {
    return 'da $peer';
  }

  @override
  String discoverCopiesEveryAlbumBy(String artist) {
    return 'Tutti gli album di $artist';
  }

  @override
  String discoverCopiesMissingOf(String artist) {
    return '$artist · album che non hai';
  }

  @override
  String get discoverCopiesAlreadyFinished =>
      'Già finita · niente da annullare';

  @override
  String get discoverCopiesCancelFailed => 'Impossibile annullare. Riprova.';

  @override
  String get discoverCopiesDestChanged =>
      'Impossibile avviare: la destinazione dei file è cambiata — riprova da Tieni una copia';

  @override
  String discoverToastCopying(String title, String peer) {
    return 'Copia di $title da $peer';
  }

  @override
  String discoverToastCopyingEvery(String artist, String peer) {
    return 'Copia di tutti gli album di $artist da $peer';
  }

  @override
  String discoverToastCopyingMissing(String artist, String peer) {
    return 'Copia da $peer degli album di $artist che non hai';
  }

  @override
  String get discoverToastAdded => 'Aggiunto alla tua collezione';

  @override
  String get discoverToastAlreadyYours => 'Già nella tua libreria';

  @override
  String discoverToastFailed(String reason) {
    return 'Copia non riuscita: $reason';
  }

  @override
  String discoverToastStopped(String reason) {
    return 'Interrotta prima della fine: $reason';
  }

  @override
  String get discoverToastLinkFailed => 'Impossibile aprire il link';

  @override
  String discoverToastSaved(String path) {
    return 'Salvato · le copie finiscono in $path';
  }

  @override
  String get discoverDestTitle => 'Dove finiscono le copie';

  @override
  String get discoverDestSub =>
      'Un’unica impostazione per il tuo account · la usano tutte le copie';

  @override
  String get discoverDestTagDefault => 'predefinito della libreria';

  @override
  String get discoverDestTagYours => 'tuo';

  @override
  String discoverDestLandsAt(String title) {
    return '$title finisce in';
  }

  @override
  String get discoverDestFixLayout =>
      'Correggi la struttura per vedere dove finiscono i file';

  @override
  String discoverDestPathTooLong(int max) {
    return 'Il percorso di questo brano supererebbe i $max caratteri, più di quanto il server accetti';
  }

  @override
  String get discoverDestLibrary => 'Libreria';

  @override
  String get discoverDestLayout => 'Struttura';

  @override
  String get discoverDestPresetArtistAlbum => 'Artista / Album';

  @override
  String get discoverDestPresetServer => 'Server / Artista / Album';

  @override
  String get discoverDestPresetServerFolders => 'Stesse cartelle del server';

  @override
  String get discoverDestPresetLibrary => 'Struttura della libreria';

  @override
  String get discoverDestPresetCustom => 'Personalizzata';

  @override
  String get discoverDestCustomSub => 'Scrivi il tuo percorso';

  @override
  String get discoverDestCustomField => 'Struttura personalizzata';

  @override
  String discoverDestCustomHint(String example) {
    return 'es. Dagli amici o $example';
  }

  @override
  String get discoverDestCustomHelp =>
      'Separa le cartelle con /. Le variabili ordinano le copie per artista, album…; un nome fisso mette ogni copia nella stessa cartella.';

  @override
  String get discoverDestCustomEmpty =>
      'Scrivi un percorso per vedere dove finiscono i file';

  @override
  String get discoverDestInsertArtist => 'Inserisci artista';

  @override
  String get discoverDestInsertAlbum => 'Inserisci album';

  @override
  String get discoverDestInsertYear => 'Inserisci anno';

  @override
  String get discoverDestInsertGenre => 'Inserisci genere';

  @override
  String get discoverDestInsertAlbumArtist => 'Inserisci artista dell\'album';

  @override
  String get discoverDestInsertPeer => 'Inserisci nome del server';

  @override
  String get discoverDestInsertServerFolder => 'Inserisci cartella del server';

  @override
  String discoverDestErrUnknownVar(String name, String vars) {
    return 'Variabile sconosciuta $name. Usa $vars.';
  }

  @override
  String discoverDestErrBraces(String example) {
    return 'C\'è una parentesi graffa fuori posto: le variabili si scrivono come $example.';
  }

  @override
  String discoverDestErrBaseBraces(String folder) {
    return '«$folder» è una cartella impostata su un altro dispositivo, ma in una struttura si legge come una variabile. Rinominala qui o scegli una struttura.';
  }

  @override
  String get discoverDestErrAbsolute =>
      'Una struttura non può iniziare con /: parte dalla libreria.';

  @override
  String get discoverDestErrTraversal =>
      'Un percorso non può contenere cartelle «..».';

  @override
  String get discoverDestErrEmpty =>
      'Così non si crea nessuna cartella: aggiungi un nome o una variabile.';

  @override
  String get discoverDestErrHome => 'Un percorso non può contenere ~ o \$HOME.';

  @override
  String get discoverDestErrGeneric => 'Questo percorso non può essere usato.';

  @override
  String get discoverDestErrDrive =>
      'Un percorso non può usare una lettera di unità come C:.';

  @override
  String discoverDestErrTooLong(int max) {
    return 'Una struttura può avere al massimo $max caratteri.';
  }

  @override
  String get discoverDestErrControl =>
      'Un percorso non può contenere tabulazioni o altri caratteri di controllo.';

  @override
  String discoverDestMissing(String vars) {
    return 'Senza valore per questo brano, quindi escluso dal percorso: $vars';
  }

  @override
  String get discoverDestGenreSlot => 'genere';

  @override
  String get discoverDestArtistSlot => 'artista';

  @override
  String get discoverDestYearSlot => 'anno';

  @override
  String get discoverDestServerFolderSlot => 'cartella del server';

  @override
  String discoverKeepSlotNote(int count, String slots) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots vengono dai tag di ogni brano, quindi questi brani possono finire in più di una cartella.',
      one:
          '$slots viene dai tag di ogni brano, quindi questi brani possono finire in più di una cartella.',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteGenre(int count, String slots) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots vengono dai tag di ogni brano, quindi questi brani possono finire in più di una cartella (per un brano senza genere quella cartella viene omessa).',
      one:
          '$slots viene dai tag di ogni brano, quindi questi brani possono finire in più di una cartella (per un brano senza genere quella cartella viene omessa).',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteSong(String slots) {
    return '$slots viene dai tag del brano (per un brano senza genere quella cartella viene omessa).';
  }

  @override
  String discoverKeepSlotNoteServer(String server) {
    return '$server dipende da dove si trova ogni brano sul server, quindi questi brani possono finire in più di una cartella.';
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
          '$slots vengono dai tag di ogni brano e $server da dove si trova sul server, quindi questi brani possono finire in più di una cartella.',
      one:
          '$slots viene dai tag di ogni brano e $server da dove si trova sul server, quindi questi brani possono finire in più di una cartella.',
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
          '$slots vengono dai tag di ogni brano e $server da dove si trova sul server, quindi questi brani possono finire in più di una cartella (per un brano senza genere quella cartella viene omessa).',
      one:
          '$slots viene dai tag di ogni brano e $server da dove si trova sul server, quindi questi brani possono finire in più di una cartella (per un brano senza genere quella cartella viene omessa).',
    );
    return '$_temp0';
  }

  @override
  String get discoverDestUseDefault => 'Usa il predefinito della libreria';

  @override
  String get discoverDestSaving => 'Salvataggio…';

  @override
  String get discoverDestLoadFailed =>
      'Impossibile caricare dove finiscono le copie';

  @override
  String get discoverDestLoading => 'Caricamento di dove finiscono le copie';

  @override
  String get discoverKeepFirstUse =>
      'Le copie vanno sul tuo server, non su questo telefono. Controlla dove finiscono prima della prima.';

  @override
  String get discoverElsewhereExact => 'Pagine esatte';

  @override
  String get discoverElsewhereSearch => 'Cerca';

  @override
  String get discoverElsewhereMbRecording => 'Registrazione su MusicBrainz';

  @override
  String get discoverElsewhereMbReleaseGroup =>
      'Gruppo di pubblicazioni su MusicBrainz';

  @override
  String get discoverElsewhereMbIsrc => 'ISRC su MusicBrainz';

  @override
  String get discoverElsewhereEmpty => 'Nessun link per questo brano';

  @override
  String get discoverElsewhereEmptySub =>
      'Non ha ID MusicBrainz, né titolo o artista da cercare.';

  @override
  String get discoverElsewhereFailed => 'Impossibile cercare i link adesso';

  @override
  String get discoverElsewhereLoading => 'Ricerca dei link';

  @override
  String get discoverElsewhereOpensOutside => 'Si apre fuori dall’app';

  @override
  String get visualizerMilkdropTitle => 'Visualizzatore Milkdrop';

  @override
  String get visualizerShadertoyTitle => 'Visualizzatore ShaderToy';

  @override
  String get realAudioSynthesizedNote =>
      'Senza il permesso, il visualizzatore usa dati sintetizzati.';

  @override
  String get realAudioDontAskAgain => 'Non chiedere più';

  @override
  String get realAudioUseSynthesized => 'Usa dati sintetizzati';

  @override
  String get realAudioUseReal => 'Usa l’audio reale';

  @override
  String get queueSharePlaylist => 'Condividi playlist';

  @override
  String get autoDjStopShort => 'Ferma';

  @override
  String get autoDjPlayFrom => 'Riproduci da';

  @override
  String get autoDjAllServers => 'Tutti i server';

  @override
  String autoDjServersTakingPart(int count, int total) {
    return '$count su $total';
  }

  @override
  String get autoDjQuickSettings => 'Impostazioni rapide di Auto DJ';

  @override
  String get autoDjAllSettings => 'Tutte le impostazioni di Auto DJ';

  @override
  String autoDjServerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count server',
      one: '1 server',
    );
    return '$_temp0';
  }

  @override
  String get autoDjFirstSong => 'Primo brano';

  @override
  String get autoDjFirstSongRandom => 'Casuale';

  @override
  String get autoDjFirstSongChoose => 'Scegli';

  @override
  String get autoDjMustMatch => 'Deve corrispondere';

  @override
  String get autoDjPrefer => 'Preferisci';

  @override
  String autoDjPercent(int pct) {
    return '$pct%';
  }

  @override
  String get autoDjDrift => 'Evolvere';

  @override
  String get autoDjStayClose => 'Restare vicino';

  @override
  String get autoDjGenres => 'Generi';

  @override
  String get autoDjGenresOnly => 'Solo';

  @override
  String get autoDjGenresSkip => 'Escludi';

  @override
  String autoDjGenresSkipValue(String genres) {
    return 'Senza $genres';
  }

  @override
  String get autoDjRating => 'Valutazione';

  @override
  String autoDjRatingValue(String stars) {
    return '$stars★+';
  }

  @override
  String get autoDjAny => 'Qualsiasi';

  @override
  String autoDjLengthOver(String min) {
    return '$min+';
  }

  @override
  String autoDjLengthUnder(String max) {
    return 'Sotto $max';
  }

  @override
  String autoDjLengthBetween(String min, String max) {
    return '$min–$max';
  }

  @override
  String get autoDjIncludeUnknown => 'Includi sconosciute';

  @override
  String get autoDjLengthShortest => 'Minimo';

  @override
  String get autoDjLengthLongest => 'Massimo';

  @override
  String get autoDjWheelHours => 'h';

  @override
  String get autoDjTempo => 'Beatmatching';

  @override
  String get autoDjSkipWords => 'Parole escluse';

  @override
  String get autoDjBatch => 'Blocco';

  @override
  String get autoDjVaries => 'Varia';

  @override
  String autoDjMax(int count) {
    return 'max $count';
  }

  @override
  String autoDjNeedsServer(String version) {
    return 'Server $version+';
  }

  @override
  String get autoDjDiscoveryOff => 'Senza scoperta';

  @override
  String get autoDjStillScanning => 'Scansione in corso';

  @override
  String get autoDjTooStrict => 'Troppo rigido';

  @override
  String get autoDjNotOnPeers => 'Non sui peer';

  @override
  String get autoDjNoMoodData => 'Nessun dato d\'atmosfera';

  @override
  String get autoDjOtherModel => 'Altro modello audio';

  @override
  String get autoDjUnreachable => 'Irraggiungibile';

  @override
  String get autoDjRemember => 'Ricorda';

  @override
  String get autoDjGenresNone => 'Nessun genere';

  @override
  String get autoDjNoMatches => 'Nessun risultato';

  @override
  String get autoDjRecentlyPlayed => 'Ascoltati di recente';

  @override
  String get autoDjFirstSongRecent => 'Recenti';

  @override
  String get browseLoadFailed =>
      'Couldn\'t load this from the server. Check the connection and try again.';

  @override
  String get settingsSectionVisualizer => 'Visualizzatore';

  @override
  String get settingsOfflineQueueFooter =>
      'Solo per i download della coda. I brani che scarichi tu restano sempre.';

  @override
  String settingsAutoDownloadCapValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '$count brano',
    );
    return '$_temp0';
  }

  @override
  String get settingsAutoDownloadCapHint => '0 = nessun limite';

  @override
  String get settingsStartupRecentHint => 'Aggiunti di recente';

  @override
  String settingsLetterStripValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count+ elementi',
      one: '$count+ elementi',
      zero: 'Sempre',
    );
    return '$_temp0';
  }

  @override
  String get settingsLetterStripHint =>
      'Negli elenchi A–Z. In quelli più corti i nomi lunghi vanno a capo.';

  @override
  String get settingsHistoryFooter =>
      'Scrobbling su Last.fm solo dai server con un account collegato.';

  @override
  String get settingsHistoryEmpty => 'Vuota';

  @override
  String get settingsHistoryOffTitle =>
      'Smettere di registrare le riproduzioni?';

  @override
  String settingsHistoryOffBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Verrà eliminata la cronologia di ascolto di questo telefono, incluse $count riproduzioni non ancora sincronizzate. I server conservano la loro.',
      one:
          'Verrà eliminata la cronologia di ascolto di questo telefono, inclusa $count riproduzione non ancora sincronizzata. I server conservano la loro.',
      zero:
          'Verrà eliminata la cronologia di ascolto di questo telefono. I server conservano la loro.',
    );
    return '$_temp0';
  }

  @override
  String get settingsHistoryOffConfirm => 'Disattiva';

  @override
  String get settingsHistoryClearTitle => 'Cancellare la cronologia?';

  @override
  String get settingsResetTitle => 'Ripristinare le impostazioni?';

  @override
  String get settingsResetBody =>
      'Ripristina anche Equalizzatore, Transcodifica e alcune opzioni fuori da Impostazioni. Server, download, cronologia di ascolto e preset salvati restano.';

  @override
  String get settingsResetBodyIos =>
      'Ripristina anche Transcodifica e alcune opzioni fuori da Impostazioni. Server, download e cronologia di ascolto restano.';

  @override
  String get ytdlTitle => 'Aggiungi da YouTube';

  @override
  String ytdlHomeAdding(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in corso',
    );
    return '$_temp0';
  }

  @override
  String ytdlHomeAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aggiunti',
      one: '$count aggiunto',
    );
    return '$_temp0';
  }

  @override
  String ytdlHomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count falliti',
      one: '$count fallito',
    );
    return '$_temp0';
  }

  @override
  String get ytdlPasteHint => 'Incolla un link di YouTube';

  @override
  String get ytdlPasteFromClipboard => 'Incolla dagli appunti';

  @override
  String ytdlLandsIn(String path) {
    return 'Finisce in $path';
  }

  @override
  String get ytdlLimits =>
      'Un video per link · il server si ferma a 500 MB o dopo un’ora · niente dirette né playlist';

  @override
  String get ytdlEmptyTitle =>
      'Incolla un link per aggiungere un brano alla tua libreria.';

  @override
  String get ytdlEmptyWebApp =>
      'Qui compaiono anche i brani aggiunti dall’app web.';

  @override
  String ytdlLinkShortSent(String link) {
    return 'Link breve: inviato come $link';
  }

  @override
  String ytdlLinkSentAs(String link) {
    return 'Inviato come $link';
  }

  @override
  String get ytdlLinkNotYoutube =>
      'Non è un link di YouTube. Incollane uno da youtube.com o youtu.be.';

  @override
  String get ytdlLinkPlaylist =>
      'È una playlist. Apri un video della playlist e copia il suo link.';

  @override
  String get ytdlLinkInPlaylist => 'Solo questo video, non la playlist.';

  @override
  String get ytdlLinkLive =>
      'Le dirette non si possono salvare. Se questa è finita, potrebbe funzionare comunque.';

  @override
  String get ytdlLinkLiveOlder =>
      'Questo server non rifiuta le dirette. Aggiungilo solo se la diretta è finita.';

  @override
  String get ytdlLookupReading => 'Lettura del video…';

  @override
  String get ytdlLookupSlow =>
      'Ricerca ancora in corso — YouTube può essere lento.';

  @override
  String get ytdlLookupEnterYourself => 'Inserisci i dettagli a mano';

  @override
  String get ytdlLookupFailed =>
      'Impossibile leggere i dettagli di questo video. Potrebbe essere privato, soggetto a limiti di età o bloccato per il server.';

  @override
  String get ytdlLookupTimedOut =>
      'Il server ha impiegato troppo tempo — forse sta ancora preparando il suo strumento per YouTube. Riprova tra un minuto.';

  @override
  String get ytdlLookupEnterDetails => 'Inserisci dettagli';

  @override
  String get ytdlLookupNoTags =>
      'Ancora nessun tag, quindi finisce nella cartella principale della libreria.';

  @override
  String get ytdlLookupFailedUsingYours =>
      'Impossibile leggere i dettagli di questo video · verranno usati i tuoi.';

  @override
  String get ytdlLateFound => 'Dettagli trovati per questo video';

  @override
  String get ytdlLateUseThem => 'Usali';

  @override
  String get ytdlLateEditsStay => 'Le tue modifiche restano.';

  @override
  String get ytdlOffline =>
      'Sei offline — la ricerca partirà quando tornerai online.';

  @override
  String get ytdlYtdlpMissing =>
      'Questo server non può ancora aggiungere brani da YouTube. Chiedi all’amministratore di configurare yt-dlp.';

  @override
  String get ytdlCardNoAlbum => 'Nessun album';

  @override
  String get ytdlSourceMusic => 'Tag da YouTube Music';

  @override
  String get ytdlSourceSplit => 'Artista e titolo dal titolo del video';

  @override
  String get ytdlSourceSplitAgrees =>
      'Artista e titolo dal titolo del video · corrisponde all’artista indicato da YouTube';

  @override
  String get ytdlSourceChannel =>
      'L’artista potrebbe essere il nome del canale — verificalo';

  @override
  String ytdlCleanedFrom(String title) {
    return 'Ripulito da “$title”';
  }

  @override
  String get ytdlUndoAll => 'Ripristina tutto';

  @override
  String get ytdlEditTags => 'Modifica tag';

  @override
  String get ytdlFieldTitle => 'Titolo';

  @override
  String get ytdlHelpMusic => 'Da YouTube Music';

  @override
  String get ytdlHelpVideoTitle => 'Dal titolo del video';

  @override
  String get ytdlHelpVideoTitleCleaned => 'Dal titolo del video, ripulito';

  @override
  String get ytdlHelpYoutubeArtist => 'Dal campo artista di YouTube';

  @override
  String get ytdlHelpYoutubeArtistCheck =>
      'Dal campo artista di YouTube — verificalo';

  @override
  String ytdlHelpYoutubeArtistStripped(String removed) {
    return 'Dal campo artista di YouTube, tolto “$removed” — verificalo';
  }

  @override
  String get ytdlHelpEdited => 'Modificato';

  @override
  String get ytdlBlankTitle =>
      'Vuoto: il file prende il titolo originale del video.';

  @override
  String get ytdlBlankArtistMusic =>
      'Vuoto: il file mantiene l’artista di YouTube Music.';

  @override
  String ytdlBlankArtistGuess(String name) {
    return 'Vuoto: il file prende l’artista ipotizzato da YouTube, spesso il nome grezzo del canale (qui “$name”).';
  }

  @override
  String get ytdlBlankArtistGuessUnnamed =>
      'Vuoto: il file prende l’artista ipotizzato da YouTube, spesso il nome grezzo del canale.';

  @override
  String get ytdlBlankAlbumSingle => 'Lascia vuoto per un singolo';

  @override
  String get ytdlBlankAlbumKeeps => 'Se vuoto, resta il tag album di YouTube';

  @override
  String get ytdlBlankYear =>
      'Vuoto: il file prende l’anno di caricamento su YouTube.';

  @override
  String get ytdlYearInvalid => 'Un anno ha 4 cifre, es. 2001';

  @override
  String ytdlRestoreSplit(String separator) {
    return 'Diviso su $separator';
  }

  @override
  String ytdlOrYoutubeArtist(String name) {
    return 'Oppure l’artista di YouTube: $name';
  }

  @override
  String get ytdlSwap => 'Scambia artista e titolo';

  @override
  String get ytdlSavesTo => 'Finisce in';

  @override
  String get ytdlSavesHere => 'Finisce qui';

  @override
  String get ytdlNewTag => 'nuova';

  @override
  String get ytdlSampleFile => 'file';

  @override
  String get ytdlSampleFileStem => 'Titolo_video';

  @override
  String ytdlFileAbout(String name) {
    return 'nome probabile: $name';
  }

  @override
  String ytdlFileAboutLettersDropped(String name) {
    return 'nome probabile: $name · le lettere fuori da A–Z vengono tolte dai nomi dei file';
  }

  @override
  String get ytdlCheckFailed => 'Impossibile controllare questa cartella';

  @override
  String get ytdlJustThisSong => 'Solo questo brano';

  @override
  String get ytdlUndo => 'Annulla';

  @override
  String ytdlClash(String name) {
    return 'Un file simile a “$name” sembra già presente in questa cartella. Il server non lo sovrascrive, quindi probabilmente l’aggiunta non riuscirà.';
  }

  @override
  String get ytdlClashChangeFormat =>
      'Cambia formato — un formato diverso crea un file diverso';

  @override
  String ytdlClashOlder(String name) {
    return 'In questa cartella c’è già un file chiamato “$name”. Questo server aggiornerebbe i tag di quel file invece di aggiungerne uno nuovo.';
  }

  @override
  String get ytdlChangeFormat => 'Cambia formato';

  @override
  String get ytdlAddToLibrary => 'Aggiungi alla libreria';

  @override
  String get ytdlAddHere => 'Aggiungi qui';

  @override
  String get ytdlAddAnyway => 'Aggiungi comunque';

  @override
  String get ytdlAlreadyAdding => 'Aggiunta già in corso in questa cartella';

  @override
  String get ytdlFormatMenuTitle => 'Il miglior audio del video, salvato come';

  @override
  String ytdlFormatRemembered(String server) {
    return 'Memorizzato per $server';
  }

  @override
  String get ytdlFormatMp3Help => 'Si riproduce ovunque';

  @override
  String get ytdlFormatM4aHelp => 'Ideale per i dispositivi Apple';

  @override
  String get ytdlFormatOpusHelp =>
      'Di solito l’audio originale di YouTube, senza ricodifica';

  @override
  String get ytdlFormatFlacHelp =>
      'Più grande, ma non migliore del suono del video';

  @override
  String get ytdlFormatWavHelp => 'Il più grande, senza copertina';

  @override
  String get ytdlErrFfmpeg =>
      'Il server non può convertire l’audio in questo momento. Riprova più tardi o chiedi all’amministratore.';

  @override
  String get ytdlErrUploadsOff =>
      'Il tuo account non può aggiungere file a questo server.';

  @override
  String ytdlErrLibraryGone(String library) {
    return 'Non puoi più aggiungere file a “$library”. Scegli un’altra libreria.';
  }

  @override
  String ytdlErrLibraryGoneSheet(String library) {
    return 'Non puoi più aggiungere file a “$library”.';
  }

  @override
  String get ytdlErrNoRoute =>
      'Questo server non permette di aggiungere brani da YouTube.';

  @override
  String ytdlErrFormatOff(String format) {
    return 'Questo server non salva più in $format';
  }

  @override
  String get ytdlErrPickAnother => 'scegline un altro';

  @override
  String get ytdlErrBadRequest =>
      'Qualcosa in questo link non va bene per il server. Riprova.';

  @override
  String get ytdlErrServer => 'Qualcosa è andato storto sul server.';

  @override
  String ytdlErrOther(String message) {
    return 'Il server ha risposto: “$message”';
  }

  @override
  String ytdlErrMkdir(String folder) {
    return 'Impossibile creare la cartella “$folder”.';
  }

  @override
  String get ytdlSectionAdding => 'In corso';

  @override
  String get ytdlSectionAddingNote =>
      'Avviene sul server · non si può fermare dall’app';

  @override
  String get ytdlSectionNeedsLook => 'Da controllare';

  @override
  String get ytdlSectionAdded => 'Aggiunti';

  @override
  String ytdlRowAdding(int minutes, String format) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'In corso · $minutes min · $format',
    );
    return '$_temp0';
  }

  @override
  String get ytdlRowStartUnsure => 'Avvio… il server non ha ancora risposto';

  @override
  String get ytdlRowNotSureStarted => 'Avvio non confermato';

  @override
  String get ytdlRowNotFound => 'Non trovato sul server';

  @override
  String get ytdlRowClash =>
      'Non riuscito · sembra che ci sia già un file con questo nome. Non è stato sovrascritto nulla.';

  @override
  String get ytdlRowFailed =>
      'Non riuscito · il server non ha detto perché. Cause comuni: una diretta, YouTube che rifiuta il server, oltre 500 MB o un’ora.';

  @override
  String get ytdlRowFailedOlder =>
      'Non riuscito · il server non ha detto perché. YouTube potrebbe aver rifiutato il server.';

  @override
  String get ytdlRowNotSureFinished =>
      'Fine non confermata · è terminato mentre l’app non era attiva e il server non ne ha traccia';

  @override
  String get ytdlRowWaiting => 'In attesa di connessione';

  @override
  String get ytdlRowFileMissing => 'File mancante';

  @override
  String get ytdlRowHide => 'Nascondi da questo elenco';

  @override
  String get ytdlRowChangeFormatRetry => 'Cambia formato e riprova';

  @override
  String get ytdlRowShowFolder => 'Mostra cartella';

  @override
  String get ytdlRowShowInFolder => 'Mostra nella cartella';

  @override
  String get ytdlShowEarlier => 'Mostra precedenti';

  @override
  String get ytdlWhereTitle => 'Dove finiscono i nuovi brani';

  @override
  String ytdlWhereSub(String server) {
    return 'Resta su questo telefono per $server · le copie di Scopri mantengono la propria impostazione.';
  }

  @override
  String ytdlWhereLandsAt(String title) {
    return '“$title” finisce in';
  }

  @override
  String get ytdlWhereLandsAtSample => 'Un brano finisce in';

  @override
  String get ytdlWhereSampleNote =>
      'Mostrato con parole di esempio finché non incolli un link.';

  @override
  String ytdlWhereFileNote(String title) {
    return 'Il nome del file viene dal titolo del video; la tua libreria mostra “$title”.';
  }

  @override
  String ytdlWhereAlwaysEmpty(String vars) {
    return 'Sempre vuote per i brani da YouTube, quindi escluse: $vars';
  }

  @override
  String get ytdlWhereSetByDiscover => 'Impostata da Scopri';

  @override
  String get ytdlLayoutTop => 'Direttamente nella libreria';

  @override
  String get ytdlLayoutTopSub => 'Nessuna cartella';

  @override
  String get ytdlLayoutDiscover => 'Uguale a Scopri';

  @override
  String get ytdlWhereUseForSong => 'Usa per questo brano';

  @override
  String get ytdlWhereNoMkdir =>
      'Il tuo account non può creare cartelle, quindi funzionano solo quelle già esistenti. “Direttamente nella libreria” funziona sempre.';

  @override
  String get ytdlCustomHelp =>
      'Separa le cartelle con /. Non c’è TITLE: il nome del file viene sempre dal titolo del video.';

  @override
  String ytdlErrNeverVar(String name, String vars) {
    return '$name non ha mai un valore per i brani da YouTube. Usa $vars.';
  }

  @override
  String get ytdlErrBadChars =>
      'Il nome di una cartella non può contenere : * ? \" < > o |.';

  @override
  String ytdlTrapEmpty(String folder) {
    return 'Niente con cui riempire questa cartella, quindi si chiama “$folder”. Aggiungi album e anno, o scegli un’altra struttura.';
  }

  @override
  String ytdlTrapNoYear(String folder) {
    return 'Nessun anno per questo brano, quindi la cartella diventa “$folder”. Il file riceve comunque come tag l’anno di caricamento su YouTube.';
  }

  @override
  String ytdlTrapOther(String folder) {
    return 'Un tag è vuoto, quindi la cartella diventa “$folder”. Compila i tag o scegli un’altra struttura.';
  }

  @override
  String get ytdlTrapAddYear => 'Aggiungi un anno';

  @override
  String ytdlNoMkdirNew(String folder) {
    return '“$folder” non esiste ancora e il tuo account non può creare cartelle.';
  }

  @override
  String get ytdlNoMkdirUnchecked =>
      'Il tuo account non può creare cartelle e non è stato possibile controllare questa cartella.';

  @override
  String ytdlSaveToInstead(String path) {
    return 'Salva invece in $path';
  }

  @override
  String get ytdlChooseFolderLink => 'Scegli una cartella…';

  @override
  String get ytdlChooseTitle => 'Scegli una cartella';

  @override
  String get ytdlChooseSub =>
      'Il tuo account non può creare cartelle, quindi scegline una già esistente.';

  @override
  String get ytdlChooseEmpty => 'Nessuna cartella qui.';

  @override
  String get ytdlExplorerEntry => 'Aggiungi qui da YouTube';

  @override
  String ytdlSheetInto(String path) {
    return 'In $path';
  }

  @override
  String get ytdlSortSubfolders => 'Ordina in sottocartelle…';

  @override
  String get ytdlSubfoldersTitle => 'Ordina in sottocartelle';

  @override
  String get ytdlSubfoldersHere => 'La cartella in cui ti trovi';

  @override
  String get ytdlSubfoldersRightHere => 'Proprio qui';

  @override
  String get ytdlSubfoldersNone => 'Nessuna sottocartella';

  @override
  String ytdlSubfoldersNew(int count, String folders) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verranno create $count nuove cartelle: $folders',
      one: 'Verrà creata $count nuova cartella: $folders',
    );
    return '$_temp0';
  }

  @override
  String ytdlStripAdding(String title) {
    return 'Aggiunta di “$title”…';
  }

  @override
  String ytdlStripAddingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aggiunta di $count video…',
      one: 'Aggiunta di $count video…',
    );
    return '$_temp0';
  }

  @override
  String get ytdlStripSeeAll => 'Vedi tutto';

  @override
  String get ytdlStripDetails => 'Dettagli';

  @override
  String ytdlToastAdded(String title, String path) {
    return '“$title” aggiunto in $path';
  }

  @override
  String ytdlCouldntAdd(String title) {
    return 'Impossibile aggiungere “$title”';
  }

  @override
  String ytdlToastSaved(String path) {
    return 'Salvato · i nuovi brani finiscono in $path';
  }

  @override
  String get ytdlToastHidden => 'Nascosto. Il server continua.';

  @override
  String get ytdlA11yLinkField => 'Link di YouTube';

  @override
  String get ytdlA11yClearLink => 'Cancella link';

  @override
  String ytdlA11yFormat(String format) {
    return 'Formato, $format';
  }

  @override
  String ytdlA11yPutBack(String fragment) {
    return 'Ripristina $fragment';
  }

  @override
  String get ytdlA11yUndoSplit => 'Annulla la divisione al trattino';

  @override
  String get ytdlA11yUndoSplitColon => 'Annulla la divisione ai due punti';

  @override
  String ytdlA11yMoreFor(String title) {
    return 'Altro per $title';
  }

  @override
  String get ytdlA11yAdding => 'Aggiunta in corso';

  @override
  String get ytdlA11yNewFolder => 'una nuova cartella';

  @override
  String ytdlCrumbThen(String previous, String next) {
    return '$previous, poi $next';
  }

  @override
  String ytdlCrumbNew(String folder) {
    return '$folder, una nuova cartella';
  }

  @override
  String ytdlCrumbFile(String path, String file) {
    return '$path, file $file';
  }

  @override
  String get ytdlCrumbEmptyBrackets => 'parentesi vuote';

  @override
  String ytdlCrumbWithEmptyBrackets(String folder) {
    return '$folder con parentesi vuote';
  }

  @override
  String ytdlA11yVarUsed(String name) {
    return '$name, già usato';
  }

  @override
  String get ytdlA11yInsertVariable => 'Inserisci una variabile';

  @override
  String get ytdlA11yLocked => 'Bloccato';

  @override
  String get ytdlA11yFolderPath => 'Percorso della cartella';

  @override
  String ytdlA11yUpTo(String folder) {
    return 'Risali a $folder';
  }

  @override
  String get ytdlA11yCover => 'Copertina';

  @override
  String ytdlSummaryBy(String title, String artist) {
    return '$title, di $artist';
  }

  @override
  String ytdlSummaryAlbum(String album) {
    return 'album $album';
  }

  @override
  String get ytdlSummaryNoAlbum => 'nessun album';

  @override
  String ytdlSummary(String details, String source, String path) {
    return '$details. $source. Finisce in $path.';
  }

  @override
  String get ytdlErrAddOffline =>
      'Sei offline — riprova quando tornerai online.';

  @override
  String get ytdlHelpVideoRelease => 'Dalla data di uscita del video';

  @override
  String get ytdlChooseLoading => 'Caricamento delle cartelle';

  @override
  String get ytdlRowNoConnection =>
      'Non avviato · il telefono non è riuscito a raggiungere il server';

  @override
  String ytdlServerUnreachable(String server) {
    return 'Impossibile raggiungere il server $server. Controlla che sia attivo, poi riprova.';
  }

  @override
  String ytdlErrAddUnreachable(String server) {
    return 'Impossibile raggiungere il server $server — controlla che sia attivo, poi riprova.';
  }
}
