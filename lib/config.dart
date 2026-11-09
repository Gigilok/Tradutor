/// Configuração do app — É AQUI que você cola as credenciais do Supabase.
///
/// Siga o passo a passo do README.md (seção "Passo 1 — Criar o banco no Supabase")
/// e cole abaixo a URL e a chave anônima (anon key) do seu projeto.
class AppConfig {
  /// Exemplo: 'https://abcdefgh.supabase.co'
  static const String supabaseUrl = 'COLE_AQUI_A_URL_DO_SUPABASE';

  /// Exemplo: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
  /// (Settings > API > Project API keys > anon / public)
  static const String supabaseAnonKey = 'COLE_AQUI_A_CHAVE_ANON';

  /// Nome exibido do app.
  static const String appName = 'Ponte';

  /// Retorna true quando as credenciais já foram preenchidas.
  static bool get isConfigured =>
      !supabaseUrl.contains('COLE_AQUI') &&
      !supabaseAnonKey.contains('COLE_AQUI');

  /// Idiomas disponíveis no app (código -> nome exibido).
  static const Map<String, String> languages = {
    'pt': 'Português',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'ru': 'Русский',
    'uk': 'Українська',
    'tr': 'Türkçe',
    'ar': 'العربية',
    'hi': 'हिन्दी',
    'th': 'ไทย',
    'vi': 'Tiếng Việt',
    'id': 'Bahasa Indonesia',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
  };

  /// Nome do idioma a partir do código.
  static String languageName(String code) => languages[code] ?? code;

  /// Bucket de fotos no Supabase Storage (criado pelo script supabase/setup.sql).
  static const String photoBucket = 'fotos';
}
