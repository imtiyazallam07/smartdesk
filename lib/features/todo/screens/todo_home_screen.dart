import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../main.dart'; // For flutterLocalNotificationsPlugin
import '../models/todo_model.dart';
import '../services/todo_db_helper.dart';
import '../services/todo_notification_service.dart';
import 'add_todo_screen.dart';

class TodoHomeScreen extends StatefulWidget {
  const TodoHomeScreen({super.key});

  @override
  State<TodoHomeScreen> createState() => _TodoHomeScreenState();
}

class _TodoHomeScreenState extends State<TodoHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TodoNotificationService _notificationService;

  List<RecurringTask> _recurringTasks = [];
  List<OneTimeTask> _oneTimeTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notificationService = TodoNotificationService(
      flutterLocalNotificationsPlugin,
    );
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final recurring = await TodoDatabaseHelper.instance.getRecurringTasks();
    final oneTime = await TodoDatabaseHelper.instance.getOneTimeTasks();

    if (mounted) {
      setState(() {
        _recurringTasks = recurring;
        _oneTimeTasks = oneTime;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tasks and Reminder")),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Repeated'),
                Tab(text: 'Tasks'), // One-Time
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [_buildRecurringList(), _buildOneTimeList()],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTodoScreen()),
          );
          if (result == true) {
            _loadTasks();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRecurringList() {
    if (_recurringTasks.isEmpty) {
      return const Center(child: Text('No recurring tasks. Add one!'));
    }
    return ListView.builder(
      itemCount: _recurringTasks.length,
      itemBuilder: (context, index) {
        final task = _recurringTasks[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          child: ListTile(
            title: Text(
              task.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_getRepeatSummary(task)),
            trailing: Switch(
              value: task.isActive,
              onChanged: (val) async {
                task.isActive = val;
                await TodoDatabaseHelper.instance.updateRecurringTask(task);
                if (val) {
                  await _notificationService.scheduleRecurringTask(task);
                } else {
                  await _notificationService.cancelRecurringTask(task);
                }
                setState(() {});
              },
            ),
            onLongPress: () => _confirmDeleteRecurring(task),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTodoScreen(recurringTask: task),
                ),
              );
              if (result == true) {
                _loadTasks();
              }
            },
          ),
        );
      },
    );
  }

  String _getRepeatSummary(RecurringTask task) {
    if (!task.isNotificationEnabled) return 'Notifications Off';
    if (task.repeatType == 0) {
      return 'Every Working Day @ ${task.notificationTime}';
    }
    if (task.repeatType == 1) {
      return 'Specific Days @ ${task.notificationTime}';
    }
    if (task.repeatType == 2) {
      return 'Every ${task.intervalDays} Days @ ${task.notificationTime}';
    }
    return '';
  }

  Widget _buildOneTimeList() {
    if (_oneTimeTasks.isEmpty) {
      return const Center(child: Text('No tasks pending. Great job!'));
    }
    return ListView.builder(
      itemCount: _oneTimeTasks.length,
      itemBuilder: (context, index) {
        final task = _oneTimeTasks[index];
        final isCompleted = task.isCompleted;
        final isOverdue =
            task.deadline != null &&
            task.deadline!.isBefore(DateTime.now()) &&
            !isCompleted;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //color: isCompleted ? Colors.grey.withOpacity(0.1) : Colors.white,
          elevation: isCompleted ? 0 : 2,
          child: ListTile(
            title: Text(
              task.title,
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            subtitle: task.deadline != null
                ? Text(
                    'Deadline: ${DateFormat('MMM d, yyyy').format(task.deadline!)}',
                    style: TextStyle(
                      color: isOverdue
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isOverdue
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  )
                : null,
            trailing: Checkbox(
              value: isCompleted,
              onChanged: (val) async {
                task.isCompleted = val ?? false;
                await TodoDatabaseHelper.instance.updateOneTimeTask(task);
                if (task.isCompleted) {
                  await _notificationService.cancelOneTimeTask(task);
                } else {
                  await _notificationService.scheduleOneTimeTask(
                    task,
                  ); // Reschedule if unchecked
                }
                _loadTasks(); // Reload to sort/move to bottom
              },
            ),
            onLongPress: () => _confirmDeleteOneTime(task),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTodoScreen(oneTimeTask: task),
                ),
              );
              if (result == true) {
                _loadTasks();
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteRecurring(RecurringTask task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TodoDatabaseHelper.instance.deleteRecurringTask(task.id!);
      await _notificationService.cancelRecurringTask(task);
      _loadTasks();
    }
  }

  Future<void> _confirmDeleteOneTime(OneTimeTask task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TodoDatabaseHelper.instance.deleteOneTimeTask(task.id!);
      await _notificationService.cancelOneTimeTask(task);
      _loadTasks();
    }
  }
}
