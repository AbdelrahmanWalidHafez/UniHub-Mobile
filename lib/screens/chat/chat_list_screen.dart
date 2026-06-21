import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat/chat_model.dart';
import '../../services/chat_service.dart';
import 'chat_screen_modern.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;
  final String userName;

  const ChatListScreen({
    super.key,
    required this.onMenuPressed,
    required this.userName,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with WidgetsBindingObserver {
  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);

  // List of random colors for avatars
  final List<Color> _avatarColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  Color _getAvatarColor(String name) {
    final hash = name.hashCode.abs();
    return _avatarColors[hash % _avatarColors.length];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChatRooms();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _loadChatRooms() {
    final provider = context.read<ChatProvider>();
    provider.loadChatRooms(refresh: true);
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}';
    } else if (difference.inDays > 0) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[timestamp.weekday - 1];
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }

  String _getDisplayName(ChatRoom room, String currentUserEmail) {
    if (room.isGroup) {
      return room.name ?? 'Group Chat';
    }
    final otherParticipant = room.participants.firstWhere(
          (p) => p.email != currentUserEmail,
      orElse: () => room.participants.first,
    );
    return otherParticipant.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserEmail = authProvider.userEmail ?? '';

    return Scaffold(
      backgroundColor: _lightBg,
      body: Column(
        children: [
          // ── White App Bar ──────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.black),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NewChatScreen()),
                        ).then((_) => _loadChatRooms());
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: _lime,
              onRefresh: () => provider.loadChatRooms(refresh: true),
              child: provider.isLoading && provider.chatRooms.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.chatRooms.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: provider.chatRooms.length,
                itemBuilder: (context, index) {
                  final room = provider.chatRooms[index];
                  final lastMessage = room.lastMessage;
                  final displayName = _getDisplayName(room, currentUserEmail);

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreenModern(room: room),
                        ),
                      ).then((_) {
                        provider.loadChatRooms(refresh: true);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade100,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: _getAvatarColor(displayName),
                            child: Text(
                              displayName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (lastMessage != null) ...[
                                      if (room.unreadCount > 0)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: const BoxDecoration(
                                            color: _lime,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      Icon(
                                        lastMessage.type == 'IMAGE' ? Icons.image :
                                        lastMessage.type == 'VOICE' ? Icons.mic :
                                        Icons.message,
                                        size: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          lastMessage.senderEmail == currentUserEmail
                                              ? 'You: ${lastMessage.contentPreview}'
                                              : lastMessage.contentPreview,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: room.unreadCount > 0
                                                ? Colors.black87
                                                : Colors.grey.shade600,
                                            fontWeight: room.unreadCount > 0
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ] else
                                      const Text('No messages yet', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Trailing (time + unread count)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (lastMessage != null)
                                Text(
                                  _formatTimestamp(lastMessage.sentAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              if (room.unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _lime,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    room.unreadCount.toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _lime.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _lime.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: _lime,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Chats Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the search icon to start a new chat',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}