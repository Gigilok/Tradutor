import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../config.dart';
import '../models.dart';
import '../service/app_state.dart';
import '../service/movie_service.dart';
import '../service/subtitles.dart';

/// Player de filme com legendas (.srt/.vtt) traduzidas e modo
/// "assistir junto" (quem controla comanda a reprodução dos dois).
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.movie});

  final Movie movie;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _movies = MovieService();

  VideoPlayerController? _controller;
  bool _initialized = false;
  String? _error;

  // O filme pode ser "substituído" localmente quando a amiga escolhe
  // a cópia dela do arquivo.
  late Movie _movie = widget.movie;

  // Legendas
  List<SubtitleCue> _cues = [];
  bool _subtitlesVisible = true;
  SubtitleCue? _currentCue;

  // Assistir junto
  bool _syncActive = false;
  String _controllerName = '';
  bool _applyingRemote = false;
  bool _syncBusy = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _movies.unsubscribe();
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  bool get _isLocal => _movie.isLocal;
  bool get _iControl => _controllerName.isEmpty;

  Future<void> _initPlayer() async {
    final state = context.read<AppState>();
    try {
      // Filme local: confere se a cópia existe NESTE aparelho.
      if (_isLocal) {
        final path = _movie.localPath;
        final file = path == null ? null : File(path);
        if (file == null || !file.existsSync()) {
          if (mounted) setState(() => _error = 'MISSING_FILE');
          return;
        }
      }
      final VideoPlayerController controller;
      if (_isLocal) {
        controller = VideoPlayerController.file(File(_movie.localPath!));
      } else {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(_movie.url!),
        );
      }
      _controller = controller;
      await controller.initialize();
      controller.addListener(_onVideoTick);

      await _setupSync(state);
      if (!mounted) return;
      setState(() => _initialized = true);
      await controller.play();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  Future<void> _setupSync(AppState state) async {
    try {
      final current = await _movies.loadPlayback(state.roomId);
      if (current != null && current.movieId == _movie.id) {
        _controllerName = current.controller;
      }
      _movies.subscribePlayback(state.roomId, (remote) {
        if (remote.movieId != _movie.id) return;
        if (!mounted) return;
        _applyRemoteState(remote);
      });
      _syncActive = true;
    } catch (_) {
      // Sincronização é opcional: segue sem ela.
    }
  }

  /// Recebe o estado remoto e ajusta a reprodução (só quando eu não controlo).
  void _applyRemoteState(PlaybackState remote) {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    if (_iControl || _applyingRemote) return;
    if (remote.controller == _controllerName && mounted) {
      setState(() => _controllerName = remote.controller);
    }
    _applyingRemote = true;
    Future(() async {
      try {
        final target =
            Duration(milliseconds: (remote.positionSeconds * 1000).round());
        final diff = (controller.value.position - target).abs();
        if (diff > const Duration(seconds: 4)) {
          await controller.seekTo(target);
        }
        if (remote.isPlaying && !controller.value.isPlaying) {
          await controller.play();
        } else if (!remote.isPlaying && controller.value.isPlaying) {
          await controller.pause();
        }
      } catch (_) {
        // ignora falhas pontuais de sincronia
      } finally {
        _applyingRemote = false;
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _publishState() async {
    final state = context.read<AppState>();
    final controller = _controller;
    if (!_iControl || controller == null || _syncBusy || !_syncActive) return;
    _syncBusy = true;
    try {
      await _movies.publishPlayback(
        roomId: state.roomId,
        movieId: widget.movie.id,
        positionSeconds: controller.value.position.inMilliseconds / 1000,
        isPlaying: controller.value.isPlaying,
        controller: state.name,
      );
    } catch (_) {
      // silencioso: próximo tick tenta de novo
    } finally {
      _syncBusy = false;
    }
  }

  void _onVideoTick() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    final position = controller.value.position;

    final cue = _cues.isEmpty ? null : SubtitleService.cueAt(_cues, position);
    if (cue?.text != _currentCue?.text ||
        cue?.translated != _currentCue?.translated) {
      setState(() => _currentCue = cue);
    }

    // Quem controla publica a posição a cada ~5 segundos.
    if (_iControl) {
      final seconds = position.inSeconds;
      if (_lastPublishedSeconds != seconds && seconds % 5 == 0) {
        _lastPublishedSeconds = seconds;
        _publishState();
      }
    }
  }

  int _lastPublishedSeconds = -1;

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    await _publishState();
    if (mounted) setState(() {});
  }

  Future<void> _seekTo(Duration position) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.seekTo(position);
    await _publishState();
    if (mounted) setState(() {});
  }

  Future<void> _takeControl() async {
    final state = context.read<AppState>();
    final controller = _controller;
    if (controller == null) return;
    _controllerName = state.name;
    setState(() {});
    await _movies.publishPlayback(
      roomId: state.roomId,
      movieId: _movie.id,
      positionSeconds: controller.value.position.inMilliseconds / 1000,
      isPlaying: controller.value.isPlaying,
      controller: state.name,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você está controlando o filme agora!')),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Legendas
  // ---------------------------------------------------------------------

  Future<void> _loadSubtitles() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2227),
        title: const Text('Carregar legenda'),
        content: const Text(
          'A legenda pode ser um arquivo .srt ou .vtt do seu aparelho, '
          'ou um link direto para o arquivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'url'),
            child: const Text('Link'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'file'),
            child: const Text('Arquivo'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    try {
      String content;
      if (choice == 'file') {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['srt', 'vtt', 'txt'],
          withData: true,
        );
        final bytes = picked?.files.single.bytes;
        if (bytes == null) return;
        content = String.fromCharCodes(bytes);
      } else {
        final urlInput = TextEditingController();
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E2227),
            title: const Text('Link da legenda'),
            content: TextField(
              controller: urlInput,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL do .srt/.vtt',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Carregar'),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        if (urlInput.text.trim().isEmpty) return;
        content = await SubtitleService.download(urlInput.text.trim());
      }

      final cues = SubtitleService.parse(content);
      if (!mounted) return;
      if (cues.isEmpty) {
        _showError('Não encontrei falhas válidas nessa legenda.');
        return;
      }
      setState(() {
        _cues = cues;
        _subtitlesVisible = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Legenda carregada (${cues.length} falas).')),
      );
    } catch (error) {
      _showError('Erro na legenda: $error');
    }
  }

  Future<void> _doTranslateSubtitles(String from) async {
    final state = context.read<AppState>();
    if (from == state.lang) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A legenda já está no seu idioma.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<double>(0);
    final dialogOpen = Completer<void>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        dialogOpen.complete();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2227),
          title: const Text('Traduzindo legendas...'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value == 0 ? null : value),
                const SizedBox(height: 12),
                Text('${(value * 100).toStringAsFixed(0)}%'),
              ],
            ),
          ),
        );
      },
    );

    try {
      await dialogOpen.future;
      await SubtitleService.translateCues(
        _cues,
        from,
        state.lang,
        onProgress: (p) => progress.value = p,
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _subtitlesVisible = true);
        messenger.showSnackBar(
          const SnackBar(content: Text('Legendas traduzidas!')),
        );
      }
    } catch (error) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError('Falha ao traduzir legendas: $error');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  // ---------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          _movie.title,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _iControl
                  ? const Chip(
                      label: Text('Você controla',
                          style: TextStyle(fontSize: 11)),
                      avatar: Icon(Icons.gamepad_outlined, size: 15),
                      visualDensity: VisualDensity.compact,
                    )
                  : ActionChip(
                      label: Text(
                        '$_controllerName controla — assumir',
                        style: const TextStyle(fontSize: 11),
                      ),
                      avatar: const Icon(Icons.swap_horiz, size: 15),
                      visualDensity: VisualDensity.compact,
                      onPressed: _takeControl,
                    ),
            ),
          ),
        ],
      ),
      body: _error != null
          ? _errorView()
          : !_initialized || controller == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          VideoPlayer(controller),
                          if (_subtitlesVisible &&
                              _currentCue != null &&
                              (_currentCue!.translated?.isNotEmpty ?? false))
                            _subtitleOverlay(
                              _currentCue!.translated!,
                            )
                          else if (_subtitlesVisible && _currentCue != null)
                            _subtitleOverlay(_currentCue!.text),
                        ],
                      ),
                    ),
                    _controlsRow(controller),
                    Expanded(
                      child: _subtitleInfoPanel(),
                    ),
                  ],
                ),
    );
  }

  Widget _subtitleOverlay(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withOpacity(0.55),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _controlsRow(VideoPlayerController controller) {
    final position = controller.value.position;
    final duration = controller.value.duration;
    return Column(
      children: [
        Slider(
          value: position.inMilliseconds
              .clamp(0, duration.inMilliseconds)
              .toDouble(),
          max: duration.inMilliseconds == 0
              ? 1
              : duration.inMilliseconds.toDouble(),
          onChanged: (value) => _seekTo(Duration(milliseconds: value.round())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const Spacer(),
              Text(
                _formatDuration(duration),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () => _seekTo(position - const Duration(seconds: 10)),
              icon: const Icon(Icons.replay_10),
              tooltip: 'Voltar 10s',
            ),
            IconButton.filled(
              onPressed: _togglePlay,
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 32,
              ),
              tooltip: 'Play/Pause',
            ),
            IconButton(
              onPressed: () => _seekTo(position + const Duration(seconds: 10)),
              icon: const Icon(Icons.forward_10),
              tooltip: 'Avançar 10s',
            ),
            IconButton(
              onPressed: _loadSubtitles,
              icon: const Icon(Icons.subtitles_outlined),
              tooltip: 'Carregar legenda',
            ),
            IconButton(
              onPressed: _cues.isEmpty ? null : _openSubtitleMenu,
              icon: const Icon(Icons.translate),
              tooltip: 'Legendas / tradução',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openSubtitleMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E2227),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _subtitlesVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              title: Text(
                  _subtitlesVisible ? 'Esconder legendas' : 'Mostrar legendas'),
              onTap: () => Navigator.pop(context, 'toggle'),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Traduzir legendas para o meu idioma'),
              onTap: () => Navigator.pop(context, 'translate'),
            ),
            ListTile(
              leading: const Icon(Icons.subtitles_outlined),
              title: const Text('Carregar outra legenda'),
              onTap: () => Navigator.pop(context, 'load'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'toggle') {
      setState(() => _subtitlesVisible = !_subtitlesVisible);
    }
    if (choice == 'load') await _loadSubtitles();
    if (choice == 'translate') await _openTranslateDialog();
  }

  Future<void> _openTranslateDialog() async {
    final state = context.read<AppState>();
    final from = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2227),
        title: const Text('Traduzir legendas'),
        content: Text(
          'As ${_cues.length} falas serão traduzidas para '
          '${AppConfig.languageName(state.lang)}. '
          'Em qual idioma está a legenda original?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          for (final lang in ['en', 'es', 'pt', 'zh', 'fr', 'ja'])
            TextButton(
              onPressed: () => Navigator.pop(context, lang),
              child: Text(AppConfig.languageName(lang)),
            ),
        ],
      ),
    );
    if (from == null || !mounted) return;
    await _doTranslateSubtitles(from);
  }

  Widget _subtitleInfoPanel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_cues.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.subtitles, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Legenda ativa · ${_cues.length} falas',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentCue?.translated?.isNotEmpty ?? false
                        ? '${_currentCue!.text}\n\n→ ${_currentCue!.translated}'
                        : _currentCue?.text ?? 'Aguardando a próxima fala...',
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        if (_isLocal)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.smartphone, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Este vídeo é do seu aparelho. Quando a sua amiga abrir '
                      'o mesmo filme e escolher a cópia dela, as duas '
                      'assistem juntas: quem estiver com o selo "controla" '
                      'comanda o play e a pausa das duas.',
                      style: TextStyle(fontSize: 12.5, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.groups_outlined, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Use um filme por link para vocês assistirem juntas: '
                      'quem estiver com o selo "controla" comanda o play, '
                      'a pausa e o avanço para as duas ao mesmo tempo.',
                      style: TextStyle(fontSize: 12.5, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickLocalCopy() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null || !mounted) return;
      // Guarda na pasta do app com o MESMO nome do filme,
      // para virar a "cópia da amiga" e permitir assistir junto.
      final dir = await getApplicationDocumentsDirectory();
      final moviesDir = Directory('${dir.path}/movies');
      if (!moviesDir.existsSync()) moviesDir.createSync(recursive: true);
      final name = _movie.fileName ?? picked!.files.single.name;
      final dest = '${moviesDir.path}/$name';
      await File(path).copy(dest);
      if (!mounted) return;
      setState(() {
        _error = null;
        _initialized = false;
        _movie = _movie.copyWith(localPath: dest);
      });
      _initPlayer();
    } catch (error) {
      _showError('Não consegui copiar o vídeo: $error');
    }
  }

  Widget _errorView() {
    if (_error == 'MISSING_FILE') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.folder_off_outlined,
                size: 56,
                color: Colors.amberAccent,
              ),
              const SizedBox(height: 12),
              Text(
                'Esse vídeo está no aparelho de ${_movie.addedBy}.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Para assistir junto, consiga o arquivo com ${_movie.addedBy} '
                '(pode mandar pelo WhatsApp) e salve no seu celular. '
                'Depois toque no botão abaixo e escolha ele.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Colors.white54),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _pickLocalCopy,
                icon: const Icon(Icons.folder_open),
                label: const Text('Escolher o vídeo no meu aparelho'),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Não consegui abrir o vídeo.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Confira o link (precisa terminar em .mp4 ou .m3u8) '
              'ou tente novamente.\n\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _error = null;
                  _initialized = false;
                });
                _initPlayer();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
