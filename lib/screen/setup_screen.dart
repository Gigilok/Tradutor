import 'package:flutter/material.dart';

/// Este app NÃO precisa mais de tela de configuração:
/// o servidor (broker.emqx.io) já vem embutido e pronto.
///
/// O arquivo ficou aqui só para não quebrar builds antigos —
/// ele não é mais usado por nenhuma tela e pode ser apagado.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Tudo já está configurado!')),
    );
  }
}
