import 'package:flutter/material.dart';
import '/models/task/task_model.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(TaskStatus) onStatusChange;

  const TaskCard({
    super.key,
    required this.task,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);
  static const Color _cardBg = Colors.white;

  String _formatDate(DateTime? date) {
    if (date == null) return 'No date';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isOverdue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? _lime.withOpacity(0.08) : _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? Colors.red.withOpacity(0.3)
              : (isSelected ? _lime.withOpacity(0.5) : Colors.grey.shade200),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: onSelect,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with checkbox, title, and actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onSelect,
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? _lime : Colors.grey.shade400,
                            width: 2,
                          ),
                          color: isSelected ? _lime : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: Colors.black)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: task.status == TaskStatus.done
                                  ? Colors.grey.shade400
                                  : Colors.black87,
                              decoration: task.status == TaskStatus.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (task.description != null && task.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                task.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Edit button
                        _iconButton(
                          icon: Icons.edit_outlined,
                          onPressed: onEdit,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        // Delete button
                        _iconButton(
                          icon: Icons.delete_outline,
                          onPressed: onDelete,
                          color: Colors.red.shade400,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Tags row
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildStatusChip(),
                    _buildPriorityChip(),
                    _buildDueDateChip(isOverdue),
                    if (task.startedAt != null)
                      _buildStartedAtChip(),
                  ],
                ),

                if (task.status != TaskStatus.done)
                  const SizedBox(height: 14),

                // Action buttons
                if (task.status != TaskStatus.done)
                  Row(
                    children: [
                      if (task.status == TaskStatus.todo)
                        _actionButton(
                          label: 'Start',
                          icon: Icons.play_arrow,
                          onPressed: () => onStatusChange(TaskStatus.inprogress),
                          color: _lime,
                        ),
                      if (task.status == TaskStatus.inprogress)
                        _actionButton(
                          label: 'Complete',
                          icon: Icons.check,
                          onPressed: () => onStatusChange(TaskStatus.done),
                          color: _lime,
                        ),
                      if (task.status != TaskStatus.todo)
                        const SizedBox(width: 12),
                      if (task.status != TaskStatus.todo)
                        _actionButton(
                          label: 'Reset',
                          icon: Icons.refresh,
                          onPressed: () => onStatusChange(TaskStatus.todo),
                          color: Colors.grey.shade500,
                          isOutline: true,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: task.status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: task.status.color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(task.status.icon, size: 12, color: task.status.color),
          const SizedBox(width: 6),
          Text(
            task.status.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: task.status.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: task.priority.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: task.priority.color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.priority.color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            task.priority.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: task.priority.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateChip(bool isOverdue) {
    final dueColor = isOverdue ? Colors.red : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dueColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dueColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 11, color: dueColor),
          const SizedBox(width: 6),
          Text(
            _formatDate(task.dueDate),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: dueColor,
            ),
          ),
          if (isOverdue) ...[
            const SizedBox(width: 6),
            Text(
              'Overdue',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStartedAtChip() {
    // Changed from blue to a more neutral color
    final startColor = _lime.withOpacity(0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: startColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: startColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 11, color: startColor),
          const SizedBox(width: 6),
          Text(
            'Started ${_formatDate(task.startedAt)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: startColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    bool isOutline = false,
  }) {
    if (isOutline) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: color),
        label: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: Colors.black),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 0,
      ),
    );
  }
}