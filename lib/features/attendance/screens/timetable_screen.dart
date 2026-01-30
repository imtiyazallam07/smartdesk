import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable.dart';
import '../providers/subject_provider.dart';
import 'subject_management_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    // Initial fetch
    Future.microtask(() {
      if (mounted) {
        Provider.of<TimetableProvider>(context, listen: false).init();
        Provider.of<SubjectProvider>(context, listen: false).loadSubjects();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Timetable"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: _days.map((day) => Tab(text: day)).toList(),
          indicatorColor: Colors.blue,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(6, (index) => _buildDaySchedule(index + 1)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.book, color: Colors.blue),
                title: const Text("Add Subject"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubjectManagementScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.green),
                title: const Text("Add Time Table"),
                onTap: () {
                  Navigator.pop(context);
                  _showEditSlotDialog(context, dayOfWeek: _tabController.index + 1);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDaySchedule(int dayOfWeek) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final schedule = provider.getScheduleForDay(dayOfWeek);
        final slots = schedule?.slots ?? [];

        if (slots.isEmpty) {
          return const Center(
            child: Text(
              "No classes scheduled",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.class_outlined, color: Colors.blue),
                ),
                title: Text(
                  slot.subjectName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  slot.timeString,
                  style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditSlotDialog(context, dayOfWeek: dayOfWeek, slot: slot);
                    } else if (value == 'delete') {
                      _confirmDelete(context, slot);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, TimeSlot slot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Class?"),
        content: Text("Are you sure you want to delete '${slot.subjectName}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Provider.of<TimetableProvider>(context, listen: false).deleteSlot(slot.id);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditSlotDialog(BuildContext context, {required int dayOfWeek, TimeSlot? slot}) {
    final subProvider = Provider.of<SubjectProvider>(context, listen: false);
    final subjects = subProvider.subjects;

    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add subjects first in Manage Subjects."))
      );
      return;
    }

    final isEditing = slot != null;
    
    // Subject Selection
    String selectedSubject = slot?.subjectName ?? subjects.first.name;
    if (isEditing && !subjects.any((s) => s.name == selectedSubject)) {
       selectedSubject = subjects.first.name;
    }

    // Time Selection Logic
    // Valid Start Hours: 8, 9, 10, 11, 12, 14 (2PM), 15, 16, 17
    final List<int> validStartHours = [8, 9, 10, 11, 12, 14, 15, 16, 17];
    
    int selectedStartHour = slot != null ? slot.startTime.hour : 8;
    if (!validStartHours.contains(selectedStartHour)) {
        selectedStartHour = 8; // Reset to default if invalid
    }
    
    int selectedDuration = 1;
    if (slot != null) {
        // Calculate existing duration
        int startMins = slot.startTime.hour * 60 + slot.startTime.minute;
        int endMins = slot.endTime.hour * 60 + slot.endTime.minute;
        int diffHours = (endMins - startMins) ~/ 60;
        selectedDuration = diffHours > 0 ? diffHours : 1;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          
          // Calculate max duration based on start time
          // Morning Session: Ends at 13 (1 PM)
          // Afternoon Session: Ends at 18 (6 PM)
          int maxDuration = 1;
          
          if (selectedStartHour < 13) {
             // Morning: 13 - start
             maxDuration = 13 - selectedStartHour;
          } else {
             // Afternoon: 18 - start
             maxDuration = 18 - selectedStartHour;
          }
          
          // Cap at 3 hours globally per requirement
          if (maxDuration > 3) maxDuration = 3;
          
          // Ensure selected duration is valid
          if (selectedDuration > maxDuration) selectedDuration = maxDuration;
          
          final validDurations = List.generate(maxDuration, (index) => index + 1);

          // Calculate End Time Display
          final endHour = selectedStartHour + selectedDuration;
          final TimeOfDay endTime = TimeOfDay(hour: endHour, minute: 0);
          final TimeOfDay startTime = TimeOfDay(hour: selectedStartHour, minute: 0);

          return AlertDialog(
            title: Text(isEditing ? "Edit Class" : "Add Class"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedSubject,
                  decoration: const InputDecoration(
                    labelText: "Subject",
                    border: OutlineInputBorder(),
                  ),
                  items: subjects.map((s) => DropdownMenuItem(
                    value: s.name, 
                    child: Text(s.name)
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedSubject = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text("Time Slot", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedStartHour,
                        decoration: const InputDecoration(
                          labelText: "Start Time",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: validStartHours.map((hour) {
                           final t = TimeOfDay(hour: hour, minute: 0);
                           return DropdownMenuItem(
                             value: hour,
                             child: Text(t.format(context)),
                           );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                                selectedStartHour = val;
                                // Reset duration if needed is handled by next rebuild logic
                                selectedDuration = 1; 
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedDuration,
                        decoration: const InputDecoration(
                          labelText: "Duration",
                          border: OutlineInputBorder(),
                           contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: validDurations.map((d) {
                           return DropdownMenuItem(
                             value: d,
                             child: Text("$d Hr${d > 1 ? 's' : ''}"),
                           );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => selectedDuration = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text("Visual Timeline", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(10, (index) {
                    // Map index 0..9 to hours 8..17
                    int hour = 8 + index;
                    bool isBreak = hour == 13;
                     bool isSelected = !isBreak && 
                                      hour >= selectedStartHour && 
                                      hour < selectedStartHour + selectedDuration;

                    int displayHour = hour > 12 ? hour - 12 : hour;
                    
                    return Expanded(
                      child: InkWell(
                        onTap: isBreak ? null : () {
                            setState(() {
                                // Logic:
                                // 1. If tapped hour < startHour: New Start, Duration 1
                                // 2. If tapped hour == startHour: New Start (No change essentially, ensures selection)
                                // 3. If tapped hour > startHour:
                                //    - Check if valid path (no break in between)
                                //    - Check if duration <= 3
                                //    - If valid, update duration
                                //    - If invalid (break crossing), treat as New Start
                                
                                if (hour < selectedStartHour) {
                                    selectedStartHour = hour;
                                    selectedDuration = 1;
                                } else if (hour == selectedStartHour) {
                                  // Just confirm selection
                                   selectedDuration = 1;
                                } else {
                                    // Tapping ahead
                                    // Check for break crossing
                                    bool crossesBreak = false;
                                    for (int i = selectedStartHour; i <= hour; i++) {
                                        if (i == 13) crossesBreak = true;
                                    }
                                    
                                    if (crossesBreak) {
                                        // Can't span across different sessions -> Treat as new start
                                        selectedStartHour = hour;
                                        selectedDuration = 1;
                                    } else {
                                        // Valid range potential
                                        int newDuration = hour - selectedStartHour + 1;
                                        if (newDuration <= 3) {
                                            selectedDuration = newDuration;
                                        } else {
                                            // Cap at 3 or maybe treat as new start? 
                                            // Let's cap if user taps far, or maybe just set to max (3)
                                            // User request: "8 then 10 -> 8,9,10". That's duration 3.
                                            // If user taps 8 then 12 (5 hours), we probably shouldn't allow.
                                            // Let's reset to new start for clarity if out of bounds
                                            selectedStartHour = hour;
                                            selectedDuration = 1;
                                        }
                                    }
                                }
                            });
                        },
                        child: Column(
                        children: [
                          Text(
                            "$displayHour", 
                            style: const TextStyle(fontSize: 10, color: Colors.grey)
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 28, // Slightly reduced height to look proportionate
                            margin: const EdgeInsets.symmetric(horizontal: 1.0), // Minimal spacing
                            decoration: BoxDecoration(
                              color: isBreak 
                                  ? Colors.grey.withValues(alpha: 0.3)
                                  : isSelected 
                                     ? Theme.of(context).primaryColor 
                                     : Colors.transparent,
                              border: Border.all(
                                color: isBreak ? Colors.transparent : Colors.grey.withValues(alpha: 0.5)
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: isBreak 
                              ? const Icon(Icons.block, size: 14, color: Colors.grey) // Smaller icon
                              : isSelected 
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                        ],
                      ),
                    ));
                  }),
                ),
                const SizedBox(height: 16),
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)
                    ),
                    child: Row(
                        children: [
                            Icon(Icons.access_time, size: 20, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                                "${startTime.format(context)} - ${endTime.format(context)}",
                                style: const TextStyle(fontWeight: FontWeight.w500),
                            )
                        ]
                    )
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  final newSlot = TimeSlot(
                    id: slot?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    subjectName: selectedSubject,
                    startTimeHour: startTime.hour,
                    startTimeMinute: startTime.minute,
                    endTimeHour: endTime.hour,
                    endTimeMinute: endTime.minute,
                  );

                  final provider = Provider.of<TimetableProvider>(context, listen: false);
                  if (isEditing) {
                    provider.updateSlot(dayOfWeek, newSlot);
                  } else {
                    provider.addSlot(dayOfWeek, newSlot);
                  }

                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          );
        }
      ),
    );
  }


}
