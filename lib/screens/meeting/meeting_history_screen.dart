import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/jitsi_service.dart';

class _MeetingEntry {
  final String roomName;
  final DateTime joinedAt;
  final Duration? duration;

  const _MeetingEntry({
    required this.roomName,
    required this.joinedAt,
    this.duration,
  });
}

class MeetingHistoryScreen extends StatefulWidget {
  const MeetingHistoryScreen({super.key});

  @override
  State<MeetingHistoryScreen> createState() => _MeetingHistoryScreenState();
}

class _MeetingHistoryScreenState extends State<MeetingHistoryScreen>
    with SingleTickerProviderStateMixin {
  final List<_MeetingEntry> _history = [
    _MeetingEntry(
      roomName: 'cs-lecture-q4',
      joinedAt: DateTime.now().subtract(const Duration(hours: 2)),
      duration: const Duration(minutes: 45),
    ),
    _MeetingEntry(
      roomName: 'unihub-study-group',
      joinedAt: DateTime.now().subtract(const Duration(days: 1)),
      duration: const Duration(minutes: 90),
    ),
    _MeetingEntry(
      roomName: 'math-revision-session',
      joinedAt: DateTime.now().subtract(const Duration(days: 2)),
      duration: const Duration(minutes: 30),
    ),
  ];

  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _brand = Color(0xFF0077B3);
  static const Color _lightBg = Color(0xFFF8FAFB);
  static const Color _cardBg = Colors.white;
  static const Color _border = Color(0xFFE8EDF2);

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '—';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }

  Future<void> _rejoin(_MeetingEntry entry) async {
    final auth = context.read<AuthProvider>();
    await JitsiService.joinMeeting(
      context: context,
      roomName: entry.roomName,
      displayName: auth.userName,
      email: auth.userEmail,
    );
  }

  void _delete(int index) {
    setState(() => _history.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Removed from history'),
        backgroundColor: Colors.grey.shade200,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black54, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: FadeTransition(
          opacity: _headerFade,
          child: const Text(
            'Meeting History',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        actions: [
          if (_history.isNotEmpty)
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Clear history?', style: TextStyle(color: Colors.black87)),
                  content: Text(
                    'This will remove all ${_history.length} entries.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _history.clear());
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
              child: Text('Clear', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ),
        ],
      ),
      body: _history.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _lime.withOpacity(0.1),
              border: Border.all(color: _lime.withOpacity(0.3)),
            ),
            child: Icon(Icons.history_rounded, color: _lime, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'No meeting history yet',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Meetings you join will appear here',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = _history[index];
        return _buildHistoryTile(entry, index);
      },
    );
  }

  Widget _buildHistoryTile(_MeetingEntry entry, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 80),
      curve: Curves.easeOut,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: Dismissible(
        key: Key(entry.roomName + entry.joinedAt.toString()),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _delete(index),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _lime.withOpacity(0.1),
                  border: Border.all(color: _lime.withOpacity(0.3)),
                ),
                child: const Icon(Icons.videocam_rounded, color: _lime, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.roomName,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(entry.joinedAt),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.timer_outlined, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(entry.duration),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _rejoin(entry),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_brand, _lime],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Rejoin',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}