import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/chat/chat_model.dart';
import '../models/chat/chat_message_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatRoom> _chatRooms = [];
  List<ChatMessage> _messages = [];
  List<dynamic> _searchResults = [];
  ChatRoom? _currentRoom;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMoreMessages = true;

  Map<String, bool> _typingUsers = {};

  List<ChatRoom> get chatRooms => _chatRooms;
  List<ChatMessage> get messages => _messages;
  List<dynamic> get searchResults => _searchResults;
  ChatRoom? get currentRoom => _currentRoom;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMoreMessages => _hasMoreMessages;
  Map<String, bool> get typingUsers => _typingUsers;

  bool get isSomeoneTyping => _typingUsers.values.contains(true);
  String get typingUsersNames {
    return _typingUsers.entries
        .where((e) => e.value)
        .map((e) => e.key.split('@').first)
        .join(', ');
  }

  // ── Safe notify: never fires during a build frame ──────────────────────────
  bool _notifyScheduled = false;

  void _safeNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  void setCurrentRoom(ChatRoom room) {
    _currentRoom = room;
    _safeNotify();
  }

  // ── Chat rooms ─────────────────────────────────────────────────────────────

  Future<void> loadChatRooms({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) _chatRooms.clear();

    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      final rooms = await ChatService.getUserChatRooms();
      _chatRooms = rooms;

      for (final room in rooms) {
        ChatService.addMessageListener(room.id, _handleIncomingMessage);
        ChatService.addTypingListener(room.id, _handleTypingEvent);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('loadChatRooms error: $e');
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  void _handleTypingEvent(Map<String, dynamic> data) {
    try {
      final senderEmail =
          data['senderEmail']?.toString() ?? data['sender_email']?.toString();
      final isTyping = data['typing'] == true;
      if (senderEmail == null) return;

      _typingUsers[senderEmail] = isTyping;
      _safeNotify();

      if (isTyping) {
        Future.delayed(const Duration(seconds: 3), () {
          if (_typingUsers[senderEmail] == true) {
            _typingUsers.remove(senderEmail);
            _safeNotify();
          }
        });
      }
    } catch (e) {
      debugPrint('_handleTypingEvent error: $e');
    }
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  Future<void> loadMessages(String roomId, {bool refresh = false}) async {
    if (refresh) {
      _messages.clear();
      _currentPage = 1;
      _hasMoreMessages = true;
    }

    if (refresh && _isLoading) return;
    if (!refresh && _isLoadingMore) return;

    if (refresh) {
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }
    _error = null;
    _safeNotify();

    try {
      final fetched = await ChatService.getMessages(roomId, page: _currentPage);

      if (refresh) {
        _messages = fetched.reversed.toList();
      } else {
        _messages.insertAll(0, fetched.reversed.toList());
      }

      _hasMoreMessages = fetched.length == 20;
      if (_hasMoreMessages) _currentPage++;

      ChatService.markAsRead(roomId);
    } catch (e) {
      _error = e.toString();
      debugPrint('loadMessages error: $e');
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      _safeNotify();
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final message = ChatMessage.fromJson(data);

      // Check if message already exists by ID (prevent duplicates)
      final exists = _messages.any((m) => m.id == message.id);
      if (exists) return;

      final currentEmail = ChatService.currentUserEmail ?? '';
      final isOwnMessage = message.senderEmail == currentEmail;

      // For own messages, check if this is a temp message replacement
      if (isOwnMessage) {
        // Try to find a temp message with the same content and recent timestamp
        final tempIndex = _messages.indexWhere((m) {
          if (!m.id.startsWith('temp-')) return false;
          if (m.content != message.content) return false;
          if (m.senderEmail != currentEmail) return false;
          // Check if timestamps are close (within 5 seconds)
          final diff = m.createdAt.difference(message.createdAt).abs();
          return diff.inSeconds < 5;
        });

        if (tempIndex != -1) {
          // Replace temp message with real one
          _messages[tempIndex] = message;
          _safeNotify();
          _updateChatRoomLastMessage(message);
          return;
        }

        // Also check by temp ID pattern (for images/voice where content might differ)
        final tempIdIndex = _messages.indexWhere((m) {
          return m.id.startsWith('temp-') &&
              m.senderEmail == currentEmail &&
              m.roomId == message.roomId &&
              m.createdAt.difference(message.createdAt).abs().inSeconds < 10;
        });

        if (tempIdIndex != -1) {
          // Only replace if we have a match by room and time
          _messages[tempIdIndex] = message;
          _safeNotify();
          _updateChatRoomLastMessage(message);
          return;
        }
      }

      // If we get here, it's a new message (not a duplicate)
      _messages.add(message);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      _updateChatRoomLastMessage(message);
      _safeNotify();
    } catch (e) {
      debugPrint('_handleIncomingMessage error: $e');
    }
  }

  void _updateChatRoomLastMessage(ChatMessage message) {
    final roomIndex = _chatRooms.indexWhere((r) => r.id == message.roomId);
    if (roomIndex != -1) {
      final old = _chatRooms[roomIndex];
      final currentEmail = ChatService.currentUserEmail ?? '';
      final isOwn = message.senderEmail == currentEmail;

      final shouldIncrementUnread = !isOwn &&
          message.editedAt == null &&
          message.deletedAt == null &&
          old.lastMessage?.messageId != message.id;

      String preview;
      switch (message.type) {
        case MessageType.image:
          preview = message.content ?? 'Photo';
          break;
        case MessageType.voice:
          preview = 'Voice note';
          break;
        case MessageType.system:
          preview = message.content ?? '';
          break;
        default:
          preview = message.content ?? '';
      }

      final updated = ChatRoom(
        id: old.id,
        type: old.type,
        name: old.name,
        participants: old.participants,
        lastMessage: ChatRoomLastMessage(
          messageId: message.id,
          contentPreview: preview,
          senderEmail: message.senderEmail,
          type: message.type.toString().split('.').last.toUpperCase(),
          sentAt: message.createdAt,
        ),
        unreadCount: shouldIncrementUnread ? old.unreadCount + 1 : old.unreadCount,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );

      _chatRooms.removeAt(roomIndex);
      _chatRooms.insert(0, updated);
    }
  }

  void addNewMessage(ChatMessage message) {
    // Check if message already exists by ID
    final exists = _messages.any((m) => m.id == message.id);
    if (exists) return;

    // Check if this is a temp message we already have
    if (message.id.startsWith('temp-')) {
      final tempExists = _messages.any((m) => m.id == message.id);
      if (tempExists) return;
    }

    // For own messages, check if we have a temp that needs replacing
    final currentEmail = ChatService.currentUserEmail ?? '';
    if (message.senderEmail == currentEmail) {
      // Check if there's a temp message from this room with similar content
      final tempIndex = _messages.indexWhere((m) {
        if (!m.id.startsWith('temp-')) return false;
        if (m.senderEmail != currentEmail) return false;
        if (m.roomId != message.roomId) return false;
        // Check if same content or same message type
        if (m.content == message.content) return true;
        // For images/voice, check if within 5 seconds
        return m.createdAt.difference(message.createdAt).abs().inSeconds < 5;
      });

      if (tempIndex != -1) {
        _messages[tempIndex] = message;
        _safeNotify();
        _updateChatRoomLastMessage(message);
        return;
      }
    }

    _messages.add(message);
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _updateChatRoomLastMessage(message);
    _safeNotify();
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<ChatRoom?> createDirectChat(String targetEmail) async {
    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      final room = await ChatService.createDirectChat(targetEmail);
      if (!_chatRooms.any((r) => r.id == room.id)) {
        _chatRooms.insert(0, room);
      }
      return room;
    } catch (e) {
      _error = e.toString();
      debugPrint('createDirectChat error: $e');
      return null;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<ChatRoom?> createGroupChat({
    required String name,
    required List<String> participantEmails,
  }) async {
    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      final room = await ChatService.createGroupChat(
        name: name,
        participantEmails: participantEmails,
      );
      _chatRooms.insert(0, room);
      return room;
    } catch (e) {
      _error = e.toString();
      debugPrint('createGroupChat error: $e');
      return null;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> sendTextMessage({
    required String roomId,
    required String content,
    String? replyToMessageId,
    List<String>? mentionedEmails,
  }) async {
    try {
      ChatService.sendTextMessage(
        roomId: roomId,
        content: content,
        replyToMessageId: replyToMessageId,
        mentionedEmails: mentionedEmails,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('sendTextMessage error: $e');
      _safeNotify();
    }
  }

  Future<void> sendImageMessage({
    required String roomId,
    required File image,
    String? replyToMessageId,
    String? content,
  }) async {
    _isLoading = true;
    _safeNotify();

    try {
      final message = await ChatService.sendImageMessage(
        roomId: roomId,
        image: image,
        replyToMessageId: replyToMessageId,
        content: content,
      );
      addNewMessage(message);
    } catch (e) {
      _error = e.toString();
      debugPrint('sendImageMessage error: $e');
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> sendVoiceMessage({
    required String roomId,
    required File voice,
    required int durationSecs,
    String? replyToMessageId,
  }) async {
    _isLoading = true;
    _safeNotify();

    try {
      final message = await ChatService.sendVoiceMessage(
        roomId: roomId,
        voice: voice,
        durationSecs: durationSecs,
        replyToMessageId: replyToMessageId,
      );
      addNewMessage(message);
    } catch (e) {
      _error = e.toString();
      debugPrint('sendVoiceMessage error: $e');
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    try {
      final updated = await ChatService.editMessage(messageId, newContent);
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = updated;
        _safeNotify();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('editMessage error: $e');
      _safeNotify();
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      final deleted = await ChatService.deleteMessage(messageId);
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = deleted;
        _safeNotify();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('deleteMessage error: $e');
      _safeNotify();
    }
  }

  Future<void> updateGroupName(String roomId, String name) async {
    try {
      final updated = await ChatService.updateGroupName(roomId, name);
      final index = _chatRooms.indexWhere((r) => r.id == roomId);
      if (index != -1) _chatRooms[index] = updated;
      if (_currentRoom?.id == roomId) _currentRoom = updated;
      _safeNotify();
    } catch (e) {
      _error = e.toString();
      debugPrint('updateGroupName error: $e');
      _safeNotify();
    }
  }

  Future<void> addParticipant(String roomId, String email) async {
    try {
      await ChatService.addParticipants(roomId, [email]);
      final updated = await ChatService.getChatRoomById(roomId);
      _replaceRoom(updated);
      _safeNotify();
    } catch (e) {
      _error = e.toString();
      _safeNotify();
    }
  }

  Future<void> removeParticipant(String roomId, String email) async {
    try {
      await ChatService.removeParticipant(roomId, email);
      final updated = await ChatService.getChatRoomById(roomId);
      _replaceRoom(updated);
      _safeNotify();
    } catch (e) {
      _error = e.toString();
      _safeNotify();
    }
  }

  Future<void> leaveGroup(String roomId) async {
    try {
      await ChatService.leaveRoom(roomId);
      _chatRooms.removeWhere((r) => r.id == roomId);
      if (_currentRoom?.id == roomId) {
        _currentRoom = null;
        _messages.clear();
      }
      _safeNotify();
    } catch (e) {
      _error = e.toString();
      _safeNotify();
    }
  }

  Future<void> deleteGroup(String roomId) async {
    try {
      await ChatService.deleteRoom(roomId);
      _chatRooms.removeWhere((r) => r.id == roomId);
      if (_currentRoom?.id == roomId) {
        _currentRoom = null;
        _messages.clear();
      }
      _safeNotify();
    } catch (e) {
      _error = e.toString();
      _safeNotify();
    }
  }

  void _replaceRoom(ChatRoom updated) {
    final index = _chatRooms.indexWhere((r) => r.id == updated.id);
    if (index != -1) _chatRooms[index] = updated;
    if (_currentRoom?.id == updated.id) _currentRoom = updated;
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      _safeNotify();
      return;
    }

    _isLoading = true;
    _safeNotify();

    try {
      _searchResults = await ChatService.searchUsers(query);
    } catch (e) {
      _error = e.toString();
      _searchResults = [];
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  void sendTyping(String roomId, bool isTyping) {
    ChatService.sendTyping(roomId, isTyping);
  }

  void markAsRead(String roomId) {
    ChatService.markAsRead(roomId);
    final index = _chatRooms.indexWhere((r) => r.id == roomId);
    if (index != -1 && _chatRooms[index].unreadCount > 0) {
      final room = _chatRooms[index];
      _chatRooms[index] = ChatRoom(
        id: room.id,
        type: room.type,
        name: room.name,
        participants: room.participants,
        lastMessage: room.lastMessage,
        unreadCount: 0,
        createdAt: room.createdAt,
        updatedAt: DateTime.now(),
      );
      _safeNotify();
    }
  }

  void clearError() {
    _error = null;
    _safeNotify();
  }

  void clearTypingUsers() {
    _typingUsers.clear();
    _safeNotify();
  }

  void closeCurrentConversation() {
    _currentRoom = null;
    _messages.clear();
    _typingUsers.clear();
    _currentPage = 1;
    _hasMoreMessages = true;
    _safeNotify();
  }

  @override
  void dispose() {
    for (final room in _chatRooms) {
      ChatService.removeMessageListener(room.id);
      ChatService.removeTypingListener(room.id);
    }
    super.dispose();
  }
}