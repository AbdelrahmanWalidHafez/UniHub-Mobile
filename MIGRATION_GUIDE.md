# Chat System Migration Guide

## Quick Start - 3 Steps to Get Working

### Step 1: Update Chat Screen Navigation
Find all places where you import/use `ChatScreen` and replace with `ChatScreenModern`:

**Before:**
```dart
import '../../screens/chat/chat_screen.dart';

// In navigation
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ChatScreen(room: chatRoom),
));
```

**After:**
```dart
import '../../screens/chat/chat_screen_modern.dart';

// In navigation
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ChatScreenModern(room: chatRoom),
));
```

### Step 2: Initialize WebSocket on App Start
In your `main.dart` or authentication flow:

```dart
void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final userData = await TokenService.getUserData();
    final token = await TokenService.getAccessToken();
    
    if (userData != null && userData['email'] != null && token != null) {
      ChatService.initWebSocket(
        userData['email'] as String,
        token,
      );
    }
  }

  @override
  void dispose() {
    ChatService.disconnectWebSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        // ... other providers
      ],
      child: MaterialApp(
        // ... app config
      ),
    );
  }
}
```

### Step 3: Update pubspec.yaml (if needed)
Ensure you have these packages in your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  http: ^1.1.0
  web_socket_channel: ^2.4.0  # Add if not present
  image_picker: ^1.0.5
  file_picker: ^8.0.5
  flutter_secure_storage: ^9.0.0
```

Run: `flutter pub get`

## File Structure After Migration

```
lib/
├── screens/
│   └── chat/
│       ├── chat_screen.dart           # Old - Keep for backup
│       ├── chat_screen_modern.dart    # NEW - Use this ✨
│       ├── group_info_screen.dart
│       └── voice_message_widget.dart
├── services/
│   ├── chat_service.dart              # UPDATED ✨
│   ├── token_service.dart
│   └── ...
├── providers/
│   ├── chat_provider.dart             # UPDATED ✨
│   └── ...
└── models/
    └── chat/
        ├── chat_model.dart
        ├── chat_message_model.dart
        └── chat_user_model.dart
```

## Common Use Cases

### Open Chat from User List
```dart
Future<void> _openChat(ChatUser user) async {
  try {
    final provider = context.read<ChatProvider>();
    final room = await provider.createDirectChat(user.email);
    
    if (room != null && mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreenModern(room: room),
      ));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Load Chat Rooms List
```dart
class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({super.key});

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ChatProvider>().loadChatRooms(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.chatRooms.isEmpty) {
          return const Center(child: Text('No chats yet'));
        }

        return ListView.builder(
          itemCount: provider.chatRooms.length,
          itemBuilder: (context, index) {
            final room = provider.chatRooms[index];
            return ListTile(
              title: Text(room.name ?? 'Chat'),
              subtitle: Text(room.lastMessage?.contentPreview ?? 'No messages'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreenModern(room: room),
                ));
              },
            );
          },
        );
      },
    );
  }
}
```

### Search and Create Direct Chat
```dart
class CreateChatScreen extends StatefulWidget {
  const CreateChatScreen({super.key});

  @override
  State<CreateChatScreen> createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends State<CreateChatScreen> {
  final _controller = TextEditingController();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search by email...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                context.read<ChatProvider>().searchUsers(value);
              },
            ),
          ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, _) {
                if (provider.searchResults.isEmpty) {
                  return const Center(child: Text('No users found'));
                }
                
                return ListView.builder(
                  itemCount: provider.searchResults.length,
                  itemBuilder: (context, index) {
                    final user = provider.searchResults[index];
                    return ListTile(
                      title: Text(user.displayName),
                      subtitle: Text(user.email),
                      onTap: () {
                        _startChat(user);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startChat(ChatUser user) async {
    try {
      final provider = context.read<ChatProvider>();
      final room = await provider.createDirectChat(user.email);
      
      if (room != null && mounted) {
        Navigator.of(context).pop(); // Close search
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatScreenModern(room: room),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

### Create Group Chat
```dart
Future<void> _createGroup(
  String groupName,
  List<String> emailList,
) async {
  try {
    final provider = context.read<ChatProvider>();
    final room = await provider.createGroupChat(
      name: groupName,
      participantEmails: emailList,
    );
    
    if (room != null && mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreenModern(room: room),
      ));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error creating group: $e')),
    );
  }
}
```

## Debugging Tips

### Enable Logging
In `chat_service.dart`, logging is already enabled:
```dart
static const bool enableLogging = true;
```

Check your Flutter console for detailed logs:
- WebSocket connection status
- Message routing
- Error details
- API call responses

### Check WebSocket Connection
```dart
// Add this to test connection
void _testWebSocket() {
  ChatService.addMessageListener('test-room', (data) {
    print('Message received: $data');
  });
}
```

### Monitor API Calls
All HTTP requests and responses are logged with status codes and errors.

## Breaking Changes from Old Chat Screen

1. **Import Path**: Use `chat_screen_modern.dart` instead of `chat_screen.dart`
2. **Class Name**: `ChatScreenModern` instead of `ChatScreen`
3. **WebSocket Init**: Now requires manual `ChatService.initWebSocket()` call
4. **Error Handling**: Better error messages shown to user via SnackBars
5. **Message Grouping**: Messages are now grouped by sender (visual only, no API change)

## Performance Tips

### For Large Chat Rooms
- Messages load in pages of 20
- Use `loadMoreMessages()` when reaching end
- Already optimized with ListView.builder

### For Multiple Active Chats
- Only one WebSocket connection shared across all chats
- Each room subscription is lightweight
- Proper cleanup on dispose prevents memory leaks

### For Mobile Devices
- Images are compressed at 80% quality
- Pagination prevents loading all messages at once
- Efficient state management with Provider

## Backwards Compatibility

- Old `ChatScreen` still exists but is deprecated
- All models remain the same (`ChatMessage`, `ChatRoom`, etc.)
- API endpoints unchanged
- WebSocket protocol unchanged

## Support & Debugging

If you encounter issues:

1. **Check WebSocket Connection**
   ```dart
   ChatService.enableLogging = true;
   // Watch console for connection messages
   ```

2. **Verify Permissions**
   - Camera permission for images
   - Microphone permission for voice
   - Storage permission for file access

3. **Check Network**
   - Test API connectivity: `http://34.58.11.82:8082/unihub/chat/api/v1/rooms`
   - Test WebSocket: `ws://34.58.11.82:8082/unihub/chat/ws`

4. **Common Errors**
   - "Missing X-User-Email": WebSocket not initialized with email
   - "Failed to send message": Check WebSocket connection
   - "Image not loading": Check image URL and permissions
