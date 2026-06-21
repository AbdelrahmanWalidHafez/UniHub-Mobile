import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/classroom_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/classroom/classroom_model.dart';
import '../../models/classroom/material_model.dart';
import 'create_material_screen.dart';
import 'material_detail_screen.dart';
import 'widgets/classroom_calendar.dart';

class ClassroomDetailScreen extends StatefulWidget {
  final String classroomId;
  final Classroom classroom;
  final bool isInstructor;

  const ClassroomDetailScreen({
    super.key,
    required this.classroomId,
    required this.classroom,
    required this.isInstructor,
  });

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);

  final List<Color> _avatarColors = [
    Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
    Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
    Colors.teal, Colors.green, Colors.lightGreen,
    Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
    Colors.brown, Colors.grey, Colors.blueGrey,
  ];

  Color _getAvatarColor(String name) {
    final hash = name.hashCode.abs();
    return _avatarColors[hash % _avatarColors.length];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_selectedTab != _tabController.index) {
        setState(() => _selectedTab = _tabController.index);
        _loadTabData();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final provider = context.read<ClassroomProvider>();
    provider.loadMaterials(widget.classroomId, refresh: true);
    provider.loadAssignments(widget.classroomId, refresh: true);
    provider.loadMembers(widget.classroomId, refresh: true);
    provider.loadOwner(widget.classroomId);
  }

  void _loadTabData() {
    final provider = context.read<ClassroomProvider>();
    if (_selectedTab == 0) provider.loadMaterials(widget.classroomId, refresh: true);
    else if (_selectedTab == 1) provider.loadAssignments(widget.classroomId, refresh: true);
    else if (_selectedTab == 3) provider.loadMembers(widget.classroomId, refresh: true);
  }

  Future<void> _refresh() async {
    final provider = context.read<ClassroomProvider>();
    await provider.loadMaterials(widget.classroomId, refresh: true);
    await provider.loadAssignments(widget.classroomId, refresh: true);
    await provider.loadMembers(widget.classroomId, refresh: true);
    await provider.loadOwner(widget.classroomId);
  }

  // ── FAB action (Stream=0, Classwork=1 only) ───────────────────────────────
  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
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
                child: Text('Create', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),
            const Divider(height: 1),
            _sheetTile(
              sheetCtx: sheetCtx,
              icon: Icons.announcement_rounded,
              label: 'Announcement',
              type: ClassroomMaterialType.announcement,
            ),
            _sheetTile(
              sheetCtx: sheetCtx,
              icon: Icons.description_rounded,
              label: 'Material',
              type: ClassroomMaterialType.material,
            ),
            _sheetTile(
              sheetCtx: sheetCtx,
              icon: Icons.assignment_rounded,
              label: 'Assignment',
              type: ClassroomMaterialType.assignment,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile({
    required BuildContext sheetCtx,
    required IconData icon,
    required String label,
    required ClassroomMaterialType type,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _lime.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      onTap: () {
        Navigator.pop(sheetCtx);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateMaterialScreen(
              classroomId: widget.classroomId,
              materialType: type,
            ),
          ),
        ).then((_) => _refresh());
      },
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.classroom.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.black, size: 18),
            SizedBox(width: 10),
            Text('Code copied!', style: TextStyle(color: Colors.black)),
          ],
        ),
        backgroundColor: _lime,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final postDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(postDate).inDays;

    if (difference == 0) {
      int hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final amPm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $amPm';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _openUrl(String url) async {
    String fullUrl = url;
    if (!url.startsWith('http')) {
      const baseUrl = 'http://34.58.11.82:8082';
      fullUrl = url.startsWith('/') ? '$baseUrl$url' : '$baseUrl/$url';
    }
    final Uri uri = Uri.parse(fullUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showUrlOptions(fullUrl);
      }
    } catch (e) {
      _showUrlOptions(fullUrl);
    }
  }

  void _showUrlOptions(String fullUrl) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Cannot open file automatically', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.black),
              title: const Text('Copy URL'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: fullUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL copied'), backgroundColor: Colors.green),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Whether to show FAB ───────────────────────────────────────────────────
  bool get _showFab => widget.isInstructor && (_selectedTab == 0 || _selectedTab == 1);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassroomProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isOwner = provider.owner?.email == authProvider.userEmail;

    return Scaffold(
      backgroundColor: _lightBg,
      // ── FAB replaces the AppBar + button ──────────────────────────
      floatingActionButton: _showFab
          ? FloatingActionButton(
        onPressed: _showCreateMenu,
        backgroundColor: _lime,
        foregroundColor: Colors.black87,
        elevation: 2,
        child: const Icon(Icons.add),
      )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            floating: false,
            // ── Title only — no code chip here anymore ────────────
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.classroom.classTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (widget.classroom.classSubTitle.isNotEmpty)
                  Text(
                    widget.classroom.classSubTitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
            centerTitle: false,
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'leave') _showLeaveDialog();
                  else if (value == 'archive') _showArchiveDialog();
                },
                icon: const Icon(Icons.more_vert, color: Colors.black),
                itemBuilder: (context) => [
                  if (!widget.isInstructor)
                    const PopupMenuItem(
                      value: 'leave',
                      child: Row(children: [
                        Icon(Icons.exit_to_app, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Leave Class', style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  if (widget.isInstructor) ...[
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(children: [
                        Icon(Icons.archive, size: 20, color: Colors.orange),
                        SizedBox(width: 12),
                        Text('Archive Class'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'leave',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete Class', style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ],
              ),
            ],
            // ── Pinned tab bar ────────────────────────────────────
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: _lime,
              indicatorWeight: 3,
              labelColor: _lime,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Stream'),
                Tab(text: 'Classwork'),
                Tab(text: 'Calendar'),
                Tab(text: 'People'),
              ],
            ),
          ),
        ],
        body: RefreshIndicator(
          color: _lime,
          onRefresh: _refresh,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStreamTab(provider),
              _buildClassworkTab(provider),
              _buildCalendarTab(),
              _buildPeopleTab(provider, authProvider),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stream tab ────────────────────────────────────────────────────────────

  Widget _buildStreamTab(ClassroomProvider provider) {
    final materials = provider.materials;

    if (provider.isLoading && materials.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (materials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                child: Icon(Icons.dynamic_feed_rounded, size: 48, color: _lime),
              ),
              const SizedBox(height: 20),
              const Text('Nothing here yet',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 8),
              Text(
                widget.isInstructor
                    ? 'Tap + to post an announcement or assignment'
                    : 'Your teacher hasn\'t posted anything yet',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: materials.length,
      itemBuilder: (context, index) => _buildMaterialCard(materials[index]),
    );
  }

  // ── Classwork tab ─────────────────────────────────────────────────────────

  Widget _buildClassworkTab(ClassroomProvider provider) {
    final assignments = provider.assignments;

    if (provider.isLoading && assignments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (assignments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                child: Icon(Icons.assignment_rounded, size: 48, color: _lime),
              ),
              const SizedBox(height: 20),
              const Text('No assignments yet',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 8),
              Text(
                widget.isInstructor
                    ? 'Tap + to create your first assignment'
                    : 'Assignments will appear here once posted',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: assignments.length,
      itemBuilder: (context, index) =>
          _buildMaterialCard(assignments[index], isAssignment: true),
    );
  }

  // ── Calendar tab ──────────────────────────────────────────────────────────

  Widget _buildCalendarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ClassroomCalendar(classroomId: widget.classroomId),
    );
  }

  // ── Material card ─────────────────────────────────────────────────────────

  Widget _buildMaterialCard(ClassroomMaterial material, {bool isAssignment = false}) {
    final isOverdue = isAssignment &&
        material.dueDate != null &&
        material.dueDate!.isBefore(DateTime.now());

    // Type label pill
    String typeLabel;
    switch (material.materialType) {
      case ClassroomMaterialType.announcement:
        typeLabel = 'Announcement';
        break;
      case ClassroomMaterialType.assignment:
        typeLabel = 'Assignment';
        break;
      default:
        typeLabel = 'Material';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MaterialDetailScreen(
                materialId: material.id,
                material: material,
                isInstructor: widget.isInstructor,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _lime.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(material.materialType.icon, size: 20, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type pill + date on same row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(material.createdAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                            ),
                            if (material.isEdited)
                              Text(
                                ' · edited',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Headline
                        Text(
                          material.headLine,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          material.authorName,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Description
              if (material.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  material.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.45, fontSize: 14),
                ),
              ],

              // Attachments
              if (material.materialUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: material.materialUrls.map((url) {
                    final isPdf = url.toLowerCase().endsWith('.pdf');
                    final isImage = url.toLowerCase().endsWith('.jpg') ||
                        url.toLowerCase().endsWith('.png') ||
                        url.toLowerCase().endsWith('.jpeg');
                    final fileName = url.split('/').last;
                    final displayName = fileName.length > 20
                        ? '${fileName.substring(0, 20)}…'
                        : fileName;
                    return GestureDetector(
                      onTap: () => _openUrl(url),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _lime.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _lime.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPdf ? Icons.picture_as_pdf_rounded
                                  : isImage ? Icons.image_rounded
                                  : Icons.insert_drive_file_rounded,
                              size: 13, color: Colors.black87,
                            ),
                            const SizedBox(width: 5),
                            Text(displayName, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Due date — red if overdue
              if (isAssignment && material.dueDate != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      isOverdue ? Icons.warning_amber_rounded : Icons.calendar_today_rounded,
                      size: 14,
                      color: isOverdue ? Colors.red.shade600 : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOverdue
                          ? 'Overdue · ${_formatDate(material.dueDate!)}'
                          : 'Due ${_formatDate(material.dueDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                        color: isOverdue ? Colors.red.shade600 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],

              // Footer
              const SizedBox(height: 10),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.comment_outlined, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 5),
                  Text(
                    '${material.commentsCount} comment${material.commentsCount != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── People tab ────────────────────────────────────────────────────────────

  Widget _buildPeopleTab(ClassroomProvider provider, AuthProvider authProvider) {
    if (provider.isLoading && provider.members.isEmpty && provider.owner == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Class info card (entry code here now) ────────────────
        if (widget.isInstructor && widget.classroom.code.isNotEmpty) ...[
          GestureDetector(
            onTap: _copyCode,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _lime.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _lime.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _lime.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.key_rounded, size: 18, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Class code', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      Text(
                        widget.classroom.code,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.copy_rounded, size: 18, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
        ],

        // ── Teachers section ─────────────────────────────────────
        const Text('Teachers',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 10),
        if (provider.owner != null)
          _personCard(
            name: provider.owner!.getDisplayName(),
            email: provider.owner!.email,
          ),

        // ── Divider ───────────────────────────────────────────────
        if (provider.members.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Classmates (${provider.members.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              if (provider.hasMoreMembers && !provider.isLoadingMore)
                TextButton(
                  onPressed: () => provider.loadMembers(widget.classroomId),
                  child: Text('Load more', style: TextStyle(color: _lime, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...provider.members.map((member) => _personCard(
            name: member.getDisplayName(),
            email: member.email,
          )),
          if (provider.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ],
    );
  }

  Widget _personCard({required String name, required String email}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _getAvatarColor(name),
            radius: 22,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 2),
                Text(email,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.isInstructor ? 'Delete Class' : 'Leave Class',
          style: const TextStyle(color: Colors.black87),
        ),
        content: Text(
          widget.isInstructor
              ? 'Are you sure you want to delete "${widget.classroom.classTitle}"? This action cannot be undone.'
              : 'Are you sure you want to leave "${widget.classroom.classTitle}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<ClassroomProvider>();
              await provider.leaveClassroom(widget.classroomId);
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(widget.isInstructor ? 'Delete' : 'Leave'),
          ),
        ],
      ),
    );
  }

  void _showArchiveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Archive Class', style: TextStyle(color: Colors.black87)),
        content: Text(
          'Are you sure you want to archive "${widget.classroom.classTitle}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Archive coming soon!'), backgroundColor: Colors.orange),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}