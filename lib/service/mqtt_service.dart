import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';
import 'photos.dart';

/// Situação de uma pessoa da sala (para o indicador de online).
class PresenceInfo {
  PresenceInfo({
    required this.clientId,
    required this.name,
    required this.lang,
    required this.online,
    required this.lastSeen,
  });

  final String clientId;
  String name;
  String lang;
  bool online;
  DateTime lastSeen;
}

/// Conexão com o servidor público gratuito (broker.emqx.io, protocolo MQTT).
///
/// Não precisa de conta nem de chave: o app conecta sozinho e usa "tópicos"
/// separados por sala para conversa, fotos, presença (online), filmes e
/// sincronização de reprodução.
class PonteNet {
  PonteNet._();

  static final PonteNet instance = PonteNet._();

  MqttServerClient? _client;
  String _room = '';
  String _clientId = '';
  String _name = '';
  String _lang = 'pt';
  bool _connecting = false;

  // Conteúdo da sala, guardado em memória.
  final Map<String, Message> _history = {};
  final Map<String, Movie> _movies = {};
  final Map<String, PresenceInfo> _presence = {};
  final Map<String, Map<String, dynamic>> _photoMeta = {};
  final Map<String, Map<int, String>> _photoChunks = {};
  final Map<String, int> _photoTotal = {};
  final Set<String> _seenChatIds = {};

  // Controle de limpeza do histórico (o servidor público guarda pouco).
  final List<String> _myHistTopics = [];
  final List<String> _myPhotoIds = [];

  Timer? _heartbeat;
  Completer<void>? _connected;
  DateTime? _histDeadline;
  DateTime? _moviesDeadline;

  // callbacks usados pelas telas (via ChatService / MovieService)
  void Function(Message message)? onMessage;
  void Function()? onPresenceChanged;
  void Function()? onPhotosChanged;
  void Function()? onMoviesChanged;
  void Function(PlaybackState state)? onPlayback;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  /// As outras pessoas da sala (sem você mesmo).
  List<PresenceInfo> get others => _presence.values
      .where((p) => p.clientId != _clientId)
      .toList(growable: false);

  /// Dados de presença da outra pessoa (para "está online"/"visto por último").
  PresenceInfo? friendPresence(String myName) {
    for (final p in others) {
      if (p.name.toLowerCase() != myName.toLowerCase()) return p;
    }
    return null;
  }

  String? otherLanguage(String myName) => friendPresence(myName)?.lang;

  // -------------------------------------------------------------------------
  // Conexão
  // -------------------------------------------------------------------------

  /// Conecta na sala. Já é chamado pelo AppState ao entrar.
  Future<void> connect({
    required String roomCode,
    required String name,
    required String lang,
  }) async {
    if (_connecting) return;
    if (isConnected && _room == roomCode) {
      _name = name;
      _lang = lang;
      _publishStatus(online: true);
      return;
    }
    _name = name;
    _lang = lang;
    _clientId = await _loadClientId();
    await _teardown();
    _room = roomCode;
    _connecting = true;
    _connected = Completer<void>();
    try {
      await _startClient(useWebsocket: false);
    } catch (_) {
      // A rede pode estar bloqueando a porta padrão: tenta a reserva (wss).
      await _teardown();
      _connected = Completer<void>();
      try {
        await _startClient(useWebsocket: true);
      } catch (error) {
        _connecting = false;
        throw Exception(
          'Não consegui falar com o servidor ($error). Verifique a internet.',
        );
      }
    }
    _connecting = false;
  }

  Future<void> _startClient({required bool useWebsocket}) async {
    final port = useWebsocket
        ? AppConfig.mqttPortWebsocket
        : AppConfig.mqttPort;
    final client = MqttServerClient.withPort(
      AppConfig.mqttHost,
      _clientId,
      port,
    );
    _client = client;
    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.connectTimeoutPeriod = 8000;
    client.onConnected = _onConnected;

    // "Testamento": se o app cair sem se despedir, o servidor avisa
    // sozinho que a pessoa ficou offline.
    final will = jsonEncode({
      'name': _name,
      'lang': _lang,
      'online': false,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .withWillTopic(_statusTopic)
        .withWillMessage(will)
        .withWillRetain()
        .withWillQos(MqttQos.atLeastOnce)
        .startClean();

    client.updates!.listen(_onArrived);
    await client.connect().timeout(const Duration(seconds: 25));
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      throw Exception('o servidor não respondeu');
    }
  }

  Future<void> _teardown() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _connected = null;
    final client = _client;
    _client = null;
    if (client == null) return;
    try {
      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        client.disconnect();
      }
    } catch (_) {
      // silencioso
    }
  }

  /// Desconecta de verdade (ao sair da sala) avisando que ficou offline.
  Future<void> disconnect() async {
    try {
      if (isConnected) {
        _publishStatus(online: false);
        await Future.delayed(const Duration(milliseconds: 250));
        _client?.disconnect();
      }
    } catch (_) {
      // silencioso
    }
    await _teardown();
    _room = '';
    _history.clear();
    _movies.clear();
    _presence.clear();
    _photoMeta.clear();
    _photoChunks.clear();
    _photoTotal.clear();
    _seenChatIds.clear();
    _myHistTopics.clear();
    _myPhotoIds.clear();
    _histDeadline = null;
    _moviesDeadline = null;
  }

  void _onConnected() {
    final client = _client;
    if (client == null) return;
    client.subscribe(_topic('msg'), MqttQos.atLeastOnce);
    client.subscribe('${_topic('hist')}/#', MqttQos.atLeastOnce);
    client.subscribe('${_topic('foto')}/#', MqttQos.atLeastOnce);
    client.subscribe('${_topic('status')}/+', MqttQos.atLeastOnce);
    client.subscribe('${_topic('movie')}/#', MqttQos.atLeastOnce);
    client.subscribe(_topic('play'), MqttQos.atLeastOnce);

    _publishStatus(online: true);
    final done = _connected;
    if (done != null && !done.isCompleted) done.complete();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _publishStatus(online: true),
    );
  }

  // -------------------------------------------------------------------------
  // Receber tudo que chega do servidor
  // -------------------------------------------------------------------------

  void _onArrived(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final rec in messages) {
      final topic = rec.topic;
      final raw = MqttPublishPayload.bytesToStringAsString(
        (rec.payload as MqttPublishMessage).payload.message,
      );
      try {
        if (raw.isEmpty) {
          _onCleared(topic);
          continue;
        }
        // Pedacos de foto vêm crus (base64), sem JSON.
        if (topic.startsWith('${_topic('foto')}/')) {
          _onPhotoChunk(topic, raw);
          continue;
        }
        final json = jsonDecode(raw);
        if (json is! Map<String, dynamic>) continue;
        if (topic == _topic('msg') || topic.startsWith('${_topic('hist')}/')) {
          _onChatJson(json);
        } else if (topic.startsWith('${_topic('status')}/')) {
          _onStatusJson(topic, json);
        } else if (topic.startsWith('${_topic('movie')}/')) {
          _onMovieJson(json);
        } else if (topic == _topic('play')) {
          onPlayback?.call(PlaybackState.fromMap(json));
        }
      } catch (_) {
        // mensagem estranha: ignora
      }
    }
  }

  /// Um tópico com valor apagado (limpeza de histórico).
  void _onCleared(String topic) {
    // nada a fazer: só sinaliza que aquele histórico antigo acabou
  }

  void _onChatJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || _seenChatIds.contains(id)) return;
    _seenChatIds.add(id);
    final message = Message.fromMqtt(json, room: _room);
    _history[id] = message;
    final cb = onMessage;
    if (cb != null) cb(message);
  }

  void _onStatusJson(String topic, Map<String, dynamic> json) {
    // O id do aparelho vem no tópico: ponte/<sala>/status/<clientId>
    final parts = topic.split('/');
    if (parts.length < 4) return;
    final clientId = parts.sublist(3).join('/');
    if (clientId == _clientId) return;
    final online = (json['online'] ?? false) as bool;
    final ts = json['ts'];
    final lastSeen = ts is num
        ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
        : DateTime.now();
    final current = _presence[clientId];
    if (current == null) {
      _presence[clientId] = PresenceInfo(
        clientId: clientId,
        name: (json['name'] ?? 'Amiga') as String,
        lang: (json['lang'] ?? 'pt') as String,
        online: online,
        lastSeen: lastSeen,
      );
    } else {
      current
        ..name = (json['name'] ?? current.name) as String
        ..lang = (json['lang'] ?? current.lang) as String
        ..online = online
        ..lastSeen = lastSeen;
    }
    onPresenceChanged?.call();
  }

  void _onMovieJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return;
    _movies[id] = Movie.fromMqtt(json);
    onMoviesChanged?.call();
  }

  void _onPhotoChunk(String topic, String raw) {
    final parts = topic.split('/');
    // foto/<id> -> meta (JSON) | foto/<id>/c<numero> -> pedaço cru
    if (parts.length == 2) {
      // Meta da foto: diz quantos pedaços existem.
      final meta = jsonDecode(raw);
      if (meta is! Map<String, dynamic>) return;
      final photoId = meta['id'] as String?;
      final total = meta['n'];
      if (photoId == null || total is! num) return;
      _photoMeta[photoId] = meta;
      _photoTotal[photoId] = total.toInt();
      _tryAssemblePhoto(photoId);
      return;
    }
    if (parts.length != 3) return;
    final photoId = parts[1];
    final indexTag = parts[2];
    if (!indexTag.startsWith('c')) return;
    final index = int.tryParse(indexTag.substring(1));
    if (index == null) return;
    final chunks = _photoChunks.putIfAbsent(photoId, () => {});
    if (chunks.containsKey(index)) return;
    chunks[index] = raw;
    _tryAssemblePhoto(photoId);
  }

  Future<void> _tryAssemblePhoto(String photoId) async {
    final total = _photoTotal[photoId];
    final chunks = _photoChunks[photoId];
    if (total == null || chunks == null) return;
    if (chunks.length < total) return;
    if (PhotoStore.exists(photoId)) {
      onPhotosChanged?.call();
      return;
    }
    if (chunks.keys.any((i) => i < 0 || i >= total)) return;
    final buffer = StringBuffer();
    for (var i = 0; i < total; i++) {
      buffer.write(chunks[i]);
    }
    try {
      final bytes = base64Decode(buffer.toString());
      await PhotoStore.save(photoId, bytes);
    } catch (_) {
      return;
    }
    chunks.clear();
    _photoChunks.remove(photoId);
    _photoMeta.remove(photoId);
    _photoTotal.remove(photoId);
    onPhotosChanged?.call();
  }

  // -------------------------------------------------------------------------
  // Enviar
  // -------------------------------------------------------------------------

  void _publish(
    String topic,
    Map<String, dynamic> json, {
    bool retain = false,
  }) {
    final client = _client;
    if (client == null || !isConnected) {
      throw Exception('sem conexão com o servidor');
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(json));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!,
        retain: retain);
  }

  void _publishRaw(String topic, String payload, {bool retain = false}) {
    final client = _client;
    if (client == null || !isConnected) {
      throw Exception('sem conexão com o servidor');
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!,
        retain: retain);
  }

  void _clearRetained(String topic) {
    try {
      _publishRaw(topic, '', retain: true);
    } catch (_) {
      // sem conexão agora: a limpeza pode ficar para depois
    }
  }

  void _publishStatus({required bool online}) {
    try {
      _publish(
        _statusTopic,
        {
          'name': _name,
          'lang': _lang,
          'online': online,
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
        retain: true,
      );
    } catch (_) {
      // silencioso: o heartbeat tenta de novo
    }
  }

  /// Atualiza nome/idioma publicados (usado nos Ajustes).
  void updateProfile({required String name, required String lang}) {
    _name = name;
    _lang = lang;
    _publishStatus(online: true);
  }

  Future<void> sendChat({
    required String senderName,
    required String senderLang,
    required String kind,
    required String text,
    String? photoId,
  }) async {
    final id = _newId(kind == 'system' ? 's' : 'm');
    final json = <String, dynamic>{
      'id': id,
      'room': _room,
      'name': senderName,
      'lang': senderLang,
      'kind': kind,
      'text': text,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    if (photoId != null) json['photoId'] = photoId;
    _publish(_topic('msg'), json);
    _retainHist(id, json);
  }

  /// Envia uma foto em pedaços (o servidor público tem limite por mensagem).
  Future<void> sendPhotoBytes({
    required String senderName,
    required String senderLang,
    required List<int> bytes,
    String? caption,
  }) async {
    if (bytes.isEmpty) return;
    final photoId = _newId('p');
    final b64 = base64Encode(bytes);
    const chunkSize = 120000;
    final total = (b64.length / chunkSize).ceil();

    _publish(_topic('foto/$photoId'), {
      'id': photoId,
      'n': total,
      'name': senderName,
      'lang': senderLang,
      'text': caption ?? '',
      'ts': DateTime.now().millisecondsSinceEpoch,
    }, retain: true);
    for (var i = 0; i < total; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize) < b64.length
          ? (start + chunkSize)
          : b64.length;
      _publishRaw(
        _topic('foto/$photoId/c$i'),
        b64.substring(start, end),
        retain: true,
      );
    }

    await sendChat(
      senderName: senderName,
      senderLang: senderLang,
      kind: 'image',
      text: caption ?? '',
      photoId: photoId,
    );

    // Guarda a minha própria cópia para mostrar na hora.
    await PhotoStore.save(photoId, bytes);
    _myPhotoIds.add(photoId);
    _cleanupOldPhotos();
  }

  void _retainHist(String id, Map<String, dynamic> json) {
    final topic = _topic('hist/$id');
    _publish(topic, json, retain: true);
    _myHistTopics.add(topic);
    _cleanupOldHistory();
  }

  /// Mantém só as mensagens recentes no servidor (limpa as antigas que eu
  /// mesmo publiquei, para não pesar no servidor público).
  void _cleanupOldHistory() {
    const keep = 60;
    if (_myHistTopics.length <= keep) return;
    final old = _myHistTopics.sublist(0, _myHistTopics.length - keep);
    _myHistTopics.removeRange(0, _myHistTopics.length - keep);
    for (final topic in old) {
      _clearRetained(topic);
    }
  }

  void _cleanupOldPhotos() {
    const keep = 3;
    if (_myPhotoIds.length <= keep) return;
    final old = _myPhotoIds.sublist(0, _myPhotoIds.length - keep);
    _myPhotoIds.removeRange(0, _myPhotoIds.length - keep);
    for (final photoId in old) {
      _clearRetained(_topic('foto/$photoId'));
      for (var i = 0; i < 40; i++) {
        _clearRetained(_topic('foto/$photoId/c$i'));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Filmes e "assistir junto"
  // -------------------------------------------------------------------------

  Future<List<Movie>> loadMovies() async {
    await _waitFor(_moviesDeadlineGetter, _moviesDeadlineSetter,
        const Duration(seconds: 2));
    final list = _movies.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> addMovie({
    required String title,
    String? url,
    String? fileName,
  }) async {
    final id = _newId('f');
    final json = <String, dynamic>{
      'id': id,
      'title': title.trim().isEmpty ? 'Filme' : title.trim(),
      'url': url,
      'file': fileName,
      'by': _name,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _publish(_topic('movie/$id'), json, retain: true);
    _movies[id] = Movie.fromMqtt(json);
    onMoviesChanged?.call();
  }

  Future<void> removeMovie(String movieId) async {
    _clearRetained(_topic('movie/$movieId'));
    _movies.remove(movieId);
    onMoviesChanged?.call();
  }

  Future<void> publishPlayback({
    required String movieId,
    required double positionSeconds,
    required bool isPlaying,
    required String controller,
  }) async {
    _publish(_topic('play'), {
      'movie_id': movieId,
      'position_seconds': positionSeconds,
      'is_playing': isPlaying,
      'controller': controller,
    });
  }

  // -------------------------------------------------------------------------
  // Histórico do chat
  // -------------------------------------------------------------------------

  Future<List<Message>> loadMessages({int limit = 200}) async {
    await _waitFor(_histDeadlineGetter, _histDeadlineSetter,
        const Duration(seconds: 3));
    final list = _history.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (list.length > limit) {
      return list.sublist(list.length - limit);
    }
    return list;
  }

  // -------------------------------------------------------------------------
  // Utilidades
  // -------------------------------------------------------------------------

  DateTime? _histDeadlineGetter() => _histDeadline;
  void _histDeadlineSetter(DateTime d) => _histDeadline = d;
  DateTime? _moviesDeadlineGetter() => _moviesDeadline;
  void _moviesDeadlineSetter(DateTime d) => _moviesDeadline = d;

  Future<void> _waitFor(
    DateTime? Function() getter,
    void Function(DateTime) setter,
    Duration window,
  ) async {
    final connected = _connected;
    if (connected != null) {
      await connected.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {},
      );
    }
    var deadline = getter();
    if (deadline == null) {
      deadline = DateTime.now().add(window);
      setter(deadline);
    }
    final wait = deadline.difference(DateTime.now());
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
  }

  String _topic(String suffix) => '${AppConfig.topicBase}/$_room/$suffix';

  String get _statusTopic => '${_topic('status')}/$_clientId';

  Future<String> _loadClientId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null || id.isEmpty) {
      final random = Random.secure();
      id = 'ponte-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-'
          '${random.nextInt(999999)}';
      await prefs.setString('device_id', id);
    }
    return id;
  }

  String _newId(String prefix) {
    final random = Random.secure();
    return '$prefix${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        '${random.nextInt(1296).toRadixString(36)}';
  }
}
