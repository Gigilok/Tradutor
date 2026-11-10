import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../service/app_state.dart';

/// Primeira tela (só na primeira vez que abre o app):
/// escolhe nome, idioma e o código da sala combinado com a amiga.
/// O servidor já vem configurado dentro do app — não pede conta nem chave.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  String _lang = 'pt';
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool createNew}) async {
    final state = context.read<AppState>();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Digite o seu nome.');
      return;
    }
    if (!createNew && _codeController.text.trim().length < 4) {
      _showError('Digite o código de 4 caracteres combinado com a sua amiga.');
      return;
    }
    setState(() => _busy = true);
    try {
      state.name = name;
      state.lang = _lang;
      if (createNew) {
        await state.createRoom();
      } else {
        await state.joinRoom(_codeController.text);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sala ${state.roomCode} pronta!')),
      );
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.route_rounded, size: 64, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    AppConfig.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tudo pronto! Só falta você escolher o seu nome e idioma.\n'
                    'Depois combine com a sua amiga um código e as duas\n'
                    'entram com o mesmo código para conversar.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Seu nome',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _lang,
                    decoration: const InputDecoration(
                      labelText: 'Você fala qual idioma?',
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
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _submit(createNew: true),
                    icon: const Icon(Icons.add_link),
                    label: const Text('Criar sala (gera um código)'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'ou entre com o código',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: 'K7PD',
                      labelText: 'Código combinado com a amiga',
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _submit(createNew: false),
                    icon: const Icon(Icons.meeting_room_outlined),
                    label: const Text('Entrar na sala'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'O app usa um servidor público gratuito (broker.emqx.io) — '
                    'não precisa criar conta.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
