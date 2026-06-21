import 'package:flutter/material.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String chatId;
  final bool isInitiator;
  final String callType;
  final String recipientName;

  const CallScreen({
    super.key,
    required this.callId,
    required this.chatId,
    required this.isInitiator,
    required this.callType,
    required this.recipientName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isCallActive = true;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  void _endCall() {
    setState(() => _isCallActive = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0077B3).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.recipientName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isInitiator ? 'Calling...' : 'Incoming call...',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCallButton(
                    icon: Icons.mic,
                    label: 'Mute',
                    isActive: _isMuted,
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                  ),
                  _buildCallButton(
                    icon: Icons.call_end,
                    label: 'End',
                    isActive: true,
                    color: Colors.red,
                    onPressed: _endCall,
                  ),
                  _buildCallButton(
                    icon: Icons.volume_up,
                    label: 'Speaker',
                    isActive: _isSpeakerOn,
                    onPressed: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color ?? (isActive ? const Color(0xFF0077B3) : Colors.grey.shade700),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}