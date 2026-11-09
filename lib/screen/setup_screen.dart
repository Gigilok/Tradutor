import 'package:flutter/material.dart';

/// Mostrada quando o Supabase ainda não foi configurado.
/// Explica o passo a passo em português para destravar o app.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = <(String, String)>[
      (
        '1. Crie o banco gratuito',
        'Acesse supabase.com, crie uma conta e um novo projeto '
            '(escolha a região São Paulo para ficar rápido no Brasil).',
      ),
      (
        '2. Rode o script pronto',
        'No menu lateral, abra "SQL Editor", clique em "New query", '
            'cole todo o conteúdo do arquivo supabase/setup.sql '
            '(que está junto deste projeto) e clique em RUN.',
      ),
      (
        '3. Copie as chaves',
        'Em "Project Settings" > "API", copie a "Project URL" e a '
            '"anon public" key.',
      ),
      (
        '4. Cole no arquivo lib/config.dart',
        'Substitua COLE_AQUI_A_URL_DO_SUPABASE e COLE_AQUI_A_CHAVE_ANON '
            'pelas chaves copiadas, salve e gere o app novamente pelo '
            'GitHub Actions.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Configuração inicial')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade400,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'O app precisa de um banco de dados gratuito para '
                        'sincronizar a conversa entre os dois celulares. '
                        'São 5 minutos de configuração, uma vez só.',
                        style: TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...steps.map(
              (step) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      step.$1.split('.')[0],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    step.$1,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(step.$2, style: const TextStyle(height: 1.4)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Detalhes completos (com capturas de onde clicar) estão no '
                  'arquivo README.md do projeto, seção "Passo 1 — Criar o '
                  'banco no Supabase".',
                  style: TextStyle(height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
