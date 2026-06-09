// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get mainRemove => 'Убрать';

  @override
  String get playlistActionFailed =>
      'Не удалось сохранить плейлист — возможно, имя уже занято.';

  @override
  String get queueAddNext => 'Добавить следующим';

  @override
  String get queuePlayNow => 'Воспроизвести сейчас';

  @override
  String get queueAddToEnd => 'Добавить в конец очереди';

  @override
  String get shuffle => 'Перемешать';

  @override
  String get variousArtists => 'Разные исполнители';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get languageSystemDefault => 'Системный по умолчанию';

  @override
  String get settingsLanguageSubtitle =>
      'Язык интерфейса приложения. «Системный по умолчанию» следует за настройками устройства.';

  @override
  String couldNotOpen(String url) {
    return 'Не удалось открыть $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count треков',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
      zero: 'Нет треков',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Сбросить';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get tapAddToQueue => 'Добавить в очередь';

  @override
  String get tapPlayFromHere => 'Воспроизвести отсюда';

  @override
  String get tapAppendAndJump => 'Добавить и воспроизвести';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'Шейдеры';

  @override
  String get visualizerSourceSynthesized => 'Синтезированный';

  @override
  String get visualizerSourceReal => 'Реальный звук';

  @override
  String get downloadsTitle => 'Загрузки';

  @override
  String downloadProgress(String progress) {
    return 'прогресс: $progress%';
  }

  @override
  String get songInfoTitle => 'Сведения о треке';

  @override
  String get eqTitle => 'Эквалайзер';

  @override
  String get eqOnlyAndroid => 'Эквалайзер доступен только на Android.';

  @override
  String get eqNeedsPlayback =>
      'Запустите трек, чтобы настроить эквалайзер.\n\nНативный эквалайзер Android инициализируется вместе с аудиосессией, поэтому для считывания раскладки полос необходимо активное воспроизведение.';

  @override
  String eqInitFailed(String error) {
    return 'Не удалось инициализировать эквалайзер:\n$error';
  }

  @override
  String get eqNoBands =>
      'Аудиодрайвер этого устройства не сообщает о полосах эквалайзера.';

  @override
  String get eqEnabledOn => 'Включён — усиление применяется к воспроизведению';

  @override
  String get eqEnabledOff => 'Выключен — режим обхода';

  @override
  String get cancel => 'Отмена';

  @override
  String get continueLabel => 'Продолжить';

  @override
  String get openSettings => 'Открыть настройки';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSectionAppearance => 'Внешний вид';

  @override
  String get settingsSectionPlayback => 'Воспроизведение';

  @override
  String get settingsSectionBrowse => 'Обзор';

  @override
  String get settingsSectionAbout => 'О приложении';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get themeSubtitleVelvet =>
      'Тёмно-синий и фиолетовый — фирменная тёмная тема.';

  @override
  String get themeSubtitleDark => 'Нейтральная тёмная с янтарными акцентами.';

  @override
  String get themeSubtitleLight =>
      'Светлый фон с тёмной панелью приложения и янтарными акцентами — совпадает с прежней темой.';

  @override
  String get settingsTranscode => 'Перекодировать звук';

  @override
  String get settingsTranscodeSubtitle =>
      'Транслировать перекодированную копию с сервера (файлы меньше, старт немного медленнее). При выключении воспроизводятся исходные файлы.';

  @override
  String get transcodeTitle => 'Перекодирование';

  @override
  String get transcodeCodec => 'Кодек';

  @override
  String get transcodeBitrate => 'Битрейт';

  @override
  String get transcodeAuto => 'По умолчанию сервера';

  @override
  String get transcodeUnavailable =>
      'На этом сервере транскодирование не включено — его треки воспроизводятся в оригинальном качестве.';

  @override
  String get transcodeReloadQueue => 'Применить к текущей очереди';

  @override
  String get transcodeReloadQueueSubtitle =>
      'При изменении настроек транскодирования — включено: перезагрузить всю очередь сейчас (текущий трек ненадолго буферизуется); выключено: меняются только следующие треки, текущий доигрывает без изменений.';

  @override
  String get settingsTapBehavior => 'При нажатии на трек';

  @override
  String get tapSubtitleAddToQueue =>
      'Нажатие на трек добавляет его в очередь. Если очередь пуста, воспроизведение начнётся автоматически.';

  @override
  String get tapSubtitlePlayFromHere =>
      'Нажатие на трек заменяет очередь треками из текущего вида и начинает воспроизведение с выбранного трека.';

  @override
  String get tapSubtitleAppendAndJump =>
      'Нажатие на трек добавляет его в очередь и переключает воспроизведение на него, прерывая то, что играло.';

  @override
  String get settingsEqSubtitle =>
      'Настройте низкие, средние и высокие частоты. Только на Android.';

  @override
  String get settingsVisualizerEngine => 'Движок визуализации';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'Пресеты Milkdrop через projectM (по умолчанию). Более насыщенные эффекты, выше нагрузка на GPU.';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Фрагментные шейдеры в стиле Shadertoy. Легче и модульнее — добавляйте файлы .glsl в assets/shaders/, чтобы расширить каталог.';

  @override
  String get settingsVisualizerSource => 'Источник звука визуализации';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'По умолчанию. Визуализация реагирует только на тайминг воспроизведения — разрешение на микрофон не требуется.';

  @override
  String get visualizerSourceSubtitleReal =>
      'Визуализация реагирует на реальный аудиовыход. Требуется разрешение RECORD_AUDIO на Android.';

  @override
  String get settingsAlbumGrid => 'Альбомы сеткой';

  @override
  String get settingsAlbumGridSubtitle =>
      'Показывать альбомы сеткой карточек с обложками вместо обычного списка.';

  @override
  String get settingsFileMetadata =>
      'Читать метаданные треков в проводнике файлов';

  @override
  String get settingsFileMetadataSubtitle =>
      'Получать название, исполнителя и обложку для каждого трека при просмотре файлов сервера. При выключении показываются исходные имена файлов (быстрее для больших папок).';

  @override
  String get settingsLetterStrip => 'Порог буквенной прокрутки';

  @override
  String get settingsLetterStripSubtitle =>
      'Показывать полосу быстрой прокрутки A–Z, когда в списке столько элементов или больше. Ниже этого размера полоса скрывается, а длинные имена папок и файлов переносятся на несколько строк вместо обрезки. Установите 0, чтобы полоса показывалась всегда.';

  @override
  String get settingsReset => 'Сбросить к значениям по умолчанию';

  @override
  String get settingsResetSubtitle =>
      'Восстановить все настройки на этом экране к значениям по умолчанию. Серверы и загрузки не затрагиваются.';

  @override
  String get settingsResetDone =>
      'Настройки восстановлены к значениям по умолчанию';

  @override
  String get realAudioDialogTitle => 'Использовать реальный звук?';

  @override
  String get realAudioDialogBody =>
      'Режим реального звука считывает форму волны музыки, которую воспроизводит телефон, чтобы визуализация могла реагировать на неё. Для этого Android требует разрешение RECORD_AUDIO — приложение никуда не записывает и не отправляет звук. Вы можете в любой момент вернуться к синтезированному режиму.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Разрешение отклонено навсегда. Включите его в системных настройках, чтобы использовать реальный звук.';

  @override
  String get realAudioPermDenied =>
      'Разрешение отклонено. Остаёмся на синтезированном звуке.';

  @override
  String get visualizerTapHint =>
      'Нажатие = следующий пресет · стрелка назад (вверху слева) или долгое нажатие для выхода';

  @override
  String get visualizerFailed => 'Не удалось запустить визуализацию';

  @override
  String get visualizerBringingUp => 'Запуск рендерера…';

  @override
  String get visualizerReady => 'Визуализация готова';

  @override
  String get visualizerBridgeFailed => 'Не удалось запустить мост';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Источник звука: $source';
  }

  @override
  String get visualizerTapToClose => 'Нажмите в любом месте, чтобы закрыть';

  @override
  String get visualizerUnsupported =>
      'Визуализация сейчас поддерживается только на Android.';

  @override
  String get aboutTitle => 'О приложении';

  @override
  String aboutBuiltBy(String name) {
    return 'Разработано $name';
  }

  @override
  String get linkDiscordSubtitle => 'Чат сообщества';

  @override
  String get linkGithubSubtitle => 'Исходный код сервера mStream';

  @override
  String get linkHomepageSubtitle => 'Домашняя страница проекта';

  @override
  String get aboutAttributions => 'Упоминания';

  @override
  String get aboutAttributionsSubtitle =>
      'Лицензия, упоминания авторов шейдеров и уведомления об открытом исходном коде.';

  @override
  String get ok => 'ОК';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Изменить';

  @override
  String get info => 'Сведения';

  @override
  String get makeDefault => 'Сделать основным';

  @override
  String get goBack => 'Назад';

  @override
  String get play => 'Воспроизвести';

  @override
  String get playAll => 'Воспроизвести всё';

  @override
  String get rename => 'Переименовать';

  @override
  String get create => 'Создать';

  @override
  String get copy => 'Копировать';

  @override
  String get done => 'Готово';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get attributionsTitle => 'Упоминания';

  @override
  String get attributionsSectionLicense => 'Лицензия';

  @override
  String get attributionsSectionShaders => 'Шейдеры визуализации';

  @override
  String get attributionsSectionLibraries => 'Нативные библиотеки';

  @override
  String get attributionsSectionEverythingElse => 'Всё остальное';

  @override
  String get attributionsLicenseBody =>
      'Свободное программное обеспечение под лицензией GNU General Public License v3.0. Вы можете использовать, изучать, распространять и изменять его на этих условиях.';

  @override
  String get attributionsPackages =>
      'Лицензии пакетов с открытым исходным кодом';

  @override
  String get attributionsPackagesSubtitle =>
      'Полные тексты лицензий для всех включённых пакетов Flutter/Dart.';

  @override
  String get manageServersTitle => 'Управление серверами';

  @override
  String get manageServerInfo => 'Сведения о сервере';

  @override
  String get manageServerDownloadFolder => 'Папка загрузок:';

  @override
  String get manageServerCopyPath => 'Копировать путь загрузки';

  @override
  String get manageServerPathCopied => 'Путь скопирован в буфер обмена';

  @override
  String get confirmRemoveServerTitle => 'Подтвердите удаление сервера';

  @override
  String get removeSyncedFiles =>
      'Удалить синхронизированные файлы с устройства?';

  @override
  String get playlistsTitle => 'Плейлисты';

  @override
  String get playlistsNew => 'Новый плейлист';

  @override
  String get playlistsEmptyTitle => 'Плейлистов пока нет';

  @override
  String get playlistsEmptyBody =>
      'Создайте плейлист кнопкой «Новый плейлист», затем заполните его свайпом «Добавить в плейлист» в очереди.';

  @override
  String get playlistNameHint => 'Название';

  @override
  String get playlistsRename => 'Переименовать плейлист';

  @override
  String get playlistFallbackTitle => 'Плейлист';

  @override
  String get playlistEmptyDetail =>
      'Плейлист пуст.\nДобавляйте треки через очередь.';

  @override
  String get shareEmptyTitle => 'Очередь пуста';

  @override
  String get shareEmptyBody =>
      'Добавьте треки в очередь перед тем, как делиться.';

  @override
  String get shareBlockedTitle => 'Не удаётся поделиться этой очередью';

  @override
  String get shareLocalOnlyBody =>
      'В очереди есть треки, которые находятся только на этом устройстве (ни на одном сервере). Поделиться можно, только когда все треки в очереди с одного сервера.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'В очереди смешаны треки с $count серверов ($names). Поделиться можно, только когда все треки с одного сервера.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'Сервера «$name» больше нет в вашем списке серверов. Добавьте его снова, чтобы поделиться его очередью.';
  }

  @override
  String get shareTitle => 'Поделиться плейлистом';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count треков',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
    );
    return '$_temp0 с $url';
  }

  @override
  String get shareLinkExpires => 'Срок действия ссылки';

  @override
  String get shareExpireNever => 'Никогда';

  @override
  String get shareExpire1Day => 'Через 1 день';

  @override
  String get shareExpire7Days => 'Через 7 дней';

  @override
  String get shareExpire30Days => 'Через 30 дней';

  @override
  String get shareAction => 'Поделиться';

  @override
  String get shareDoneTitle => 'Плейлист отправлен';

  @override
  String get shareDoneBody =>
      'Любой, у кого есть эта ссылка, может воспроизвести очередь:';

  @override
  String get save => 'Сохранить';

  @override
  String get start => 'Запустить';

  @override
  String get addServerTitle => 'Добавить сервер';

  @override
  String get editServerTitle => 'Изменить сервер';

  @override
  String get fieldServerUrl => 'URL сервера';

  @override
  String get fieldPublicAccess => 'Публичный доступ';

  @override
  String get publicAccessSubtitle =>
      'Сервер общедоступен — имя пользователя и пароль не нужны.';

  @override
  String get fieldUsername => 'Имя пользователя';

  @override
  String get fieldPassword => 'Пароль';

  @override
  String get fieldSdCard => 'Загружать на SD-карту';

  @override
  String get sdCardSubtitle =>
      'Сохранять загруженную музыку на съёмную SD-карту вместо внутреннего хранилища.';

  @override
  String get testConnectionButton => 'Проверить подключение';

  @override
  String get testing => 'Проверка…';

  @override
  String get connecting => 'Подключение…';

  @override
  String get validatorUrlNeeded => 'Требуется URL сервера';

  @override
  String get validatorUrlParse => 'Не удаётся разобрать URL';

  @override
  String get testEnterUrl => 'Сначала введите URL сервера.';

  @override
  String get testParseUrl => 'Не удалось разобрать URL.';

  @override
  String get testCouldNotConnect =>
      'Не удалось подключиться. Проверьте URL и повторите попытку.';

  @override
  String get testTimedOut => 'Время ожидания подключения истекло.';

  @override
  String get connectFailedSnack =>
      'Не удалось подключиться к серверу. Проверьте URL и повторите попытку.';

  @override
  String get connectionSuccessful => 'Подключение установлено!';

  @override
  String get couldNotReachServer =>
      'Не удалось связаться с сервером. Если требуется вход, отключите «Публичный доступ» и добавьте учётные данные.';

  @override
  String get failedToLogin => 'Не удалось войти';

  @override
  String testConnected(String version) {
    return 'Подключено — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'Не удалось подключиться: $error';
  }

  @override
  String get sleepTimerTitle => 'Таймер сна';

  @override
  String get sleepTimerHint =>
      'Выберите интервал, после которого приостановить воспроизведение.';

  @override
  String get sleepTimerCustom => 'Свой';

  @override
  String get sleepTimerCustomHint => 'минуты (1–600)';

  @override
  String get sleepTimerCancel => 'Отменить таймер';

  @override
  String get sleepTimerInvalid => 'Введите число от 1 до 600 минут';

  @override
  String sleepTimerPausesIn(String time) {
    return 'Пауза через $time';
  }

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String sleepTimerSet(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Таймер сна установлен на $minutes минут',
      many: 'Таймер сна установлен на $minutes минут',
      few: 'Таймер сна установлен на $minutes минуты',
      one: 'Таймер сна установлен на $minutes минуту',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Добавить';

  @override
  String get autoDjTitle => 'Авто-DJ';

  @override
  String get autoDjAddServerFirst => 'Сначала добавьте сервер.';

  @override
  String get autoDjSectionServer => 'Сервер';

  @override
  String get autoDjSectionSources => 'Источники';

  @override
  String get autoDjSectionContinuity => 'Непрерывность';

  @override
  String get autoDjSectionFilters => 'Фильтры';

  @override
  String get autoDjBpmTitle => 'Непрерывность по BPM';

  @override
  String get autoDjBpmSubtitle =>
      'Предпочитать выбор в пределах темпового окна текущего трека. Учитывает эквивалентность половинного/двойного темпа.';

  @override
  String get autoDjTolerance => 'Допуск';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Гармоническое сведение';

  @override
  String get autoDjHarmonicSubtitle =>
      'Предпочитать выбор в тональностях, хорошо сочетающихся с закреплённым треком (соседи по колесу Camelot).';

  @override
  String get autoDjStatusOn => 'Авто-DJ включён';

  @override
  String get autoDjStatusOff => 'Авто-DJ выключен';

  @override
  String get autoDjStatusOffDetail =>
      'Нажмите ниже, чтобы запустить. Будет использована библиотека текущего сервера.';

  @override
  String get autoDjStart => 'Запустить Авто-DJ';

  @override
  String get autoDjStop => 'Остановить Авто-DJ';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'Треки выбираются из $url, когда очередь подходит к концу.';
  }

  @override
  String get autoDjActiveSource => 'Активный источник';

  @override
  String get autoDjActiveSourceTap =>
      'Активный источник — нажмите, чтобы сменить';

  @override
  String get autoDjSwitch => 'Сменить';

  @override
  String get autoDjOneSourceRequired => 'Требуется хотя бы один источник.';

  @override
  String get autoDjMinRating => 'Минимальная оценка';

  @override
  String get autoDjMinRatingSubtitle =>
      'Выбирать только треки с этой оценкой или выше.';

  @override
  String get autoDjRatingAny => 'Любая';

  @override
  String get autoDjGenreTitle => 'Фильтр по жанрам';

  @override
  String get autoDjGenreSubtitle =>
      'Белый список воспроизводит только подходящие треки; чёрный список пропускает их.';

  @override
  String get autoDjWhitelist => 'Белый список';

  @override
  String get autoDjBlacklist => 'Чёрный список';

  @override
  String get autoDjNoGenres =>
      'Жанры не выбраны. Нажмите «Выбрать жанры», чтобы выбрать.';

  @override
  String get autoDjPickGenres => 'Выбрать жанры';

  @override
  String get autoDjGenreLoadError => 'Не удалось загрузить жанры';

  @override
  String get autoDjKeywordTitle => 'Фильтр по ключевым словам';

  @override
  String get autoDjKeywordSubtitle =>
      'Пропускать выбор, в названии, исполнителе, альбоме или пути к файлу которого есть любое из этих слов.';

  @override
  String get autoDjNoKeywords =>
      'Ключевых слов нет. Добавьте слова ниже, чтобы начать фильтрацию.';

  @override
  String get autoDjKeywordHint => 'например, «live» или «remix»';

  @override
  String get autoDjSearchGenres => 'Поиск жанров…';

  @override
  String get autoDjNoGenresOnServer => 'На этом сервере жанры не найдены.';

  @override
  String autoDjSelectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return 'Нет жанров по запросу «$query».';
  }

  @override
  String get download => 'Скачать';

  @override
  String get addAll => 'Добавить всё';

  @override
  String get browserConfirmDeletePlaylist => 'Подтвердите удаление плейлиста';

  @override
  String get browserConfirmDeleteFolder => 'Подтвердите удаление папки';

  @override
  String get browserSearchHint => 'Поиск в базе данных';

  @override
  String browserDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Начато $count загрузок',
      many: 'Начато $count загрузок',
      few: 'Начато $count загрузки',
      one: 'Начата $count загрузка',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count треков добавлено в очередь',
      many: '$count треков добавлено в очередь',
      few: '$count трека добавлено в очередь',
      one: '$count трек добавлен в очередь',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Обзор';

  @override
  String get tabQueue => 'Очередь';

  @override
  String get drawerTagline => 'Личный стриминг музыки';

  @override
  String get mainFailedToConnect => 'Не удалось подключиться к серверу';

  @override
  String get mainQueueEmpty => 'Очередь пуста';

  @override
  String get visualizerTitle => 'Визуализация';

  @override
  String get mainClearQueue => 'Очистить очередь';

  @override
  String get mainSync => 'Синхронизировать';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count треков в очереди',
      many: '$count треков в очереди',
      few: '$count трека в очереди',
      one: '$count трек в очереди',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Авто-DJ включён';

  @override
  String get autoDjDisabled => 'Авто-DJ выключен';

  @override
  String autoDjEnabledFor(String url) {
    return 'Авто-DJ включён для $url';
  }

  @override
  String get addToPlaylistTitle => 'Добавить в плейлист';

  @override
  String get addToPlaylistEmpty =>
      'Плейлистов пока нет — нажмите +, чтобы создать.';

  @override
  String addedToPlaylist(String name) {
    return 'Добавлено в $name';
  }

  @override
  String get testConnectedSignedIn => 'Подключено — вход выполнен успешно.';

  @override
  String get testSignInFailed =>
      'Сервер доступен, но вход не удался — проверьте имя пользователя и пароль.';

  @override
  String get browserFileExplorer => 'Проводник файлов';

  @override
  String get browserLocalFiles => 'Локальные файлы';

  @override
  String get browserPlaylists => 'Плейлисты';

  @override
  String get browserAlbums => 'Альбомы';

  @override
  String get browserArtists => 'Исполнители';

  @override
  String get browserRecent => 'Недавние';

  @override
  String get browserRated => 'С оценкой';

  @override
  String get browserSearch => 'Поиск';

  @override
  String get browserWelcomeTitle => 'Добро пожаловать в mStream';

  @override
  String get browserWelcomeSubtitle => 'Нажмите здесь, чтобы добавить сервер';

  @override
  String get settingsVisualizerKnobs => 'Регуляторы настройки визуализации';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      'Показывать живые ползунки поверх визуализации для подстройки реактивности звука каждого шейдера. Только для движка шейдеров.';

  @override
  String get visualizerTuningTitle => 'Настройка';

  @override
  String get close => 'Закрыть';

  @override
  String get migMoveStopped =>
      'Перемещение остановлено — недостаточно места или расположение недоступно.';

  @override
  String get migMoveComplete => 'Перемещение завершено';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Перемещение завершено — пропущено $count файлов (не поддерживаются в месте назначения)',
      many:
          'Перемещение завершено — пропущено $count файлов (не поддерживаются в месте назначения)',
      few:
          'Перемещение завершено — пропущено $count файла (не поддерживаются в месте назначения)',
      one:
          'Перемещение завершено — пропущен $count файл (не поддерживается в месте назначения)',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'Перемещение загрузок… $progress — не закрывайте приложение';
  }

  @override
  String get migRetry => 'Повторить';

  @override
  String get queueDownloadAll => 'Скачать всё';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Для воспроизведения офлайн будет скачано $count треков.',
      many: 'Для воспроизведения офлайн будет скачано $count треков.',
      few: 'Для воспроизведения офлайн будет скачано $count трека.',
      one: 'Для воспроизведения офлайн будет скачан $count трек.',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'Ещё';

  @override
  String get commonOn => 'Вкл.';

  @override
  String get commonOff => 'Выкл.';

  @override
  String get settingsCastQuality => 'Качество визуализации при трансляции';

  @override
  String get settingsCastQualitySubtitle720 =>
      'Разрешение, в котором визуализация транслируется на ТВ. 720p — наименьшая нагрузка на телефон.';

  @override
  String get settingsCastQualitySubtitle1080 =>
      'Разрешение, в котором визуализация транслируется на ТВ. 1080p — чётко на любом Chromecast (по умолчанию).';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Разрешение, в котором визуализация транслируется на ТВ. 4K — нужен Chromecast с поддержкой 4K; гораздо большая нагрузка на телефон.';

  @override
  String get eqCasting =>
      'Эквалайзер регулирует звук на этом устройстве, поэтому он недоступен во время трансляции. Отключитесь, чтобы использовать его.';

  @override
  String get browserNothingToDownload => 'В этом списке нечего скачивать';

  @override
  String get browserDownloadAllTitle => 'Скачать всё';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Будет скачано $count файлов.',
      many: 'Будет скачано $count файлов.',
      few: 'Будет скачано $count файла.',
      one: 'Будет скачан $count файл.',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => 'Закрыть поиск';

  @override
  String get browserSearchThisList => 'Поиск в этом списке';

  @override
  String get browserSearchList => 'Поиск в списке';

  @override
  String browserNoMatches(String query) {
    return 'Нет совпадений по запросу «$query»';
  }

  @override
  String get clear => 'Очистить';

  @override
  String get dlLocationUnavailable => 'Расположение загрузки недоступно';

  @override
  String get dlLocationUnavailableServer =>
      'Расположение загрузки недоступно для этого сервера.';

  @override
  String get dlFailed => 'Загрузка не удалась — проверьте подключение.';

  @override
  String get dlFatSkip =>
      'Некоторые треки нельзя сохранить на этой карте — их имена не поддерживаются. Вместо этого они транслируются.';

  @override
  String get dlServerGone => 'Этот сервер больше не настроен.';

  @override
  String get dlStorageUnavailable =>
      'Расположение хранилища недоступно — переподключите SD-карту или измените расположение хранилища этого сервера в разделе «Изменить сервер».';

  @override
  String get dlCouldNotStart =>
      'Не удалось начать загрузку — хранилище недоступно.';

  @override
  String get storageLocationLabel => 'Расположение хранилища';

  @override
  String get storageAppLocal => 'Локально в приложении';

  @override
  String get storagePermanent => 'Постоянное';

  @override
  String get storageSdCard => 'SD-карта';

  @override
  String get storageHelpAppLocal =>
      'Сохраняется внутри приложения. Удаляется при удалении приложения или очистке его данных.';

  @override
  String get storageHelpPermanent =>
      'Сохраняется в выбранную вами папку. Сохраняется при удалении приложения. Требуется «Доступ ко всем файлам».';

  @override
  String get storageHelpSdCard =>
      'Сохраняется в выбранную вами папку на SD-карте. Может стать недоступным, если карту извлечь. Некоторые устройства не позволяют приложениям записывать на SD-карты — если выбор папки постоянно не удаётся, используйте «Постоянное» или «Локально в приложении».';

  @override
  String get storageChooseFolder => 'Выбрать папку';

  @override
  String get storageNoFolderChosen => 'Папка ещё не выбрана';

  @override
  String get storageDownloadFolderLabel => 'Папка загрузок';

  @override
  String get storageDownloadFolderHint => 'имя папки';

  @override
  String get storageBrowse => 'Обзор';

  @override
  String get storageDownloadFolderHelp =>
      'Файлы скачиваются в каталог «media/<folder>» на этом устройстве. Повторное использование папки прежнего сервера сохраняет его скачанные треки при повторном добавлении утраченного сервера.';

  @override
  String get storageNoStorageAvailable => 'Хранилище недоступно';

  @override
  String get storageNoDownloadFolders =>
      'Существующие папки загрузок не найдены';

  @override
  String get storageExistingFolders => 'Существующие папки загрузок';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элементов',
      many: '$count элементов',
      few: '$count элемента',
      one: '$count элемент',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'Предоставьте «Доступ ко всем файлам», чтобы хранить загрузки постоянно, затем снова выберите режим.';

  @override
  String get storageSettings => 'Настройки';

  @override
  String get storageNoVolume => 'Не удалось найти том хранилища';

  @override
  String get storageNotWritable =>
      'В эту папку нельзя записывать — выберите другую.';

  @override
  String get storageNewFolder => 'Новая папка';

  @override
  String get storageFolderNameHint => 'Имя папки';

  @override
  String get storageCouldNotCreateFolder => 'Не удалось создать папку';

  @override
  String get storageNoSubfolders => 'Здесь нет вложенных папок';

  @override
  String get storageUseThisFolder => 'Использовать эту папку';

  @override
  String get storageMovedToNewFolder =>
      'Скачанные файлы перемещены в новую папку.';

  @override
  String get storageMoveAlreadyRunning =>
      'Перемещение уже выполняется — дайте ему сначала завершиться.';

  @override
  String get storageMigrateTitle => 'Другой том хранилища';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count скачанных файлов этого сервера ($size) находятся на другом томе хранилища, чем новое расположение. Выберите, что делать:',
      many:
          '$count скачанных файлов этого сервера ($size) находятся на другом томе хранилища, чем новое расположение. Выберите, что делать:',
      few:
          '$count скачанных файла этого сервера ($size) находятся на другом томе хранилища, чем новое расположение. Выберите, что делать:',
      one:
          '$count скачанный файл этого сервера ($size) находится на другом томе хранилища, чем новое расположение. Выберите, что делать:',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return 'Недостаточно свободного места в месте назначения (свободно $free). Перемещение может прерваться на середине — сначала освободите место.';
  }

  @override
  String get storageMigrateMove => 'Переместить их';

  @override
  String get storageMigrateMoveBody =>
      'Копировать в новое расположение в фоне, удаляя каждую старую копию по мере перемещения. Не закрывайте приложение, пока не завершится.';

  @override
  String get storageMigrateLeave => 'Оставить их';

  @override
  String get storageMigrateLeaveBody =>
      'Переключиться сейчас; старые загрузки останутся на месте и будут скачаны заново в новом расположении.';

  @override
  String get storageMigrateDelete => 'Удалить старые загрузки';

  @override
  String get storageMigrateDeleteBody =>
      'Переключиться сейчас и удалить старые файлы; они будут скачаны заново в новом расположении.';

  @override
  String get storageMovingBackground =>
      'Перемещение ваших загрузок в фоне — не закрывайте приложение.';

  @override
  String get storageChooseFolderFirst => 'Сначала выберите папку загрузок.';

  @override
  String get storageChooseSdFolderFirst =>
      'Сначала выберите папку на SD-карте. Если отклоняются все папки, возможно, ваше устройство не позволяет приложениям записывать на карту — используйте «Постоянное» или «Локально в приложении».';

  @override
  String get castPlayOn => 'Воспроизвести на';

  @override
  String get castPlayOnTooltip => 'Воспроизвести на…';

  @override
  String get castSearching => 'Поиск устройств для трансляции…';

  @override
  String get castNotSeeing =>
      'Не видите своё устройство? Убедитесь, что оно в той же сети Wi-Fi.';

  @override
  String get castVisualizer => 'Транслировать визуализацию';

  @override
  String get castVisualizerSubtitle =>
      'Транслировать визуализацию на ТВ · только Chromecast';

  @override
  String get visualizerNoKnobs => 'Этот шейдер не предоставляет регуляторов.';

  @override
  String get nowPlaying => 'Сейчас играет';

  @override
  String get playerLayoutSmall => 'Маленький';

  @override
  String get playerLayoutMedium => 'Средний';

  @override
  String get playerLayoutLarge => 'Большой';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => 'Тонкая панель — максимум очереди';

  @override
  String get playerLayoutMediumDesc =>
      'Баннер — сбалансированный (по умолчанию)';

  @override
  String get playerLayoutLargeDesc => 'Компактный — обложка по центру';

  @override
  String get playerLayoutXlDesc => 'Крупный — полная обложка';

  @override
  String get queueNothingToDownloadEmpty => 'Очередь пуста — нечего скачивать';

  @override
  String get queueNothingToDownloadSaved =>
      'Нечего скачивать — треки уже сохранены';

  @override
  String get settingsAccentColor => 'Акцентный цвет';

  @override
  String get settingsAccentColorSubtitle =>
      'Цвет выделения, используемый во всём приложении.';

  @override
  String get accentThemeDefault => 'Из темы';

  @override
  String get accentCustom => 'Свой';

  @override
  String get settingsResumeQueue => 'Восстанавливать очередь при запуске';

  @override
  String get settingsResumeQueueSubtitle =>
      'Сохраняет очередь воспроизведения и позицию и восстанавливает их при повторном открытии приложения.';

  @override
  String get diagnosticsTitle => 'Диагностика';

  @override
  String get diagnosticsEnable => 'Включить журналирование';

  @override
  String get diagnosticsHint =>
      'Журналы хранятся на вашем устройстве. Токены скрываются перед копированием или отправкой.';

  @override
  String get diagnosticsCopy => 'Копировать';

  @override
  String get diagnosticsShare => 'Поделиться';

  @override
  String get diagnosticsClear => 'Очистить';

  @override
  String get diagnosticsCopied => 'Журналы скопированы в буфер обмена';

  @override
  String get diagnosticsEmpty => 'Журналов пока нет';
}
