// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

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
  String get settingsTapBehavior => 'Lorsque vous touchez un morceau';

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
  String get testCouldNotConnect =>
      'Connexion impossible. Vérifiez l\'URL et réessayez.';

  @override
  String get testTimedOut => 'Délai de connexion dépassé.';

  @override
  String get connectFailedSnack =>
      'Impossible de se connecter au serveur. Vérifiez l\'URL et réessayez.';

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
  String get autoDjActiveSource => 'Source active';

  @override
  String get autoDjActiveSourceTap => 'Source active — touchez pour changer';

  @override
  String get autoDjSwitch => 'Changer';

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
  String get browserConfirmDeletePlaylist =>
      'Confirmer la suppression de la liste de lecture';

  @override
  String get browserConfirmDeleteFolder =>
      'Confirmer la suppression du dossier';

  @override
  String get browserSearchHint => 'Rechercher dans la base de données';

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
      other: '$count pistes dans la file',
      one: '1 piste dans la file',
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
}
