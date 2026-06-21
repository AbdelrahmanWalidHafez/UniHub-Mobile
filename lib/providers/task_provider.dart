import 'package:flutter/material.dart';
import '../models/task/task_model.dart';
import '../services/task_service.dart';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  bool _hasMore = true;
  int _currentPage = 1;

  // Filters
  TaskStatus?  _statusFilter;
  TaskPriority? _priorityFilter;
  String _sortOrder = 'none'; // 'asc', 'desc', 'none'


  final Set<String> _selectedTaskIds = {};

  // ── Getters ────────────────────────────────────────────────────────────────

  List<Task> get tasks => _tasks;

  List<Task> get filteredTasks {
    var filtered = List<Task>.from(_tasks);

    if (_statusFilter != null) {
      filtered = filtered.where((t) => t.status == _statusFilter).toList();
    }
    if (_priorityFilter != null) {
      filtered = filtered.where((t) => t.priority == _priorityFilter).toList();
    }
    if (_sortOrder == 'asc') {
      filtered.sort((a, b) {
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    } else if (_sortOrder == 'desc') {
      filtered.sort((a, b) {
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return b.dueDate!.compareTo(a.dueDate!);
      });
    }
    return filtered;
  }

  Set<String> get selectedTaskIds  => _selectedTaskIds;
  bool        get isLoading        => _isLoading;
  bool        get isLoadingMore    => _isLoadingMore;
  String?     get error            => _error;
  bool        get hasMore          => _hasMore;
  TaskStatus?  get statusFilter    => _statusFilter;
  TaskPriority? get priorityFilter => _priorityFilter;
  String      get sortOrder        => _sortOrder;
  int         get selectedCount    => _selectedTaskIds.length;

  // Stats
  int get totalTasks      => _tasks.length;
  int get todoCount       => _tasks.where((t) => t.status == TaskStatus.todo).length;
  int get inProgressCount => _tasks.where((t) => t.status == TaskStatus.inprogress).length;
  int get doneCount       => _tasks.where((t) => t.status == TaskStatus.done).length;
  int get overdueCount    => _tasks.where((t) => t.isOverdue).length;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadTasks({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _tasks = [];
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    _isLoading    = _tasks.isEmpty;
    _isLoadingMore = !_isLoading && !refresh;
    _error = null;
    notifyListeners();

    try {
      final newTasks = await TaskService.getTasks(pageNum: _currentPage);

      if (refresh) {
        _tasks = newTasks;
      } else {
        _tasks.addAll(newTasks);
      }

      _hasMore = newTasks.isNotEmpty;
      if (newTasks.isNotEmpty) _currentPage++;
    } catch (e) {
      _error = e.toString();
      if (refresh) _tasks = [];
    } finally {
      _isLoading     = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ── Create ─────────────────────────────────────────────────────────────────
  // FIX: Do NOT insert locally before the API call succeeds.
  // Only add the task returned by the server, so a 403/500 never shows a ghost task.

  Future<Task?> createTask(CreateTaskRequest request) async {
    _error = null;
    notifyListeners();

    try {
      final task = await TaskService.createTask(request);
      // Only insert AFTER confirmed success ↓
      _tasks.insert(0, task);
      notifyListeners();
      return task;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;   // caller checks for null to show an error snackbar
    }
  }

  // ── Edit ───────────────────────────────────────────────────────────────────

  Future<Task?> editTask(String taskId, CreateTaskRequest request) async {
    _error = null;
    notifyListeners();

    try {
      final task = await TaskService.editTask(taskId, request);
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) _tasks[index] = task;
      notifyListeners();
      return task;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ── Status ─────────────────────────────────────────────────────────────────

  Future<Task?> updateTaskStatus(String taskId, TaskStatus status) async {
    try {
      final task = await TaskService.setTaskStatus(taskId, status);
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) _tasks[index] = task;
      notifyListeners();
      return task;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<bool> deleteTask(String taskId) async {
    try {
      await TaskService.deleteTask(taskId);
      _tasks.removeWhere((t) => t.id == taskId);
      _selectedTaskIds.remove(taskId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSelectedTasks() async {
    if (_selectedTaskIds.isEmpty) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await TaskService.deleteTasks(_selectedTaskIds.toList());
      _tasks.removeWhere((t) => _selectedTaskIds.contains(t.id));
      _selectedTaskIds.clear();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void toggleSelection(String taskId) {
    if (_selectedTaskIds.contains(taskId)) {
      _selectedTaskIds.remove(taskId);
    } else {
      _selectedTaskIds.add(taskId);
    }
    notifyListeners();
  }

  void toggleSelectAll(List<Task> tasks) {
    if (_selectedTaskIds.length == tasks.length) {
      _selectedTaskIds.clear();
    } else {
      _selectedTaskIds.addAll(tasks.map((t) => t.id));
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedTaskIds.clear();
    notifyListeners();
  }

  // ── Filters ────────────────────────────────────────────────────────────────

  void setStatusFilter(TaskStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setPriorityFilter(TaskPriority? priority) {
    _priorityFilter = priority;
    notifyListeners();
  }

  void setSortOrder(String order) {
    _sortOrder = order;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter   = null;
    _priorityFilter = null;
    _sortOrder      = 'none';
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _tasks = [];
    _selectedTaskIds.clear();
    _statusFilter   = null;
    _priorityFilter = null;
    _sortOrder      = 'none';
    _currentPage    = 1;
    _hasMore        = true;
    _error          = null;
    _isLoading      = false;
    notifyListeners();
  }
}