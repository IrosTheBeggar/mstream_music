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
      'Não foi possível salvar a playlist — o nome pode já estar em uso.';

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
      one: '$count faixa',
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
  String get lyricsTitle => 'Letra';

  @override
  String get lyricsEmpty => 'Nenhuma letra encontrada para esta música';

  @override
  String get lyricsError => 'Não foi possível carregar a letra';

  @override
  String get lyricsRetry => 'Tentar novamente';

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
      'Ao alterar as configurações de transcodificação — marcado: recarregar toda a fila agora (a faixa em reprodução faz buffer por instantes); desmarcado: só mudam as faixas seguintes, a atual termina sem alterações.';

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
  String get settingsLetterStrip => 'Limite da barra alfabética';

  @override
  String get settingsLetterStripSubtitle =>
      'Mostra a barra de navegação rápida A–Z quando uma lista tiver esta quantidade de itens ou mais. Abaixo disso, a barra fica oculta e nomes longos de pastas/arquivos quebram em várias linhas em vez de serem cortados. Defina 0 para sempre mostrar a barra.';

  @override
  String get settingsLetterStripSide => 'Lado da barra alfabética';

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
      'Toque = próxima predefinição · seta de voltar (canto superior esquerdo) ou pressione e segure para sair';

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
  String get visualizerClose => 'Fechar visualizador';

  @override
  String get visualizerPreviousPreset => 'Predefinição anterior';

  @override
  String get visualizerNextPreset => 'Próxima predefinição';

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
      one: '$count música',
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
  String get fieldPasswordShow => 'Mostrar senha';

  @override
  String get fieldPasswordHide => 'Ocultar senha';

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
      one: 'Temporizador definido para $minutes minuto',
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
    return '$count de $total servidores participando — aos demais falta a descoberta, um modelo de embeddings compatível ou uma versão de servidor recente o bastante';
  }

  @override
  String get autoDjSectionQueue => 'Fila';

  @override
  String get autoDjSongsPerFetchTitle => 'Músicas por busca';

  @override
  String get autoDjSongsPerFetchSubtitle =>
      'Quantas músicas o Auto DJ coloca na fila cada vez que é acionado. Os filtros de continuidade avaliam todo o lote em relação à música que tocava no momento da busca.';

  @override
  String autoDjSongsPerFetchValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '$count música',
    );
    return '$_temp0';
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
  String get searchCategoriesTooltip => 'O que pesquisar';

  @override
  String get searchCategoriesHeader => 'Pesquisar em';

  @override
  String get searchCategoryArtists => 'Artistas';

  @override
  String get searchCategoryAlbums => 'Álbuns';

  @override
  String get searchCategorySongs => 'Músicas';

  @override
  String get searchCategoryFiles => 'Arquivos';

  @override
  String get searchCategoryLyrics => 'Letras';

  @override
  String searchSubheaderResults(String term) {
    return 'Resultados para “$term”';
  }

  @override
  String searchSubheaderCategories(String categories) {
    return 'Pesquisando em: $categories';
  }

  @override
  String browserDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads iniciados',
      one: '$count download iniciado',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas adicionadas à fila',
      one: '$count música adicionada à fila',
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
  String get queueEmptyDjHint =>
      'O Auto DJ está ligado e precisa de uma primeira música.';

  @override
  String get queueEmptyDjRandom => 'Música aleatória';

  @override
  String get queueEmptyDjChoose => 'Escolher uma música';

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
      one: '$count faixa',
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
      one: '$count biblioteca compartilhada',
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
          'Movimentação concluída — $count arquivo ignorado (sem suporte no destino)',
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
      one: '$count faixa será baixada para reprodução offline.',
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
      one: '$count arquivo será baixado.',
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
  String get storageSdSwitchTitle => 'Salvar no cartão SD';

  @override
  String get storageSdSwitchSubtitle =>
      'Salvo na pasta do app no cartão SD — não exige permissão, mas é removido ao desinstalar o app.';

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
      one: '$count item',
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
          'O arquivo baixado deste servidor ($size) está em um volume de armazenamento diferente do novo local. Escolha o que fazer:',
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
  String get castThisDevice => 'Este dispositivo';

  @override
  String get visualizerNoKnobs => 'Este shader não expõe nenhum controle.';

  @override
  String get nowPlaying => 'Tocando agora';

  @override
  String get settingsPlayerLayout => 'Layout de Tocando agora';

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
      'A Conexão rápida está ativada neste servidor, mas ele não compartilhou um código de pareamento. Entre como administrador ou peça ao operador para ativar o compartilhamento do código.';

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
  String get settingsAutoDownloadCap => 'Limite de download automático';

  @override
  String get settingsAutoDownloadCapSubtitle =>
      'Guarda esta quantidade de músicas a partir da atual; as que ficam para trás são removidas.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Guarda a fila inteira (sem limite).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Ilimitado';

  @override
  String get settingsAutoDownloadCapField => 'Número de músicas';

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
  String get diagnosticsVerbose => 'Registro detalhado';

  @override
  String get diagnosticsVerboseHint =>
      'Também registra eventos muito frequentes, como mudanças de foco do app. Só é necessário ao diagnosticar um problema de reprodução.';

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
  String get storageAppExternal => 'Externo do app';

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
      'Adicione os seus próprios arquivos .glsl à rotação do motor de shaders.';

  @override
  String get importedShadersRescan => 'Reanalisar pasta';

  @override
  String get importedShadersDropHint =>
      'Coloque arquivos .glsl nesta pasta e depois Reanalisar:';

  @override
  String get importedShadersCopyPath => 'Copiar caminho';

  @override
  String get importedShadersReachableHint =>
      'Acessível via USB ou um gerenciador de arquivos (em Android/data). Os shaders importados entram na rotação quando o motor de shaders está ativo.';

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
  String get importedShadersImportDownloads => 'Importar .glsl de Downloads';

  @override
  String importedShadersDownloadsImported(int count) {
    return 'Importados de Downloads: $count shader(s)';
  }

  @override
  String get importedShadersDownloadsNone =>
      'Nenhum arquivo .glsl novo em Downloads';

  @override
  String get importedShadersDownloadsNoPermission =>
      'É necessária a permissão de armazenamento para ler Downloads';

  @override
  String get addServerTabUrl => 'URL do servidor';

  @override
  String get addServerTabQuickConnect => 'Conexão rápida';

  @override
  String get irohPairingHeader => 'Conectar com um código de pareamento';

  @override
  String get irohPairingBody =>
      'Ative \"Remote Access\" (acesso remoto) no servidor e depois cole o código de pareamento ou escaneie o QR.';

  @override
  String get irohPairingCodeLabel => 'Código de pareamento';

  @override
  String get irohPairingCodeHint =>
      'Cole o código do painel \"Remote Access\" do servidor';

  @override
  String get irohShowPairingCode => 'Mostrar código de pareamento';

  @override
  String get irohQrBody =>
      'Escaneie com o app mStream em outro dispositivo para conectá-lo a este servidor, ou copie o código e cole lá.';

  @override
  String get irohQrCaution =>
      'Qualquer pessoa com este código pode se conectar ao seu servidor.';

  @override
  String get irohScanQr => 'Escanear QR';

  @override
  String get irohPaste => 'Colar';

  @override
  String get irohTestConnection => 'Testar conexão';

  @override
  String get irohTesting => 'Testando…';

  @override
  String get irohScannerTitle => 'Escanear QR de pareamento';

  @override
  String get irohQrAndroidOnly =>
      'A leitura de QR não está disponível neste dispositivo.';

  @override
  String get irohAndroidOnly =>
      'A Conexão rápida não está disponível neste dispositivo.';

  @override
  String get irohCameraPermission =>
      'É preciso permissão da câmera para escanear um código.';

  @override
  String get irohPasteFirst =>
      'Primeiro cole ou escaneie um código de pareamento.';

  @override
  String get irohTestFirst => 'Primeiro teste a conexão.';

  @override
  String get irohTestConnected => 'Conectado pelo túnel iroh';

  @override
  String irohTestConnectedVersion(String version) {
    return 'Conectado pelo túnel iroh — mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · direta';

  @override
  String get irohPathSuffixRelay => ' · via relay';

  @override
  String get irohTunnelTimeout =>
      'O túnel abriu, mas o servidor não respondeu a tempo.';

  @override
  String irohTunnelTestFailed(String error) {
    return 'Falha no teste do túnel: $error';
  }

  @override
  String get irohSignInHeader => 'Entrar';

  @override
  String get irohSigningIn => 'Entrando…';

  @override
  String get irohSignInSave => 'Entrar e salvar';

  @override
  String get irohSignInTimeout => 'O login expirou.';

  @override
  String irohSignInFailed(String error) {
    return 'Falha no login: $error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return 'Falha no login (HTTP $status). Verifique seu usuário e senha.';
  }

  @override
  String get irohBannerConnecting => 'Conectando ao servidor…';

  @override
  String get irohBannerReconnecting => 'Reconectando ao servidor…';

  @override
  String get irohBannerDisconnected => 'Desconectado do servidor.';

  @override
  String get irohBannerRelay => 'Conectado via relay — caminho mais lento.';

  @override
  String get irohBannerRepair =>
      'O pareamento do servidor mudou — pareie novamente para reconectar.';

  @override
  String get irohRepairAction => 'Parear novamente';

  @override
  String get irohRetry => 'Tentar novamente';

  @override
  String get irohRepairTitle => 'Parear servidor novamente';

  @override
  String get irohRepairBody =>
      'O código de pareamento deste servidor mudou (o segredo foi renovado). Cole ou escaneie o novo código do painel \"Remote Access\" do servidor.';

  @override
  String get irohRepairFailed =>
      'Não foi possível conectar com esse código — confira e tente de novo.';

  @override
  String get irohPathDirect => 'Direta';

  @override
  String get irohPathRelay => 'Relay';

  @override
  String get irohCastUnavailable =>
      'A transmissão para dispositivos externos não está disponível em servidores peer-to-peer (iroh) — a reprodução continua neste dispositivo.';

  @override
  String get irohShareUnavailable =>
      'O compartilhamento não está disponível em servidores peer-to-peer (iroh) — eles não têm uma URL pública para vincular.';

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
      'Este servidor ainda não analisou nenhuma música, por isso não há nada por onde traçar um caminho. Funciona depois de a análise de descoberta ser executada.';

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
  String get setupOfflineTitle => 'Mantenha sua fila disponível offline';

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
    return 'Este servidor está na v$version. Alguns recursos exigem a v5.5 ou mais recente e ficarão indisponíveis.';
  }

  @override
  String get autoDjNeedsNewerServer =>
      'Continuidade de BPM, mixagem harmônica e filtro de gêneros exigem um servidor mais recente. Atualize para obtê-los.';

  @override
  String get autoDjSonicNeedsNewerServer =>
      'Requer um servidor 6.15.2 ou mais recente';

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
  String get browserFederatedReadOnly => 'Servidor somente leitura';

  @override
  String get browserFederatedReadOnlyNote =>
      'Playlists e avaliações ficam no seu próprio servidor';

  @override
  String get federatedShareUnavailable =>
      'Músicas de um servidor compartilhado não podem ser compartilhadas daqui — elas estão na biblioteca de outra pessoa.';

  @override
  String get federatedForget => 'Esquecer';

  @override
  String get federatedHide => 'Ocultar no seletor';

  @override
  String get federatedShow => 'Mostrar no seletor';

  @override
  String federatedNoLongerListed(String parent) {
    return 'Não é mais compartilhado por $parent';
  }

  @override
  String get federationTitle => 'Federação';

  @override
  String get federationStatusOn => 'Ativada · conectada ao relay';

  @override
  String get federationStatusConnecting => 'Ativada · conectando…';

  @override
  String get federationStatusOff => 'Desativada';

  @override
  String get federationStatusUnavailable => 'Indisponível nesta plataforma';

  @override
  String get federationSharedWithYou => 'Compartilhado com você';

  @override
  String get federationRequestsSection => 'Solicitações';

  @override
  String get federationYourSharedLibraries => 'Suas bibliotecas compartilhadas';

  @override
  String get federationAddPeer => 'Adicionar um par';

  @override
  String get federationShareLibrary => 'Compartilhar uma biblioteca';

  @override
  String get federationNoPeersYet =>
      'Nada foi compartilhado com este servidor ainda.';

  @override
  String get federationNoKeysYet =>
      'Ainda sem tickets — compartilhe uma biblioteca para criar um.';

  @override
  String get federationNoRequests =>
      'Ainda sem solicitações — os servidores da rede de descoberta podem encontrar você aqui.';

  @override
  String get federationClipboardTicket => 'Ticket na área de transferência';

  @override
  String federationTicketPreview(String name, String libraries) {
    return '$name · compartilha $libraries';
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
  String get federationPeerConnecting => 'conectando…';

  @override
  String get federationPeerDirectTunnel => 'túnel direto';

  @override
  String federationPeerViaParent(String parent) {
    return 'via $parent';
  }

  @override
  String federationPeerViaTunnel(String parent) {
    return 'pelo túnel de $parent';
  }

  @override
  String get federationPeerMissing => 'não é mais compartilhado';

  @override
  String get federationPeerHidden => 'oculto no seletor';

  @override
  String federationMemberNote(String server) {
    return 'Compartilhar é tarefa do administrador. Criar tickets, adicionar pares e responder a solicitações de pareamento exigem login de administrador em $server — o mesmo que abre o painel de administração.';
  }

  @override
  String get federationRestrictedNote =>
      'Este servidor só aceita chamadas de administração vindas da própria rede. Conecte-se de casa para gerenciar o compartilhamento aqui.';

  @override
  String get federationDisabledNote =>
      'A API de administração está desativada neste servidor.';

  @override
  String get federationUnsupportedNote =>
      'Este servidor é antigo demais para gerenciar a federação pelo app. Atualize o mStream.';

  @override
  String get federationLoadFailed => 'Não foi possível alcançar o servidor.';

  @override
  String get federationRetry => 'Tentar novamente';

  @override
  String get federationOffTitle =>
      'Compartilhe bibliotecas com os servidores dos seus amigos';

  @override
  String get federationOffBody =>
      'Pareie dois servidores mStream para que cada um leia a música do outro. Vocês trocam tickets — envie um por mensagem, escaneie um, cole um.';

  @override
  String get federationOffPoint1Title =>
      'Somente leitura, criptografado de ponta a ponta';

  @override
  String get federationOffPoint1Body =>
      'Playlists e avaliações nunca saem do seu servidor';

  @override
  String get federationOffPoint2Title =>
      'Sem redirecionamento de portas nem DNS';

  @override
  String get federationOffPoint2Body =>
      'O iroh encontra um caminho — direto quando pode, por relay quando precisa';

  @override
  String get federationOffPoint3Title => 'Tickets que você pode revogar';

  @override
  String get federationOffPoint3Body =>
      'Cada um é resgatado uma vez e pode ser cortado a qualquer momento';

  @override
  String get federationOffAdminOnly =>
      'Só o administrador do servidor pode ativar isso.';

  @override
  String federationOffMemberNote(String server) {
    return 'A federação está desativada em $server. O administrador pode ativá-la.';
  }

  @override
  String get federationTurnOn => 'Ativar federação';

  @override
  String get federationUnavailableNote =>
      'O componente iroh não tem build para o sistema/CPU deste servidor, então o endpoint de federação não pode ser executado aqui.';

  @override
  String get federationTurnedOn => 'A federação está ativada';

  @override
  String get federationTurnedOff => 'A federação está desativada';

  @override
  String get federationToggleFailed =>
      'Não foi possível atualizar a configuração de federação.';

  @override
  String get federationSettingsTitle => 'Configurações de federação';

  @override
  String get federationSwitchSubtitle =>
      'Peer-to-peer, criptografado de ponta a ponta. Sem redirecionamento de portas, sem DNS.';

  @override
  String get federationStatusSection => 'Status';

  @override
  String get federationConnectedRelay => 'Conectado ao relay';

  @override
  String get federationNotRunning => 'Endpoint parado';

  @override
  String get federationEndpointId => 'ID do endpoint';

  @override
  String get federationEndpointCopied => 'ID do endpoint copiado';

  @override
  String get federationPairingRequestsSection => 'Solicitações de pareamento';

  @override
  String get federationRequestsInboxTitle =>
      'Aceitar solicitações da rede de descoberta';

  @override
  String get federationRequestsInboxSubtitle =>
      'Desativado por padrão. Quando desativado, novas solicitações são recusadas no transporte; as respostas às suas próprias solicitações continuam chegando.';

  @override
  String get federationInboxFailed =>
      'Não foi possível atualizar a caixa de solicitações.';

  @override
  String get federationDefaultsSection => 'Padrões para novos tickets';

  @override
  String get federationDefaultsNote =>
      'Da configuração do servidor — cada ticket pode alterá-los';

  @override
  String get federationOffWarning =>
      'Desativar a federação derruba todas as pontes com os pares e oculta seus tickets até ela ser reativada. Os pares mantêm os tickets deles.';

  @override
  String federationRequestWantsToPair(String name) {
    return '$name quer parear';
  }

  @override
  String federationRequestToName(String name) {
    return 'Solicitação para $name';
  }

  @override
  String federationRequestOffers(String libraries) {
    return 'Oferece $libraries';
  }

  @override
  String get federationRequestOffersNothing => 'Não oferece nada';

  @override
  String federationRequestYouOffered(String libraries) {
    return 'Você ofereceu $libraries';
  }

  @override
  String get federationRequestYouOfferedNothing => 'Você não ofereceu nada';

  @override
  String get federationReqSending => 'enviando…';

  @override
  String get federationReqWaiting => 'aguardando resposta';

  @override
  String get federationReqSharingBack => 'compartilhando de volta…';

  @override
  String get federationReqNeedsAnswer => 'precisa da sua resposta';

  @override
  String get federationReqSendingTicket => 'enviando seu ticket…';

  @override
  String get federationReqWaitingShare => 'aguardando o compartilhamento deles';

  @override
  String get federationReqDeclined => 'recusada';

  @override
  String get federationReqYouDeclined => 'você recusou';

  @override
  String get federationReqInboxClosed =>
      'a caixa de entrada deles está fechada';

  @override
  String get federationReqFederated => 'federada';

  @override
  String get federationReqWithdrawn => 'retirada';

  @override
  String get federationReqExpired => 'expirada';

  @override
  String get federationAccept => 'Aceitar…';

  @override
  String get federationAcceptAndShare => 'Aceitar e compartilhar';

  @override
  String get federationDecline => 'Recusar';

  @override
  String get federationCancelRequest => 'Cancelar solicitação';

  @override
  String get federationDismiss => 'Dispensar';

  @override
  String get federationRequestTitle => 'Solicitação de pareamento';

  @override
  String federationRequestReceived(String ago) {
    return 'Recebida $ago pela rede de descoberta';
  }

  @override
  String federationRequestSent(String ago) {
    return 'Enviada $ago pela rede de descoberta';
  }

  @override
  String get federationShareBack => 'Compartilhar de volta';

  @override
  String get federationShareBackNote =>
      'Nada é trocado até você aceitar. Eles terão acesso somente leitura às bibliotecas que você marcar — pelo menos uma.';

  @override
  String get federationTheirLimits => 'Os limites deles';

  @override
  String get federationChange => 'Alterar';

  @override
  String get federationRequestIgnored =>
      'As solicitações deste servidor serão ignoradas por 7 dias';

  @override
  String get federationRequestAccepted => 'Solicitação aceita';

  @override
  String get federationRequestDeclined => 'Solicitação recusada';

  @override
  String get federationRequestCancelled => 'Solicitação retirada';

  @override
  String get federationRequestActionFailed =>
      'Não foi possível atualizar a solicitação.';

  @override
  String get federationTicketNameLabel => 'Para quem é?';

  @override
  String get federationTicketNameHint =>
      'Só você vê este nome — ele identifica o ticket na sua lista.';

  @override
  String get federationLibrariesTheyCanRead => 'Bibliotecas que eles podem ler';

  @override
  String get federationLimitsSection => 'Limites';

  @override
  String get federationExactNumbers => 'Valores exatos';

  @override
  String get federationPresets => 'Predefinições';

  @override
  String get federationLimitStreamRate => 'Taxa de streaming';

  @override
  String get federationLimitPerDay => 'Por dia';

  @override
  String get federationLimitStreams => 'Streams simultâneos';

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
      one: '$count dia',
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
      one: '$count stream',
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
      other: 'em $count dias',
      one: 'em $count dia',
    );
    return '$_temp0';
  }

  @override
  String federationInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'em $count horas',
      one: 'em $count hora',
    );
    return '$_temp0';
  }

  @override
  String get federationStreamRateField => 'Taxa (kbps, 0 = ilimitada)';

  @override
  String get federationPerDayField => 'Cota diária (MB, 0 = ilimitada)';

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
      'Este servidor não tem bibliotecas para compartilhar.';

  @override
  String get federationTicketTitle => 'Seu ticket';

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
      'Na mesma sala? Deixe que escaneiem isto.';

  @override
  String get federationTicketWarning =>
      'Qualquer pessoa com este ticket pode ler essas bibliotecas até ele ser resgatado ou revogado. Envie-o por um canal privado — o primeiro servidor a usá-lo fica com ele.';

  @override
  String get federationCopyTicket => 'Copiar ticket';

  @override
  String get federationTicketCopied => 'Ticket copiado';

  @override
  String get federationSendByText => 'Enviar por mensagem…';

  @override
  String get federationTicketRevokeNote =>
      'Revogue-o a qualquer momento em Federação. Se reinstalarem, \"Redefinir resgate\" permite que o ticket seja resgatado novamente.';

  @override
  String get federationTicketNotRunning =>
      'O endpoint de federação não está em execução, então ainda não há ticket para enviar. Ative a federação e volte.';

  @override
  String federationShareMessage(String libraries, String ticket) {
    return 'Estou compartilhando minha biblioteca de música do mStream com você — $libraries, somente leitura. No app mStream, abra Federação → Adicionar um par e cole este ticket:\n\n$ticket\n\nEle funciona uma vez — posso revogá-lo a qualquer momento.';
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
    return 'Último uso $ago';
  }

  @override
  String get federationKeyNeverUsed => 'Nunca usado';

  @override
  String federationKeyClaimedAgo(String ago) {
    return 'Resgatado $ago';
  }

  @override
  String get federationResetBinding => 'Redefinir resgate';

  @override
  String get federationResetBindingNote =>
      'Seu amigo reinstalou? Permita que o ticket seja resgatado novamente.';

  @override
  String get federationBindingReset => 'O ticket pode ser resgatado novamente';

  @override
  String get federationRevoke => 'Revogar';

  @override
  String federationRevokeConfirm(String name) {
    return 'Revogar este ticket? $name perde o acesso imediatamente.';
  }

  @override
  String get federationRevoked => 'Ticket revogado';

  @override
  String get federationSaveLimits => 'Salvar limites';

  @override
  String get federationLimitsSaved => 'Limites salvos';

  @override
  String get federationLimitsFailed => 'Não foi possível salvar os limites.';

  @override
  String get federationSend => 'Enviar';

  @override
  String get federationKeyTitle => 'Biblioteca compartilhada';

  @override
  String federationActionFailed(String error) {
    return 'Isso não funcionou: $error';
  }

  @override
  String get federationTheirTicket => 'O ticket deles';

  @override
  String get federationScanQr => 'Escanear um código QR';

  @override
  String get federationScannerTitle => 'Escanear um ticket de federação';

  @override
  String get federationPaste => 'Colar';

  @override
  String get federationTicketPasted => 'Colado da área de transferência.';

  @override
  String get federationNotATicket => 'Isso não parece um ticket de federação.';

  @override
  String get federationTicketTooNew =>
      'Este ticket vem de um mStream mais recente do que este app entende.';

  @override
  String get federationTicketExpiredNote => 'Este ticket expirou.';

  @override
  String get federationDisplayName => 'Nome de exibição';

  @override
  String get federationDisplayNameHint =>
      'Opcional — como aparece no seu seletor de servidores.';

  @override
  String federationSharesLibraries(String libraries) {
    return 'Compartilha $libraries';
  }

  @override
  String get federationSharesUnknown => 'Bibliotecas não indicadas no ticket';

  @override
  String federationValidUntil(String date) {
    return 'válido até $date';
  }

  @override
  String federationAddPeerShowsUnder(String server) {
    return 'Aparece abaixo de $server';
  }

  @override
  String federationAddPeerReadOnly(String branch, String name) {
    return 'Somente leitura · $branch $name no seletor';
  }

  @override
  String get federationAddPeerDials => 'Seu servidor se conecta a ele por iroh';

  @override
  String get federationAddPeerEncrypted =>
      'Criptografado de ponta a ponta · sem redirecionamento de portas';

  @override
  String get federationAddPeerNoTicket =>
      'Ainda sem ticket? Peça para enviarem um por mensagem.';

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
  String get federationLibrariesYouCanRead => 'Bibliotecas que você pode ler';

  @override
  String get federationDiscoverySection => 'Descoberta';

  @override
  String get federationAskPeerSimilar => 'Pedir músicas semelhantes a este par';

  @override
  String get federationAskPeerSimilarNote =>
      'Envia o que você está ouvindo — só para este par.';

  @override
  String get federationAutoDjSection => 'Auto DJ';

  @override
  String get federationAutoDjParticipates =>
      'Participa do Auto DJ multisservidor';

  @override
  String get federationAutoDjParticipatesNote =>
      'Responde com a própria biblioteca quando o DJ está ativado';

  @override
  String get federationAutoDjNotCandidate => 'Não é candidato ao Auto DJ';

  @override
  String get federationAutoDjNotCandidateNote =>
      'Precisa de um servidor capaz de responder a seleções sonoras';

  @override
  String get federationTest => 'Testar';

  @override
  String get federationTesting => 'Testando…';

  @override
  String get federationTestOk => 'Acessível';

  @override
  String federationTestFailed(String error) {
    return 'Não foi possível alcançá-lo: $error';
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
    return 'Remover $name? As faixas na fila vindas dele param de tocar.';
  }

  @override
  String federationPeerRemoved(String name) {
    return '$name removido';
  }

  @override
  String get federationShowInPicker => 'Mostrar no seletor de servidores';

  @override
  String get federationShowInPickerNote =>
      'Pares ocultos continuam tocando o que você colocou na fila a partir deles.';

  @override
  String get federationPeerReadOnlyNote =>
      'Somente leitura — playlists e avaliações ficam no seu próprio servidor.';

  @override
  String get federationPeerLibrariesUnknown =>
      'Ainda não listadas — abra-o uma vez para carregar as bibliotecas.';

  @override
  String get federationTransportDirect => 'Túnel direto a partir deste celular';

  @override
  String get federationTransportRelay => 'Relay em espera';

  @override
  String federationTransportViaParent(String parent) {
    return 'Através de $parent';
  }

  @override
  String federationTransportViaParentTunnel(String parent) {
    return 'Através de $parent, pelo túnel dele';
  }

  @override
  String get federationDiscoveryFailed =>
      'Não foi possível atualizar a configuração de descoberta.';

  @override
  String get agoJustNow => 'agora mesmo';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count min',
      one: 'há $count min',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count h',
      one: 'há $count h',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count dias',
      one: 'há $count dia',
    );
    return '$_temp0';
  }

  @override
  String get browserP2pNetwork => 'Rede P2P';

  @override
  String get browserP2pOn => 'Ativada';

  @override
  String get browserP2pOff => 'Desativada';

  @override
  String get p2pTitle => 'Rede P2P';

  @override
  String get p2pStatusConnected => 'Conectado';

  @override
  String p2pNeighborsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vizinhos',
      one: '$count vizinho',
    );
    return '$_temp0';
  }

  @override
  String p2pAnnouncingAs(String name) {
    return 'anunciando como $name';
  }

  @override
  String get p2pStatusSearching => 'Na rede · aguardando vizinhos';

  @override
  String p2pStatusReconnecting(int n) {
    return 'Reconectando · tentativa $n';
  }

  @override
  String get p2pStatusNotJoined => 'Ainda não entrou';

  @override
  String get p2pStatusOff => 'Desativada';

  @override
  String get p2pStatusUnavailable => 'Indisponível nesta plataforma';

  @override
  String get p2pStatNeighbors => 'vizinhos na malha';

  @override
  String get p2pStatNeighborsSub => 'conexões gossip ativas';

  @override
  String get p2pStatKnown => 'servidores conhecidos';

  @override
  String p2pStatKnownSub(int hidden, int blocked) {
    return '$hidden ocultos · $blocked bloqueados';
  }

  @override
  String get p2pStatHeld => 'snapshots retidos';

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
      one: 'pesquisáveis, $count biblioteca',
    );
    return '$_temp0';
  }

  @override
  String get p2pActivity => 'Atividade';

  @override
  String get p2pActivitySubtitle => 'mais recente primeiro · só em memória';

  @override
  String get p2pActivityEmpty =>
      'Ainda nada — entradas na malha, downloads de snapshots, rotações e recuperações aparecem aqui conforme acontecem.';

  @override
  String get p2pActivityNote =>
      'O histórico completo fica nos registros do servidor.';

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
          'Abre Descobrir para a faixa em reprodução · sugestões de $count bibliotecas baixadas',
      one:
          'Abre Descobrir para a faixa em reprodução · sugestões de $count biblioteca baixada',
    );
    return '$_temp0';
  }

  @override
  String get p2pFindSimilarNothingPlaying =>
      'Toque algo primeiro — Descobrir segue a faixa atual';

  @override
  String get p2pNewArtistsOnlySub =>
      'Ocultar sugestões de artistas que já estão nesta biblioteca';

  @override
  String get p2pServersYouFollow => 'Servidores que você segue';

  @override
  String get p2pServersOnNetwork => 'Servidores na rede';

  @override
  String get p2pNoServersYet =>
      'Nenhum servidor detectado ainda — adicione um com o ticket de um amigo ou dê um minuto ao gossip.';

  @override
  String p2pHiddenIncompatible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servidores ocultos — modelo incompatível',
      one: '$count servidor oculto — modelo incompatível',
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
      one: '$count faixa',
    );
    return '$_temp0';
  }

  @override
  String p2pSeedersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seeders',
      one: '$count seeder',
    );
    return '$_temp0';
  }

  @override
  String get p2pChipDownloaded => 'baixado';

  @override
  String get p2pChipUpdate => 'atualização disponível';

  @override
  String get p2pChipNotDownloaded => 'não baixado';

  @override
  String get p2pChipPinned => 'fixado';

  @override
  String get p2pChipIncompatible => 'modelo incompatível';

  @override
  String get p2pChipFederated => 'federado';

  @override
  String get p2pChipTheyAsked => 'pediram a você';

  @override
  String get p2pChipRequestSent => 'solicitação enviada';

  @override
  String get p2pSearchingTitle => 'Procurando pares';

  @override
  String get p2pSearchingBody =>
      'A malha se forma em cerca de um minuto. Esta tela se atualiza sozinha.';

  @override
  String get p2pReconnectingTitle => 'Reconectando';

  @override
  String p2pReconnectingBody(int n) {
    return 'O sidecar parou e está sendo reiniciado (tentativa $n) — nenhuma ação necessária.';
  }

  @override
  String get p2pJoinTitle => 'Recomendações das bibliotecas de outras pessoas';

  @override
  String get p2pWhatShared => 'O que é compartilhado';

  @override
  String get p2pShared1 => 'Um snapshot só com metadados';

  @override
  String get p2pShared1Sub =>
      'Artista, título, duração, impressões sonoras — nunca arquivos de áudio';

  @override
  String get p2pShared2 => 'O nome e a descrição do seu servidor';

  @override
  String get p2pShared2Sub =>
      'Visíveis para todos na rede — por padrão, a rede pública da comunidade';

  @override
  String get p2pHowYouAppear => 'Como você aparece';

  @override
  String get p2pServerName => 'Nome do servidor';

  @override
  String get p2pServerNameHint =>
      '“mStream” ao lado de outros 18.000 mStreams é a primeira coisa a mudar.';

  @override
  String get p2pDescription => 'Descrição';

  @override
  String get p2pDescriptionHint => '180 caracteres, opcional.';

  @override
  String get p2pAlsoAcceptRequests =>
      'Aceitar também solicitações de federação';

  @override
  String get p2pAlsoAcceptRequestsSub =>
      'Convites para compartilhar bibliotecas — nada é compartilhado até você aprovar cada um. Ativa a federação.';

  @override
  String get p2pJoin => 'Entrar na rede';

  @override
  String get p2pJoining => 'Entrando…';

  @override
  String get p2pJoined =>
      'Entrou na rede de descoberta — dê um minuto para a malha se formar.';

  @override
  String p2pJoinFailed(String error) {
    return 'Não foi possível entrar na rede: $error';
  }

  @override
  String p2pInboxFailed(String error) {
    return 'A descoberta está ativada, mas a caixa de solicitações não iniciou: $error';
  }

  @override
  String get p2pUnavailableNote =>
      'O binário p2p-sidecar não foi encontrado para esta plataforma e não há build para baixar — a rede está indisponível.';

  @override
  String get p2pWillDownloadNote =>
      'O sidecar ainda não está instalado; ao entrar, ele é baixado primeiro.';

  @override
  String get p2pAdminOnlyNote => 'Só o administrador do servidor pode entrar.';

  @override
  String p2pMemberOffNote(String server) {
    return 'A rede de descoberta está desativada em $server. O administrador pode entrar.';
  }

  @override
  String p2pMemberNote(String server) {
    return 'Entrar, convidar e gerenciar snapshots são tarefas do administrador. Faça login em $server como administrador para gerenciar a rede aqui.';
  }

  @override
  String get p2pSnapshotSection => 'Snapshot';

  @override
  String p2pDownloadedSize(String size) {
    return 'Baixado · $size';
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
  String get p2pNotDownloaded => 'Não baixado';

  @override
  String get p2pNotDownloadedSub =>
      'Baixe-o para pesquisar nele a partir de Descobrir';

  @override
  String get p2pDownload => 'Baixar';

  @override
  String get p2pUpdate => 'Atualizar';

  @override
  String get p2pDownloading => 'Baixando…';

  @override
  String get p2pDownloaded => 'Snapshot baixado';

  @override
  String p2pDownloadFailed(String error) {
    return 'Não foi possível baixar o snapshot: $error';
  }

  @override
  String get p2pPin => 'Fixar este snapshot';

  @override
  String p2pPinSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'A rotação libera os snapshots menos usados após $count dias; um fixado permanece.',
      one:
          'A rotação libera os snapshots menos usados após $count dia; um fixado permanece.',
    );
    return '$_temp0';
  }

  @override
  String get p2pPinSubNoRotation =>
      'A rotação está desativada; um snapshot fixado também sobrevive à falta de espaço.';

  @override
  String get p2pRemoveSnapshot => 'Remover snapshot';

  @override
  String get p2pSnapshotRemoved => 'Snapshot removido';

  @override
  String get p2pHeldSince => 'retido desde';

  @override
  String get p2pTracksLabel => 'faixas';

  @override
  String get p2pSeedersLabel => 'seeders';

  @override
  String get p2pSeedersSub => 'servindo o snapshot';

  @override
  String get p2pFederatedWithYou => 'Federado com você';

  @override
  String get p2pFederatedWithYouSub =>
      'Abra Federação para ver o que vocês leem um do outro';

  @override
  String get p2pTheyAskedYou => 'Eles pediram para federar';

  @override
  String get p2pTheyAskedYouSub => 'Revise a solicitação em Federação';

  @override
  String get p2pRequestSentTitle => 'Solicitação enviada';

  @override
  String get p2pRequestSentSub =>
      'Aguardando resposta · acompanhe em Federação';

  @override
  String get p2pAskToFederate => 'Pedir para compartilhar bibliotecas';

  @override
  String get p2pAskToFederateSub =>
      'Envia uma solicitação pela rede — nada é trocado por enquanto';

  @override
  String get p2pOpen => 'Abrir';

  @override
  String get p2pReview => 'Revisar';

  @override
  String get p2pForget => 'Esquecer este servidor';

  @override
  String get p2pForgetSub =>
      'Offline e sem nada baixado; volta se for detectado de novo';

  @override
  String p2pForgotten(String name) {
    return '$name esquecido';
  }

  @override
  String get p2pBlockServer => 'Bloquear servidor';

  @override
  String p2pBlockConfirm(String name) {
    return 'Bloquear $name? Seus anúncios serão ignorados e seu snapshot removido.';
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
      'Modelo de embeddings incompatível — a biblioteca dele não pode alimentar a pesquisa de semelhantes deste servidor.';

  @override
  String get p2pCompatible => 'modelo compatível';

  @override
  String get p2pModelUnknown => 'modelo desconhecido';

  @override
  String get p2pNoDescription => 'Sem descrição.';

  @override
  String get p2pUnnamedServer => 'Servidor sem nome';

  @override
  String get p2pFederateTitle => 'Pedir para federar';

  @override
  String get p2pFederateNote =>
      'Envia uma solicitação pela rede de descoberta. Nenhum acesso é trocado agora — eles veem seu nome, sua mensagem e sua oferta; as bibliotecas só são compartilhadas se eles aceitarem.';

  @override
  String get p2pMessage => 'Mensagem';

  @override
  String p2pMessageHint(int n) {
    return 'Opcional · $n / 500';
  }

  @override
  String get p2pShareBackLibraries =>
      'Bibliotecas que você compartilhará de volta se eles aceitarem';

  @override
  String get p2pShareBackNote =>
      'Desmarque tudo para uma solicitação unilateral — você só leria as deles.';

  @override
  String get p2pSendRequest => 'Enviar solicitação';

  @override
  String get p2pRequestSent => 'Solicitação enviada — acompanhe em Federação';

  @override
  String p2pRequestFailed(String error) {
    return 'Não foi possível enviar a solicitação: $error';
  }

  @override
  String get p2pTheirTicket => 'O ticket deles';

  @override
  String get p2pTheirTicketHint =>
      'Um amigo encontra o dele em “Convidar um amigo” na tela Rede P2P.';

  @override
  String get p2pTicketPasted => 'Colado da área de transferência.';

  @override
  String get p2pRememberFriend => 'Lembrar este amigo';

  @override
  String get p2pRememberFriendSub =>
      'Salvo na configuração do servidor para que a amizade sobreviva a reinícios.';

  @override
  String get p2pJoinFriend => 'Entrar';

  @override
  String get p2pJoinedFriend => 'Entrou — a malha se forma em um minuto';

  @override
  String p2pJoinFriendFailed(String error) {
    return 'Não foi possível entrar: $error';
  }

  @override
  String get p2pNotATicket => 'Isso não parece um ticket de endpoint.';

  @override
  String get p2pScanQr => 'Escanear um código QR';

  @override
  String get p2pScannerTitle => 'Escanear um ticket de rede';

  @override
  String get p2pInviteFriend => 'Convidar um amigo';

  @override
  String p2pYourTicketNote(String name) {
    return 'Seu ticket — um amigo cola isto no celular dele para adicionar $name. É um endereço, não uma credencial.';
  }

  @override
  String get p2pTicketCopied => 'Ticket copiado';

  @override
  String p2pShareMessage(String ticket) {
    return 'Adicione meu servidor mStream na rede de descoberta — no app mStream, abra Rede P2P → Adicionar um servidor amigo e cole este ticket:\n\n$ticket';
  }

  @override
  String get p2pShareSubject => 'Ticket da rede de descoberta mStream';

  @override
  String get p2pTicketNotReady =>
      'O sidecar ainda não está em execução, então ainda não há ticket para compartilhar.';

  @override
  String get p2pSettingsTitle => 'Configurações de rede';

  @override
  String get p2pSwitchTitle => 'Rede de descoberta';

  @override
  String get p2pSwitchSub =>
      'Anuncia à rede um snapshot só com metadados. Desative para sair — os dados coletados permanecem locais.';

  @override
  String get p2pLeaveConfirm =>
      'Sair da rede de descoberta? Seu servidor para de anunciar e de baixar snapshots. A descoberta local continua funcionando.';

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
  String get p2pIdentitySaved => 'Salvo — anunciado à rede';

  @override
  String p2pSaveFailed(String error) {
    return 'Não foi possível salvar: $error';
  }

  @override
  String get p2pSnapshotsSection => 'Snapshots';

  @override
  String get p2pAutoDownload => 'Download automático de até';

  @override
  String p2pServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servidores',
      one: '$count servidor',
    );
    return '$_temp0';
  }

  @override
  String get p2pStorageCap => 'Limite de armazenamento';

  @override
  String get p2pRotate => 'Rotacionar downloads';

  @override
  String get p2pForgetOffline => 'Esquecer servidores offline';

  @override
  String get p2pMeshSection => 'Malha';

  @override
  String get p2pCommunitySeeds => 'Seeds da comunidade';

  @override
  String get p2pCommunitySeedsOn =>
      'Inicialização pelos servidores seed públicos';

  @override
  String get p2pCommunitySeedsOff =>
      'Desativados — só servidores amigos; definido na configuração do servidor';

  @override
  String p2pBlockedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servidores bloqueados',
      one: '$count servidor bloqueado',
      zero: 'Nenhum servidor bloqueado',
    );
    return '$_temp0';
  }

  @override
  String get p2pBlockedSub => 'Anúncios ignorados, snapshots nunca baixados';

  @override
  String get p2pBlockedTitle => 'Servidores bloqueados';

  @override
  String get p2pSaved => 'Salvo';

  @override
  String get p2pOff => 'Desativada';

  @override
  String get p2pSave => 'Salvar';

  @override
  String get p2pSearchServers => 'Procurar servidores — nome ou descrição';

  @override
  String federationInboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solicitações de federação aguardando',
      one: '$count solicitação de federação aguardando',
    );
    return '$_temp0';
  }

  @override
  String get federationInboxBannerSub => 'Toque para aceitar ou recusar';

  @override
  String federationInboxNotificationTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count solicitações de federação aguardando',
      one: 'Há uma solicitação de federação aguardando',
    );
    return '$_temp0';
  }

  @override
  String federationInboxNotificationBody(String server) {
    return 'Em $server. Abra para aceitar ou recusar.';
  }

  @override
  String get federationInboxChannelName => 'Solicitações de federação';

  @override
  String get federationInboxChannelDescription =>
      'Chegou uma solicitação para compartilhar bibliotecas em um dos seus servidores';

  @override
  String get federationNotifyTitle => 'Notificar sobre solicitações';

  @override
  String get federationNotifySubtitle =>
      'Uma notificação no celular quando chega uma solicitação com o app aberto ou tocando';

  @override
  String get autoRecentlyPlayed => 'Reproduzidas recentemente';

  @override
  String get settingsSectionListening => 'Histórico de escuta';

  @override
  String get settingsHistoryEnabled => 'Manter histórico de escuta';

  @override
  String get settingsHistoryEnabledSubtitle =>
      'Registra o que este celular reproduz, em todos os servidores e com arquivos locais. Fica somente neste dispositivo.';

  @override
  String get settingsHistorySend => 'Enviar reproduções aos seus servidores';

  @override
  String get settingsHistorySendSubtitle =>
      'Cada reprodução vai para o servidor onde a faixa está (a faixa de um par, para o servidor principal dele), para que suas estatísticas incluam este celular. Os servidores só encaminham ao Last.fm se você vinculou uma conta lá.';

  @override
  String get settingsHistoryClear => 'Limpar histórico de escuta';

  @override
  String settingsHistoryClearSubtitle(Object size) {
    return 'Remove o registro deste celular ($size). Seus servidores mantêm o deles.';
  }

  @override
  String get settingsHistoryClearConfirm =>
      'Apagar o histórico de escuta deste celular? As reproduções já enviadas a um servidor continuam lá.';

  @override
  String get settingsHistoryCleared => 'Histórico de escuta limpo';

  @override
  String settingsHistoryUnsynced(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções aguardando envio',
      one: '$count reprodução aguardando envio',
      zero: 'Tudo sincronizado',
    );
    return '$_temp0';
  }

  @override
  String songInfoServerPlays(num count, Object server) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções em $server',
      one: '$count reprodução em $server',
    );
    return '$_temp0';
  }

  @override
  String songInfoDevicePlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções neste celular',
      one: '$count reprodução neste celular',
    );
    return '$_temp0';
  }

  @override
  String songInfoLastPlayed(Object ago) {
    return 'última vez $ago';
  }

  @override
  String get listeningTitle => 'Estatísticas de escuta';

  @override
  String get listeningScopeThisPhone => 'Este celular';

  @override
  String get listeningScopeSheetTitle => 'O que mostrar';

  @override
  String get listeningScopeSheetDevice =>
      'O que este celular reproduziu: todos os servidores, arquivos locais, offline. Fica neste dispositivo.';

  @override
  String get listeningScopeSheetServer =>
      'Suas reproduções neste servidor de todos os apps: o player web, outros celulares e este celular depois de sincronizado.';

  @override
  String get listeningScopeSheetLegacy =>
      'Ainda sem estatísticas de escuta: requer mStream 6.27 ou mais recente.';

  @override
  String listeningScopeSheetPeer(Object server) {
    return 'Contadas em $server: as faixas de um par contam onde sua conta está.';
  }

  @override
  String get listeningProvenanceDevice =>
      'O que este celular reproduziu, em todos os servidores e com arquivos locais. Fica neste dispositivo.';

  @override
  String listeningProvenanceServer(Object server) {
    return 'Suas reproduções em $server de todos os apps, incluindo faixas dos pares dele.';
  }

  @override
  String listeningProvenancePeer(Object peer, Object server) {
    return 'Suas reproduções das faixas de $peer, contadas em $server.';
  }

  @override
  String listeningProvenanceFallback(Object server) {
    return '$server não respondeu: mostrando as reproduções deste celular nele.';
  }

  @override
  String listeningProvenanceLegacy(Object server) {
    return '$server ainda não tem estatísticas de escuta (mStream 6.27+): mostrando as reproduções deste celular nele.';
  }

  @override
  String listeningUnsynced(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções ainda não sincronizadas',
      one: '$count reprodução ainda não sincronizada',
    );
    return '$_temp0';
  }

  @override
  String get listeningPeriodWeek => 'Esta semana';

  @override
  String get listeningPeriodMonth => 'Este mês';

  @override
  String get listeningPeriodQuarter => 'Este trimestre';

  @override
  String get listeningPeriodYear => 'Este ano';

  @override
  String get listeningPeriodAll => 'Todo o período';

  @override
  String get listeningTilePlays => 'Reproduções';

  @override
  String get listeningTileTime => 'Tempo de escuta';

  @override
  String get listeningTileTracks => 'Faixas';

  @override
  String get listeningTileSkips => 'Ignoradas';

  @override
  String get listeningTileStreak => 'Sequência';

  @override
  String get listeningTileSessions => 'Sessões';

  @override
  String listeningDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '$count dia',
    );
    return '$_temp0';
  }

  @override
  String get listeningTileSubCounted => 'reproduções contadas';

  @override
  String get listeningTileSubTracks => 'faixas diferentes';

  @override
  String listeningTileSubSkips(Object pct) {
    return '$pct% dos inícios';
  }

  @override
  String listeningTileSubStreak(Object count) {
    return 'mais longa: $count';
  }

  @override
  String listeningTileSubSessions(Object duration) {
    return 'cerca de $duration cada';
  }

  @override
  String get listeningWhenYouListen => 'Quando você ouve';

  @override
  String listeningMostAround(Object hour) {
    return 'Mais por volta das $hour';
  }

  @override
  String get listeningTop => 'Top';

  @override
  String get listeningTopTracks => 'Faixas';

  @override
  String get listeningTopArtists => 'Artistas';

  @override
  String get listeningTopAlbums => 'Álbuns';

  @override
  String get listeningByPlays => 'Reproduções';

  @override
  String get listeningByTime => 'Tempo';

  @override
  String listeningPlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções',
      one: '$count reprodução',
    );
    return '$_temp0';
  }

  @override
  String listeningTracksCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '$count faixa',
    );
    return '$_temp0';
  }

  @override
  String get listeningRecent => 'Reproduções recentes';

  @override
  String get listeningLoadMore => 'Carregar mais';

  @override
  String get listeningEmptyTitle => 'Nenhuma reprodução ainda';

  @override
  String get listeningEmptyDevice =>
      'As reproduções aparecem aqui conforme você ouve. Este celular mantém o próprio registro; seu servidor mantém o seu em todos os apps.';

  @override
  String listeningEmptyServer(Object server) {
    return 'Nada foi informado a $server ainda. As reproduções deste celular chegam depois de sincronizadas.';
  }

  @override
  String get listeningEmptyPeriod => 'Nada neste período.';

  @override
  String get listeningOutcomeCompleted => 'Concluída';

  @override
  String get listeningOutcomeSkipped => 'Ignorada';

  @override
  String get listeningOutcomeStopped => 'Parada';

  @override
  String listeningOutcomeAt(Object outcome, Object position) {
    return '$outcome em $position';
  }

  @override
  String get listeningNotCounted => 'não contada';

  @override
  String listeningVia(Object peer) {
    return 'via $peer';
  }

  @override
  String listeningRepeats(Object count) {
    return '×$count';
  }

  @override
  String get listeningLocalFile => 'Arquivo local';

  @override
  String get listeningHistoryOff =>
      'O histórico de escuta está desativado. Ative-o nas configurações para registrar as reproduções neste celular.';

  @override
  String listeningError(Object message) {
    return 'Não foi possível carregar: $message';
  }

  @override
  String get listeningRetry => 'Tentar novamente';

  @override
  String get listeningToday => 'Hoje';

  @override
  String get listeningYesterday => 'Ontem';

  @override
  String get listeningPlaysPerDay => 'Reproduções por dia';

  @override
  String get listeningPlaysPerMonth => 'Reproduções por mês';

  @override
  String listeningMostOnDay(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mais em $date: $count reproduções',
      one: 'Mais em $date: $count reprodução',
    );
    return '$_temp0';
  }

  @override
  String listeningMostInMonth(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mais em $month: $count reproduções',
      one: 'Mais em $month: $count reprodução',
    );
    return '$_temp0';
  }

  @override
  String get settingsHomeWidget => 'Widget da tela inicial';

  @override
  String get settingsHomeWidgetSubtitle =>
      'Adicione o widget Tocando agora à tela inicial em um de cinco tamanhos.';

  @override
  String get settingsHomeWidgetSubtitleIos =>
      'Toque e segure na tela inicial, adicione um widget e escolha mStream Music.';

  @override
  String get homeWidgetPickSize => 'Escolha um tamanho';

  @override
  String get homeWidgetPinUnsupported =>
      'Este launcher não consegue adicionar widgets daqui. Use o seletor de widgets dele.';
}
