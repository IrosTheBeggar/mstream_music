// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get mainRemove => 'Retirer';

  @override
  String get playlistActionFailed =>
      'Impossible d\'enregistrer la liste : ce nom est peut-être déjà utilisé.';

  @override
  String get queueAddNext => 'Ajouter à la suite';

  @override
  String get queuePlayNow => 'Lire maintenant';

  @override
  String get queueAddToEnd => 'Ajouter à la fin de la file';

  @override
  String get shuffle => 'Aléatoire';

  @override
  String get variousArtists => 'Artistes divers';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languageSystemDefault => 'Langue du système';

  @override
  String get settingsLanguageSubtitle =>
      'La langue d\'affichage de l\'application. « Langue du système » suit votre appareil.';

  @override
  String couldNotOpen(String url) {
    return 'Impossible d\'ouvrir $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistes',
      one: '1 piste',
      zero: 'Aucune piste',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Réinitialiser';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeLight => 'Clair';

  @override
  String get tapAddToQueue => 'Ajouter à la file';

  @override
  String get tapPlayFromHere => 'Lire à partir d\'ici';

  @override
  String get tapAppendAndJump => 'Ajouter et lire';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'Shaders';

  @override
  String get visualizerSourceSynthesized => 'Synthétisé';

  @override
  String get visualizerSourceReal => 'Audio réel';

  @override
  String get downloadsTitle => 'Téléchargements';

  @override
  String downloadProgress(String progress) {
    return 'progression : $progress %';
  }

  @override
  String get songInfoTitle => 'Infos du morceau';

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsEmpty => 'No lyrics found for this song';

  @override
  String get lyricsError => 'Couldn\'t load lyrics';

  @override
  String get lyricsRetry => 'Retry';

  @override
  String get eqTitle => 'Égaliseur';

  @override
  String get eqOnlyAndroid => 'L\'égaliseur n\'est disponible que sur Android.';

  @override
  String get eqNeedsPlayback =>
      'Lancez un morceau pour configurer l\'égaliseur.\n\nL\'égaliseur natif d\'Android s\'initialise avec la session audio ; la lecture doit donc être active avant que nous puissions lire la disposition des bandes.';

  @override
  String eqInitFailed(String error) {
    return 'Impossible d\'initialiser l\'égaliseur :\n$error';
  }

  @override
  String get eqNoBands =>
      'Aucune bande d\'égaliseur signalée par le pilote audio de cet appareil.';

  @override
  String get eqDisabledHint => 'Active l\'égaliseur pour régler les bandes.';

  @override
  String get eqEnabledOn => 'Activé — gains appliqués à la lecture';

  @override
  String get eqEnabledOff => 'Désactivé — mode contournement';

  @override
  String get cancel => 'Annuler';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get openSettings => 'Ouvrir les paramètres';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsSectionAppearance => 'Apparence';

  @override
  String get settingsSectionPlayback => 'Lecture';

  @override
  String get settingsSectionBrowse => 'Navigation';

  @override
  String get settingsSectionAbout => 'À propos';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get themeSubtitleVelvet =>
      'Bleu marine et violet — le thème sombre emblématique.';

  @override
  String get themeSubtitleDark => 'Sombre neutre avec des accents ambrés.';

  @override
  String get themeSubtitleLight =>
      'Corps clair avec une barre d\'application sombre et des accents ambrés — correspond à l\'ancien thème livré.';

  @override
  String get settingsTranscode => 'Transcoder l\'audio';

  @override
  String get settingsTranscodeSubtitle =>
      'Diffuser une copie transcodée depuis le serveur (fichiers plus légers, démarrage un peu plus lent). Désactivé, lit les fichiers d\'origine.';

  @override
  String get transcodeTitle => 'Transcodage';

  @override
  String get transcodeCodec => 'Codec';

  @override
  String get transcodeBitrate => 'Débit binaire';

  @override
  String get transcodeAuto => 'Valeur par défaut du serveur';

  @override
  String get transcodeUnavailable =>
      'Ce serveur n\'a pas le transcodage activé — ses pistes sont diffusées en qualité d\'origine.';

  @override
  String get transcodeReloadQueue => 'Appliquer à la file d\'attente actuelle';

  @override
  String get transcodeReloadQueueSubtitle =>
      'Quand vous modifiez les réglages de transcodage — coché : recharger toute la file maintenant (la piste en cours se remet brièvement en mémoire tampon) ; décoché : seules les pistes à venir changent, celle en cours se termine telle quelle.';

  @override
  String get settingsTapBehavior => 'Lorsque vous touchez un morceau';

  @override
  String get settingsStartupPage => 'Écran de démarrage';

  @override
  String get settingsStartupPageSubtitle =>
      'Ouvrir l’application sur cette vue du navigateur ; Retour revient au navigateur.';

  @override
  String get tapSubtitleAddToQueue =>
      'Toucher un morceau l\'ajoute à la file. Si la file est vide, la lecture démarre automatiquement.';

  @override
  String get tapSubtitlePlayFromHere =>
      'Toucher un morceau remplace la file par les morceaux de la vue actuelle et démarre la lecture au morceau touché.';

  @override
  String get tapSubtitleAppendAndJump =>
      'Toucher un morceau l\'ajoute à la file et y saute la lecture, interrompant ce qui était en cours.';

  @override
  String get settingsEqSubtitle =>
      'Réglez les basses, les médiums et les aigus. Android uniquement.';

  @override
  String get settingsVisualizerEngine => 'Moteur du visualiseur';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'Préréglages Milkdrop via projectM (par défaut). Effets plus riches, plus exigeants pour le GPU.';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Fragment shaders de style Shadertoy. Plus légers et modulaires — déposez des fichiers .glsl dans assets/shaders/ pour enrichir le catalogue.';

  @override
  String get settingsVisualizerSource => 'Source audio du visualiseur';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'Par défaut. Le visualiseur réagit uniquement au rythme de lecture — aucune autorisation micro requise.';

  @override
  String get visualizerSourceSubtitleReal =>
      'Le visualiseur réagit à la sortie audio réelle. Nécessite l\'autorisation RECORD_AUDIO sur Android.';

  @override
  String get settingsAlbumGrid => 'Vue en grille des albums';

  @override
  String get settingsAlbumGridSubtitle =>
      'Afficher les albums sous forme de grille de cartes avec les pochettes au lieu d\'une simple liste.';

  @override
  String get settingsFileMetadata =>
      'Lire les métadonnées dans l\'explorateur de fichiers';

  @override
  String get settingsFileMetadataSubtitle =>
      'Récupérer le titre, l\'artiste et la pochette de chaque morceau lors de la navigation dans les fichiers du serveur. Désactivé, affiche les noms de fichiers bruts (plus rapide pour les gros dossiers).';

  @override
  String get settingsLetterStrip => 'Seuil du défileur alphabétique';

  @override
  String get settingsLetterStripSubtitle =>
      'Afficher la bande de défilement rapide A-Z lorsqu\'une liste compte au moins ce nombre d\'éléments. En dessous de cette taille, la bande est masquée et les longs noms de dossiers/fichiers passent à la ligne au lieu d\'être tronqués. Mettez 0 pour toujours afficher la bande.';

  @override
  String get settingsLetterStripSide => 'Côté du curseur';

  @override
  String get settingsLetterStripSideSubtitle =>
      'Sur quel bord se place la barre A–Z.';

  @override
  String get settingsLetterStripLeft => 'Gauche';

  @override
  String get settingsLetterStripRight => 'Droite';

  @override
  String get settingsReset => 'Réinitialiser aux valeurs par défaut';

  @override
  String get settingsResetSubtitle =>
      'Rétablir tous les paramètres de cet écran à leurs valeurs par défaut. Les serveurs et les téléchargements ne sont pas affectés.';

  @override
  String get settingsResetDone => 'Paramètres rétablis aux valeurs par défaut';

  @override
  String get realAudioDialogTitle => 'Utiliser l\'audio réel ?';

  @override
  String get realAudioDialogBody =>
      'Le mode audio réel lit la forme d\'onde de la musique que votre téléphone joue afin que le visualiseur puisse y réagir. Android nécessite l\'autorisation RECORD_AUDIO pour cela — l\'application n\'enregistre ni n\'envoie aucun audio où que ce soit. Vous pouvez revenir à l\'audio synthétisé à tout moment.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Autorisation définitivement refusée. Activez-la dans les paramètres système pour utiliser l\'audio réel.';

  @override
  String get realAudioPermDenied =>
      'Autorisation refusée. Maintien de l\'audio synthétisé.';

  @override
  String get visualizerTapHint =>
      'Toucher = préréglage suivant · appui long pour fermer';

  @override
  String get visualizerFailed => 'Échec du démarrage du visualiseur';

  @override
  String get visualizerBringingUp => 'Démarrage du moteur de rendu…';

  @override
  String get visualizerReady => 'Visualiseur prêt';

  @override
  String get visualizerBridgeFailed => 'Échec du démarrage du pont';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Source audio : $source';
  }

  @override
  String get visualizerTapToClose => 'Touchez n\'importe où pour fermer';

  @override
  String get visualizerUnsupported =>
      'Le visualiseur n\'est actuellement pris en charge que sur Android.';

  @override
  String get aboutTitle => 'À propos';

  @override
  String aboutBuiltBy(String name) {
    return 'Créé par $name';
  }

  @override
  String get linkDiscordSubtitle => 'Discussion communautaire';

  @override
  String get linkGithubSubtitle => 'Code source du serveur mStream';

  @override
  String get linkHomepageSubtitle => 'Page d\'accueil du projet';

  @override
  String get aboutAttributions => 'Attributions';

  @override
  String get aboutAttributionsSubtitle =>
      'Licence, crédits des shaders et mentions open source.';

  @override
  String get aboutSponsor => 'Soutenir mStream';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get info => 'Infos';

  @override
  String get makeDefault => 'Définir par défaut';

  @override
  String get goBack => 'Retour';

  @override
  String get play => 'Lire';

  @override
  String get playAll => 'Tout lire';

  @override
  String get rename => 'Renommer';

  @override
  String get create => 'Créer';

  @override
  String get copy => 'Copier';

  @override
  String get done => 'Terminé';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get attributionsTitle => 'Attributions';

  @override
  String get attributionsSectionLicense => 'Licence';

  @override
  String get attributionsSectionShaders => 'Shaders du visualiseur';

  @override
  String get attributionsSectionLibraries => 'Bibliothèques natives';

  @override
  String get attributionsSectionEverythingElse => 'Tout le reste';

  @override
  String get attributionsLicenseBody =>
      'Logiciel libre sous la GNU General Public License v3.0. Vous pouvez l\'utiliser, l\'étudier, le partager et le modifier selon ces conditions.';

  @override
  String get attributionsPackages => 'Licences des paquets open source';

  @override
  String get attributionsPackagesSubtitle =>
      'Textes complets des licences de tous les paquets Flutter/Dart inclus.';

  @override
  String get manageServersTitle => 'Gérer les serveurs';

  @override
  String get manageServerInfo => 'Infos du serveur';

  @override
  String get manageServerDownloadFolder => 'Dossier de téléchargement :';

  @override
  String get manageServerCopyPath => 'Copier le chemin de téléchargement';

  @override
  String get manageServerPathCopied => 'Chemin copié dans le presse-papiers';

  @override
  String get confirmRemoveServerTitle => 'Confirmer la suppression du serveur';

  @override
  String get removeSyncedFiles =>
      'Supprimer les fichiers synchronisés de l\'appareil ?';

  @override
  String get playlistsTitle => 'Listes de lecture';

  @override
  String get playlistsNew => 'Nouvelle liste de lecture';

  @override
  String get playlistsEmptyTitle => 'Aucune liste de lecture';

  @override
  String get playlistsEmptyBody =>
      'Créez-en une avec le bouton Nouvelle liste de lecture, puis utilisez l\'action de balayage Ajouter à la liste de lecture de la file pour la remplir.';

  @override
  String get playlistNameHint => 'Nom';

  @override
  String get playlistsRename => 'Renommer la liste de lecture';

  @override
  String get playlistFallbackTitle => 'Liste de lecture';

  @override
  String get playlistEmptyDetail =>
      'La liste de lecture est vide.\nAjoutez des pistes depuis la file.';

  @override
  String get shareEmptyTitle => 'File vide';

  @override
  String get shareEmptyBody =>
      'Ajoutez des morceaux à la file avant de partager.';

  @override
  String get shareBlockedTitle => 'Impossible de partager cette file';

  @override
  String get shareLocalOnlyBody =>
      'La file contient des morceaux qui sont uniquement sur cet appareil (sur aucun serveur). Le partage ne fonctionne que lorsque tous les morceaux de la file proviennent d\'un seul serveur.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'La file mélange des morceaux de $count serveurs ($names). Le partage ne fonctionne que lorsque tous les morceaux proviennent d\'un seul serveur.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'Le serveur « $name » ne figure plus dans votre liste de serveurs. Rajoutez-le pour partager sa file.';
  }

  @override
  String get shareTitle => 'Partager la liste de lecture';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '1 morceau',
    );
    return '$_temp0 de $url';
  }

  @override
  String get shareLinkExpires => 'Le lien expire';

  @override
  String get shareExpireNever => 'Jamais';

  @override
  String get shareExpire1Day => 'Après 1 jour';

  @override
  String get shareExpire7Days => 'Après 7 jours';

  @override
  String get shareExpire30Days => 'Après 30 jours';

  @override
  String get shareAction => 'Partager';

  @override
  String get shareDoneTitle => 'Liste de lecture partagée';

  @override
  String get shareDoneBody =>
      'Toute personne disposant de ce lien peut lire la file :';

  @override
  String get save => 'Enregistrer';

  @override
  String get start => 'Démarrer';

  @override
  String get addServerTitle => 'Ajouter un serveur';

  @override
  String get editServerTitle => 'Modifier le serveur';

  @override
  String get fieldServerUrl => 'URL du serveur';

  @override
  String get fieldPublicAccess => 'Accès public';

  @override
  String get publicAccessSubtitle =>
      'Le serveur est accessible publiquement — aucun nom d\'utilisateur ni mot de passe requis.';

  @override
  String get fieldUsername => 'Nom d\'utilisateur';

  @override
  String get fieldPassword => 'Mot de passe';

  @override
  String get fieldPasswordShow => 'Show password';

  @override
  String get fieldPasswordHide => 'Hide password';

  @override
  String get fieldSdCard => 'Télécharger sur la carte SD';

  @override
  String get sdCardSubtitle =>
      'Enregistrer la musique téléchargée sur la carte SD amovible plutôt que dans le stockage interne.';

  @override
  String get testConnectionButton => 'Tester la connexion';

  @override
  String get testing => 'Test en cours…';

  @override
  String get connecting => 'Connexion…';

  @override
  String get validatorUrlNeeded => 'L\'URL du serveur est requise';

  @override
  String get validatorUrlParse => 'Impossible d\'analyser l\'URL';

  @override
  String get testEnterUrl => 'Saisissez d\'abord une URL de serveur.';

  @override
  String get testParseUrl => 'Impossible d\'analyser l\'URL.';

  @override
  String get testTimedOut => 'Délai de connexion dépassé.';

  @override
  String get connectionSuccessful => 'Connexion réussie !';

  @override
  String get couldNotReachServer =>
      'Impossible de joindre le serveur. S\'il nécessite une connexion, désactivez « Accès public » et ajoutez vos identifiants.';

  @override
  String get failedToLogin => 'Échec de la connexion';

  @override
  String testConnected(String version) {
    return 'Connecté — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'Connexion impossible : $error';
  }

  @override
  String get sleepTimerTitle => 'Minuterie de veille';

  @override
  String get sleepTimerHint =>
      'Choisissez une durée après laquelle mettre la lecture en pause.';

  @override
  String get sleepTimerCustom => 'Personnalisé';

  @override
  String get sleepTimerCustomHint => 'minutes (1–600)';

  @override
  String get sleepTimerCancel => 'Annuler la minuterie';

  @override
  String get sleepTimerInvalid => 'Saisissez un nombre entre 1 et 600 minutes';

  @override
  String sleepTimerPausesIn(String time) {
    return 'Pause dans $time';
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
      other: 'Minuterie de veille réglée sur $minutes minutes',
      one: 'Minuterie de veille réglée sur 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Ajouter';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String get autoDjAddServerFirst => 'Ajoutez d\'abord un serveur.';

  @override
  String get autoDjSectionServer => 'Serveur';

  @override
  String get autoDjSectionSources => 'Sources';

  @override
  String get autoDjSectionContinuity => 'Continuité';

  @override
  String get autoDjSectionFilters => 'Filtres';

  @override
  String get autoDjBpmTitle => 'Continuité du BPM';

  @override
  String get autoDjBpmSubtitle =>
      'Privilégier les choix dans une fenêtre de tempo proche du morceau actuel. Prend en compte l\'équivalence demi/double tempo.';

  @override
  String get autoDjTolerance => 'Tolérance';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Mixage harmonique';

  @override
  String get autoDjHarmonicSubtitle =>
      'Privilégier les choix dans des tonalités qui se mixent bien avec le morceau verrouillé (voisins de la roue Camelot).';

  @override
  String get autoDjDurationTitle => 'Durée des morceaux';

  @override
  String get autoDjDurationSubtitle =>
      'Ignore les interludes et les longs mixes en ne choisissant que des morceaux dans une plage de durée';

  @override
  String get autoDjDurationRange => 'Durée';

  @override
  String get autoDjDurationAny => 'Toute durée';

  @override
  String autoDjDurationOver(String min) {
    return 'Plus de $min';
  }

  @override
  String autoDjDurationUnder(String max) {
    return 'Moins de $max';
  }

  @override
  String autoDjDurationBetween(String min, String max) {
    return 'De $min à $max';
  }

  @override
  String get autoDjDurationAllowUnknown =>
      'Inclure les morceaux de durée inconnue';

  @override
  String get autoDjDurationAllowUnknownSub =>
      'Les morceaux dont votre serveur n’a pas lu la durée sont sinon ignorés';

  @override
  String get autoDjStatusOn => 'Auto DJ activé';

  @override
  String get autoDjStatusOff => 'Auto DJ désactivé';

  @override
  String get autoDjStatusOffDetail =>
      'Touchez ci-dessous pour démarrer. La bibliothèque du serveur actuel sera utilisée.';

  @override
  String get autoDjStart => 'Démarrer Auto DJ';

  @override
  String get autoDjStop => 'Arrêter Auto DJ';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'Les morceaux sont choisis depuis $url lorsque la file s\'épuise.';
  }

  @override
  String get autoDjOneSourceRequired => 'Au moins une source est requise.';

  @override
  String get autoDjMinRating => 'Note minimale';

  @override
  String get autoDjMinRatingSubtitle =>
      'Ne choisir que les morceaux égaux ou supérieurs à cette note.';

  @override
  String get autoDjRatingAny => 'Indifférent';

  @override
  String get autoDjGenreTitle => 'Filtre par genre';

  @override
  String get autoDjGenreSubtitle =>
      'La liste blanche ne lit que les pistes correspondantes ; la liste noire les ignore.';

  @override
  String get autoDjWhitelist => 'Liste blanche';

  @override
  String get autoDjBlacklist => 'Liste noire';

  @override
  String get autoDjNoGenres =>
      'Aucun genre sélectionné. Touchez « Choisir des genres » pour en choisir.';

  @override
  String get autoDjPickGenres => 'Choisir des genres';

  @override
  String get autoDjGenreLoadError => 'Impossible de charger les genres';

  @override
  String get autoDjKeywordTitle => 'Filtre par mot-clé';

  @override
  String get autoDjKeywordSubtitle =>
      'Ignorer les choix dont le titre, l\'artiste, l\'album ou le chemin de fichier contient l\'un de ces mots.';

  @override
  String get autoDjNoKeywords =>
      'Aucun mot-clé. Ajoutez des mots ci-dessous pour commencer à filtrer.';

  @override
  String get autoDjKeywordHint => 'p. ex. « live » ou « remix »';

  @override
  String get autoDjSearchGenres => 'Rechercher des genres…';

  @override
  String get autoDjNoGenresOnServer => 'Aucun genre trouvé sur ce serveur.';

  @override
  String autoDjSelectedCount(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return 'Aucun genre ne correspond à « $query ».';
  }

  @override
  String get download => 'Télécharger';

  @override
  String get addAll => 'Tout ajouter';

  @override
  String get browserMoreActions => 'Plus d\'actions';

  @override
  String get browserConfirmDeletePlaylist =>
      'Confirmer la suppression de la liste de lecture';

  @override
  String get browserConfirmDeleteFolder =>
      'Confirmer la suppression du dossier';

  @override
  String get browserSearchHint => 'Rechercher dans la base de données';

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
      other: '$count téléchargements démarrés',
      one: '1 téléchargement démarré',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux ajoutés à la file',
      one: '1 morceau ajouté à la file',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Explorateur';

  @override
  String get tabQueue => 'File';

  @override
  String get drawerTagline => 'Streaming musical personnel';

  @override
  String get mainFailedToConnect => 'Échec de la connexion au serveur';

  @override
  String get mainQueueEmpty => 'La file est vide';

  @override
  String get visualizerTitle => 'Visualiseur';

  @override
  String get mainClearQueue => 'Vider la file';

  @override
  String get mainSync => 'Synchroniser';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistes',
      one: '1 piste',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ activé';

  @override
  String get autoDjDisabled => 'Auto DJ désactivé';

  @override
  String autoDjEnabledFor(String url) {
    return 'Auto DJ activé pour $url';
  }

  @override
  String get addToPlaylistTitle => 'Ajouter à la liste de lecture';

  @override
  String get addToPlaylistEmpty =>
      'Aucune liste de lecture — touchez + pour en créer une.';

  @override
  String addedToPlaylist(String name) {
    return 'Ajouté à $name';
  }

  @override
  String get testConnectedSignedIn => 'Connecté — connexion réussie.';

  @override
  String get testSignInFailed =>
      'Serveur joint, mais la connexion a échoué — vérifiez votre nom d\'utilisateur et votre mot de passe.';

  @override
  String get browserFileExplorer => 'Explorateur de fichiers';

  @override
  String get browserLocalFiles => 'Fichiers locaux';

  @override
  String get browserPlaylists => 'Listes de lecture';

  @override
  String get browserAlbums => 'Albums';

  @override
  String get browserArtists => 'Artistes';

  @override
  String get browserRecent => 'Récents';

  @override
  String get browserRated => 'Notés';

  @override
  String get browserSearch => 'Rechercher';

  @override
  String get browserWelcomeTitle => 'Bienvenue sur mStream';

  @override
  String get browserWelcomeSubtitle => 'Touchez ici pour ajouter un serveur';

  @override
  String get settingsVisualizerKnobs => 'Réglages du visualiseur';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      'Affiche des curseurs sur le visualiseur pour ajuster la réactivité audio de chaque shader. Moteur de shaders uniquement.';

  @override
  String get visualizerTuningTitle => 'Réglage';

  @override
  String get close => 'Fermer';

  @override
  String get migMoveStopped =>
      'Déplacement interrompu — espace insuffisant ou emplacement indisponible.';

  @override
  String get migMoveComplete => 'Déplacement terminé';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Déplacement terminé — $count fichiers ignorés (non pris en charge sur la destination)',
      one:
          'Déplacement terminé — 1 fichier ignoré (non pris en charge sur la destination)',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'Déplacement des téléchargements… $progress — gardez l’application ouverte';
  }

  @override
  String get migRetry => 'Réessayer';

  @override
  String get queueDownloadAll => 'Tout télécharger';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistes seront téléchargées pour une lecture hors ligne.',
      one: '1 piste sera téléchargée pour une lecture hors ligne.',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'Plus';

  @override
  String get commonOn => 'Activé';

  @override
  String get commonOff => 'Désactivé';

  @override
  String get settingsCastQuality => 'Qualité du visualiseur diffusé';

  @override
  String get settingsCastQualitySubtitle720 =>
      'Résolution à laquelle le visualiseur est diffusé sur un téléviseur. 720p — la plus légère pour le téléphone.';

  @override
  String get settingsCastQualitySubtitle1080 =>
      'Résolution à laquelle le visualiseur est diffusé sur un téléviseur. 1080p — net sur tout Chromecast (par défaut).';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Résolution à laquelle le visualiseur est diffusé sur un téléviseur. 4K — nécessite un Chromecast 4K ; bien plus exigeant pour le téléphone.';

  @override
  String get eqCasting =>
      'L’égaliseur ajuste l’audio sur cet appareil, il est donc indisponible pendant la diffusion. Déconnectez-vous pour l’utiliser.';

  @override
  String get browserNothingToDownload => 'Rien à télécharger dans cette liste';

  @override
  String get browserDownloadAllTitle => 'Tout télécharger';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers seront téléchargés.',
      one: '1 fichier sera téléchargé.',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => 'Fermer la recherche';

  @override
  String get browserSearchThisList => 'Rechercher dans cette liste';

  @override
  String get browserSearchList => 'Rechercher dans la liste';

  @override
  String browserNoMatches(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get clear => 'Effacer';

  @override
  String get dlLocationUnavailable =>
      'Emplacement de téléchargement indisponible';

  @override
  String get dlLocationUnavailableServer =>
      'Emplacement de téléchargement indisponible pour ce serveur.';

  @override
  String get dlFailed =>
      'Un téléchargement a échoué — vérifiez votre connexion.';

  @override
  String get dlFatSkip =>
      'Certaines pistes ne peuvent pas être enregistrées sur cette carte — leurs noms ne sont pas pris en charge. Elles sont diffusées à la place.';

  @override
  String get dlServerGone => 'Ce serveur n\'est plus configuré.';

  @override
  String get dlStorageUnavailable =>
      'Emplacement de stockage indisponible — reconnectez la carte SD ou modifiez l\'emplacement de stockage de ce serveur dans Modifier le serveur.';

  @override
  String get dlCouldNotStart =>
      'Impossible de démarrer le téléchargement — stockage indisponible.';

  @override
  String get storageLocationLabel => 'Emplacement de stockage';

  @override
  String get storageAppLocal => 'Local à l\'application';

  @override
  String get storagePermanent => 'Permanent';

  @override
  String get storageSdCard => 'Carte SD';

  @override
  String get storageSdSwitchTitle => 'Save to SD card';

  @override
  String get storageSdSwitchSubtitle =>
      'Stored in the SD card\'s app folder — no permission needed, but removed if you uninstall the app.';

  @override
  String get storageHelpAppLocal =>
      'Enregistré dans l\'application. Supprimé lorsque vous désinstallez ou videz l\'application.';

  @override
  String get storageHelpPermanent =>
      'Enregistré dans un dossier de votre choix. Conservé après la désinstallation de l\'application. Nécessite « Accès à tous les fichiers ».';

  @override
  String get storageHelpSdCard =>
      'Enregistré dans un dossier de la carte SD que vous choisissez. Peut devenir indisponible si la carte est retirée. Certains appareils n\'autorisent pas les applications à écrire sur les cartes SD — si la sélection du dossier échoue sans cesse, utilisez Permanent ou Local à l\'application.';

  @override
  String get storageChooseFolder => 'Choisir un dossier';

  @override
  String get storageNoFolderChosen => 'Aucun dossier choisi pour l\'instant';

  @override
  String get storageDownloadFolderLabel => 'Dossier de téléchargement';

  @override
  String get storageDownloadFolderHint => 'nom du dossier';

  @override
  String get storageBrowse => 'Parcourir';

  @override
  String get storageDownloadFolderHelp =>
      'Les fichiers se téléchargent dans un dossier « media/<folder> » sur cet appareil. Réutiliser le dossier d\'un serveur précédent conserve ses morceaux téléchargés lorsque vous rajoutez un serveur perdu.';

  @override
  String get storageNoStorageAvailable => 'Aucun stockage disponible';

  @override
  String get storageNoDownloadFolders =>
      'Aucun dossier de téléchargement existant trouvé';

  @override
  String get storageExistingFolders => 'Dossiers de téléchargement existants';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'Accordez l\'« Accès à tous les fichiers » pour stocker les téléchargements de façon permanente, puis choisissez à nouveau le mode.';

  @override
  String get storageSettings => 'Paramètres';

  @override
  String get storageNoVolume => 'Impossible de localiser un volume de stockage';

  @override
  String get storageNotWritable =>
      'Ce dossier n\'est pas accessible en écriture — choisissez-en un autre.';

  @override
  String get storageNewFolder => 'Nouveau dossier';

  @override
  String get storageFolderNameHint => 'Nom du dossier';

  @override
  String get storageCouldNotCreateFolder => 'Impossible de créer le dossier';

  @override
  String get storageNoSubfolders => 'Aucun sous-dossier ici';

  @override
  String get storageUseThisFolder => 'Utiliser ce dossier';

  @override
  String get storageMovedToNewFolder =>
      'Fichiers téléchargés déplacés vers le nouveau dossier.';

  @override
  String get storageMoveAlreadyRunning =>
      'Un déplacement est déjà en cours — laissez-le se terminer d\'abord.';

  @override
  String get storageMigrateTitle => 'Volume de stockage différent';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Les $count fichiers téléchargés de ce serveur ($size) se trouvent sur un volume de stockage différent du nouvel emplacement. Choisissez ce qu’il faut faire :',
      one:
          'Le fichier téléchargé de ce serveur ($size) se trouve sur un volume de stockage différent du nouvel emplacement. Choisissez ce qu’il faut faire :',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return 'Espace libre insuffisant à la destination ($free libres). Un déplacement risque d\'échouer en cours de route — libérez d\'abord de l\'espace.';
  }

  @override
  String get storageMigrateMove => 'Les déplacer';

  @override
  String get storageMigrateMoveBody =>
      'Copier vers le nouvel emplacement en arrière-plan, en supprimant chaque ancienne copie au fur et à mesure. Gardez l\'application ouverte jusqu\'à la fin.';

  @override
  String get storageMigrateLeave => 'Les laisser';

  @override
  String get storageMigrateLeaveBody =>
      'Changer maintenant ; les anciens téléchargements restent où ils sont et seront retéléchargés au nouvel emplacement.';

  @override
  String get storageMigrateDelete => 'Supprimer les anciens téléchargements';

  @override
  String get storageMigrateDeleteBody =>
      'Changer maintenant et supprimer les anciens fichiers ; ils seront retéléchargés au nouvel emplacement.';

  @override
  String get storageMovingBackground =>
      'Déplacement de vos téléchargements en arrière-plan — gardez l\'application ouverte.';

  @override
  String get storageChooseFolderFirst =>
      'Choisissez d\'abord un dossier de téléchargement.';

  @override
  String get storageChooseSdFolderFirst =>
      'Choisissez d\'abord un dossier sur la carte SD. Si chaque dossier est rejeté, votre appareil n\'autorise peut-être pas les applications à écrire sur la carte — utilisez Permanent ou Local à l\'application à la place.';

  @override
  String get castPlayOn => 'Diffuser sur';

  @override
  String get castPlayOnTooltip => 'Diffuser sur…';

  @override
  String get castSearching => 'Recherche d’appareils de diffusion…';

  @override
  String get castNotSeeing =>
      'Vous ne voyez pas votre appareil ? Vérifiez qu’il est sur le même réseau Wi-Fi.';

  @override
  String get castVisualizer => 'Diffuser le visualiseur';

  @override
  String get castVisualizerSubtitle =>
      'Diffuser le visualiseur sur le téléviseur · Chromecast uniquement';

  @override
  String get visualizerNoKnobs => 'Ce shader n’expose aucun réglage.';

  @override
  String get nowPlaying => 'Lecture en cours';

  @override
  String get playerLayoutSmall => 'Petit';

  @override
  String get playerLayoutMedium => 'Moyen';

  @override
  String get playerLayoutLarge => 'Grand';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => 'Barre fine — file maximale';

  @override
  String get playerLayoutMediumDesc => 'Bannière — équilibré (par défaut)';

  @override
  String get playerLayoutLargeDesc => 'Compact — pochette centrée';

  @override
  String get playerLayoutXlDesc => 'Grand format — pochette complète';

  @override
  String get queueNothingToDownloadEmpty =>
      'La file est vide — rien à télécharger';

  @override
  String get queueNothingToDownloadSaved =>
      'Rien à télécharger — les titres sont déjà enregistrés';

  @override
  String get settingsAccentColor => 'Couleur d\'accent';

  @override
  String get settingsAccentColorSubtitle =>
      'La couleur de mise en évidence utilisée dans toute l\'application.';

  @override
  String get accentThemeDefault => 'Par défaut du thème';

  @override
  String get accentCustom => 'Personnalisé';

  @override
  String get lanOnYourNetwork => 'Serveurs sur votre réseau local';

  @override
  String get lanSearching => 'Recherche de serveurs…';

  @override
  String get lanRefresh => 'Actualiser';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return 'Connexion à $name';
  }

  @override
  String get lanUnreachable =>
      'Impossible de joindre ce serveur sur le réseau.';

  @override
  String get lanNoCode =>
      'Quick Connect est activé sur ce serveur, mais aucun code d\'appairage n\'a été partagé. Connectez-vous en tant qu\'admin ou demandez à l\'opérateur d\'activer le partage du code.';

  @override
  String get settingsResumeQueue => 'Reprendre la file au démarrage';

  @override
  String get settingsResumeQueueSubtitle =>
      'Enregistre la file de lecture et votre position, puis les restaure à la réouverture de l\'application.';

  @override
  String get settingsOfflineQueue =>
      'Garder la file d\'attente disponible hors ligne';

  @override
  String get settingsOfflineQueueSubtitle =>
      'Télécharge automatiquement les pistes de la file d\'attente sur cet appareil pour que la lecture survive à une perte de connexion.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Télécharger uniquement en Wi-Fi';

  @override
  String get settingsOfflineQueueWifiOnlySubtitle =>
      'Attend une connexion Wi-Fi avant de télécharger les pistes de la file d\'attente.';

  @override
  String get settingsAutoDownloadCap => 'Auto-download limit';

  @override
  String get settingsAutoDownloadCapSubtitle =>
      'Met en cache ce nombre de morceaux à partir du morceau en cours ; ceux qui sont dépassés sont supprimés.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Met en cache toute la file d\'attente (sans limite).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unlimited';

  @override
  String get settingsAutoDownloadCapField => 'Number of tracks';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Combien de morceaux de la file restent téléchargés, à partir de celui en cours. Au fil de la lecture, les morceaux dépassés sont supprimés. 0 pour toute la file.';

  @override
  String get downloadWaitingWifi => 'En attente du Wi-Fi';

  @override
  String get settingsRatingHalf => 'Notes en demi-étoiles';

  @override
  String get settingsRatingHalfSubtitle =>
      'Noter les morceaux par demi-étoile (appui long sur une étoile).';

  @override
  String get ratingTitle => 'Noter';

  @override
  String get ratingFailed => 'Note non enregistrée';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get diagnosticsEnable => 'Activer la journalisation';

  @override
  String get diagnosticsHint =>
      'Les journaux restent sur votre appareil. Les jetons sont masqués avant copie ou partage.';

  @override
  String get diagnosticsVerbose => 'Verbose logging';

  @override
  String get diagnosticsVerboseHint =>
      'Also logs high-frequency events like app focus changes. Only needed when diagnosing a playback issue.';

  @override
  String get diagnosticsCopy => 'Copier';

  @override
  String get diagnosticsShare => 'Partager';

  @override
  String get diagnosticsClear => 'Effacer';

  @override
  String get diagnosticsCopied => 'Journaux copiés dans le presse-papiers';

  @override
  String get diagnosticsEmpty => 'Aucun journal pour l\'instant';

  @override
  String get storageAppExternal => 'App externe';

  @override
  String get storageAppSdCard => 'Carte SD de l\'app';

  @override
  String get selfSignedTitle => 'Autoriser le certificat auto-signé';

  @override
  String get selfSignedSubtitle =>
      'Ignore la validation TLS pour ce serveur. À n\'activer que sur un réseau de confiance.';

  @override
  String get importedShadersTitle => 'Shaders importés';

  @override
  String get importedShadersSettingsSubtitle =>
      'Ajoutez vos propres fichiers .glsl à la rotation du moteur Shader.';

  @override
  String get importedShadersRescan => 'Réanalyser le dossier';

  @override
  String get importedShadersDropHint =>
      'Déposez des fichiers .glsl dans ce dossier, puis Réanalyser :';

  @override
  String get importedShadersCopyPath => 'Copier le chemin';

  @override
  String get importedShadersReachableHint =>
      'Accessible via USB ou un gestionnaire de fichiers (sous Android/data). Les shaders importés rejoignent la rotation lorsque le moteur Shader est actif.';

  @override
  String get importedShadersRemove => 'Retirer';

  @override
  String get importedShadersEmptyTitle =>
      'Aucun shader dans le dossier pour l’instant';

  @override
  String get importedShadersEmptyBody =>
      'Copiez des fichiers .glsl de style Shadertoy dans le dossier ci-dessus, puis touchez Réanalyser.';

  @override
  String get importedShadersInvalid =>
      'N’est peut-être pas un shader valide — aucun point d’entrée mainImage/main.';

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
  String get discoverTitle => 'Découvrir';

  @override
  String get discoverMatchedBySound => 'Correspondances sonores';

  @override
  String get discoverSimilarTracks => 'Titres similaires';

  @override
  String get discoverSimilarArtists => 'Artistes similaires';

  @override
  String get discoverFromNetwork => 'Depuis le réseau';

  @override
  String get discoverFromPeers => 'De vos pairs';

  @override
  String get discoverQueueAll => 'Tout ajouter à la file';

  @override
  String get discoverNewArtistsOnly => 'Nouveaux artistes uniquement';

  @override
  String get discoverNotAnalyzed =>
      'Ce titre n\'a pas encore été analysé — les titres similaires apparaîtront quand l\'analyse de découverte l\'aura traité.';

  @override
  String get discoverScanPendingTitle => 'Rien n\'a encore été analysé';

  @override
  String get discoverScanPendingBody =>
      'La découverte est activée sur ce serveur, mais aucune musique n\'a encore été analysée. Les titres similaires apparaîtront une fois l\'analyse de découverte effectuée.';

  @override
  String get discoverCheckAgain => 'Vérifier à nouveau';

  @override
  String get discoverTurnedOff =>
      'La découverte a été désactivée sur ce serveur.';

  @override
  String get pathScanPending =>
      'Ce serveur n\'a encore analysé aucune musique, il n\'y a donc rien pour tracer un parcours. Cela fonctionnera une fois l\'analyse de découverte effectuée.';

  @override
  String get discoverNothingFound => 'Aucune correspondance trouvée.';

  @override
  String get discoverNoSeed =>
      'Lancez un titre pour découvrir de la musique similaire.';

  @override
  String get discoverLeadCopied => 'Copié — bonne recherche !';

  @override
  String get discoverOpenMusicBrainz => 'Ouvrir sur MusicBrainz';

  @override
  String get discoverNetworkWarmingUp =>
      'Pas encore de données réseau — les bibliothèques des pairs se téléchargent en arrière-plan dès que d\'autres serveurs sont détectés.';

  @override
  String get discoverNetworkNothingNew =>
      'Rien de nouveau pour ce titre — le réseau n\'a aucune correspondance inconnue.';

  @override
  String get discoverPeersUnreachable =>
      'Vos pairs n\'ont pas répondu — ils sont peut-être hors ligne en ce moment.';

  @override
  String get discoverPeersNothingNew =>
      'Rien de nouveau pour ce titre sur les serveurs de vos pairs.';

  @override
  String get autoDjSonicTitle => 'Similarité sonore';

  @override
  String get autoDjSonicSubtitle =>
      'Ne choisit que des titres qui sonnent comme la session, grâce à l\'analyse audio du serveur.';

  @override
  String get autoDjSonicUnavailable =>
      'Ce serveur n\'a pas de données de découverte — la sélection reste aléatoire.';

  @override
  String get autoDjSonicStrictness => 'Seuil de similarité';

  @override
  String autoDjSonicStrictnessValue(int pct) {
    return '$pct % ou plus proche';
  }

  @override
  String get autoDjSonicSeedLabel => 'Titre de départ';

  @override
  String get autoDjSonicSeedNone =>
      'Aucun titre de départ — le titre en cours ancre la session.';

  @override
  String get autoDjSonicSeedBanner =>
      'Choisis le titre de départ — touche une piste n\'importe où dans la bibliothèque';

  @override
  String get autoDjSonicSeedSearchHint => 'Rechercher un titre…';

  @override
  String get autoDjSonicSeedRandom => 'Titre aléatoire';

  @override
  String get autoDjSonicSeedRemove => 'Retirer le titre de départ';

  @override
  String get autoDjSonicSeedFailed =>
      'Impossible de récupérer un titre depuis le serveur.';

  @override
  String get autoDjSeedNoMatch =>
      'Aucun morceau ne correspond à vos filtres Auto DJ — essayez de les assouplir';

  @override
  String get discoverFindSimilar => 'Titres similaires';

  @override
  String get discoverStartSession => 'Lancer une session sonore';

  @override
  String get discoverStartSessionSubtitle =>
      'De la musique sans fin qui sonne comme ce titre — remplace votre file d\'attente.';

  @override
  String get discoverStartSessionSubtitleRandom =>
      'De la musique sans fin à partir d\'un titre de départ aléatoire — remplace votre file d\'attente.';

  @override
  String get discoverSessionStarted =>
      'Session sonore lancée — Auto DJ activé.';

  @override
  String get autoDjSonicAnchorLabel => 'Ancre';

  @override
  String get autoDjSonicAnchorRolling => 'Suivre l\'ambiance';

  @override
  String get autoDjSonicAnchorLocked => 'Rester sur le titre de départ';

  @override
  String get autoDjSonicAnchorRollingHint =>
      'Chaque titre suit le son récent de la session — elle peut évoluer lentement.';

  @override
  String get autoDjSonicAnchorLockedHint =>
      'Chaque titre reste proche du titre de départ pendant toute la session.';

  @override
  String get trackAddToPlaylist => 'Ajouter à la playlist';

  @override
  String get trackAddToPlaylistFailed => 'Impossible d\'ajouter à la playlist.';

  @override
  String get discoverPlayPathTo => 'Jouer un chemin vers…';

  @override
  String get pathScreenTitle => 'Chemin sonore';

  @override
  String get pathStartNotAnalyzed =>
      'Le titre de départ n\'a pas encore été analysé — attendez l\'analyse de découverte ou choisissez-en un autre.';

  @override
  String get pathEndNotAnalyzed =>
      'Le titre de destination n\'a pas encore été analysé — attendez l\'analyse de découverte ou choisissez-en un autre.';

  @override
  String get pathStartSong => 'Chanson de départ';

  @override
  String get pathEndSong => 'Chanson d\'arrivée';

  @override
  String get pathLength => 'Longueur';

  @override
  String get pathRegenerate => 'Régénérer';

  @override
  String get pathSaveAsPlaylist => 'Enregistrer comme playlist';

  @override
  String get pathSetupHint =>
      'Choisis un morceau de départ et un d\'arrivée — le voyage entre les deux se remplit tout seul.';

  @override
  String get pathNotSet => 'Non défini';

  @override
  String get pathUsePlaying => 'Utiliser le morceau en cours';

  @override
  String get pathSearchSong => 'Rechercher';

  @override
  String get pathBrowseLibrary => 'Parcourir la bibliothèque';

  @override
  String get pathBuild => 'Créer le voyage';

  @override
  String get pathStartOver => 'Recommencer';

  @override
  String get pathPickBannerStart =>
      'Choisis le morceau de départ — touche une piste n\'importe où dans la bibliothèque';

  @override
  String get pathPickBannerEnd =>
      'Choisis le morceau d\'arrivée — touche une piste n\'importe où dans la bibliothèque';

  @override
  String get pathNothingPlaying => 'Aucune lecture en cours';

  @override
  String pathPickOnServer(String server) {
    return 'Choisis une piste sur $server';
  }

  @override
  String get welcomeTranslationNote =>
      'Cette langue a été traduite automatiquement et peut sembler maladroite.';

  @override
  String get welcomeTranslationCta => 'Aidez à traduire mStream';

  @override
  String get setupTitle => 'Configuration rapide';

  @override
  String get setupSkip => 'Ignorer';

  @override
  String get setupNext => 'Suivant';

  @override
  String get setupFinish => 'Terminer';

  @override
  String get setupBack => 'Retour';

  @override
  String get setupAccentTitle => 'Choisissez votre couleur';

  @override
  String get setupAccentBody =>
      'La couleur d\'accent met en valeur les boutons, les curseurs et les commandes du lecteur. Touchez-en une pour l\'essayer.';

  @override
  String get setupVisualizerTitle => 'Audio réel pour le visualiseur';

  @override
  String get setupVisualizerBody =>
      'Le visualiseur utilise des données synthétisées tant que ceci n\'est pas activé.';

  @override
  String get setupVisualizerWarning =>
      'L\'activer demande l\'autorisation du micro : Android l\'exige des applications qui décodent le flux audio de l\'appareil (ce que fait le visualiseur).';

  @override
  String get setupPlaybackTitle => 'Quand vous touchez un morceau';

  @override
  String get setupOfflineTitle => 'Gardez votre file d\'attente hors ligne';

  @override
  String get setupVisualizerNoMic => 'mStream n\'utilise jamais votre micro.';

  @override
  String get playlistEmpty => 'La liste de lecture est vide';

  @override
  String get trackRating => 'Note';

  @override
  String albumDiscNumber(int n) {
    return 'Disque $n';
  }

  @override
  String get autoDjStartTitle => 'Démarrer Auto DJ avec quoi ?';

  @override
  String get autoDjStartSubtitle =>
      'La file est vide, le DJ a besoin d\'un premier titre. Avec une file, il suit simplement ce qui s\'y trouve.';

  @override
  String get autoDjStartRandom => 'Surprends-moi';

  @override
  String get autoDjStartRandomSub =>
      'Choisir un titre au hasard dans la bibliothèque et partir de là.';

  @override
  String get autoDjStartPick => 'Je choisis';

  @override
  String get autoDjStartPickSub =>
      'Ouvrir la bibliothèque et choisir le premier titre soi-même.';

  @override
  String get autoDjStartRemember => 'Mémoriser';

  @override
  String get autoDjStartRememberSub =>
      'Passer cette question la prochaine fois et toujours démarrer ainsi.';

  @override
  String get autoDjStartPickBanner =>
      'Choisis le premier titre — touche une piste n\'importe où dans la bibliothèque';

  @override
  String get autoDjOnEmptyQueue => 'File vide';

  @override
  String get autoDjOnEmptyQueueSub =>
      'Ce que fait Auto DJ quand tu l\'actives sans rien dans la file.';

  @override
  String get autoDjStartAskShort => 'Demander';

  @override
  String serverVersionLabel(String version) {
    return 'Serveur v$version';
  }

  @override
  String get serverVersionUnknown => 'Version du serveur inconnue';

  @override
  String get serverUpdateUrgent => 'Mets à jour ton serveur';

  @override
  String get serverUpdateAvailable => 'Mise à jour du serveur disponible';

  @override
  String serverTooOldWarning(String version) {
    return 'Ce serveur est en version v$version. Certaines fonctions nécessitent v5.5 ou plus récent et seront indisponibles.';
  }

  @override
  String get autoDjNeedsNewerServer =>
      'La continuité BPM, le mixage harmonique et le filtre de genres nécessitent un serveur plus récent. Mets à jour pour en profiter.';

  @override
  String get autoDjSonicNeedsNewerServer =>
      'Nécessite un serveur 6.15.2 ou plus récent';

  @override
  String get torrentScreenTitle => 'Ajouter un torrent';

  @override
  String get torrentNoServer => 'Aucun serveur configuré.';

  @override
  String get torrentServerLabel => 'Serveur';

  @override
  String get torrentLibraryLabel => 'Bibliothèque';

  @override
  String get torrentNoLibraries => 'Aucune bibliothèque sur ce serveur';

  @override
  String get torrentSourceLabel => 'Source';

  @override
  String get torrentChooseFile => 'Choisir un fichier .torrent';

  @override
  String get torrentOr => 'ou';

  @override
  String get torrentMagnetLabel => 'Lien magnet';

  @override
  String get torrentMagnetInvalid => 'Lien magnet non valide';

  @override
  String torrentNotATorrent(String name) {
    return '« $name » n’est pas un fichier .torrent';
  }

  @override
  String get torrentOpenWith => 'Ouvrir dans une autre application';

  @override
  String get torrentOpenWithNone =>
      'Aucune application de cet appareil ne peut ouvrir un fichier .torrent';

  @override
  String get torrentOpenWithFailed =>
      'Impossible de transmettre le torrent à une autre application';

  @override
  String get torrentIntentTitle => 'Torrent reçu';

  @override
  String get torrentIntentBody =>
      'Ajoutez-le à une bibliothèque de votre serveur mStream, ou confiez-le à une autre application.';

  @override
  String get torrentIntentAdd => 'Ajouter à mStream';

  @override
  String get torrentIntentDontAsk =>
      'Toujours ajouter à mStream, ne plus demander';

  @override
  String get settingsTorrentAskTitle => 'Demander quoi faire des torrents';

  @override
  String get settingsTorrentAskSub =>
      'À l’ouverture d’un torrent avec mStream, proposer de le confier à une autre application';

  @override
  String get settingsTorrentDefaultTitle =>
      'Application par défaut pour les torrents';

  @override
  String get settingsTorrentDefaultSub =>
      'Ouvre les paramètres Android, où vous choisissez quelle application ouvre les torrents et les liens magnet';

  @override
  String get settingsTorrentDefaultFailed =>
      'Impossible d’ouvrir les paramètres Android';

  @override
  String get torrentAutoDetect => 'Détecter les métadonnées';

  @override
  String get torrentDetecting => 'Détection…';

  @override
  String get torrentDetectNoMetadata =>
      'Métadonnées insuffisantes — remplis les champs à la main';

  @override
  String get torrentDetected => 'Métadonnées détectées';

  @override
  String get torrentDetectGuess =>
      'Estimation approximative — vérifie les champs';

  @override
  String get torrentMetadataLabel => 'Métadonnées';

  @override
  String get torrentArtistLabel => 'Artiste';

  @override
  String get torrentAlbumLabel => 'Album';

  @override
  String get torrentYearLabel => 'Année';

  @override
  String get torrentDestinationLabel => 'Destination';

  @override
  String get torrentPathLabel => 'Chemin dans la bibliothèque';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹aucune bibliothèque›/$path';
  }

  @override
  String get torrentPreviewContents => '‹contenu du torrent›';

  @override
  String get torrentRenameRoot => 'Renommer le dossier racine du torrent';

  @override
  String get torrentRenameRootSub =>
      'L\'aligner sur le nom du dossier de destination';

  @override
  String get torrentForceFresh => 'Forcer un téléchargement complet';

  @override
  String get torrentForceFreshSub =>
      'Ne pas vérifier les fichiers déjà sur le serveur';

  @override
  String get torrentSubmit => 'Ajouter le torrent';

  @override
  String get torrentSubmitting => 'Ajout…';

  @override
  String get torrentUnavailable =>
      'Les torrents ne sont pas disponibles sur ce serveur.';

  @override
  String get torrentPickLibrary => 'Choisis une bibliothèque';

  @override
  String get torrentOneSource =>
      'Ajoute un lien magnet ou un fichier .torrent (un seul)';

  @override
  String get torrentPathEmpty => 'Le chemin de destination est vide';

  @override
  String get torrentSeeded => 'Déjà sur le disque — partage en cours';

  @override
  String get torrentAlreadyInClient => 'Déjà dans le client torrent';

  @override
  String get torrentInvalidFile => 'Fichier torrent invalide';

  @override
  String get torrentSeedCheckFailed =>
      'Impossible de vérifier les fichiers existants — téléchargement complet';

  @override
  String get torrentPartialTitle => 'Certains fichiers existent déjà';

  @override
  String get torrentPartialBody =>
      'Pointe le torrent vers une copie existante pour la partager et ne télécharger que ce qui manque.';

  @override
  String torrentPartialCount(String matched, String total) {
    return '$matched/$total fichiers ici';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · $missing à télécharger';
  }

  @override
  String get torrentDownloadFresh => 'Télécharger quand même';

  @override
  String get torrentMatchNoFolder =>
      'Cette correspondance n\'a pas de nom de dossier — utilise \'Télécharger quand même\'';

  @override
  String torrentAdded(String name) {
    return '« $name » ajouté';
  }

  @override
  String torrentDuplicate(String name) {
    return '« $name » est déjà dans le client';
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
  String get adminLogOut => 'Se déconnecter';

  @override
  String get adminConfigGroup => 'Configuration';

  @override
  String get adminDirectories => 'Répertoires';

  @override
  String get adminUsers => 'Utilisateurs';

  @override
  String get adminDLNA => 'DLNA';

  @override
  String get adminTorrent => 'Torrent';

  @override
  String get adminFederation => 'Fédération';

  @override
  String get adminServerGroup => 'Serveur';

  @override
  String get adminAbout => 'À propos';

  @override
  String get adminSettings => 'Paramètres';

  @override
  String get adminDatabase => 'Base de données';

  @override
  String get adminBackups => 'Sauvegardes';

  @override
  String get adminTranscoding => 'Transcodage';

  @override
  String get adminLogs => 'Journaux';

  @override
  String get adminAccess => 'Accès admin';

  @override
  String adminAppBarTitle(String label) {
    return 'mStream Admin · $label';
  }

  @override
  String get adminPanelTitle => 'mStream Admin';

  @override
  String get adminLoginErrorRequired =>
      'Le serveur et le nom d\'utilisateur sont requis';

  @override
  String get adminLoginServerURL => 'URL du serveur';

  @override
  String get adminLoginUsername => 'Nom d\'utilisateur';

  @override
  String get adminLoginPassword => 'Mot de passe';

  @override
  String get adminLoginSignIn => 'Se connecter';

  @override
  String get adminRetry => 'Réessayer';

  @override
  String get adminSaved => 'Enregistré';

  @override
  String get adminSave => 'Enregistrer';

  @override
  String get adminClose => 'Fermer';

  @override
  String get adminPanelMenuItem => 'Panneau d\'administration';

  @override
  String get adminNoLibrariesYetTitle => 'Aucune bibliothèque pour l\'instant';

  @override
  String get adminAddDirectoryHint =>
      'Ajoutez un répertoire pour commencer à analyser la musique dans la bibliothèque.';

  @override
  String get adminAddDirectoryButton => 'Ajouter un répertoire';

  @override
  String adminRemoveDirectoryTitle(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get adminRemoveDirectoryWarning =>
      'Cela supprime la bibliothèque et ses pistes analysées de la base de données. Les fichiers sur le disque ne sont pas modifiés.';

  @override
  String get adminCancel => 'Annuler';

  @override
  String get adminRemove => 'Supprimer';

  @override
  String get adminLibraryRemovedToast => 'Bibliothèque supprimée';

  @override
  String get adminDirectoryPathLabel => 'Chemin';

  @override
  String get adminDirectoryTypeLabel => 'Type';

  @override
  String get adminFollowSymlinksTitle => 'Suivre les liens symboliques';

  @override
  String get adminFollowSymlinksSubtitle =>
      'Prend effet à la prochaine analyse';

  @override
  String get adminPickFolderAndNameError =>
      'Choisissez un dossier et saisissez un nom';

  @override
  String get adminDirectoryAddedToast => 'Répertoire ajouté — analyse démarrée';

  @override
  String get adminAddDirectoryDialogTitle => 'Ajouter un répertoire';

  @override
  String get adminChooseFolderButton => 'Choisir un dossier sur le serveur…';

  @override
  String get adminLibraryNameLabel => 'Nom de la bibliothèque (vpath)';

  @override
  String get adminLibraryNameHelper => 'Lettres, chiffres et tirets';

  @override
  String get adminGrantAllUsersAccessTitle =>
      'Accorder l\'accès à tous les utilisateurs';

  @override
  String get adminAdd => 'Ajouter';

  @override
  String get adminChooseFolderTitle => 'Choisir un dossier';

  @override
  String get adminSelectFolderButton => 'Sélectionner ce dossier';

  @override
  String get adminNoUsersTitle => 'Aucun utilisateur';

  @override
  String get adminNoUsersSubtitle =>
      'Sans utilisateur, le serveur fonctionne en mode ouvert/public. Ajoutez-en un pour exiger une connexion.';

  @override
  String get adminAddUserButton => 'Ajouter un utilisateur';

  @override
  String get adminLibraryAccessDialogTitle => 'Accès aux bibliothèques';

  @override
  String get adminLibraryAccessUpdatedToast =>
      'Accès aux bibliothèques mis à jour';

  @override
  String get adminSetPasswordTitle => 'Définir le mot de passe';

  @override
  String get adminPasswordUpdatedToast => 'Mot de passe mis à jour';

  @override
  String adminDeleteUserTitle(String username) {
    return 'Supprimer $username ?';
  }

  @override
  String get adminDeleteUserWarning =>
      'Cela supprime définitivement le compte utilisateur.';

  @override
  String get adminDelete => 'Supprimer';

  @override
  String get adminUserDeletedToast => 'Utilisateur supprimé';

  @override
  String get adminStatusPillLabel => 'admin';

  @override
  String get adminDeleteUserMenuItem => 'Supprimer l\'utilisateur';

  @override
  String get adminNoLibraryAccessLabel => 'Aucun accès aux bibliothèques';

  @override
  String get adminLibrariesButton => 'Bibliothèques';

  @override
  String get adminAdminToggleTitle => 'Admin';

  @override
  String get adminMakeDirsToggleTitle => 'Créer dossiers';

  @override
  String get adminUploadToggleTitle => 'Téléverser';

  @override
  String get adminModifyFilesToggleTitle => 'Modifier fichiers';

  @override
  String get adminServerAudioToggleTitle => 'Audio serveur';

  @override
  String get adminAddUserDialogTitle => 'Ajouter un utilisateur';

  @override
  String get adminUsername => 'Nom d\'utilisateur';

  @override
  String get adminPassword => 'Mot de passe';

  @override
  String get adminLibraryAccessHeader => 'Accès aux bibliothèques';

  @override
  String get adminUsernamePasswordRequiredError =>
      'Le nom d\'utilisateur et le mot de passe sont requis';

  @override
  String get adminUserCreatedToast => 'Utilisateur créé';

  @override
  String get adminAdministratorToggleTitle => 'Administrateur';

  @override
  String get adminAllowMakeDirectoriesTitle =>
      'Autoriser la création de dossiers';

  @override
  String get adminAllowUploadTitle => 'Autoriser le téléversement';

  @override
  String get adminAllowServerAudioTitle => 'Autoriser l\'audio serveur';

  @override
  String get adminCreate => 'Créer';

  @override
  String get adminNoLibrariesConfigured => 'Aucune bibliothèque configurée.';

  @override
  String get adminNewPasswordLabel => 'Nouveau mot de passe';

  @override
  String get adminLibraryTitle => 'Bibliothèque';

  @override
  String get adminTracksInDatabase => 'Pistes dans la base de données';

  @override
  String get adminScanAllButton => 'Tout analyser';

  @override
  String get adminScanStarted => 'Analyse démarrée';

  @override
  String get adminForceRescan => 'Forcer la réanalyse';

  @override
  String get adminFullRescanStarted => 'Réanalyse complète démarrée';

  @override
  String get adminCompressImages => 'Compresser les images';

  @override
  String get adminImageCompressionStarted => 'Compression des images démarrée';

  @override
  String get adminScanOptions => 'Options d\'analyse';

  @override
  String get adminScanInterval =>
      'Intervalle d\'analyse (heures, 0 = désactivé)';

  @override
  String get adminBootScanDelay => 'Délai d\'analyse au démarrage (secondes)';

  @override
  String get adminScanCommitInterval =>
      'Intervalle de validation d\'analyse (1–1000)';

  @override
  String get adminScanThreads => 'Threads d\'analyse (0 = auto)';

  @override
  String get adminSkipImageExtraction => 'Ignorer l\'extraction des images';

  @override
  String get adminCompressEmbeddedImages => 'Compresser les images intégrées';

  @override
  String get adminGenerateWaveforms =>
      'Générer les formes d\'onde après l\'analyse';

  @override
  String get adminAnalyzeBpm => 'Analyser BPM/tonalité (obsolète, sans effet)';

  @override
  String get adminAutomaticAlbumArt => 'Pochettes d\'album automatiques';

  @override
  String get adminDownloadMissingAlbumArt =>
      'Télécharger les pochettes manquantes';

  @override
  String get adminTargetLabel => 'Cible';

  @override
  String get adminMissingOnly => 'Manquantes uniquement';

  @override
  String get adminAllAlbums => 'Tous les albums';

  @override
  String get adminAlbumsPerRun => 'Albums par exécution (1–10000)';

  @override
  String get adminAutoDownloadedArtWriteFolder =>
      'Pochettes auto-téléchargées → écrire dans le dossier';

  @override
  String get adminManualArtWriteFolder =>
      'Pochette définie manuellement → écrire dans le dossier';

  @override
  String get adminManualArtEmbedTag =>
      'Pochette définie manuellement → intégrer dans la balise du fichier';

  @override
  String get adminArtServices => 'Services de pochettes';

  @override
  String get adminArtServicesUpdated => 'Services de pochettes mis à jour';

  @override
  String get adminSharedPlaylists => 'Listes de lecture partagées';

  @override
  String get adminDeleteExpired => 'Supprimer les expirées';

  @override
  String get adminExpiredSharesDeleted => 'Partages expirés supprimés';

  @override
  String get adminDeleteNeverExpiring => 'Supprimer les sans expiration';

  @override
  String get adminEternalSharesDeleted => 'Partages permanents supprimés';

  @override
  String get adminNoSharedPlaylists => 'Aucune liste de lecture partagée';

  @override
  String adminSharedPlaylistSubtitle(String user, int count, String expiry) {
    return 'par $user · $count pistes · expire le $expiry';
  }

  @override
  String get adminShareDeleted => 'Partage supprimé';

  @override
  String get adminNetwork => 'Réseau';

  @override
  String get adminNetworkSubtitle =>
      'Modifier ces paramètres redémarre le serveur en douceur.';

  @override
  String get adminBindAddress => 'Adresse de liaison';

  @override
  String get adminPort => 'Port';

  @override
  String get adminTrustProxyHeaders => 'Faire confiance aux en-têtes du proxy';

  @override
  String get adminTrustProxyHeadersSubtitle =>
      'Activez derrière un proxy inverse (X-Forwarded-*)';

  @override
  String get adminPermissions => 'Autorisations';

  @override
  String get adminAllowUploads => 'Autoriser les téléversements';

  @override
  String get adminAllowMakingDirectories => 'Autoriser la création de dossiers';

  @override
  String get adminAllowModifyingFiles =>
      'Autoriser la modification des fichiers';

  @override
  String get adminMaxRequestSize => 'Taille maximale de requête';

  @override
  String get adminMaxRequestSizeHelper => 'p. ex. 50MB ou 512KB';

  @override
  String get adminHttpUi => 'HTTP et interface';

  @override
  String get adminResponseCompression => 'Compression des réponses';

  @override
  String get adminCompressionNone => 'Aucune';

  @override
  String get adminCompressionGzip => 'gzip';

  @override
  String get adminCompressionBrotli => 'brotli';

  @override
  String get adminWebUi => 'Interface web';

  @override
  String get adminUiDefault => 'Par défaut';

  @override
  String get adminUiVelvet => 'Velvet';

  @override
  String get adminDatabaseTuning => 'Optimisation de la base de données';

  @override
  String get adminSqliteSynchronous => 'SQLite synchronous';

  @override
  String get adminSyncFull => 'FULL (safest)';

  @override
  String get adminSyncNormal => 'NORMAL (faster)';

  @override
  String get adminCacheSize => 'Taille du cache (Mo, 1–2048)';

  @override
  String get adminLogging => 'Journalisation';

  @override
  String get adminWriteLogsToDisk => 'Écrire les journaux sur le disque';

  @override
  String get adminLogBufferSize => 'Taille du tampon de journal';

  @override
  String get adminLogBufferSizeHelper => '0–10000, 0 = désactivé';

  @override
  String get adminServerAudio => 'Audio serveur';

  @override
  String get adminAutoBootServerAudio =>
      'Démarrer automatiquement l\'audio serveur (lecteur Rust)';

  @override
  String get adminRustPlayerPort => 'Port du lecteur Rust';

  @override
  String get adminActiveBackend => 'Backend actif';

  @override
  String get adminPlayer => 'Lecteur';

  @override
  String get adminDetectedCliPlayers => 'Lecteurs CLI détectés';

  @override
  String get adminNone => 'aucun';

  @override
  String get adminReDetectPlayers => 'Redétecter les lecteurs';

  @override
  String get adminReProbedCliPlayers => 'Lecteurs CLI re-sondés';

  @override
  String get adminSslHttps => 'SSL / HTTPS';

  @override
  String get adminEnabled => 'Activé';

  @override
  String get adminDisabled => 'Désactivé';

  @override
  String get adminReplaceCertificate => 'Remplacer le certificat';

  @override
  String get adminSetCertificate => 'Définir le certificat';

  @override
  String get adminSetSslCertificateDialog => 'Définir le certificat SSL';

  @override
  String get adminCertificatePath => 'Chemin du certificat';

  @override
  String get adminKeyPath => 'Chemin de la clé';

  @override
  String get adminSslConfigured => 'SSL configuré — redémarrez pour appliquer';

  @override
  String get adminRemoveSsl => 'Supprimer le SSL';

  @override
  String get adminSslRemoved => 'SSL supprimé';

  @override
  String get adminSecurity => 'Sécurité';

  @override
  String get adminJwtSecretLast4 => 'Secret JWT (4 derniers)';

  @override
  String get adminRegenerateSecret => 'Régénérer le secret';

  @override
  String get adminSecretRegenerated =>
      'Secret régénéré — toutes les sessions invalidées';

  @override
  String get adminRegenerateJwtSecretDialog => 'Régénérer le secret JWT ?';

  @override
  String get adminRegenerateJwtSecretDialogBody =>
      'Cela invalide toutes les connexions existantes (y compris celle-ci). Chacun devra se reconnecter.';

  @override
  String get adminRegenerateButton => 'Régénérer';

  @override
  String get adminAllNetworks => 'Tous les réseaux';

  @override
  String get adminLocalhostOnly => 'Localhost uniquement';

  @override
  String get adminIpWhitelist => 'Liste blanche d\'IP';

  @override
  String get adminNoneLockAdmin => 'Aucun (verrouiller l\'admin)';

  @override
  String get adminNetworkAccess => 'Accès réseau';

  @override
  String get adminNetworkAccessSubtitle =>
      'Restreignez les réseaux pouvant atteindre l\'API admin.';

  @override
  String get adminMode => 'Mode';

  @override
  String get adminWhitelistedIps => 'IP / CIDR en liste blanche';

  @override
  String get adminNoneYet => 'Aucun pour l\'instant';

  @override
  String get adminAddIpOrCidr => 'Ajouter une IP ou un CIDR';

  @override
  String get adminCidrExample => '192.168.1.0/24';

  @override
  String get adminApply => 'Appliquer';

  @override
  String get adminDangerZone => 'Zone de danger';

  @override
  String get adminLockAdminApi => 'Verrouiller l\'API admin';

  @override
  String get adminLockAdminApiSubtitle =>
      'Désactiver entièrement l\'API admin. Irréversible depuis ici.';

  @override
  String get adminLockButton => 'Verrouiller';

  @override
  String get adminLockAdminApiDialog => 'Verrouiller l\'API admin ?';

  @override
  String get adminLockAdminApiDialogBody =>
      'Cela désactive entièrement l\'API /admin pour tous. Vous ne pourrez pas l\'annuler depuis ce panneau — il faut modifier le fichier de configuration du serveur et le redémarrer. Continuer ?';

  @override
  String get adminAdminApiLocked => 'API admin verrouillée';

  @override
  String get adminAccessUpdated => 'Accès admin mis à jour';

  @override
  String get adminTranscodingFFmpegTitle => 'FFmpeg';

  @override
  String get adminFFmpegStatusReady => 'Prêt';

  @override
  String get adminFFmpegStatusNotDownloaded => 'Non téléchargé';

  @override
  String get adminFFmpegDownloadButton => 'Télécharger / mettre à jour ffmpeg';

  @override
  String get adminFFmpegDownloadedToast => 'ffmpeg téléchargé';

  @override
  String get adminFFmpegAutoUpdateTitle =>
      'Mettre à jour ffmpeg automatiquement';

  @override
  String get adminFFmpegAutoUpdateSubtitle =>
      'Garder le ffmpeg intégré à jour automatiquement';

  @override
  String get adminTranscodingDefaultsTitle => 'Valeurs par défaut';

  @override
  String get adminDefaultCodecLabel => 'Codec par défaut';

  @override
  String get adminDefaultBitrateLabel => 'Débit par défaut';

  @override
  String get adminLogsResumeButton => 'Reprendre';

  @override
  String get adminLogsPauseButton => 'Pause';

  @override
  String get adminClear => 'Effacer';

  @override
  String get adminLogsAutoScrollTitle => 'Défilement automatique';

  @override
  String adminLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes',
      one: '1 ligne',
    );
    return '$_temp0';
  }

  @override
  String get adminLogsDownloadZipButton => 'Télécharger le zip';

  @override
  String get adminLogsNoEntriesHint =>
      'Aucune entrée de journal pour l\'instant';

  @override
  String get adminDlnaModeDisabled => 'Désactivé';

  @override
  String get adminSamePortAsHttp => 'Même port que HTTP';

  @override
  String get adminSeparatePort => 'Port séparé';

  @override
  String get adminDlnaBrowseFlat => 'À plat (toutes les pistes)';

  @override
  String get adminDlnaBrowseDirectories => 'Répertoires';

  @override
  String get adminDlnaBrowseArtist => 'Par artiste';

  @override
  String get adminDlnaBrowseAlbum => 'Par album';

  @override
  String get adminDlnaBrowseGenre => 'Par genre';

  @override
  String get adminDlnaServerTitle => 'Serveur';

  @override
  String get adminDlnaIdentityTitle => 'Identité';

  @override
  String get adminDlnaFriendlyNameLabel => 'Nom convivial';

  @override
  String get adminDlnaDeviceUuidLabel => 'UUID de l\'appareil';

  @override
  String get adminDlnaDeviceUuidHelper => 'GUID canonique';

  @override
  String get adminDlnaBrowseLayoutTitle => 'Disposition de navigation';

  @override
  String get adminDlnaStructureLabel => 'Structure';

  @override
  String get adminTestConnection => 'Tester la connexion';

  @override
  String get adminKeyNameLabel => 'Nom / libellé de la clé';

  @override
  String get adminMintKey => 'Générer la clé';

  @override
  String get adminTorrentClient => 'Client';

  @override
  String get adminActiveClient => 'Client actif';

  @override
  String get adminTransmission => 'Transmission';

  @override
  String get adminQbittorrent => 'qBittorrent';

  @override
  String get adminDeluge => 'Deluge';

  @override
  String get adminEnabledFor => 'Activé pour';

  @override
  String get adminAllUsers => 'Tous les utilisateurs';

  @override
  String get adminWhitelistedUsers => 'Utilisateurs en liste blanche';

  @override
  String get adminHost => 'Hôte';

  @override
  String get adminPasswordUnchangedIfBlank => 'inchangé si vide';

  @override
  String get adminRpcPath => 'Chemin RPC';

  @override
  String get adminUseHttps => 'Utiliser HTTPS';

  @override
  String get adminTest => 'Tester';

  @override
  String adminReachable(String version) {
    return 'Accessible$version';
  }

  @override
  String adminConnectionFailed(String error) {
    return 'Échec : $error';
  }

  @override
  String get adminConnectAndSave => 'Connecter et enregistrer';

  @override
  String adminSaveFailed(String error) {
    return 'Échec : $error';
  }

  @override
  String get adminConnectedAndSaved => 'Connecté et enregistré';

  @override
  String get adminDisconnect => 'Déconnecter';

  @override
  String get adminDisconnected => 'Déconnecté';

  @override
  String get adminConfigured => 'Configuré';

  @override
  String get adminNotConfigured => 'Non configuré';

  @override
  String get adminTorrents => 'Torrents';

  @override
  String get adminConnected => 'Connecté';

  @override
  String get adminNoTorrents => 'Aucun torrent';

  @override
  String get adminMstream => 'mStream';

  @override
  String get adminTorrentRemoved => 'Torrent supprimé';

  @override
  String get adminLibraryDaemonPathMapping =>
      'Mappage bibliothèque → chemin du démon';

  @override
  String get adminLibraryDaemonPathMappingSubtitle =>
      'Mappe chaque bibliothèque à son chemin tel que le démon torrent le voit.';

  @override
  String get adminAutoDetectAll => 'Tout détecter automatiquement';

  @override
  String get adminAutoDetectionComplete => 'Détection automatique terminée';

  @override
  String get adminVerified => 'vérifié';

  @override
  String get adminUnverified => 'non vérifié';

  @override
  String get adminSetManually => 'Définir manuellement';

  @override
  String adminDaemonPathFor(String name) {
    return 'Chemin du démon pour « $name »';
  }

  @override
  String get adminPathOnDaemonHost => 'Chemin sur l\'hôte du démon';

  @override
  String get adminVerifyAndSave => 'Vérifier et enregistrer';

  @override
  String get adminVpathVerified => 'Vérifié';

  @override
  String get adminVpathSavedUnverified => 'Enregistré (non vérifié)';

  @override
  String get adminDownloadPathTemplates =>
      'Modèles de chemin de téléchargement';

  @override
  String adminPathTemplateVars(String vars) {
    return 'Variables : $vars';
  }

  @override
  String get adminNoLibraries => 'Aucune bibliothèque';

  @override
  String adminSuggestedTemplate(String template) {
    return 'Suggéré : $template';
  }

  @override
  String get adminTemplateSaved => 'Modèle enregistré';

  @override
  String get adminNoBackupDestinations => 'Aucune destination de sauvegarde';

  @override
  String get adminBackupDestinationInfo =>
      'Ajoutez une destination pour répliquer une bibliothèque vers un autre dossier.';

  @override
  String get adminAddDestination => 'Ajouter une destination';

  @override
  String get adminAddLibraryFirst => 'Ajoutez d\'abord une bibliothèque';

  @override
  String get adminBackupQueue => 'File de sauvegarde';

  @override
  String adminTasksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches en file',
      one: '1 tâche en file',
    );
    return '$_temp0';
  }

  @override
  String adminBackingUp(String library) {
    return 'Sauvegarde en cours : $library';
  }

  @override
  String get adminRunning => 'en cours';

  @override
  String adminBackupStats(int done, String total, String stats) {
    return '$done fichiers$total$stats';
  }

  @override
  String get adminBackupDisabled => 'désactivé';

  @override
  String get adminDestination => 'Destination';

  @override
  String get adminTrigger => 'Déclencheur';

  @override
  String adminDailyTriggerTime(String trigger, String hour) {
    return '$trigger à $hour h 00';
  }

  @override
  String get adminRetention => 'Rétention';

  @override
  String adminRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get adminLastRun => 'Dernière exécution';

  @override
  String adminLastRunStatus(String status, int files) {
    return '$status · $files copiés';
  }

  @override
  String get adminRunNow => 'Exécuter maintenant';

  @override
  String get adminBackupQueued => 'Sauvegarde mise en file';

  @override
  String get adminAlreadyRunningSkipped => 'Déjà en cours — ignorée';

  @override
  String get adminHistory => 'Historique';

  @override
  String get adminEdit => 'Modifier';

  @override
  String get adminDestinationDeleted => 'Destination supprimée';

  @override
  String get adminBackupHistory => 'Historique des sauvegardes';

  @override
  String get adminNoHistoryYet => 'Aucun historique pour l\'instant';

  @override
  String get adminEditDestination => 'Modifier la destination';

  @override
  String get adminAddBackupDestination =>
      'Ajouter une destination de sauvegarde';

  @override
  String get adminDestinationPath => 'Chemin de destination';

  @override
  String get adminBrowseServer => 'Parcourir le serveur';

  @override
  String get adminCheckPath => 'Vérifier le chemin';

  @override
  String get adminTriggerField => 'Déclencheur';

  @override
  String get adminAfterEachScan => 'Après chaque analyse';

  @override
  String get adminDaily => 'Quotidien';

  @override
  String get adminManualOnly => 'Manuel uniquement';

  @override
  String get adminRunAtHour => 'Exécuter à l\'heure : ';

  @override
  String get adminRetentionFieldLabel =>
      'Rétention (jours, 0 = tout conserver)';

  @override
  String get adminEnabledToggle => 'Activé';

  @override
  String get adminDestinationUpdated => 'Destination mise à jour';

  @override
  String get adminDestinationCreated => 'Destination créée';

  @override
  String get adminPickLibrary => 'Choisissez une bibliothèque';

  @override
  String get adminPickDestinationPath => 'Choisissez un chemin de destination';

  @override
  String adminAboutTitle(String version) {
    return 'mStream v$version';
  }

  @override
  String get adminAboutPort => 'Port';

  @override
  String get adminSSL => 'SSL';

  @override
  String get adminUI => 'Interface';

  @override
  String get adminCompression => 'Compression';

  @override
  String get adminTrustProxy => 'Confiance au proxy';

  @override
  String get adminYes => 'Oui';

  @override
  String get adminNo => 'Non';

  @override
  String get adminSecretLast4 => 'Secret (4 derniers)';

  @override
  String get adminUploads => 'Téléversements';

  @override
  String get adminMakeDirs => 'Créer dossiers';

  @override
  String get adminFileModify => 'Modifier fichiers';

  @override
  String get adminSynchronous => 'Synchronous';

  @override
  String get adminCacheSizeLabel => 'Taille du cache';

  @override
  String adminCacheSizeMb(int size) {
    return '$size Mo';
  }

  @override
  String get adminFederationDescription =>
      'Associez d’autres serveurs mStream : émettez des clés pour qu’ils lisent vos bibliothèques, ou ajoutez leurs tickets pour lire les leurs.';

  @override
  String get adminAllowed => 'Autorisé';

  @override
  String get adminBackupEnabled => 'activé';

  @override
  String get adminNotAvailable => 'Non disponible';

  @override
  String get adminNotMapped => 'non mappé';

  @override
  String get adminExpiryNever => 'jamais';

  @override
  String get adminUnknownUser => 'inconnu';

  @override
  String get adminFederationEnableTitle => 'Activer la fédération';

  @override
  String get adminFederationEnableSubtitle =>
      'Autoriser ce serveur à s’associer à d’autres serveurs mStream';

  @override
  String get adminFederationEndpointId => 'ID de point de terminaison';

  @override
  String get adminFederationRelay => 'Relais';

  @override
  String get adminFederationOnline => 'En ligne';

  @override
  String get adminFederationOffline => 'Hors ligne';

  @override
  String get adminFederationStopped => 'Arrêté';

  @override
  String get adminFederationUnsupportedTitle => 'Non pris en charge ici';

  @override
  String get adminFederationUnsupportedBody =>
      'Cette version ne contient pas de point de terminaison de fédération pour votre plateforme ; elle ne peut pas fonctionner ici.';

  @override
  String get adminFederationCopy => 'Copier';

  @override
  String get adminFederationCopied => 'Copié';

  @override
  String get adminFederationKeysTitle => 'Clés que vous avez émises';

  @override
  String get adminFederationKeysSubtitle =>
      'Identifiants que d’autres serveurs utilisent pour lire depuis celui-ci';

  @override
  String get adminFederationNoKeys => 'Aucune clé émise pour l’instant';

  @override
  String get adminFederationMintTitle => 'Émettre une clé';

  @override
  String get adminFederationCopyTicket => 'Afficher le ticket';

  @override
  String get adminFederationTicketTitle => 'Ticket';

  @override
  String get adminFederationTicketBody =>
      'Transmettez-le à l’administrateur de l’autre serveur. Il n’est affiché qu’une fois.';

  @override
  String get adminFederationNoTicket =>
      'Aucun ticket disponible pour cette clé';

  @override
  String get adminFederationEditLimits => 'Modifier les limites';

  @override
  String get adminFederationLimitsTitle => 'Limites';

  @override
  String get adminFederationLimitsSaved => 'Limites enregistrées';

  @override
  String get adminFederationStreamKbps => 'Plafond de flux (kb/s)';

  @override
  String get adminFederationDailyMb => 'Plafond quotidien (Mo)';

  @override
  String get adminFederationMaxStreams => 'Flux simultanés';

  @override
  String get adminFederationUnlimitedHint => '0 signifie illimité';

  @override
  String get adminFederationUnlimited => 'illimité';

  @override
  String adminFederationKbps(int kbps) {
    return '$kbps kb/s';
  }

  @override
  String adminFederationMbPerDay(int mb) {
    return '$mb Mo/jour';
  }

  @override
  String adminFederationStreams(int count) {
    return '$count flux';
  }

  @override
  String adminFederationUsageToday(String used) {
    return 'Aujourd’hui : $used';
  }

  @override
  String get adminFederationExpired => 'Expirée';

  @override
  String get adminFederationBound => 'liée';

  @override
  String get adminFederationUnbound => 'non liée';

  @override
  String get adminFederationResetBinding => 'Réinitialiser la liaison';

  @override
  String get adminFederationResetBindingDone => 'Liaison réinitialisée';

  @override
  String get adminFederationRevoke => 'Révoquer';

  @override
  String adminFederationRevokeTitle(String name) {
    return 'Révoquer $name ?';
  }

  @override
  String get adminFederationRevokeBody =>
      'Tous les flux utilisant cette clé seront coupés immédiatement.';

  @override
  String get adminFederationRevoked => 'Clé révoquée';

  @override
  String get adminFederationPeersTitle => 'Serveurs que vous lisez';

  @override
  String get adminFederationPeersSubtitle =>
      'Serveurs qui vous ont donné un ticket et depuis lesquels vous pouvez lire';

  @override
  String get adminFederationNoPeers => 'Aucun pair ajouté pour l’instant';

  @override
  String get adminFederationAddPeer => 'Ajouter un pair';

  @override
  String get adminFederationAddPeerBody =>
      'Collez le ticket fourni par l’autre serveur. Il contient son adresse et la clé d’accès.';

  @override
  String get adminFederationTicketLabel => 'Ticket';

  @override
  String get adminFederationPeerNameLabel => 'Nom (facultatif)';

  @override
  String get adminFederationPeerAdded => 'Pair ajouté';

  @override
  String get adminFederationPeerRemoved => 'Pair supprimé';

  @override
  String adminFederationRemovePeerTitle(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get adminFederationTestOk => 'Pair joignable';

  @override
  String adminFederationLastSeen(String when) {
    return 'Vu pour la dernière fois $when';
  }

  @override
  String get adminFederationNeverSeen => 'Jamais joint';

  @override
  String get adminFederationUseDiscovery =>
      'Envoyer des requêtes de découverte';

  @override
  String get adminFederationUseDiscoverySubtitle =>
      'Partage avec ce pair ce que vous écoutez';
}
