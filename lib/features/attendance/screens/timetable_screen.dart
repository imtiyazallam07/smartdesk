import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable.dart';
import '../providers/subject_provider.dart';
import 'subject_management_screen.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/subject.dart';

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
    int initialIndex = DateTime.now().weekday - 1;
    if (initialIndex >= 6) initialIndex = 0; // Sunday -> Monday
    _tabController = TabController(length: 6, vsync: this, initialIndex: initialIndex);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => _showQROptions(context),
            tooltip: 'Import/Export QR',
          ),
        ],
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

  // QR Code Import/Export Methods
  
  void _showQROptions(BuildContext context) {
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
                leading: const Icon(Icons.qr_code, color: Colors.blue),
                title: const Text("Export as QR Code"),
                subtitle: const Text("Share your timetable"),
                onTap: () {
                  Navigator.pop(context);
                  _exportTimetable();
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner, color: Colors.green),
                title: const Text("Import from QR Code"),
                subtitle: const Text("Scan a timetable QR"),
                onTap: () {
                  Navigator.pop(context);
                  _importTimetable();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _exportTimetable() async {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final timetable = provider.timetable;
    
    if (timetable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No timetable to export")),
      );
      return;
    }

    // Convert to JSON format
    final Map<String, List<Map<String, dynamic>>> exportData = {};
    
    timetable.forEach((day, slots) {
      exportData[day.toString()] = slots.map((slot) {
        return {
          'n': slot.subjectName,
          'a': slot.startTimeHour,
          'b': slot.endTimeHour,
        };
      }).toList();
    });

    final jsonString = jsonEncode(exportData);
    
    // Show QR Code Dialog with Share and Save options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Export Timetable"),
        content: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: QrImageView(
            data: jsonString,
            version: QrVersions.auto,
            size: 260,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await _shareQRCode(jsonString);
            },
            icon: const Icon(Icons.share),
            label: const Text("Share"),
          ),
          TextButton.icon(
            onPressed: () async {
              await _saveQRToGallery(jsonString);
            },
            icon: const Icon(Icons.save),
            label: const Text("Save"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _shareQRCode(String data) async {
    try {
      final image = await _generateQRImage(data);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/timetable_qr.png');
      await file.writeAsBytes(image);
      
      await Share.shareXFiles([XFile(file.path)], text: 'My Timetable QR Code');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Share failed: $e")),
        );
      }
    }
  }

  Future<void> _saveQRToGallery(String data) async {
    try {
      final image = await _generateQRImage(data);
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(image),
        quality: 100,
        name: "timetable_qr_${DateTime.now().millisecondsSinceEpoch}.png",
      );
      
      if (mounted) {
        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("QR code saved to gallery!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to save QR code")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: $e")),
        );
      }
    }
  }

  Future<Uint8List> _generateQRImage(String data) async {
    final qrValidationResult = QrValidator.validate(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.Q,
    );

    if (qrValidationResult.status == QrValidationStatus.valid) {
      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF), // Explicit white for empty modules
        gapless: true,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Increased size and padding for absolute safety
      const double imageSize = 1200.0;
      const double padding = 80.0; // Very large quiet zone
      const double qrSize = imageSize - (padding * 2);
      
      // Fill entire background with opaque white
      canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.dstOver);
      // Double check with a rect fill to be sure
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, imageSize, imageSize), 
        Paint()..color = const Color(0xFFFFFFFF)
      );
      
      canvas.save();
      canvas.translate(padding, padding);
      
      painter.paint(canvas, const Size(qrSize, qrSize));
      
      canvas.restore();
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(imageSize.toInt(), imageSize.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData!.buffer.asUint8List();
    }

    throw Exception('Failed to generate QR code');
  }

  void _importTimetable() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QRScannerScreen(
          onScan: (data) async {
            Navigator.pop(context);
            await _processImportedData(data);
          },
        ),
      ),
    );
  }

  Future<void> _processImportedData(String qrData) async {
    try {
      // Validate JSON format
      final Map<String, dynamic> data = jsonDecode(qrData);
      
      // Validate structure
      bool isValid = true;
      for (var entry in data.entries) {
        // Check if key is a number 1-6
        final dayNum = int.tryParse(entry.key);
        if (dayNum == null || dayNum < 1 || dayNum > 6) {
          isValid = false;
          break;
        }
        
        // Check if value is a list
        if (entry.value is! List) {
          isValid = false;
          break;
        }
        
        // Check each slot has required fields
        for (var slot in entry.value as List) {
          if (slot is! Map || !slot.containsKey('n') || !slot.containsKey('a') || !slot.containsKey('b')) {
            isValid = false;
            break;
          }
        }
      }
      
      if (!isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid QR - Wrong format")),
          );
        }
        return;
      }
      
      final subjectProvider = Provider.of<SubjectProvider>(context, listen: false);
      final timetableProvider = Provider.of<TimetableProvider>(context, listen: false);
      
      // Collect all unique subject names
      final Set<String> allSubjects = {};
      data.forEach((day, slots) {
        for (var slot in slots as List) {
          allSubjects.add(slot['n'] as String);
        }
      });

      // Check and create missing subjects
      final existingSubjects = subjectProvider.subjects.map((s) => s.name).toSet();
      for (var subjectName in allSubjects) {
        if (!existingSubjects.contains(subjectName)) {
          final newSubject = Subject(
            id: DateTime.now().millisecondsSinceEpoch.toString() + subjectName.hashCode.toString(),
            name: subjectName,
          );
          await subjectProvider.addSubject(newSubject);
        }
      }

      // Import slots for each day
      for (var entry in data.entries) {
        final dayOfWeek = int.parse(entry.key);
        final slots = entry.value as List;
        
        // Delete existing slots for this day
        final existingSlots = timetableProvider.getScheduleForDay(dayOfWeek)?.slots ?? [];
        for (var slot in existingSlots) {
          await timetableProvider.deleteSlot(slot.id);
        }
        
        // Add new slots
        for (var slotData in slots) {
          final slot = TimeSlot(
            id: DateTime.now().millisecondsSinceEpoch.toString() + dayOfWeek.toString() + slotData['n'].hashCode.toString(),
            subjectName: slotData['n'],
            startTimeHour: slotData['a'],
            startTimeMinute: 0,
            endTimeHour: slotData['b'],
            endTimeMinute: 0,
          );
          await timetableProvider.addSlot(dayOfWeek, slot);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Timetable imported successfully!")),
        );
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid QR - Not valid JSON")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import failed: $e")),
        );
      }
    }
  }

}

// QR Scanner Screen  
class _QRScannerScreen extends StatefulWidget {
  final Function(String) onScan;
  
  const _QRScannerScreen({required this.onScan});

  @override
  State<_QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<_QRScannerScreen> {
  bool _scanned = false;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return;
      
      // Analyze the image for QR code
      final BarcodeCapture? capture = await _controller.analyzeImage(image.path);
      
      if (capture == null || capture.barcodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No QR found in image")),
          );
        }
        return;
      }
      
      final barcode = capture.barcodes.first;
      if (barcode.rawValue != null) {
        setState(() => _scanned = true);
        widget.onScan(barcode.rawValue!);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No QR found in image")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No QR found in image")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Code"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() => _scanned = true);
                  widget.onScan(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text("Import from Gallery"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
