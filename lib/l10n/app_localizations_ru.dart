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
  String get languageSystemDefault => 'Как в системе';

  @override
  String get settingsLanguageSubtitle =>
      'Язык интерфейса приложения. «Как в системе» повторяет язык устройства.';

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
  String get themeSlate => 'Сланец';

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
  String get lyricsTitle => 'Текст песни';

  @override
  String get lyricsEmpty => 'Текст для этого трека не найден';

  @override
  String get lyricsError => 'Не удалось загрузить текст';

  @override
  String get lyricsRetry => 'Повторить';

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
  String get eqDisabledHint => 'Включите эквалайзер, чтобы настроить полосы.';

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
  String get themeSubtitleSlate =>
      'Сине-серые тона в стиле веб-приложения с янтарными акцентами.';

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
  String get transcodeAuto => 'Как на сервере';

  @override
  String get transcodeUnavailable =>
      'На этом сервере перекодирование не включено — его треки воспроизводятся в оригинальном качестве.';

  @override
  String get transcodeReloadQueue => 'Применить к текущей очереди';

  @override
  String get transcodeReloadQueueSubtitle =>
      'При изменении настроек перекодирования — включено: перезагрузить всю очередь сейчас (текущий трек ненадолго буферизуется); выключено: меняются только следующие треки, текущий доигрывает без изменений.';

  @override
  String get settingsTapBehavior => 'При нажатии на трек';

  @override
  String get settingsStartupPage => 'Стартовый экран';

  @override
  String get settingsStartupPageSubtitle =>
      'Открывать приложение на этом разделе «Обзора»; «Назад» возвращает в «Обзор».';

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
  String get settingsLetterStripSide => 'Сторона полосы A–Z';

  @override
  String get settingsLetterStripSideSubtitle =>
      'У какого края находится полоса A–Z.';

  @override
  String get settingsLetterStripLeft => 'Слева';

  @override
  String get settingsLetterStripRight => 'Справа';

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
  String get visualizerClose => 'Закрыть визуализацию';

  @override
  String get visualizerPreviousPreset => 'Предыдущий пресет';

  @override
  String get visualizerNextPreset => 'Следующий пресет';

  @override
  String get visualizerUnsupported =>
      'Визуализация сейчас поддерживается только на Android.';

  @override
  String get aboutTitle => 'О приложении';

  @override
  String aboutBuiltBy(String name) {
    return 'Разработчик: $name';
  }

  @override
  String get linkDiscordSubtitle => 'Чат сообщества';

  @override
  String get linkGithubSubtitle => 'Исходный код сервера mStream';

  @override
  String get linkHomepageSubtitle => 'Домашняя страница проекта';

  @override
  String get aboutAttributions => 'Благодарности и лицензии';

  @override
  String get aboutAttributionsSubtitle =>
      'Лицензия, упоминания авторов шейдеров и уведомления об открытом исходном коде.';

  @override
  String get aboutSponsor => 'Поддержать mStream';

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
  String get attributionsTitle => 'Благодарности и лицензии';

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
  String get shareDoneTitle => 'Плейлист доступен по ссылке';

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
  String get fieldPasswordShow => 'Показать пароль';

  @override
  String get fieldPasswordHide => 'Скрыть пароль';

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
  String get testTimedOut => 'Время ожидания подключения истекло.';

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
  String get autoDjMultiServerTitle => 'Играть со всех серверов';

  @override
  String get autoDjMultiServerSubtitle =>
      'Авто-DJ выбирает сразу со всех серверов, подстраиваясь под звучание того, что играет';

  @override
  String get autoDjMultiServerNeedsSonic =>
      'Нужно включить «Похожее звучание» ниже';

  @override
  String get autoDjSectionShared => 'Сессия';

  @override
  String get autoDjSectionPerServer => 'Каждая библиотека';

  @override
  String get autoDjEditingServer => 'Настройки для';

  @override
  String autoDjMultiServerAllIn(int count) {
    return 'Участвуют серверов: $count';
  }

  @override
  String autoDjMultiServerConnecting(int count) {
    return 'Подключаются: $count';
  }

  @override
  String autoDjMultiServerSomeExcluded(int count, int total) {
    return 'Участвуют $count из $total серверов — у остальных нет подбора по звучанию, совпадающей модели эмбеддингов или достаточно новой версии сервера';
  }

  @override
  String get autoDjSectionQueue => 'Очередь';

  @override
  String get autoDjSongsPerFetchTitle => 'Треков за один запрос';

  @override
  String get autoDjSongsPerFetchSubtitle =>
      'Сколько треков Авто-DJ добавляет в очередь при каждом запуске. Фильтры непрерывности оценивают всю партию по треку, звучавшему в момент запроса.';

  @override
  String autoDjSongsPerFetchValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count трека',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
    );
    return '$_temp0';
  }

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
  String get autoDjDurationTitle => 'Длительность трека';

  @override
  String get autoDjDurationSubtitle =>
      'Пропускать интерлюдии и длинные миксы, выбирая только треки в заданном диапазоне длительности';

  @override
  String get autoDjDurationRange => 'Длительность';

  @override
  String get autoDjDurationAny => 'Любая длительность';

  @override
  String autoDjDurationOver(String min) {
    return 'Больше $min';
  }

  @override
  String autoDjDurationUnder(String max) {
    return 'Меньше $max';
  }

  @override
  String autoDjDurationBetween(String min, String max) {
    return 'От $min до $max';
  }

  @override
  String get autoDjDurationAllowUnknown =>
      'Включать треки неизвестной длительности';

  @override
  String get autoDjDurationAllowUnknownSub =>
      'Иначе треки, длительность которых сервер не определил, пропускаются';

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
      'Пропускать треки, у которых в названии, исполнителе, альбоме или пути к файлу встречается любое из этих слов.';

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
  String get browserMoreActions => 'Другие действия';

  @override
  String get browserConfirmDeletePlaylist => 'Подтвердите удаление плейлиста';

  @override
  String get browserConfirmDeleteFolder => 'Подтвердите удаление папки';

  @override
  String get browserSearchHint => 'Поиск в базе данных';

  @override
  String get searchCategoriesTooltip => 'Где искать';

  @override
  String get searchCategoriesHeader => 'Искать в';

  @override
  String get searchCategoryArtists => 'Исполнители';

  @override
  String get searchCategoryAlbums => 'Альбомы';

  @override
  String get searchCategorySongs => 'Треки';

  @override
  String get searchCategoryFiles => 'Файлы';

  @override
  String get searchCategoryLyrics => 'Тексты песен';

  @override
  String searchSubheaderResults(String term) {
    return 'Результаты по запросу «$term»';
  }

  @override
  String searchSubheaderCategories(String categories) {
    return 'Поиск в: $categories';
  }

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
      other: '$count треков',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
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
  String get browserSectionLibrary => 'Библиотека';

  @override
  String get browserSectionListen => 'Слушать';

  @override
  String get browserSectionNetwork => 'Сеть';

  @override
  String get browserSectionServer => 'Сервер';

  @override
  String get browserFederation => 'Федерация';

  @override
  String get browserAutoDjOn => 'Включён';

  @override
  String get browserAutoDjOff => 'Выключен';

  @override
  String browserSharedLibraries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count общих библиотек',
      many: '$count общих библиотек',
      few: '$count общие библиотеки',
      one: '$count общая библиотека',
    );
    return '$_temp0';
  }

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
      'Показывать живые ползунки поверх визуализации, чтобы подстраивать реакцию каждого шейдера на звук. Только для движка шейдеров.';

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
  String get browserEmptyList => 'Nothing here yet';

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
      'Некоторые треки нельзя сохранить на этой карте — их имена не поддерживаются. Вместо этого они будут воспроизводиться потоком с сервера.';

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
  String get storageSdSwitchTitle => 'Сохранять на SD-карту';

  @override
  String get storageSdSwitchSubtitle =>
      'Хранится в папке приложения на SD-карте — разрешение не нужно, но при удалении приложения файлы удаляются.';

  @override
  String get storageHelpAppLocal =>
      'Сохраняется внутри приложения. Удаляется при удалении приложения или очистке его данных.';

  @override
  String get storageHelpPermanent =>
      'Сохраняется в выбранную вами папку. Не удаляется при удалении приложения. Требуется «Доступ ко всем файлам».';

  @override
  String get storageHelpSdCard =>
      'Сохраняется в выбранную вами папку на SD-карте. Файлы могут стать недоступными, если извлечь карту. Некоторые устройства не позволяют приложениям записывать на SD-карты — если выбор папки постоянно не удаётся, используйте «Постоянное» или «Локально в приложении».';

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
  String get castThisDevice => 'Это устройство';

  @override
  String get visualizerNoKnobs => 'Этот шейдер не предоставляет регуляторов.';

  @override
  String get nowPlaying => 'Сейчас играет';

  @override
  String get settingsPlayerLayout => 'Макет экрана «Сейчас играет»';

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
  String get lanOnYourNetwork => 'Серверы в вашей локальной сети';

  @override
  String get lanSearching => 'Поиск серверов…';

  @override
  String get lanRefresh => 'Обновить';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return 'Вход на сервер $name';
  }

  @override
  String get lanUnreachable => 'Не удалось связаться с этим сервером по сети.';

  @override
  String get lanNoCode =>
      'Быстрое подключение включено на этом сервере, но код сопряжения не был опубликован. Войдите как администратор или попросите оператора включить публикацию кода.';

  @override
  String get settingsResumeQueue => 'Восстанавливать очередь при запуске';

  @override
  String get settingsResumeQueueSubtitle =>
      'Сохранять очередь воспроизведения и позицию в ней и восстанавливать их при повторном открытии приложения.';

  @override
  String get settingsOfflineQueue => 'Держать очередь доступной офлайн';

  @override
  String get settingsOfflineQueueSubtitle =>
      'Автоматически загружает треки из очереди на это устройство, чтобы воспроизведение продолжалось при потере соединения.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Загружать только по Wi-Fi';

  @override
  String get settingsOfflineQueueWifiOnlySubtitle =>
      'Ожидает подключения к Wi-Fi перед загрузкой треков из очереди.';

  @override
  String get settingsAutoDownloadCap => 'Лимит автозагрузки';

  @override
  String get settingsAutoDownloadCapSubtitle =>
      'Кэшировать столько треков начиная с текущего; пройденные удаляются по ходу.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Кэшировать всю очередь (без ограничений).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Без ограничений';

  @override
  String get settingsAutoDownloadCapField => 'Количество треков';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Сколько треков очереди остаются загруженными, начиная с текущего. По мере воспроизведения пройденные удаляются. 0 — вся очередь.';

  @override
  String get downloadWaitingWifi => 'Ожидание Wi-Fi';

  @override
  String get settingsRatingHalf => 'Оценки с шагом в ползвезды';

  @override
  String get settingsRatingHalfSubtitle =>
      'Оценивать треки с шагом в ползвезды (долгое нажатие на звезду).';

  @override
  String get ratingTitle => 'Оценить';

  @override
  String get ratingFailed => 'Не удалось сохранить оценку';

  @override
  String get diagnosticsTitle => 'Диагностика';

  @override
  String get diagnosticsEnable => 'Включить журналирование';

  @override
  String get diagnosticsHint =>
      'Журналы хранятся на вашем устройстве. Токены скрываются перед копированием или отправкой.';

  @override
  String get diagnosticsVerbose => 'Подробное журналирование';

  @override
  String get diagnosticsVerboseHint =>
      'Также записывает частые события, например смену фокуса приложения. Нужно только при диагностике проблем с воспроизведением.';

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

  @override
  String get storageAppExternal => 'Внешнее хранилище приложения';

  @override
  String get storageAppSdCard => 'SD-карта приложения';

  @override
  String get selfSignedTitle => 'Разрешить самоподписанный сертификат';

  @override
  String get selfSignedSubtitle =>
      'Пропускать проверку TLS для этого сервера. Включайте только в доверенной сети.';

  @override
  String get importedShadersTitle => 'Импортированные шейдеры';

  @override
  String get importedShadersSettingsSubtitle =>
      'Добавьте свои файлы .glsl в ротацию движка шейдеров.';

  @override
  String get importedShadersRescan => 'Пересканировать папку';

  @override
  String get importedShadersDropHint =>
      'Поместите файлы .glsl в эту папку, затем нажмите «Пересканировать»:';

  @override
  String get importedShadersCopyPath => 'Копировать путь';

  @override
  String get importedShadersReachableHint =>
      'Доступно по USB или через файловый менеджер (в Android/data). Импортированные шейдеры входят в ротацию, когда активен движок шейдеров.';

  @override
  String get importedShadersRemove => 'Удалить';

  @override
  String get importedShadersEmptyTitle => 'В папке пока нет шейдеров';

  @override
  String get importedShadersEmptyBody =>
      'Скопируйте файлы .glsl в стиле Shadertoy в папку выше, затем нажмите «Пересканировать».';

  @override
  String get importedShadersInvalid =>
      'Возможно, это нерабочий шейдер — нет точки входа mainImage/main.';

  @override
  String get importedShadersImportDownloads =>
      'Импортировать .glsl из «Загрузок»';

  @override
  String importedShadersDownloadsImported(int count) {
    return 'Импортировано шейдеров из «Загрузок»: $count';
  }

  @override
  String get importedShadersDownloadsNone =>
      'В «Загрузках» нет новых файлов .glsl';

  @override
  String get importedShadersDownloadsNoPermission =>
      'Для чтения «Загрузок» нужно разрешение на доступ к хранилищу';

  @override
  String get addServerTabUrl => 'URL сервера';

  @override
  String get addServerTabQuickConnect => 'Быстрое подключение';

  @override
  String get irohPairingHeader => 'Подключение по коду сопряжения';

  @override
  String get irohPairingBody =>
      'Включите «Remote Access» (удалённый доступ) на сервере, затем вставьте его код сопряжения или отсканируйте QR-код.';

  @override
  String get irohPairingCodeLabel => 'Код сопряжения';

  @override
  String get irohPairingCodeHint =>
      'Вставьте код из панели «Remote Access» сервера';

  @override
  String get irohShowPairingCode => 'Показать код сопряжения';

  @override
  String get irohQrBody =>
      'Отсканируйте его приложением mStream на другом устройстве, чтобы подключить его к этому серверу, или скопируйте код и вставьте там.';

  @override
  String get irohQrCaution =>
      'Любой, у кого есть этот код, может подключиться к вашему серверу.';

  @override
  String get irohScanQr => 'Сканировать QR';

  @override
  String get irohPaste => 'Вставить';

  @override
  String get irohTestConnection => 'Проверить подключение';

  @override
  String get irohTesting => 'Проверка…';

  @override
  String get irohScannerTitle => 'Сканировать QR-код сопряжения';

  @override
  String get irohQrAndroidOnly =>
      'Сканирование QR недоступно на этом устройстве.';

  @override
  String get serverBadgeBuiltIn => 'Built-in';

  @override
  String get irohAndroidOnly =>
      'Быстрое подключение недоступно на этом устройстве.';

  @override
  String get irohCameraPermission =>
      'Для сканирования кода нужно разрешение на использование камеры.';

  @override
  String get irohPasteFirst =>
      'Сначала вставьте или отсканируйте код сопряжения.';

  @override
  String get irohTestFirst => 'Сначала проверьте подключение.';

  @override
  String get irohTestConnected => 'Подключено через туннель iroh';

  @override
  String irohTestConnectedVersion(String version) {
    return 'Подключено через туннель iroh — mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · напрямую';

  @override
  String get irohPathSuffixRelay => ' · через ретранслятор';

  @override
  String get irohTunnelTimeout =>
      'Туннель открыт, но сервер не ответил вовремя.';

  @override
  String irohTunnelTestFailed(String error) {
    return 'Проверка туннеля не удалась: $error';
  }

  @override
  String get irohSignInHeader => 'Вход';

  @override
  String get irohSigningIn => 'Выполняется вход…';

  @override
  String get irohSignInSave => 'Войти и сохранить';

  @override
  String get irohSignInTimeout => 'Время ожидания входа истекло.';

  @override
  String irohSignInFailed(String error) {
    return 'Не удалось войти: $error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return 'Не удалось войти (HTTP $status). Проверьте имя пользователя и пароль.';
  }

  @override
  String get irohBannerConnecting => 'Подключение к серверу…';

  @override
  String get irohBannerReconnecting => 'Повторное подключение к серверу…';

  @override
  String get irohBannerDisconnected => 'Соединение с сервером разорвано.';

  @override
  String get irohBannerRelay =>
      'Подключено через ретранслятор — более медленный путь.';

  @override
  String get irohBannerRepair =>
      'Сопряжение сервера изменилось — выполните его заново, чтобы переподключиться.';

  @override
  String get irohRepairAction => 'Повторить сопряжение';

  @override
  String get irohRetry => 'Повторить';

  @override
  String get irohRepairTitle => 'Повторное сопряжение сервера';

  @override
  String get irohRepairBody =>
      'Код сопряжения этого сервера изменился (его секрет был обновлён). Вставьте или отсканируйте новый код из панели «Remote Access» сервера.';

  @override
  String get irohRepairFailed =>
      'Не удалось подключиться с этим кодом — проверьте его и попробуйте снова.';

  @override
  String get irohPathDirect => 'Напрямую';

  @override
  String get irohPathRelay => 'Ретранслятор';

  @override
  String get irohCastUnavailable =>
      'Трансляция на внешние устройства недоступна для одноранговых (iroh) серверов — воспроизведение остаётся на этом устройстве.';

  @override
  String get irohShareUnavailable =>
      'Функция «Поделиться» недоступна для одноранговых (iroh) серверов — у них нет публичного URL для ссылки.';

  @override
  String get discoverTitle => 'Открытия';

  @override
  String get discoverMatchedBySound => 'Подобрано по звучанию';

  @override
  String get discoverSimilarTracks => 'Похожие треки';

  @override
  String get discoverSimilarArtists => 'Похожие исполнители';

  @override
  String get discoverFromNetwork => 'Из сети';

  @override
  String get discoverFromPeers => 'От ваших пиров';

  @override
  String get discoverQueueAll => 'Добавить все в очередь';

  @override
  String get discoverNewArtistsOnly => 'Только новые исполнители';

  @override
  String get discoverNotAnalyzed =>
      'Этот трек ещё не проанализирован — похожие треки появятся, когда сканирование дойдёт до него.';

  @override
  String get discoverScanPendingTitle => 'Пока ничего не проанализировано';

  @override
  String get discoverScanPendingBody =>
      'На этом сервере подбор по звучанию включён, но музыка ещё не проанализирована. Похожие треки появятся после сканирования.';

  @override
  String get discoverCheckAgain => 'Проверить снова';

  @override
  String get discoverTurnedOff =>
      'Подбор по звучанию отключён на этом сервере.';

  @override
  String get pathScanPending =>
      'На этом сервере музыка ещё не проанализирована, поэтому прокладывать путь не по чему. Заработает после сканирования.';

  @override
  String get discoverNothingFound => 'Совпадений не найдено.';

  @override
  String get discoverNoSeed => 'Включите трек, чтобы открыть похожую музыку.';

  @override
  String get discoverLeadCopied => 'Скопировано — идите искать!';

  @override
  String get discoverOpenMusicBrainz => 'Открыть на MusicBrainz';

  @override
  String get discoverNetworkWarmingUp =>
      'Данных из сети пока нет — библиотеки пиров загружаются в фоне, как только обнаружены другие серверы.';

  @override
  String get discoverNetworkNothingNew =>
      'Ничего нового для этого трека — в сети нет незнакомых совпадений.';

  @override
  String get discoverPeersUnreachable =>
      'Ваши пиры не ответили — возможно, они сейчас офлайн.';

  @override
  String get discoverPeersNothingNew =>
      'Ничего нового для этого трека на серверах ваших пиров.';

  @override
  String get autoDjSonicTitle => 'Похожее звучание';

  @override
  String get autoDjSonicSubtitle =>
      'Выбирать только треки, похожие по звучанию на сессию, на основе аудиоанализа сервера.';

  @override
  String get autoDjSonicUnavailable =>
      'На этом сервере нет данных подбора по звучанию — выбор останется случайным.';

  @override
  String get autoDjSonicNotReady =>
      'Подбор по звучанию включён, но сканирование ещё не дало данных — до тех пор выбор останется случайным.';

  @override
  String get autoDjSonicStrictness => 'Порог похожести';

  @override
  String autoDjSonicStrictnessValue(int pct) {
    return '$pct% и ближе';
  }

  @override
  String get autoDjSonicSeedLabel => 'Стартовый трек';

  @override
  String get autoDjSonicSeedNone => 'Не задан — сессию задаёт играющий трек.';

  @override
  String get autoDjSonicSeedBanner =>
      'Выберите стартовый трек — коснитесь любого трека в библиотеке';

  @override
  String get autoDjSonicSeedSearchHint => 'Найти трек…';

  @override
  String get autoDjSonicSeedRandom => 'Случайный трек';

  @override
  String get autoDjSonicSeedRemove => 'Убрать стартовый трек';

  @override
  String get autoDjSonicSeedFailed => 'Не удалось получить трек с сервера.';

  @override
  String get autoDjSeedNoMatch =>
      'Нет треков, подходящих под фильтры Авто-DJ — попробуйте смягчить их';

  @override
  String get discoverFindSimilar => 'Найти похожие';

  @override
  String get discoverStartSession => 'Запустить звуковую сессию';

  @override
  String get discoverStartSessionSubtitle =>
      'Бесконечная музыка, звучащая как этот трек — заменит вашу очередь.';

  @override
  String get discoverStartSessionSubtitleRandom =>
      'Бесконечная музыка со случайного стартового трека — заменит вашу очередь.';

  @override
  String get discoverSessionStarted =>
      'Звуковая сессия запущена — Авто-DJ включён.';

  @override
  String get autoDjSonicAnchorLabel => 'Якорь';

  @override
  String get autoDjSonicAnchorRolling => 'Следовать настроению';

  @override
  String get autoDjSonicAnchorLocked => 'Держаться стартового трека';

  @override
  String get autoDjSonicAnchorRollingHint =>
      'Каждый трек следует недавнему звучанию сессии — она может медленно меняться.';

  @override
  String get autoDjSonicAnchorLockedHint =>
      'Каждый трек остаётся близким к стартовому треку всю сессию.';

  @override
  String get trackAddToPlaylist => 'Добавить в плейлист';

  @override
  String get trackAddToPlaylistFailed => 'Не удалось добавить в плейлист.';

  @override
  String get discoverPlayPathTo => 'Проиграть путь к…';

  @override
  String get pathScreenTitle => 'Звуковой путь';

  @override
  String get pathStartNotAnalyzed =>
      'Начальный трек ещё не проанализирован — дождитесь сканирования или выберите другой.';

  @override
  String get pathEndNotAnalyzed =>
      'Конечный трек ещё не проанализирован — дождитесь сканирования или выберите другой.';

  @override
  String get pathStartSong => 'Начальный трек';

  @override
  String get pathEndSong => 'Конечный трек';

  @override
  String get pathLength => 'Длина';

  @override
  String get pathRegenerate => 'Пересоздать';

  @override
  String get pathSaveAsPlaylist => 'Сохранить как плейлист';

  @override
  String get pathSetupHint =>
      'Выберите начальный и конечный трек — путь между ними заполнится сам.';

  @override
  String get pathNotSet => 'Не выбрано';

  @override
  String get pathUsePlaying => 'Текущий трек';

  @override
  String get pathSearchSong => 'Поиск';

  @override
  String get pathBrowseLibrary => 'Обзор библиотеки';

  @override
  String get pathBuild => 'Построить путь';

  @override
  String get pathStartOver => 'Начать заново';

  @override
  String get pathPickBannerStart =>
      'Выберите начальный трек — коснитесь любого трека в библиотеке';

  @override
  String get pathPickBannerEnd =>
      'Выберите конечный трек — коснитесь любого трека в библиотеке';

  @override
  String get pathNothingPlaying => 'Сейчас ничего не играет';

  @override
  String pathPickOnServer(String server) {
    return 'Выберите трек на сервере $server';
  }

  @override
  String get welcomeTranslationNote =>
      'Этот язык переведён машинно и может звучать неестественно.';

  @override
  String get welcomeTranslationCta => 'Помочь с переводом mStream';

  @override
  String get setupTitle => 'Быстрая настройка';

  @override
  String get setupSkip => 'Пропустить';

  @override
  String get setupNext => 'Далее';

  @override
  String get setupFinish => 'Готово';

  @override
  String get setupBack => 'Назад';

  @override
  String get setupAccentTitle => 'Выберите цвет';

  @override
  String get setupAccentBody =>
      'Акцентный цвет выделяет кнопки, ползунки и элементы управления плеером. Коснитесь любого, чтобы попробовать.';

  @override
  String get setupVisualizerTitle => 'Реальный звук для визуализации';

  @override
  String get setupVisualizerBody =>
      'Пока это не включено, визуализация использует синтезированные данные.';

  @override
  String get setupVisualizerWarning =>
      'При включении запрашивается разрешение на микрофон — Android требует его от приложений, которые декодируют аудиопоток устройства (а визуализация это делает).';

  @override
  String get setupPlaybackTitle => 'При нажатии на трек';

  @override
  String get setupOfflineTitle => 'Очередь доступна и офлайн';

  @override
  String get setupVisualizerNoMic =>
      'mStream никогда не использует ваш микрофон.';

  @override
  String get playlistEmpty => 'Плейлист пуст';

  @override
  String get trackRating => 'Оценка';

  @override
  String albumDiscNumber(int n) {
    return 'Диск $n';
  }

  @override
  String get autoDjStartTitle => 'С чего начать Авто-DJ?';

  @override
  String get autoDjStartSubtitle =>
      'Очередь пуста, поэтому диджею нужен первый трек. С очередью он просто идёт по тому, что уже есть.';

  @override
  String get autoDjStartRandom => 'Удиви меня';

  @override
  String get autoDjStartRandomSub =>
      'Выбрать случайный трек из библиотеки и строить от него.';

  @override
  String get autoDjStartPick => 'Выбрать самостоятельно';

  @override
  String get autoDjStartPickSub =>
      'Открыть библиотеку и выбрать первый трек самостоятельно.';

  @override
  String get autoDjStartRemember => 'Запомнить';

  @override
  String get autoDjStartRememberSub =>
      'Пропускать этот вопрос и всегда начинать так.';

  @override
  String get autoDjStartPickBanner =>
      'Выберите первый трек — коснитесь любого трека в библиотеке';

  @override
  String get autoDjOnEmptyQueue => 'При пустой очереди';

  @override
  String get autoDjOnEmptyQueueSub =>
      'Что делает Авто-DJ, когда вы включаете его с пустой очередью.';

  @override
  String get autoDjStartAskShort => 'Спрашивать';

  @override
  String serverVersionLabel(String version) {
    return 'Сервер v$version';
  }

  @override
  String get serverVersionUnknown => 'Версия сервера неизвестна';

  @override
  String get serverUpdateUrgent => 'Обновите сервер';

  @override
  String get serverUpdateAvailable => 'Доступно обновление сервера';

  @override
  String serverTooOldWarning(String version) {
    return 'Версия этого сервера — v$version. Некоторым функциям нужна v5.5 или новее, они будут недоступны.';
  }

  @override
  String get autoDjNeedsNewerServer =>
      'Непрерывность по BPM, гармоническое сведение и фильтр по жанрам требуют более новой версии сервера. Обновите его, чтобы получить их.';

  @override
  String get autoDjSonicNeedsNewerServer => 'Требуется сервер 6.15.2 или новее';

  @override
  String get torrentScreenTitle => 'Добавить торрент';

  @override
  String get torrentNoServer => 'Сервер не настроен.';

  @override
  String get torrentServerLabel => 'Сервер';

  @override
  String get torrentLibraryLabel => 'Библиотека';

  @override
  String get torrentNoLibraries => 'На этом сервере нет библиотек';

  @override
  String get torrentSourceLabel => 'Источник';

  @override
  String get torrentChooseFile => 'Выбрать файл .torrent';

  @override
  String get torrentOr => 'или';

  @override
  String get torrentMagnetLabel => 'Magnet-ссылка';

  @override
  String get torrentMagnetInvalid => 'Недействительная magnet-ссылка';

  @override
  String torrentNotATorrent(String name) {
    return '«$name» не является файлом .torrent';
  }

  @override
  String get torrentOpenWith => 'Открыть в другом приложении';

  @override
  String get torrentOpenWithNone =>
      'На этом устройстве нет приложения, способного открыть файл .torrent';

  @override
  String get torrentOpenWithFailed =>
      'Не удалось передать торрент другому приложению';

  @override
  String get torrentIntentTitle => 'Торрент получен';

  @override
  String get torrentIntentBody =>
      'Добавьте его в библиотеку на сервере mStream или передайте другому приложению.';

  @override
  String get torrentIntentAdd => 'Добавить в mStream';

  @override
  String get torrentIntentDontAsk =>
      'Всегда добавлять в mStream и больше не спрашивать';

  @override
  String get settingsTorrentAskTitle => 'Спрашивать, что делать с торрентами';

  @override
  String get settingsTorrentAskSub =>
      'При открытии торрента в mStream предлагать передать его другому приложению';

  @override
  String get settingsTorrentDefaultTitle =>
      'Приложение по умолчанию для торрентов';

  @override
  String get settingsTorrentDefaultSub =>
      'Откроет настройки Android, где можно выбрать приложение для торрентов и magnet-ссылок';

  @override
  String get settingsTorrentDefaultFailed =>
      'Не удалось открыть настройки Android';

  @override
  String get torrentAutoDetect => 'Определить метаданные';

  @override
  String get torrentDetecting => 'Определение…';

  @override
  String get torrentDetectNoMetadata =>
      'Недостаточно метаданных — заполните поля вручную';

  @override
  String get torrentDetected => 'Метаданные определены';

  @override
  String get torrentDetectGuess => 'Приблизительная оценка — проверьте поля';

  @override
  String get torrentMetadataLabel => 'Метаданные';

  @override
  String get torrentArtistLabel => 'Исполнитель';

  @override
  String get torrentAlbumLabel => 'Альбом';

  @override
  String get torrentYearLabel => 'Год';

  @override
  String get torrentDestinationLabel => 'Место назначения';

  @override
  String get torrentPathLabel => 'Путь в библиотеке';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹без библиотеки›/$path';
  }

  @override
  String get torrentPreviewContents => '‹содержимое торрента›';

  @override
  String get torrentRenameRoot => 'Переименовать корневую папку торрента';

  @override
  String get torrentRenameRootSub =>
      'Сделать таким же, как имя папки назначения';

  @override
  String get torrentForceFresh => 'Принудительно скачать заново';

  @override
  String get torrentForceFreshSub =>
      'Не проверять файлы, уже имеющиеся на сервере';

  @override
  String get torrentSubmit => 'Добавить торрент';

  @override
  String get torrentSubmitting => 'Добавление…';

  @override
  String get torrentUnavailable => 'Торренты недоступны на этом сервере.';

  @override
  String get torrentPickLibrary => 'Выберите библиотеку';

  @override
  String get torrentOneSource =>
      'Укажите magnet-ссылку или файл .torrent (что-то одно)';

  @override
  String get torrentPathEmpty => 'Путь назначения пуст';

  @override
  String get torrentSeeded => 'Уже на диске — раздаётся';

  @override
  String get torrentAlreadyInClient => 'Уже в торрент-клиенте';

  @override
  String get torrentInvalidFile => 'Некорректный торрент-файл';

  @override
  String get torrentSeedCheckFailed =>
      'Не удалось проверить существующие файлы — скачиваем заново';

  @override
  String get torrentPartialTitle => 'Некоторые файлы уже существуют';

  @override
  String get torrentPartialBody =>
      'Укажите торренту существующую копию, чтобы раздавать её и скачать только недостающее.';

  @override
  String torrentPartialCount(String matched, String total) {
    return '$matched/$total файлов здесь';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · скачать $missing';
  }

  @override
  String get torrentDownloadFresh => 'Всё равно скачать заново';

  @override
  String get torrentMatchNoFolder =>
      'У этого совпадения нет имени папки — используйте «Всё равно скачать заново»';

  @override
  String torrentAdded(String name) {
    return 'Добавлено: «$name»';
  }

  @override
  String torrentDuplicate(String name) {
    return '«$name» уже в клиенте';
  }

  @override
  String serverPickerVia(String parent) {
    return 'через $parent';
  }

  @override
  String get browserFederatedReadOnly => 'Сервер только для чтения';

  @override
  String get browserFederatedReadOnlyNote =>
      'Плейлисты и оценки остаются на вашем сервере';

  @override
  String get federatedShareUnavailable =>
      'Треками с общего сервера нельзя поделиться отсюда — они находятся в чужой библиотеке.';

  @override
  String get federatedForget => 'Забыть';

  @override
  String get federatedHide => 'Скрыть из списка серверов';

  @override
  String get federatedShow => 'Показать в списке серверов';

  @override
  String federatedNoLongerListed(String parent) {
    return '$parent больше не делится этим сервером';
  }

  @override
  String get federationTitle => 'Федерация';

  @override
  String get federationStatusOn => 'Включена · подключено к ретранслятору';

  @override
  String get federationStatusConnecting => 'Включена · подключение…';

  @override
  String get federationStatusOff => 'Выключена';

  @override
  String get federationStatusUnavailable => 'Недоступно на этой платформе';

  @override
  String get federationSharedWithYou => 'Доступно вам';

  @override
  String get federationRequestsSection => 'Запросы';

  @override
  String get federationYourSharedLibraries => 'Ваши общие библиотеки';

  @override
  String get federationAddPeer => 'Добавить пир';

  @override
  String get federationShareLibrary => 'Поделиться библиотекой';

  @override
  String get federationNoPeersYet => 'С этим сервером пока ничем не делятся.';

  @override
  String get federationNoKeysYet =>
      'Билетов пока нет — поделитесь библиотекой, чтобы создать билет.';

  @override
  String get federationNoRequests =>
      'Запросов пока нет — серверы из сети обнаружения найдут вас здесь.';

  @override
  String get federationClipboardTicket => 'Билет в буфере обмена';

  @override
  String federationTicketPreview(String name, String libraries) {
    return '$name · делится: $libraries';
  }

  @override
  String federationTicketPreviewNoLibraries(String name) {
    return '$name';
  }

  @override
  String get federationUnnamedServer => 'Сервер без имени';

  @override
  String get federationAddPeerAction => 'Добавить';

  @override
  String get federationPeerLive => 'на связи';

  @override
  String get federationPeerConnecting => 'подключение…';

  @override
  String get federationPeerDirectTunnel => 'прямой туннель';

  @override
  String federationPeerViaParent(String parent) {
    return 'через $parent';
  }

  @override
  String federationPeerViaTunnel(String parent) {
    return 'через туннель сервера $parent';
  }

  @override
  String get federationPeerMissing => 'больше не доступен';

  @override
  String get federationPeerHidden => 'скрыт из списка серверов';

  @override
  String federationMemberNote(String server) {
    return 'Делиться может только администратор. Создание билетов, добавление пиров и ответы на запросы объединения требуют входа администратором на сервер $server — того же, что открывает панель администратора.';
  }

  @override
  String get federationRestrictedNote =>
      'Этот сервер принимает административные вызовы только из своей сети. Подключитесь из дома, чтобы управлять доступом здесь.';

  @override
  String get federationDisabledNote =>
      'Административный API на этом сервере выключен.';

  @override
  String get federationUnsupportedNote =>
      'Этот сервер слишком стар, чтобы управлять федерацией из приложения. Обновите mStream.';

  @override
  String get federationLoadFailed => 'Не удалось связаться с сервером.';

  @override
  String get federationRetry => 'Повторить';

  @override
  String get federationOffTitle => 'Делитесь библиотеками с серверами друзей';

  @override
  String get federationOffBody =>
      'Объедините два сервера mStream, чтобы слушать музыку друг друга. Вы обмениваетесь билетами — билет можно отправить сообщением, отсканировать или вставить.';

  @override
  String get federationOffPoint1Title => 'Только чтение, сквозное шифрование';

  @override
  String get federationOffPoint1Body =>
      'Плейлисты и оценки не покидают ваш сервер';

  @override
  String get federationOffPoint2Title => 'Без проброса портов и DNS';

  @override
  String get federationOffPoint2Body =>
      'iroh находит путь — напрямую, когда может, через ретранслятор, когда нужно';

  @override
  String get federationOffPoint3Title => 'Билеты можно отозвать';

  @override
  String get federationOffPoint3Body =>
      'Каждый используется один раз, и его можно отключить в любой момент';

  @override
  String get federationOffAdminOnly =>
      'Включить это может только администратор сервера.';

  @override
  String federationOffMemberNote(String server) {
    return 'Федерация на сервере $server выключена. Администратор может её включить.';
  }

  @override
  String get federationTurnOn => 'Включить федерацию';

  @override
  String get federationUnavailableNote =>
      'У компонента iroh нет сборки для ОС/процессора этого сервера, поэтому конечная точка федерации здесь не запустится.';

  @override
  String get federationTurnedOn => 'Федерация включена';

  @override
  String get federationTurnedOff => 'Федерация выключена';

  @override
  String get federationToggleFailed =>
      'Не удалось изменить настройку федерации.';

  @override
  String get federationSettingsTitle => 'Настройки федерации';

  @override
  String get federationSwitchSubtitle =>
      'Одноранговое соединение, сквозное шифрование. Без проброса портов, без DNS.';

  @override
  String get federationStatusSection => 'Состояние';

  @override
  String get federationConnectedRelay => 'Подключено к ретранслятору';

  @override
  String get federationNotRunning => 'Конечная точка не запущена';

  @override
  String get federationEndpointId => 'ID конечной точки';

  @override
  String get federationEndpointCopied => 'ID конечной точки скопирован';

  @override
  String get federationPairingRequestsSection => 'Запросы объединения';

  @override
  String get federationRequestsInboxTitle =>
      'Принимать запросы из сети обнаружения';

  @override
  String get federationRequestsInboxSubtitle =>
      'По умолчанию выключено. Когда выключено, новые запросы отклоняются на транспортном уровне; ответы на ваши собственные запросы всё равно приходят.';

  @override
  String get federationInboxFailed => 'Не удалось изменить приём запросов.';

  @override
  String get federationDefaultsSection =>
      'Значения по умолчанию для новых билетов';

  @override
  String get federationDefaultsNote =>
      'Из конфигурации сервера — каждый билет может их изменить';

  @override
  String get federationOffWarning =>
      'Выключение федерации обрывает все связи с пирами и скрывает ваши билеты, пока она снова не включится. Пиры сохраняют свои билеты.';

  @override
  String federationRequestWantsToPair(String name) {
    return '$name хочет объединиться';
  }

  @override
  String federationRequestToName(String name) {
    return 'Запрос серверу $name';
  }

  @override
  String federationRequestOffers(String libraries) {
    return 'Предлагает: $libraries';
  }

  @override
  String get federationRequestOffersNothing => 'Ничего не предлагает';

  @override
  String federationRequestYouOffered(String libraries) {
    return 'Вы предложили: $libraries';
  }

  @override
  String get federationRequestYouOfferedNothing => 'Вы ничего не предложили';

  @override
  String get federationReqSending => 'отправка…';

  @override
  String get federationReqWaiting => 'ждём ответа';

  @override
  String get federationReqSharingBack => 'делимся в ответ…';

  @override
  String get federationReqNeedsAnswer => 'нужен ваш ответ';

  @override
  String get federationReqSendingTicket => 'отправляем ваш билет…';

  @override
  String get federationReqWaitingShare => 'ждём ответного доступа';

  @override
  String get federationReqDeclined => 'отклонён';

  @override
  String get federationReqYouDeclined => 'вы отклонили';

  @override
  String get federationReqInboxClosed => 'они не принимают запросы';

  @override
  String get federationReqFederated => 'объединено';

  @override
  String get federationReqWithdrawn => 'отозван';

  @override
  String get federationReqExpired => 'истёк';

  @override
  String get federationAccept => 'Принять…';

  @override
  String get federationAcceptAndShare => 'Принять и поделиться';

  @override
  String get federationDecline => 'Отклонить';

  @override
  String get federationCancelRequest => 'Отозвать запрос';

  @override
  String get federationDismiss => 'Убрать';

  @override
  String get federationRequestTitle => 'Запрос объединения';

  @override
  String federationRequestReceived(String ago) {
    return 'Получен $ago через сеть обнаружения';
  }

  @override
  String federationRequestSent(String ago) {
    return 'Отправлен $ago через сеть обнаружения';
  }

  @override
  String get federationShareBack => 'Поделиться в ответ';

  @override
  String get federationShareBackNote =>
      'Ничего не передаётся, пока вы не примете запрос. Они получат доступ только для чтения к отмеченным библиотекам — хотя бы одной.';

  @override
  String get federationTheirLimits => 'Их ограничения';

  @override
  String get federationChange => 'Изменить';

  @override
  String get federationRequestIgnored =>
      'Запросы от этого сервера игнорируются 7 дней';

  @override
  String get federationRequestAccepted => 'Запрос принят';

  @override
  String get federationRequestDeclined => 'Запрос отклонён';

  @override
  String get federationRequestCancelled => 'Запрос отозван';

  @override
  String get federationRequestActionFailed => 'Не удалось обновить запрос.';

  @override
  String get federationTicketNameLabel => 'Для кого это?';

  @override
  String get federationTicketNameHint =>
      'Это имя видите только вы — так билет будет подписан в вашем списке.';

  @override
  String get federationLibrariesTheyCanRead =>
      'Библиотеки, которые они смогут читать';

  @override
  String get federationLimitsSection => 'Ограничения';

  @override
  String get federationExactNumbers => 'Точные значения';

  @override
  String get federationPresets => 'Пресеты';

  @override
  String get federationLimitStreamRate => 'Скорость потока';

  @override
  String get federationLimitPerDay => 'В день';

  @override
  String get federationLimitStreams => 'Потоков одновременно';

  @override
  String get federationLimitExpires => 'Истекает';

  @override
  String get federationUnlimited => 'Без ограничений';

  @override
  String get federationNever => 'Никогда';

  @override
  String federationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get federationOneYear => '1 год';

  @override
  String federationKbps(int n) {
    return '$n кбит/с';
  }

  @override
  String federationMbps(int n) {
    return '$n Мбит/с';
  }

  @override
  String federationMbPerDay(int n) {
    return '$n МБ в день';
  }

  @override
  String federationGbPerDay(int n) {
    return '$n ГБ в день';
  }

  @override
  String federationStreamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count потоков',
      many: '$count потоков',
      few: '$count потока',
      one: '$count поток',
    );
    return '$_temp0';
  }

  @override
  String get federationNeverExpires => 'не истекает';

  @override
  String federationExpiresIn(String when) {
    return 'истекает $when';
  }

  @override
  String get federationExpired => 'истёк';

  @override
  String federationInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'через $count дней',
      many: 'через $count дней',
      few: 'через $count дня',
      one: 'через $count день',
    );
    return '$_temp0';
  }

  @override
  String federationInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'через $count часов',
      many: 'через $count часов',
      few: 'через $count часа',
      one: 'через $count час',
    );
    return '$_temp0';
  }

  @override
  String get federationStreamRateField =>
      'Скорость (кбит/с, 0 = без ограничений)';

  @override
  String get federationPerDayField => 'Дневная квота (МБ, 0 = без ограничений)';

  @override
  String get federationStreamsField => 'Макс. потоков (0 = без ограничений)';

  @override
  String get federationExpiresField => 'Срок действия, дней (0 = бессрочно)';

  @override
  String get federationCreateTicket => 'Создать билет';

  @override
  String get federationMintFailed => 'Не удалось создать билет.';

  @override
  String get federationNoLibraries =>
      'На этом сервере нет библиотек, которыми можно поделиться.';

  @override
  String get federationTicketTitle => 'Ваш билет';

  @override
  String federationTicketFor(String name) {
    return 'Билет: $name';
  }

  @override
  String federationTicketReads(String libraries) {
    return 'Читает: $libraries';
  }

  @override
  String get federationTicketQrHint => 'В одной комнате? Дайте отсканировать.';

  @override
  String get federationTicketWarning =>
      'Любой, у кого есть этот билет, может читать эти библиотеки, пока он не использован или не отозван. Отправляйте его по приватному каналу — билет достаётся первому серверу, который его использует.';

  @override
  String get federationCopyTicket => 'Скопировать билет';

  @override
  String get federationTicketCopied => 'Билет скопирован';

  @override
  String get federationSendByText => 'Отправить сообщением…';

  @override
  String get federationTicketRevokeNote =>
      'Отозвать можно в любой момент в разделе «Федерация». Если друг переустановил сервер, «Сбросить привязку» позволит использовать билет снова.';

  @override
  String get federationTicketNotRunning =>
      'Конечная точка федерации не запущена, поэтому отправлять пока нечего. Включите федерацию и вернитесь.';

  @override
  String federationShareMessage(String libraries, String ticket) {
    return 'Делюсь с тобой своей музыкальной библиотекой mStream — $libraries, только чтение. В приложении mStream открой «Федерация → Добавить пир» и вставь этот билет:\n\n$ticket\n\nОн работает один раз — я могу отозвать его в любой момент.';
  }

  @override
  String get federationShareSubject => 'Билет федерации mStream';

  @override
  String get federationKeyClaimed => 'использован';

  @override
  String get federationKeyNotClaimed => 'ещё не использован';

  @override
  String federationKeyTodayUsage(String amount) {
    return '$amount сегодня';
  }

  @override
  String federationKeyLastUsed(String ago) {
    return 'Последнее использование $ago';
  }

  @override
  String get federationKeyNeverUsed => 'Не использовался';

  @override
  String federationKeyClaimedAgo(String ago) {
    return 'Использован $ago';
  }

  @override
  String get federationResetBinding => 'Сбросить привязку';

  @override
  String get federationResetBindingNote =>
      'Друг переустановил сервер? Позвольте использовать билет снова.';

  @override
  String get federationBindingReset => 'Билет можно использовать снова';

  @override
  String get federationRevoke => 'Отозвать';

  @override
  String federationRevokeConfirm(String name) {
    return 'Отозвать этот билет? $name сразу потеряет доступ.';
  }

  @override
  String get federationRevoked => 'Билет отозван';

  @override
  String get federationSaveLimits => 'Сохранить ограничения';

  @override
  String get federationLimitsSaved => 'Ограничения сохранены';

  @override
  String get federationLimitsFailed => 'Не удалось сохранить ограничения.';

  @override
  String get federationSend => 'Отправить';

  @override
  String get federationKeyTitle => 'Общая библиотека';

  @override
  String federationActionFailed(String error) {
    return 'Не сработало: $error';
  }

  @override
  String get federationTheirTicket => 'Их билет';

  @override
  String get federationScanQr => 'Сканировать QR-код';

  @override
  String get federationScannerTitle => 'Сканировать билет федерации';

  @override
  String get federationPaste => 'Вставить';

  @override
  String get federationTicketPasted => 'Вставлено из буфера обмена.';

  @override
  String get federationNotATicket => 'Это не похоже на билет федерации.';

  @override
  String get federationTicketTooNew =>
      'Этот билет от более новой версии mStream, чем понимает это приложение.';

  @override
  String get federationTicketExpiredNote => 'Срок действия этого билета истёк.';

  @override
  String get federationDisplayName => 'Отображаемое имя';

  @override
  String get federationDisplayNameHint =>
      'Необязательно — так сервер будет показан в списке серверов.';

  @override
  String federationSharesLibraries(String libraries) {
    return 'Делится: $libraries';
  }

  @override
  String get federationSharesUnknown => 'Библиотеки в билете не указаны';

  @override
  String federationValidUntil(String date) {
    return 'действует до $date';
  }

  @override
  String federationAddPeerShowsUnder(String server) {
    return 'Появится в группе «$server»';
  }

  @override
  String federationAddPeerReadOnly(String branch, String name) {
    return 'Только чтение · $branch $name в списке серверов';
  }

  @override
  String get federationAddPeerDials =>
      'Ваш сервер подключается к нему через iroh';

  @override
  String get federationAddPeerEncrypted =>
      'Сквозное шифрование · без проброса портов';

  @override
  String get federationAddPeerNoTicket =>
      'Билета ещё нет? Попросите прислать его сообщением.';

  @override
  String federationPeerAdded(String name) {
    return '$name добавлен';
  }

  @override
  String get federationAddPeerFailed => 'Не удалось добавить пир.';

  @override
  String get federationPeerAlreadyAdded => 'Этот билет уже добавлен как пир.';

  @override
  String get federationLibrariesYouCanRead =>
      'Библиотеки, которые вы можете читать';

  @override
  String get federationDiscoverySection => 'Открытия';

  @override
  String get federationAskPeerSimilar =>
      'Запрашивать у этого пира похожую музыку';

  @override
  String get federationAskPeerSimilarNote =>
      'Отправляет то, что вы слушаете — только этому пиру.';

  @override
  String get federationAutoDjSection => 'Авто-DJ';

  @override
  String get federationAutoDjParticipates =>
      'Участвует в многосерверном Авто-DJ';

  @override
  String get federationAutoDjParticipatesNote =>
      'Отвечает из своей библиотеки, когда DJ включён';

  @override
  String get federationAutoDjNotCandidate => 'Не кандидат для Авто-DJ';

  @override
  String get federationAutoDjNotCandidateNote =>
      'Нужен сервер, умеющий подбирать треки по звучанию';

  @override
  String get federationTest => 'Проверить';

  @override
  String get federationTesting => 'Проверка…';

  @override
  String get federationTestOk => 'Доступен';

  @override
  String federationTestFailed(String error) {
    return 'Не удалось связаться: $error';
  }

  @override
  String federationCheckedAgo(String ago) {
    return 'Проверено $ago';
  }

  @override
  String get federationNeverTested => 'Не проверялся';

  @override
  String federationLastSeen(String ago) {
    return 'Последний раз на связи $ago';
  }

  @override
  String get federationBrowseLibrary => 'Открыть эту библиотеку';

  @override
  String get federationRemovePeer => 'Удалить пир';

  @override
  String federationRemovePeerConfirm(String name) {
    return 'Удалить $name? Треки из очереди с этого пира перестанут играть.';
  }

  @override
  String federationPeerRemoved(String name) {
    return '$name удалён';
  }

  @override
  String get federationShowInPicker => 'Показывать в списке серверов';

  @override
  String get federationShowInPickerNote =>
      'Скрытые пиры продолжают играть то, что вы поставили из них в очередь.';

  @override
  String get federationPeerReadOnlyNote =>
      'Только чтение — плейлисты и оценки остаются на вашем сервере.';

  @override
  String get federationPeerLibrariesUnknown =>
      'Пока не загружено — откройте его один раз, чтобы получить список библиотек.';

  @override
  String get federationTransportDirect => 'Прямой туннель с этого телефона';

  @override
  String get federationTransportRelay => 'Ретранслятор наготове';

  @override
  String federationTransportViaParent(String parent) {
    return 'Через $parent';
  }

  @override
  String federationTransportViaParentTunnel(String parent) {
    return 'Через $parent по его туннелю';
  }

  @override
  String get federationDiscoveryFailed =>
      'Не удалось изменить настройку подбора похожей музыки.';

  @override
  String get agoJustNow => 'только что';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мин назад',
      many: '$count мин назад',
      few: '$count мин назад',
      one: '$count мин назад',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ч назад',
      many: '$count ч назад',
      few: '$count ч назад',
      one: '$count ч назад',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней назад',
      many: '$count дней назад',
      few: '$count дня назад',
      one: '$count день назад',
    );
    return '$_temp0';
  }

  @override
  String get browserP2pNetwork => 'P2P-сеть';

  @override
  String get browserP2pOn => 'Включена';

  @override
  String get browserP2pOff => 'Выключена';

  @override
  String get p2pTitle => 'P2P-сеть';

  @override
  String get p2pStatusConnected => 'Подключено';

  @override
  String p2pNeighborsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count соседей',
      many: '$count соседей',
      few: '$count соседа',
      one: '$count сосед',
    );
    return '$_temp0';
  }

  @override
  String p2pAnnouncingAs(String name) {
    return 'объявляется как $name';
  }

  @override
  String get p2pStatusSearching => 'В сети · ожидание соседей';

  @override
  String p2pStatusReconnecting(int n) {
    return 'Переподключение · попытка $n';
  }

  @override
  String get p2pStatusNotJoined => 'Ещё не в сети';

  @override
  String get p2pStatusOff => 'Выключена';

  @override
  String get p2pStatusUnavailable => 'Недоступно на этой платформе';

  @override
  String get p2pStatNeighbors => 'соседей в сети';

  @override
  String get p2pStatNeighborsSub => 'активные gossip-соединения';

  @override
  String get p2pStatKnown => 'известных серверов';

  @override
  String p2pStatKnownSub(int hidden, int blocked) {
    return '$hidden скрыто · $blocked заблокировано';
  }

  @override
  String get p2pStatHeld => 'снимков хранится';

  @override
  String p2pStatHeldOf(int held, int max) {
    return '$held из $max';
  }

  @override
  String p2pStatStorage(String used, String cap) {
    return '$used из $cap';
  }

  @override
  String get p2pStatTracks => 'треков у пиров';

  @override
  String p2pStatTracksSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'доступно для поиска, $count библиотек',
      many: 'доступно для поиска, $count библиотек',
      few: 'доступно для поиска, $count библиотеки',
      one: 'доступно для поиска, $count библиотека',
    );
    return '$_temp0';
  }

  @override
  String get p2pActivity => 'Активность';

  @override
  String get p2pActivitySubtitle => 'сначала новые · только в памяти';

  @override
  String get p2pActivityEmpty =>
      'Пока ничего — подключения к сети, загрузки снимков, ротация и восстановление появляются здесь по мере того, как происходят.';

  @override
  String get p2pActivityNote => 'Полная история — в журналах сервера.';

  @override
  String get p2pFromNetwork => 'Из сети';

  @override
  String get p2pFindSimilar => 'Найти похожую музыку в сети';

  @override
  String p2pFindSimilarSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Открывает «Открытия» для играющего трека · подсказки из $count загруженных библиотек',
      many:
          'Открывает «Открытия» для играющего трека · подсказки из $count загруженных библиотек',
      few:
          'Открывает «Открытия» для играющего трека · подсказки из $count загруженных библиотек',
      one:
          'Открывает «Открытия» для играющего трека · подсказки из $count загруженной библиотеки',
    );
    return '$_temp0';
  }

  @override
  String get p2pFindSimilarNothingPlaying =>
      'Сначала включите что-нибудь — «Открытия» следуют за текущим треком';

  @override
  String get p2pNewArtistsOnlySub =>
      'Скрывать подсказки по исполнителям, которые уже есть в этой библиотеке';

  @override
  String get p2pServersYouFollow => 'Серверы, за которыми вы следите';

  @override
  String get p2pServersOnNetwork => 'Серверы в сети';

  @override
  String get p2pNoServersYet =>
      'Пока ни одного сервера — добавьте сервер по билету друга или дайте сети минуту.';

  @override
  String p2pHiddenIncompatible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count серверов скрыто — несовместимая модель',
      many: '$count серверов скрыто — несовместимая модель',
      few: '$count сервера скрыты — несовместимая модель',
      one: '$count сервер скрыт — несовместимая модель',
    );
    return '$_temp0';
  }

  @override
  String get p2pShow => 'Показать';

  @override
  String get p2pHide => 'Скрыть';

  @override
  String get p2pBefriend => 'Добавить сервер друга';

  @override
  String get p2pOnline => 'в сети';

  @override
  String p2pOfflineFor(String ago) {
    return 'не в сети $ago';
  }

  @override
  String p2pTracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count треков',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
    );
    return '$_temp0';
  }

  @override
  String p2pSeedersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сидов',
      many: '$count сидов',
      few: '$count сида',
      one: '$count сид',
    );
    return '$_temp0';
  }

  @override
  String get p2pChipDownloaded => 'загружено';

  @override
  String get p2pChipUpdate => 'есть обновление';

  @override
  String get p2pChipNotDownloaded => 'не загружено';

  @override
  String get p2pChipPinned => 'закреплено';

  @override
  String get p2pChipIncompatible => 'несовместимая модель';

  @override
  String get p2pChipFederated => 'объединено';

  @override
  String get p2pChipTheyAsked => 'они попросили вас';

  @override
  String get p2pChipRequestSent => 'запрос отправлен';

  @override
  String get p2pSearchingTitle => 'Поиск пиров';

  @override
  String get p2pSearchingBody =>
      'Сеть собирается около минуты. Этот экран обновляется сам.';

  @override
  String get p2pReconnectingTitle => 'Переподключение';

  @override
  String p2pReconnectingBody(int n) {
    return 'Вспомогательный процесс (sidecar) упал и перезапускается (попытка $n) — ничего делать не нужно.';
  }

  @override
  String get p2pJoinTitle => 'Рекомендации из чужих библиотек';

  @override
  String get p2pWhatShared => 'Что передаётся';

  @override
  String get p2pShared1 => 'Снимок только из метаданных';

  @override
  String get p2pShared1Sub =>
      'Исполнитель, название, длительность, звуковые отпечатки — никогда аудиофайлы';

  @override
  String get p2pShared2 => 'Имя и описание вашего сервера';

  @override
  String get p2pShared2Sub =>
      'Видны всем в сети, по умолчанию в публичной сети сообщества';

  @override
  String get p2pHowYouAppear => 'Как вас видят';

  @override
  String get p2pServerName => 'Имя сервера';

  @override
  String get p2pServerNameHint =>
      '«mStream» рядом с 18 000 других «mStream» — первое, что захочется поменять.';

  @override
  String get p2pDescription => 'Описание';

  @override
  String get p2pDescriptionHint => '180 символов, необязательно.';

  @override
  String get p2pAlsoAcceptRequests => 'Также принимать запросы объединения';

  @override
  String get p2pAlsoAcceptRequestsSub =>
      'Приглашения делиться библиотеками — ничего не передаётся, пока вы не одобрите каждое. Включает федерацию.';

  @override
  String get p2pJoin => 'Подключиться к сети';

  @override
  String get p2pJoining => 'Подключение…';

  @override
  String get p2pJoined => 'Вы в сети обнаружения — дайте ей минуту собраться.';

  @override
  String p2pJoinFailed(String error) {
    return 'Не удалось подключиться к сети: $error';
  }

  @override
  String p2pInboxFailed(String error) {
    return 'Обнаружение включено, но приём запросов не запустился: $error';
  }

  @override
  String get p2pUnavailableNote =>
      'Двоичный файл p2p-sidecar для этой платформы не найден, и загружаемой сборки нет — сеть недоступна.';

  @override
  String get p2pWillDownloadNote =>
      'Вспомогательный процесс (sidecar) ещё не установлен; при подключении он будет загружен.';

  @override
  String get p2pAdminOnlyNote =>
      'Подключиться к сети может только администратор сервера.';

  @override
  String p2pMemberOffNote(String server) {
    return 'Сеть обнаружения на сервере $server выключена. Администратор может её включить.';
  }

  @override
  String p2pMemberNote(String server) {
    return 'Подключение к сети, приглашения и снимки — задачи администратора. Войдите на сервер $server как администратор, чтобы управлять сетью здесь.';
  }

  @override
  String get p2pSnapshotSection => 'Снимок';

  @override
  String p2pDownloadedSize(String size) {
    return 'Загружено · $size';
  }

  @override
  String p2pSnapshotSeq(int seq) {
    return 'Снимок $seq';
  }

  @override
  String p2pNewerAnnounced(int seq) {
    return 'объявлен более новый ($seq)';
  }

  @override
  String get p2pNotDownloaded => 'Не загружено';

  @override
  String get p2pNotDownloadedSub =>
      'Загрузите, чтобы искать по нему в «Открытиях»';

  @override
  String get p2pDownload => 'Загрузить';

  @override
  String get p2pUpdate => 'Обновить';

  @override
  String get p2pDownloading => 'Загрузка…';

  @override
  String get p2pDownloaded => 'Снимок загружен';

  @override
  String p2pDownloadFailed(String error) {
    return 'Не удалось загрузить снимок: $error';
  }

  @override
  String get p2pPin => 'Закрепить этот снимок';

  @override
  String p2pPinSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ротация освобождает наименее используемые снимки через $count дней; закреплённый остаётся.',
      many:
          'Ротация освобождает наименее используемые снимки через $count дней; закреплённый остаётся.',
      few:
          'Ротация освобождает наименее используемые снимки через $count дня; закреплённый остаётся.',
      one:
          'Ротация освобождает наименее используемые снимки через $count день; закреплённый остаётся.',
    );
    return '$_temp0';
  }

  @override
  String get p2pPinSubNoRotation =>
      'Ротация выключена; закреплённый снимок переживёт и нехватку места.';

  @override
  String get p2pRemoveSnapshot => 'Удалить снимок';

  @override
  String get p2pSnapshotRemoved => 'Снимок удалён';

  @override
  String get p2pHeldSince => 'хранится с';

  @override
  String get p2pTracksLabel => 'треков';

  @override
  String get p2pSeedersLabel => 'сидов';

  @override
  String get p2pSeedersSub => 'раздают снимок';

  @override
  String get p2pFederatedWithYou => 'Объединён с вами';

  @override
  String get p2pFederatedWithYouSub =>
      'Откройте «Федерацию», чтобы увидеть, что вы читаете друг у друга';

  @override
  String get p2pTheyAskedYou => 'Просят объединиться';

  @override
  String get p2pTheyAskedYouSub => 'Рассмотрите запрос в разделе «Федерация»';

  @override
  String get p2pRequestSentTitle => 'Запрос отправлен';

  @override
  String get p2pRequestSentSub => 'Ждём ответа · следите в разделе «Федерация»';

  @override
  String get p2pAskToFederate => 'Попросить поделиться библиотеками';

  @override
  String get p2pAskToFederateSub =>
      'Отправляет запрос через сеть — пока ничего не передаётся';

  @override
  String get p2pOpen => 'Открыть';

  @override
  String get p2pReview => 'Рассмотреть';

  @override
  String get p2pForget => 'Забыть этот сервер';

  @override
  String get p2pForgetSub =>
      'Не в сети и ничего не загружено; вернётся, если снова появится';

  @override
  String p2pForgotten(String name) {
    return '$name забыт';
  }

  @override
  String get p2pBlockServer => 'Заблокировать сервер';

  @override
  String p2pBlockConfirm(String name) {
    return 'Заблокировать $name? Его объявления будут игнорироваться, а снимок будет удалён.';
  }

  @override
  String p2pBlocked(String name) {
    return '$name заблокирован';
  }

  @override
  String get p2pUnblock => 'Разблокировать';

  @override
  String get p2pUnblocked => 'Сервер разблокирован';

  @override
  String get p2pIncompatibleNote =>
      'Несовместимая модель эмбеддингов — его библиотека не годится для поиска похожего на этом сервере.';

  @override
  String get p2pCompatible => 'совместимая модель';

  @override
  String get p2pModelUnknown => 'модель неизвестна';

  @override
  String get p2pNoDescription => 'Без описания.';

  @override
  String get p2pUnnamedServer => 'Сервер без имени';

  @override
  String get p2pFederateTitle => 'Попросить объединиться';

  @override
  String get p2pFederateNote =>
      'Отправляет запрос через сеть обнаружения. Сейчас доступ не передаётся — они увидят ваше имя, сообщение и предложение; библиотеки станут общими, только если они согласятся.';

  @override
  String get p2pMessage => 'Сообщение';

  @override
  String p2pMessageHint(int n) {
    return 'Необязательно · $n / 500';
  }

  @override
  String get p2pShareBackLibraries =>
      'Библиотеки, которыми вы поделитесь в ответ, если они согласятся';

  @override
  String get p2pShareBackNote =>
      'Снимите все отметки для односторонней просьбы — вы будете только читать их библиотеки.';

  @override
  String get p2pSendRequest => 'Отправить запрос';

  @override
  String get p2pRequestSent =>
      'Запрос отправлен — следите в разделе «Федерация»';

  @override
  String p2pRequestFailed(String error) {
    return 'Не удалось отправить запрос: $error';
  }

  @override
  String get p2pTheirTicket => 'Их билет';

  @override
  String get p2pTheirTicketHint =>
      'Друг найдёт свой билет в разделе «Пригласить друга» на своём экране P2P-сети.';

  @override
  String get p2pTicketPasted => 'Вставлено из буфера обмена.';

  @override
  String get p2pRememberFriend => 'Запомнить этого друга';

  @override
  String get p2pRememberFriendSub =>
      'Сохраняется в конфигурации сервера, чтобы дружба пережила перезапуски.';

  @override
  String get p2pJoinFriend => 'Подключиться';

  @override
  String get p2pJoinedFriend => 'Подключено — сеть соберётся за минуту';

  @override
  String p2pJoinFriendFailed(String error) {
    return 'Не удалось подключиться: $error';
  }

  @override
  String get p2pNotATicket => 'Это не похоже на билет конечной точки.';

  @override
  String get p2pScanQr => 'Сканировать QR-код';

  @override
  String get p2pScannerTitle => 'Сканировать сетевой билет';

  @override
  String get p2pInviteFriend => 'Пригласить друга';

  @override
  String p2pYourTicketNote(String name) {
    return 'Ваш билет — друг вставляет его здесь на своём телефоне, чтобы добавить $name. Это адрес, а не ключ доступа.';
  }

  @override
  String get p2pTicketCopied => 'Билет скопирован';

  @override
  String p2pShareMessage(String ticket) {
    return 'Добавь мой сервер mStream в сети обнаружения — в приложении mStream открой «P2P-сеть → Добавить сервер друга» и вставь этот билет:\n\n$ticket';
  }

  @override
  String get p2pShareSubject => 'Билет сети обнаружения mStream';

  @override
  String get p2pTicketNotReady =>
      'Вспомогательный процесс (sidecar) ещё не запущен, поэтому делиться пока нечем.';

  @override
  String get p2pSettingsTitle => 'Настройки сети';

  @override
  String get p2pSwitchTitle => 'Сеть обнаружения';

  @override
  String get p2pSwitchSub =>
      'Объявляет в сети снимок только из метаданных. Выключите, чтобы выйти — собранные данные останутся локально.';

  @override
  String get p2pLeaveConfirm =>
      'Выйти из сети обнаружения? Сервер перестанет объявлять и загружать снимки. Локальный подбор по звучанию продолжит работать.';

  @override
  String get p2pLeave => 'Выйти';

  @override
  String get p2pLeft => 'Вы вышли из сети обнаружения';

  @override
  String p2pLeaveFailed(String error) {
    return 'Не удалось выйти из сети: $error';
  }

  @override
  String get p2pEditIdentity => 'Имя и описание';

  @override
  String get p2pIdentitySaved => 'Сохранено — объявлено в сети';

  @override
  String p2pSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get p2pSnapshotsSection => 'Снимки';

  @override
  String get p2pAutoDownload => 'Автозагрузка до';

  @override
  String p2pServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count серверов',
      many: '$count серверов',
      few: '$count серверов',
      one: '$count сервера',
    );
    return '$_temp0';
  }

  @override
  String get p2pStorageCap => 'Лимит хранилища';

  @override
  String get p2pRotate => 'Ротация загрузок';

  @override
  String get p2pForgetOffline => 'Забывать недоступные серверы';

  @override
  String get p2pMeshSection => 'Сеть';

  @override
  String get p2pCommunitySeeds => 'Стартовые серверы сообщества';

  @override
  String get p2pCommunitySeedsOn =>
      'Подключение через публичные стартовые серверы';

  @override
  String get p2pCommunitySeedsOff =>
      'Выключено — только серверы друзей; задаётся в конфигурации сервера';

  @override
  String p2pBlockedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заблокированных серверов',
      many: '$count заблокированных серверов',
      few: '$count заблокированных сервера',
      one: '$count заблокированный сервер',
      zero: 'Нет заблокированных серверов',
    );
    return '$_temp0';
  }

  @override
  String get p2pBlockedSub =>
      'Объявления игнорируются, снимки никогда не загружаются';

  @override
  String get p2pBlockedTitle => 'Заблокированные серверы';

  @override
  String get p2pSaved => 'Сохранено';

  @override
  String get p2pOff => 'Выключена';

  @override
  String get p2pSave => 'Сохранить';

  @override
  String get p2pSearchServers => 'Поиск серверов — имя или описание';

  @override
  String federationInboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count запросов объединения ожидают',
      many: '$count запросов объединения ожидают',
      few: '$count запроса объединения ожидают',
      one: '$count запрос объединения ожидает',
    );
    return '$_temp0';
  }

  @override
  String get federationInboxBannerSub => 'Нажмите, чтобы принять или отклонить';

  @override
  String federationInboxNotificationTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ожидают $count запросов объединения',
      many: 'Ожидают $count запросов объединения',
      few: 'Ожидают $count запроса объединения',
      one: 'Ожидает $count запрос объединения',
    );
    return '$_temp0';
  }

  @override
  String federationInboxNotificationBody(String server) {
    return 'На сервере $server. Откройте, чтобы принять или отклонить.';
  }

  @override
  String get federationInboxChannelName => 'Запросы объединения';

  @override
  String get federationInboxChannelDescription =>
      'На один из ваших серверов пришёл запрос на общий доступ к библиотекам';

  @override
  String get federationNotifyTitle => 'Уведомлять о запросах';

  @override
  String get federationNotifySubtitle =>
      'Уведомление на телефоне, когда запрос приходит при открытом приложении или во время воспроизведения';

  @override
  String get autoRecentlyPlayed => 'Недавно прослушанные';

  @override
  String get settingsSectionListening => 'История прослушиваний';

  @override
  String get settingsHistoryEnabled => 'Сохранять историю прослушиваний';

  @override
  String get settingsHistoryEnabledSubtitle =>
      'Записывает, что воспроизводит этот телефон, — на каждом сервере и для локальных файлов. Хранится только на этом устройстве.';

  @override
  String get settingsHistorySend => 'Отправлять прослушивания на ваши серверы';

  @override
  String get settingsHistorySendSubtitle =>
      'Каждое прослушивание уходит на сервер, где лежит трек (трек пира — на его родительский сервер), чтобы ваша статистика включала этот телефон. Серверы передают данные в Last.fm, только если вы привязали там аккаунт.';

  @override
  String get settingsHistoryClear => 'Очистить историю прослушиваний';

  @override
  String settingsHistoryClearSubtitle(Object size) {
    return 'Удаляет запись на этом телефоне ($size). Серверы сохранят свою.';
  }

  @override
  String get settingsHistoryClearConfirm =>
      'Удалить историю прослушиваний на этом телефоне? Прослушивания, уже отправленные на сервер, останутся там.';

  @override
  String get settingsHistoryCleared => 'История прослушиваний очищена';

  @override
  String settingsHistoryUnsynced(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count прослушивания ждут отправки',
      many: '$count прослушиваний ждут отправки',
      few: '$count прослушивания ждут отправки',
      one: '$count прослушивание ждёт отправки',
      zero: 'Всё синхронизировано',
    );
    return '$_temp0';
  }

  @override
  String songInfoServerPlays(num count, Object server) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count прослушивания на $server',
      many: '$count прослушиваний на $server',
      few: '$count прослушивания на $server',
      one: '$count прослушивание на $server',
    );
    return '$_temp0';
  }

  @override
  String songInfoDevicePlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count прослушивания на этом телефоне',
      many: '$count прослушиваний на этом телефоне',
      few: '$count прослушивания на этом телефоне',
      one: '$count прослушивание на этом телефоне',
    );
    return '$_temp0';
  }

  @override
  String songInfoLastPlayed(Object ago) {
    return 'последний раз $ago';
  }

  @override
  String get listeningTitle => 'Статистика прослушиваний';

  @override
  String get listeningScopeThisPhone => 'Этот телефон';

  @override
  String get listeningScopeSheetTitle => 'Что показывать';

  @override
  String get listeningScopeSheetDevice =>
      'Что воспроизводил этот телефон: все серверы, локальные файлы, офлайн. Хранится на этом устройстве.';

  @override
  String get listeningScopeSheetServer =>
      'Ваши прослушивания на этом сервере из всех приложений — веб-плеера, других телефонов и этого телефона после синхронизации.';

  @override
  String get listeningScopeSheetLegacy =>
      'Статистики прослушиваний пока нет — нужен mStream 6.27 или новее.';

  @override
  String listeningScopeSheetPeer(Object server) {
    return 'Учитываются на $server: треки пира считаются там, где живёт ваш аккаунт.';
  }

  @override
  String get listeningProvenanceDevice =>
      'Что воспроизводил этот телефон, на всех серверах и для локальных файлов. Хранится на этом устройстве.';

  @override
  String listeningProvenanceServer(Object server) {
    return 'Ваши прослушивания на $server из всех приложений, включая треки его пиров.';
  }

  @override
  String listeningProvenancePeer(Object peer, Object server) {
    return 'Ваши прослушивания треков $peer, учтённые на $server.';
  }

  @override
  String listeningProvenanceFallback(Object server) {
    return '$server не ответил — показаны прослушивания этого телефона на нём.';
  }

  @override
  String listeningProvenanceLegacy(Object server) {
    return '$server пока не ведёт статистику прослушиваний (mStream 6.27+) — показаны прослушивания этого телефона на нём.';
  }

  @override
  String listeningUnsynced(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count прослушивания ещё не синхронизированы',
      many: '$count прослушиваний ещё не синхронизированы',
      few: '$count прослушивания ещё не синхронизированы',
      one: '$count прослушивание ещё не синхронизировано',
    );
    return '$_temp0';
  }

  @override
  String get listeningPeriodWeek => 'Эта неделя';

  @override
  String get listeningPeriodMonth => 'Этот месяц';

  @override
  String get listeningPeriodQuarter => 'Этот квартал';

  @override
  String get listeningPeriodYear => 'Этот год';

  @override
  String get listeningPeriodAll => 'За всё время';

  @override
  String get listeningTilePlays => 'Прослушивания';

  @override
  String get listeningTileTime => 'Время прослушивания';

  @override
  String get listeningTileTracks => 'Треки';

  @override
  String get listeningTileSkips => 'Пропуски';

  @override
  String get listeningTileStreak => 'Серия';

  @override
  String get listeningTileSessions => 'Сеансы';

  @override
  String listeningDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get listeningTileSubCounted => 'засчитанные прослушивания';

  @override
  String get listeningTileSubTracks => 'разных треков';

  @override
  String listeningTileSubSkips(Object pct) {
    return '$pct % запусков';
  }

  @override
  String listeningTileSubStreak(Object count) {
    return 'самая длинная: $count';
  }

  @override
  String listeningTileSubSessions(Object duration) {
    return 'около $duration каждый';
  }

  @override
  String get listeningWhenYouListen => 'Когда вы слушаете';

  @override
  String listeningMostAround(Object hour) {
    return 'Больше всего около $hour';
  }

  @override
  String get listeningTop => 'Топ';

  @override
  String get listeningTopTracks => 'Треки';

  @override
  String get listeningTopArtists => 'Исполнители';

  @override
  String get listeningTopAlbums => 'Альбомы';

  @override
  String get listeningByPlays => 'Прослушивания';

  @override
  String get listeningByTime => 'Время';

  @override
  String listeningPlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count прослушивания',
      many: '$count прослушиваний',
      few: '$count прослушивания',
      one: '$count прослушивание',
    );
    return '$_temp0';
  }

  @override
  String listeningTracksCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count трека',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
    );
    return '$_temp0';
  }

  @override
  String get listeningRecent => 'Недавние прослушивания';

  @override
  String get listeningLoadMore => 'Загрузить ещё';

  @override
  String get listeningEmptyTitle => 'Прослушиваний пока нет';

  @override
  String get listeningEmptyDevice =>
      'Прослушивания появляются здесь по мере того, как вы слушаете. Этот телефон ведёт свою запись; ваш сервер ведёт вашу — по всем приложениям.';

  @override
  String listeningEmptyServer(Object server) {
    return 'На $server пока ничего не передано. Прослушивания с этого телефона появятся после синхронизации.';
  }

  @override
  String get listeningEmptyPeriod => 'За этот период ничего нет.';

  @override
  String get listeningOutcomeCompleted => 'Дослушано';

  @override
  String get listeningOutcomeSkipped => 'Пропущено';

  @override
  String get listeningOutcomeStopped => 'Остановлено';

  @override
  String listeningOutcomeAt(Object outcome, Object position) {
    return '$outcome на $position';
  }

  @override
  String get listeningNotCounted => 'не засчитано';

  @override
  String listeningVia(Object peer) {
    return 'через $peer';
  }

  @override
  String listeningRepeats(Object count) {
    return '×$count';
  }

  @override
  String get listeningLocalFile => 'Локальный файл';

  @override
  String get listeningHistoryOff =>
      'История прослушиваний выключена. Включите её в настройках, чтобы записывать прослушивания на этом телефоне.';

  @override
  String listeningError(Object message) {
    return 'Не удалось загрузить: $message';
  }

  @override
  String get listeningRetry => 'Повторить';

  @override
  String get listeningToday => 'Сегодня';

  @override
  String get listeningYesterday => 'Вчера';

  @override
  String get listeningPlaysPerDay => 'Прослушиваний в день';

  @override
  String get listeningPlaysPerMonth => 'Прослушиваний в месяц';

  @override
  String listeningMostOnDay(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Больше всего $date: $count прослушивания',
      many: 'Больше всего $date: $count прослушиваний',
      few: 'Больше всего $date: $count прослушивания',
      one: 'Больше всего $date: $count прослушивание',
    );
    return '$_temp0';
  }

  @override
  String listeningMostInMonth(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Больше всего: $month — $count прослушивания',
      many: 'Больше всего: $month — $count прослушиваний',
      few: 'Больше всего: $month — $count прослушивания',
      one: 'Больше всего: $month — $count прослушивание',
    );
    return '$_temp0';
  }
}
