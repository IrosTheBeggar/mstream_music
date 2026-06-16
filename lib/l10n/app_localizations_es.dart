// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get mainRemove => 'Quitar';

  @override
  String get playlistActionFailed =>
      'No se pudo guardar la lista: puede que el nombre ya esté en uso.';

  @override
  String get queueAddNext => 'Añadir a continuación';

  @override
  String get queuePlayNow => 'Reproducir ahora';

  @override
  String get queueAddToEnd => 'Añadir al final de la cola';

  @override
  String get shuffle => 'Aleatorio';

  @override
  String get variousArtists => 'Varios artistas';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystemDefault => 'Predeterminado del sistema';

  @override
  String get settingsLanguageSubtitle =>
      'El idioma de la aplicación. \"Predeterminado del sistema\" sigue el de tu dispositivo.';

  @override
  String couldNotOpen(String url) {
    return 'No se pudo abrir $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
      zero: 'Sin pistas',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Restablecer';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get tapAddToQueue => 'Añadir a la cola';

  @override
  String get tapPlayFromHere => 'Reproducir desde aquí';

  @override
  String get tapAppendAndJump => 'Añadir y reproducir';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'Shaders';

  @override
  String get visualizerSourceSynthesized => 'Sintetizado';

  @override
  String get visualizerSourceReal => 'Audio real';

  @override
  String get downloadsTitle => 'Descargas';

  @override
  String downloadProgress(String progress) {
    return 'progreso: $progress%';
  }

  @override
  String get songInfoTitle => 'Información de la canción';

  @override
  String get eqTitle => 'Ecualizador';

  @override
  String get eqOnlyAndroid => 'El ecualizador solo está disponible en Android.';

  @override
  String get eqNeedsPlayback =>
      'Inicia una canción para configurar el ecualizador.\n\nEl ecualizador nativo de Android se inicializa con la sesión de audio, así que necesitamos que la reproducción esté activa antes de poder leer la distribución de bandas.';

  @override
  String eqInitFailed(String error) {
    return 'No se pudo inicializar el ecualizador:\n$error';
  }

  @override
  String get eqNoBands =>
      'El controlador de audio de este dispositivo no reporta bandas de ecualización.';

  @override
  String get eqEnabledOn => 'Activado — ganancias aplicadas a la reproducción';

  @override
  String get eqEnabledOff => 'Desactivado — modo de derivación';

  @override
  String get cancel => 'Cancelar';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSectionAppearance => 'Apariencia';

  @override
  String get settingsSectionPlayback => 'Reproducción';

  @override
  String get settingsSectionBrowse => 'Explorar';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSubtitleVelvet =>
      'Azul marino y púrpura — el tema oscuro característico.';

  @override
  String get themeSubtitleDark => 'Oscuro neutro con detalles ámbar.';

  @override
  String get themeSubtitleLight =>
      'Cuerpo claro con barra de aplicación oscura y detalles ámbar — coincide con el tema anterior.';

  @override
  String get settingsTranscode => 'Transcodificar audio';

  @override
  String get settingsTranscodeSubtitle =>
      'Transmite una copia transcodificada desde el servidor (archivos más pequeños, inicio algo más lento). Desactivado reproduce los archivos originales.';

  @override
  String get transcodeTitle => 'Transcodificación';

  @override
  String get transcodeCodec => 'Códec';

  @override
  String get transcodeBitrate => 'Tasa de bits';

  @override
  String get transcodeAuto => 'Predeterminado del servidor';

  @override
  String get transcodeUnavailable =>
      'Este servidor no tiene la transcodificación habilitada: sus pistas se transmiten en calidad original.';

  @override
  String get transcodeReloadQueue => 'Aplicar a la cola actual';

  @override
  String get transcodeReloadQueueSubtitle =>
      'Al cambiar los ajustes de transcodificación — marcado: recargar toda la cola ahora (la pista en reproducción se almacena en búfer brevemente); sin marcar: solo cambian las pistas siguientes, la actual termina sin cambios.';

  @override
  String get settingsTapBehavior => 'Al tocar una canción';

  @override
  String get settingsStartupPage => 'Pantalla de inicio';

  @override
  String get settingsStartupPageSubtitle =>
      'Abrir la app en esta vista del navegador; Atrás vuelve al navegador.';

  @override
  String get tapSubtitleAddToQueue =>
      'Al tocar una canción se añade a la cola. Si la cola está vacía, la reproducción comienza automáticamente.';

  @override
  String get tapSubtitlePlayFromHere =>
      'Al tocar una canción se reemplaza la cola con las canciones de la vista actual y la reproducción comienza en la canción tocada.';

  @override
  String get tapSubtitleAppendAndJump =>
      'Al tocar una canción se añade a la cola y la reproducción salta a ella, interrumpiendo lo que se estuviera reproduciendo.';

  @override
  String get settingsEqSubtitle =>
      'Ajusta graves, medios y agudos. Solo en Android.';

  @override
  String get settingsVisualizerEngine => 'Motor del visualizador';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'Presets de Milkdrop mediante projectM (predeterminado). Efectos más ricos, mayor carga en la GPU.';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Shaders de fragmento al estilo Shadertoy. Más ligeros y modulares — coloca archivos .glsl en assets/shaders/ para ampliar el catálogo.';

  @override
  String get settingsVisualizerSource => 'Fuente de audio del visualizador';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'Predeterminado. El visualizador reacciona solo a la sincronización de reproducción — no requiere permiso de micrófono.';

  @override
  String get visualizerSourceSubtitleReal =>
      'El visualizador reacciona a la salida de audio real. Requiere el permiso RECORD_AUDIO en Android.';

  @override
  String get settingsAlbumGrid => 'Vista de cuadrícula de álbumes';

  @override
  String get settingsAlbumGridSubtitle =>
      'Muestra los álbumes como una cuadrícula de tarjetas con la portada en lugar de una lista simple.';

  @override
  String get settingsFileMetadata =>
      'Leer metadatos de canciones en el explorador de archivos';

  @override
  String get settingsFileMetadataSubtitle =>
      'Obtiene el título, artista y portada de cada canción al explorar los archivos del servidor. Desactivado muestra los nombres de archivo sin procesar (más rápido para carpetas grandes).';

  @override
  String get settingsLetterStrip => 'Umbral del desplazador alfabético';

  @override
  String get settingsLetterStripSubtitle =>
      'Muestra la tira de desplazamiento rápido A-Z cuando una lista tiene esta cantidad de elementos o más. Por debajo de este tamaño la tira se oculta y los nombres largos de carpetas/archivos se ajustan en varias líneas en lugar de truncarse. Pon 0 para mostrar siempre la tira.';

  @override
  String get settingsReset => 'Restablecer valores predeterminados';

  @override
  String get settingsResetSubtitle =>
      'Restaura todos los ajustes de esta pantalla a sus valores predeterminados. Los servidores y las descargas no se ven afectados.';

  @override
  String get settingsResetDone =>
      'Ajustes restaurados a los valores predeterminados';

  @override
  String get realAudioDialogTitle => '¿Usar audio real?';

  @override
  String get realAudioDialogBody =>
      'El modo de audio real lee la forma de onda de la música que reproduce tu teléfono para que el visualizador pueda reaccionar a ella. Android requiere el permiso RECORD_AUDIO para esto — la aplicación no graba ni envía ningún audio a ningún lugar. Puedes volver al modo sintetizado en cualquier momento.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Permiso denegado permanentemente. Actívalo en los ajustes del sistema para usar audio real.';

  @override
  String get realAudioPermDenied =>
      'Permiso denegado. Se mantiene el audio sintetizado.';

  @override
  String get visualizerTapHint =>
      'Tocar = siguiente preset · mantén pulsado para cerrar';

  @override
  String get visualizerFailed => 'El visualizador no pudo iniciarse';

  @override
  String get visualizerBringingUp => 'Iniciando el renderizador…';

  @override
  String get visualizerReady => 'Visualizador listo';

  @override
  String get visualizerBridgeFailed => 'El puente no pudo iniciarse';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Fuente de audio: $source';
  }

  @override
  String get visualizerTapToClose => 'Toca en cualquier lugar para cerrar';

  @override
  String get visualizerUnsupported =>
      'El visualizador actualmente solo es compatible con Android.';

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String aboutBuiltBy(String name) {
    return 'Creado por $name';
  }

  @override
  String get linkDiscordSubtitle => 'Chat de la comunidad';

  @override
  String get linkGithubSubtitle => 'Código fuente del servidor mStream';

  @override
  String get linkHomepageSubtitle => 'Página del proyecto';

  @override
  String get aboutAttributions => 'Atribuciones';

  @override
  String get aboutAttributionsSubtitle =>
      'Licencia, créditos de shaders y avisos de código abierto.';

  @override
  String get ok => 'Aceptar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get info => 'Información';

  @override
  String get makeDefault => 'Establecer como predeterminado';

  @override
  String get goBack => 'Volver';

  @override
  String get play => 'Reproducir';

  @override
  String get playAll => 'Reproducir todo';

  @override
  String get rename => 'Renombrar';

  @override
  String get create => 'Crear';

  @override
  String get copy => 'Copiar';

  @override
  String get done => 'Listo';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get attributionsTitle => 'Atribuciones';

  @override
  String get attributionsSectionLicense => 'Licencia';

  @override
  String get attributionsSectionShaders => 'Shaders del visualizador';

  @override
  String get attributionsSectionLibraries => 'Bibliotecas nativas';

  @override
  String get attributionsSectionEverythingElse => 'Todo lo demás';

  @override
  String get attributionsLicenseBody =>
      'Software libre bajo la GNU General Public License v3.0. Puedes usarlo, estudiarlo, compartirlo y modificarlo bajo esos términos.';

  @override
  String get attributionsPackages => 'Licencias de paquetes de código abierto';

  @override
  String get attributionsPackagesSubtitle =>
      'Textos completos de licencia de todos los paquetes Flutter/Dart incluidos.';

  @override
  String get manageServersTitle => 'Gestionar servidores';

  @override
  String get manageServerInfo => 'Información del servidor';

  @override
  String get manageServerDownloadFolder => 'Carpeta de descargas:';

  @override
  String get manageServerCopyPath => 'Copiar ruta de descarga';

  @override
  String get manageServerPathCopied => 'Ruta copiada al portapapeles';

  @override
  String get confirmRemoveServerTitle => 'Confirmar eliminación del servidor';

  @override
  String get removeSyncedFiles =>
      '¿Eliminar los archivos sincronizados del dispositivo?';

  @override
  String get playlistsTitle => 'Listas de reproducción';

  @override
  String get playlistsNew => 'Nueva lista de reproducción';

  @override
  String get playlistsEmptyTitle => 'Aún no hay listas de reproducción';

  @override
  String get playlistsEmptyBody =>
      'Crea una con el botón Nueva lista de reproducción y luego usa la acción de deslizar Añadir a lista de reproducción de la cola para llenarla.';

  @override
  String get playlistNameHint => 'Nombre';

  @override
  String get playlistsRename => 'Renombrar lista de reproducción';

  @override
  String get playlistFallbackTitle => 'Lista de reproducción';

  @override
  String get playlistEmptyDetail =>
      'La lista de reproducción está vacía.\nAñade pistas desde la cola.';

  @override
  String get shareEmptyTitle => 'Cola vacía';

  @override
  String get shareEmptyBody => 'Añade canciones a la cola antes de compartir.';

  @override
  String get shareBlockedTitle => 'No se puede compartir esta cola';

  @override
  String get shareLocalOnlyBody =>
      'La cola contiene canciones que solo están en este dispositivo (en ningún servidor). Compartir solo funciona cuando todas las canciones de la cola provienen de un único servidor.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'La cola mezcla canciones de $count servidores ($names). Compartir solo funciona cuando todas las canciones provienen de un único servidor.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'El servidor \"$name\" ya no está en tu lista de servidores. Vuelve a añadirlo para compartir su cola.';
  }

  @override
  String get shareTitle => 'Compartir lista de reproducción';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return '$_temp0 de $url';
  }

  @override
  String get shareLinkExpires => 'El enlace caduca';

  @override
  String get shareExpireNever => 'Nunca';

  @override
  String get shareExpire1Day => 'Tras 1 día';

  @override
  String get shareExpire7Days => 'Tras 7 días';

  @override
  String get shareExpire30Days => 'Tras 30 días';

  @override
  String get shareAction => 'Compartir';

  @override
  String get shareDoneTitle => 'Lista de reproducción compartida';

  @override
  String get shareDoneBody =>
      'Cualquiera con este enlace puede reproducir la cola:';

  @override
  String get save => 'Guardar';

  @override
  String get start => 'Iniciar';

  @override
  String get addServerTitle => 'Añadir servidor';

  @override
  String get editServerTitle => 'Editar servidor';

  @override
  String get fieldServerUrl => 'URL del servidor';

  @override
  String get fieldPublicAccess => 'Acceso público';

  @override
  String get publicAccessSubtitle =>
      'El servidor es de acceso público — no se necesita usuario ni contraseña.';

  @override
  String get fieldUsername => 'Usuario';

  @override
  String get fieldPassword => 'Contraseña';

  @override
  String get fieldSdCard => 'Descargar a la tarjeta SD';

  @override
  String get sdCardSubtitle =>
      'Guarda la música descargada en la tarjeta SD extraíble en lugar del almacenamiento interno.';

  @override
  String get testConnectionButton => 'Probar conexión';

  @override
  String get testing => 'Probando…';

  @override
  String get connecting => 'Conectando…';

  @override
  String get validatorUrlNeeded => 'Se necesita la URL del servidor';

  @override
  String get validatorUrlParse => 'No se puede analizar la URL';

  @override
  String get testEnterUrl => 'Primero introduce la URL de un servidor.';

  @override
  String get testParseUrl => 'No se pudo analizar la URL.';

  @override
  String get testCouldNotConnect =>
      'No se pudo conectar. Comprueba la URL e inténtalo de nuevo.';

  @override
  String get testTimedOut => 'Se agotó el tiempo de conexión.';

  @override
  String get connectFailedSnack =>
      'No se pudo conectar al servidor. Comprueba la URL e inténtalo de nuevo.';

  @override
  String get connectionSuccessful => '¡Conexión correcta!';

  @override
  String get couldNotReachServer =>
      'No se pudo contactar con el servidor. Si requiere inicio de sesión, desactiva \"Acceso público\" y añade las credenciales.';

  @override
  String get failedToLogin => 'Error al iniciar sesión';

  @override
  String testConnected(String version) {
    return 'Conectado — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'No se pudo conectar: $error';
  }

  @override
  String get sleepTimerTitle => 'Temporizador de apagado';

  @override
  String get sleepTimerHint =>
      'Elige una duración tras la cual pausar la reproducción.';

  @override
  String get sleepTimerCustom => 'Personalizado';

  @override
  String get sleepTimerCustomHint => 'minutos (1–600)';

  @override
  String get sleepTimerCancel => 'Cancelar temporizador';

  @override
  String get sleepTimerInvalid => 'Introduce un número entre 1 y 600 minutos';

  @override
  String sleepTimerPausesIn(String time) {
    return 'Se pausa en $time';
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
      other: 'Temporizador de apagado configurado para $minutes minutos',
      one: 'Temporizador de apagado configurado para 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Añadir';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String get autoDjAddServerFirst => 'Primero añade un servidor.';

  @override
  String get autoDjSectionServer => 'Servidor';

  @override
  String get autoDjSectionSources => 'Fuentes';

  @override
  String get autoDjSectionContinuity => 'Continuidad';

  @override
  String get autoDjSectionFilters => 'Filtros';

  @override
  String get autoDjBpmTitle => 'Continuidad de BPM';

  @override
  String get autoDjBpmSubtitle =>
      'Prefiere selecciones dentro de un margen de tempo respecto a la canción actual. Respeta la equivalencia de tempo medio/doble.';

  @override
  String get autoDjTolerance => 'Tolerancia';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Mezcla armónica';

  @override
  String get autoDjHarmonicSubtitle =>
      'Prefiere selecciones en tonalidades que mezclen bien con la canción fijada (vecinos de la rueda Camelot).';

  @override
  String get autoDjStatusOn => 'Auto DJ está activado';

  @override
  String get autoDjStatusOff => 'Auto DJ está desactivado';

  @override
  String get autoDjStatusOffDetail =>
      'Toca abajo para iniciar. Se usará la biblioteca del servidor actual.';

  @override
  String get autoDjStart => 'Iniciar Auto DJ';

  @override
  String get autoDjStop => 'Detener Auto DJ';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'Las canciones se seleccionan de $url cuando la cola se está quedando corta.';
  }

  @override
  String get autoDjActiveSource => 'Fuente activa';

  @override
  String get autoDjActiveSourceTap => 'Fuente activa — toca para cambiar';

  @override
  String get autoDjSwitch => 'Cambiar';

  @override
  String get autoDjOneSourceRequired => 'Se requiere al menos una fuente.';

  @override
  String get autoDjMinRating => 'Valoración mínima';

  @override
  String get autoDjMinRatingSubtitle =>
      'Solo selecciona canciones con esta valoración o superior.';

  @override
  String get autoDjRatingAny => 'Cualquiera';

  @override
  String get autoDjGenreTitle => 'Filtro de géneros';

  @override
  String get autoDjGenreSubtitle =>
      'La lista blanca reproduce solo las pistas coincidentes; la lista negra las omite.';

  @override
  String get autoDjWhitelist => 'Lista blanca';

  @override
  String get autoDjBlacklist => 'Lista negra';

  @override
  String get autoDjNoGenres =>
      'No hay géneros seleccionados. Toca \"Elegir géneros\" para elegir.';

  @override
  String get autoDjPickGenres => 'Elegir géneros';

  @override
  String get autoDjGenreLoadError => 'No se pudieron cargar los géneros';

  @override
  String get autoDjKeywordTitle => 'Filtro de palabras clave';

  @override
  String get autoDjKeywordSubtitle =>
      'Omite selecciones cuyo título, artista, álbum o ruta de archivo contenga alguna de estas palabras.';

  @override
  String get autoDjNoKeywords =>
      'Sin palabras clave. Añade palabras abajo para empezar a filtrar.';

  @override
  String get autoDjKeywordHint => 'p. ej. \"live\" o \"remix\"';

  @override
  String get autoDjSearchGenres => 'Buscar géneros…';

  @override
  String get autoDjNoGenresOnServer =>
      'No se encontraron géneros en este servidor.';

  @override
  String autoDjSelectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return 'Ningún género coincide con \"$query\".';
  }

  @override
  String get download => 'Descargar';

  @override
  String get addAll => 'Añadir todo';

  @override
  String get browserConfirmDeletePlaylist =>
      'Confirmar eliminación de la lista de reproducción';

  @override
  String get browserConfirmDeleteFolder =>
      'Confirmar eliminación de la carpeta';

  @override
  String get browserSearchHint => 'Buscar en la base de datos';

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
      other: '$count descargas iniciadas',
      one: '1 descarga iniciada',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones añadidas a la cola',
      one: '1 canción añadida a la cola',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Explorador';

  @override
  String get tabQueue => 'Cola';

  @override
  String get drawerTagline => 'Streaming de música personal';

  @override
  String get mainFailedToConnect => 'Error al conectar con el servidor';

  @override
  String get mainQueueEmpty => 'La cola está vacía';

  @override
  String get visualizerTitle => 'Visualizador';

  @override
  String get mainClearQueue => 'Vaciar la cola';

  @override
  String get mainSync => 'Sincronizar';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas en la cola',
      one: '1 pista en la cola',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ activado';

  @override
  String get autoDjDisabled => 'Auto DJ desactivado';

  @override
  String autoDjEnabledFor(String url) {
    return 'Auto DJ activado para $url';
  }

  @override
  String get addToPlaylistTitle => 'Añadir a lista de reproducción';

  @override
  String get addToPlaylistEmpty =>
      'Aún no hay listas de reproducción — toca + para crear una.';

  @override
  String addedToPlaylist(String name) {
    return 'Añadido a $name';
  }

  @override
  String get testConnectedSignedIn =>
      'Conectado — sesión iniciada correctamente.';

  @override
  String get testSignInFailed =>
      'Se contactó con el servidor, pero el inicio de sesión falló — comprueba tu usuario y contraseña.';

  @override
  String get browserFileExplorer => 'Explorador de archivos';

  @override
  String get browserLocalFiles => 'Archivos locales';

  @override
  String get browserPlaylists => 'Listas de reproducción';

  @override
  String get browserAlbums => 'Álbumes';

  @override
  String get browserArtists => 'Artistas';

  @override
  String get browserRecent => 'Recientes';

  @override
  String get browserRated => 'Valoradas';

  @override
  String get browserSearch => 'Buscar';

  @override
  String get browserWelcomeTitle => 'Bienvenido a mStream';

  @override
  String get browserWelcomeSubtitle => 'Toca aquí para añadir un servidor';

  @override
  String get settingsVisualizerKnobs => 'Controles de ajuste del visualizador';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      'Muestra controles deslizantes sobre el visualizador para ajustar la reactividad de audio de cada shader. Solo con el motor de shaders.';

  @override
  String get visualizerTuningTitle => 'Ajuste';

  @override
  String get close => 'Cerrar';

  @override
  String get migMoveStopped =>
      'Traslado detenido — no hay espacio suficiente o la ubicación no está disponible.';

  @override
  String get migMoveComplete => 'Traslado completado';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Traslado completado — $count archivos omitidos (no compatibles en el destino)',
      one:
          'Traslado completado — 1 archivo omitido (no compatible en el destino)',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'Trasladando descargas… $progress — mantén la aplicación abierta';
  }

  @override
  String get migRetry => 'Reintentar';

  @override
  String get queueDownloadAll => 'Descargar todo';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se descargarán $count pistas para reproducción sin conexión.',
      one: 'Se descargará 1 pista para reproducción sin conexión.',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'Más';

  @override
  String get commonOn => 'Activado';

  @override
  String get commonOff => 'Desactivado';

  @override
  String get settingsCastQuality => 'Calidad del visualizador en Cast';

  @override
  String get settingsCastQualitySubtitle720 =>
      'Resolución a la que el visualizador se transmite a una TV. 720p — la más ligera para el teléfono.';

  @override
  String get settingsCastQualitySubtitle1080 =>
      'Resolución a la que el visualizador se transmite a una TV. 1080p — nítida en cualquier Chromecast (predeterminada).';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Resolución a la que el visualizador se transmite a una TV. 4K — necesita un Chromecast 4K; mucha más carga para el teléfono.';

  @override
  String get eqCasting =>
      'El ecualizador ajusta el audio en este dispositivo, así que no está disponible mientras se transmite. Desconecta para usarlo.';

  @override
  String get browserNothingToDownload =>
      'No hay nada que descargar en esta lista';

  @override
  String get browserDownloadAllTitle => 'Descargar todo';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se descargarán $count archivos.',
      one: 'Se descargará 1 archivo.',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => 'Cerrar búsqueda';

  @override
  String get browserSearchThisList => 'Buscar en esta lista';

  @override
  String get browserSearchList => 'Buscar en la lista';

  @override
  String browserNoMatches(String query) {
    return 'Sin coincidencias para \"$query\"';
  }

  @override
  String get clear => 'Borrar';

  @override
  String get dlLocationUnavailable => 'Ubicación de descarga no disponible';

  @override
  String get dlLocationUnavailableServer =>
      'Ubicación de descarga no disponible para este servidor.';

  @override
  String get dlFailed => 'Una descarga falló — comprueba tu conexión.';

  @override
  String get dlFatSkip =>
      'Algunas pistas no se pueden guardar en esta tarjeta — sus nombres no son compatibles. En su lugar se transmiten.';

  @override
  String get dlServerGone => 'Ese servidor ya no está configurado.';

  @override
  String get dlStorageUnavailable =>
      'Ubicación de almacenamiento no disponible — vuelve a conectar la tarjeta SD o cambia la ubicación de almacenamiento de este servidor en Editar servidor.';

  @override
  String get dlCouldNotStart =>
      'No se pudo iniciar la descarga — almacenamiento no disponible.';

  @override
  String get storageLocationLabel => 'Ubicación de almacenamiento';

  @override
  String get storageAppLocal => 'Local de la app';

  @override
  String get storagePermanent => 'Permanente';

  @override
  String get storageSdCard => 'Tarjeta SD';

  @override
  String get storageHelpAppLocal =>
      'Guardado dentro de la aplicación. Se elimina al desinstalar o borrar los datos de la app.';

  @override
  String get storageHelpPermanent =>
      'Guardado en una carpeta que elijas. Se conserva al desinstalar la aplicación. Requiere \"Acceso a todos los archivos\".';

  @override
  String get storageHelpSdCard =>
      'Guardado en una carpeta de la tarjeta SD que elijas. Puede dejar de estar disponible si se retira la tarjeta. Algunos dispositivos no permiten que las apps escriban en tarjetas SD — si la selección de carpeta sigue fallando, usa Permanente o Local de la app.';

  @override
  String get storageChooseFolder => 'Elegir carpeta';

  @override
  String get storageNoFolderChosen => 'Aún no se ha elegido ninguna carpeta';

  @override
  String get storageDownloadFolderLabel => 'Carpeta de descargas';

  @override
  String get storageDownloadFolderHint => 'nombre de la carpeta';

  @override
  String get storageBrowse => 'Examinar';

  @override
  String get storageDownloadFolderHelp =>
      'Los archivos se descargan en un directorio \'media/<folder>\' de este dispositivo. Reutilizar la carpeta de un servidor anterior conserva sus canciones descargadas al volver a añadir un servidor perdido.';

  @override
  String get storageNoStorageAvailable => 'No hay almacenamiento disponible';

  @override
  String get storageNoDownloadFolders =>
      'No se encontraron carpetas de descarga existentes';

  @override
  String get storageExistingFolders => 'Carpetas de descarga existentes';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'Concede \"Acceso a todos los archivos\" para almacenar las descargas de forma permanente y luego vuelve a elegir el modo.';

  @override
  String get storageSettings => 'Ajustes';

  @override
  String get storageNoVolume =>
      'No se pudo localizar un volumen de almacenamiento';

  @override
  String get storageNotWritable =>
      'Esa carpeta no admite escritura — elige otra.';

  @override
  String get storageNewFolder => 'Nueva carpeta';

  @override
  String get storageFolderNameHint => 'Nombre de la carpeta';

  @override
  String get storageCouldNotCreateFolder => 'No se pudo crear la carpeta';

  @override
  String get storageNoSubfolders => 'No hay subcarpetas aquí';

  @override
  String get storageUseThisFolder => 'Usar esta carpeta';

  @override
  String get storageMovedToNewFolder =>
      'Se trasladaron los archivos descargados a la nueva carpeta.';

  @override
  String get storageMoveAlreadyRunning =>
      'Ya hay un traslado en curso — deja que termine primero.';

  @override
  String get storageMigrateTitle => 'Volumen de almacenamiento distinto';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Los $count archivos descargados de este servidor ($size) están en un volumen de almacenamiento distinto al de la nueva ubicación. Elige qué hacer:',
      one:
          'El archivo descargado de este servidor ($size) está en un volumen de almacenamiento distinto al de la nueva ubicación. Elige qué hacer:',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return 'No hay espacio libre suficiente en el destino ($free libres). Un traslado podría fallar a medias — libera espacio primero.';
  }

  @override
  String get storageMigrateMove => 'Trasladarlos';

  @override
  String get storageMigrateMoveBody =>
      'Copia a la nueva ubicación en segundo plano, eliminando cada copia antigua a medida que avanza. Mantén la aplicación abierta hasta que termine.';

  @override
  String get storageMigrateLeave => 'Dejarlos';

  @override
  String get storageMigrateLeaveBody =>
      'Cambia ahora; las descargas antiguas se quedan donde están y se vuelven a descargar en la nueva ubicación.';

  @override
  String get storageMigrateDelete => 'Eliminar descargas antiguas';

  @override
  String get storageMigrateDeleteBody =>
      'Cambia ahora y elimina los archivos antiguos; se volverán a descargar en la nueva ubicación.';

  @override
  String get storageMovingBackground =>
      'Trasladando tus descargas en segundo plano — mantén la aplicación abierta.';

  @override
  String get storageChooseFolderFirst =>
      'Primero elige una carpeta de descargas.';

  @override
  String get storageChooseSdFolderFirst =>
      'Primero elige una carpeta en la tarjeta SD. Si se rechazan todas las carpetas, puede que tu dispositivo no permita que las apps escriban en la tarjeta — usa Permanente o Local de la app en su lugar.';

  @override
  String get castPlayOn => 'Reproducir en';

  @override
  String get castPlayOnTooltip => 'Reproducir en…';

  @override
  String get castSearching => 'Buscando dispositivos de Cast…';

  @override
  String get castNotSeeing =>
      '¿No ves tu dispositivo? Asegúrate de que esté en la misma red Wi-Fi.';

  @override
  String get castVisualizer => 'Transmitir el visualizador';

  @override
  String get castVisualizerSubtitle =>
      'Transmite el visualizador a la TV · solo Chromecast';

  @override
  String get visualizerNoKnobs => 'Este shader no expone ningún control.';

  @override
  String get nowPlaying => 'Reproduciendo ahora';

  @override
  String get playerLayoutSmall => 'Pequeño';

  @override
  String get playerLayoutMedium => 'Mediano';

  @override
  String get playerLayoutLarge => 'Grande';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => 'Barra fina — cola máxima';

  @override
  String get playerLayoutMediumDesc => 'Banner — equilibrado (predeterminado)';

  @override
  String get playerLayoutLargeDesc => 'Compacto — carátula centrada';

  @override
  String get playerLayoutXlDesc => 'Destacado — carátula completa';

  @override
  String get queueNothingToDownloadEmpty =>
      'La cola está vacía — no hay nada que descargar';

  @override
  String get queueNothingToDownloadSaved =>
      'No hay nada que descargar — las pistas ya están guardadas';

  @override
  String get settingsAccentColor => 'Color de acento';

  @override
  String get settingsAccentColorSubtitle =>
      'El color de resalte que se usa en toda la aplicación.';

  @override
  String get accentThemeDefault => 'Predeterminado del tema';

  @override
  String get accentCustom => 'Personalizado';

  @override
  String get settingsResumeQueue => 'Reanudar la cola al iniciar';

  @override
  String get settingsResumeQueueSubtitle =>
      'Guarda la cola de reproducción y tu posición y las restaura al volver a abrir la app.';

  @override
  String get settingsRatingHalf => 'Valoraciones de media estrella';

  @override
  String get settingsRatingHalfSubtitle =>
      'Valora canciones en pasos de media estrella (mantén pulsada una estrella).';

  @override
  String get ratingTitle => 'Valorar';

  @override
  String get ratingFailed => 'No se pudo guardar la valoración';

  @override
  String get diagnosticsTitle => 'Diagnóstico';

  @override
  String get diagnosticsEnable => 'Activar registro';

  @override
  String get diagnosticsHint =>
      'Los registros se quedan en tu dispositivo. Los tokens se ocultan antes de copiar o compartir.';

  @override
  String get diagnosticsCopy => 'Copiar';

  @override
  String get diagnosticsShare => 'Compartir';

  @override
  String get diagnosticsClear => 'Borrar';

  @override
  String get diagnosticsCopied => 'Registros copiados al portapapeles';

  @override
  String get diagnosticsEmpty => 'Aún no hay registros';

  @override
  String get storageAppExternal => 'App externa';

  @override
  String get selfSignedTitle => 'Permitir certificado autofirmado';

  @override
  String get selfSignedSubtitle =>
      'Omite la validación TLS de este servidor. Actívalo solo en una red de confianza.';

  @override
  String get importedShadersTitle => 'Shaders importados';

  @override
  String get importedShadersSettingsSubtitle =>
      'Añade tus propios archivos .glsl a la rotación del motor Shader.';

  @override
  String get importedShadersRescan => 'Volver a escanear la carpeta';

  @override
  String get importedShadersDropHint =>
      'Coloca archivos .glsl en esta carpeta y luego pulsa Volver a escanear:';

  @override
  String get importedShadersCopyPath => 'Copiar ruta';

  @override
  String get importedShadersReachableHint =>
      'Accesible por USB o un gestor de archivos (en Android/data). Los shaders importados se unen a la rotación cuando el motor Shader está activo.';

  @override
  String get importedShadersRemove => 'Quitar';

  @override
  String get importedShadersEmptyTitle => 'Aún no hay shaders en la carpeta';

  @override
  String get importedShadersEmptyBody =>
      'Copia archivos .glsl al estilo Shadertoy en la carpeta de arriba y luego toca Volver a escanear.';

  @override
  String get importedShadersInvalid =>
      'Puede que no sea un shader válido — sin punto de entrada mainImage/main.';

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
  String get adminLogOut => 'Cerrar sesión';

  @override
  String get adminConfigGroup => 'Configuración';

  @override
  String get adminDirectories => 'Directorios';

  @override
  String get adminUsers => 'Usuarios';

  @override
  String get adminDLNA => 'DLNA';

  @override
  String get adminSubsonicAPI => 'API de Subsonic';

  @override
  String get adminMP3Player => 'Reproductor MP3';

  @override
  String get adminTorrent => 'Torrent';

  @override
  String get adminFederation => 'Federación';

  @override
  String get adminServerGroup => 'Servidor';

  @override
  String get adminAbout => 'Acerca de';

  @override
  String get adminSettings => 'Ajustes';

  @override
  String get adminDatabase => 'Base de datos';

  @override
  String get adminBackups => 'Copias de seguridad';

  @override
  String get adminTranscoding => 'Transcodificación';

  @override
  String get adminLogs => 'Registros';

  @override
  String get adminAccess => 'Acceso de administrador';

  @override
  String adminAppBarTitle(String label) {
    return 'mStream Admin · $label';
  }

  @override
  String get adminPanelTitle => 'mStream Admin';

  @override
  String get adminLoginErrorRequired =>
      'El servidor y el nombre de usuario son obligatorios';

  @override
  String get adminLoginServerURL => 'URL del servidor';

  @override
  String get adminLoginUsername => 'Nombre de usuario';

  @override
  String get adminLoginPassword => 'Contraseña';

  @override
  String get adminLoginSignIn => 'Iniciar sesión';

  @override
  String get adminRetry => 'Reintentar';

  @override
  String get adminSaved => 'Guardado';

  @override
  String get adminSave => 'Guardar';

  @override
  String get adminClose => 'Cerrar';

  @override
  String get adminPanelMenuItem => 'Panel de administración';

  @override
  String get adminNoLibrariesYetTitle => 'Aún no hay bibliotecas';

  @override
  String get adminAddDirectoryHint =>
      'Añade un directorio para empezar a escanear música en la biblioteca.';

  @override
  String get adminAddDirectoryButton => 'Añadir directorio';

  @override
  String adminRemoveDirectoryTitle(String name) {
    return '¿Quitar $name?';
  }

  @override
  String get adminRemoveDirectoryWarning =>
      'Esto quita la biblioteca y sus pistas escaneadas de la base de datos. Los archivos del disco no se modifican.';

  @override
  String get adminCancel => 'Cancelar';

  @override
  String get adminRemove => 'Quitar';

  @override
  String get adminLibraryRemovedToast => 'Biblioteca quitada';

  @override
  String get adminDirectoryPathLabel => 'Ruta';

  @override
  String get adminDirectoryTypeLabel => 'Tipo';

  @override
  String get adminFollowSymlinksTitle => 'Seguir enlaces simbólicos';

  @override
  String get adminFollowSymlinksSubtitle => 'Se aplica en el próximo escaneo';

  @override
  String get adminPickFolderAndNameError =>
      'Elige una carpeta e introduce un nombre';

  @override
  String get adminDirectoryAddedToast =>
      'Directorio añadido — escaneo iniciado';

  @override
  String get adminAddDirectoryDialogTitle => 'Añadir directorio';

  @override
  String get adminChooseFolderButton => 'Elegir carpeta en el servidor…';

  @override
  String get adminLibraryNameLabel => 'Nombre de la biblioteca (vpath)';

  @override
  String get adminLibraryNameHelper => 'Letras, números y guiones';

  @override
  String get adminGrantAllUsersAccessTitle => 'Dar acceso a todos los usuarios';

  @override
  String get adminAudiobookLibraryTitle => 'Biblioteca de audiolibros';

  @override
  String get adminAdd => 'Añadir';

  @override
  String get adminChooseFolderTitle => 'Elegir una carpeta';

  @override
  String get adminSelectFolderButton => 'Seleccionar esta carpeta';

  @override
  String get adminNoUsersTitle => 'Sin usuarios';

  @override
  String get adminNoUsersSubtitle =>
      'Sin usuarios, el servidor funciona en modo abierto/público. Añade uno para exigir inicio de sesión.';

  @override
  String get adminAddUserButton => 'Añadir usuario';

  @override
  String get adminLibraryAccessDialogTitle => 'Acceso a bibliotecas';

  @override
  String get adminLibraryAccessUpdatedToast =>
      'Acceso a bibliotecas actualizado';

  @override
  String get adminSetSubsonicPasswordTitle =>
      'Establecer contraseña de Subsonic';

  @override
  String get adminSetPasswordTitle => 'Establecer contraseña';

  @override
  String get adminPasswordUpdatedToast => 'Contraseña actualizada';

  @override
  String adminDeleteUserTitle(String username) {
    return '¿Eliminar $username?';
  }

  @override
  String get adminDeleteUserWarning =>
      'Esto elimina permanentemente la cuenta de usuario.';

  @override
  String get adminDelete => 'Eliminar';

  @override
  String get adminUserDeletedToast => 'Usuario eliminado';

  @override
  String get adminStatusPillLabel => 'admin';

  @override
  String get adminDeleteUserMenuItem => 'Eliminar usuario';

  @override
  String get adminNoLibraryAccessLabel => 'Sin acceso a bibliotecas';

  @override
  String get adminLibrariesButton => 'Bibliotecas';

  @override
  String get adminAdminToggleTitle => 'Administrador';

  @override
  String get adminMakeDirsToggleTitle => 'Crear dirs.';

  @override
  String get adminUploadToggleTitle => 'Subir';

  @override
  String get adminModifyFilesToggleTitle => 'Modificar archivos';

  @override
  String get adminServerAudioToggleTitle => 'Audio del servidor';

  @override
  String get adminAddUserDialogTitle => 'Añadir usuario';

  @override
  String get adminUsername => 'Nombre de usuario';

  @override
  String get adminPassword => 'Contraseña';

  @override
  String get adminSubsonicPasswordLabel => 'Contraseña de Subsonic (opcional)';

  @override
  String get adminLibraryAccessHeader => 'Acceso a bibliotecas';

  @override
  String get adminUsernamePasswordRequiredError =>
      'El nombre de usuario y la contraseña son obligatorios';

  @override
  String get adminUserCreatedToast => 'Usuario creado';

  @override
  String get adminAdministratorToggleTitle => 'Administrador';

  @override
  String get adminAllowMakeDirectoriesTitle => 'Permitir crear directorios';

  @override
  String get adminAllowUploadTitle => 'Permitir subidas';

  @override
  String get adminAllowServerAudioTitle => 'Permitir audio del servidor';

  @override
  String get adminCreate => 'Crear';

  @override
  String get adminNoLibrariesConfigured => 'No hay bibliotecas configuradas.';

  @override
  String get adminNewPasswordLabel => 'Nueva contraseña';

  @override
  String get adminLibraryTitle => 'Biblioteca';

  @override
  String get adminTracksInDatabase => 'Pistas en la base de datos';

  @override
  String get adminScanAllButton => 'Escanear todo';

  @override
  String get adminScanStarted => 'Escaneo iniciado';

  @override
  String get adminForceRescan => 'Forzar reescaneo';

  @override
  String get adminFullRescanStarted => 'Reescaneo completo iniciado';

  @override
  String get adminCompressImages => 'Comprimir imágenes';

  @override
  String get adminImageCompressionStarted => 'Compresión de imágenes iniciada';

  @override
  String get adminScanOptions => 'Opciones de escaneo';

  @override
  String get adminScanInterval =>
      'Intervalo de escaneo (horas, 0 = desactivado)';

  @override
  String get adminBootScanDelay => 'Retardo del escaneo al iniciar (segundos)';

  @override
  String get adminScanCommitInterval =>
      'Intervalo de confirmación del escaneo (1–1000)';

  @override
  String get adminScanThreads => 'Hilos de escaneo (0 = automático)';

  @override
  String get adminSkipImageExtraction => 'Omitir extracción de imágenes';

  @override
  String get adminCompressEmbeddedImages => 'Comprimir imágenes incrustadas';

  @override
  String get adminGenerateWaveforms => 'Generar formas de onda tras el escaneo';

  @override
  String get adminAnalyzeBpm => 'Analizar BPM/tono (obsoleto, sin efecto)';

  @override
  String get adminAutomaticAlbumArt => 'Carátulas automáticas';

  @override
  String get adminDownloadMissingAlbumArt => 'Descargar carátulas faltantes';

  @override
  String get adminTargetLabel => 'Objetivo';

  @override
  String get adminMissingOnly => 'Solo las faltantes';

  @override
  String get adminAllAlbums => 'Todos los álbumes';

  @override
  String get adminAlbumsPerRun => 'Álbumes por ejecución (1–10000)';

  @override
  String get adminAutoDownloadedArtWriteFolder =>
      'Carátula descargada automáticamente → escribir en la carpeta';

  @override
  String get adminManualArtWriteFolder =>
      'Carátula manual → escribir en la carpeta';

  @override
  String get adminManualArtEmbedTag =>
      'Carátula manual → incrustar en la etiqueta del archivo';

  @override
  String get adminArtServices => 'Servicios de carátulas';

  @override
  String get adminArtServicesUpdated => 'Servicios de carátulas actualizados';

  @override
  String get adminSharedPlaylists => 'Listas compartidas';

  @override
  String get adminDeleteExpired => 'Eliminar caducadas';

  @override
  String get adminExpiredSharesDeleted => 'Compartidos caducados eliminados';

  @override
  String get adminDeleteNeverExpiring => 'Eliminar sin caducidad';

  @override
  String get adminEternalSharesDeleted =>
      'Compartidos sin caducidad eliminados';

  @override
  String get adminNoSharedPlaylists => 'No hay listas compartidas';

  @override
  String adminSharedPlaylistSubtitle(String user, int count, String expiry) {
    return 'de $user · $count pistas · caduca $expiry';
  }

  @override
  String get adminShareDeleted => 'Compartido eliminado';

  @override
  String get adminNetwork => 'Red';

  @override
  String get adminNetworkSubtitle =>
      'Cambiar esto reinicia suavemente el servidor.';

  @override
  String get adminBindAddress => 'Dirección de enlace';

  @override
  String get adminPort => 'Puerto';

  @override
  String get adminTrustProxyHeaders => 'Confiar en cabeceras de proxy';

  @override
  String get adminTrustProxyHeadersSubtitle =>
      'Actívalo si estás detrás de un proxy inverso (X-Forwarded-*)';

  @override
  String get adminPermissions => 'Permisos';

  @override
  String get adminAllowUploads => 'Permitir subidas';

  @override
  String get adminAllowMakingDirectories => 'Permitir crear directorios';

  @override
  String get adminAllowModifyingFiles => 'Permitir modificar archivos';

  @override
  String get adminMaxRequestSize => 'Tamaño máximo de solicitud';

  @override
  String get adminMaxRequestSizeHelper => 'p. ej. 50MB o 512KB';

  @override
  String get adminHttpUi => 'HTTP e interfaz';

  @override
  String get adminResponseCompression => 'Compresión de respuestas';

  @override
  String get adminCompressionNone => 'Ninguna';

  @override
  String get adminCompressionGzip => 'gzip';

  @override
  String get adminCompressionBrotli => 'brotli';

  @override
  String get adminWebUi => 'Interfaz web';

  @override
  String get adminUiDefault => 'Predeterminada';

  @override
  String get adminUiVelvet => 'Velvet';

  @override
  String get adminUiSubsonic => 'Subsonic';

  @override
  String get adminDatabaseTuning => 'Ajuste de la base de datos';

  @override
  String get adminSqliteSynchronous => 'SQLite synchronous';

  @override
  String get adminSyncFull => 'FULL (safest)';

  @override
  String get adminSyncNormal => 'NORMAL (faster)';

  @override
  String get adminCacheSize => 'Tamaño de caché (MB, 1–2048)';

  @override
  String get adminLogging => 'Registro';

  @override
  String get adminWriteLogsToDisk => 'Escribir registros en disco';

  @override
  String get adminLogBufferSize =>
      'Tamaño del búfer de registros (0–10000, 0 = desactivado)';

  @override
  String get adminServerAudio => 'Audio del servidor';

  @override
  String get adminAutoBootServerAudio =>
      'Iniciar automáticamente el audio del servidor (reproductor Rust)';

  @override
  String get adminRustPlayerPort => 'Puerto del reproductor Rust';

  @override
  String get adminActiveBackend => 'Backend activo';

  @override
  String get adminPlayer => 'Reproductor';

  @override
  String get adminDetectedCliPlayers => 'Reproductores CLI detectados';

  @override
  String get adminNone => 'ninguno';

  @override
  String get adminReDetectPlayers => 'Volver a detectar reproductores';

  @override
  String get adminReProbedCliPlayers => 'Reproductores CLI vueltos a detectar';

  @override
  String get adminSslHttps => 'SSL / HTTPS';

  @override
  String get adminEnabled => 'Activado';

  @override
  String get adminDisabled => 'Desactivado';

  @override
  String get adminReplaceCertificate => 'Reemplazar certificado';

  @override
  String get adminSetCertificate => 'Establecer certificado';

  @override
  String get adminSetSslCertificateDialog => 'Establecer certificado SSL';

  @override
  String get adminCertificatePath => 'Ruta del certificado';

  @override
  String get adminKeyPath => 'Ruta de la clave';

  @override
  String get adminSslConfigured => 'SSL configurado — reinicia para aplicar';

  @override
  String get adminRemoveSsl => 'Quitar SSL';

  @override
  String get adminSslRemoved => 'SSL quitado';

  @override
  String get adminSecurity => 'Seguridad';

  @override
  String get adminJwtSecretLast4 => 'Secreto JWT (últimos 4)';

  @override
  String get adminRegenerateSecret => 'Regenerar secreto';

  @override
  String get adminSecretRegenerated =>
      'Secreto regenerado — todas las sesiones invalidadas';

  @override
  String get adminRegenerateJwtSecretDialog => '¿Regenerar el secreto JWT?';

  @override
  String get adminRegenerateJwtSecretDialogBody =>
      'Esto invalida todos los inicios de sesión existentes (incluido este). Todos deberán volver a iniciar sesión.';

  @override
  String get adminRegenerateButton => 'Regenerar';

  @override
  String get adminAllNetworks => 'Todas las redes';

  @override
  String get adminLocalhostOnly => 'Solo localhost';

  @override
  String get adminIpWhitelist => 'Lista blanca de IP';

  @override
  String get adminNoneLockAdmin => 'Ninguno (bloquear administrador)';

  @override
  String get adminNetworkAccess => 'Acceso de red';

  @override
  String get adminNetworkAccessSubtitle =>
      'Restringe qué redes pueden acceder a la API de administración.';

  @override
  String get adminMode => 'Modo';

  @override
  String get adminWhitelistedIps => 'IP / CIDR en lista blanca';

  @override
  String get adminNoneYet => 'Aún ninguno';

  @override
  String get adminAddIpOrCidr => 'Añadir IP o CIDR';

  @override
  String get adminCidrExample => '192.168.1.0/24';

  @override
  String get adminApply => 'Aplicar';

  @override
  String get adminDangerZone => 'Zona de peligro';

  @override
  String get adminLockAdminApi => 'Bloquear la API de administración';

  @override
  String get adminLockAdminApiSubtitle =>
      'Desactiva toda la API de administración. No se puede deshacer desde aquí.';

  @override
  String get adminLockButton => 'Bloquear';

  @override
  String get adminLockAdminApiDialog => '¿Bloquear la API de administración?';

  @override
  String get adminLockAdminApiDialogBody =>
      'Esto desactiva toda la API /admin para todos. No podrás deshacerlo desde este panel: requiere editar el archivo de configuración del servidor y reiniciarlo. ¿Continuar?';

  @override
  String get adminAdminApiLocked => 'API de administración bloqueada';

  @override
  String get adminAccessUpdated => 'Acceso de administrador actualizado';

  @override
  String get adminTranscodingFFmpegTitle => 'FFmpeg';

  @override
  String get adminFFmpegStatusReady => 'Listo';

  @override
  String get adminFFmpegStatusNotDownloaded => 'No descargado';

  @override
  String get adminFFmpegDownloadButton => 'Descargar / actualizar ffmpeg';

  @override
  String get adminFFmpegDownloadedToast => 'ffmpeg descargado';

  @override
  String get adminFFmpegAutoUpdateTitle => 'Actualizar ffmpeg automáticamente';

  @override
  String get adminFFmpegAutoUpdateSubtitle =>
      'Mantén el ffmpeg incluido actualizado automáticamente';

  @override
  String get adminTranscodingDefaultsTitle => 'Predeterminados';

  @override
  String get adminDefaultCodecLabel => 'Códec predeterminado';

  @override
  String get adminDefaultBitrateLabel => 'Tasa de bits predeterminada';

  @override
  String get adminLogsResumeButton => 'Reanudar';

  @override
  String get adminLogsPauseButton => 'Pausar';

  @override
  String get adminClear => 'Borrar';

  @override
  String get adminLogsAutoScrollTitle => 'Desplazamiento automático';

  @override
  String adminLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas',
      one: '1 línea',
    );
    return '$_temp0';
  }

  @override
  String get adminLogsDownloadZipButton => 'Descargar zip';

  @override
  String get adminLogsNoEntriesHint => 'Aún no hay entradas de registro';

  @override
  String get adminDlnaModeDisabled => 'Desactivado';

  @override
  String get adminSamePortAsHttp => 'Mismo puerto que HTTP';

  @override
  String get adminSeparatePort => 'Puerto separado';

  @override
  String get adminDlnaBrowseFlat => 'Plano (todas las pistas)';

  @override
  String get adminDlnaBrowseDirectories => 'Directorios';

  @override
  String get adminDlnaBrowseArtist => 'Por artista';

  @override
  String get adminDlnaBrowseAlbum => 'Por álbum';

  @override
  String get adminDlnaBrowseGenre => 'Por género';

  @override
  String get adminDlnaServerTitle => 'Servidor';

  @override
  String get adminDlnaIdentityTitle => 'Identidad';

  @override
  String get adminDlnaFriendlyNameLabel => 'Nombre descriptivo';

  @override
  String get adminDlnaDeviceUuidLabel => 'UUID del dispositivo';

  @override
  String get adminDlnaDeviceUuidHelper => 'GUID canónico';

  @override
  String get adminDlnaBrowseLayoutTitle => 'Diseño de navegación';

  @override
  String get adminDlnaStructureLabel => 'Estructura';

  @override
  String get adminMdnsLocalNetworkDiscoveryTitle => 'Detección en red local';

  @override
  String get adminMdnsLocalNetworkDiscoverySubtitle =>
      'Anuncia este servidor como un servicio mDNS _mstream._tcp. Solo publica metadatos: no expone datos de la biblioteca ni nuevas rutas.';

  @override
  String get adminMdnsEnableAdvertisingTitle => 'Activar anuncio';

  @override
  String get adminMdnsFriendlyNameLabel => 'Nombre descriptivo';

  @override
  String get adminMdnsFriendlyNameHelper =>
      'Vacío = derivar del nombre de host (máx. 63 bytes)';

  @override
  String get adminMdnsInstanceIdLabel => 'ID de instancia';

  @override
  String get adminSubsonicApiTitle => 'API de Subsonic';

  @override
  String get adminTestConnection => 'Probar conexión';

  @override
  String adminSubsonicTestSuccess(String version, String latency) {
    return 'OK · $version · $latency ms';
  }

  @override
  String adminSubsonicTestFailed(String reason) {
    return 'Error: $reason';
  }

  @override
  String get adminStatus => 'Estado';

  @override
  String get adminMethodsImplemented => 'Métodos implementados';

  @override
  String get adminFullStub => 'Completo / stub';

  @override
  String get adminNowPlaying => 'Reproduciendo ahora';

  @override
  String get adminNobody => 'nadie';

  @override
  String get adminLyricsLrclib => 'Letras (LRCLib)';

  @override
  String get adminLrclibFallback => 'Respaldo de LRCLib';

  @override
  String get adminWriteLrcSidecarFiles => 'Escribir archivos .lrc adjuntos';

  @override
  String get adminCache => 'Caché';

  @override
  String get adminPurgeCache => 'Purgar caché';

  @override
  String get adminLyricsCachePurged => 'Caché de letras purgada';

  @override
  String get adminRetryFailed => 'Reintentar fallidas';

  @override
  String get adminTransientLyricsEntriesCleared =>
      'Entradas transitorias de letras borradas';

  @override
  String get adminJukebox => 'Jukebox';

  @override
  String get adminAvailable => 'Disponible';

  @override
  String get adminUnavailable => 'No disponible';

  @override
  String get adminState => 'Estado';

  @override
  String get adminPlaying => 'reproduciendo';

  @override
  String get adminPaused => 'en pausa';

  @override
  String get adminIdle => 'inactivo';

  @override
  String get adminCurrent => 'Actual';

  @override
  String get adminQueue => 'Cola';

  @override
  String adminQueueTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
    );
    return '$_temp0';
  }

  @override
  String get adminVolume => 'Volumen';

  @override
  String adminVolumePercent(int percent) {
    return '$percent %';
  }

  @override
  String get adminTokenAuthFailures => 'Fallos de autenticación por token';

  @override
  String get adminTokenAuthFailuresSubtitle =>
      'Clientes que recurren a autenticación por token sin una contraseña de Subsonic.';

  @override
  String get adminNoRecentFailures => 'No hay fallos recientes';

  @override
  String get adminCleared => 'Borrado';

  @override
  String get adminMintApiKey => 'Generar clave de API';

  @override
  String get adminMintApiKeySubtitle =>
      'Genera una apiKey de Subsonic para un usuario (se muestra una sola vez).';

  @override
  String get adminKeyNameLabel => 'Nombre / etiqueta de la clave';

  @override
  String get adminMintKey => 'Generar clave';

  @override
  String get adminUsernameAndNameRequired =>
      'Se requieren el nombre de usuario y el nombre';

  @override
  String get adminTorrentClient => 'Cliente';

  @override
  String get adminActiveClient => 'Cliente activo';

  @override
  String get adminTransmission => 'Transmission';

  @override
  String get adminQbittorrent => 'qBittorrent';

  @override
  String get adminDeluge => 'Deluge';

  @override
  String get adminEnabledFor => 'Activado para';

  @override
  String get adminAllUsers => 'Todos los usuarios';

  @override
  String get adminWhitelistedUsers => 'Usuarios en lista blanca';

  @override
  String get adminHost => 'Host';

  @override
  String get adminPasswordUnchangedIfBlank =>
      'sin cambios si se deja en blanco';

  @override
  String get adminRpcPath => 'Ruta RPC';

  @override
  String get adminUseHttps => 'Usar HTTPS';

  @override
  String get adminTest => 'Probar';

  @override
  String adminReachable(String version) {
    return 'Accesible$version';
  }

  @override
  String adminConnectionFailed(String error) {
    return 'Error: $error';
  }

  @override
  String get adminConnectAndSave => 'Conectar y guardar';

  @override
  String adminSaveFailed(String error) {
    return 'Error: $error';
  }

  @override
  String get adminConnectedAndSaved => 'Conectado y guardado';

  @override
  String get adminDisconnect => 'Desconectar';

  @override
  String get adminDisconnected => 'Desconectado';

  @override
  String get adminConfigured => 'Configurado';

  @override
  String get adminNotConfigured => 'Sin configurar';

  @override
  String get adminTorrents => 'Torrents';

  @override
  String get adminConnected => 'Conectado';

  @override
  String get adminNoTorrents => 'Sin torrents';

  @override
  String get adminMstream => 'mStream';

  @override
  String get adminTorrentRemoved => 'Torrent quitado';

  @override
  String get adminLibraryDaemonPathMapping =>
      'Asignación de rutas biblioteca → daemon';

  @override
  String get adminLibraryDaemonPathMappingSubtitle =>
      'Asigna cada biblioteca a su ruta tal como la ve el daemon de torrents.';

  @override
  String get adminAutoDetectAll => 'Detectar todo automáticamente';

  @override
  String get adminAutoDetectionComplete => 'Detección automática completada';

  @override
  String get adminVerified => 'verificado';

  @override
  String get adminUnverified => 'sin verificar';

  @override
  String get adminSetManually => 'Establecer manualmente';

  @override
  String adminDaemonPathFor(String name) {
    return 'Ruta del daemon para «$name»';
  }

  @override
  String get adminPathOnDaemonHost => 'Ruta en el host del daemon';

  @override
  String get adminVerifyAndSave => 'Verificar y guardar';

  @override
  String get adminVpathVerified => 'Verificado';

  @override
  String get adminVpathSavedUnverified => 'Guardado (sin verificar)';

  @override
  String get adminDownloadPathTemplates => 'Plantillas de ruta de descarga';

  @override
  String adminPathTemplateVars(String vars) {
    return 'Variables: $vars';
  }

  @override
  String get adminNoLibraries => 'Sin bibliotecas';

  @override
  String adminSuggestedTemplate(String template) {
    return 'Sugerido: $template';
  }

  @override
  String get adminTemplateSaved => 'Plantilla guardada';

  @override
  String get adminNoBackupDestinations => 'Sin destinos de copia de seguridad';

  @override
  String get adminBackupDestinationInfo =>
      'Añade un destino para replicar una biblioteca en otra carpeta.';

  @override
  String get adminAddDestination => 'Añadir destino';

  @override
  String get adminAddLibraryFirst => 'Añade primero una biblioteca';

  @override
  String get adminBackupQueue => 'Cola de copias de seguridad';

  @override
  String adminTasksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas en cola',
      one: '1 tarea en cola',
    );
    return '$_temp0';
  }

  @override
  String adminBackingUp(String library) {
    return 'Copiando: $library';
  }

  @override
  String get adminRunning => 'en ejecución';

  @override
  String adminBackupStats(int done, String total, String stats) {
    return '$done archivos$total$stats';
  }

  @override
  String get adminBackupDisabled => 'desactivado';

  @override
  String get adminDestination => 'Destino';

  @override
  String get adminTrigger => 'Activador';

  @override
  String adminDailyTriggerTime(String trigger, String hour) {
    return '$trigger a las $hour:00';
  }

  @override
  String get adminRetention => 'Retención';

  @override
  String adminRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get adminLastRun => 'Última ejecución';

  @override
  String adminLastRunStatus(String status, int files) {
    return '$status · $files copiados';
  }

  @override
  String get adminRunNow => 'Ejecutar ahora';

  @override
  String get adminBackupQueued => 'Copia de seguridad en cola';

  @override
  String get adminAlreadyRunningSkipped => 'Ya en ejecución — omitido';

  @override
  String get adminHistory => 'Historial';

  @override
  String get adminEdit => 'Editar';

  @override
  String get adminDestinationDeleted => 'Destino eliminado';

  @override
  String get adminBackupHistory => 'Historial de copias de seguridad';

  @override
  String get adminNoHistoryYet => 'Aún no hay historial';

  @override
  String get adminEditDestination => 'Editar destino';

  @override
  String get adminAddBackupDestination =>
      'Añadir destino de copia de seguridad';

  @override
  String get adminDestinationPath => 'Ruta del destino';

  @override
  String get adminBrowseServer => 'Explorar servidor';

  @override
  String get adminCheckPath => 'Comprobar ruta';

  @override
  String get adminTriggerField => 'Activador';

  @override
  String get adminAfterEachScan => 'Después de cada escaneo';

  @override
  String get adminDaily => 'Diario';

  @override
  String get adminManualOnly => 'Solo manual';

  @override
  String get adminRunAtHour => 'Ejecutar a la hora: ';

  @override
  String get adminRetentionFieldLabel => 'Retención (días, 0 = conservar todo)';

  @override
  String get adminEnabledToggle => 'Activado';

  @override
  String get adminDestinationUpdated => 'Destino actualizado';

  @override
  String get adminDestinationCreated => 'Destino creado';

  @override
  String get adminPickLibrary => 'Elige una biblioteca';

  @override
  String get adminPickDestinationPath => 'Elige una ruta de destino';

  @override
  String adminAboutTitle(String version) {
    return 'mStream v$version';
  }

  @override
  String get adminAboutPort => 'Puerto';

  @override
  String get adminSSL => 'SSL';

  @override
  String get adminUI => 'Interfaz';

  @override
  String get adminCompression => 'Compresión';

  @override
  String get adminTrustProxy => 'Confiar en proxy';

  @override
  String get adminYes => 'Sí';

  @override
  String get adminNo => 'No';

  @override
  String get adminSecretLast4 => 'Secreto (últimos 4)';

  @override
  String get adminUploads => 'Subidas';

  @override
  String get adminMakeDirs => 'Crear dirs.';

  @override
  String get adminFileModify => 'Modificar archivos';

  @override
  String get adminSynchronous => 'Synchronous';

  @override
  String get adminCacheSizeLabel => 'Tamaño de caché';

  @override
  String adminCacheSizeMb(int size) {
    return '$size MB';
  }

  @override
  String get adminFederationUnavailable => 'No disponible';

  @override
  String get adminFederationDescription =>
      'La federación se está reconstruyendo en torno al nuevo enfoque de copias de seguridad locales y actualmente no está disponible en el servidor. El endpoint permanece montado para que los clientes antiguos reciban un estado claro en lugar de un 404.';

  @override
  String get adminCheckStatus => 'Comprobar estado';

  @override
  String get adminAllowed => 'Permitido';

  @override
  String get adminBackupEnabled => 'activado';

  @override
  String get adminNotAvailable => 'No disponible';

  @override
  String get adminNotMapped => 'sin asignar';

  @override
  String get adminExpiryNever => 'nunca';

  @override
  String get adminUnknownUser => 'desconocido';
}
