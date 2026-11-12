import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../services/app_state.dart';
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
      appBar: AppBar(title: Text(AppStrings.t(context, 'settings.title'))),
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
                    decoration: InputDecoration(
                      labelText: AppStrings.t(context, 'settings.name_label'),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _lang,
                    decoration: InputDecoration(
                      labelText: AppStrings.t(context, 'settings.lang_label'),
                      prefixIcon: const Icon(Icons.translate),
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
                      label: Text(AppStrings.t(context, 'settings.save_profile')),
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
              title: Text(AppStrings.t(context, 'settings.room_code')),
              subtitle: Text(
                AppStrings.t(context, 'settings.room_code_subtitle')
                    .format({'code': state.roomCode}),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: AppStrings.t(context, 'settings.copy_code'),
                onPressed: () {
                  // Clipboard do Flutter.
                  // ignore: avoid_print
                  Clipboard.setData(ClipboardData(text: state.roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.t(context, 'settings.code_copied')
                          .format({'code': state.roomCode})),
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
                AppStrings.t(context, 'settings.leave_room'),
                style: TextStyle(color: scheme.error),
              ),
              onTap: _leaveRoom,
            ),
          ),
          const SizedBox(height: 14),
          // >>> CORREÇÃO #11: botão para limpar explicitamente o histórico
          // local desta sala. Antes não existia — só dar sair da sala NÃO
          // limpa mais (permite voltar e ver as mensagens antigas).
          Card(
            color: scheme.errorContainer.withOpacity(0.20),
            child: ListTile(
              leading: Icon(Icons.delete_sweep_outlined, color: scheme.error),
              title: Text(
                AppStrings.t(context, 'settings.clear_history'),
                style: TextStyle(color: scheme.error),
              ),
              onTap: _clearHistory,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.t(context, 'settings.how_translation_works'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.t(context, 'settings.translation_body'),
                    style: const TextStyle(
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
