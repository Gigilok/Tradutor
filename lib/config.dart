/// Configuração do app — já vem PRONTA, não precisa colar nada.
///
/// A conversa usa um servidor público e gratuito da EMQX
/// (broker.emqx.io) pelo protocolo MQTT. Não precisa de conta,
/// não precisa de chave, não paga nada. O app conecta sozinho.
class AppConfig {
  /// Endereço do servidor público (MQTT, sem cadastro).
  static const String mqttHost = 'broker.emqx.io';

  /// Porta principal (TCP puro).
  static const int mqttPort = 1883;

  /// Porta reserva com criptografia (TLS), usada se a principal falhar
  /// (algumas redes de celular e Wi-Fi bloqueiam a 1883).
  static const int mqttPortTls = 8883;

  /// Última reserva: WebSocket seguro (WSS), que passa por quase qualquer
  /// rede porque usa a mesma porta dos sites com HTTPS. O pacote MQTT
  /// exige a URL completa (com o caminho /mqtt) nesse modo.
  static const int mqttPortWebsocket = 8084;
  static const String mqttUrlWebsocket = 'wss://broker.emqx.io/mqtt';

  /// Prefixo dos "tópicos" (canais) da conversa.
  static const String topicBase = 'ponte';

  /// Nome exibido do app.
  static const String appName = 'Ponte';

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
}
