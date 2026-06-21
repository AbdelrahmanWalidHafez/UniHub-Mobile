import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/classroom_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/classroom/classroom_model.dart';
import 'classroom_detail_screen.dart';
import 'join_classroom_screen.dart';
import 'create_classroom_screen.dart';

class ClassroomListScreen extends StatefulWidget {
  const ClassroomListScreen({super.key});

  @override
  State<ClassroomListScreen> createState() => _ClassroomListScreenState();
}

class _ClassroomListScreenState extends State<ClassroomListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInstructor = false;
  bool _isInitialized = false;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);

  final Map<int, String> _classroomImages = {
    1: 'assets/images/classroom/class_1.jpg',
    2: 'assets/images/classroom/class_2.jpg',
    3: 'assets/images/classroom/class_3.jpg',
    4: 'assets/images/classroom/class_4.jpg',
    5: 'assets/images/classroom/class_5.jpg',
    6: 'assets/images/classroom/class_6.jpg',
    7: 'assets/images/classroom/class_7.jpg',
    8: 'assets/images/classroom/class_8.jpg',
    9: 'assets/images/classroom/class_9.jpg',
    10: 'assets/images/classroom/class_10.jpg',
  };

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkUserRole() {
    final authProvider = context.read<AuthProvider>();
    final userRole = authProvider.currentUser?['role']?.toString() ?? '';
    _isInstructor = userRole.toLowerCase().contains('instructor');

    final tabLength = _isInstructor ? 3 : 2;
    _tabController = TabController(length: tabLength, vsync: this);
    _isInitialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final provider = context.read<ClassroomProvider>();
    if (_isInstructor) {
      provider.loadTeachingClasses(refresh: true);
    } else {
      provider.loadEnrolledClasses(refresh: true);
    }
    provider.loadArchivedClasses(refresh: true);
  }

  Future<void> _refresh() async {
    final provider = context.read<ClassroomProvider>();
    if (_isInstructor) {
      await provider.loadTeachingClasses(refresh: true);
    } else {
      await provider.loadEnrolledClasses(refresh: true);
    }
    await provider.loadArchivedClasses(refresh: true);
  }

  String _getImagePath(Classroom classroom) {
    final imageNum = classroom.imageNum.clamp(1, 10);
    return _classroomImages[imageNum] ?? _classroomImages[1]!;
  }

  // ── + button action ──────────────────────────────────────────────
  void _onAddPressed() {
    if (_isInstructor) {
      // Show bottom sheet: Create or Join
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: Colors.white,
        builder: (sheetCtx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'What would you like to do?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _lime.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_circle_outline_rounded,
                        color: Colors.black87, size: 22),
                  ),
                  title: const Text('Create a Class',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: const Text('Set up a new class for your students'),
                  trailing:
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Future.delayed(const Duration(milliseconds: 250), () {
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreateClassroomScreen()),
                      ).then((created) {
                        if (created == true) {
                          _refresh();
                          // Switch to Teaching tab (index 0 for instructors)
                          _tabController.animateTo(0);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      color: Colors.black, size: 18),
                                  SizedBox(width: 10),
                                  Text('Class created!',
                                      style: TextStyle(color: Colors.black)),
                                ],
                              ),
                              backgroundColor: _lime,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      });
                    });
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.login_rounded,
                        color: Colors.black87, size: 22),
                  ),
                  title: const Text('Join a Class',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: const Text('Enter a code to join an existing class'),
                  trailing:
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Future.delayed(const Duration(milliseconds: 250), () {
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const JoinClassroomScreen()),
                      ).then((_) => _refresh());
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    } else {
      // Students go straight to Join
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const JoinClassroomScreen()),
      ).then((_) => _refresh());
    }
  }

  Future<void> _leaveClass(Classroom classroom, String type) async {
    final isTeaching = type == 'teaching';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isTeaching ? 'Delete Class' : 'Leave Class',
          style: const TextStyle(color: Colors.black87),
        ),
        content: Text(
          isTeaching
              ? 'Are you sure you want to delete "${classroom.classTitle}"? This action cannot be undone.'
              : 'Are you sure you want to leave "${classroom.classTitle}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(isTeaching ? 'Delete' : 'Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<ClassroomProvider>();
      await provider.leaveClassroom(classroom.id);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTeaching ? 'Class deleted' : 'Left class'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: _lightBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final provider = context.watch<ClassroomProvider>();
    final teachingClasses = provider.teachingClasses;
    final enrolledClasses = provider.enrolledClasses;
    final archivedClasses = provider.archivedClasses;

    List<Tab> tabs;
    List<Widget> tabChildren;

    if (_isInstructor) {
      tabs = const [
        Tab(text: 'Teaching'),
        Tab(text: 'Enrolled'),
        Tab(text: 'Archived'),
      ];
      tabChildren = [
        _buildClassroomList(teachingClasses, 'teaching'),
        _buildClassroomList(enrolledClasses, 'enrolled'),
        _buildClassroomList(archivedClasses, 'archived'),
      ];
    } else {
      tabs = const [
        Tab(text: 'Enrolled'),
        Tab(text: 'Archived'),
      ];
      tabChildren = [
        _buildClassroomList(enrolledClasses, 'enrolled'),
        _buildClassroomList(archivedClasses, 'archived'),
      ];
    }

    return Scaffold(
      backgroundColor: _lightBg,
      body: Column(
        children: [
          // ── App Bar ───────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.black),
                      onPressed: _onAddPressed,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Tab Bar ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: _lime,
              indicatorWeight: 3,
              labelColor: _lime,
              unselectedLabelColor: Colors.grey,
              tabs: tabs,
            ),
          ),

          // ── Content ──────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: _lime,
              onRefresh: _refresh,
              child: TabBarView(
                controller: _tabController,
                children: tabChildren,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomList(List<Classroom> classes, String type) {
    final provider = Provider.of<ClassroomProvider>(context);

    if (provider.isLoading && classes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (classes.isEmpty) {
      String title, message;
      if (type == 'teaching') {
        title = 'No classes yet';
        message = 'Tap + to create your first class!';
      } else if (type == 'archived') {
        title = 'No archived classes';
        message = 'Archived classes will appear here';
      } else {
        title = 'No enrolled classes';
        message = 'Join a class with a code';
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _lime.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _lime.withOpacity(0.3)),
              ),
              child: Icon(Icons.class_outlined, size: 48, color: _lime),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(color: Colors.grey.shade600)),
            if (type == 'enrolled' || type == 'teaching') ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _onAddPressed,
                icon: const Icon(Icons.add, size: 18, color: Colors.black),
                label: Text(
                  type == 'teaching' ? 'Create Class' : 'Join Class',
                  style: const TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _lime,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final classroom = classes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildClassroomCard(classroom, type),
        );
      },
    );
  }

  Widget _buildClassroomCard(Classroom classroom, String type) {
    final isArchived = type == 'archived';
    final isTeaching = type == 'teaching';
    final imagePath = _getImagePath(classroom);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassroomDetailScreen(
              classroomId: classroom.id,
              classroom: classroom,
              isInstructor: isTeaching,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image header ────────────────────────────────────
            ClipRRect(
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  Image.asset(
                    imagePath,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0077B3),
                              const Color(0xFF0077B3).withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            classroom.classTitle.isNotEmpty
                                ? classroom.classTitle[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                  // Gradient overlay
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                  // Title overlay
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 64,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classroom.classTitle,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          classroom.classSubTitle,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Icon badge
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          classroom.classTitle.isNotEmpty
                              ? classroom.classTitle[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  // Entry code chip (instructors only, not archived)
                  if (isTeaching && !isArchived && classroom.code.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _lime,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.key_rounded,
                                size: 13, color: Colors.black87),
                            const SizedBox(width: 4),
                            Text(
                              classroom.code,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Archived badge
                  if (isArchived)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.archive, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Archived',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Card footer ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _lime.withOpacity(0.2),
                        child: Text(
                          classroom.displayName[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0077B3)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          classroom.displayName,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isTeaching && !isArchived)
                        _buildActionButton(
                          icon: Icons.archive_outlined,
                          label: 'Archive',
                          color: Colors.orange,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Archive feature coming soon!'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                        ),
                      if (!isArchived || (isArchived && isTeaching))
                        _buildActionButton(
                          icon: isTeaching
                              ? Icons.delete_outline
                              : Icons.exit_to_app,
                          label: isTeaching ? 'Delete' : 'Leave',
                          color: Colors.red,
                          onPressed: () => _leaveClass(classroom, type),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label,
          style: TextStyle(
              fontSize: 14, color: color, fontWeight: FontWeight.w500)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}