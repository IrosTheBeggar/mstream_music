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
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsEmpty => 'No lyrics found for this song';

  @override
  String get lyricsError => 'Couldn\'t load lyrics';

  @override
  String get lyricsRetry => 'Retry';

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
  String get eqDisabledHint => 'Activa el ecualizador para ajustar las bandas.';

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
  String get settingsLetterStripSide => 'Lado del deslizador';

  @override
  String get settingsLetterStripSideSubtitle =>
      'En qué borde se sitúa la barra A–Z.';

  @override
  String get settingsLetterStripLeft => 'Izquierda';

  @override
  String get settingsLetterStripRight => 'Derecha';

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
  String get aboutSponsor => 'Patrocinar mStream';

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
  String get testTimedOut => 'Se agotó el tiempo de conexión.';

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
  String get autoDjDurationTitle => 'Duración de la pista';

  @override
  String get autoDjDurationSubtitle =>
      'Omite interludios y mezclas largas eligiendo solo pistas dentro de un rango de duración';

  @override
  String get autoDjDurationRange => 'Duración';

  @override
  String get autoDjDurationAny => 'Cualquier duración';

  @override
  String autoDjDurationOver(String min) {
    return 'Más de $min';
  }

  @override
  String autoDjDurationUnder(String max) {
    return 'Menos de $max';
  }

  @override
  String autoDjDurationBetween(String min, String max) {
    return 'De $min a $max';
  }

  @override
  String get autoDjDurationAllowUnknown =>
      'Incluir pistas de duración desconocida';

  @override
  String get autoDjDurationAllowUnknownSub =>
      'Las pistas cuya duración tu servidor no ha leído se omiten en caso contrario';

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
  String get browserMoreActions => 'Más acciones';

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
      other: '$count pistas',
      one: '1 pista',
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
  String get storageSdSwitchTitle => 'Save to SD card';

  @override
  String get storageSdSwitchSubtitle =>
      'Stored in the SD card\'s app folder — no permission needed, but removed if you uninstall the app.';

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
  String get lanOnYourNetwork => 'Servidores en tu red local';

  @override
  String get lanSearching => 'Buscando servidores…';

  @override
  String get lanRefresh => 'Actualizar';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return 'Inicia sesión en $name';
  }

  @override
  String get lanUnreachable =>
      'No se pudo contactar con este servidor en la red.';

  @override
  String get lanNoCode =>
      'Quick Connect está activado en este servidor, pero no compartió un código de emparejamiento. Inicia sesión como administrador o pide al operador que active el uso compartido del código.';

  @override
  String get settingsResumeQueue => 'Reanudar la cola al iniciar';

  @override
  String get settingsResumeQueueSubtitle =>
      'Guarda la cola de reproducción y tu posición y las restaura al volver a abrir la app.';

  @override
  String get settingsOfflineQueue => 'Mantener la cola disponible sin conexión';

  @override
  String get settingsOfflineQueueSubtitle =>
      'Descarga automáticamente las pistas de la cola en este dispositivo para que la reproducción sobreviva a la pérdida de conexión.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Descargar solo con Wi-Fi';

  @override
  String get settingsOfflineQueueWifiOnlySubtitle =>
      'Espera a tener Wi-Fi antes de descargar las pistas de la cola.';

  @override
  String get settingsAutoDownloadCap => 'Auto-download limit';

  @override
  String get settingsAutoDownloadCapSubtitle =>
      'Guarda esta cantidad de canciones por delante de la actual; las que quedan atrás se eliminan.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Guarda toda la cola (sin límite).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unlimited';

  @override
  String get settingsAutoDownloadCapField => 'Number of tracks';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Cuántas canciones de la cola se mantienen descargadas, contando desde la que suena. A medida que avanza la reproducción, las que quedan atrás se eliminan. 0 para toda la cola.';

  @override
  String get downloadWaitingWifi => 'Esperando Wi-Fi';

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
  String get diagnosticsVerbose => 'Verbose logging';

  @override
  String get diagnosticsVerboseHint =>
      'Also logs high-frequency events like app focus changes. Only needed when diagnosing a playback issue.';

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
  String get storageAppSdCard => 'Tarjeta SD de la app';

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
  String get discoverTitle => 'Descubrir';

  @override
  String get discoverMatchedBySound => 'Coincidencias por sonido';

  @override
  String get discoverSimilarTracks => 'Canciones similares';

  @override
  String get discoverSimilarArtists => 'Artistas similares';

  @override
  String get discoverFromNetwork => 'De la red';

  @override
  String get discoverFromPeers => 'De tus pares';

  @override
  String get discoverQueueAll => 'Añadir todo a la cola';

  @override
  String get discoverNewArtistsOnly => 'Solo artistas nuevos';

  @override
  String get discoverNotAnalyzed =>
      'Esta canción aún no se ha analizado — las canciones similares aparecerán cuando el análisis de descubrimiento la procese.';

  @override
  String get discoverScanPendingTitle => 'Aún no hay nada analizado';

  @override
  String get discoverScanPendingBody =>
      'Este servidor tiene el descubrimiento activado, pero todavía no ha analizado ninguna música. Las canciones similares aparecerán cuando el análisis de descubrimiento se haya ejecutado.';

  @override
  String get discoverCheckAgain => 'Comprobar de nuevo';

  @override
  String get discoverTurnedOff =>
      'El descubrimiento se ha desactivado en este servidor.';

  @override
  String get pathScanPending =>
      'Este servidor todavía no ha analizado ninguna música, así que no hay nada por lo que trazar un recorrido. Funcionará cuando el análisis de descubrimiento se haya ejecutado.';

  @override
  String get discoverNothingFound => 'No se encontraron coincidencias.';

  @override
  String get discoverNoSeed =>
      'Reproduce una canción para descubrir música similar.';

  @override
  String get discoverLeadCopied => 'Copiado — ¡ve a buscarla!';

  @override
  String get discoverOpenMusicBrainz => 'Abrir en MusicBrainz';

  @override
  String get discoverNetworkWarmingUp =>
      'Aún no hay datos de la red — las bibliotecas de los pares se descargan en segundo plano cuando se detectan otros servidores.';

  @override
  String get discoverNetworkNothingNew =>
      'Nada nuevo para esta canción — la red no tiene coincidencias desconocidas.';

  @override
  String get discoverPeersUnreachable =>
      'Tus pares no respondieron — puede que estén desconectados ahora mismo.';

  @override
  String get discoverPeersNothingNew =>
      'Nada nuevo para esta canción en los servidores de tus pares.';

  @override
  String get autoDjSonicTitle => 'Similitud sonora';

  @override
  String get autoDjSonicSubtitle =>
      'Elige solo canciones que suenan como la sesión, usando el análisis de audio del servidor.';

  @override
  String get autoDjSonicUnavailable =>
      'Este servidor no tiene datos de descubrimiento — la selección seguirá siendo aleatoria.';

  @override
  String get autoDjSonicStrictness => 'Umbral de similitud';

  @override
  String autoDjSonicStrictnessValue(int pct) {
    return '$pct % o más parecido';
  }

  @override
  String get autoDjSonicSeedLabel => 'Canción semilla';

  @override
  String get autoDjSonicSeedNone =>
      'Sin semilla — la canción en reproducción ancla la sesión.';

  @override
  String get autoDjSonicSeedBanner =>
      'Elige la canción semilla — toca una pista en cualquier parte de la biblioteca';

  @override
  String get autoDjSonicSeedSearchHint => 'Buscar una canción…';

  @override
  String get autoDjSonicSeedRandom => 'Canción aleatoria';

  @override
  String get autoDjSonicSeedRemove => 'Quitar canción semilla';

  @override
  String get autoDjSonicSeedFailed =>
      'No se pudo obtener una canción del servidor.';

  @override
  String get autoDjSeedNoMatch =>
      'Ninguna canción coincide con tus filtros de Auto DJ; prueba a relajarlos';

  @override
  String get discoverFindSimilar => 'Buscar similares';

  @override
  String get discoverStartSession => 'Iniciar una sesión sonora';

  @override
  String get discoverStartSessionSubtitle =>
      'Música sin fin que suena como esta — reemplaza tu cola.';

  @override
  String get discoverStartSessionSubtitleRandom =>
      'Música sin fin desde una canción inicial aleatoria — reemplaza tu cola.';

  @override
  String get discoverSessionStarted =>
      'Sesión sonora iniciada — Auto DJ activado.';

  @override
  String get autoDjSonicAnchorLabel => 'Ancla';

  @override
  String get autoDjSonicAnchorRolling => 'Seguir el ambiente';

  @override
  String get autoDjSonicAnchorLocked => 'Mantener la semilla';

  @override
  String get autoDjSonicAnchorRollingHint =>
      'Cada canción sigue el sonido reciente de la sesión — puede evolucionar poco a poco.';

  @override
  String get autoDjSonicAnchorLockedHint =>
      'Cada canción se mantiene cerca de la canción semilla durante toda la sesión.';

  @override
  String get trackAddToPlaylist => 'Añadir a la lista de reproducción';

  @override
  String get trackAddToPlaylistFailed =>
      'No se pudo añadir a la lista de reproducción.';

  @override
  String get discoverPlayPathTo => 'Reproducir un camino hacia…';

  @override
  String get pathScreenTitle => 'Camino sonoro';

  @override
  String get pathStartNotAnalyzed =>
      'La canción inicial aún no se ha analizado — espera al análisis de descubrimiento o elige otra.';

  @override
  String get pathEndNotAnalyzed =>
      'La canción de destino aún no se ha analizado — espera al análisis de descubrimiento o elige otra.';

  @override
  String get pathStartSong => 'Canción inicial';

  @override
  String get pathEndSong => 'Canción final';

  @override
  String get pathLength => 'Longitud';

  @override
  String get pathRegenerate => 'Regenerar';

  @override
  String get pathSaveAsPlaylist => 'Guardar como lista';

  @override
  String get pathSetupHint =>
      'Elige una canción de inicio y una de destino — el viaje entre ellas se completa solo.';

  @override
  String get pathNotSet => 'Sin elegir';

  @override
  String get pathUsePlaying => 'Usar la canción actual';

  @override
  String get pathSearchSong => 'Buscar';

  @override
  String get pathBrowseLibrary => 'Explorar biblioteca';

  @override
  String get pathBuild => 'Crear el viaje';

  @override
  String get pathStartOver => 'Empezar de nuevo';

  @override
  String get pathPickBannerStart =>
      'Elige la canción de inicio — toca una pista en cualquier parte de la biblioteca';

  @override
  String get pathPickBannerEnd =>
      'Elige la canción de destino — toca una pista en cualquier parte de la biblioteca';

  @override
  String get pathNothingPlaying => 'No se está reproduciendo nada';

  @override
  String pathPickOnServer(String server) {
    return 'Elige una pista en $server';
  }

  @override
  String get welcomeTranslationNote =>
      'Este idioma se tradujo automáticamente y puede sonar raro.';

  @override
  String get welcomeTranslationCta => 'Ayuda a traducir mStream';

  @override
  String get setupTitle => 'Configuración rápida';

  @override
  String get setupSkip => 'Omitir';

  @override
  String get setupNext => 'Siguiente';

  @override
  String get setupFinish => 'Finalizar';

  @override
  String get setupBack => 'Atrás';

  @override
  String get setupAccentTitle => 'Elige tu color';

  @override
  String get setupAccentBody =>
      'El color de acento resalta botones, deslizadores y los controles del reproductor. Toca uno para probarlo.';

  @override
  String get setupVisualizerTitle => 'Audio real para el visualizador';

  @override
  String get setupVisualizerBody =>
      'El visualizador usa datos sintetizados hasta que actives esta opción.';

  @override
  String get setupVisualizerWarning =>
      'Activarlo pide el permiso de micrófono: Android lo exige a las apps que decodifican el flujo de audio del dispositivo (que es lo que hace el visualizador).';

  @override
  String get setupPlaybackTitle => 'Cuando tocas una canción';

  @override
  String get setupOfflineTitle => 'Mantén tu cola sin conexión';

  @override
  String get setupVisualizerNoMic => 'mStream nunca usa tu micrófono.';

  @override
  String get playlistEmpty => 'La lista está vacía';

  @override
  String get trackRating => 'Valoración';

  @override
  String albumDiscNumber(int n) {
    return 'Disco $n';
  }

  @override
  String get autoDjStartTitle => '¿Con qué empieza Auto DJ?';

  @override
  String get autoDjStartSubtitle =>
      'No hay nada en la cola, así que el DJ necesita una primera canción. Con cola, simplemente sigue lo que ya tienes.';

  @override
  String get autoDjStartRandom => 'Sorpréndeme';

  @override
  String get autoDjStartRandomSub =>
      'Elegir una canción al azar de la biblioteca y construir a partir de ahí.';

  @override
  String get autoDjStartPick => 'Déjame elegir';

  @override
  String get autoDjStartPickSub =>
      'Abrir la biblioteca y elegir tú la primera canción.';

  @override
  String get autoDjStartRemember => 'Recordar esto';

  @override
  String get autoDjStartRememberSub =>
      'Omitir esta pregunta la próxima vez y empezar siempre así.';

  @override
  String get autoDjStartPickBanner =>
      'Elige la primera canción — toca una pista en cualquier parte de la biblioteca';

  @override
  String get autoDjOnEmptyQueue => 'Con la cola vacía';

  @override
  String get autoDjOnEmptyQueueSub =>
      'Qué hace Auto DJ cuando lo activas sin nada en la cola.';

  @override
  String get autoDjStartAskShort => 'Preguntar';

  @override
  String serverVersionLabel(String version) {
    return 'Servidor v$version';
  }

  @override
  String get serverVersionUnknown => 'Versión del servidor desconocida';

  @override
  String get serverUpdateUrgent => 'Actualiza tu servidor';

  @override
  String get serverUpdateAvailable => 'Actualización de servidor disponible';

  @override
  String serverTooOldWarning(String version) {
    return 'Este servidor es la versión v$version. Algunas funciones requieren v5.5 o posterior y no estarán disponibles.';
  }

  @override
  String get autoDjNeedsNewerServer =>
      'La continuidad de BPM, la mezcla armónica y el filtro de géneros requieren un servidor más reciente. Actualiza para obtenerlos.';

  @override
  String get autoDjSonicNeedsNewerServer =>
      'Requiere servidor 6.15.2 o posterior';

  @override
  String get torrentScreenTitle => 'Añadir torrent';

  @override
  String get torrentNoServer => 'No hay ningún servidor configurado.';

  @override
  String get torrentServerLabel => 'Servidor';

  @override
  String get torrentLibraryLabel => 'Biblioteca';

  @override
  String get torrentNoLibraries => 'No hay bibliotecas en este servidor';

  @override
  String get torrentSourceLabel => 'Origen';

  @override
  String get torrentChooseFile => 'Elegir archivo .torrent';

  @override
  String get torrentOr => 'o';

  @override
  String get torrentMagnetLabel => 'Enlace magnet';

  @override
  String get torrentMagnetInvalid => 'Enlace magnet no válido';

  @override
  String torrentNotATorrent(String name) {
    return '«$name» no es un archivo .torrent';
  }

  @override
  String get torrentOpenWith => 'Abrir en otra aplicación';

  @override
  String get torrentOpenWithNone =>
      'Ninguna aplicación de este dispositivo puede abrir un archivo .torrent';

  @override
  String get torrentOpenWithFailed =>
      'No se pudo pasar el torrent a otra aplicación';

  @override
  String get torrentIntentTitle => 'Torrent recibido';

  @override
  String get torrentIntentBody =>
      'Añádelo a una biblioteca de tu servidor mStream o pásalo a otra aplicación.';

  @override
  String get torrentIntentAdd => 'Añadir a mStream';

  @override
  String get torrentIntentDontAsk =>
      'Añadir siempre a mStream, no volver a preguntar';

  @override
  String get settingsTorrentAskTitle => 'Preguntar qué hacer con los torrents';

  @override
  String get settingsTorrentAskSub =>
      'Cuando se abra un torrent con mStream, ofrecer pasarlo a otra aplicación';

  @override
  String get settingsTorrentDefaultTitle =>
      'Aplicación predeterminada para torrents';

  @override
  String get settingsTorrentDefaultSub =>
      'Abre los ajustes de Android, donde puedes elegir qué aplicación abre torrents y enlaces magnet';

  @override
  String get settingsTorrentDefaultFailed =>
      'No se pudieron abrir los ajustes de Android';

  @override
  String get torrentAutoDetect => 'Detectar metadatos';

  @override
  String get torrentDetecting => 'Detectando…';

  @override
  String get torrentDetectNoMetadata =>
      'Metadatos insuficientes — rellena los campos a mano';

  @override
  String get torrentDetected => 'Metadatos detectados';

  @override
  String get torrentDetectGuess =>
      'Estimación aproximada — verifica los campos';

  @override
  String get torrentMetadataLabel => 'Metadatos';

  @override
  String get torrentArtistLabel => 'Artista';

  @override
  String get torrentAlbumLabel => 'Álbum';

  @override
  String get torrentYearLabel => 'Año';

  @override
  String get torrentDestinationLabel => 'Destino';

  @override
  String get torrentPathLabel => 'Ruta en la biblioteca';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹sin biblioteca›/$path';
  }

  @override
  String get torrentPreviewContents => '‹contenido del torrent›';

  @override
  String get torrentRenameRoot => 'Renombrar la carpeta raíz del torrent';

  @override
  String get torrentRenameRootSub =>
      'Igualarla al nombre de la carpeta de destino';

  @override
  String get torrentForceFresh => 'Forzar descarga nueva';

  @override
  String get torrentForceFreshSub =>
      'No comprobar si los archivos ya están en el servidor';

  @override
  String get torrentSubmit => 'Añadir torrent';

  @override
  String get torrentSubmitting => 'Añadiendo…';

  @override
  String get torrentUnavailable =>
      'Los torrents no están disponibles en este servidor.';

  @override
  String get torrentPickLibrary => 'Elige una biblioteca';

  @override
  String get torrentOneSource =>
      'Añade un enlace magnet o un archivo .torrent (solo uno)';

  @override
  String get torrentPathEmpty => 'La ruta de destino está vacía';

  @override
  String get torrentSeeded => 'Ya está en el disco — sembrando ahora';

  @override
  String get torrentAlreadyInClient => 'Ya está en el cliente de torrents';

  @override
  String get torrentInvalidFile => 'Archivo torrent no válido';

  @override
  String get torrentSeedCheckFailed =>
      'No se pudo comprobar si hay archivos existentes — descargando de nuevo';

  @override
  String get torrentPartialTitle => 'Algunos archivos ya existen';

  @override
  String get torrentPartialBody =>
      'Apunta el torrent a una copia existente para sembrarla y descargar solo lo que falta.';

  @override
  String torrentPartialCount(String matched, String total) {
    return '$matched/$total archivos aquí';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · $missing por descargar';
  }

  @override
  String get torrentDownloadFresh => 'Descargar de nuevo igualmente';

  @override
  String get torrentMatchNoFolder =>
      'Esa coincidencia no tiene nombre de carpeta — usa \'Descargar de nuevo igualmente\'';

  @override
  String torrentAdded(String name) {
    return '\"$name\" añadido';
  }

  @override
  String torrentDuplicate(String name) {
    return '\"$name\" ya está en el cliente';
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
  String get adminLogBufferSize => 'Tamaño del búfer de registros';

  @override
  String get adminLogBufferSizeHelper => '0–10000, 0 = desactivado';

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
  String get adminTestConnection => 'Probar conexión';

  @override
  String get adminKeyNameLabel => 'Nombre / etiqueta de la clave';

  @override
  String get adminMintKey => 'Generar clave';

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
  String get adminFederationDescription =>
      'Empareja con otros servidores mStream: emite claves para que lean tus bibliotecas o añade sus tickets para leer las suyas.';

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

  @override
  String get adminFederationEnableTitle => 'Activar federación';

  @override
  String get adminFederationEnableSubtitle =>
      'Permite que este servidor se empareje con otros servidores mStream';

  @override
  String get adminFederationEndpointId => 'ID de endpoint';

  @override
  String get adminFederationRelay => 'Relé';

  @override
  String get adminFederationOnline => 'En línea';

  @override
  String get adminFederationOffline => 'Sin conexión';

  @override
  String get adminFederationStopped => 'Detenido';

  @override
  String get adminFederationUnsupportedTitle => 'No compatible aquí';

  @override
  String get adminFederationUnsupportedBody =>
      'Esta compilación no incluye un endpoint de federación para tu plataforma, así que no puede ejecutarse aquí.';

  @override
  String get adminFederationCopy => 'Copiar';

  @override
  String get adminFederationCopied => 'Copiado';

  @override
  String get adminFederationKeysTitle => 'Claves emitidas';

  @override
  String get adminFederationKeysSubtitle =>
      'Credenciales que otros servidores usan para leer de este';

  @override
  String get adminFederationNoKeys => 'Aún no hay claves emitidas';

  @override
  String get adminFederationMintTitle => 'Emitir una clave';

  @override
  String get adminFederationCopyTicket => 'Mostrar ticket';

  @override
  String get adminFederationTicketTitle => 'Ticket';

  @override
  String get adminFederationTicketBody =>
      'Entrégalo al administrador del otro servidor. Solo se muestra una vez.';

  @override
  String get adminFederationNoTicket =>
      'No hay ticket disponible para esta clave';

  @override
  String get adminFederationEditLimits => 'Editar límites';

  @override
  String get adminFederationLimitsTitle => 'Límites';

  @override
  String get adminFederationLimitsSaved => 'Límites guardados';

  @override
  String get adminFederationStreamKbps => 'Techo de flujo (kbps)';

  @override
  String get adminFederationDailyMb => 'Límite diario (MB)';

  @override
  String get adminFederationMaxStreams => 'Flujos simultáneos';

  @override
  String get adminFederationUnlimitedHint => '0 significa sin límite';

  @override
  String get adminFederationUnlimited => 'sin límite';

  @override
  String adminFederationKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String adminFederationMbPerDay(int mb) {
    return '$mb MB/día';
  }

  @override
  String adminFederationStreams(int count) {
    return '$count flujos';
  }

  @override
  String adminFederationUsageToday(String used) {
    return 'Hoy: $used';
  }

  @override
  String get adminFederationExpired => 'Caducada';

  @override
  String get adminFederationBound => 'vinculada';

  @override
  String get adminFederationUnbound => 'sin vincular';

  @override
  String get adminFederationResetBinding => 'Restablecer vínculo';

  @override
  String get adminFederationResetBindingDone => 'Vínculo restablecido';

  @override
  String get adminFederationRevoke => 'Revocar';

  @override
  String adminFederationRevokeTitle(String name) {
    return '¿Revocar $name?';
  }

  @override
  String get adminFederationRevokeBody =>
      'Los flujos que estén usando esta clave se cortarán de inmediato.';

  @override
  String get adminFederationRevoked => 'Clave revocada';

  @override
  String get adminFederationPeersTitle => 'Servidores que lees';

  @override
  String get adminFederationPeersSubtitle =>
      'Servidores que te dieron un ticket y de los que puedes leer';

  @override
  String get adminFederationNoPeers => 'Aún no se han añadido pares';

  @override
  String get adminFederationAddPeer => 'Añadir par';

  @override
  String get adminFederationAddPeerBody =>
      'Pega el ticket que te dio el otro servidor. Contiene su dirección y la clave de acceso.';

  @override
  String get adminFederationTicketLabel => 'Ticket';

  @override
  String get adminFederationPeerNameLabel => 'Nombre (opcional)';

  @override
  String get adminFederationPeerAdded => 'Par añadido';

  @override
  String get adminFederationPeerRemoved => 'Par eliminado';

  @override
  String adminFederationRemovePeerTitle(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get adminFederationTestOk => 'Par accesible';

  @override
  String adminFederationLastSeen(String when) {
    return 'Visto por última vez $when';
  }

  @override
  String get adminFederationNeverSeen => 'Nunca accesible';

  @override
  String get adminFederationUseDiscovery =>
      'Enviar consultas de descubrimiento';

  @override
  String get adminFederationUseDiscoverySubtitle =>
      'Comparte con este par lo que estás escuchando';
}
