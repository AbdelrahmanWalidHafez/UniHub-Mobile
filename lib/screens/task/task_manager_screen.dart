import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../models/task/task_model.dart';
import '../classroom/widgets/task_form_dialog.dart';
import '../classroom/widgets/task_card.dart';

class TaskManagerScreen extends StatefulWidget {
  // onMenuPressed removed — use back button instead
  const TaskManagerScreen({super.key});

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen> {
  late final ScrollController _scrollController;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTasks());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    await context.read<TaskProvider>().loadTasks(refresh: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<TaskProvider>();
      if (!provider.isLoading && provider.hasMore) {
        provider.loadTasks();
      }
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.black, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.black))),
          ],
        ),
        backgroundColor: _lime,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => TaskFormDialog(
        onSubmit: (request) async {
          final provider = context.read<TaskProvider>();
          final task = await provider.createTask(request);
          if (!mounted) return;
          if (task != null) {
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            _showSuccess('Task "${task.title}" created!');
          } else {
            final errMsg = provider.error ?? 'Failed to create task. Please try again.';
            _showError(errMsg);
            provider.clearError();
          }
        },
      ),
    );
  }

  void _showEditDialog(Task task) {
    showDialog(
      context: context,
      builder: (dialogContext) => TaskFormDialog(
        initialTask: task,
        onSubmit: (request) async {
          final provider = context.read<TaskProvider>();
          final updated = await provider.editTask(task.id, request);
          if (!mounted) return;
          if (updated != null) {
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            _showSuccess('Task updated!');
          } else {
            final errMsg = provider.error ?? 'Failed to update task. Please try again.';
            _showError(errMsg);
            provider.clearError();
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Task', style: TextStyle(color: Colors.black87)),
        content: Text(
          'Are you sure you want to delete "${task.title}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<TaskProvider>();
      final success = await provider.deleteTask(task.id);
      if (success) {
        _showSuccess('Task deleted');
      } else {
        _showError(provider.error ?? 'Failed to delete task');
        provider.clearError();
      }
    }
  }

  Future<void> _confirmBatchDelete(TaskProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Tasks', style: TextStyle(color: Colors.black87)),
        content: Text(
          'Are you sure you want to delete ${provider.selectedCount} tasks?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await provider.deleteSelectedTasks();
      if (success) {
        _showSuccess('Tasks deleted');
      } else {
        _showError(provider.error ?? 'Failed to delete tasks');
        provider.clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = provider.filteredTasks;
    final selectedCount = provider.selectedCount;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFB), Color(0xFFF0F4F8)],
          ),
        ),
        child: Column(
          children: [
            // ── App Bar ────────────────────────────────────────────
            Container(
              color: Colors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      // ← Back button instead of menu
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.black87, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'My Tasks',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showCreateDialog,
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.add, color: Colors.black87, size: 18),
                                  SizedBox(width: 4),
                                  Text(
                                    'Add Task',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  _buildStatsRow(provider),
                  _buildFiltersRow(provider),
                  if (selectedCount > 0) _buildBatchActionsBar(provider, selectedCount),
                  Expanded(
                    child: provider.isLoading && tasks.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : tasks.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                      color: _lime,
                      onRefresh: _loadTasks,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: tasks.length + (provider.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == tasks.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final task = tasks[index];
                          return TaskCard(
                            task: task,
                            isSelected: provider.selectedTaskIds.contains(task.id),
                            onSelect: () => provider.toggleSelection(task.id),
                            onEdit: () => _showEditDialog(task),
                            onDelete: () => _confirmDelete(task),
                            onStatusChange: (status) =>
                                provider.updateTaskStatus(task.id, status),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(TaskProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _statChip(label: 'All', count: provider.totalTasks,
                isActive: provider.statusFilter == null, color: _lime,
                onTap: () => provider.setStatusFilter(null)),
            const SizedBox(width: 8),
            _statChip(label: 'To Do', count: provider.todoCount,
                isActive: provider.statusFilter == TaskStatus.todo,
                color: TaskStatus.todo.color,
                onTap: () => provider.setStatusFilter(
                    provider.statusFilter == TaskStatus.todo ? null : TaskStatus.todo)),
            const SizedBox(width: 8),
            _statChip(label: 'In Progress', count: provider.inProgressCount,
                isActive: provider.statusFilter == TaskStatus.inprogress,
                color: TaskStatus.inprogress.color,
                onTap: () => provider.setStatusFilter(
                    provider.statusFilter == TaskStatus.inprogress ? null : TaskStatus.inprogress)),
            const SizedBox(width: 8),
            _statChip(label: 'Done', count: provider.doneCount,
                isActive: provider.statusFilter == TaskStatus.done,
                color: TaskStatus.done.color,
                onTap: () => provider.setStatusFilter(
                    provider.statusFilter == TaskStatus.done ? null : TaskStatus.done)),
            if (provider.overdueCount > 0) ...[
              const SizedBox(width: 8),
              _statChip(label: 'Overdue', count: provider.overdueCount,
                  isActive: false, color: Colors.red, onTap: () {}),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip({
    required String label, required int count,
    required bool isActive, required Color color, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? color : Colors.grey.shade300,
              width: isActive ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(count.toString(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: isActive ? color : Colors.grey.shade600)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 13,
                    color: isActive ? color : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersRow(TaskProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text('Priority:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 8),
            _filterChip(label: 'All', isActive: provider.priorityFilter == null,
                onTap: () => provider.setPriorityFilter(null)),
            const SizedBox(width: 6),
            _filterChip(label: 'Low', isActive: provider.priorityFilter == TaskPriority.low,
                color: TaskPriority.low.color,
                onTap: () => provider.setPriorityFilter(
                    provider.priorityFilter == TaskPriority.low ? null : TaskPriority.low)),
            const SizedBox(width: 6),
            _filterChip(label: 'Medium', isActive: provider.priorityFilter == TaskPriority.mid,
                color: TaskPriority.mid.color,
                onTap: () => provider.setPriorityFilter(
                    provider.priorityFilter == TaskPriority.mid ? null : TaskPriority.mid)),
            const SizedBox(width: 6),
            _filterChip(label: 'High', isActive: provider.priorityFilter == TaskPriority.high,
                color: TaskPriority.high.color,
                onTap: () => provider.setPriorityFilter(
                    provider.priorityFilter == TaskPriority.high ? null : TaskPriority.high)),
            const SizedBox(width: 16),
            Container(width: 1, height: 20, color: Colors.grey.shade300),
            const SizedBox(width: 16),
            const Text('Sort by due date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 8),
            _filterChip(label: '↑ Earliest', isActive: provider.sortOrder == 'asc',
                onTap: () => provider.setSortOrder(provider.sortOrder == 'asc' ? 'none' : 'asc')),
            const SizedBox(width: 6),
            _filterChip(label: '↓ Latest', isActive: provider.sortOrder == 'desc',
                onTap: () => provider.setSortOrder(provider.sortOrder == 'desc' ? 'none' : 'desc')),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label, required bool isActive,
    Color? color, required VoidCallback onTap,
  }) {
    final activeColor = color ?? _lime;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isActive ? activeColor : Colors.grey.shade300,
              width: isActive ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null && isActive)
              Container(
                width: 6, height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: activeColor),
              ),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? activeColor : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchActionsBar(TaskProvider provider, int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _lime.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lime.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text('$count selected',
              style: TextStyle(color: _lime, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton(
            onPressed: () => provider.clearSelection(),
            child: Text('Clear', style: TextStyle(color: Colors.grey.shade500)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _confirmBatchDelete(provider),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _lime.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _lime.withOpacity(0.3)),
            ),
            child: Icon(Icons.task_alt, size: 48, color: _lime),
          ),
          const SizedBox(height: 24),
          const Text('No tasks yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Tap "Add Task" to create your first task',
              style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}