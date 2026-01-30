import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/timetable.dart';
import '../providers/timetable_provider.dart';
import '../providers/subject_provider.dart';

class TimetableSetupScreen extends StatelessWidget {
  const TimetableSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Timetable")),
      body: Consumer<TimetableProvider>(
        builder: (context, provider, child) {
          return ListView.builder(
            itemCount: 7, 
            itemBuilder: (context, index) {
              int day = index + 1; // 1=Mon
              if (day == 7) return const SizedBox.shrink(); // Skip Sunday per requirement

              final schedule = provider.getScheduleForDay(day);
              final slots = schedule?.slots ?? [];
              
              return ExpansionTile(
                title: Text(_getDayName(day)),
                subtitle: Text("${slots.length} classes"),
                children: [
                    ...slots.map((slot) => ListTile(
                        title: Text(slot.subjectName),
                        subtitle: Text(slot.timeString),
                        trailing: IconButton(
                           icon: const Icon(Icons.delete, color: Colors.grey),
                           onPressed: () => provider.deleteSlot(slot.id),
                        ),
                        onTap: () => _showSlotDialog(context, day, slot: slot),
                    )),
                    ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text("Add Class"),
                        onTap: () => _showSlotDialog(context, day),
                    )
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _getDayName(int day) {
    switch (day) {
      case 1: return "Monday";
      case 2: return "Tuesday";
      case 3: return "Wednesday";
      case 4: return "Thursday";
      case 5: return "Friday";
      case 6: return "Saturday";
      case 7: return "Sunday";
      default: return "";
    }
  }

  void _showSlotDialog(BuildContext context, int day, {TimeSlot? slot}) {
    final subProvider = Provider.of<SubjectProvider>(context, listen: false);
    final subjects = subProvider.subjects;

    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add subjects first."))
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
                                if (hour < selectedStartHour) {
                                    selectedStartHour = hour;
                                    selectedDuration = 1;
                                } else if (hour == selectedStartHour) {
                                   selectedDuration = 1;
                                } else {
                                    // Check for break crossing
                                    bool crossesBreak = false;
                                    for (int i = selectedStartHour; i <= hour; i++) {
                                        if (i == 13) crossesBreak = true;
                                    }
                                    
                                    if (crossesBreak) {
                                        selectedStartHour = hour;
                                        selectedDuration = 1;
                                    } else {
                                        int newDuration = hour - selectedStartHour + 1;
                                        if (newDuration <= 3) {
                                            selectedDuration = newDuration;
                                        } else {
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
                            height: 28,
                            margin: const EdgeInsets.symmetric(horizontal: 1.0),
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
                              ? const Icon(Icons.block, size: 14, color: Colors.grey)
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
                    id: slot?.id ?? const Uuid().v4(),
                    subjectName: selectedSubject,
                    startTimeHour: startTime.hour,
                    startTimeMinute: startTime.minute,
                    endTimeHour: endTime.hour,
                    endTimeMinute: endTime.minute,
                  );

                  final provider = Provider.of<TimetableProvider>(context, listen: false);
                  if (isEditing) {
                    provider.updateSlot(day, newSlot);
                  } else {
                    provider.addSlot(day, newSlot);
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
