import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/chat/chat_model.dart';
import '../models/chat/chat_message_model.dart';
import 'token_service.dart';


class ChatService {
  static const String _baseUrl = 'http://34.58.11.82:8082/unihub/chat/api/v1';


  static const String _sockJsBase = 'http://34.58.11.82:8082/unihub/chat/ws';
  static const bool enableLogging = true;

  // ── Listener maps ──────────────────────────────────────────────────────────
  static final Map<String, void Function(Map<String, dynamic>)> _messageListeners = {};
  static final Map<String, void Function(Map<String, dynamic>)> _typingListeners = {};
  static final Map<String, void Function(Map<String, dynamic>)> _readListeners = {};

  // ── State ──────────────────────────────────────────────────────────────────
  static WebSocket? _ws;
  static String? _currentToken;
  static String? _currentUserEmail;
  static String? _currentTid;
  static String? _currentCid;

  static String get baseUrl => _baseUrl;

  static Timer? _heartbeatTimer;
  static Timer? _reconnectTimer;
  static bool _isConnected = false;
  static bool _isConnecting = false;
  static int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  // Rooms we must (re-)subscribe to after every connect.
  static final Set<String> _subscribedRooms = {};

  static String? get currentUserEmail => _currentUserEmail;

  static bool get isConnected => _isConnected;

  // ── Headers ────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _getHeaders({bool json = true}) async {
    final accessToken = await TokenService.getAccessToken();
    final userData = await TokenService.getUserData();

    final headers = <String, String>{
      if (json) 'Content-Type': 'application/json',
    };

    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    if (userData != null) {
      final university = userData['university'];
      if (university != null) {
        if (university['tid'] != null) {
          headers['X-User-University-Id'] = university['tid'].toString();
          _currentTid = university['tid'].toString();
        }
        if (university['cid'] != null) {
          headers['X-User-College-Id'] = university['cid'].toString();
          _currentCid = university['cid'].toString();
        }
      }
      if (userData['email'] != null) {
        headers['X-User-Email'] = userData['email'].toString();
        _currentUserEmail = userData['email'].toString();
      }
    }

    return headers;
  }


  static void initWebSocket(String userId, String token, {String? tid, String? cid}) {
    if (_isConnecting || _isConnected) return;

    _currentToken = token;
    _currentUserEmail = userId;
    _currentTid = tid;
    _currentCid = cid;
    _reconnectAttempts = 0;

    _connect();
  }

  static Future<void> _connect() async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {

      final infoUrl = '$_sockJsBase/info?t=${DateTime.now().millisecondsSinceEpoch}';
      if (enableLogging) print('SockJS info: $infoUrl');
      try {
        await http.get(Uri.parse(infoUrl)).timeout(const Duration(seconds: 5));
      } catch (_) {

      }


      final server = '000';
      final session = _randomHex(8);
      final wsBase = _sockJsBase
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      final wsUrl = '$wsBase/$server/$session/websocket';

      if (enableLogging) print('Connecting to SockJS WS: $wsUrl');

      _ws = await WebSocket.connect(
        wsUrl,
        headers: {
          if (_currentToken != null) 'Authorization': 'Bearer $_currentToken',
          if (_currentUserEmail != null) 'X-User-Email': _currentUserEmail!,
          if (_currentTid != null) 'X-User-University-Id': _currentTid!,
          if (_currentCid != null) 'X-User-College-Id': _currentCid!,
        },
      ).timeout(const Duration(seconds: 15));

      _ws!.listen(
        _onWsData,
        onDone: _onWsDone,
        onError: _onWsError,
        cancelOnError: false,
      );

      _isConnecting = false;
    } catch (e) {
      if (enableLogging) print('WS connect error: $e');
      _isConnecting = false;
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  static String _randomHex(int length) {
    final rand = DateTime.now().microsecondsSinceEpoch;
    return rand.toRadixString(16).padLeft(length, '0').substring(0, length);
  }



  static void _onWsData(dynamic raw) {

    String msg;
    if (raw is String) {
      msg = raw;
    } else if (raw is List<int>) {
      msg = utf8.decode(raw);
    } else {
      msg = raw.toString();
    }

    if (enableLogging && msg.length < 800) print('WS ← $msg');


    if (msg == 'o') {

      _sendStompConnect();
      return;
    }
    if (msg == 'h') return;
    if (msg.startsWith('c')) return;


    if (msg.startsWith('a')) {
      try {
        final list = jsonDecode(msg.substring(1)) as List;
        for (final frame in list) {
          _handleStompFrame(frame.toString());
        }
      } catch (e) {
        if (enableLogging) print('SockJS parse error: $e  raw=$msg');
      }
    }
  }

  static void _onWsDone() {
    if (enableLogging) print('WS disconnected');
    _isConnected = false;
    _isConnecting = false;
    _ws = null;
    _heartbeatTimer?.cancel();
    _scheduleReconnect();
  }

  static void _onWsError(Object error) {
    if (enableLogging) print('WS error: $error');
    _isConnected = false;
    _isConnecting = false;
  }


  static void _sockJsSend(String stompFrame) {
    if (_ws == null) return;


    try {
      final encoded = jsonEncode([stompFrame]);
      _ws!.add(encoded);
    } catch (e) {
      if (enableLogging) print('Error sending frame: $e');
    }
  }

  static void _sendStompConnect() {
    final buf = StringBuffer()
      ..write('CONNECT\n')
      ..write('accept-version:1.2\n')
      ..write('heart-beat:10000,10000\n');
    if (_currentUserEmail != null) buf.write('X-User-Email:$_currentUserEmail\n');
    if (_currentTid != null) buf.write('X-User-University-Id:$_currentTid\n');
    if (_currentCid != null) buf.write('X-User-College-Id:$_currentCid\n');
    if (_currentToken != null) buf.write('Authorization:Bearer $_currentToken\n');
    buf.write('\n\u0000');

    if (enableLogging) print('STOMP → CONNECT');
    _sockJsSend(buf.toString());
  }

  static void _handleStompFrame(String frame) {
    if (frame.startsWith('CONNECTED')) {
      if (enableLogging) print('✅ STOMP CONNECTED');
      _isConnected = true;
      _reconnectAttempts = 0;
      _startHeartbeat();

      // Subscribe to personal queue
      _stompSubscribe('/user/queue/rooms', 'sub-rooms');

      // Re-subscribe to all rooms
      for (final roomId in _subscribedRooms) {
        _stompSubscribe('/topic/room/$roomId', 'sub-room-$roomId');
        _stompSubscribe('/topic/room/$roomId/typing', 'sub-typing-$roomId');
        _stompSubscribe('/topic/room/$roomId/read', 'sub-read-$roomId');
      }
      return;
    }

    if (frame.startsWith('MESSAGE')) {
      _parseStompMessageFrame(frame);
      return;
    }

    if (frame.startsWith('ERROR')) {
      if (enableLogging) print('STOMP ERROR: $frame');
    }
  }

  static void _stompSubscribe(String destination, String id) {
    final frame = 'SUBSCRIBE\nid:$id\ndestination:$destination\n\n\u0000';
    if (enableLogging) print('STOMP → SUBSCRIBE $destination');
    _sockJsSend(frame);
  }

  static void _stompSend(String destination, String jsonBody) {
    if (!_isConnected || _ws == null) {
      if (enableLogging) print('⚠️ Cannot send, not connected');
      return;
    }

    final frame =
        'SEND\ndestination:$destination\ncontent-type:application/json;charset=UTF-8\n\n$jsonBody\u0000';
    _sockJsSend(frame);
  }

  static void _parseStompMessageFrame(String frame) {
    try {
      final bodyStart = frame.indexOf('\n\n');
      if (bodyStart == -1) return;

      final headersSection = frame.substring(0, bodyStart);
      String? destination;
      for (final line in headersSection.split('\n')) {
        if (line.startsWith('destination:')) {
          destination = line.substring('destination:'.length).trim();
          break;
        }
      }

      var body = frame.substring(bodyStart + 2);
      if (body.endsWith('\u0000')) body = body.substring(0, body.length - 1);
      body = body.trim();
      if (body.isEmpty) return;

      final data = jsonDecode(body) as Map<String, dynamic>;
      _routeMessage(data, destination);
    } catch (e) {
      if (enableLogging) print('STOMP parse error: $e');
    }
  }


  static void _routeMessage(Map<String, dynamic> data, String? destination) {
    if (destination == null) return;

    // ── Typing ─────────────────────────────────────────────────────────────
    if (destination.contains('/typing')) {
      final roomId = data['roomId']?.toString() ?? data['room_id']?.toString();
      if (roomId != null && _typingListeners.containsKey(roomId)) {
        _typingListeners[roomId]!(data);
      }
      return;
    }

    // ── Read receipt ────────────────────────────────────────────────────────
    if (destination.contains('/read')) {
      final roomId = data['roomId']?.toString() ?? data['room_id']?.toString();
      if (roomId != null && _readListeners.containsKey(roomId)) {
        _readListeners[roomId]!(data);
      }
      return;
    }

    // ── Room-update events (/user/queue/rooms) ──────────────────────────────
    if (destination == '/user/queue/rooms' || destination.endsWith('/queue/rooms')) {
      final eventType = data['type']?.toString();
      final roomId = data['roomId']?.toString() ?? data['room_id']?.toString();

      if (eventType == 'MESSAGE' && roomId != null) {
        final messageData = data['message'] as Map<String, dynamic>?;
        if (messageData != null && _messageListeners.containsKey(roomId)) {
          _messageListeners[roomId]!(messageData);
        }
      }
      return;
    }

    // ── Direct room topic (/topic/room/<id>) ────────────────────────────────
    final roomId = data['room_id']?.toString() ?? data['roomId']?.toString();
    if (roomId != null && _messageListeners.containsKey(roomId)) {
      _messageListeners[roomId]!(data);
    }
  }

  // ── Heartbeat ─────────────────────────────────────────────────────────────

  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_ws != null && _isConnected) {
        try {
          _ws!.add('h');
        } catch (_) {}
      }
    });
  }

  // ── Reconnect ─────────────────────────────────────────────────────────────

  static void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (enableLogging) print('Max reconnect attempts reached.');
      return;
    }
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: _reconnectAttempts * 2 + 1);
    _reconnectAttempts++;
    if (enableLogging) {
      print('Reconnecting in ${delay.inSeconds}s '
          '(attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    }
    _reconnectTimer = Timer(delay, () {
      if (_currentUserEmail != null) _connect();
    });
  }

  static void disconnectWebSocket() {
    _reconnectAttempts = _maxReconnectAttempts;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _ws?.close();
    _ws = null;
    _isConnected = false;
    _isConnecting = false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Room subscriptions
  // ══════════════════════════════════════════════════════════════════════════

  static void subscribeToRoom(String roomId) {
    _subscribedRooms.add(roomId);
    if (!_isConnected) return;
    _stompSubscribe('/topic/room/$roomId', 'sub-room-$roomId');
    _stompSubscribe('/topic/room/$roomId/typing', 'sub-typing-$roomId');
    _stompSubscribe('/topic/room/$roomId/read', 'sub-read-$roomId');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Message sending
  // ══════════════════════════════════════════════════════════════════════════

  static void sendTextMessage({
    required String roomId,
    required String content,
    String? replyToMessageId,
    List<String>? mentionedEmails,
  }) {
    final payload = <String, dynamic>{
      'roomId': roomId,
      'content': content, // Content with emojis preserved
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (mentionedEmails != null && mentionedEmails.isNotEmpty)
        'mentionedEmails': mentionedEmails,
    };
    final jsonString = jsonEncode(payload);
    _stompSend('/app/chat.send', jsonString);
    if (enableLogging) print('📤 sendTextMessage: $content');
  }

  static void sendTyping(String roomId, bool isTyping) {
    if (!_isConnected) return;
    _stompSend(
      '/app/chat.typing',
      jsonEncode({'roomId': roomId, 'typing': isTyping}),
    );
  }

  static void markAsRead(String roomId) {
    if (!_isConnected) return;
    _stompSend('/app/chat.read', jsonEncode({'roomId': roomId}));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Listener registration
  // ══════════════════════════════════════════════════════════════════════════

  static void addMessageListener(String roomId, void Function(Map<String, dynamic>) callback) {
    _messageListeners[roomId] = callback;
    subscribeToRoom(roomId);
    if (enableLogging) print('👂 Message listener added for room: $roomId');
  }

  static void removeMessageListener(String roomId) {
    _messageListeners.remove(roomId);
  }

  static void addTypingListener(String roomId, void Function(Map<String, dynamic>) callback) {
    _typingListeners[roomId] = callback;
    if (enableLogging) print('👂 Typing listener added for room: $roomId');
  }

  static void removeTypingListener(String roomId) {
    _typingListeners.remove(roomId);
  }

  static void addReadListener(String roomId, void Function(Map<String, dynamic>) callback) {
    _readListeners[roomId] = callback;
  }

  static void removeReadListener(String roomId) {
    _readListeners.remove(roomId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REST API
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<ChatUser>> searchUsers(String query) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
        Uri.parse('$_baseUrl/users/search?q=${Uri.encodeComponent(query)}'),
        headers: headers,
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((j) => ChatUser.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      if (enableLogging) print('❌ searchUsers: $e');
      return [];
    }
  }

  static Future<ChatRoom> createDirectChat(String targetEmail) async {
    final headers = await _getHeaders();
    final response = await http
        .post(
      Uri.parse('$_baseUrl/rooms/direct'),
      headers: headers,
      body: jsonEncode({'targetEmail': targetEmail}),
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ChatRoom.fromJson(jsonDecode(response.body));
    }
    throw Exception('createDirectChat failed: ${response.statusCode} ${response.body}');
  }

  static Future<ChatRoom> createGroupChat({
    required String name,
    required List<String> participantEmails,
  }) async {
    final headers = await _getHeaders();
    final response = await http
        .post(
      Uri.parse('$_baseUrl/rooms/group'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'participantEmails': participantEmails,
      }),
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ChatRoom.fromJson(jsonDecode(response.body));
    }
    throw Exception('createGroupChat failed: ${response.statusCode} ${response.body}');
  }

  static Future<List<ChatRoom>> getUserChatRooms() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$_baseUrl/rooms'), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((j) => ChatRoom.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      if (enableLogging) print('❌ getUserChatRooms: $e');
      return [];
    }
  }

  static Future<ChatRoom> getChatRoomById(String roomId) async {
    final headers = await _getHeaders();
    final response = await http
        .get(Uri.parse('$_baseUrl/rooms/$roomId'), headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return ChatRoom.fromJson(jsonDecode(response.body));
    }
    throw Exception('getChatRoomById failed: ${response.statusCode}');
  }

  static Future<List<ChatMessage>> getMessages(String roomId, {int page = 1}) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
        Uri.parse('$_baseUrl/rooms/$roomId/messages?page=$page'),
        headers: headers,
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = (data['content'] ?? []) as List;
        return content.map((j) => ChatMessage.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      if (enableLogging) print('❌ getMessages: $e');
      return [];
    }
  }

  static Future<ChatMessage> sendImageMessage({
    required String roomId,
    required File image,
    String? replyToMessageId,
    String? content,
  }) async {
    final token = await TokenService.getAccessToken();
    final userData = await TokenService.getUserData();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/rooms/$roomId/messages/image'),
    );
    _applyMultipartHeaders(request, token, userData);

    request.files.add(await http.MultipartFile.fromPath('file', image.path));
    if (replyToMessageId != null) request.fields['replyTo'] = replyToMessageId;
    if (content != null && content.isNotEmpty) request.fields['content'] = content;

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) return ChatMessage.fromJson(jsonDecode(body));
    throw Exception('sendImageMessage failed: ${streamed.statusCode} $body');
  }

  static Future<ChatMessage> sendVoiceMessage({
    required String roomId,
    required File voice,
    required int durationSecs,
    String? replyToMessageId,
  }) async {
    final token = await TokenService.getAccessToken();
    final userData = await TokenService.getUserData();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/rooms/$roomId/messages/voice?duration_secs=$durationSecs'),
    );
    _applyMultipartHeaders(request, token, userData);

    request.files.add(await http.MultipartFile.fromPath('file', voice.path));
    if (replyToMessageId != null) request.fields['replyTo'] = replyToMessageId;

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) return ChatMessage.fromJson(jsonDecode(body));
    throw Exception('sendVoiceMessage failed: ${streamed.statusCode} $body');
  }

  static void _applyMultipartHeaders(
      http.MultipartRequest request,
      String? token,
      Map<String, dynamic>? userData,
      ) {
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (userData != null) {
      final uni = userData['university'];
      if (uni != null) {
        if (uni['tid'] != null) request.headers['X-User-University-Id'] = uni['tid'].toString();
        if (uni['cid'] != null) request.headers['X-User-College-Id'] = uni['cid'].toString();
      }
      if (userData['email'] != null) request.headers['X-User-Email'] = userData['email'].toString();
    }
  }

  static Future<ChatMessage> editMessage(String messageId, String newContent) async {
    final headers = await _getHeaders();
    final response = await http
        .patch(
      Uri.parse('$_baseUrl/messages/$messageId'),
      headers: headers,
      body: jsonEncode({'content': newContent}),
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return ChatMessage.fromJson(jsonDecode(response.body));
    }
    throw Exception('editMessage failed: ${response.statusCode} ${response.body}');
  }

  static Future<ChatMessage> deleteMessage(String messageId) async {
    final headers = await _getHeaders();
    final response = await http
        .delete(
      Uri.parse('$_baseUrl/messages/$messageId'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return ChatMessage.fromJson(jsonDecode(response.body));
    }
    throw Exception('deleteMessage failed: ${response.statusCode} ${response.body}');
  }

  static Future<ChatRoom> updateGroupName(String roomId, String name) async {
    final headers = await _getHeaders(json: false);
    final response = await http
        .patch(
      Uri.parse('$_baseUrl/rooms/$roomId/name?name=${Uri.encodeComponent(name)}'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return ChatRoom.fromJson(jsonDecode(response.body));
    }
    throw Exception('updateGroupName failed: ${response.statusCode}');
  }

  static Future<void> addParticipants(String roomId, List<String> emails) async {
    final headers = await _getHeaders();
    final response = await http
        .post(
      Uri.parse('$_baseUrl/rooms/$roomId/participants'),
      headers: headers,
      body: jsonEncode({'emails': emails}),
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 204) {
      throw Exception('addParticipants failed: ${response.statusCode}');
    }
  }

  static Future<void> removeParticipant(String roomId, String targetEmail) async {
    final headers = await _getHeaders();
    final response = await http
        .delete(
      Uri.parse('$_baseUrl/rooms/$roomId/participants/$targetEmail'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 204) {
      throw Exception('removeParticipant failed: ${response.statusCode}');
    }
  }

  static Future<void> leaveRoom(String roomId) async {
    final headers = await _getHeaders();
    final response = await http
        .delete(
      Uri.parse('$_baseUrl/rooms/$roomId/leave'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 204) {
      throw Exception('leaveRoom failed: ${response.statusCode}');
    }
  }

  static Future<void> deleteRoom(String roomId) async {
    final headers = await _getHeaders();
    final response = await http
        .delete(
      Uri.parse('$_baseUrl/rooms/$roomId'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 204) {
      throw Exception('deleteRoom failed: ${response.statusCode}');
    }
  }

  static Future<Uint8List> getVoiceMessage(String messageId) async {
    try {
      final headers = await _getHeaders(json: false);
      final response = await http.get(
        Uri.parse('$_baseUrl/messages/$messageId/voice'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get voice message status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      throw Exception('Failed to get voice message: ${response.statusCode}');
    } catch (e) {
      if (enableLogging) print('Get voice error: $e');
      rethrow;
    }
  }

  static Future<ChatUser> getUserPresence(String email) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$email/presence'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get presence status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return ChatUser.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to get presence');
    } catch (e) {
      if (enableLogging) print('Get presence error: $e');
      rethrow;
    }
  }
}