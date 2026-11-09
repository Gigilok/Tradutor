import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/app_state.dart';
import '../services/movie_service.dart';
import 'player_screen.dart';

/// Lista de filmes da sala. Permite adicionar por LINK (mp4/m3u8)
/// ou por ARQUIVO que está no próprio aparelho.
class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  final _movies = MovieService();
  List<Movie> _list = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final state = context.read<AppState>();
    try {
      final list = await _movies.loadMovies(state.roomId);
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Erro ao carregar filmes: $error');
    }
  }

  Future<void> _addByUrl() async {
    if (_busy) return;
    final state = context.read<AppState>();
    final title = TextEditingController();
    final url = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2227),
        title: const Text('Adicionar por link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Nome do filme',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link do vídeo',
                hintText: 'https://... .mp4 ou .m3u8',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Serve link direto de vídeo (.mp4, .m3u8/HLS). '
              'Assim as duas conseguem assistir juntas.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    if (url.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await _movies.addByUrl(
        roomId: state.roomId,
        addedBy: state.name,
        title: title.text,
        url: url.text,
      );
      await _reload();
    } catch (error) {
      _showError('Erro ao adicionar: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addLocalFile() async {
    if (_busy) return;
    final state = context.read<AppState>();
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null || !mounted) return;

      final name = picked!.files.single.name;
      final titleController = TextEditingController(text: name);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E2227),
          title: const Text('Nome do filme'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Adicionar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final finalTitle = titleController.text.trim().isEmpty
          ? name
          : titleController.text.trim();

      setState(() => _busy = true);
      // Copia o vídeo para a pasta privada do app para não sumir depois.
      final dir = await getApplicationDocumentsDirectory();
      final moviesDir = Directory('${dir.path}/movies');
      if (!moviesDir.existsSync()) moviesDir.createSync(recursive: true);
      final dest = '${moviesDir.path}/$name';
      final sourceFile = File(path);
      if (!sourceFile.existsSync()) {
        throw Exception('Arquivo não encontrado.');
      }
      await sourceFile.copy(dest);

      await _movies.addLocalFile(
        roomId: state.roomId,
        addedBy: state.name,
        title: finalTitle,
        localPath: dest,
      );
      await _reload();
    } catch (error) {
      _showError('Erro ao adicionar arquivo: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Movie movie) async {
    try {
      await _movies.removeMovie(movie.id);
      await _reload();
    } catch (error) {
      _showError('Erro ao remover: $error');
    }
  }

  void _openPlayer(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PlayerScreen(movie: movie)),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filmes'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.black87),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF1E2227),
        onSelected: (value) {
          if (value == 'url') _addByUrl();
          if (value == 'file') _addLocalFile();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'url',
            child: ListTile(
              leading: Icon(Icons.link),
              title: Text('Por link (.mp4/.m3u8)'),
              subtitle: Text('As duas assistem juntas'),
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: 'file',
            child: ListTile(
              leading: Icon(Icons.folder_outlined),
              title: Text('Arquivo do meu aparelho'),
              subtitle: Text('A amiga escolhe a cópia dela para assistir junto'),
              dense: true,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.movie_outlined,
                          size: 56, color: Colors.white24),
                      SizedBox(height: 12),
                      Text(
                        'Nenhum filme ainda.\n'
                        'Toque no + para adicionar um link\n'
                        'ou um vídeo do seu aparelho.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final movie = _list[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            movie.isLocal
                                ? Icons.smartphone
                                : Icons.play_circle_fill,
                            color: Colors.black87,
                          ),
                        ),
                        title: Text(
                          movie.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          movie.isLocal
                              ? 'Arquivo local de ${movie.addedBy} — a amiga escolhe a cópia dela'
                              : 'Link · adicionado por ${movie.addedBy}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: const Color(0xFF1E2227),
                          onSelected: (value) {
                            if (value == 'remove') _remove(movie);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Remover da lista'),
                            ),
                          ],
                        ),
                        onTap: () => _openPlayer(movie),
                      ),
                    );
                  },
                ),
    );
  }
}
