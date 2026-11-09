# Ponte — conversa traduzida, fotos e filmes com legendas

App de celular (Android e iOS) para duas pessoas que falam idiomas
diferentes conversarem sem barreiras:

- **Chat em tempo real** — cada mensagem chega mostrando as **duas versões**:
  a original e a traduzida para o idioma de quem lê (Google Translate
  gratuito, embutido, com 2 reservas automáticas em caso de falha).
- **Fotos** — envie da galeria ou da câmera, com legenda opcional (traduzida também).
- **Filmes com legendas** — adicione um filme por **link** (.mp4/.m3u8) ou
  **arquivo do próprio aparelho**, carregue a legenda `.srt`/`.vtt` e
  **traduza todas as falas** para o seu idioma com um toque.
- **Assistir junto** — com filme por link, o que uma faz no vídeo
  (play, pausa, avançar) acompanha na tela da outra, na mesma cena.
- **19 idiomas** prontos, sem chave de API, sem pagar nada.

O app funciona em qualquer par de idiomas — por exemplo, você fala
português e sua amiga fala inglês, espanhol, chinês... cada uma escolhe
o seu idioma ao entrar.

---

## Como o projeto funciona

```
celular de vocês  ──►  Supabase (grátis)  ──►  celular da outra pessoa
        │                    │
        └── tradução (Google gratuito) direto do aparelho
```

- **Supabase** é o banco gratuito que guarda as salas, mensagens, fotos
  (Storage) e sincroniza tudo em tempo real. Você cria uma vez e esquece.
- **Tradução** é feita direto do celular, em serviços públicos gratuitos,
  com cache para não repetir pedidos.
- **Compilação** é feita pelo **GitHub Actions**: você sobe o código para o
  GitHub e o GitHub devolve o APK (Android) e o .ipa (iOS) prontos, sem
  você precisar instalar nada no computador.

---

## Passo 1 — Criar o banco no Supabase (5 minutos, uma vez só)

1. Acesse **https://supabase.com** e clique em **Start your project**
   (pode entrar com conta do Google).
2. Clique em **New project**:
   - **Name**: `ponte` (ou o nome que quiser)
   - **Database Password**: escolha uma senha e guarde (não será usada no app)
   - **Region**: escolha **São Paulo (South America / sa-east-1)** para ficar rápido
   - Clique em **Create new project** e espere ~2 minutos.
3. No menu lateral esquerdo, clique no ícone **SQL Editor** (parece um
   terminal) e depois em **New query**.
4. Abra o arquivo **`supabase/setup.sql`** deste projeto, copie TODO o
   conteúdo, cole no editor e clique em **RUN** (canto inferior direito).
   Deve aparecer "Success. No rows returned".
5. Pegue as chaves: menu **Project Settings** (engrenagem) → **API**:
   - **Project URL** — algo como `https://abcd1234.supabase.co`
   - **Project API Keys → anon / public** — uma chave longa `eyJ...`

> Se o projeto aparecer como "pausado" depois de algumas semanas sem uso,
> entre no painel do Supabase e clique em **Restore** — os dados ficam salvos.

## Passo 2 — Colar as chaves no app

Abra **`lib/config.dart`** e substitua as duas linhas:

```dart
static const String supabaseUrl = 'https://abcd1234.supabase.co';   // sua URL
static const String supabaseAnonKey = 'eyJhbGciOi...';              // sua anon key
```

## Passo 3 — Subir o código para o GitHub

1. Crie uma conta no **github.com** (se ainda não tiver).
2. Clique no **+** no topo → **New repository** → nome `ponte-app`,
   marque **Private** (recomendado) → **Create repository**.
3. Envie o código (no computador, dentro da pasta do projeto):

```bash
git init
git add .
git commit -m "App Ponte"
git branch -M main
git remote add origin https://github.com/SEU-USUARIO/ponte-app.git
git push -u origin main
```

## Passo 4 — Gerar o app Android (APK) pelo GitHub Actions

1. No site do GitHub, abra seu repositório → aba **Actions**.
2. Se aparecer um aviso "Workflows aren't being run on this repository",
   clique em **I understand my workflows, go ahead and enable them**.
3. A cada push na `main` o workflow **Build Android (APK)** roda sozinho.
   Você também pode rodar manualmente: **Actions → Build Android (APK) →
   Run workflow → Run workflow**.
4. Em ~8 minutos, entre na execução, desça até **Artifacts** e baixe
   **`ponte-android`** (zip com o `app-release.apk`).
5. No celular: abra o APK (aceite "instalar app desconhecido") e instale.

> Importante: só depois do **Passo 2** as chaves estarão no app. Se você
> gerou o APK antes, gere de novo após colar as chaves.

## Passo 5 — Gerar o app iOS (iPhone)

O workflow **Build iOS** cria um `.ipa` **sem assinatura** (não precisa de
conta de desenvolvedor Apple de US$ 99/ano):

1. No GitHub, aba **Actions → Build iOS (ipa não assinado) → Run workflow**.
   Ele é manual de propósito: os runners da Apple gastam 10x os minutos do
   plano gratuito do GitHub — rode só quando precisar.
2. Baixe o artifact **`ponte-ios`** (zip com `ponte-ios.ipa`).
3. Para instalar no iPhone com Apple ID gratuito:
   - **Sideloadly** (Windows/Mac): conecte o iPhone, abra o .ipa, entre com
     seu Apple ID e clique em Start; ou
   - **AltStore/AltServer**: instale o AltServer, envie o .ipa pelo AltStore.
   - O app vale por **7 dias**; reconecte no computador para renovar
     (AltStore renova sozinho com o celular na mesma rede).
4. No iPhone, confie no app: **Ajustes → Geral → VPN e Gerenciamento de
   Dispositivos → confie no seu Apple ID**.

Alternativa sem GitHub: instale o **Flutter** no computador e rode
`flutter run --release` com o iPhone plugado (também precisa do Xcode no Mac).

---

## Como usar o app

1. **Primeira abertura**: digite seu nome, escolha o idioma que você fala
   e toque em **Criar nova sala**. Anote o código de 4 letras (ex.: `K7QP`).
2. **Sua amiga** instala o app, digita o nome dela, escolhe o idioma dela
   e entra com o **mesmo código** (Entrar na sala). Você também encontra o
   código copiável em **Ajustes → Código da sala**.
3. **Conversa**: escreva no seu idioma — ela recebe sua mensagem com a
   versão dela traduzida embaixo (e vice-versa). Fotos entram pelo botão
   **+** ao lado do campo de texto (galeria ou câmera).
4. **Filmes** (aba Filmes → botão **+**):
   - **Por link**: endereço direto de vídeo `.mp4` ou `.m3u8` (ex.: um link
     de vídeo que vocês hospedem ou tenham direito de usar). Assim as duas
     conseguem **assistir juntas**.
   - **Arquivo do aparelho**: vídeo que está só no seu celular (só você
     assiste; o arquivo fica copiado dentro do app).
5. **Legendas**: dentro do player, toque no ícone de legendas para carregar
   um arquivo `.srt`/`.vtt` do aparelho ou um link. Depois toque no ícone de
   tradução, diga em que idioma a legenda está e aguarde a barra de
   progresso — todas as falas são traduzidas para o seu idioma.
6. **Assistir junto**: no player, quem toca no selo **"Você controla"**
   comanda o vídeo; a outra pessoa acompanha a mesma cena (dá para
   assumir o controle a qualquer momento).

---

## Atualizando o app depois

A cada `git push` o GitHub gera um APK novo. Para **atualizar por cima**
sem desinstalar, o Android exige que a assinatura seja a mesma:

- **Jeito simples**: no primeiro build, baixe também o artifact
  **`keystore-para-atualizacoes`**. No GitHub, vá em **Settings → Secrets
  and variables → Actions → New repository secret**, nome
  `ANDROID_KEYSTORE_B64`, e cole o conteúdo do arquivo em base64:

  ```bash
  base64 -w 0 ponte-key.jks        # Linux/Mac
  certutil -encode ponte-key.jks saida.txt   # Windows (copie o bloco entre BEGIN/END)
  ```

  A partir daí todos os builds usam a mesma assinatura e o app atualiza
  direto por cima.
- **Sem secrets**: cada build gera uma assinatura nova — você desinstala o
  app antigo e instala o novo (nada se perde: conversa e fotos estão no
  Supabase; você só redigita nome/idioma/sala).

## Problemas comuns

| Sintoma | Solução |
| --- | --- |
| "Sala não encontrada" | Confira o código de 4 letras (maiúsculas, sem espaço). |
| Mensagens não chegam em tempo real | Feche e abra o app; confira se o SQL do Passo 1 rodou inteiro. |
| "tradução falhou — tentar de novo" | Toque na própria bolha para tentar de novo; o app já troca de serviço sozinho. |
| Filme não abre | O link precisa ser de vídeo direto (`.mp4`, `.m3u8`), não página do YouTube. |
| Legenda não aparece | Confira se é `.srt`/`.vtt` e se o tempo do vídeo bate. |
| Foto não envia | Confira se o SQL criou o bucket `fotos` (rodar o setup.sql de novo não quebra nada). |
| Supabase "pausado" | Entre no painel e clique em Restore. |

## Segurança e privacidade

- Conversem no app **de vocês**: quem souber o código da sala entra. Para
  trocar de sala, use **Ajustes → Sair da sala** e crie outra.
- Mantenha o repositório do GitHub **privado** (as chaves do Supabase
  ficam no código — a anon key é protegida pelas regras do banco, mas é
  boa prática não expor).
- Nada é enviado para outro servidor além do seu Supabase e do serviço de
  tradução.

## Estrutura do projeto

```
ponte_app/
├── lib/
│   ├── main.dart                  # entrada, tema e rotas iniciais
│   ├── config.dart                # SUAS CHAVES DO SUPABASE ficam aqui
│   ├── models.dart                # Message, Movie, PlaybackState...
│   ├── services/
│   │   ├── app_state.dart         # perfil salvo no aparelho + salas
│   │   ├── chat_service.dart      # mensagens em tempo real + upload de fotos
│   │   ├── movie_service.dart     # filmes + sincronização "assistir junto"
│   │   ├── translation.dart       # tradução gratuita com 3 provedores
│   │   └── subtitles.dart         # leitura/tradução de .srt e .vtt
│   ├── screens/
│   │   ├── join_screen.dart       # nome, idioma, criar/entrar em sala
│   │   ├── setup_screen.dart      # instruções quando falta configurar
│   │   ├── home_screen.dart       # abas: Conversa / Filmes / Ajustes
│   │   ├── chat_screen.dart       # conversa com bolhas bilíngues
│   │   ├── movies_screen.dart     # lista e cadastro de filmes
│   │   ├── player_screen.dart     # player + legendas + assistir junto
│   │   ├── photo_view_screen.dart # foto em tela cheia com zoom
│   │   └── settings_screen.dart   # perfil, idioma, código da sala
│   └── widgets/message_bubble.dart# bolha com original + tradução
├── supabase/setup.sql             # script do banco (Passo 1)
├── .github/workflows/
│   ├── android.yml                # gera o APK automaticamente
│   └── ios.yml                    # gera o .ipa (manual)
└── pubspec.yaml                   # dependências
```

Feito para compilar com o Flutter estável pelo GitHub Actions — você não
precisa instalar Flutter, Android Studio nem Xcode em lugar nenhum.
