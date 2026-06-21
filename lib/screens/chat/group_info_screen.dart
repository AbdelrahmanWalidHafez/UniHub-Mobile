import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';

class GroupInfoScreen extends StatefulWidget {
  final ChatRoom room;

  const GroupInfoScreen({super.key, required this.room});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserEmail = authProvider.userEmail ?? '';

    // FIXED: Use role instead of isAdmin
    final isAdmin = widget.room.participants.any(
          (p) => p.email == currentUserEmail && p.role == ParticipantRole.admin,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Group Info'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF0077B3).withOpacity(0.1),
                  child: Text(
                    (widget.room.name ?? 'G').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0077B3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.room.name ?? 'Group Chat',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Group • ${widget.room.participants.length} members',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Divider(),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text('Edit Group Name'),
              onTap: () => _showEditNameDialog(context),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Members',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ...widget.room.participants.map((participant) => ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF0077B3).withOpacity(0.1),
              child: Text(
                participant.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Color(0xFF0077B3)),
              ),
            ),
            title: Text(participant.displayName),
            subtitle: participant.email == currentUserEmail
                ? const Text('You')
                : null,
            trailing: isAdmin && participant.email != currentUserEmail
                ? IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showRemoveConfirmation(context, participant.email),
            )
                : null,
          )),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Leave Group', style: TextStyle(color: Colors.red)),
            onTap: () => _showLeaveConfirmation(context),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.room.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await context.read<ChatProvider>().updateGroupName(
                  widget.room.id,
                  controller.text.trim(),
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<ChatProvider>().removeParticipant(widget.room.id, email);
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showLeaveConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<ChatProvider>().leaveGroup(widget.room.id);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to chat list
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}