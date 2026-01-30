import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/timetable.dart';
import '../models/attendance.dart';
import '../providers/timetable_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/database_helper.dart';

class DayAttendanceScreen extends StatefulWidget {
  final DateTime date;
  const DayAttendanceScreen({super.key, required this.date});

  @override
  State<DayAttendanceScreen> createState() => _DayAttendanceScreenState();
}

class _DayAttendanceScreenState extends State<DayAttendanceScreen> {
  late AttendanceStatus _status;
  final Map<String, bool> _slotAttendance = {};
  String? _note;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final attProvider = Provider.of<AttendanceProvider>(context, listen: false);
      final existingAttendance = attProvider.getAttendance(widget.date);
      
      if (existingAttendance != null) {
        _status = existingAttendance.status;
        _slotAttendance.addAll(existingAttendance.slotAttendance);
        _note = existingAttendance.note;
      } else {
        _status = AttendanceStatus.notMarked;
      }
      _isInit = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timetableProvider = Provider.of<TimetableProvider>(context);
    int dayOfWeek = widget.date.weekday; 
    final daySchedule = timetableProvider.getScheduleForDay(dayOfWeek);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEEE, MMM d').format(widget.date)),
        actions: [
            TextButton(
                onPressed: _deselectAttendance,
                child: const Text("DESELECT", style: TextStyle(color: Colors.red))
            ),
            TextButton(
                onPressed: _saveAttendance,
                child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold))
            )
        ]
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               _buildStatusSelector(),
               const SizedBox(height: 20),
               if (_status != AttendanceStatus.absent && _status != AttendanceStatus.holiday && _status != AttendanceStatus.weeklyOff && _status != AttendanceStatus.notMarked)
                   _buildSlotList(daySchedule),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSelector() {
      return Card(
          elevation: 0,
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                  children: [
                      const Text("Mark Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Wrap(
                          spacing: 10,
                          children: [
                              _choiceChip(AttendanceStatus.present, "Present", Colors.green),
                              _choiceChip(AttendanceStatus.absent, "Absent", Colors.red),
                              _choiceChip(AttendanceStatus.partial, "Partial", Colors.orange),
                              _choiceChip(AttendanceStatus.holiday, "Holiday", Colors.blue),
                          ]
                      )
                  ]
              )
          )
      );
  }
  
  Widget _choiceChip(AttendanceStatus status, String label, Color color) {
      return ChoiceChip(
          label: Text(label),
          selected: _status == status,
          selectedColor: color.withValues(alpha: 0.2),
          labelStyle: TextStyle(
              color: _status == status ? color : Theme.of(context).colorScheme.onSurface,
          ),
          onSelected: (selected) {
              if (selected) {
                  setState(() {
                      _status = status;
                      
                      // Logic: If Present, check all. If Absent or Holiday, uncheck all.
                      if (status == AttendanceStatus.present) {
                          final timetableProvider = Provider.of<TimetableProvider>(context, listen: false);
                          final daySchedule = timetableProvider.getScheduleForDay(widget.date.weekday);
                          if (daySchedule != null) {
                              for(var slot in daySchedule.slots) {
                                  _slotAttendance[slot.id] = true;
                              }
                          }
                      } else if (status == AttendanceStatus.absent || status == AttendanceStatus.holiday) {
                          final timetableProvider = Provider.of<TimetableProvider>(context, listen: false);
                          final daySchedule = timetableProvider.getScheduleForDay(widget.date.weekday);
                          if (daySchedule != null) {
                              for(var slot in daySchedule.slots) {
                                  _slotAttendance[slot.id] = false;
                              }
                          }
                      }
                  });
              }
          },
      );
  }

  Widget _buildSlotList(DaySchedule? schedule) {
      if (schedule == null || schedule.slots.isEmpty) {
          return const Center(child: Text("No classes scheduled for this day."));
      }
      
      return Column(
          children: [
              const Text("Class Attendance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...schedule.slots.map((slot) {
                  bool isPresent = false;
                  if (_slotAttendance.containsKey(slot.id)) {
                      isPresent = _slotAttendance[slot.id]!;
                  } else {
                       isPresent = (_status == AttendanceStatus.present || _status == AttendanceStatus.partial);
                  }
                  
                  return CheckboxListTile(
                      title: Text(slot.subjectName),
                      subtitle: Text(slot.timeString),
                      value: isPresent,
                      activeColor: Colors.green,
                      onChanged: (val) {
                          setState(() {
                              _slotAttendance[slot.id] = val ?? false;
                              
                              // Recalculate status based on slot selection
                              int pCount = 0;
                              for(var s in schedule.slots) {
                                  if (_slotAttendance[s.id] == true) pCount++;
                              }
                              
                              if (pCount == schedule.slots.length) {
                                  _status = AttendanceStatus.present;
                              } else if (pCount == 0) {
                                  _status = AttendanceStatus.absent;
                              } else {
                                  _status = AttendanceStatus.partial;
                              }
                          });
                      },
                  );
              })
          ]
      );
  }

    void _deselectAttendance() async {
        final attProvider = Provider.of<AttendanceProvider>(context, listen: false);
        await attProvider.deleteAttendance(widget.date);
        
        // Update local state to reflect de-selection
        setState(() {
            _status = AttendanceStatus.notMarked;
            _slotAttendance.clear();
        });
        
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Attendance cleared for this day"))
            );
            Navigator.pop(context);
        }
    }

  void _saveAttendance() {
      final timetableProvider = Provider.of<TimetableProvider>(context, listen: false);
      
      AttendanceStatus finalStatus = _status;
      final Map<String, String> slotSubjects = {};
      
      int dayOfWeek = widget.date.weekday; 
      final daySchedule = timetableProvider.getScheduleForDay(dayOfWeek);
      
      if (daySchedule != null && daySchedule.slots.isNotEmpty) {
           for(var slot in daySchedule.slots) {
               slotSubjects[slot.id] = slot.subjectName;
               
               if (!_slotAttendance.containsKey(slot.id)) {
                   _slotAttendance[slot.id] = (_status == AttendanceStatus.present);
               }
           }
           
           if (_status == AttendanceStatus.partial || _status == AttendanceStatus.present) {
               int pCount = 0; 
               for(var slot in daySchedule.slots) {
                   if (_slotAttendance[slot.id] == true) pCount++;
               }

               if (pCount == daySchedule.slots.length) {
                 finalStatus = AttendanceStatus.present;
               } else if (pCount == 0) {
                 finalStatus = AttendanceStatus.absent;
               } else {
                 finalStatus = AttendanceStatus.partial;
               }
           }
      }
      
      final attendance = DailyAttendance(
          date: widget.date,
          status: finalStatus,
          slotAttendance: _slotAttendance,
          slotSubjects: slotSubjects, 
          note: _note
      );
      
      Provider.of<AttendanceProvider>(context, listen: false).markAttendance(attendance);
      Navigator.pop(context);
  }
}
