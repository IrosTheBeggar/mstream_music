// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get mainRemove => 'Remover';

  @override
  String get playlistActionFailed =>
      'Não foi possível guardar a playlist — o nome pode já estar em uso.';

  @override
  String get queueAddNext => 'Adicionar a seguir';

  @override
  String get queuePlayNow => 'Reproduzir agora';

  @override
  String get queueAddToEnd => 'Adicionar ao fim da fila';

  @override
  String get shuffle => 'Aleatório';

  @override
  String get variousArtists => 'Vários artistas';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystemDefault => 'Padrão do sistema';

  @override
  String get settingsLanguageSubtitle =>
      'O idioma de exibição do app. \"Padrão do sistema\" segue o seu dispositivo.';

  @override
  String couldNotOpen(String url) {
    return 'Não foi possível abrir $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
      zero: 'Nenhuma faixa',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Redefinir';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get tapAddToQueue => 'Adicionar à fila';

  @override
  String get tapPlayFromHere => 'Tocar a partir daqui';

  @override
  String get tapAppendAndJump => 'Adicionar e tocar';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'Shaders';

  @override
  String get visualizerSourceSynthesized => 'Sintetizado';

  @override
  String get visualizerSourceReal => 'Áudio real';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String downloadProgress(String progress) {
    return 'progresso: $progress%';
  }

  @override
  String get songInfoTitle => 'Informações da música';

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsEmpty => 'No lyrics found for this song';

  @override
  String get lyricsError => 'Couldn\'t load lyrics';

  @override
  String get lyricsRetry => 'Retry';

  @override
  String get eqTitle => 'Equalizador';

  @override
  String get eqOnlyAndroid => 'O equalizador só está disponível no Android.';

  @override
  String get eqNeedsPlayback =>
      'Inicie uma música para configurar o equalizador.\n\nO equalizador nativo do Android é inicializado junto com a sessão de áudio, então é preciso ter a reprodução ativa antes de conseguir ler o layout das bandas.';

  @override
  String eqInitFailed(String error) {
    return 'Não foi possível inicializar o equalizador:\n$error';
  }

  @override
  String get eqNoBands =>
      'Nenhuma banda de equalização informada pelo driver de áudio deste dispositivo.';

  @override
  String get eqDisabledHint => 'Ative o equalizador para ajustar as bandas.';

  @override
  String get eqEnabledOn => 'Ligado — ganhos aplicados à reprodução';

  @override
  String get eqEnabledOff => 'Desligado — modo bypass';

  @override
  String get cancel => 'Cancelar';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get openSettings => 'Abrir configurações';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsSectionAppearance => 'Aparência';

  @override
  String get settingsSectionPlayback => 'Reprodução';

  @override
  String get settingsSectionBrowse => 'Navegar';

  @override
  String get settingsSectionAbout => 'Sobre';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSubtitleVelvet =>
      'Azul-marinho e roxo — o tema escuro característico.';

  @override
  String get themeSubtitleDark => 'Escuro neutro com detalhes em âmbar.';

  @override
  String get themeSubtitleLight =>
      'Corpo claro com barra superior escura e detalhes em âmbar — combina com o tema antigo.';

  @override
  String get settingsTranscode => 'Transcodificar áudio';

  @override
  String get settingsTranscodeSubtitle =>
      'Transmite uma cópia transcodificada do servidor (arquivos menores, início um pouco mais lento). Desligado, toca os arquivos originais.';

  @override
  String get transcodeTitle => 'Transcodificação';

  @override
  String get transcodeCodec => 'Codec';

  @override
  String get transcodeBitrate => 'Taxa de bits';

  @override
  String get transcodeAuto => 'Padrão do servidor';

  @override
  String get transcodeUnavailable =>
      'Este servidor não tem a transcodificação ativada — as suas faixas são transmitidas na qualidade original.';

  @override
  String get transcodeReloadQueue => 'Aplicar à fila atual';

  @override
  String get transcodeReloadQueueSubtitle =>
      'Ao alterar as definições de transcodificação — marcado: recarregar toda a fila agora (a faixa em reprodução faz buffer por instantes); desmarcado: só mudam as faixas seguintes, a atual termina sem alterações.';

  @override
  String get settingsTapBehavior => 'Ao tocar em uma música';

  @override
  String get settingsStartupPage => 'Tela inicial';

  @override
  String get settingsStartupPageSubtitle =>
      'Abrir o app nesta visualização do navegador; Voltar retorna ao navegador.';

  @override
  String get tapSubtitleAddToQueue =>
      'Tocar em uma música a adiciona à fila. Se a fila estiver vazia, a reprodução começa automaticamente.';

  @override
  String get tapSubtitlePlayFromHere =>
      'Tocar em uma música substitui a fila pelas músicas da visualização atual e inicia a reprodução pela música tocada.';

  @override
  String get tapSubtitleAppendAndJump =>
      'Tocar em uma música a adiciona à fila e pula a reprodução para ela, interrompendo o que estava tocando.';

  @override
  String get settingsEqSubtitle =>
      'Ajuste graves, médios e agudos. Apenas no Android.';

  @override
  String get settingsVisualizerEngine => 'Motor do visualizador';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'Predefinições do Milkdrop via projectM (padrão). Efeitos mais ricos, mais pesados para a GPU.';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Shaders de fragmento no estilo Shadertoy. Mais leves e modulares — coloque arquivos .glsl em assets/shaders/ para ampliar o catálogo.';

  @override
  String get settingsVisualizerSource => 'Fonte de áudio do visualizador';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'Padrão. O visualizador reage apenas ao tempo da reprodução — não exige permissão de microfone.';

  @override
  String get visualizerSourceSubtitleReal =>
      'O visualizador reage à saída de áudio real. Exige a permissão RECORD_AUDIO no Android.';

  @override
  String get settingsAlbumGrid => 'Visualização em grade de álbuns';

  @override
  String get settingsAlbumGridSubtitle =>
      'Mostra os álbuns como uma grade de cartões com capas em vez de uma lista simples.';

  @override
  String get settingsFileMetadata =>
      'Ler metadados das músicas no explorador de arquivos';

  @override
  String get settingsFileMetadataSubtitle =>
      'Busca título, artista e capa de cada música ao navegar pelos arquivos do servidor. Desligado, mostra os nomes brutos dos arquivos (mais rápido em pastas enormes).';

  @override
  String get settingsLetterStrip => 'Limite do scrubber de letras';

  @override
  String get settingsLetterStripSubtitle =>
      'Mostra a barra de navegação rápida A-Z quando uma lista tiver esta quantidade de itens ou mais. Abaixo disso, a barra fica oculta e nomes longos de pastas/arquivos quebram em várias linhas em vez de serem cortados. Defina 0 para sempre mostrar a barra.';

  @override
  String get settingsLetterStripSide => 'Lado da barra';

  @override
  String get settingsLetterStripSideSubtitle =>
      'Em que extremidade fica a barra A–Z.';

  @override
  String get settingsLetterStripLeft => 'Esquerda';

  @override
  String get settingsLetterStripRight => 'Direita';

  @override
  String get settingsReset => 'Restaurar padrões';

  @override
  String get settingsResetSubtitle =>
      'Restaura todas as configurações desta tela aos valores padrão. Servidores e downloads não são afetados.';

  @override
  String get settingsResetDone => 'Configurações restauradas aos padrões';

  @override
  String get realAudioDialogTitle => 'Usar áudio real?';

  @override
  String get realAudioDialogBody =>
      'O modo de áudio real lê a forma de onda da música que o seu celular está tocando para que o visualizador possa reagir a ela. O Android exige a permissão RECORD_AUDIO para isso — o app não grava nem envia áudio a lugar nenhum. Você pode voltar para o sintetizado a qualquer momento.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Permissão negada permanentemente. Ative-a nas configurações do sistema para usar áudio real.';

  @override
  String get realAudioPermDenied =>
      'Permissão negada. Mantendo o áudio sintetizado.';

  @override
  String get visualizerTapHint =>
      'Toque = próxima predefinição · pressione e segure para fechar';

  @override
  String get visualizerFailed => 'Falha ao iniciar o visualizador';

  @override
  String get visualizerBringingUp => 'Inicializando o renderizador…';

  @override
  String get visualizerReady => 'Visualizador pronto';

  @override
  String get visualizerBridgeFailed => 'Falha ao iniciar a ponte';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Fonte de áudio: $source';
  }

  @override
  String get visualizerTapToClose => 'Toque em qualquer lugar para fechar';

  @override
  String get visualizerUnsupported =>
      'O visualizador só é compatível com o Android no momento.';

  @override
  String get aboutTitle => 'Sobre';

  @override
  String aboutBuiltBy(String name) {
    return 'Criado por $name';
  }

  @override
  String get linkDiscordSubtitle => 'Bate-papo da comunidade';

  @override
  String get linkGithubSubtitle => 'Código-fonte do servidor mStream';

  @override
  String get linkHomepageSubtitle => 'Página do projeto';

  @override
  String get aboutAttributions => 'Créditos';

  @override
  String get aboutAttributionsSubtitle =>
      'Licença, créditos de shaders e avisos de código aberto.';

  @override
  String get aboutSponsor => 'Apoiar o mStream';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Excluir';

  @override
  String get edit => 'Editar';

  @override
  String get info => 'Informações';

  @override
  String get makeDefault => 'Tornar padrão';

  @override
  String get goBack => 'Voltar';

  @override
  String get play => 'Tocar';

  @override
  String get playAll => 'Tocar tudo';

  @override
  String get rename => 'Renomear';

  @override
  String get create => 'Criar';

  @override
  String get copy => 'Copiar';

  @override
  String get done => 'Concluído';

  @override
  String get copiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get attributionsTitle => 'Créditos';

  @override
  String get attributionsSectionLicense => 'Licença';

  @override
  String get attributionsSectionShaders => 'Shaders do visualizador';

  @override
  String get attributionsSectionLibraries => 'Bibliotecas nativas';

  @override
  String get attributionsSectionEverythingElse => 'Tudo o mais';

  @override
  String get attributionsLicenseBody =>
      'Software livre sob a GNU General Public License v3.0. Você pode usá-lo, estudá-lo, compartilhá-lo e modificá-lo sob esses termos.';

  @override
  String get attributionsPackages => 'Licenças de pacotes de código aberto';

  @override
  String get attributionsPackagesSubtitle =>
      'Textos completos das licenças de todos os pacotes Flutter/Dart incluídos.';

  @override
  String get manageServersTitle => 'Gerenciar servidores';

  @override
  String get manageServerInfo => 'Informações do servidor';

  @override
  String get manageServerDownloadFolder => 'Pasta de download:';

  @override
  String get manageServerCopyPath => 'Copiar caminho de download';

  @override
  String get manageServerPathCopied =>
      'Caminho copiado para a área de transferência';

  @override
  String get confirmRemoveServerTitle => 'Confirmar remoção do servidor';

  @override
  String get removeSyncedFiles =>
      'Remover arquivos sincronizados do dispositivo?';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistsNew => 'Nova playlist';

  @override
  String get playlistsEmptyTitle => 'Nenhuma playlist ainda';

  @override
  String get playlistsEmptyBody =>
      'Crie uma com o botão Nova playlist e depois use o gesto de deslizar Adicionar à playlist na fila para preenchê-la.';

  @override
  String get playlistNameHint => 'Nome';

  @override
  String get playlistsRename => 'Renomear playlist';

  @override
  String get playlistFallbackTitle => 'Playlist';

  @override
  String get playlistEmptyDetail =>
      'A playlist está vazia.\nAdicione faixas pela fila.';

  @override
  String get shareEmptyTitle => 'Fila vazia';

  @override
  String get shareEmptyBody => 'Adicione músicas à fila antes de compartilhar.';

  @override
  String get shareBlockedTitle => 'Não é possível compartilhar esta fila';

  @override
  String get shareLocalOnlyBody =>
      'A fila contém músicas que estão apenas neste dispositivo (não em nenhum servidor). O compartilhamento só funciona quando todas as músicas da fila vêm de um único servidor.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'A fila mistura músicas de $count servidores ($names). O compartilhamento só funciona quando todas as músicas vêm de um único servidor.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'O servidor \"$name\" não está mais na sua lista de servidores. Adicione-o novamente para compartilhar a fila dele.';
  }

  @override
  String get shareTitle => 'Compartilhar playlist';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return '$_temp0 de $url';
  }

  @override
  String get shareLinkExpires => 'O link expira';

  @override
  String get shareExpireNever => 'Nunca';

  @override
  String get shareExpire1Day => 'Após 1 dia';

  @override
  String get shareExpire7Days => 'Após 7 dias';

  @override
  String get shareExpire30Days => 'Após 30 dias';

  @override
  String get shareAction => 'Compartilhar';

  @override
  String get shareDoneTitle => 'Playlist compartilhada';

  @override
  String get shareDoneBody =>
      'Qualquer pessoa com este link pode tocar a fila:';

  @override
  String get save => 'Salvar';

  @override
  String get start => 'Iniciar';

  @override
  String get addServerTitle => 'Adicionar servidor';

  @override
  String get editServerTitle => 'Editar servidor';

  @override
  String get fieldServerUrl => 'URL do servidor';

  @override
  String get fieldPublicAccess => 'Acesso público';

  @override
  String get publicAccessSubtitle =>
      'O servidor é acessível publicamente — não é preciso usuário nem senha.';

  @override
  String get fieldUsername => 'Usuário';

  @override
  String get fieldPassword => 'Senha';

  @override
  String get fieldPasswordShow => 'Show password';

  @override
  String get fieldPasswordHide => 'Hide password';

  @override
  String get fieldSdCard => 'Baixar para o cartão SD';

  @override
  String get sdCardSubtitle =>
      'Salva a música baixada no cartão SD removível em vez do armazenamento interno.';

  @override
  String get testConnectionButton => 'Testar conexão';

  @override
  String get testing => 'Testando…';

  @override
  String get connecting => 'Conectando…';

  @override
  String get validatorUrlNeeded => 'A URL do servidor é necessária';

  @override
  String get validatorUrlParse => 'Não foi possível interpretar a URL';

  @override
  String get testEnterUrl => 'Informe uma URL de servidor primeiro.';

  @override
  String get testParseUrl => 'Não foi possível interpretar a URL.';

  @override
  String get testTimedOut => 'Tempo de conexão esgotado.';

  @override
  String get connectionSuccessful => 'Conexão bem-sucedida!';

  @override
  String get couldNotReachServer =>
      'Não foi possível acessar o servidor. Se ele exigir login, desative o \"Acesso público\" e adicione as credenciais.';

  @override
  String get failedToLogin => 'Falha ao fazer login';

  @override
  String testConnected(String version) {
    return 'Conectado — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'Não foi possível conectar: $error';
  }

  @override
  String get sleepTimerTitle => 'Temporizador para dormir';

  @override
  String get sleepTimerHint =>
      'Escolha uma duração para pausar a reprodução depois.';

  @override
  String get sleepTimerCustom => 'Personalizado';

  @override
  String get sleepTimerCustomHint => 'minutos (1–600)';

  @override
  String get sleepTimerCancel => 'Cancelar temporizador';

  @override
  String get sleepTimerInvalid => 'Informe um número entre 1 e 600 minutos';

  @override
  String sleepTimerPausesIn(String time) {
    return 'Pausa em $time';
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
      other: 'Temporizador definido para $minutes minutos',
      one: 'Temporizador definido para 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Adicionar';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String get autoDjAddServerFirst => 'Adicione um servidor primeiro.';

  @override
  String get autoDjSectionServer => 'Servidor';

  @override
  String get autoDjSectionSources => 'Fontes';

  @override
  String get autoDjSectionContinuity => 'Continuidade';

  @override
  String get autoDjSectionFilters => 'Filtros';

  @override
  String get autoDjMultiServerTitle => 'Reproduzir de todos os servidores';

  @override
  String get autoDjMultiServerSubtitle =>
      'O Auto DJ escolhe de todos os servidores ao mesmo tempo, seguindo o som atual';

  @override
  String get autoDjMultiServerNeedsSonic =>
      'Requer Semelhança sonora ativada, abaixo';

  @override
  String get autoDjSectionShared => 'A sessão';

  @override
  String get autoDjSectionPerServer => 'Cada biblioteca';

  @override
  String get autoDjEditingServer => 'Configurações de';

  @override
  String autoDjMultiServerAllIn(int count) {
    return '$count servidores estão participando';
  }

  @override
  String autoDjMultiServerConnecting(int count) {
    return '$count ainda conectando';
  }

  @override
  String autoDjMultiServerSomeExcluded(int count, int total) {
    return '$count de $total servidores participando — aos demais falta discovery, um modelo de embeddings compatível ou uma versão de servidor recente o bastante';
  }

  @override
  String get autoDjBpmTitle => 'Continuidade de BPM';

  @override
  String get autoDjBpmSubtitle =>
      'Prefere escolhas dentro de uma faixa de andamento da música atual. Considera a equivalência de meio/dobro de andamento.';

  @override
  String get autoDjTolerance => 'Tolerância';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Mixagem harmônica';

  @override
  String get autoDjHarmonicSubtitle =>
      'Prefere escolhas em tons que combinam bem com a música travada (vizinhos na roda Camelot).';

  @override
  String get autoDjDurationTitle => 'Duração da faixa';

  @override
  String get autoDjDurationSubtitle =>
      'Ignora interlúdios e mixes longos, escolhendo apenas faixas dentro de uma faixa de duração';

  @override
  String get autoDjDurationRange => 'Duração';

  @override
  String get autoDjDurationAny => 'Qualquer duração';

  @override
  String autoDjDurationOver(String min) {
    return 'Acima de $min';
  }

  @override
  String autoDjDurationUnder(String max) {
    return 'Abaixo de $max';
  }

  @override
  String autoDjDurationBetween(String min, String max) {
    return 'De $min a $max';
  }

  @override
  String get autoDjDurationAllowUnknown =>
      'Incluir faixas de duração desconhecida';

  @override
  String get autoDjDurationAllowUnknownSub =>
      'Faixas cuja duração seu servidor não leu são ignoradas caso contrário';

  @override
  String get autoDjStatusOn => 'O Auto DJ está ligado';

  @override
  String get autoDjStatusOff => 'O Auto DJ está desligado';

  @override
  String get autoDjStatusOffDetail =>
      'Toque abaixo para iniciar. A biblioteca do servidor atual será usada.';

  @override
  String get autoDjStart => 'Iniciar Auto DJ';

  @override
  String get autoDjStop => 'Parar Auto DJ';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'As músicas são escolhidas de $url quando a fila fica curta.';
  }

  @override
  String get autoDjOneSourceRequired => 'É necessária pelo menos uma fonte.';

  @override
  String get autoDjMinRating => 'Avaliação mínima';

  @override
  String get autoDjMinRatingSubtitle =>
      'Escolhe apenas músicas com esta avaliação ou superior.';

  @override
  String get autoDjRatingAny => 'Qualquer';

  @override
  String get autoDjGenreTitle => 'Filtro de gênero';

  @override
  String get autoDjGenreSubtitle =>
      'A lista de permissões toca só faixas correspondentes; a lista de bloqueios as ignora.';

  @override
  String get autoDjWhitelist => 'Lista de permissões';

  @override
  String get autoDjBlacklist => 'Lista de bloqueios';

  @override
  String get autoDjNoGenres =>
      'Nenhum gênero selecionado. Toque em \"Escolher gêneros\" para selecionar.';

  @override
  String get autoDjPickGenres => 'Escolher gêneros';

  @override
  String get autoDjGenreLoadError => 'Não foi possível carregar os gêneros';

  @override
  String get autoDjKeywordTitle => 'Filtro de palavras-chave';

  @override
  String get autoDjKeywordSubtitle =>
      'Ignora escolhas cujo título, artista, álbum ou caminho contenha qualquer uma destas palavras.';

  @override
  String get autoDjNoKeywords =>
      'Nenhuma palavra-chave. Adicione palavras abaixo para começar a filtrar.';

  @override
  String get autoDjKeywordHint => 'ex.: \"live\" ou \"remix\"';

  @override
  String get autoDjSearchGenres => 'Pesquisar gêneros…';

  @override
  String get autoDjNoGenresOnServer =>
      'Nenhum gênero encontrado neste servidor.';

  @override
  String autoDjSelectedCount(int count) {
    return '$count selecionado(s)';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return 'Nenhum gênero corresponde a \"$query\".';
  }

  @override
  String get download => 'Baixar';

  @override
  String get addAll => 'Adicionar tudo';

  @override
  String get browserMoreActions => 'Mais ações';

  @override
  String get browserConfirmDeletePlaylist => 'Confirmar exclusão da playlist';

  @override
  String get browserConfirmDeleteFolder => 'Confirmar exclusão da pasta';

  @override
  String get browserSearchHint => 'Pesquisar no banco de dados';

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
      other: '$count downloads iniciados',
      one: '1 download iniciado',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas adicionadas à fila',
      one: '1 música adicionada à fila',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Navegador';

  @override
  String get tabQueue => 'Fila';

  @override
  String get drawerTagline => 'Streaming pessoal de música';

  @override
  String get mainFailedToConnect => 'Falha ao conectar ao servidor';

  @override
  String get mainQueueEmpty => 'A fila está vazia';

  @override
  String get visualizerTitle => 'Visualizador';

  @override
  String get mainClearQueue => 'Limpar fila';

  @override
  String get mainSync => 'Sincronizar';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ ativado';

  @override
  String get autoDjDisabled => 'Auto DJ desativado';

  @override
  String autoDjEnabledFor(String url) {
    return 'Auto DJ ativado para $url';
  }

  @override
  String get addToPlaylistTitle => 'Adicionar à playlist';

  @override
  String get addToPlaylistEmpty =>
      'Nenhuma playlist ainda — toque em + para criar uma.';

  @override
  String addedToPlaylist(String name) {
    return 'Adicionado a $name';
  }

  @override
  String get testConnectedSignedIn => 'Conectado — login efetuado com sucesso.';

  @override
  String get testSignInFailed =>
      'Servidor acessível, mas o login falhou — verifique seu usuário e senha.';

  @override
  String get browserFileExplorer => 'Explorador de arquivos';

  @override
  String get browserLocalFiles => 'Arquivos locais';

  @override
  String get browserPlaylists => 'Playlists';

  @override
  String get browserAlbums => 'Álbuns';

  @override
  String get browserArtists => 'Artistas';

  @override
  String get browserRecent => 'Recentes';

  @override
  String get browserRated => 'Avaliadas';

  @override
  String get browserSectionLibrary => 'Biblioteca';

  @override
  String get browserSectionListen => 'Ouvir';

  @override
  String get browserSectionNetwork => 'Rede';

  @override
  String get browserSectionServer => 'Servidor';

  @override
  String get browserFederation => 'Federação';

  @override
  String get browserAutoDjOn => 'Ligado';

  @override
  String get browserAutoDjOff => 'Desligado';

  @override
  String browserSharedLibraries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bibliotecas compartilhadas',
      one: '1 biblioteca compartilhada',
    );
    return '$_temp0';
  }

  @override
  String get browserSearch => 'Pesquisar';

  @override
  String get browserWelcomeTitle => 'Bem-vindo ao mStream';

  @override
  String get browserWelcomeSubtitle => 'Toque aqui para adicionar um servidor';

  @override
  String get settingsVisualizerKnobs => 'Controles de ajuste do visualizador';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      'Mostra controles deslizantes sobre o visualizador para ajustar a reatividade de áudio de cada shader. Apenas no motor de shaders.';

  @override
  String get visualizerTuningTitle => 'Ajuste';

  @override
  String get close => 'Fechar';

  @override
  String get migMoveStopped =>
      'Movimentação interrompida — espaço insuficiente ou o local está indisponível.';

  @override
  String get migMoveComplete => 'Movimentação concluída';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Movimentação concluída — $count arquivos ignorados (sem suporte no destino)',
      one:
          'Movimentação concluída — 1 arquivo ignorado (sem suporte no destino)',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'Movendo downloads… $progress — mantenha o app aberto';
  }

  @override
  String get migRetry => 'Tentar novamente';

  @override
  String get queueDownloadAll => 'Baixar tudo';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas serão baixadas para reprodução offline.',
      one: '1 faixa será baixada para reprodução offline.',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'Mais';

  @override
  String get commonOn => 'Ligado';

  @override
  String get commonOff => 'Desligado';

  @override
  String get settingsCastQuality => 'Qualidade do visualizador na transmissão';

  @override
  String get settingsCastQualitySubtitle720 =>
      'Resolução em que o visualizador é transmitido para a TV. 720p — a mais leve para o celular.';

  @override
  String get settingsCastQualitySubtitle1080 =>
      'Resolução em que o visualizador é transmitido para a TV. 1080p — nítida em qualquer Chromecast (padrão).';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Resolução em que o visualizador é transmitido para a TV. 4K — exige um Chromecast 4K; muito mais pesada para o celular.';

  @override
  String get eqCasting =>
      'O equalizador ajusta o áudio neste dispositivo, então fica indisponível durante a transmissão. Desconecte para usá-lo.';

  @override
  String get browserNothingToDownload => 'Nada para baixar nesta lista';

  @override
  String get browserDownloadAllTitle => 'Baixar tudo';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos serão baixados.',
      one: '1 arquivo será baixado.',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => 'Fechar pesquisa';

  @override
  String get browserSearchThisList => 'Pesquisar nesta lista';

  @override
  String get browserSearchList => 'Pesquisar na lista';

  @override
  String browserNoMatches(String query) {
    return 'Nenhum resultado para \"$query\"';
  }

  @override
  String get clear => 'Limpar';

  @override
  String get dlLocationUnavailable => 'Local de download indisponível';

  @override
  String get dlLocationUnavailableServer =>
      'Local de download indisponível para este servidor.';

  @override
  String get dlFailed => 'Um download falhou — verifique sua conexão.';

  @override
  String get dlFatSkip =>
      'Algumas faixas não podem ser salvas neste cartão — os nomes delas não são compatíveis. Em vez disso, são transmitidas.';

  @override
  String get dlServerGone => 'Esse servidor não está mais configurado.';

  @override
  String get dlStorageUnavailable =>
      'Local de armazenamento indisponível — reconecte o cartão SD ou altere o local de armazenamento deste servidor em Editar servidor.';

  @override
  String get dlCouldNotStart =>
      'Não foi possível iniciar o download — armazenamento indisponível.';

  @override
  String get storageLocationLabel => 'Local de armazenamento';

  @override
  String get storageAppLocal => 'Local do app';

  @override
  String get storagePermanent => 'Permanente';

  @override
  String get storageSdCard => 'Cartão SD';

  @override
  String get storageSdSwitchTitle => 'Save to SD card';

  @override
  String get storageSdSwitchSubtitle =>
      'Stored in the SD card\'s app folder — no permission needed, but removed if you uninstall the app.';

  @override
  String get storageHelpAppLocal =>
      'Salvo dentro do app. Excluído ao desinstalar ou limpar o app.';

  @override
  String get storageHelpPermanent =>
      'Salvo em uma pasta que você escolher. Permanece após desinstalar o app. Exige o \"Acesso a todos os arquivos\".';

  @override
  String get storageHelpSdCard =>
      'Salvo em uma pasta do cartão SD que você escolher. Pode ficar indisponível se o cartão for removido. Alguns dispositivos não permitem que apps gravem em cartões SD — se a seleção de pasta continuar falhando, use Permanente ou Local do app.';

  @override
  String get storageChooseFolder => 'Escolher pasta';

  @override
  String get storageNoFolderChosen => 'Nenhuma pasta escolhida ainda';

  @override
  String get storageDownloadFolderLabel => 'Pasta de download';

  @override
  String get storageDownloadFolderHint => 'nome da pasta';

  @override
  String get storageBrowse => 'Procurar';

  @override
  String get storageDownloadFolderHelp =>
      'Os arquivos são baixados em um diretório \'media/<folder>\' neste dispositivo. Reutilizar a pasta de um servidor anterior mantém as músicas baixadas dele quando você readiciona um servidor perdido.';

  @override
  String get storageNoStorageAvailable => 'Nenhum armazenamento disponível';

  @override
  String get storageNoDownloadFolders =>
      'Nenhuma pasta de download existente encontrada';

  @override
  String get storageExistingFolders => 'Pastas de download existentes';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'Conceda o \"Acesso a todos os arquivos\" para armazenar downloads permanentemente e depois escolha o modo novamente.';

  @override
  String get storageSettings => 'Configurações';

  @override
  String get storageNoVolume =>
      'Não foi possível localizar um volume de armazenamento';

  @override
  String get storageNotWritable =>
      'Essa pasta não permite gravação — escolha outra.';

  @override
  String get storageNewFolder => 'Nova pasta';

  @override
  String get storageFolderNameHint => 'Nome da pasta';

  @override
  String get storageCouldNotCreateFolder => 'Não foi possível criar a pasta';

  @override
  String get storageNoSubfolders => 'Nenhuma subpasta aqui';

  @override
  String get storageUseThisFolder => 'Usar esta pasta';

  @override
  String get storageMovedToNewFolder =>
      'Arquivos baixados movidos para a nova pasta.';

  @override
  String get storageMoveAlreadyRunning =>
      'Uma movimentação já está em andamento — deixe-a terminar primeiro.';

  @override
  String get storageMigrateTitle => 'Volume de armazenamento diferente';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Os $count arquivos baixados deste servidor ($size) estão em um volume de armazenamento diferente do novo local. Escolha o que fazer:',
      one:
          'O 1 arquivo baixado deste servidor ($size) está em um volume de armazenamento diferente do novo local. Escolha o que fazer:',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return 'Espaço livre insuficiente no destino ($free livres). A movimentação pode falhar no meio — libere espaço primeiro.';
  }

  @override
  String get storageMigrateMove => 'Mover';

  @override
  String get storageMigrateMoveBody =>
      'Copia para o novo local em segundo plano, excluindo cada cópia antiga conforme avança. Mantenha o app aberto até concluir.';

  @override
  String get storageMigrateLeave => 'Manter onde estão';

  @override
  String get storageMigrateLeaveBody =>
      'Troca agora; os downloads antigos permanecem onde estão e são baixados novamente no novo local.';

  @override
  String get storageMigrateDelete => 'Excluir downloads antigos';

  @override
  String get storageMigrateDeleteBody =>
      'Troca agora e remove os arquivos antigos; eles serão baixados novamente no novo local.';

  @override
  String get storageMovingBackground =>
      'Movendo seus downloads em segundo plano — mantenha o app aberto.';

  @override
  String get storageChooseFolderFirst =>
      'Escolha uma pasta de download primeiro.';

  @override
  String get storageChooseSdFolderFirst =>
      'Escolha uma pasta no cartão SD primeiro. Se todas as pastas forem rejeitadas, talvez seu dispositivo não permita que apps gravem no cartão — use Permanente ou Local do app.';

  @override
  String get castPlayOn => 'Tocar em';

  @override
  String get castPlayOnTooltip => 'Tocar em…';

  @override
  String get castSearching => 'Procurando dispositivos de transmissão…';

  @override
  String get castNotSeeing =>
      'Não está vendo seu dispositivo? Verifique se ele está na mesma rede Wi-Fi.';

  @override
  String get castVisualizer => 'Transmitir o visualizador';

  @override
  String get castVisualizerSubtitle =>
      'Transmite o visualizador para a TV · apenas Chromecast';

  @override
  String get visualizerNoKnobs => 'Este shader não expõe nenhum controle.';

  @override
  String get nowPlaying => 'Tocando agora';

  @override
  String get playerLayoutSmall => 'Pequeno';

  @override
  String get playerLayoutMedium => 'Médio';

  @override
  String get playerLayoutLarge => 'Grande';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => 'Barra fina — fila máxima';

  @override
  String get playerLayoutMediumDesc => 'Banner — equilibrado (padrão)';

  @override
  String get playerLayoutLargeDesc => 'Compacto — capa centralizada';

  @override
  String get playerLayoutXlDesc => 'Destaque — capa completa';

  @override
  String get queueNothingToDownloadEmpty =>
      'A fila está vazia — nada para baixar';

  @override
  String get queueNothingToDownloadSaved =>
      'Nada para baixar — as faixas já estão salvas';

  @override
  String get settingsAccentColor => 'Cor de destaque';

  @override
  String get settingsAccentColorSubtitle =>
      'A cor de destaque usada em todo o aplicativo.';

  @override
  String get accentThemeDefault => 'Padrão do tema';

  @override
  String get accentCustom => 'Personalizado';

  @override
  String get lanOnYourNetwork => 'Servidores na sua rede local';

  @override
  String get lanSearching => 'Procurando servidores…';

  @override
  String get lanRefresh => 'Atualizar';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return 'Entrar em $name';
  }

  @override
  String get lanUnreachable =>
      'Não foi possível alcançar este servidor na rede.';

  @override
  String get lanNoCode =>
      'O Quick Connect está ativado neste servidor, mas ele não compartilhou um código de pareamento. Entre como administrador ou peça ao operador para ativar o compartilhamento do código.';

  @override
  String get settingsResumeQueue => 'Retomar a fila ao iniciar';

  @override
  String get settingsResumeQueueSubtitle =>
      'Salva a fila de reprodução e sua posição e as restaura ao reabrir o app.';

  @override
  String get settingsOfflineQueue => 'Manter a fila disponível offline';

  @override
  String get settingsOfflineQueueSubtitle =>
      'Baixa automaticamente as faixas da fila para este dispositivo, para que a reprodução sobreviva à perda de conexão.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Baixar somente por Wi-Fi';

  @override
  String get settingsOfflineQueueWifiOnlySubtitle =>
      'Aguarda uma conexão Wi-Fi antes de baixar as faixas da fila.';

  @override
  String get settingsAutoDownloadCap => 'Auto-download limit';

  @override
  String get settingsAutoDownloadCapSubtitle =>
      'Guarda esta quantidade de músicas a partir da atual; as que ficam para trás são removidas.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Guarda a fila inteira (sem limite).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unlimited';

  @override
  String get settingsAutoDownloadCapField => 'Number of tracks';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Quantas músicas da fila permanecem baixadas, contando a partir da atual. Conforme a reprodução avança, as que ficam para trás são excluídas. 0 para a fila inteira.';

  @override
  String get downloadWaitingWifi => 'Aguardando Wi-Fi';

  @override
  String get settingsRatingHalf => 'Avaliações de meia estrela';

  @override
  String get settingsRatingHalfSubtitle =>
      'Avalie músicas em passos de meia estrela (mantenha uma estrela pressionada).';

  @override
  String get ratingTitle => 'Avaliar';

  @override
  String get ratingFailed => 'Não foi possível salvar a avaliação';

  @override
  String get diagnosticsTitle => 'Diagnóstico';

  @override
  String get diagnosticsEnable => 'Ativar registro';

  @override
  String get diagnosticsHint =>
      'Os registros ficam no seu dispositivo. Os tokens são ocultados antes de copiar ou compartilhar.';

  @override
  String get diagnosticsVerbose => 'Verbose logging';

  @override
  String get diagnosticsVerboseHint =>
      'Also logs high-frequency events like app focus changes. Only needed when diagnosing a playback issue.';

  @override
  String get diagnosticsCopy => 'Copiar';

  @override
  String get diagnosticsShare => 'Compartilhar';

  @override
  String get diagnosticsClear => 'Limpar';

  @override
  String get diagnosticsCopied =>
      'Registros copiados para a área de transferência';

  @override
  String get diagnosticsEmpty => 'Ainda não há registros';

  @override
  String get storageAppExternal => 'App externo';

  @override
  String get storageAppSdCard => 'Cartão SD do app';

  @override
  String get selfSignedTitle => 'Permitir certificado autoassinado';

  @override
  String get selfSignedSubtitle =>
      'Ignora a validação TLS deste servidor. Ative apenas em uma rede confiável.';

  @override
  String get importedShadersTitle => 'Shaders importados';

  @override
  String get importedShadersSettingsSubtitle =>
      'Adicione os seus próprios arquivos .glsl à rotação do motor Shader.';

  @override
  String get importedShadersRescan => 'Reanalisar pasta';

  @override
  String get importedShadersDropHint =>
      'Coloque arquivos .glsl nesta pasta e depois Reanalisar:';

  @override
  String get importedShadersCopyPath => 'Copiar caminho';

  @override
  String get importedShadersReachableHint =>
      'Acessível via USB ou um gerenciador de arquivos (em Android/data). Os shaders importados entram na rotação quando o motor Shader está ativo.';

  @override
  String get importedShadersRemove => 'Remover';

  @override
  String get importedShadersEmptyTitle => 'Nenhum shader na pasta ainda';

  @override
  String get importedShadersEmptyBody =>
      'Copie arquivos .glsl no estilo Shadertoy para a pasta acima e depois toque em Reanalisar.';

  @override
  String get importedShadersInvalid =>
      'Pode não ser um shader válido — sem ponto de entrada mainImage/main.';

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
  String get discoverTitle => 'Descobrir';

  @override
  String get discoverMatchedBySound => 'Combinações por som';

  @override
  String get discoverSimilarTracks => 'Faixas semelhantes';

  @override
  String get discoverSimilarArtists => 'Artistas semelhantes';

  @override
  String get discoverFromNetwork => 'Da rede';

  @override
  String get discoverFromPeers => 'Dos seus pares';

  @override
  String get discoverQueueAll => 'Adicionar tudo à fila';

  @override
  String get discoverNewArtistsOnly => 'Apenas artistas novos';

  @override
  String get discoverNotAnalyzed =>
      'Esta música ainda não foi analisada — músicas semelhantes aparecem quando a análise de descoberta chegar a ela.';

  @override
  String get discoverScanPendingTitle => 'Ainda não há nada analisado';

  @override
  String get discoverScanPendingBody =>
      'Este servidor tem a descoberta ativada, mas ainda não analisou nenhuma música. As músicas semelhantes aparecem depois de a análise de descoberta ser executada.';

  @override
  String get discoverCheckAgain => 'Verificar novamente';

  @override
  String get discoverTurnedOff => 'A descoberta foi desativada neste servidor.';

  @override
  String get pathScanPending =>
      'Este servidor ainda não analisou nenhuma música, por isso não há nada por onde traçar um percurso. Funciona depois de a análise de descoberta ser executada.';

  @override
  String get discoverNothingFound => 'Nenhuma correspondência encontrada.';

  @override
  String get discoverNoSeed =>
      'Toque uma música para descobrir músicas semelhantes.';

  @override
  String get discoverLeadCopied => 'Copiado — vá procurar!';

  @override
  String get discoverOpenMusicBrainz => 'Abrir no MusicBrainz';

  @override
  String get discoverNetworkWarmingUp =>
      'Ainda não há dados da rede — as bibliotecas dos pares são baixadas em segundo plano quando outros servidores são detectados.';

  @override
  String get discoverNetworkNothingNew =>
      'Nada de novo para esta música — a rede não tem correspondências desconhecidas.';

  @override
  String get discoverPeersUnreachable =>
      'Seus pares não responderam — eles podem estar offline agora.';

  @override
  String get discoverPeersNothingNew =>
      'Nada de novo para esta música nos servidores dos seus pares.';

  @override
  String get autoDjSonicTitle => 'Semelhança sonora';

  @override
  String get autoDjSonicSubtitle =>
      'Escolhe apenas músicas que soam como a sessão, usando a análise de áudio do servidor.';

  @override
  String get autoDjSonicUnavailable =>
      'Este servidor não tem dados de descoberta — a seleção continua aleatória.';

  @override
  String get autoDjSonicNotReady =>
      'A descoberta está ativa, mas a análise ainda não produziu dados — a seleção continua aleatória até lá.';

  @override
  String get autoDjSonicStrictness => 'Limite de semelhança';

  @override
  String autoDjSonicStrictnessValue(int pct) {
    return '$pct% ou mais próximo';
  }

  @override
  String get autoDjSonicSeedLabel => 'Música semente';

  @override
  String get autoDjSonicSeedNone =>
      'Sem semente — a música em reprodução ancora a sessão.';

  @override
  String get autoDjSonicSeedBanner =>
      'Escolha a música semente — toque em uma faixa em qualquer lugar da biblioteca';

  @override
  String get autoDjSonicSeedSearchHint => 'Buscar uma música…';

  @override
  String get autoDjSonicSeedRandom => 'Música aleatória';

  @override
  String get autoDjSonicSeedRemove => 'Remover música semente';

  @override
  String get autoDjSonicSeedFailed =>
      'Não foi possível obter uma música do servidor.';

  @override
  String get autoDjSeedNoMatch =>
      'Nenhuma música corresponde aos seus filtros do Auto DJ — tente afrouxá-los';

  @override
  String get discoverFindSimilar => 'Encontrar semelhantes';

  @override
  String get discoverStartSession => 'Iniciar uma sessão sonora';

  @override
  String get discoverStartSessionSubtitle =>
      'Música sem fim que soa como esta — substitui sua fila.';

  @override
  String get discoverStartSessionSubtitleRandom =>
      'Música sem fim a partir de uma música inicial aleatória — substitui sua fila.';

  @override
  String get discoverSessionStarted =>
      'Sessão sonora iniciada — Auto DJ ativado.';

  @override
  String get autoDjSonicAnchorLabel => 'Âncora';

  @override
  String get autoDjSonicAnchorRolling => 'Seguir o clima';

  @override
  String get autoDjSonicAnchorLocked => 'Manter a semente';

  @override
  String get autoDjSonicAnchorRollingHint =>
      'Cada música segue o som recente da sessão — pode evoluir aos poucos.';

  @override
  String get autoDjSonicAnchorLockedHint =>
      'Cada música fica próxima da música semente durante toda a sessão.';

  @override
  String get trackAddToPlaylist => 'Adicionar à playlist';

  @override
  String get trackAddToPlaylistFailed =>
      'Não foi possível adicionar à playlist.';

  @override
  String get discoverPlayPathTo => 'Tocar um caminho até…';

  @override
  String get pathScreenTitle => 'Caminho sonoro';

  @override
  String get pathStartNotAnalyzed =>
      'A música inicial ainda não foi analisada — aguarde a análise de descoberta ou escolha outra.';

  @override
  String get pathEndNotAnalyzed =>
      'A música de destino ainda não foi analisada — aguarde a análise de descoberta ou escolha outra.';

  @override
  String get pathStartSong => 'Música inicial';

  @override
  String get pathEndSong => 'Música final';

  @override
  String get pathLength => 'Comprimento';

  @override
  String get pathRegenerate => 'Gerar novamente';

  @override
  String get pathSaveAsPlaylist => 'Salvar como playlist';

  @override
  String get pathSetupHint =>
      'Escolha uma música de início e uma de destino — a jornada entre elas se preenche sozinha.';

  @override
  String get pathNotSet => 'Não definido';

  @override
  String get pathUsePlaying => 'Usar a música em reprodução';

  @override
  String get pathSearchSong => 'Buscar';

  @override
  String get pathBrowseLibrary => 'Explorar biblioteca';

  @override
  String get pathBuild => 'Criar a jornada';

  @override
  String get pathStartOver => 'Começar de novo';

  @override
  String get pathPickBannerStart =>
      'Escolha a música de início — toque em uma faixa em qualquer lugar da biblioteca';

  @override
  String get pathPickBannerEnd =>
      'Escolha a música de destino — toque em uma faixa em qualquer lugar da biblioteca';

  @override
  String get pathNothingPlaying => 'Nada está tocando';

  @override
  String pathPickOnServer(String server) {
    return 'Escolha uma faixa em $server';
  }

  @override
  String get welcomeTranslationNote =>
      'Este idioma foi traduzido automaticamente e pode soar estranho.';

  @override
  String get welcomeTranslationCta => 'Ajude a traduzir o mStream';

  @override
  String get setupTitle => 'Configuração rápida';

  @override
  String get setupSkip => 'Pular';

  @override
  String get setupNext => 'Avançar';

  @override
  String get setupFinish => 'Concluir';

  @override
  String get setupBack => 'Voltar';

  @override
  String get setupAccentTitle => 'Escolha sua cor';

  @override
  String get setupAccentBody =>
      'A cor de destaque realça botões, controles deslizantes e os controles do player. Toque em uma para experimentar.';

  @override
  String get setupVisualizerTitle => 'Áudio real para o visualizador';

  @override
  String get setupVisualizerBody =>
      'O visualizador usa dados sintetizados até que isto seja ativado.';

  @override
  String get setupVisualizerWarning =>
      'Ativar isso pede a permissão de microfone: o Android a exige de apps que decodificam o fluxo de áudio do dispositivo (que é o que o visualizador faz).';

  @override
  String get setupPlaybackTitle => 'Ao tocar em uma música';

  @override
  String get setupOfflineTitle => 'Mantenha sua fila offline';

  @override
  String get setupVisualizerNoMic => 'O mStream nunca usa seu microfone.';

  @override
  String get playlistEmpty => 'A playlist está vazia';

  @override
  String get trackRating => 'Avaliação';

  @override
  String albumDiscNumber(int n) {
    return 'Disco $n';
  }

  @override
  String get autoDjStartTitle => 'Começar o Auto DJ com o quê?';

  @override
  String get autoDjStartSubtitle =>
      'Não há nada na fila, então o DJ precisa de uma primeira música. Com fila, ele apenas segue o que já existe.';

  @override
  String get autoDjStartRandom => 'Surpreenda-me';

  @override
  String get autoDjStartRandomSub =>
      'Escolher uma música aleatória da biblioteca e construir a partir dela.';

  @override
  String get autoDjStartPick => 'Eu escolho';

  @override
  String get autoDjStartPickSub =>
      'Abrir a biblioteca e escolher a primeira música você mesmo.';

  @override
  String get autoDjStartRemember => 'Lembrar disto';

  @override
  String get autoDjStartRememberSub =>
      'Pular esta pergunta na próxima vez e sempre começar assim.';

  @override
  String get autoDjStartPickBanner =>
      'Escolha a primeira música — toque em uma faixa em qualquer lugar da biblioteca';

  @override
  String get autoDjOnEmptyQueue => 'Com a fila vazia';

  @override
  String get autoDjOnEmptyQueueSub =>
      'O que o Auto DJ faz quando você o liga sem nada na fila.';

  @override
  String get autoDjStartAskShort => 'Perguntar';

  @override
  String serverVersionLabel(String version) {
    return 'Servidor v$version';
  }

  @override
  String get serverVersionUnknown => 'Versão do servidor desconhecida';

  @override
  String get serverUpdateUrgent => 'Atualize seu servidor';

  @override
  String get serverUpdateAvailable => 'Atualização de servidor disponível';

  @override
  String serverTooOldWarning(String version) {
    return 'Este servidor é a versão v$version. Alguns recursos exigem v5.5 ou mais recente e ficarão indisponíveis.';
  }

  @override
  String get autoDjNeedsNewerServer =>
      'Continuidade de BPM, mixagem harmônica e filtro de gêneros exigem um servidor mais recente. Atualize para obtê-los.';

  @override
  String get autoDjSonicNeedsNewerServer =>
      'Requer servidor 6.15.2 ou mais recente';

  @override
  String get torrentScreenTitle => 'Adicionar torrent';

  @override
  String get torrentNoServer => 'Nenhum servidor configurado.';

  @override
  String get torrentServerLabel => 'Servidor';

  @override
  String get torrentLibraryLabel => 'Biblioteca';

  @override
  String get torrentNoLibraries => 'Nenhuma biblioteca neste servidor';

  @override
  String get torrentSourceLabel => 'Origem';

  @override
  String get torrentChooseFile => 'Escolher arquivo .torrent';

  @override
  String get torrentOr => 'ou';

  @override
  String get torrentMagnetLabel => 'Link magnet';

  @override
  String get torrentMagnetInvalid => 'Link magnet inválido';

  @override
  String torrentNotATorrent(String name) {
    return '“$name” não é um arquivo .torrent';
  }

  @override
  String get torrentOpenWith => 'Abrir em outro aplicativo';

  @override
  String get torrentOpenWithNone =>
      'Nenhum aplicativo neste dispositivo pode abrir um arquivo .torrent';

  @override
  String get torrentOpenWithFailed =>
      'Não foi possível passar o torrent para outro aplicativo';

  @override
  String get torrentIntentTitle => 'Torrent recebido';

  @override
  String get torrentIntentBody =>
      'Adicione-o a uma biblioteca no seu servidor mStream ou passe-o para outro aplicativo.';

  @override
  String get torrentIntentAdd => 'Adicionar ao mStream';

  @override
  String get torrentIntentDontAsk =>
      'Sempre adicionar ao mStream, não perguntar novamente';

  @override
  String get settingsTorrentAskTitle => 'Perguntar o que fazer com torrents';

  @override
  String get settingsTorrentAskSub =>
      'Quando um torrent for aberto com o mStream, oferecer passá-lo para outro aplicativo';

  @override
  String get settingsTorrentDefaultTitle => 'Aplicativo padrão para torrents';

  @override
  String get settingsTorrentDefaultSub =>
      'Abre as configurações do Android, onde você escolhe qual aplicativo abre torrents e links magnet';

  @override
  String get settingsTorrentDefaultFailed =>
      'Não foi possível abrir as configurações do Android';

  @override
  String get torrentAutoDetect => 'Detectar metadados';

  @override
  String get torrentDetecting => 'Detectando…';

  @override
  String get torrentDetectNoMetadata =>
      'Metadados insuficientes — preencha os campos manualmente';

  @override
  String get torrentDetected => 'Metadados detectados';

  @override
  String get torrentDetectGuess =>
      'Estimativa aproximada — verifique os campos';

  @override
  String get torrentMetadataLabel => 'Metadados';

  @override
  String get torrentArtistLabel => 'Artista';

  @override
  String get torrentAlbumLabel => 'Álbum';

  @override
  String get torrentYearLabel => 'Ano';

  @override
  String get torrentDestinationLabel => 'Destino';

  @override
  String get torrentPathLabel => 'Caminho na biblioteca';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹sem biblioteca›/$path';
  }

  @override
  String get torrentPreviewContents => '‹conteúdo do torrent›';

  @override
  String get torrentRenameRoot => 'Renomear a pasta raiz do torrent';

  @override
  String get torrentRenameRootSub => 'Igualar ao nome da pasta de destino';

  @override
  String get torrentForceFresh => 'Forçar download do zero';

  @override
  String get torrentForceFreshSub => 'Não verificar arquivos já no servidor';

  @override
  String get torrentSubmit => 'Adicionar torrent';

  @override
  String get torrentSubmitting => 'Adicionando…';

  @override
  String get torrentUnavailable =>
      'Torrents não estão disponíveis neste servidor.';

  @override
  String get torrentPickLibrary => 'Escolha uma biblioteca';

  @override
  String get torrentOneSource =>
      'Adicione um link magnet ou um arquivo .torrent (apenas um)';

  @override
  String get torrentPathEmpty => 'O caminho de destino está vazio';

  @override
  String get torrentSeeded => 'Já está no disco — semeando agora';

  @override
  String get torrentAlreadyInClient => 'Já está no cliente de torrents';

  @override
  String get torrentInvalidFile => 'Arquivo torrent inválido';

  @override
  String get torrentSeedCheckFailed =>
      'Não foi possível verificar arquivos existentes — baixando do zero';

  @override
  String get torrentPartialTitle => 'Alguns arquivos já existem';

  @override
  String get torrentPartialBody =>
      'Aponte o torrent para uma cópia existente para semeá-la e baixar só o que falta.';

  @override
  String torrentPartialCount(String matched, String total) {
    return '$matched/$total arquivos aqui';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · $missing a baixar';
  }

  @override
  String get torrentDownloadFresh => 'Baixar do zero mesmo assim';

  @override
  String get torrentMatchNoFolder =>
      'Essa correspondência não tem nome de pasta — use \'Baixar do zero mesmo assim\'';

  @override
  String torrentAdded(String name) {
    return '\"$name\" adicionado';
  }

  @override
  String torrentDuplicate(String name) {
    return '\"$name\" já está no cliente';
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
  String get federationTitle => 'Federação';

  @override
  String get federationStatusOn => 'Ligada · conectada ao relay';

  @override
  String get federationStatusConnecting => 'Ligada · a ligar…';

  @override
  String get federationStatusOff => 'Desligada';

  @override
  String get federationStatusUnavailable => 'Indisponível nesta plataforma';

  @override
  String get federationSharedWithYou => 'Partilhado consigo';

  @override
  String get federationRequestsSection => 'Pedidos';

  @override
  String get federationYourSharedLibraries => 'As suas bibliotecas partilhadas';

  @override
  String get federationAddPeer => 'Adicionar um par';

  @override
  String get federationShareLibrary => 'Partilhar uma biblioteca';

  @override
  String get federationNoPeersYet =>
      'Ainda nada é partilhado com este servidor.';

  @override
  String get federationNoKeysYet =>
      'Ainda sem tickets — partilhe uma biblioteca para criar um.';

  @override
  String get federationNoRequests =>
      'Ainda sem pedidos — os servidores da rede de descoberta podem encontrá-lo aqui.';

  @override
  String get federationClipboardTicket => 'Ticket na área de transferência';

  @override
  String federationTicketPreview(String name, String libraries) {
    return '$name · partilha $libraries';
  }

  @override
  String federationTicketPreviewNoLibraries(String name) {
    return '$name';
  }

  @override
  String get federationUnnamedServer => 'Servidor sem nome';

  @override
  String get federationAddPeerAction => 'Adicionar par';

  @override
  String get federationPeerLive => 'ativo';

  @override
  String get federationPeerConnecting => 'a ligar…';

  @override
  String get federationPeerDirectTunnel => 'túnel direto';

  @override
  String federationPeerViaParent(String parent) {
    return 'via $parent';
  }

  @override
  String federationPeerViaTunnel(String parent) {
    return 'via o túnel de $parent';
  }

  @override
  String get federationPeerMissing => 'já não é partilhado';

  @override
  String get federationPeerHidden => 'oculto no seletor';

  @override
  String federationMemberNote(String server) {
    return 'Partilhar é tarefa do administrador. Criar tickets, adicionar pares e responder a pedidos de emparelhamento exigem uma sessão de administrador em $server — a mesma que abre o painel de administração.';
  }

  @override
  String get federationRestrictedNote =>
      'Este servidor só aceita chamadas de administração a partir da sua própria rede. Ligue-se a partir de casa para gerir a partilha aqui.';

  @override
  String get federationDisabledNote =>
      'A API de administração está desligada neste servidor.';

  @override
  String get federationUnsupportedNote =>
      'Este servidor é demasiado antigo para gerir a federação a partir da app. Atualize o mStream.';

  @override
  String get federationLoadFailed => 'Não foi possível contactar o servidor.';

  @override
  String get federationRetry => 'Tentar novamente';

  @override
  String get federationOffTitle =>
      'Partilhe bibliotecas com os servidores dos seus amigos';

  @override
  String get federationOffBody =>
      'Emparelhe dois servidores mStream para ouvirem a música um do outro. Trocam-se tickets — envie um por mensagem, digitalize-o ou cole-o.';

  @override
  String get federationOffPoint1Title => 'Só leitura, cifrado de ponta a ponta';

  @override
  String get federationOffPoint1Body =>
      'As listas e as classificações nunca saem do seu servidor';

  @override
  String get federationOffPoint2Title =>
      'Sem reencaminhamento de portas nem DNS';

  @override
  String get federationOffPoint2Body =>
      'O iroh encontra o caminho — direto quando pode, por relay quando é preciso';

  @override
  String get federationOffPoint3Title => 'Tickets que pode revogar';

  @override
  String get federationOffPoint3Body =>
      'Cada um é resgatado uma vez e cortado a qualquer momento';

  @override
  String get federationOffAdminOnly =>
      'Só o administrador do servidor pode ligar isto.';

  @override
  String federationOffMemberNote(String server) {
    return 'A federação está desligada em $server. O administrador pode ligá-la.';
  }

  @override
  String get federationTurnOn => 'Ligar a federação';

  @override
  String get federationUnavailableNote =>
      'O componente iroh não tem uma compilação para o sistema/CPU deste servidor, por isso o ponto de federação não pode correr aqui.';

  @override
  String get federationTurnedOn => 'A federação está ligada';

  @override
  String get federationTurnedOff => 'A federação está desligada';

  @override
  String get federationToggleFailed =>
      'Não foi possível alterar a definição de federação.';

  @override
  String get federationSettingsTitle => 'Definições de federação';

  @override
  String get federationSwitchSubtitle =>
      'Entre pares, cifrado de ponta a ponta. Sem reencaminhamento de portas, sem DNS.';

  @override
  String get federationStatusSection => 'Estado';

  @override
  String get federationConnectedRelay => 'Ligado ao relay';

  @override
  String get federationNotRunning => 'Ponto de federação parado';

  @override
  String get federationEndpointId => 'ID do ponto';

  @override
  String get federationEndpointCopied => 'ID do ponto copiado';

  @override
  String get federationPairingRequestsSection => 'Pedidos de emparelhamento';

  @override
  String get federationRequestsInboxTitle =>
      'Aceitar pedidos da rede de descoberta';

  @override
  String get federationRequestsInboxSubtitle =>
      'Desligado por predefinição. Quando desligado, os novos pedidos são recusados no transporte; as respostas aos seus próprios pedidos continuam a chegar.';

  @override
  String get federationInboxFailed =>
      'Não foi possível alterar a caixa de pedidos.';

  @override
  String get federationDefaultsSection => 'Predefinições para novos tickets';

  @override
  String get federationDefaultsNote =>
      'Da configuração do servidor — cada ticket pode alterá-las';

  @override
  String get federationOffWarning =>
      'Desligar a federação corta todas as pontes com os pares e esconde os seus tickets até voltar a ligar. Os pares mantêm os seus tickets.';

  @override
  String federationRequestWantsToPair(String name) {
    return '$name quer emparelhar';
  }

  @override
  String federationRequestToName(String name) {
    return 'Pedido a $name';
  }

  @override
  String federationRequestOffers(String libraries) {
    return 'Oferece $libraries';
  }

  @override
  String get federationRequestOffersNothing => 'Não oferece nada';

  @override
  String federationRequestYouOffered(String libraries) {
    return 'Ofereceu $libraries';
  }

  @override
  String get federationRequestYouOfferedNothing => 'Não ofereceu nada';

  @override
  String get federationReqSending => 'a enviar…';

  @override
  String get federationReqWaiting => 'à espera da resposta';

  @override
  String get federationReqSharingBack => 'a partilhar de volta…';

  @override
  String get federationReqNeedsAnswer => 'precisa da sua resposta';

  @override
  String get federationReqSendingTicket => 'a enviar o seu ticket…';

  @override
  String get federationReqWaitingShare => 'à espera da partilha deles';

  @override
  String get federationReqDeclined => 'recusado';

  @override
  String get federationReqYouDeclined => 'recusado por si';

  @override
  String get federationReqInboxClosed => 'a caixa deles está fechada';

  @override
  String get federationReqFederated => 'federado';

  @override
  String get federationReqWithdrawn => 'retirado';

  @override
  String get federationReqExpired => 'expirado';

  @override
  String get federationAccept => 'Aceitar…';

  @override
  String get federationAcceptAndShare => 'Aceitar e partilhar';

  @override
  String get federationDecline => 'Recusar';

  @override
  String get federationCancelRequest => 'Cancelar pedido';

  @override
  String get federationDismiss => 'Dispensar';

  @override
  String get federationRequestTitle => 'Pedido de emparelhamento';

  @override
  String federationRequestReceived(String ago) {
    return 'Recebido $ago pela rede de descoberta';
  }

  @override
  String federationRequestSent(String ago) {
    return 'Enviado $ago pela rede de descoberta';
  }

  @override
  String get federationShareBack => 'Partilhar de volta';

  @override
  String get federationShareBackNote =>
      'Nada muda até aceitar. Terão acesso só de leitura às bibliotecas que marcar — pelo menos uma.';

  @override
  String get federationTheirLimits => 'Os limites deles';

  @override
  String get federationChange => 'Alterar';

  @override
  String get federationRequestIgnored =>
      'Os pedidos deste servidor são ignorados durante 7 dias';

  @override
  String get federationRequestAccepted => 'Pedido aceite';

  @override
  String get federationRequestDeclined => 'Pedido recusado';

  @override
  String get federationRequestCancelled => 'Pedido retirado';

  @override
  String get federationRequestActionFailed =>
      'Não foi possível atualizar o pedido.';

  @override
  String get federationTicketNameLabel => 'Para quem é?';

  @override
  String get federationTicketNameHint =>
      'Só você vê este nome — identifica o ticket na sua lista.';

  @override
  String get federationLibrariesTheyCanRead => 'Bibliotecas que podem ler';

  @override
  String get federationLimitsSection => 'Limites';

  @override
  String get federationExactNumbers => 'Valores exatos';

  @override
  String get federationPresets => 'Predefinições';

  @override
  String get federationLimitStreamRate => 'Débito de streaming';

  @override
  String get federationLimitPerDay => 'Por dia';

  @override
  String get federationLimitStreams => 'Streams em simultâneo';

  @override
  String get federationLimitExpires => 'Expira';

  @override
  String get federationUnlimited => 'Ilimitado';

  @override
  String get federationNever => 'Nunca';

  @override
  String federationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return '$_temp0';
  }

  @override
  String get federationOneYear => '1 ano';

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
    return '$n MB por dia';
  }

  @override
  String federationGbPerDay(int n) {
    return '$n GB por dia';
  }

  @override
  String federationStreamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count streams',
      one: '1 stream',
    );
    return '$_temp0';
  }

  @override
  String get federationNeverExpires => 'nunca expira';

  @override
  String federationExpiresIn(String when) {
    return 'expira $when';
  }

  @override
  String get federationExpired => 'expirado';

  @override
  String federationInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dentro de $count dias',
      one: 'dentro de 1 dia',
    );
    return '$_temp0';
  }

  @override
  String federationInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dentro de $count horas',
      one: 'dentro de 1 hora',
    );
    return '$_temp0';
  }

  @override
  String get federationStreamRateField => 'Débito (kbps, 0 = ilimitado)';

  @override
  String get federationPerDayField => 'Quota diária (MB, 0 = ilimitada)';

  @override
  String get federationStreamsField => 'Streams máx. (0 = ilimitado)';

  @override
  String get federationExpiresField => 'Expira em dias (0 = nunca)';

  @override
  String get federationCreateTicket => 'Criar ticket';

  @override
  String get federationMintFailed => 'Não foi possível criar o ticket.';

  @override
  String get federationNoLibraries =>
      'Este servidor não tem bibliotecas para partilhar.';

  @override
  String get federationTicketTitle => 'O seu ticket';

  @override
  String federationTicketFor(String name) {
    return 'Ticket para $name';
  }

  @override
  String federationTicketReads(String libraries) {
    return 'Lê $libraries';
  }

  @override
  String get federationTicketQrHint =>
      'Na mesma sala? Deixe-os digitalizar isto.';

  @override
  String get federationTicketWarning =>
      'Quem tiver este ticket pode ler essas bibliotecas até ele ser resgatado ou revogado. Envie-o por um canal privado — o primeiro servidor a usá-lo fica com ele.';

  @override
  String get federationCopyTicket => 'Copiar ticket';

  @override
  String get federationTicketCopied => 'Ticket copiado';

  @override
  String get federationSendByText => 'Enviar por mensagem…';

  @override
  String get federationTicketRevokeNote =>
      'Revogue-o a qualquer momento em Federação. Se reinstalarem, «Repor resgate» permite resgatar o ticket de novo.';

  @override
  String get federationTicketNotRunning =>
      'O ponto de federação não está a correr, por isso ainda não há ticket para enviar. Ligue a federação e volte.';

  @override
  String federationShareMessage(String libraries, String ticket) {
    return 'Estou a partilhar consigo a minha biblioteca de música mStream — $libraries, só de leitura. Na app mStream abra Federação → Adicionar um par e cole este ticket:\n\n$ticket\n\nFunciona uma vez — posso revogá-lo a qualquer momento.';
  }

  @override
  String get federationShareSubject => 'Ticket de federação mStream';

  @override
  String get federationKeyClaimed => 'resgatado';

  @override
  String get federationKeyNotClaimed => 'ainda não resgatado';

  @override
  String federationKeyTodayUsage(String amount) {
    return '$amount hoje';
  }

  @override
  String federationKeyLastUsed(String ago) {
    return 'Última utilização $ago';
  }

  @override
  String get federationKeyNeverUsed => 'Nunca utilizado';

  @override
  String federationKeyClaimedAgo(String ago) {
    return 'Resgatado $ago';
  }

  @override
  String get federationResetBinding => 'Repor resgate';

  @override
  String get federationResetBindingNote =>
      'Reinstalaram? Permita resgatar o ticket de novo.';

  @override
  String get federationBindingReset => 'O ticket pode ser resgatado de novo';

  @override
  String get federationRevoke => 'Revogar';

  @override
  String federationRevokeConfirm(String name) {
    return 'Revogar este ticket? $name perde o acesso de imediato.';
  }

  @override
  String get federationRevoked => 'Ticket revogado';

  @override
  String get federationSaveLimits => 'Guardar limites';

  @override
  String get federationLimitsSaved => 'Limites guardados';

  @override
  String get federationLimitsFailed => 'Não foi possível guardar os limites.';

  @override
  String get federationSend => 'Enviar';

  @override
  String get federationKeyTitle => 'Biblioteca partilhada';

  @override
  String federationActionFailed(String error) {
    return 'Isso não resultou: $error';
  }

  @override
  String get federationTheirTicket => 'O ticket deles';

  @override
  String get federationScanQr => 'Digitalizar um código QR';

  @override
  String get federationScannerTitle => 'Digitalizar um ticket de federação';

  @override
  String get federationPaste => 'Colar';

  @override
  String get federationTicketPasted => 'Colado da área de transferência.';

  @override
  String get federationNotATicket => 'Isso não parece um ticket de federação.';

  @override
  String get federationTicketTooNew =>
      'Este ticket vem de um mStream mais recente do que esta app entende.';

  @override
  String get federationTicketExpiredNote => 'Este ticket expirou.';

  @override
  String get federationDisplayName => 'Nome a mostrar';

  @override
  String get federationDisplayNameHint =>
      'Opcional — como aparece no seu seletor de servidores.';

  @override
  String federationSharesLibraries(String libraries) {
    return 'Partilha $libraries';
  }

  @override
  String get federationSharesUnknown => 'Bibliotecas não indicadas no ticket';

  @override
  String federationValidUntil(String date) {
    return 'válido até $date';
  }

  @override
  String federationAddPeerShowsUnder(String server) {
    return 'Aparece sob $server';
  }

  @override
  String federationAddPeerReadOnly(String branch, String name) {
    return 'Só leitura · $branch $name no seletor';
  }

  @override
  String get federationAddPeerDials => 'O seu servidor liga-se a ele por iroh';

  @override
  String get federationAddPeerEncrypted =>
      'Cifrado de ponta a ponta · sem reencaminhamento de portas';

  @override
  String get federationAddPeerNoTicket =>
      'Ainda sem ticket? Peça que lhe enviem um por mensagem.';

  @override
  String federationPeerAdded(String name) {
    return '$name adicionado';
  }

  @override
  String get federationAddPeerFailed => 'Não foi possível adicionar o par.';

  @override
  String get federationPeerAlreadyAdded =>
      'Este ticket já está adicionado como par.';

  @override
  String get federationLibrariesYouCanRead => 'Bibliotecas que pode ler';

  @override
  String get federationDiscoverySection => 'Descoberta';

  @override
  String get federationAskPeerSimilar => 'Pedir música semelhante a este par';

  @override
  String get federationAskPeerSimilarNote =>
      'Envia o que está a ouvir — só a este par.';

  @override
  String get federationAutoDjSection => 'Auto DJ';

  @override
  String get federationAutoDjParticipates =>
      'Participa no Auto DJ multisservidor';

  @override
  String get federationAutoDjParticipatesNote =>
      'Responde com a sua própria biblioteca quando o DJ está ligado';

  @override
  String get federationAutoDjNotCandidate => 'Não é candidato ao Auto DJ';

  @override
  String get federationAutoDjNotCandidateNote =>
      'Precisa de um servidor capaz de responder a escolhas sónicas';

  @override
  String get federationTest => 'Testar';

  @override
  String get federationTesting => 'A testar…';

  @override
  String get federationTestOk => 'Acessível';

  @override
  String federationTestFailed(String error) {
    return 'Não foi possível contactar: $error';
  }

  @override
  String federationCheckedAgo(String ago) {
    return 'Verificado $ago';
  }

  @override
  String get federationNeverTested => 'Nunca testado';

  @override
  String federationLastSeen(String ago) {
    return 'Visto pela última vez $ago';
  }

  @override
  String get federationBrowseLibrary => 'Explorar esta biblioteca';

  @override
  String get federationRemovePeer => 'Remover par';

  @override
  String federationRemovePeerConfirm(String name) {
    return 'Remover $name? As faixas em fila vindas dele deixam de tocar.';
  }

  @override
  String federationPeerRemoved(String name) {
    return '$name removido';
  }

  @override
  String get federationShowInPicker => 'Mostrar no seletor de servidores';

  @override
  String get federationShowInPickerNote =>
      'Os pares ocultos continuam a tocar o que pôs em fila a partir deles.';

  @override
  String get federationPeerReadOnlyNote =>
      'Só leitura — as listas e as classificações ficam no seu próprio servidor.';

  @override
  String get federationPeerLibrariesUnknown =>
      'Ainda não listadas — abra-o uma vez para carregar as bibliotecas.';

  @override
  String get federationTransportDirect =>
      'Túnel direto a partir deste telemóvel';

  @override
  String get federationTransportRelay => 'Relay em espera';

  @override
  String federationTransportViaParent(String parent) {
    return 'Através de $parent';
  }

  @override
  String federationTransportViaParentTunnel(String parent) {
    return 'Através de $parent pelo seu túnel';
  }

  @override
  String get federationDiscoveryFailed =>
      'Não foi possível alterar a definição de descoberta.';

  @override
  String get agoJustNow => 'agora mesmo';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count min',
      one: 'há 1 min',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count h',
      one: 'há 1 h',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count dias',
      one: 'há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String get browserP2pNetwork => 'Rede P2P';

  @override
  String get browserP2pOn => 'Ligada';

  @override
  String get browserP2pOff => 'Desligada';

  @override
  String get p2pTitle => 'Rede P2P';

  @override
  String get p2pStatusConnected => 'Ligado';

  @override
  String p2pNeighborsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vizinhos',
      one: '1 vizinho',
    );
    return '$_temp0';
  }

  @override
  String p2pAnnouncingAs(String name) {
    return 'anunciado como $name';
  }

  @override
  String get p2pStatusSearching => 'Entrou · à espera de vizinhos';

  @override
  String p2pStatusReconnecting(int n) {
    return 'A religar · tentativa $n';
  }

  @override
  String get p2pStatusNotJoined => 'Ainda não entrou';

  @override
  String get p2pStatusOff => 'Desligada';

  @override
  String get p2pStatusUnavailable => 'Indisponível nesta plataforma';

  @override
  String get p2pStatNeighbors => 'vizinhos na malha';

  @override
  String get p2pStatNeighborsSub => 'ligações gossip ativas';

  @override
  String get p2pStatKnown => 'servidores conhecidos';

  @override
  String p2pStatKnownSub(int hidden, int blocked) {
    return '$hidden ocultos · $blocked bloqueados';
  }

  @override
  String get p2pStatHeld => 'snapshots guardados';

  @override
  String p2pStatHeldOf(int held, int max) {
    return '$held de $max';
  }

  @override
  String p2pStatStorage(String used, String cap) {
    return '$used de $cap';
  }

  @override
  String get p2pStatTracks => 'faixas dos pares';

  @override
  String p2pStatTracksSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pesquisáveis, $count bibliotecas',
      one: 'pesquisáveis, 1 biblioteca',
    );
    return '$_temp0';
  }

  @override
  String get p2pActivity => 'Atividade';

  @override
  String get p2pActivitySubtitle => 'mais recente primeiro · só em memória';

  @override
  String get p2pActivityEmpty =>
      'Ainda nada — entradas na malha, descargas de snapshots, rotação e recuperações aparecem aqui à medida que acontecem.';

  @override
  String get p2pActivityNote =>
      'O histórico completo está nos registos do servidor.';

  @override
  String get p2pFromNetwork => 'Da rede';

  @override
  String get p2pFindSimilar => 'Encontrar música semelhante na rede';

  @override
  String p2pFindSimilarSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Abre Descobrir para a faixa em reprodução · sugestões de $count bibliotecas descarregadas',
      one:
          'Abre Descobrir para a faixa em reprodução · sugestões de 1 biblioteca descarregada',
    );
    return '$_temp0';
  }

  @override
  String get p2pFindSimilarNothingPlaying =>
      'Reproduza algo primeiro — Descobrir segue a faixa atual';

  @override
  String get p2pNewArtistsOnlySub =>
      'Ocultar sugestões de artistas que já estão nesta biblioteca';

  @override
  String get p2pServersYouFollow => 'Servidores que segue';

  @override
  String get p2pServersOnNetwork => 'Servidores na rede';

  @override
  String get p2pNoServersYet =>
      'Ainda não se ouviu nenhum servidor — adicione um com o ticket de um amigo ou dê um minuto ao gossip.';

  @override
  String p2pHiddenIncompatible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servidores ocultos — modelo incompatível',
      one: '1 servidor oculto — modelo incompatível',
    );
    return '$_temp0';
  }

  @override
  String get p2pShow => 'Mostrar';

  @override
  String get p2pHide => 'Ocultar';

  @override
  String get p2pBefriend => 'Adicionar um servidor amigo';

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
      other: '$count faixas',
      one: '1 faixa',
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
  String get p2pChipDownloaded => 'descarregado';

  @override
  String get p2pChipUpdate => 'atualização disponível';

  @override
  String get p2pChipNotDownloaded => 'não descarregado';

  @override
  String get p2pChipPinned => 'afixado';

  @override
  String get p2pChipIncompatible => 'modelo incompatível';

  @override
  String get p2pChipFederated => 'federado';

  @override
  String get p2pChipTheyAsked => 'pediram-lhe';

  @override
  String get p2pChipRequestSent => 'pedido enviado';

  @override
  String get p2pSearchingTitle => 'À procura de pares';

  @override
  String get p2pSearchingBody =>
      'A malha forma-se em cerca de um minuto. Este ecrã atualiza-se sozinho.';

  @override
  String get p2pReconnectingTitle => 'A religar';

  @override
  String p2pReconnectingBody(int n) {
    return 'O sidecar morreu e está a ser relançado (tentativa $n) — não é preciso fazer nada.';
  }

  @override
  String get p2pJoinTitle => 'Recomendações das bibliotecas de outras pessoas';

  @override
  String get p2pWhatShared => 'O que é partilhado';

  @override
  String get p2pShared1 => 'Um snapshot só com metadados';

  @override
  String get p2pShared1Sub =>
      'Artista, título, duração, impressões sonoras — nunca ficheiros de áudio';

  @override
  String get p2pShared2 => 'O nome e a descrição do seu servidor';

  @override
  String get p2pShared2Sub =>
      'Visíveis para todos na rede, por predefinição a rede pública da comunidade';

  @override
  String get p2pHowYouAppear => 'Como aparece';

  @override
  String get p2pServerName => 'Nome do servidor';

  @override
  String get p2pServerNameHint =>
      '“mStream” ao lado de outros 18 000 mStream é a primeira coisa a mudar.';

  @override
  String get p2pDescription => 'Descrição';

  @override
  String get p2pDescriptionHint => '180 caracteres, opcional.';

  @override
  String get p2pAlsoAcceptRequests => 'Aceitar também pedidos de federação';

  @override
  String get p2pAlsoAcceptRequestsSub =>
      'Convites para partilhar bibliotecas — nada é partilhado até aprovar cada um. Liga a federação.';

  @override
  String get p2pJoin => 'Entrar na rede';

  @override
  String get p2pJoining => 'A entrar…';

  @override
  String get p2pJoined =>
      'Entrou na rede de descoberta — dê um minuto à malha.';

  @override
  String p2pJoinFailed(String error) {
    return 'Não foi possível entrar na rede: $error';
  }

  @override
  String p2pInboxFailed(String error) {
    return 'A descoberta está ligada, mas a caixa de pedidos não arrancou: $error';
  }

  @override
  String get p2pUnavailableNote =>
      'O binário p2p-sidecar não foi encontrado para esta plataforma e não há nenhum para descarregar — a rede está indisponível.';

  @override
  String get p2pWillDownloadNote =>
      'O sidecar ainda não está instalado; ao entrar é descarregado primeiro.';

  @override
  String get p2pAdminOnlyNote => 'Só o administrador do servidor pode entrar.';

  @override
  String p2pMemberOffNote(String server) {
    return 'A rede de descoberta está desligada em $server. O administrador pode entrar.';
  }

  @override
  String p2pMemberNote(String server) {
    return 'Entrar, convidar e gerir snapshots são tarefas do administrador. Inicie sessão em $server como administrador para gerir a rede aqui.';
  }

  @override
  String get p2pSnapshotSection => 'Snapshot';

  @override
  String p2pDownloadedSize(String size) {
    return 'Descarregado · $size';
  }

  @override
  String p2pSnapshotSeq(int seq) {
    return 'Snapshot $seq';
  }

  @override
  String p2pNewerAnnounced(int seq) {
    return 'há um mais recente ($seq) anunciado';
  }

  @override
  String get p2pNotDownloaded => 'Não descarregado';

  @override
  String get p2pNotDownloadedSub =>
      'Descarregue-o para o pesquisar a partir de Descobrir';

  @override
  String get p2pDownload => 'Descarregar';

  @override
  String get p2pUpdate => 'Atualizar';

  @override
  String get p2pDownloading => 'A descarregar…';

  @override
  String get p2pDownloaded => 'Snapshot descarregado';

  @override
  String p2pDownloadFailed(String error) {
    return 'Não foi possível descarregar o snapshot: $error';
  }

  @override
  String get p2pPin => 'Afixar este snapshot';

  @override
  String p2pPinSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'A rotação liberta os snapshots menos usados após $count dias; um afixado fica.',
      one:
          'A rotação liberta os snapshots menos usados após 1 dia; um afixado fica.',
    );
    return '$_temp0';
  }

  @override
  String get p2pPinSubNoRotation =>
      'A rotação está desligada; um snapshot afixado também sobrevive à falta de espaço.';

  @override
  String get p2pRemoveSnapshot => 'Remover snapshot';

  @override
  String get p2pSnapshotRemoved => 'Snapshot removido';

  @override
  String get p2pHeldSince => 'guardado desde';

  @override
  String get p2pTracksLabel => 'faixas';

  @override
  String get p2pSeedersLabel => 'seeders';

  @override
  String get p2pSeedersSub => 'a servir o snapshot';

  @override
  String get p2pFederatedWithYou => 'Federado consigo';

  @override
  String get p2pFederatedWithYouSub =>
      'Abra Federação para ver o que leem um do outro';

  @override
  String get p2pTheyAskedYou => 'Pediram para federar';

  @override
  String get p2pTheyAskedYouSub => 'Reveja o pedido em Federação';

  @override
  String get p2pRequestSentTitle => 'Pedido enviado';

  @override
  String get p2pRequestSentSub => 'À espera deles · acompanhe em Federação';

  @override
  String get p2pAskToFederate => 'Pedir para partilhar bibliotecas';

  @override
  String get p2pAskToFederateSub =>
      'Envia um pedido pela rede — por agora nada muda';

  @override
  String get p2pOpen => 'Abrir';

  @override
  String get p2pReview => 'Rever';

  @override
  String get p2pForget => 'Esquecer este servidor';

  @override
  String get p2pForgetSub =>
      'Offline e sem nada descarregado; volta se for ouvido de novo';

  @override
  String p2pForgotten(String name) {
    return '$name esquecido';
  }

  @override
  String get p2pBlockServer => 'Bloquear servidor';

  @override
  String p2pBlockConfirm(String name) {
    return 'Bloquear $name? Os seus anúncios são ignorados e o seu snapshot removido.';
  }

  @override
  String p2pBlocked(String name) {
    return '$name bloqueado';
  }

  @override
  String get p2pUnblock => 'Desbloquear';

  @override
  String get p2pUnblocked => 'Servidor desbloqueado';

  @override
  String get p2pIncompatibleNote =>
      'Modelo de embeddings incompatível — a sua biblioteca não pode alimentar a pesquisa de semelhantes deste servidor.';

  @override
  String get p2pCompatible => 'modelo compatível';

  @override
  String get p2pModelUnknown => 'modelo desconhecido';

  @override
  String get p2pNoDescription => 'Sem descrição.';

  @override
  String get p2pUnnamedServer => 'Servidor sem nome';

  @override
  String get p2pFederateTitle => 'Pedir federação';

  @override
  String get p2pFederateNote =>
      'Envia um pedido pela rede de descoberta. Agora não se troca nenhum acesso — veem o seu nome, a mensagem e a oferta; as bibliotecas só são partilhadas se aceitarem.';

  @override
  String get p2pMessage => 'Mensagem';

  @override
  String p2pMessageHint(int n) {
    return 'Opcional · $n / 500';
  }

  @override
  String get p2pShareBackLibraries =>
      'Bibliotecas que partilhará em troca se aceitarem';

  @override
  String get p2pShareBackNote =>
      'Desmarque tudo para um pedido unilateral — só leria as deles.';

  @override
  String get p2pSendRequest => 'Enviar pedido';

  @override
  String get p2pRequestSent => 'Pedido enviado — acompanhe em Federação';

  @override
  String p2pRequestFailed(String error) {
    return 'Não foi possível enviar o pedido: $error';
  }

  @override
  String get p2pTheirTicket => 'O ticket deles';

  @override
  String get p2pTheirTicketHint =>
      'Um amigo encontra o dele em “Convidar um amigo” no ecrã Rede P2P.';

  @override
  String get p2pTicketPasted => 'Colado da área de transferência.';

  @override
  String get p2pRememberFriend => 'Lembrar este amigo';

  @override
  String get p2pRememberFriendSub =>
      'Guardado na configuração do servidor para a amizade sobreviver a reinícios.';

  @override
  String get p2pJoinFriend => 'Entrar';

  @override
  String get p2pJoinedFriend => 'Entrou — a malha forma-se num minuto';

  @override
  String p2pJoinFriendFailed(String error) {
    return 'Não foi possível entrar: $error';
  }

  @override
  String get p2pNotATicket => 'Isso não parece um ticket de ponto de ligação.';

  @override
  String get p2pScanQr => 'Digitalizar um código QR';

  @override
  String get p2pScannerTitle => 'Digitalizar um ticket de rede';

  @override
  String get p2pInviteFriend => 'Convidar um amigo';

  @override
  String p2pYourTicketNote(String name) {
    return 'O seu ticket — um amigo cola-o aqui no telemóvel para adicionar $name. É um endereço, não uma credencial.';
  }

  @override
  String get p2pTicketCopied => 'Ticket copiado';

  @override
  String p2pShareMessage(String ticket) {
    return 'Adiciona o meu servidor mStream na rede de descoberta — na app mStream abre Rede P2P → Adicionar um servidor amigo e cola este ticket:\n\n$ticket';
  }

  @override
  String get p2pShareSubject => 'Ticket da rede de descoberta mStream';

  @override
  String get p2pTicketNotReady =>
      'O sidecar ainda não está a correr, por isso ainda não há ticket para partilhar.';

  @override
  String get p2pSettingsTitle => 'Definições de rede';

  @override
  String get p2pSwitchTitle => 'Rede de descoberta';

  @override
  String get p2pSwitchSub =>
      'Anuncia à rede um snapshot só com metadados. Desligue para sair — os dados recolhidos ficam locais.';

  @override
  String get p2pLeaveConfirm =>
      'Sair da rede de descoberta? O seu servidor deixa de anunciar e descarregar snapshots. A descoberta local continua a funcionar.';

  @override
  String get p2pLeave => 'Sair';

  @override
  String get p2pLeft => 'Saiu da rede de descoberta';

  @override
  String p2pLeaveFailed(String error) {
    return 'Não foi possível sair da rede: $error';
  }

  @override
  String get p2pEditIdentity => 'Nome e descrição';

  @override
  String get p2pIdentitySaved => 'Guardado — anunciado à rede';

  @override
  String p2pSaveFailed(String error) {
    return 'Não foi possível guardar: $error';
  }

  @override
  String get p2pSnapshotsSection => 'Snapshots';

  @override
  String get p2pAutoDownload => 'Descarga automática até';

  @override
  String p2pServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servidores',
      one: '1 servidor',
    );
    return '$_temp0';
  }

  @override
  String get p2pStorageCap => 'Limite de armazenamento';

  @override
  String get p2pRotate => 'Rodar descargas';

  @override
  String get p2pForgetOffline => 'Esquecer servidores offline';

  @override
  String get p2pMeshSection => 'Malha';

  @override
  String get p2pCommunitySeeds => 'Seeds da comunidade';

  @override
  String get p2pCommunitySeedsOn =>
      'Arranque através dos servidores seed públicos';

  @override
  String get p2pCommunitySeedsOff =>
      'Desligados — só servidores amigos; definido na configuração do servidor';

  @override
  String p2pBlockedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servidores bloqueados',
      one: '1 servidor bloqueado',
      zero: 'Nenhum servidor bloqueado',
    );
    return '$_temp0';
  }

  @override
  String get p2pBlockedSub =>
      'Anúncios ignorados, snapshots nunca descarregados';

  @override
  String get p2pBlockedTitle => 'Servidores bloqueados';

  @override
  String get p2pSaved => 'Guardado';

  @override
  String get p2pOff => 'Desligada';

  @override
  String get p2pSave => 'Guardar';

  @override
  String get p2pSearchServers => 'Procurar servidores — nome ou descrição';
}
