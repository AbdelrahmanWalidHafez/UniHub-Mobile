import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'account_screen.dart';
import 'announcement/announcement_page.dart';
import 'chat/chat_list_screen.dart';
import 'login_screen.dart';
import 'ai_chat_screen.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import 'classroom/classroom_list_screen.dart';
import 'meeting/create_meeting_screen.dart';
import 'task/task_manager_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final storage = const FlutterSecureStorage();

  // User data
  String userName = "Loading...";
  String userEmail = "";
  String userAvatar = "";
  bool isLoading = true;
  String? errorMessage;

  // Bottom navigation
  int _selectedNavIndex = 0;

  static const Color _brand = Color(0xFF0077B3);
  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);
  static const Color _darkBlue = Color(0xFF1E3A5F);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    ChatService.disconnectWebSocket();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final accessToken = authProvider.accessToken;

      if (accessToken == null) {
        setState(() {
          userName = "Guest User";
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://34.136.140.99:8083/api/v1/auth/user-info'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          final firstName = data['first_name'] ?? '';
          final lastName = data['last_name'] ?? '';

          if (firstName.isNotEmpty && lastName.isNotEmpty) {
            userName = '$firstName $lastName';
          } else if (firstName.isNotEmpty) {
            userName = firstName;
          } else if (lastName.isNotEmpty) {
            userName = lastName;
          } else {
            userName = data['email']?.split('@').first ?? 'User';
          }

          userEmail = data['email'] ?? '';
          userAvatar = data['avatar'] ?? '';
          isLoading = false;
        });

        _initChatWebSocket();
      } else if (response.statusCode == 401) {
        final refreshed = await authProvider.refreshToken();
        if (refreshed) {
          await _loadUserData();
        } else {
          _redirectToLogin();
        }
      } else {
        setState(() {
          userName = "User";
          userEmail = "";
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        userName = "User";
        userEmail = "";
        isLoading = false;
      });
    }
  }

  void _initChatWebSocket() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userEmail;
    final token = authProvider.accessToken;

    if (userId != null && token != null && userId.isNotEmpty && token.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        ChatService.initWebSocket(userId, token);
      });
    }
  }

  void _redirectToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }


  void _switchTab(BuildContext sheetCtx, int index) {
    Navigator.pop(sheetCtx);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _selectedNavIndex = index);
    });
  }


  void _pushScreen(BuildContext sheetCtx, Widget screen) {
    Navigator.pop(sheetCtx);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      }
    });
  }

  void _showMenuSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // User header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: _darkBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Menu items ────────────────────────────────────────────────

              // Announcements → tab 0
              _buildMenuItem(
                icon: Icons.campaign,
                title: 'Announcements',
                onTap: () => _switchTab(sheetContext, 0),
              ),

              // Lumos AI → full screen
              _buildMenuItem(
                icon: Icons.auto_awesome,
                title: 'Lumos AI',
                onTap: () => _pushScreen(
                  sheetContext,
                  AIChatScreen(userName: userName),
                ),
              ),

              // Chat → tab 1
              _buildMenuItem(
                icon: Icons.chat_bubble_outline,
                title: 'Chat',
                onTap: () => _switchTab(sheetContext, 1),
              ),

              // My Classes → tab 2
              _buildMenuItem(
                icon: Icons.class_outlined,
                title: 'My Classes',
                onTap: () => _switchTab(sheetContext, 2),
              ),

              // Task Manager → full screen
              _buildMenuItem(
                icon: Icons.task_alt,
                title: 'Task Manager',
                onTap: () => _pushScreen(
                  sheetContext,
                  const TaskManagerScreen(),
                ),
              ),

              // Meeting → full screen
              _buildMenuItem(
                icon: Icons.video_call,
                title: 'Meeting',
                onTap: () => _pushScreen(
                  sheetContext,
                  const CreateMeetingScreen(),
                ),
              ),

              const Divider(height: 1),

              // Logout
              _buildMenuItem(
                icon: Icons.logout,
                title: 'Logout',
                isLogout: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) _showLogoutDialog();
                  });
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isLogout
              ? Colors.red.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isLogout ? Colors.red : Colors.black,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isLogout ? Colors.red : Colors.black87,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isLogout ? Colors.red : Colors.grey.shade400,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              ChatService.disconnectWebSocket();
              final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAvatarMenu(BuildContext anchorContext) {
    final RenderBox button = anchorContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
    Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.bottomLeft(Offset.zero), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: anchorContext,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      elevation: 6,
      items: [
        PopupMenuItem<String>(
          value: 'account',
          child: Row(
            children: const [
              Icon(Icons.person_outline, size: 20, color: Colors.black87),
              SizedBox(width: 12),
              Text('Account', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout, size: 20, color: Colors.black87),
              SizedBox(width: 12),
              Text('Logout', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (!mounted || value == null) return;
      if (value == 'account') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountScreen()),
        );
      } else if (value == 'logout') {
        _showLogoutDialog();
      }
    });
  }

  String _getAppBarTitle() {
    switch (_selectedNavIndex) {
      case 0:
        return 'Announcements';
      case 1:
        return 'Chats';
      case 2:
        return 'Classroom';
      default:
        return 'UniHub';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          title: Padding(
            padding: const EdgeInsets.only(top: 35.0),
            child: Text(
              _getAppBarTitle(),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            onPressed: _showMenuSheet,
            icon: const Icon(Icons.menu, color: Colors.black),
          ),
          actions: [
            Builder(
              builder: (avatarContext) {
                return IconButton(
                  onPressed: () => _showAvatarMenu(avatarContext),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: _darkBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedNavIndex,
        children: [
          // Index 0: Announcements
          AnnouncementPage(isSecretary: false),
          // Index 1: Chat
          ChatListScreen(onMenuPressed: _showMenuSheet, userName: userName),
          // Index 2: My Classes
          const ClassroomListScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedNavIndex,
          onTap: (index) {
            setState(() {
              _selectedNavIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: _lime,
          unselectedItemColor: Colors.grey.shade500,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.announcement_outlined),
              activeIcon: Icon(Icons.announcement),
              label: 'Announcements',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.class_outlined),
              activeIcon: Icon(Icons.class_),
              label: 'Classes',
            ),
          ],
        ),
      ),
    );
  }
}