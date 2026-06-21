import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/jitsi_service.dart';
import '../../services/meeting_service.dart';

class CreateMeetingScreen extends StatefulWidget {
  final String? chatId;
  final String? chatName;

  const CreateMeetingScreen({super.key, this.chatId, this.chatName});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _joinRoomController = TextEditingController();
  final FocusNode _roomFocus = FocusNode();
  final FocusNode _joinFocus = FocusNode();

  bool _isCreating = false;
  bool _isJoining = false;
  bool _joinEnabled = false;

  // Caption rotation
  late AnimationController _captionCtrl;
  int _captionIndex = 0;
  final List<String> _captions = [
    'Your next great idea starts with a conversation.',
    'Face-to-face, wherever you are.',
    'Study together, grow together.',
    'No distance too far for a great lecture.',
    'Click. Connect. Collaborate.',
  ];

  // Floating blob animation
  late AnimationController _blobCtrl;
  late Animation<double> _blobAnim;

  // Icon pulse
  late AnimationController _iconCtrl;
  late Animation<double> _iconAnim;

  // Card slide-in
  late AnimationController _cardCtrl;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  // ── Colors ───────────────────────────────────────────────────────
  static const Color _lime = Color(0xFFB9FF66);
  static const Color _brand = Color(0xFF0077B3);
  static const Color _lightBg = Color(0xFFF8FAFB);
  static const Color _cardBg = Colors.white;
  static const Color _border = Color(0xFFE8EDF2);

  // ── Lifecycle ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _captionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _startCaptionRotation();

    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _blobAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOut),
    );

    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _iconAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.easeInOut),
    );

    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardCtrl, curve: const Interval(0, 0.6)),
    );
    _cardCtrl.forward();

    _joinRoomController.addListener(() {
      final enabled = _joinRoomController.text.trim().isNotEmpty;
      if (enabled != _joinEnabled) setState(() => _joinEnabled = enabled);
    });

    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermission = await MeetingService.checkPermissions();
    if (!hasPermission && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera and microphone permissions will be requested when you start a meeting'),
          backgroundColor: Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _joinRoomController.dispose();
    _roomFocus.dispose();
    _joinFocus.dispose();
    _captionCtrl.dispose();
    _blobCtrl.dispose();
    _iconCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  void _startCaptionRotation() {
    _captionCtrl.forward();
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _captionCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() => _captionIndex = (_captionIndex + 1) % _captions.length);
        _captionCtrl.forward();
      });
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────
  String _slugify(String str) {
    if (str.trim().isEmpty) return MeetingService.generateRoomId();
    return MeetingService.slugify(str);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _copyRoom(String roomName) {
    Clipboard.setData(ClipboardData(text: roomName));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.black, size: 18),
            SizedBox(width: 10),
            Text('Room name copied!', style: TextStyle(color: Colors.black)),
          ],
        ),
        backgroundColor: Colors.grey.shade200,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────
  Future<void> _startNewMeeting() async {
    HapticFeedback.mediumImpact();

    final hasPermission = await MeetingService.requestPermissions();
    if (!hasPermission) {
      _showError('Camera and microphone permissions are required to start a meeting');
      return;
    }

    String roomName = _slugify(_roomNameController.text.trim());
    setState(() => _isCreating = true);

    try {
      final auth = context.read<AuthProvider>();

      await JitsiService.joinMeeting(
        context: context,
        roomName: roomName,
        displayName: auth.userName,
        email: auth.userEmail,
      );
    } catch (e) {
      _showError('Failed to start meeting: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _joinMeeting() async {
    final roomName = _joinRoomController.text.trim();
    if (roomName.isEmpty) {
      _showError('Please enter a room name');
      return;
    }

    HapticFeedback.mediumImpact();

    final hasPermission = await MeetingService.requestPermissions();
    if (!hasPermission) {
      _showError('Camera and microphone permissions are required to join a meeting');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final auth = context.read<AuthProvider>();
      await JitsiService.joinMeeting(
        context: context,
        roomName: _slugify(roomName),
        displayName: auth.userName,
        email: auth.userEmail,
      );
    } catch (e) {
      _showError('Failed to join meeting: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      body: SafeArea(
        child: Stack(
          children: [
            _buildBlobs(),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: SlideTransition(
                  position: _cardSlide,
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 32),
                          _buildCard(),
                          const SizedBox(height: 20),
                          _buildTip(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildBackButton(),
          ],
        ),
      ),
    );
  }

  // ── Back button ───────────────────────────────────────────────────
  Widget _buildBackButton() {
    return Positioned(
      top: 8,
      left: 8,
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black54, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // ── Animated blobs ────────────────────────────────────────────────
  Widget _buildBlobs() {
    return AnimatedBuilder(
      animation: _blobAnim,
      builder: (_, __) {
        final t = _blobAnim.value;
        return Stack(
          children: [
            Positioned(
              top: -80 + t * 30,
              right: -60 + t * 20,
              child: _blob(220, Colors.black.withOpacity(0.06)),
            ),
            Positioned(
              bottom: -60 + (1 - t) * 20,
              left: -60 + t * 15,
              child: _blob(180, Colors.grey.withOpacity(0.05)),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4 + t * 20,
              right: -40,
              child: _blob(120, Colors.black.withOpacity(0.04)),
            ),
          ],
        );
      },
    );
  }

  Widget _blob(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
    ),
  );

  // ── Header ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        ScaleTransition(
          scale: _iconAnim,
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.videocam_rounded, size: 38, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),

        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            children: [
              TextSpan(text: 'UniHub ', style: TextStyle(color: Colors.black87)),
              TextSpan(text: 'Meetings', style: TextStyle(color: Colors.black87)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 22,
          child: FadeTransition(
            opacity: _captionCtrl,
            child: Text(
              _captions[_captionIndex],
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
        ),
      ],
    );
  }

  // ── Main card ─────────────────────────────────────────────────────
  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Room name', '(optional)'),
          const SizedBox(height: 8),
          _roomField(),
          const SizedBox(height: 14),
          _startButton(),
          _divider(),
          _label('Join a meeting', null),
          const SizedBox(height: 8),
          _joinRow(),
        ],
      ),
    );
  }

  Widget _label(String text, String? sub) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(width: 6),
          Text(sub, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _roomField() {
    return TextField(
      controller: _roomNameController,
      focusNode: _roomFocus,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'e.g. cs-lecture-q4',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        filled: true,
        fillColor: _lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: _roomNameController.text.isNotEmpty
            ? IconButton(
          icon: Icon(Icons.content_copy_rounded, color: Colors.grey.shade500, size: 18),
          onPressed: () => _copyRoom(_slugify(_roomNameController.text)),
        )
            : null,
      ),
      onSubmitted: (_) => _startNewMeeting(),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _startButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: _isCreating ? null : _startNewMeeting,
          style: ElevatedButton.styleFrom(
            backgroundColor: _lime,  // LIME color
            foregroundColor: Colors.black,
            disabledBackgroundColor: _lime.withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isCreating
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.black.withOpacity(0.6),
            ),
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                'Start New Meeting',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: _border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'or join with a room name',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          Expanded(child: Container(height: 1, color: _border)),
        ],
      ),
    );
  }

  Widget _joinRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _joinRoomController,
            focusNode: _joinFocus,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter room name…',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              filled: true,
              fillColor: _lightBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) {
              if (_joinEnabled) _joinMeeting();
            },
          ),
        ),
        const SizedBox(width: 10),
        AnimatedOpacity(
          opacity: _joinEnabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: (_joinEnabled && !_isJoining) ? _joinMeeting : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _lime,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isJoining
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
                  : const Text('Join', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tip ───────────────────────────────────────────────────────────
  Widget _buildTip() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          'Share the room name so classmates can join instantly',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }
}