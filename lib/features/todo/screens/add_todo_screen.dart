import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../main.dart'; // To access global services/plugins if needed, or we'll fix injection later
import '../models/todo_model.dart';
import '../services/todo_db_helper.dart';
import '../services/todo_notification_service.dart';
import '../services/calendar_sync_service.dart';


class AddTodoScreen extends StatefulWidget {
  final RecurringTask? recurringTask;
  final OneTimeTask? oneTimeTask;

  const AddTodoScreen({
    super.key,
    this.recurringTask,
    this.oneTimeTask,
  });

  @override
  State<AddTodoScreen> createState() => _AddTodoScreenState();
}

class _AddTodoScreenState extends State<AddTodoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Common
  final TextEditingController _titleController = TextEditingController();
  bool _isNotificationEnabled = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);

  // Tab 1: Recurring
  int _repeatType = 0; // 0: Working days, 1: Specific days, 2: Interval
  final Set<int> _selectedDays = {}; // 1=Mon, 7=Sun
  final TextEditingController _intervalController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isPriority = false;

  // Tab 2: One-Time
  DateTime? _deadline;
  final TextEditingController _remindInDaysController = TextEditingController();

  late TodoNotificationService _notificationService;
  late CalendarSyncService _calendarService;


  @override
  void initState() {
    super.initState();
    // Ideally inject this, but for now grab from global or new instance
    _notificationService = TodoNotificationService(flutterLocalNotificationsPlugin);
    _calendarService = CalendarSyncService();

    
    _tabController = TabController(length: 2, vsync: this);
    _fromDate = DateTime.now().add(const Duration(days: 1)); // Default tomorrow

    // Initialize if Editing
    if (widget.recurringTask != null) {
      _initRecurring(widget.recurringTask!);
    } else if (widget.oneTimeTask != null) {
      _initOneTime(widget.oneTimeTask!);
    }
  }

  void _initRecurring(RecurringTask task) {
    _tabController.index = 0;
    _titleController.text = task.title;
    _repeatType = task.repeatType;
    if (task.repeatDays != null) {
      _selectedDays.addAll(task.repeatDays!.split(',').map(int.parse));
    }
    if (task.intervalDays != null) {
      _intervalController.text = task.intervalDays.toString();
    }
    _fromDate = task.fromDate;
    _toDate = task.toDate;
    _isPriority = task.isPriority;
    _isNotificationEnabled = task.isNotificationEnabled;
    if (task.notificationTime != null) {
      final parts = task.notificationTime!.split(':');
      _notificationTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
  }

  void _initOneTime(OneTimeTask task) {
    _tabController.index = 1;
    _titleController.text = task.title;
    _deadline = task.deadline;
    _isNotificationEnabled = task.isNotificationEnabled;
    if (task.remindInDays != null) {
      _remindInDaysController.text = task.remindInDays.toString();
    }
    if (task.notificationTime != null) {
      final parts = task.notificationTime!.split(':');
      _notificationTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _intervalController.dispose();
    _remindInDaysController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final timeString = '${_notificationTime.hour.toString().padLeft(2, '0')}:${_notificationTime.minute.toString().padLeft(2, '0')}';

    if (_tabController.index == 0) {
      // Recurring Task
      if (_repeatType == 1 && _selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one day')));
        return;
      }
      if (_repeatType == 2 && _intervalController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter number of days interval')));
        return;
      }

      final task = RecurringTask(
        id: widget.recurringTask?.id, // Preserve ID for updates
        title: title,
        repeatType: _repeatType,
        repeatDays: _repeatType == 1 ? _selectedDays.join(',') : null,
        intervalDays: _repeatType == 2 ? int.tryParse(_intervalController.text) : null,
        fromDate: _fromDate,
        toDate: _toDate,
        isPriority: _isPriority,
        isNotificationEnabled: _isNotificationEnabled,
        notificationTime: timeString,
        isActive: true,
      );

      if (widget.recurringTask != null) {
        // UPDATE
        task.calendarEventId = widget.recurringTask!.calendarEventId; // Preserve logic, check diff below
        
        // Calendar logic
        if (_isPriority) {
           final nextDate = _calendarService.getNextInstanceForRecurring(task);
           if (nextDate != null) {
              await _calendarService.removeFromCalendar(task.calendarEventId); // Remove old
              final eventId = await _calendarService.addToCalendar(
                title: task.title,
                description: "SmartDesk Reminder: High Priority",
                startTime: nextDate,
                endTime: nextDate.add(const Duration(hours: 1)),
              );
              task.calendarEventId = eventId;
           }
        } else {
           // Priority turned off
           await _calendarService.removeFromCalendar(task.calendarEventId);
           task.calendarEventId = null;
        }

        await TodoDatabaseHelper.instance.updateRecurringTask(task);
        // Reschedule: Cancel old and schedule new
        await _notificationService.cancelRecurringTask(task); 
        await _notificationService.scheduleRecurringTask(task);
      } else {
        // CREATE
        if (_isPriority) {
           final nextDate = _calendarService.getNextInstanceForRecurring(task);
           if (nextDate != null) {
              final eventId = await _calendarService.addToCalendar(
                title: task.title,
                description: "SmartDesk Reminder: High Priority",
                startTime: nextDate,
                endTime: nextDate.add(const Duration(hours: 1)),
              );
              task.calendarEventId = eventId;
           }
        }

        final id = await TodoDatabaseHelper.instance.createRecurringTask(task);
        task.id = id;
        await _notificationService.scheduleRecurringTask(task);
      }

    } else {
      // One-Time Task
      if (_deadline == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a deadline')));
        return;
      }

      final task = OneTimeTask(
        id: widget.oneTimeTask?.id, // Preserve ID
        title: title,
        deadline: _deadline,
        isNotificationEnabled: _isNotificationEnabled,
        remindInDays: _remindInDaysController.text.isNotEmpty ? int.tryParse(_remindInDaysController.text) : null,
        notificationTime: timeString,
        isCompleted: widget.oneTimeTask?.isCompleted ?? false,
      );

      if (widget.oneTimeTask != null) {
        // UPDATE
        task.calendarEventId = widget.oneTimeTask!.calendarEventId;

        // Calendar logic
        if (_isPriority) { // Wait, isPriority is not in OneTimeTask model?
          // Re-checking model: OneTimeTask DOES NOT have isPriority field in UI or Model based on previous view_file.
          // The prompt said "add to calendar in reminder screen high priority".
          // But looking at UI code: CheckboxListTile('High Priority') is inside _buildRecurringTab()!
          // It is NOT in _buildDeadlineTab().
          // So High Priority is ONLY for Recurring Tasks currently?
          // I should verify this.
        }
        
        await TodoDatabaseHelper.instance.updateOneTimeTask(task);
        await _notificationService.cancelOneTimeTask(task);
        await _notificationService.scheduleOneTimeTask(task);
      } else {
        // CREATE
        final id = await TodoDatabaseHelper.instance.createOneTimeTask(task);
        task.id = id;
        await _notificationService.scheduleOneTimeTask(task);
      }
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recurringTask != null || widget.oneTimeTask != null 
          ? 'Edit Task' 
          : 'Add Task'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Recurring'),
            Tab(text: 'Deadline'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRecurringTab(),
                  _buildDeadlineTab(),
                ],
              ),
            ),
            const Divider(),
            _buildNotificationSection(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveTask,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save Task'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Repeat', style: TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile<int>(
            title: const Text('Every working day (Mon-Sat)'),
            value: 0,
            // ignore: deprecated_member_use
            groupValue: _repeatType,
            // ignore: deprecated_member_use
            onChanged: (val) => setState(() => _repeatType = val!),
          ),
          RadioListTile<int>(
            title: const Text('Specific days'),
            value: 1,
            // ignore: deprecated_member_use
            groupValue: _repeatType,
            // ignore: deprecated_member_use
            onChanged: (val) => setState(() => _repeatType = val!),
          ),
          if (_repeatType == 1)
            Wrap(
              spacing: 8,
              children: List.generate(7, (index) {
                final day = index + 1;
                final isSelected = _selectedDays.contains(day);
                return ChoiceChip(
                  label: Text(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index]),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }),
            ),
          RadioListTile<int>(
            title: const Text('Every X days'),
            value: 2,
            // ignore: deprecated_member_use
            groupValue: _repeatType,
            // ignore: deprecated_member_use
            onChanged: (val) => setState(() => _repeatType = val!),
          ),
          if (_repeatType == 2)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: TextFormField(
                controller: _intervalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of days'),
              ),
            ),
          const SizedBox(height: 16),
          
          ListTile(
            title: const Text('From Date'),
            subtitle: Text(_fromDate == null ? 'Start Tomorrow' : DateFormat('MMM d, yyyy').format(_fromDate!)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _fromDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (date != null) setState(() => _fromDate = date);
            },
          ),
          ListTile(
            title: const Text('To Date (Optional)'),
            subtitle: Text(_toDate == null ? 'Forever' : DateFormat('MMM d, yyyy').format(_toDate!)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _toDate ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (date != null) setState(() => _toDate = date);
            },
          ),
          CheckboxListTile(
            title: const Text('High Priority'),
            subtitle: const Text('Adds next schedule to calendar/highlights task'),
            value: _isPriority,
            onChanged: (val) => setState(() => _isPriority = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
           ListTile(
            title: const Text('Deadline'),
            subtitle: Text(_deadline == null ? 'Select Date' : DateFormat('MMM d, yyyy').format(_deadline!)),
            trailing: const Icon(Icons.calendar_today),
            tileColor: Colors.grey.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _deadline ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (date != null) setState(() => _deadline = date);
            },
          ),
          const SizedBox(height: 20),
          if (_deadline != null)
             const Text(
               'Notifications will be sent 7 days, 3 days, and 1 day before, and on the deadline day.',
               style: TextStyle(color: Colors.grey),
             ),
        ],
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Allow Notifications'),
          value: _isNotificationEnabled,
          onChanged: _tabController.index == 1 && _deadline == null 
             ? null // Disable if no deadline selected in tab 2? Logic: Enable only if deadline is given for tab 2.
             : (val) => setState(() => _isNotificationEnabled = val!), 
        ),
        if (_isNotificationEnabled) ...[
           // "Field visible only if deadline is mentioned" - applies to Remind In Days
           if (_tabController.index == 1 && _deadline != null)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16),
               child: TextFormField(
                  controller: _remindInDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Remind in how many days (Optional)',
                    helperText: 'Leave empty for standard reminders (7, 3, 1 days before)',
                  ),
               ),
             ),
           ListTile(
             title: const Text('Notification Time'),
             subtitle: Text(_notificationTime.format(context)),
             trailing: const Icon(Icons.access_time),
             onTap: () async {
               final time = await showTimePicker(
                 context: context,
                 initialTime: _notificationTime,
               );
               if (time != null) setState(() => _notificationTime = time);
             },
           ),
        ],
      ],
    );
  }
}
