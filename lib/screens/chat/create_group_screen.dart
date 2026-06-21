import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat/chat_model.dart';
import 'chat_screen_modern.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<ChatUser> _selectedUsers = [];
  List<ChatUser> _searchResults = [];
  bool _isSearching = false;

  bool _onNameStep = false;
  final TextEditingController _groupNameController = TextEditingController();
  bool _isCreating = false;

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
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final provider = context.read<ChatProvider>();
    await provider.searchUsers(query.trim());

    final currentEmail = context.read<AuthProvider>().userEmail ?? '';
    final results = provider.searchResults.map((u) {
      if (u is ChatUser) return u;
      if (u is Map) {
        return ChatUser(
          email: u['email']?.toString() ?? '',
          displayName: u['display_name']?.toString() ??
              u['displayName']?.toString() ?? '',
          isOnline: u['is_online'] ?? u['isOnline'] ?? false,
        );
      }
      return ChatUser(email: '', displayName: '', isOnline: false);
    }).where((u) => u.email.isNotEmpty && u.email != currentEmail).toList();

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _toggleUser(ChatUser user) {
    setState(() {
      final idx = _selectedUsers.indexWhere((u) => u.email == user.email);
      if (idx >= 0) {
        _selectedUsers.removeAt(idx);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  bool _isSelected(ChatUser user) =>
      _selectedUsers.any((u) => u.email == user.email);

  void _goToNameStep() {
    if (_selectedUsers.isEmpty) return;
    setState(() => _onNameStep = true);
  }

  void _backToSelectStep() {
    setState(() => _onNameStep = false);
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty || _selectedUsers.isEmpty || _isCreating) return;

    setState(() => _isCreating = true);
    try {
      final provider = context.read<ChatProvider>();
      final room = await provider.createGroupChat(
        name: name,
        participantEmails: _selectedUsers.map((u) => u.email).toList(),
      );

      if (room != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => ChatScreenModern(room: room)),
              (route) => route.isFirst,
        );
      } else if (mounted) {
        _showError('Failed to create group. Please try again.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade600,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _onNameStep ? _buildNameStep() : _buildSelectStep(),
    );
  }

  Widget _buildSelectStep() {
    return Scaffold(
      key: const ValueKey('select'),
      backgroundColor: _lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Group',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            Text(
              'Add participants',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_selectedUsers.isNotEmpty) _buildSelectedChipsBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                autofocus: true,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search by name or email…',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search, color: _lime, size: 22),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: _isSearching
                      ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    ),
                  )
                      : _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade500, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                    },
                  )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(child: _buildResultsList()),
        ],
      ),
      floatingActionButton: _selectedUsers.isNotEmpty
          ? FloatingActionButton(
        onPressed: _goToNameStep,
        backgroundColor: _lime,
        child: const Icon(Icons.arrow_forward, color: Colors.black),
      )
          : null,
    );
  }

  Widget _buildSelectedChipsBar() {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: _selectedUsers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final user = _selectedUsers[i];
          final initials = user.displayName.isNotEmpty
              ? user.displayName[0].toUpperCase()
              : user.email[0].toUpperCase();
          return GestureDetector(
            onTap: () => _toggleUser(user),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _getAvatarColor(user.displayName),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.displayName.isNotEmpty
                      ? user.displayName.split(' ').first
                      : user.email.split('@').first,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultsList() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.group_add, size: 48, color: Colors.black),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add people to your group',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'Search by name or email address',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && !_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_search, size: 48, color: Colors.black),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length,
      itemBuilder: (_, i) {
        final user = _searchResults[i];
        final selected = _isSelected(user);
        final initials = user.displayName.isNotEmpty
            ? user.displayName[0].toUpperCase()
            : user.email[0].toUpperCase();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? _lime.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _lime : Colors.grey.shade100,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: selected ? _lime : _getAvatarColor(user.displayName),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 7,
                        backgroundColor: Color(0xFF25D366),
                        child: Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              user.displayName.isNotEmpty
                  ? user.displayName
                  : user.email.split('@').first,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: selected ? Color(0xFF0077B3) : Colors.black87,
              ),
            ),
            subtitle: Text(
              user.email,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: selected
                ? const Icon(Icons.check_circle, color: _lime)
                : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
            onTap: () => _toggleUser(user),
          ),
        );
      },
    );
  }

  Widget _buildNameStep() {
    return Scaffold(
      key: const ValueKey('name'),
      backgroundColor: _lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToSelectStep,
        ),
        title: const Text(
          'New Group',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.black, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _groupNameController,
                    autofocus: true,
                    maxLength: 50,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Group name',
                      hintStyle: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: Colors.grey,
                      ),
                      border: UnderlineInputBorder(),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 2),
                      ),
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Participants: ${_selectedUsers.length}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _selectedUsers.length,
              itemBuilder: (_, i) {
                final user = _selectedUsers[i];
                final initials = user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : user.email[0].toUpperCase();
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: _getAvatarColor(user.displayName),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName
                          : user.email.split('@').first,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      user.email,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      onPressed: () {
                        _toggleUser(user);
                        if (_selectedUsers.isEmpty) _backToSelectStep();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _groupNameController.text.trim().isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: _isCreating ? null : _createGroup,
        backgroundColor: _lime,
        icon: _isCreating
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
        )
            : const Icon(Icons.check, color: Colors.black),
        label: Text(
          _isCreating ? 'Creating…' : 'Create Group',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      )
          : null,
    );
  }
}