// strings.dart — Sistema de tradução da interface do app Ponte.
//
// Como o app já suporta 18 idiomas para a conversa (config.dart),
// aproveitamos o mesmo mapa para traduzir a interface. As chaves
// são strings curtas em inglês (padrão i18n) e cada idioma tem
// sua tradução.
//
// Uso:
//   AppStrings.t(context, 'home.chat_tab')    // → "Conversa" / "Chat" / "Charla" / etc.
//   AppStrings.of(context).tr('home.chat_tab')
//
// O idioma é lido do AppState (que já reage a mudanças via
// ChangeNotifier), então quando o usuário troca o idioma nas
// Ajustes, a interface atualiza sozinha.

import 'package:flutter/material.dart';
import '../config.dart';

/// Gerencia as traduções da interface.
class AppStrings {
  AppStrings._(this.locale);

  final String locale;

  static AppStrings of(BuildContext context) {
    // Lê o idioma do AppState via Provider (disponibilizado no main.dart).
    // Fallback para 'pt' se não encontrar.
    final lang = _readLang(context);
    return AppStrings._(lang);
  }

  /// Atalho: AppStrings.t(context, 'chave')
  static String t(BuildContext context, String key) {
    return AppStrings.of(context).tr(key);
  }

  /// Traduz uma chave para o idioma atual.
  /// Se não existir tradução, retorna a chave original (para debug).
  String tr(String key) {
    final table = _translations[locale] ?? _translations['pt']!;
    return table[key] ?? _translations['pt']![key] ?? key;
  }

  static String _readLang(BuildContext context) {
    // Tenta ler do AppState via inherited widget lookup.
    // Evita dependência circular importando provider aqui.
    try {
      final widget = context.dependOnInheritedWidgetForExactType<_LangInherited>();
      return widget?.lang ?? 'pt';
    } catch (_) {
      return 'pt';
    }
  }
}

/// InheritedWidget que disponibiliza o idioma atual para a árvore
/// de widgets. Atualizado pelo AppState quando o usuário troca.
class _LangInherited extends InheritedWidget {
  const _LangInherited({required this.lang, required super.child});
  final String lang;

  @override
  bool updateShouldNotify(_LangInherited oldWidget) => lang != oldWidget.lang;
}

/// Wrapper que envolve o app para disponibilizar o idioma.
/// Coloque no main.dart: LangProvider(lang: state.lang, child: PonteApp())
class LangProvider extends StatelessWidget {
  const LangProvider({
    super.key,
    required this.lang,
    required this.child,
  });

  final String lang;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _LangInherited(lang: lang, child: child);
  }
}

/// Mapa de traduções para os idiomas suportados.
/// Chaves em snake_case para evitar typos.
///
/// Cobertura: apenas os idiomas mais prováveis de serem usados
/// têm tradução completa. Para os demais, cai em 'pt' (fallback)
/// — o usuário ainda consegue usar o app, só que em português.
final Map<String, Map<String, String>> _translations = {
  // ─── Português (default) ────────────────────────────────────────
  'pt': {
    // JoinScreen
    'join.app_name': 'Ponte',
    'join.subtitle': 'Tudo pronto! Só falta você escolher o seu nome e idioma.\nDepois combine com a sua amiga um código e as duas entram com o mesmo código para conversar.',
    'join.name_label': 'Seu nome',
    'join.lang_label': 'Você fala qual idioma?',
    'join.create_room': 'Criar sala (gera um código)',
    'join.or_enter': 'ou entre com o código',
    'join.code_hint': 'Código combinado com a amiga',
    'join.enter_room': 'Entrar na sala',
    'join.need_name': 'Digite o seu nome.',
    'join.need_code': 'Digite o código de 4 caracteres combinado com a sua amiga.',
    'join.code_too_short': 'O código da sala tem 4 caracteres (ex.: K7PD).',
    'join.room_ready': 'Sala {code} pronta!',
    'join.server_note': 'O app usa um servidor público gratuito (broker.emqx.io) — não precisa criar conta.',
    'join.name_cap': 'Name',
    // HomeScreen (tabs)
    'home.chat_tab': 'Conversa',
    'home.movies_tab': 'Filmes',
    'home.settings_tab': 'Ajustes',
    // ChatScreen
    'chat.title': 'Conversa',
    'chat.room_subtitle': 'Sala {code} · amiga fala {lang}',
    'chat.empty_title': 'Mande a primeira mensagem!',
    'chat.empty_body': 'Ela chega traduzida para a sua amiga.',
    'chat.input_hint': 'Mensagem em {lang}...',
    'chat.send': 'Enviar',
    'chat.send_photo': 'Enviar foto',
    'chat.photo_from_gallery': 'Escolher da galeria',
    'chat.take_photo': 'Tirar foto agora',
    'chat.caption_optional': 'Legenda (opcional)',
    'chat.cancel': 'Cancelar',
    'chat.send_action': 'Enviar',
    'chat.error_load': 'Erro ao carregar conversa: {error}',
    'chat.error_send': 'Não consegui enviar: {error}',
    'chat.error_send_photo': 'Não consegui enviar a foto: {error}',
    'chat.friend_online': '{name} está online agora',
    'chat.friend_last_seen': '{name} vista por último às {time}',
    'chat.friend_waiting': 'Esperando {name} entrar...',
    'chat.original_label': 'original',
    'chat.translated_label': 'traduzido',
    'chat.translating': 'traduzindo...',
    'chat.translation_failed': 'tradução falhou — tentar de novo',
    'chat.photo_incoming': 'foto chegando...',
    // MoviesScreen
    'movies.title': 'Filmes',
    'movies.empty_title': 'Nenhum filme ainda.',
    'movies.empty_body': 'Toque no + para adicionar um link\nou um vídeo do seu aparelho.',
    'movies.add_url': 'Por link (.mp4/.m3u8)',
    'movies.add_url_subtitle': 'As duas assistem juntas',
    'movies.add_file': 'Arquivo do meu aparelho',
    'movies.add_file_subtitle': 'A amiga escolhe a cópia dela para assistir junto',
    'movies.add_by_url_title': 'Adicionar por link',
    'movies.movie_name': 'Nome do filme',
    'movies.movie_link': 'Link do vídeo',
    'movies.movie_link_hint': 'https://... .mp4 ou .m3u8',
    'movies.link_note': 'Serve link direto de vídeo (.mp4, .m3u8/HLS). Assim as duas conseguem assistir juntas.',
    'movies.add': 'Adicionar',
    'movies.cancel': 'Cancelar',
    'movies.add_local_title': 'Nome do filme',
    'movies.add_local_label': 'Nome',
    'movies.local_subtitle': 'Arquivo local de {by} — a amiga escolhe a cópia dela',
    'movies.link_subtitle': 'Link · adicionado por {by}',
    'movies.remove': 'Remover da lista',
    'movies.error_load': 'Erro ao carregar filmes: {error}',
    'movies.error_add': 'Erro ao adicionar: {error}',
    'movies.error_add_file': 'Erro ao adicionar arquivo: {error}',
    'movies.error_remove': 'Erro ao remover: {error}',
    // PlayerScreen
    'player.you_control': 'Você controla',
    'player.other_controls': '{name} controla — assumir',
    'player.rewind_10': 'Voltar 10s',
    'player.forward_10': 'Avançar 10s',
    'player.play_pause': 'Play/Pause',
    'player.load_subtitle': 'Carregar legenda',
    'player.subtitle_menu': 'Legendas / tradução',
    'player.subtitle_active': 'Legenda ativa · {count} falas',
    'player.next_line': 'Aguardando a próxima fala...',
    'player.load_subtitle_title': 'Carregar legenda',
    'player.load_subtitle_body': 'A legenda pode ser um arquivo .srt ou .vtt do seu aparelho, ou um link direto para o arquivo.',
    'player.subtitle_link': 'Link',
    'player.subtitle_file': 'Arquivo',
    'player.subtitle_url_label': 'URL do .srt/.vtt',
    'player.translate_subtitles': 'Traduzir legendas',
    'player.translate_question': 'As {count} falas serão traduzidas para {lang}. Em qual idioma está a legenda original?',
    'player.translate_to_mine': 'Traduzir legendas para o meu idioma',
    'player.load_other': 'Carregar outra legenda',
    'player.show_subtitles': 'Mostrar legendas',
    'player.hide_subtitles': 'Esconder legendas',
    'player.translating_title': 'Traduzindo legendas...',
    'player.subtitle_loaded': 'Legenda carregada ({count} falas).',
    'player.already_mine': 'A legenda já está no seu idioma.',
    'player.translated_ok': 'Legendas traduzidas!',
    'player.translate_failed': 'Falha ao traduzir legendas: {error}',
    'player.subtitle_error': 'Erro na legenda: {error}',
    'player.no_valid_lines': 'Não encontrei falas válidas nessa legenda.',
    'player.you_control_now': 'Você está controlando o filme agora!',
    'player.local_video_hint': 'Este vídeo é do seu aparelho. Quando a sua amiga abrir o mesmo filme e escolher a cópia dela, as duas assistem juntas: quem estiver com o selo "controla" comanda o play e a pausa das duas.',
    'player.link_video_hint': 'Use um filme por link para vocês assistirem juntas: quem estiver com o selo "controla" comanda o play, a pausa e o avanço para as duas ao mesmo tempo.',
    'player.missing_file': 'Esse vídeo está no aparelho de {by}.',
    'player.missing_file_body': 'Para assistir junto, consiga o arquivo com {by} (pode mandar pelo WhatsApp) e salve no seu celular. Depois toque no botão abaixo e escolha ele.',
    'player.pick_local': 'Escolher o vídeo no meu aparelho',
    'player.open_failed': 'Não consegui abrir o vídeo.',
    'player.open_failed_body': 'Confira o link (precisa terminar em .mp4 ou .m3u8) ou tente novamente.',
    'player.try_again': 'Tentar de novo',
    'player.copy_failed': 'Não consegui copiar o vídeo: {error}',
    // SettingsScreen
    'settings.title': 'Ajustes',
    'settings.name_label': 'Seu nome',
    'settings.lang_label': 'Seu idioma',
    'settings.save_profile': 'Salvar perfil',
    'settings.profile_saved': 'Perfil atualizado!',
    'settings.room_code': 'Código da sala',
    'settings.room_code_subtitle': '{code} — mande este código para a sua amiga para ela entrar',
    'settings.copy_code': 'Copiar código',
    'settings.code_copied': 'Código {code} copiado!',
    'settings.leave_room': 'Sair da sala',
    'settings.leave_confirm_title': 'Sair da sala?',
    'settings.leave_confirm_body': 'Você voltará para a tela de entrada e poderá criar uma nova sala ou entrar com outro código. As mensagens recentes da sala ficam guardadas no servidor público dela.',
    'settings.leave': 'Sair',
    'settings.how_translation_works': 'Como funciona a tradução',
    'settings.translation_body': 'Cada mensagem chega para a outra pessoa com as duas versões: a original e a traduzida para o idioma dela. A tradução usa serviços gratuitos (Google Translate e MyMemory) direto do aparelho — não precisa de chave nem paga nada. Se a tradução falhar uma hora, é só tocar em "tentar de novo" na própria bolha.',
    'settings.clear_history': 'Limpar histórico desta sala',
    'settings.clear_confirm_title': 'Limpar histórico?',
    'settings.clear_confirm_body': 'As mensagens salvas no seu aparelho desta sala serão apagadas. As que ainda estão no servidor continuam acessíveis até expirarem.',
    'settings.clear': 'Limpar',
    'settings.history_cleared': 'Histórico limpo.',
    // PhotoView
    'photo.title': 'Foto',
    // Generic
    'common.loading': 'Carregando...',
    'common.error': 'Erro',
    'common.retry': 'Tentar de novo',
    'common.cancel': 'Cancelar',
  },

  // ─── English ────────────────────────────────────────────────────
  'en': {
    'join.app_name': 'Ponte',
    'join.subtitle': "All set! Just pick your name and language.\nThen agree on a code with your friend and both of you enter with the same code to chat.",
    'join.name_label': 'Your name',
    'join.lang_label': 'Which language do you speak?',
    'join.create_room': 'Create room (generates a code)',
    'join.or_enter': 'or enter with a code',
    'join.code_hint': 'Code agreed with your friend',
    'join.enter_room': 'Enter room',
    'join.need_name': 'Please enter your name.',
    'join.need_code': 'Enter the 4-character code agreed with your friend.',
    'join.code_too_short': 'The room code is 4 characters (e.g. K7PD).',
    'join.room_ready': 'Room {code} ready!',
    'join.server_note': 'The app uses a free public server (broker.emqx.io) — no account needed.',
    'home.chat_tab': 'Chat',
    'home.movies_tab': 'Movies',
    'home.settings_tab': 'Settings',
    'chat.title': 'Chat',
    'chat.room_subtitle': 'Room {code} · friend speaks {lang}',
    'chat.empty_title': 'Send the first message!',
    'chat.empty_body': "It arrives translated to your friend.",
    'chat.input_hint': 'Message in {lang}...',
    'chat.send': 'Send',
    'chat.send_photo': 'Send photo',
    'chat.photo_from_gallery': 'Choose from gallery',
    'chat.take_photo': 'Take a photo now',
    'chat.caption_optional': 'Caption (optional)',
    'chat.cancel': 'Cancel',
    'chat.send_action': 'Send',
    'chat.error_load': 'Error loading chat: {error}',
    'chat.error_send': "Couldn't send: {error}",
    'chat.error_send_photo': "Couldn't send photo: {error}",
    'chat.friend_online': '{name} is online now',
    'chat.friend_last_seen': '{name} last seen at {time}',
    'chat.friend_waiting': 'Waiting for {name} to join...',
    'chat.original_label': 'original',
    'chat.translated_label': 'translated',
    'chat.translating': 'translating...',
    'chat.translation_failed': 'translation failed — try again',
    'chat.photo_incoming': 'photo arriving...',
    'movies.title': 'Movies',
    'movies.empty_title': 'No movies yet.',
    'movies.empty_body': 'Tap + to add a link\nor a video from your device.',
    'movies.add_url': 'By link (.mp4/.m3u8)',
    'movies.add_url_subtitle': 'Both watch together',
    'movies.add_file': "File from my device",
    'movies.add_file_subtitle': 'Your friend picks her copy to watch together',
    'movies.add_by_url_title': 'Add by link',
    'movies.movie_name': 'Movie name',
    'movies.movie_link': 'Video link',
    'movies.movie_link_hint': 'https://... .mp4 or .m3u8',
    'movies.link_note': 'Direct video link works (.mp4, .m3u8/HLS). That way both of you can watch together.',
    'movies.add': 'Add',
    'movies.cancel': 'Cancel',
    'movies.add_local_title': 'Movie name',
    'movies.add_local_label': 'Name',
    'movies.local_subtitle': "Local file from {by} — your friend picks her copy",
    'movies.link_subtitle': 'Link · added by {by}',
    'movies.remove': 'Remove from list',
    'movies.error_load': 'Error loading movies: {error}',
    'movies.error_add': 'Error adding: {error}',
    'movies.error_add_file': 'Error adding file: {error}',
    'movies.error_remove': 'Error removing: {error}',
    'player.you_control': 'You control',
    'player.other_controls': '{name} controls — take over',
    'player.rewind_10': 'Rewind 10s',
    'player.forward_10': 'Forward 10s',
    'player.play_pause': 'Play/Pause',
    'player.load_subtitle': 'Load subtitle',
    'player.subtitle_menu': 'Subtitles / translation',
    'player.subtitle_active': 'Active subtitle · {count} lines',
    'player.next_line': 'Waiting for the next line...',
    'player.load_subtitle_title': 'Load subtitle',
    'player.load_subtitle_body': 'The subtitle can be a .srt or .vtt file from your device, or a direct link to the file.',
    'player.subtitle_link': 'Link',
    'player.subtitle_file': 'File',
    'player.subtitle_url_label': 'URL of .srt/.vtt',
    'player.translate_subtitles': 'Translate subtitles',
    'player.translate_question': 'The {count} lines will be translated to {lang}. What language is the original subtitle in?',
    'player.translate_to_mine': 'Translate subtitles to my language',
    'player.load_other': 'Load another subtitle',
    'player.show_subtitles': 'Show subtitles',
    'player.hide_subtitles': 'Hide subtitles',
    'player.translating_title': 'Translating subtitles...',
    'player.subtitle_loaded': 'Subtitle loaded ({count} lines).',
    'player.already_mine': 'The subtitle is already in your language.',
    'player.translated_ok': 'Subtitles translated!',
    'player.translate_failed': 'Failed to translate subtitles: {error}',
    'player.subtitle_error': 'Subtitle error: {error}',
    'player.no_valid_lines': "Couldn't find valid lines in that subtitle.",
    'player.you_control_now': "You're controlling the movie now!",
    'player.local_video_hint': "This video is on your device. When your friend opens the same movie and picks her copy, both of you watch together: whoever has the 'controls' badge drives play and pause for both.",
    'player.link_video_hint': "Use a link movie so you can watch together: whoever has the 'controls' badge drives play, pause and seek for both at the same time.",
    'player.missing_file': "This video is on {by}'s device.",
    'player.missing_file_body': 'To watch together, get the file from {by} (you can send it via WhatsApp) and save it on your phone. Then tap the button below and pick it.',
    'player.pick_local': 'Pick the video on my device',
    'player.open_failed': "Couldn't open the video.",
    'player.open_failed_body': 'Check the link (must end in .mp4 or .m3u8) or try again.',
    'player.try_again': 'Try again',
    'player.copy_failed': "Couldn't copy the video: {error}",
    'settings.title': 'Settings',
    'settings.name_label': 'Your name',
    'settings.lang_label': 'Your language',
    'settings.save_profile': 'Save profile',
    'settings.profile_saved': 'Profile updated!',
    'settings.room_code': 'Room code',
    'settings.room_code_subtitle': '{code} — send this code to your friend so she can join',
    'settings.copy_code': 'Copy code',
    'settings.code_copied': 'Code {code} copied!',
    'settings.leave_room': 'Leave room',
    'settings.leave_confirm_title': 'Leave room?',
    'settings.leave_confirm_body': "You'll go back to the entry screen and can create a new room or join with another code. The room's recent messages stay saved on its public server.",
    'settings.leave': 'Leave',
    'settings.how_translation_works': 'How translation works',
    'settings.translation_body': "Each message arrives to the other person with both versions: the original and the translated one in their language. Translation uses free services (Google Translate and MyMemory) right from your device — no key needed and costs nothing. If translation fails at some point, just tap 'try again' on the bubble itself.",
    'settings.clear_history': 'Clear this room history',
    'settings.clear_confirm_title': 'Clear history?',
    'settings.clear_confirm_body': 'Messages saved on your device for this room will be deleted. The ones still on the server remain accessible until they expire.',
    'settings.clear': 'Clear',
    'settings.history_cleared': 'History cleared.',
    'photo.title': 'Photo',
    'common.loading': 'Loading...',
    'common.error': 'Error',
    'common.retry': 'Try again',
    'common.cancel': 'Cancel',
  },

  // ─── Español ────────────────────────────────────────────────────
  'es': {
    'join.app_name': 'Ponte',
    'join.subtitle': '¡Todo listo! Solo falta que elijas tu nombre e idioma.\nLuego coordina con tu amiga un código y ambas entran con el mismo código para conversar.',
    'join.name_label': 'Tu nombre',
    'join.lang_label': '¿Qué idioma hablas?',
    'join.create_room': 'Crear sala (genera un código)',
    'join.or_enter': 'o entra con un código',
    'join.code_hint': 'Código acordado con tu amiga',
    'join.enter_room': 'Entrar en la sala',
    'join.need_name': 'Escribe tu nombre.',
    'join.need_code': 'Escribe el código de 4 caracteres acordado con tu amiga.',
    'join.code_too_short': 'El código de la sala tiene 4 caracteres (ej.: K7PD).',
    'join.room_ready': '¡Sala {code} lista!',
    'join.server_note': 'La app usa un servidor público gratuito (broker.emqx.io) — no hace falta crear cuenta.',
    'home.chat_tab': 'Conversa',
    'home.movies_tab': 'Películas',
    'home.settings_tab': 'Ajustes',
    'chat.title': 'Conversa',
    'chat.room_subtitle': 'Sala {code} · amiga habla {lang}',
    'chat.empty_title': '¡Manda el primer mensaje!',
    'chat.empty_body': 'Llega traducido a tu amiga.',
    'chat.input_hint': 'Mensaje en {lang}...',
    'chat.send': 'Enviar',
    'chat.send_photo': 'Enviar foto',
    'chat.photo_from_gallery': 'Elegir de la galería',
    'chat.take_photo': 'Tomar foto ahora',
    'chat.caption_optional': 'Leyenda (opcional)',
    'chat.cancel': 'Cancelar',
    'chat.send_action': 'Enviar',
    'chat.error_load': 'Error al cargar conversa: {error}',
    'chat.error_send': 'No pude enviar: {error}',
    'chat.error_send_photo': 'No pude enviar la foto: {error}',
    'chat.friend_online': '{name} está en línea ahora',
    'chat.friend_last_seen': '{name} vista por última vez a las {time}',
    'chat.friend_waiting': 'Esperando que {name} entre...',
    'chat.original_label': 'original',
    'chat.translated_label': 'traducido',
    'chat.translating': 'traduciendo...',
    'chat.translation_failed': 'traducción falló — intentar de nuevo',
    'chat.photo_incoming': 'foto llegando...',
    'movies.title': 'Películas',
    'movies.empty_title': 'Ninguna película todavía.',
    'movies.empty_body': 'Toca + para añadir un link\no un video de tu dispositivo.',
    'movies.add_url': 'Por link (.mp4/.m3u8)',
    'movies.add_url_subtitle': 'Ambas miran juntas',
    'movies.add_file': 'Archivo de mi dispositivo',
    'movies.add_file_subtitle': 'Tu amiga elige su copia para mirar juntas',
    'movies.add_by_url_title': 'Añadir por link',
    'movies.movie_name': 'Nombre de la película',
    'movies.movie_link': 'Link del video',
    'movies.movie_link_hint': 'https://... .mp4 o .m3u8',
    'movies.link_note': 'Sirve link directo de video (.mp4, .m3u8/HLS). Así ambas consiguen mirar juntas.',
    'movies.add': 'Añadir',
    'movies.cancel': 'Cancelar',
    'movies.add_local_title': 'Nombre de la película',
    'movies.add_local_label': 'Nombre',
    'movies.local_subtitle': 'Archivo local de {by} — tu amiga elige su copia',
    'movies.link_subtitle': 'Link · añadido por {by}',
    'movies.remove': 'Quitar de la lista',
    'movies.error_load': 'Error al cargar películas: {error}',
    'movies.error_add': 'Error al añadir: {error}',
    'movies.error_add_file': 'Error al añadir archivo: {error}',
    'movies.error_remove': 'Error al quitar: {error}',
    'player.you_control': 'Tú controlas',
    'player.other_controls': '{name} controla — asumir',
    'player.rewind_10': 'Retroceder 10s',
    'player.forward_10': 'Avanzar 10s',
    'player.play_pause': 'Play/Pausa',
    'player.load_subtitle': 'Cargar subtítulo',
    'player.subtitle_menu': 'Subtítulos / traducción',
    'player.subtitle_active': 'Subtítulo activo · {count} líneas',
    'player.next_line': 'Esperando la próxima línea...',
    'player.load_subtitle_title': 'Cargar subtítulo',
    'player.load_subtitle_body': 'El subtítulo puede ser un archivo .srt o .vtt de tu dispositivo, o un link directo al archivo.',
    'player.subtitle_link': 'Link',
    'player.subtitle_file': 'Archivo',
    'player.subtitle_url_label': 'URL del .srt/.vtt',
    'player.translate_subtitles': 'Traducir subtítulos',
    'player.translate_question': 'Las {count} líneas serán traducidas a {lang}. ¿En qué idioma está el subtítulo original?',
    'player.translate_to_mine': 'Traducir subtítulos a mi idioma',
    'player.load_other': 'Cargar otro subtítulo',
    'player.show_subtitles': 'Mostrar subtítulos',
    'player.hide_subtitles': 'Esconder subtítulos',
    'player.translating_title': 'Traduciendo subtítulos...',
    'player.subtitle_loaded': 'Subtítulo cargado ({count} líneas).',
    'player.already_mine': 'El subtítulo ya está en tu idioma.',
    'player.translated_ok': '¡Subtítulos traducidos!',
    'player.translate_failed': 'Falló la traducción de subtítulos: {error}',
    'player.subtitle_error': 'Error en subtítulo: {error}',
    'player.no_valid_lines': 'No encontré líneas válidas en ese subtítulo.',
    'player.you_control_now': '¡Estás controlando la película ahora!',
    'player.local_video_hint': 'Este video está en tu dispositivo. Cuando tu amiga abra la misma película y elija su copia, ambas miran juntas: quien tenga el sello "controla" comanda el play y la pausa de ambas.',
    'player.link_video_hint': 'Usa una película por link para que miren juntas: quien tenga el sello "controla" comanda el play, la pausa y el avance para ambas al mismo tiempo.',
    'player.missing_file': 'Este video está en el dispositivo de {by}.',
    'player.missing_file_body': 'Para mirar juntas, consigue el archivo con {by} (puedes mandarlo por WhatsApp) y guárdalo en tu celular. Luego toca el botón de abajo y elógete.',
    'player.pick_local': 'Elegir el video en mi dispositivo',
    'player.open_failed': 'No pude abrir el video.',
    'player.open_failed_body': 'Confirma el link (debe terminar en .mp4 o .m3u8) o intenta de nuevo.',
    'player.try_again': 'Intentar de nuevo',
    'player.copy_failed': 'No pude copiar el video: {error}',
    'settings.title': 'Ajustes',
    'settings.name_label': 'Tu nombre',
    'settings.lang_label': 'Tu idioma',
    'settings.save_profile': 'Guardar perfil',
    'settings.profile_saved': '¡Perfil actualizado!',
    'settings.room_code': 'Código de la sala',
    'settings.room_code_subtitle': '{code} — manda este código a tu amiga para que entre',
    'settings.copy_code': 'Copiar código',
    'settings.code_copied': '¡Código {code} copiado!',
    'settings.leave_room': 'Salir de la sala',
    'settings.leave_confirm_title': '¿Salir de la sala?',
    'settings.leave_confirm_body': 'Volverás a la pantalla de entrada y podrás crear una nueva sala o entrar con otro código. Los mensajes recientes de la sala quedan guardados en su servidor público.',
    'settings.leave': 'Salir',
    'settings.how_translation_works': 'Cómo funciona la traducción',
    'settings.translation_body': 'Cada mensaje llega a la otra persona con las dos versiones: la original y la traducida a su idioma. La traducción usa servicios gratuitos (Google Translate y MyMemory) directo del dispositivo — no hace falta clave ni cuesta nada. Si la traducción falla en algún momento, basta tocar "intentar de nuevo" en la propia burbuja.',
    'settings.clear_history': 'Limpiar historial de esta sala',
    'settings.clear_confirm_title': '¿Limpiar historial?',
    'settings.clear_confirm_body': 'Los mensajes guardados en tu dispositivo de esta sala serán borrados. Los que siguen en el servidor siguen accesibles hasta expirar.',
    'settings.clear': 'Limpiar',
    'settings.history_cleared': 'Historial limpio.',
    'photo.title': 'Foto',
    'common.loading': 'Cargando...',
    'common.error': 'Error',
    'common.retry': 'Intentar de nuevo',
    'common.cancel': 'Cancelar',
  },

  // ─── Français (resumido — cai em 'pt' para chaves faltantes) ───
  'fr': {
    'join.app_name': 'Ponte',
    'join.subtitle': "Tout est prêt ! Il ne vous reste qu'à choisir votre nom et votre langue.\nEnsuite convenez d'un code avec votre amie et entrez toutes les deux avec le même code pour discuter.",
    'join.name_label': 'Votre nom',
    'join.lang_label': 'Quelle langue parlez-vous ?',
    'join.create_room': 'Créer un salon (génère un code)',
    'join.or_enter': 'ou entrez avec un code',
    'join.code_hint': 'Code convenu avec votre amie',
    'join.enter_room': 'Entrer dans le salon',
    'join.need_name': 'Saisissez votre nom.',
    'join.need_code': 'Saisissez le code de 4 caractères convenu avec votre amie.',
    'join.code_too_short': "Le code du salon a 4 caractères (ex. : K7PD).",
    'join.room_ready': 'Salon {code} prêt !',
    'join.server_note': "L'app utilise un serveur public gratuit (broker.emqx.io) — pas besoin de compte.",
    'home.chat_tab': 'Discussion',
    'home.movies_tab': 'Films',
    'home.settings_tab': 'Réglages',
    'chat.title': 'Discussion',
    'chat.empty_title': 'Envoyez le premier message !',
    'chat.empty_body': "Il arrive traduit à votre amie.",
    'chat.input_hint': 'Message en {lang}...',
    'chat.send': 'Envoyer',
    'chat.send_photo': 'Envoyer une photo',
    'chat.photo_from_gallery': 'Choisir dans la galerie',
    'chat.take_photo': "Prendre une photo maintenant",
    'chat.caption_optional': 'Légende (facultatif)',
    'chat.cancel': 'Annuler',
    'chat.send_action': 'Envoyer',
    'chat.friend_online': '{name} est en ligne',
    'chat.friend_last_seen': '{name} vu pour la dernière fois à {time}',
    'chat.friend_waiting': 'En attente de {name}...',
    'chat.original_label': 'original',
    'chat.translated_label': 'traduit',
    'chat.translating': 'traduction...',
    'chat.translation_failed': 'traduction échouée — réessayer',
    'chat.photo_incoming': 'photo en arrivée...',
    'movies.title': 'Films',
    'movies.empty_title': 'Aucun film pour le moment.',
    'movies.empty_body': 'Touchez + pour ajouter un lien\nou une vidéo depuis votre appareil.',
    'movies.add_url': 'Par lien (.mp4/.m3u8)',
    'movies.add_url_subtitle': 'Toutes les deux regardent ensemble',
    'movies.add_file': "Fichier de mon appareil",
    'movies.add_file_subtitle': 'Votre amie choisit sa copie pour regarder ensemble',
    'movies.add': 'Ajouter',
    'movies.cancel': 'Annuler',
    'movies.remove': 'Retirer de la liste',
    'settings.title': 'Réglages',
    'settings.name_label': 'Votre nom',
    'settings.lang_label': 'Votre langue',
    'settings.save_profile': 'Enregistrer le profil',
    'settings.profile_saved': 'Profil mis à jour !',
    'settings.leave_room': 'Quitter le salon',
    'settings.leave': 'Quitter',
    'photo.title': 'Photo',
    'common.loading': 'Chargement...',
    'common.error': 'Erreur',
    'common.retry': 'Réessayer',
    'common.cancel': 'Annuler',
  },
};

/// Helper para formatar strings com placeholders.
/// Exemplo: AppStrings.t(context, 'join.room_ready').format({'code': 'AB12'})
extension StringFormat on String {
  String format(Map<String, String> args) {
    String result = this;
    args.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}
