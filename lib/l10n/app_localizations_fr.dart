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
  String get autoDjMultiServerTitle => 'Lire depuis tous les serveurs';

  @override
  String get autoDjMultiServerSubtitle =>
      'Auto DJ puise dans tous les serveurs à la fois, en suivant le son du morceau en cours';

  @override
  String get autoDjMultiServerNeedsSonic =>
      'Nécessite d\'activer Similarité sonore, ci-dessous';

  @override
  String get autoDjSectionShared => 'La session';

  @override
  String get autoDjSectionPerServer => 'Chaque bibliothèque';

  @override
  String get autoDjEditingServer => 'Réglages de';

  @override
  String autoDjMultiServerAllIn(int count) {
    return '$count serveurs participent';
  }

  @override
  String autoDjMultiServerConnecting(int count) {
    return '$count en cours de connexion';
  }

  @override
  String autoDjMultiServerSomeExcluded(int count, int total) {
    return '$count serveurs sur $total participent — il manque aux autres discovery, un modèle d\'embeddings compatible ou une version de serveur assez récente';
  }

  @override
  String get autoDjSectionQueue => 'File d\'attente';

  @override
  String get autoDjSongsPerFetchTitle => 'Titres par requête';

  @override
  String get autoDjSongsPerFetchSubtitle =>
      'Nombre de titres qu\'Auto DJ ajoute à la file à chaque passage. Les filtres de continuité jugent tout le lot par rapport au titre en cours au moment de la requête.';

  @override
  String autoDjSongsPerFetchValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres',
      one: '1 titre',
    );
    return '$_temp0';
  }

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
  String get browserSectionLibrary => 'Bibliothèque';

  @override
  String get browserSectionListen => 'Écouter';

  @override
  String get browserSectionNetwork => 'Réseau';

  @override
  String get browserSectionServer => 'Serveur';

  @override
  String get browserFederation => 'Fédération';

  @override
  String get browserAutoDjOn => 'Activé';

  @override
  String get browserAutoDjOff => 'Désactivé';

  @override
  String browserSharedLibraries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bibliothèques partagées',
      one: '1 bibliothèque partagée',
    );
    return '$_temp0';
  }

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
  String get mirrorRootLabel => 'Dossier de copie locale (facultatif)';

  @override
  String get mirrorRootHelp =>
      'Un dossier qui contient déjà une copie de cette bibliothèque, synchronisé par un autre outil (Syncthing, rclone, un NAS). Les fichiers qui s\'y trouvent sont lus depuis le disque. L\'application n\'y écrit jamais.';

  @override
  String get libraryCopyTitle => 'Copie de la bibliothèque';

  @override
  String get libraryCopyKeepSection =>
      'Conserver une copie complète sur cet appareil';

  @override
  String get libraryCopyKeepHelp =>
      'Chaque piste est téléchargée en qualité d\'origine et maintenue à jour : les nouveaux fichiers arrivent, les fichiers modifiés sont remplacés et ceux supprimés sur le serveur passent un moment dans un dossier corbeille.';

  @override
  String get libraryCopyUnsupported =>
      'Ce serveur ne propose pas la synchronisation de bibliothèque. Il faut mStream 6.27 ou plus récent.';

  @override
  String get libraryCopyNoLibraries =>
      'Aucune bibliothèque signalée pour l\'instant : ouvrez le serveur une fois, puis revenez.';

  @override
  String get libraryCopyNeverSynced => 'Pas encore synchronisé';

  @override
  String libraryCopyStatus(String when, int files, String size) {
    return 'Dernière synchronisation $when · $files fichiers · $size';
  }

  @override
  String libraryCopySyncing(int done, int total) {
    return 'Synchronisation… $done sur $total';
  }

  @override
  String get libraryCopyPreparing => 'Vérification du serveur…';

  @override
  String get libraryCopySyncNow => 'Synchroniser maintenant';

  @override
  String libraryCopyFailed(int n) {
    return '$n fichiers en échec';
  }

  @override
  String get libraryCopyFailedTitle => 'Fichiers en échec';

  @override
  String libraryCopyLastRunError(String error) {
    return 'La dernière synchronisation a échoué : $error';
  }

  @override
  String get libraryCopyRetention => 'Conserver les fichiers supprimés pendant';

  @override
  String libraryCopyRetentionDays(int n) {
    return '$n jours';
  }

  @override
  String get libraryCopyRetentionForever => 'Pour toujours';

  @override
  String get libraryCopyWifiOnly => 'Wi-Fi uniquement';

  @override
  String get libraryCopyDesktopNote =>
      'Se synchronise tant que l\'application est ouverte.';

  @override
  String get offlineBrowseTitle => 'Parcourir la copie hors ligne';

  @override
  String get offlineBrowseHelp =>
      'Les albums, artistes et dossiers proviennent de l\'index de la bibliothèque sur cet appareil, et seuls les fichiers qu\'il contient peuvent être lus. S\'active automatiquement quand le serveur est injoignable.';

  @override
  String get offlineBrowseUnavailable =>
      'Pas encore d\'index de bibliothèque : synchronisez une fois pendant que le serveur est joignable.';

  @override
  String get offlineChip => 'Copie hors ligne';

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
  String get addServerTabUrl => 'URL du serveur';

  @override
  String get addServerTabQuickConnect => 'Connexion rapide';

  @override
  String get irohPairingHeader => 'Se connecter avec un code d\'appairage';

  @override
  String get irohPairingBody =>
      'Activez « Remote Access » (accès distant) sur le serveur, puis collez son code d\'appairage ou scannez le QR.';

  @override
  String get irohPairingCodeLabel => 'Code d\'appairage';

  @override
  String get irohPairingCodeHint =>
      'Collez le code depuis le panneau Remote Access du serveur';

  @override
  String get irohShowPairingCode => 'Afficher le code d\'appairage';

  @override
  String get irohQrBody =>
      'Scannez-le avec l\'application mStream sur un autre appareil pour le connecter à ce serveur, ou copiez le code et collez-le là-bas.';

  @override
  String get irohQrCaution =>
      'Toute personne disposant de ce code peut se connecter à votre serveur.';

  @override
  String get irohScanQr => 'Scanner le QR';

  @override
  String get irohPaste => 'Coller';

  @override
  String get irohTestConnection => 'Tester la connexion';

  @override
  String get irohTesting => 'Test en cours…';

  @override
  String get irohScannerTitle => 'Scanner le QR d\'appairage';

  @override
  String get irohQrAndroidOnly =>
      'Le scan de QR n\'est pas disponible sur cet appareil.';

  @override
  String get irohAndroidOnly =>
      'La connexion rapide n\'est pas disponible sur cet appareil.';

  @override
  String get irohCameraPermission =>
      'L\'autorisation d\'accès à la caméra est nécessaire pour scanner un code.';

  @override
  String get irohPasteFirst =>
      'Collez ou scannez d\'abord un code d\'appairage.';

  @override
  String get irohTestFirst => 'Testez d\'abord la connexion.';

  @override
  String get irohTestConnected => 'Connecté via le tunnel iroh';

  @override
  String irohTestConnectedVersion(String version) {
    return 'Connecté via le tunnel iroh — mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · directe';

  @override
  String get irohPathSuffixRelay => ' · via relais';

  @override
  String get irohTunnelTimeout =>
      'Tunnel ouvert, mais le serveur n\'a pas répondu à temps.';

  @override
  String irohTunnelTestFailed(String error) {
    return 'Échec du test du tunnel : $error';
  }

  @override
  String get irohSignInHeader => 'Se connecter';

  @override
  String get irohSigningIn => 'Connexion en cours…';

  @override
  String get irohSignInSave => 'Se connecter et enregistrer';

  @override
  String get irohSignInTimeout => 'Délai de connexion dépassé.';

  @override
  String irohSignInFailed(String error) {
    return 'Échec de la connexion : $error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return 'Échec de la connexion (HTTP $status). Vérifiez votre nom d\'utilisateur et votre mot de passe.';
  }

  @override
  String get irohBannerConnecting => 'Connexion au serveur…';

  @override
  String get irohBannerReconnecting => 'Reconnexion au serveur…';

  @override
  String get irohBannerDisconnected => 'Déconnecté du serveur.';

  @override
  String get irohBannerRelay => 'Connecté via un relais — chemin plus lent.';

  @override
  String get irohBannerRepair =>
      'L\'appairage du serveur a changé — réappairez pour vous reconnecter.';

  @override
  String get irohRepairAction => 'Réappairer';

  @override
  String get irohRetry => 'Réessayer';

  @override
  String get irohRepairTitle => 'Réappairer le serveur';

  @override
  String get irohRepairBody =>
      'Le code d\'appairage de ce serveur a changé (son secret a été renouvelé). Collez ou scannez le nouveau code depuis le panneau Remote Access du serveur.';

  @override
  String get irohRepairFailed =>
      'Connexion impossible avec ce code — vérifiez-le et réessayez.';

  @override
  String get irohPathDirect => 'Directe';

  @override
  String get irohPathRelay => 'Relais';

  @override
  String get irohCastUnavailable =>
      'La diffusion vers des appareils externes n\'est pas disponible pour les serveurs pair-à-pair (iroh) — la lecture reste sur cet appareil.';

  @override
  String get irohShareUnavailable =>
      'Le partage n\'est pas disponible pour les serveurs pair-à-pair (iroh) — ils n\'ont pas d\'URL publique vers laquelle pointer.';

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
  String get autoDjSonicNotReady =>
      'La découverte est activée mais l\'analyse n\'a pas encore produit de données — la sélection reste aléatoire d\'ici là.';

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
  String get federationTitle => 'Fédération';

  @override
  String get federationStatusOn => 'Activée · connectée au relais';

  @override
  String get federationStatusConnecting => 'Activée · connexion…';

  @override
  String get federationStatusOff => 'Désactivée';

  @override
  String get federationStatusUnavailable => 'Indisponible sur cette plateforme';

  @override
  String get federationSharedWithYou => 'Partagé avec vous';

  @override
  String get federationRequestsSection => 'Demandes';

  @override
  String get federationYourSharedLibraries => 'Vos bibliothèques partagées';

  @override
  String get federationAddPeer => 'Ajouter un pair';

  @override
  String get federationShareLibrary => 'Partager une bibliothèque';

  @override
  String get federationNoPeersYet =>
      'Rien n\'est encore partagé avec ce serveur.';

  @override
  String get federationNoKeysYet =>
      'Pas encore de ticket — partagez une bibliothèque pour en créer un.';

  @override
  String get federationNoRequests =>
      'Pas encore de demande — les serveurs du réseau de découverte peuvent vous trouver ici.';

  @override
  String get federationClipboardTicket => 'Ticket dans le presse-papiers';

  @override
  String federationTicketPreview(String name, String libraries) {
    return '$name · partage $libraries';
  }

  @override
  String federationTicketPreviewNoLibraries(String name) {
    return '$name';
  }

  @override
  String get federationUnnamedServer => 'Serveur sans nom';

  @override
  String get federationAddPeerAction => 'Ajouter le pair';

  @override
  String get federationPeerLive => 'en ligne';

  @override
  String get federationPeerConnecting => 'connexion…';

  @override
  String get federationPeerDirectTunnel => 'tunnel direct';

  @override
  String federationPeerViaParent(String parent) {
    return 'via $parent';
  }

  @override
  String federationPeerViaTunnel(String parent) {
    return 'via le tunnel de $parent';
  }

  @override
  String get federationPeerMissing => 'plus partagé';

  @override
  String get federationPeerHidden => 'masqué dans le sélecteur';

  @override
  String federationMemberNote(String server) {
    return 'Le partage est réservé à l\'administrateur. Créer des tickets, ajouter des pairs et répondre aux demandes d\'appairage demandent une connexion administrateur sur $server — la même qui ouvre le panneau d\'administration.';
  }

  @override
  String get federationRestrictedNote =>
      'Ce serveur n\'accepte les appels d\'administration que depuis son propre réseau. Connectez-vous depuis chez vous pour gérer le partage ici.';

  @override
  String get federationDisabledNote =>
      'L\'API d\'administration est désactivée sur ce serveur.';

  @override
  String get federationUnsupportedNote =>
      'Ce serveur est trop ancien pour gérer la fédération depuis l\'application. Mettez mStream à jour.';

  @override
  String get federationLoadFailed => 'Impossible de joindre le serveur.';

  @override
  String get federationRetry => 'Réessayer';

  @override
  String get federationOffTitle =>
      'Partagez des bibliothèques avec les serveurs de vos amis';

  @override
  String get federationOffBody =>
      'Appairez deux serveurs mStream pour écouter la musique l\'un de l\'autre. On échange des tickets — envoyé par message, scanné ou collé.';

  @override
  String get federationOffPoint1Title =>
      'Lecture seule, chiffré de bout en bout';

  @override
  String get federationOffPoint1Body =>
      'Les listes de lecture et les notes ne quittent jamais votre serveur';

  @override
  String get federationOffPoint2Title => 'Ni redirection de port ni DNS';

  @override
  String get federationOffPoint2Body =>
      'iroh trouve le chemin — en direct quand c\'est possible, via un relais sinon';

  @override
  String get federationOffPoint3Title => 'Des tickets révocables';

  @override
  String get federationOffPoint3Body =>
      'Chacun s\'utilise une fois et se coupe à tout moment';

  @override
  String get federationOffAdminOnly =>
      'Seul l\'administrateur du serveur peut l\'activer.';

  @override
  String federationOffMemberNote(String server) {
    return 'La fédération est désactivée sur $server. Son administrateur peut l\'activer.';
  }

  @override
  String get federationTurnOn => 'Activer la fédération';

  @override
  String get federationUnavailableNote =>
      'Le composant iroh n\'a pas de version pour le système/processeur de ce serveur, le point de fédération ne peut donc pas tourner ici.';

  @override
  String get federationTurnedOn => 'La fédération est activée';

  @override
  String get federationTurnedOff => 'La fédération est désactivée';

  @override
  String get federationToggleFailed =>
      'Impossible de modifier le réglage de fédération.';

  @override
  String get federationSettingsTitle => 'Réglages de fédération';

  @override
  String get federationSwitchSubtitle =>
      'Pair à pair, chiffré de bout en bout. Ni redirection de port ni DNS.';

  @override
  String get federationStatusSection => 'État';

  @override
  String get federationConnectedRelay => 'Connecté au relais';

  @override
  String get federationNotRunning => 'Point de fédération arrêté';

  @override
  String get federationEndpointId => 'Identifiant du point';

  @override
  String get federationEndpointCopied => 'Identifiant copié';

  @override
  String get federationPairingRequestsSection => 'Demandes d\'appairage';

  @override
  String get federationRequestsInboxTitle =>
      'Accepter les demandes du réseau de découverte';

  @override
  String get federationRequestsInboxSubtitle =>
      'Désactivé par défaut. Une fois désactivé, les nouvelles demandes sont refusées au transport ; les réponses à vos propres demandes arrivent toujours.';

  @override
  String get federationInboxFailed =>
      'Impossible de modifier la boîte de demandes.';

  @override
  String get federationDefaultsSection =>
      'Valeurs par défaut des nouveaux tickets';

  @override
  String get federationDefaultsNote =>
      'Issues de la configuration du serveur — chaque ticket peut les changer';

  @override
  String get federationOffWarning =>
      'Désactiver la fédération coupe tous les ponts vers les pairs et masque vos tickets jusqu\'à la réactivation. Les pairs gardent leurs tickets.';

  @override
  String federationRequestWantsToPair(String name) {
    return '$name veut s\'appairer';
  }

  @override
  String federationRequestToName(String name) {
    return 'Demande à $name';
  }

  @override
  String federationRequestOffers(String libraries) {
    return 'Propose $libraries';
  }

  @override
  String get federationRequestOffersNothing => 'Ne propose rien';

  @override
  String federationRequestYouOffered(String libraries) {
    return 'Vous avez proposé $libraries';
  }

  @override
  String get federationRequestYouOfferedNothing => 'Vous n\'avez rien proposé';

  @override
  String get federationReqSending => 'envoi…';

  @override
  String get federationReqWaiting => 'en attente de leur réponse';

  @override
  String get federationReqSharingBack => 'partage en retour…';

  @override
  String get federationReqNeedsAnswer => 'attend votre réponse';

  @override
  String get federationReqSendingTicket => 'envoi de votre ticket…';

  @override
  String get federationReqWaitingShare => 'en attente de leur partage';

  @override
  String get federationReqDeclined => 'refusée';

  @override
  String get federationReqYouDeclined => 'refusée par vous';

  @override
  String get federationReqInboxClosed => 'leur boîte est fermée';

  @override
  String get federationReqFederated => 'fédéré';

  @override
  String get federationReqWithdrawn => 'retirée';

  @override
  String get federationReqExpired => 'expirée';

  @override
  String get federationAccept => 'Accepter…';

  @override
  String get federationAcceptAndShare => 'Accepter et partager';

  @override
  String get federationDecline => 'Refuser';

  @override
  String get federationCancelRequest => 'Annuler la demande';

  @override
  String get federationDismiss => 'Ignorer';

  @override
  String get federationRequestTitle => 'Demande d\'appairage';

  @override
  String federationRequestReceived(String ago) {
    return 'Reçue $ago par le réseau de découverte';
  }

  @override
  String federationRequestSent(String ago) {
    return 'Envoyée $ago par le réseau de découverte';
  }

  @override
  String get federationShareBack => 'Partager en retour';

  @override
  String get federationShareBackNote =>
      'Rien ne change tant que vous n\'acceptez pas. Ils auront un accès en lecture seule aux bibliothèques cochées — au moins une.';

  @override
  String get federationTheirLimits => 'Leurs limites';

  @override
  String get federationChange => 'Modifier';

  @override
  String get federationRequestIgnored =>
      'Les demandes de ce serveur sont ignorées pendant 7 jours';

  @override
  String get federationRequestAccepted => 'Demande acceptée';

  @override
  String get federationRequestDeclined => 'Demande refusée';

  @override
  String get federationRequestCancelled => 'Demande retirée';

  @override
  String get federationRequestActionFailed =>
      'Impossible de mettre à jour la demande.';

  @override
  String get federationTicketNameLabel => 'Pour qui est-ce ?';

  @override
  String get federationTicketNameHint =>
      'Vous seul voyez ce nom — il étiquette le ticket dans votre liste.';

  @override
  String get federationLibrariesTheyCanRead =>
      'Bibliothèques qu\'ils peuvent lire';

  @override
  String get federationLimitsSection => 'Limites';

  @override
  String get federationExactNumbers => 'Valeurs exactes';

  @override
  String get federationPresets => 'Préréglages';

  @override
  String get federationLimitStreamRate => 'Débit de lecture';

  @override
  String get federationLimitPerDay => 'Par jour';

  @override
  String get federationLimitStreams => 'Flux simultanés';

  @override
  String get federationLimitExpires => 'Expire';

  @override
  String get federationUnlimited => 'Illimité';

  @override
  String get federationNever => 'Jamais';

  @override
  String federationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get federationOneYear => '1 an';

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
    return '$n Mo par jour';
  }

  @override
  String federationGbPerDay(int n) {
    return '$n Go par jour';
  }

  @override
  String federationStreamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flux',
      one: '1 flux',
    );
    return '$_temp0';
  }

  @override
  String get federationNeverExpires => 'n\'expire jamais';

  @override
  String federationExpiresIn(String when) {
    return 'expire $when';
  }

  @override
  String get federationExpired => 'expiré';

  @override
  String federationInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count jours',
      one: 'dans 1 jour',
    );
    return '$_temp0';
  }

  @override
  String federationInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count heures',
      one: 'dans 1 heure',
    );
    return '$_temp0';
  }

  @override
  String get federationStreamRateField => 'Débit (kbit/s, 0 = illimité)';

  @override
  String get federationPerDayField => 'Quota journalier (Mo, 0 = illimité)';

  @override
  String get federationStreamsField => 'Flux max. (0 = illimité)';

  @override
  String get federationExpiresField => 'Expire dans (jours, 0 = jamais)';

  @override
  String get federationCreateTicket => 'Créer le ticket';

  @override
  String get federationMintFailed => 'Impossible de créer le ticket.';

  @override
  String get federationNoLibraries =>
      'Ce serveur n\'a aucune bibliothèque à partager.';

  @override
  String get federationTicketTitle => 'Votre ticket';

  @override
  String federationTicketFor(String name) {
    return 'Ticket pour $name';
  }

  @override
  String federationTicketReads(String libraries) {
    return 'Lit $libraries';
  }

  @override
  String get federationTicketQrHint =>
      'Dans la même pièce ? Faites-le scanner.';

  @override
  String get federationTicketWarning =>
      'Quiconque détient ce ticket peut lire ces bibliothèques jusqu\'à ce qu\'il soit utilisé ou révoqué. Envoyez-le par un canal privé — le premier serveur qui l\'utilise se l\'approprie.';

  @override
  String get federationCopyTicket => 'Copier le ticket';

  @override
  String get federationTicketCopied => 'Ticket copié';

  @override
  String get federationSendByText => 'Envoyer par message…';

  @override
  String get federationTicketRevokeNote =>
      'Révoquez-le à tout moment depuis Fédération. En cas de réinstallation, « Réinitialiser l\'utilisation » permet de réutiliser le ticket.';

  @override
  String get federationTicketNotRunning =>
      'Le point de fédération est arrêté, il n\'y a donc pas encore de ticket à envoyer. Activez la fédération et revenez.';

  @override
  String federationShareMessage(String libraries, String ticket) {
    return 'Je partage avec toi ma bibliothèque musicale mStream — $libraries, en lecture seule. Dans l\'application mStream, ouvre Fédération → Ajouter un pair et colle ce ticket :\n\n$ticket\n\nIl ne sert qu\'une fois — je peux le révoquer à tout moment.';
  }

  @override
  String get federationShareSubject => 'Ticket de fédération mStream';

  @override
  String get federationKeyClaimed => 'utilisé';

  @override
  String get federationKeyNotClaimed => 'pas encore utilisé';

  @override
  String federationKeyTodayUsage(String amount) {
    return '$amount aujourd\'hui';
  }

  @override
  String federationKeyLastUsed(String ago) {
    return 'Dernière utilisation $ago';
  }

  @override
  String get federationKeyNeverUsed => 'Jamais utilisé';

  @override
  String federationKeyClaimedAgo(String ago) {
    return 'Utilisé $ago';
  }

  @override
  String get federationResetBinding => 'Réinitialiser l\'utilisation';

  @override
  String get federationResetBindingNote =>
      'Réinstallation chez l\'ami ? Permet de réutiliser le ticket.';

  @override
  String get federationBindingReset => 'Le ticket peut être réutilisé';

  @override
  String get federationRevoke => 'Révoquer';

  @override
  String federationRevokeConfirm(String name) {
    return 'Révoquer ce ticket ? $name perd l\'accès immédiatement.';
  }

  @override
  String get federationRevoked => 'Ticket révoqué';

  @override
  String get federationSaveLimits => 'Enregistrer les limites';

  @override
  String get federationLimitsSaved => 'Limites enregistrées';

  @override
  String get federationLimitsFailed => 'Impossible d\'enregistrer les limites.';

  @override
  String get federationSend => 'Envoyer';

  @override
  String get federationKeyTitle => 'Bibliothèque partagée';

  @override
  String federationActionFailed(String error) {
    return 'Ça n\'a pas marché : $error';
  }

  @override
  String get federationTheirTicket => 'Leur ticket';

  @override
  String get federationScanQr => 'Scanner un code QR';

  @override
  String get federationScannerTitle => 'Scanner un ticket de fédération';

  @override
  String get federationPaste => 'Coller';

  @override
  String get federationTicketPasted => 'Collé depuis le presse-papiers.';

  @override
  String get federationNotATicket =>
      'Ceci ne ressemble pas à un ticket de fédération.';

  @override
  String get federationTicketTooNew =>
      'Ce ticket vient d\'un mStream plus récent que ce que cette application comprend.';

  @override
  String get federationTicketExpiredNote => 'Ce ticket a expiré.';

  @override
  String get federationDisplayName => 'Nom affiché';

  @override
  String get federationDisplayNameHint =>
      'Facultatif — tel qu\'il apparaît dans votre sélecteur de serveurs.';

  @override
  String federationSharesLibraries(String libraries) {
    return 'Partage $libraries';
  }

  @override
  String get federationSharesUnknown =>
      'Bibliothèques non indiquées sur le ticket';

  @override
  String federationValidUntil(String date) {
    return 'valide jusqu\'au $date';
  }

  @override
  String federationAddPeerShowsUnder(String server) {
    return 'Apparaît sous $server';
  }

  @override
  String federationAddPeerReadOnly(String branch, String name) {
    return 'Lecture seule · $branch $name dans le sélecteur';
  }

  @override
  String get federationAddPeerDials => 'Votre serveur le joint via iroh';

  @override
  String get federationAddPeerEncrypted =>
      'Chiffré de bout en bout · sans redirection de port';

  @override
  String get federationAddPeerNoTicket =>
      'Pas encore de ticket ? Demandez qu\'on vous en envoie un par message.';

  @override
  String federationPeerAdded(String name) {
    return '$name ajouté';
  }

  @override
  String get federationAddPeerFailed => 'Impossible d\'ajouter le pair.';

  @override
  String get federationPeerAlreadyAdded =>
      'Ce ticket est déjà ajouté comme pair.';

  @override
  String get federationLibrariesYouCanRead =>
      'Bibliothèques que vous pouvez lire';

  @override
  String get federationDiscoverySection => 'Découverte';

  @override
  String get federationAskPeerSimilar =>
      'Demander de la musique similaire à ce pair';

  @override
  String get federationAskPeerSimilarNote =>
      'Envoie ce que vous écoutez — à ce pair seulement.';

  @override
  String get federationAutoDjSection => 'Auto DJ';

  @override
  String get federationAutoDjParticipates =>
      'Participe à l\'Auto DJ multi-serveur';

  @override
  String get federationAutoDjParticipatesNote =>
      'Répond avec sa propre bibliothèque quand le DJ est actif';

  @override
  String get federationAutoDjNotCandidate => 'Pas candidat à l\'Auto DJ';

  @override
  String get federationAutoDjNotCandidateNote =>
      'Il faut un serveur capable de répondre aux sélections sonores';

  @override
  String get federationTest => 'Tester';

  @override
  String get federationTesting => 'Test…';

  @override
  String get federationTestOk => 'Joignable';

  @override
  String federationTestFailed(String error) {
    return 'Injoignable : $error';
  }

  @override
  String federationCheckedAgo(String ago) {
    return 'Vérifié $ago';
  }

  @override
  String get federationNeverTested => 'Jamais testé';

  @override
  String federationLastSeen(String ago) {
    return 'Vu pour la dernière fois $ago';
  }

  @override
  String get federationBrowseLibrary => 'Parcourir cette bibliothèque';

  @override
  String get federationRemovePeer => 'Retirer le pair';

  @override
  String federationRemovePeerConfirm(String name) {
    return 'Retirer $name ? Les pistes en file venant de ce pair s\'arrêteront.';
  }

  @override
  String federationPeerRemoved(String name) {
    return '$name retiré';
  }

  @override
  String get federationShowInPicker => 'Afficher dans le sélecteur de serveurs';

  @override
  String get federationShowInPickerNote =>
      'Les pairs masqués continuent de lire ce que vous avez mis en file depuis eux.';

  @override
  String get federationPeerReadOnlyNote =>
      'Lecture seule — les listes de lecture et les notes restent sur votre propre serveur.';

  @override
  String get federationPeerLibrariesUnknown =>
      'Pas encore listé — ouvrez-le une fois pour charger ses bibliothèques.';

  @override
  String get federationTransportDirect => 'Tunnel direct depuis ce téléphone';

  @override
  String get federationTransportRelay => 'Relais en attente';

  @override
  String federationTransportViaParent(String parent) {
    return 'Via $parent';
  }

  @override
  String federationTransportViaParentTunnel(String parent) {
    return 'Via $parent par son tunnel';
  }

  @override
  String get federationDiscoveryFailed =>
      'Impossible de modifier le réglage de découverte.';

  @override
  String get agoJustNow => 'à l\'instant';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count min',
      one: 'il y a 1 min',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count h',
      one: 'il y a 1 h',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get browserP2pNetwork => 'Réseau P2P';

  @override
  String get browserP2pOn => 'Activé';

  @override
  String get browserP2pOff => 'Désactivé';

  @override
  String get p2pTitle => 'Réseau P2P';

  @override
  String get p2pStatusConnected => 'Connecté';

  @override
  String p2pNeighborsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voisins',
      one: '1 voisin',
    );
    return '$_temp0';
  }

  @override
  String p2pAnnouncingAs(String name) {
    return 'annoncé comme $name';
  }

  @override
  String get p2pStatusSearching => 'Rejoint · en attente de voisins';

  @override
  String p2pStatusReconnecting(int n) {
    return 'Reconnexion · tentative $n';
  }

  @override
  String get p2pStatusNotJoined => 'Pas encore rejoint';

  @override
  String get p2pStatusOff => 'Désactivé';

  @override
  String get p2pStatusUnavailable => 'Indisponible sur cette plateforme';

  @override
  String get p2pStatNeighbors => 'voisins du maillage';

  @override
  String get p2pStatNeighborsSub => 'liens gossip actifs';

  @override
  String get p2pStatKnown => 'serveurs connus';

  @override
  String p2pStatKnownSub(int hidden, int blocked) {
    return '$hidden masqués · $blocked bloqués';
  }

  @override
  String get p2pStatHeld => 'instantanés conservés';

  @override
  String p2pStatHeldOf(int held, int max) {
    return '$held sur $max';
  }

  @override
  String p2pStatStorage(String used, String cap) {
    return '$used sur $cap';
  }

  @override
  String get p2pStatTracks => 'pistes des pairs';

  @override
  String p2pStatTracksSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'cherchables, $count bibliothèques',
      one: 'cherchables, 1 bibliothèque',
    );
    return '$_temp0';
  }

  @override
  String get p2pActivity => 'Activité';

  @override
  String get p2pActivitySubtitle =>
      'plus récent en premier · en mémoire seulement';

  @override
  String get p2pActivityEmpty =>
      'Rien pour l\'instant — les entrées dans le maillage, les téléchargements d\'instantanés, la rotation et les reprises s\'affichent ici au fil de l\'eau.';

  @override
  String get p2pActivityNote =>
      'L\'historique complet est dans les journaux du serveur.';

  @override
  String get p2pFromNetwork => 'Depuis le réseau';

  @override
  String get p2pFindSimilar => 'Trouver de la musique similaire sur le réseau';

  @override
  String p2pFindSimilarSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ouvre Découvrir pour la piste en cours · pistes issues de $count bibliothèques téléchargées',
      one:
          'Ouvre Découvrir pour la piste en cours · pistes issues de 1 bibliothèque téléchargée',
    );
    return '$_temp0';
  }

  @override
  String get p2pFindSimilarNothingPlaying =>
      'Lancez d\'abord une lecture — Découvrir suit la piste en cours';

  @override
  String get p2pNewArtistsOnlySub =>
      'Masquer les pistes d\'artistes déjà présents dans cette bibliothèque';

  @override
  String get p2pServersYouFollow => 'Serveurs suivis';

  @override
  String get p2pServersOnNetwork => 'Serveurs sur le réseau';

  @override
  String get p2pNoServersYet =>
      'Aucun serveur entendu pour l\'instant — ajoutez-en un avec le ticket d\'un ami, ou laissez une minute au gossip.';

  @override
  String p2pHiddenIncompatible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs masqués — modèle incompatible',
      one: '1 serveur masqué — modèle incompatible',
    );
    return '$_temp0';
  }

  @override
  String get p2pShow => 'Afficher';

  @override
  String get p2pHide => 'Masquer';

  @override
  String get p2pBefriend => 'Ajouter un serveur ami';

  @override
  String get p2pOnline => 'en ligne';

  @override
  String p2pOfflineFor(String ago) {
    return 'hors ligne $ago';
  }

  @override
  String p2pTracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistes',
      one: '1 piste',
    );
    return '$_temp0';
  }

  @override
  String p2pSeedersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seeders',
      one: '1 seeder',
    );
    return '$_temp0';
  }

  @override
  String get p2pChipDownloaded => 'téléchargé';

  @override
  String get p2pChipUpdate => 'mise à jour disponible';

  @override
  String get p2pChipNotDownloaded => 'non téléchargé';

  @override
  String get p2pChipPinned => 'épinglé';

  @override
  String get p2pChipIncompatible => 'modèle incompatible';

  @override
  String get p2pChipFederated => 'fédéré';

  @override
  String get p2pChipTheyAsked => 'ils vous ont demandé';

  @override
  String get p2pChipRequestSent => 'demande envoyée';

  @override
  String get p2pSearchingTitle => 'Recherche de pairs';

  @override
  String get p2pSearchingBody =>
      'Le maillage se tisse en une minute environ. Cet écran se met à jour tout seul.';

  @override
  String get p2pReconnectingTitle => 'Reconnexion';

  @override
  String p2pReconnectingBody(int n) {
    return 'Le sidecar s\'est arrêté et est relancé (tentative $n) — rien à faire.';
  }

  @override
  String get p2pJoinTitle =>
      'Des recommandations issues des bibliothèques des autres';

  @override
  String get p2pWhatShared => 'Ce qui est partagé';

  @override
  String get p2pShared1 => 'Un instantané de métadonnées seulement';

  @override
  String get p2pShared1Sub =>
      'Artiste, titre, durée, empreintes sonores — jamais de fichiers audio';

  @override
  String get p2pShared2 => 'Le nom et la description de votre serveur';

  @override
  String get p2pShared2Sub =>
      'Visibles par tous sur le réseau, par défaut le réseau communautaire public';

  @override
  String get p2pHowYouAppear => 'Comment vous apparaissez';

  @override
  String get p2pServerName => 'Nom du serveur';

  @override
  String get p2pServerNameHint =>
      '« mStream » à côté de 18 000 autres mStream, c\'est la première chose à changer.';

  @override
  String get p2pDescription => 'Description';

  @override
  String get p2pDescriptionHint => '180 caractères, facultatif.';

  @override
  String get p2pAlsoAcceptRequests =>
      'Accepter aussi les demandes de fédération';

  @override
  String get p2pAlsoAcceptRequestsSub =>
      'Des invitations à partager des bibliothèques — rien n\'est partagé tant que vous n\'approuvez pas chacune. Active la fédération.';

  @override
  String get p2pJoin => 'Rejoindre le réseau';

  @override
  String get p2pJoining => 'Connexion…';

  @override
  String get p2pJoined =>
      'Réseau de découverte rejoint — laissez une minute au maillage.';

  @override
  String p2pJoinFailed(String error) {
    return 'Impossible de rejoindre le réseau : $error';
  }

  @override
  String p2pInboxFailed(String error) {
    return 'La découverte est active, mais la boîte de demandes n\'a pas démarré : $error';
  }

  @override
  String get p2pUnavailableNote =>
      'Le binaire p2p-sidecar est introuvable pour cette plateforme et aucune version n\'est téléchargeable — le réseau est indisponible.';

  @override
  String get p2pWillDownloadNote =>
      'Le sidecar n\'est pas encore installé ; rejoindre le télécharge d\'abord.';

  @override
  String get p2pAdminOnlyNote =>
      'Seul l\'administrateur du serveur peut rejoindre le réseau.';

  @override
  String p2pMemberOffNote(String server) {
    return 'Le réseau de découverte est désactivé sur $server. Son administrateur peut le rejoindre.';
  }

  @override
  String p2pMemberNote(String server) {
    return 'Rejoindre, inviter et gérer les instantanés sont réservés à l\'administrateur. Connectez-vous à $server comme administrateur pour gérer le réseau ici.';
  }

  @override
  String get p2pSnapshotSection => 'Instantané';

  @override
  String p2pDownloadedSize(String size) {
    return 'Téléchargé · $size';
  }

  @override
  String p2pSnapshotSeq(int seq) {
    return 'Instantané $seq';
  }

  @override
  String p2pNewerAnnounced(int seq) {
    return 'un plus récent ($seq) est annoncé';
  }

  @override
  String get p2pNotDownloaded => 'Non téléchargé';

  @override
  String get p2pNotDownloadedSub =>
      'Téléchargez-le pour le chercher depuis Découvrir';

  @override
  String get p2pDownload => 'Télécharger';

  @override
  String get p2pUpdate => 'Mettre à jour';

  @override
  String get p2pDownloading => 'Téléchargement…';

  @override
  String get p2pDownloaded => 'Instantané téléchargé';

  @override
  String p2pDownloadFailed(String error) {
    return 'Impossible de télécharger l\'instantané : $error';
  }

  @override
  String get p2pPin => 'Épingler cet instantané';

  @override
  String p2pPinSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'La rotation libère les instantanés les moins utilisés après $count jours ; un instantané épinglé reste.',
      one:
          'La rotation libère les instantanés les moins utilisés après 1 jour ; un instantané épinglé reste.',
    );
    return '$_temp0';
  }

  @override
  String get p2pPinSubNoRotation =>
      'La rotation est désactivée ; un instantané épinglé survit aussi au manque de place.';

  @override
  String get p2pRemoveSnapshot => 'Retirer l\'instantané';

  @override
  String get p2pSnapshotRemoved => 'Instantané retiré';

  @override
  String get p2pHeldSince => 'conservé depuis';

  @override
  String get p2pTracksLabel => 'pistes';

  @override
  String get p2pSeedersLabel => 'seeders';

  @override
  String get p2pSeedersSub => 'servent l\'instantané';

  @override
  String get p2pFederatedWithYou => 'Fédéré avec vous';

  @override
  String get p2pFederatedWithYouSub =>
      'Ouvrez Fédération pour voir ce que vous lisez l\'un chez l\'autre';

  @override
  String get p2pTheyAskedYou => 'Ils ont demandé à fédérer';

  @override
  String get p2pTheyAskedYouSub => 'Examinez la demande dans Fédération';

  @override
  String get p2pRequestSentTitle => 'Demande envoyée';

  @override
  String get p2pRequestSentSub =>
      'En attente de leur réponse · à suivre dans Fédération';

  @override
  String get p2pAskToFederate => 'Demander à partager des bibliothèques';

  @override
  String get p2pAskToFederateSub =>
      'Envoie une demande sur le réseau — rien ne change pour l\'instant';

  @override
  String get p2pOpen => 'Ouvrir';

  @override
  String get p2pReview => 'Examiner';

  @override
  String get p2pForget => 'Oublier ce serveur';

  @override
  String get p2pForgetSub =>
      'Hors ligne et rien de téléchargé ; il revient s\'il est de nouveau entendu';

  @override
  String p2pForgotten(String name) {
    return '$name oublié';
  }

  @override
  String get p2pBlockServer => 'Bloquer le serveur';

  @override
  String p2pBlockConfirm(String name) {
    return 'Bloquer $name ? Ses annonces sont ignorées et son instantané retiré.';
  }

  @override
  String p2pBlocked(String name) {
    return '$name bloqué';
  }

  @override
  String get p2pUnblock => 'Débloquer';

  @override
  String get p2pUnblocked => 'Serveur débloqué';

  @override
  String get p2pIncompatibleNote =>
      'Modèle d\'empreintes incompatible — sa bibliothèque ne peut pas alimenter la recherche de similaires de ce serveur.';

  @override
  String get p2pCompatible => 'modèle compatible';

  @override
  String get p2pModelUnknown => 'modèle inconnu';

  @override
  String get p2pNoDescription => 'Pas de description.';

  @override
  String get p2pUnnamedServer => 'Serveur sans nom';

  @override
  String get p2pFederateTitle => 'Demander à fédérer';

  @override
  String get p2pFederateNote =>
      'Envoie une demande sur le réseau de découverte. Aucun accès n\'est échangé maintenant — ils voient votre nom, votre message et votre offre ; les bibliothèques ne sont partagées que s\'ils acceptent.';

  @override
  String get p2pMessage => 'Message';

  @override
  String p2pMessageHint(int n) {
    return 'Facultatif · $n / 500';
  }

  @override
  String get p2pShareBackLibraries =>
      'Bibliothèques que vous partagerez en retour s\'ils acceptent';

  @override
  String get p2pShareBackNote =>
      'Décochez tout pour une demande à sens unique — vous ne feriez que lire les leurs.';

  @override
  String get p2pSendRequest => 'Envoyer la demande';

  @override
  String get p2pRequestSent => 'Demande envoyée — à suivre dans Fédération';

  @override
  String p2pRequestFailed(String error) {
    return 'Impossible d\'envoyer la demande : $error';
  }

  @override
  String get p2pTheirTicket => 'Leur ticket';

  @override
  String get p2pTheirTicketHint =>
      'Un ami trouve le sien sous « Inviter un ami » sur son écran Réseau P2P.';

  @override
  String get p2pTicketPasted => 'Collé depuis le presse-papiers.';

  @override
  String get p2pRememberFriend => 'Se souvenir de cet ami';

  @override
  String get p2pRememberFriendSub =>
      'Enregistré dans la configuration du serveur pour que l\'amitié survive aux redémarrages.';

  @override
  String get p2pJoinFriend => 'Rejoindre';

  @override
  String get p2pJoinedFriend => 'Rejoint — le maillage se tisse en une minute';

  @override
  String p2pJoinFriendFailed(String error) {
    return 'Impossible de rejoindre : $error';
  }

  @override
  String get p2pNotATicket =>
      'Ceci ne ressemble pas à un ticket de point de connexion.';

  @override
  String get p2pScanQr => 'Scanner un code QR';

  @override
  String get p2pScannerTitle => 'Scanner un ticket réseau';

  @override
  String get p2pInviteFriend => 'Inviter un ami';

  @override
  String p2pYourTicketNote(String name) {
    return 'Votre ticket — un ami le colle ici sur son téléphone pour ajouter $name. C\'est une adresse, pas un identifiant.';
  }

  @override
  String get p2pTicketCopied => 'Ticket copié';

  @override
  String p2pShareMessage(String ticket) {
    return 'Ajoute mon serveur mStream sur le réseau de découverte — dans l\'application mStream, ouvre Réseau P2P → Ajouter un serveur ami et colle ce ticket :\n\n$ticket';
  }

  @override
  String get p2pShareSubject => 'Ticket réseau de découverte mStream';

  @override
  String get p2pTicketNotReady =>
      'Le sidecar ne tourne pas encore, il n\'y a donc pas encore de ticket à partager.';

  @override
  String get p2pSettingsTitle => 'Réglages du réseau';

  @override
  String get p2pSwitchTitle => 'Réseau de découverte';

  @override
  String get p2pSwitchSub =>
      'Annonce un instantané de métadonnées seulement sur le réseau. Désactivez pour quitter — les données collectées restent locales.';

  @override
  String get p2pLeaveConfirm =>
      'Quitter le réseau de découverte ? Votre serveur cesse d\'annoncer et de télécharger des instantanés. La découverte locale continue de fonctionner.';

  @override
  String get p2pLeave => 'Quitter';

  @override
  String get p2pLeft => 'Réseau de découverte quitté';

  @override
  String p2pLeaveFailed(String error) {
    return 'Impossible de quitter le réseau : $error';
  }

  @override
  String get p2pEditIdentity => 'Nom et description';

  @override
  String get p2pIdentitySaved => 'Enregistré — annoncé sur le réseau';

  @override
  String p2pSaveFailed(String error) {
    return 'Impossible d\'enregistrer : $error';
  }

  @override
  String get p2pSnapshotsSection => 'Instantanés';

  @override
  String get p2pAutoDownload => 'Téléchargement auto jusqu\'à';

  @override
  String p2pServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs',
      one: '1 serveur',
    );
    return '$_temp0';
  }

  @override
  String get p2pStorageCap => 'Plafond de stockage';

  @override
  String get p2pRotate => 'Rotation des téléchargements';

  @override
  String get p2pForgetOffline => 'Oublier les serveurs hors ligne';

  @override
  String get p2pMeshSection => 'Maillage';

  @override
  String get p2pCommunitySeeds => 'Seeds communautaires';

  @override
  String get p2pCommunitySeedsOn => 'Amorçage via les serveurs seed publics';

  @override
  String get p2pCommunitySeedsOff =>
      'Désactivés — serveurs amis seulement ; réglé dans la configuration du serveur';

  @override
  String p2pBlockedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs bloqués',
      one: '1 serveur bloqué',
      zero: 'Aucun serveur bloqué',
    );
    return '$_temp0';
  }

  @override
  String get p2pBlockedSub =>
      'Annonces ignorées, instantanés jamais téléchargés';

  @override
  String get p2pBlockedTitle => 'Serveurs bloqués';

  @override
  String get p2pSaved => 'Enregistré';

  @override
  String get p2pOff => 'Désactivé';

  @override
  String get p2pSave => 'Enregistrer';

  @override
  String get p2pSearchServers => 'Rechercher des serveurs — nom ou description';

  @override
  String federationInboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes de fédération en attente',
      one: '1 demande de fédération en attente',
    );
    return '$_temp0';
  }

  @override
  String get federationInboxBannerSub => 'Touchez pour accepter ou refuser';

  @override
  String federationInboxNotificationTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes de fédération sont en attente',
      one: 'Une demande de fédération est en attente',
    );
    return '$_temp0';
  }

  @override
  String federationInboxNotificationBody(String server) {
    return 'Sur $server. Ouvrez pour accepter ou refuser.';
  }

  @override
  String get federationInboxChannelName => 'Demandes de fédération';

  @override
  String get federationInboxChannelDescription =>
      'Une demande de partage de bibliothèques est arrivée sur l\'un de vos serveurs';

  @override
  String get federationNotifyTitle => 'M\'avertir des demandes';

  @override
  String get federationNotifySubtitle =>
      'Une notification sur le téléphone quand une demande arrive, l\'app ouverte ou en lecture';
}
