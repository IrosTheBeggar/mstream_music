// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

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
  String get settingsTapBehavior => 'Al tocar una canción';

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
}
