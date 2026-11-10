import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../service/app_state.dart';
import 'join_screen.dart';

/// Ajustes: nome, idioma, código da sala e sair da sala.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  String _lang = 'pt';

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _nameController.text = state.name;
    _lang = state.lang;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    await state.updateProfile(
      newName: _nameController.text,
      newLang: _lang,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil atualizado!')),
    );
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2227),
        title: const Text('Sair da sala?'),
        content: const Text(
          'Você voltará para a tela de entrada e poderá criar uma nova '
          'sala ou entrar com outro código. As mensagens recentes da '
          'sala ficam guardadas no servidor público dela.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    await context.read<AppState>().leaveRoom();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const JoinScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          state.name.isNotEmpty
                              ? state.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              AppConfig.languageName(state.lang),
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Seu nome',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _lang,
                    decoration: const InputDecoration(
                      labelText: 'Seu idioma',
                      prefixIcon: Icon(Icons.translate),
                    ),
                    items: AppConfig.languages.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _lang = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: const Text('Salvar perfil'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.meeting_room_outlined),
              title: const Text('Código da sala'),
              subtitle: Text(
                '${state.roomCode} — mande este código para a sua amiga '
                'para ela entrar',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copiar código',
                onPressed: () {
                  // Clipboard do Flutter.
                  // ignore: unawaited_futures
                  Clipboard.setData(ClipboardData(text: state.roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Código ${state.roomCode} copiado!'),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: scheme.errorContainer.withOpacity(0.35),
            child: ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text(
                'Sair da sala',
                style: TextStyle(color: scheme.error),
              ),
              onTap: _leaveRoom,
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Como funciona a tradução',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Cada mensagem chega para a outra pessoa com as duas '
                    'versões: a original e a traduzida para o idioma dela. '
                    'A tradução usa serviços gratuitos (Google Translate e '
                    'MyMemory) direto do aparelho — não precisa de chave '
                    'nem paga nada. Se a tradução falhar uma hora, é só '
                    'tocar em "tentar de novo" na própria bolha.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
