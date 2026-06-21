import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/classroom/material_model.dart';
import '../../../providers/classroom_provider.dart';
import '../material_detail_screen.dart';

class ClassroomCalendar extends StatefulWidget {
  final String classroomId;

  const ClassroomCalendar({
    super.key,
    required this.classroomId,
  });

  @override
  State<ClassroomCalendar> createState() => _ClassroomCalendarState();
}

class _ClassroomCalendarState extends State<ClassroomCalendar> {
  DateTime _currentMonth = DateTime.now();
  List<ClassroomMaterial> _assignments = [];
  bool _isLoading = true;
  int _selectedFilter = 0;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAssignments();
    });
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);
    final provider = context.read<ClassroomProvider>();
    await provider.loadAssignments(widget.classroomId, refresh: true);
    setState(() {
      _assignments = provider.assignments;
      _isLoading = false;
    });
  }

  Map<DateTime, List<ClassroomMaterial>> _getAssignmentsByDate() {
    final Map<DateTime, List<ClassroomMaterial>> assignmentsByDate = {};

    for (final assignment in _assignments) {
      final date = assignment.dueDate ?? assignment.createdAt;
      final key = DateTime(date.year, date.month, date.day);

      if (!assignmentsByDate.containsKey(key)) {
        assignmentsByDate[key] = [];
      }
      assignmentsByDate[key]!.add(assignment);
    }

    return assignmentsByDate;
  }

  List<ClassroomMaterial> _getFilteredAssignments() {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case 1: // Upcoming
        return _assignments.where((a) {
          final dueDate = a.dueDate ?? a.createdAt;
          return dueDate.isAfter(now);
        }).toList();
      case 2: // Past Due
        return _assignments.where((a) {
          final dueDate = a.dueDate ?? a.createdAt;
          return dueDate.isBefore(now);
        }).toList();
      default: // All
        return _assignments;
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime.now();
    });
  }

  String _getStatusText(ClassroomMaterial assignment) {
    final now = DateTime.now();
    final dueDate = assignment.dueDate ?? assignment.createdAt;

    if (dueDate.isBefore(now)) {
      return 'Past Due';
    } else if (dueDate.difference(now).inDays <= 3) {
      return 'Due Soon';
    } else {
      return 'Upcoming';
    }
  }

  Color _getStatusColor(ClassroomMaterial assignment) {
    final now = DateTime.now();
    final dueDate = assignment.dueDate ?? assignment.createdAt;

    if (dueDate.isBefore(now)) {
      return Colors.red;
    } else if (dueDate.difference(now).inDays <= 3) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  IconData _getStatusIcon(ClassroomMaterial assignment) {
    final now = DateTime.now();
    final dueDate = assignment.dueDate ?? assignment.createdAt;

    if (dueDate.isBefore(now)) {
      return Icons.warning_amber_rounded;
    } else if (dueDate.difference(now).inDays <= 3) {
      return Icons.schedule;
    } else {
      return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 500,
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
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final assignmentsByDate = _getAssignmentsByDate();
    final filteredAssignments = _getFilteredAssignments();
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday;

    final startOffset = startingWeekday - 1;

    final weekDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    final today = DateTime.now();

    return Container(
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
        children: [
          // Month Selector Header - White background
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white, // White background
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: Colors.black87),
                  onPressed: _previousMonth,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _goToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: _lime, // Lime background for month/year
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: _lime.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _getMonthYearString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: Colors.black87),
                  onPressed: _nextMonth,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Week Days Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                final isWeekend = index == 5 || index == 6;
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isWeekend ? Colors.red.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Calendar Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: List.generate(6, (row) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (col) {
                      final dayNumber = row * 7 + col + 1 - startOffset;
                      final isWeekend = col == 5 || col == 6;

                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            height: 50,
                            child: const SizedBox(),
                          ),
                        );
                      }

                      final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
                      final isToday = date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;
                      final hasAssignment = assignmentsByDate.containsKey(date);

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          height: 55,
                          decoration: BoxDecoration(
                            color: isToday
                                ? _lime
                                : (hasAssignment ? _lime.withOpacity(0.12) : Colors.transparent),
                            borderRadius: BorderRadius.circular(12),
                            border: isToday ? null : Border.all(
                              color: hasAssignment ? _lime.withOpacity(0.4) : Colors.grey.shade200,
                              width: 0.5,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  dayNumber.toString(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    color: isToday ? Colors.black : (isWeekend ? Colors.red.shade400 : Colors.black87),
                                  ),
                                ),
                              ),
                              if (hasAssignment && !isToday)
                                Positioned(
                                  bottom: 6,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: _lime,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),

          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _lime.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: _lime.withOpacity(0.4)),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Assignment', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(width: 20),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _lime,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Today', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _lightBg,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _lime.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  _buildFilterChip('All', 0),
                  _buildFilterChip('Upcoming', 1),
                  _buildFilterChip('Past Due', 2),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Assignments List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assignments (${filteredAssignments.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (filteredAssignments.isNotEmpty)
                  Text(
                    _selectedFilter == 1 ? 'Upcoming' : (_selectedFilter == 2 ? 'Past Due' : 'All'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Assignments List
          if (filteredAssignments.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFilter == 1 ? 'No upcoming assignments' :
                    (_selectedFilter == 2 ? 'No past due assignments' : 'No assignments yet'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredAssignments.length,
              itemBuilder: (context, index) {
                final assignment = filteredAssignments[index];
                return _buildAssignmentCard(assignment);
              },
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _lime : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(ClassroomMaterial assignment) {
    final dueDate = assignment.dueDate ?? assignment.createdAt;
    final status = _getStatusText(assignment);
    final statusColor = _getStatusColor(assignment);
    final statusIcon = _getStatusIcon(assignment);
    final isPastDue = dueDate.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPastDue ? Colors.red.shade200 : _lime.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MaterialDetailScreen(
                  materialId: assignment.id,
                  material: assignment,
                  isInstructor: false,
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        statusIcon,
                        size: 20,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.headLine,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            assignment.materialType.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (assignment.description.isNotEmpty)
                  Text(
                    assignment.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isPastDue ? Colors.red : _lime,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Due: ${_formatDate(dueDate)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isPastDue ? Colors.red : Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _getDaysRemaining(dueDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPastDue ? Colors.red : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Colors.grey.shade400,
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

  String _getDaysRemaining(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference < 0) {
      final daysLate = -difference;
      return '$daysLate day${daysLate != 1 ? 's' : ''} late';
    } else if (difference == 0) {
      return 'Due today';
    } else if (difference == 1) {
      return 'Due tomorrow';
    } else {
      return '$difference days left';
    }
  }

  String _getMonthYearString() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}