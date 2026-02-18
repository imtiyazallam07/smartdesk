import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';

import '../providers/timetable_provider.dart';
import '../models/timetable.dart';
import '../providers/subject_provider.dart';
import '../models/subject.dart';
import 'subject_management_screen.dart';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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

  // --- SERVER IMPORT LOGIC ---

  Future<void> _showServerImportBottomSheet() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.get(Uri.parse('https://smartdesk-backend-timetable.imtiyazallam07.workers.dev/available_timetable.json'));

      if (!mounted) return;
      Navigator.pop(context); // Remove loading dialog

      if (response.statusCode == 200) {
        final Map<String, dynamic> availableData = jsonDecode(response.body);
        final List<String> years = availableData.keys.toList()..sort((a, b) => b.compareTo(a));

        String? selectedYear;
        String? selectedSection;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          builder: (context) => StatefulBuilder(
            builder: (context, setSheetState) {
              List<String> sections = selectedYear != null
                  ? List<String>.from(availableData[selectedYear])
                  : [];

              return Padding(
                padding: EdgeInsets.only(
                    left: 20, right: 20, top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 30
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("Import Timetable", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      value: selectedYear,
                      decoration: const InputDecoration(labelText: "Admission Year", border: OutlineInputBorder()),
                      items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                      onChanged: (val) {
                        setSheetState(() {
                          selectedYear = val;
                          selectedSection = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: selectedSection,
                      decoration: const InputDecoration(labelText: "Section", border: OutlineInputBorder()),
                      disabledHint: const Text("Select year first"),
                      items: sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: selectedYear == null ? null : (val) {
                        setSheetState(() => selectedSection = val);
                      },
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: selectedSection == null ? null : () {
                        Navigator.pop(context);
                        _fetchTimetableFromServer(selectedSection!);
                      },
                      child: const Text("Import Timetable"),
                    ),

                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => _showMissingTimetableDialog(),
                        child: const Text(
                          "Your timetable not available in list?",
                          style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching list: $e")));
      }
    }
  }

  void _showMissingTimetableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Send Timetable"),
        content: const Text("Send the link to your timetable to us? We will add it to the server."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: 'imtiyazallam07@outlook.com',
                queryParameters: {
                  'subject': 'Missing Timetable Request',
                  'body': 'Hello, my timetable is missing. Here is the link/details: '
                },
              );
              if (await canLaunchUrl(emailLaunchUri)) {
                await launchUrl(emailLaunchUri);
              }
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchTimetableFromServer(String section) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.get(Uri.parse('https://smartdesk-backend-timetable.imtiyazallam07.workers.dev/$section.json'));
      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        await _processImportedData(response.body);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download failed: $e")));
    }
  }

  // --- CORE UI BUILD ---

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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.book, color: Colors.blue),
                title: const Text("Add Subject"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectManagementScreen()));
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
              ListTile(
                leading: const Icon(Icons.cloud_download, color: Colors.orange),
                title: const Text("Import from Server"),
                onTap: () {
                  Navigator.pop(context);
                  _showServerImportBottomSheet();
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
          return const Center(child: Text("No classes scheduled", style: TextStyle(color: Colors.grey, fontSize: 16)));
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
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.class_outlined, color: Colors.blue),
                ),
                title: Text(slot.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(slot.timeString),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _showEditSlotDialog(context, dayOfWeek: dayOfWeek, slot: slot);
                    if (value == 'delete') _confirmDelete(context, slot);
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add subjects first.")));
      return;
    }

    final isEditing = slot != null;
    String selectedSubject = slot?.subjectName ?? subjects.first.name;
    final List<int> validStartHours = [8, 9, 10, 11, 12, 14, 15, 16, 17];
    int selectedStartHour = slot != null ? slot.startTime.hour : 8;
    int selectedDuration = 1;
    if (slot != null) {
      selectedDuration = (slot.endTime.hour - slot.startTime.hour).clamp(1, 3);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          int maxDuration = selectedStartHour < 13 ? 13 - selectedStartHour : 18 - selectedStartHour;
          if (maxDuration > 3) maxDuration = 3;
          if (selectedDuration > maxDuration) selectedDuration = maxDuration;

          final endHour = selectedStartHour + selectedDuration;
          final TimeOfDay startTime = TimeOfDay(hour: selectedStartHour, minute: 0);
          final TimeOfDay endTime = TimeOfDay(hour: endHour, minute: 0);

          return AlertDialog(
            title: Text(isEditing ? "Edit Class" : "Add Class"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSubject,
                    decoration: const InputDecoration(labelText: "Subject", border: OutlineInputBorder()),
                    items: subjects.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
                    onChanged: (val) { if (val != null) setState(() => selectedSubject = val); },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedStartHour,
                          decoration: const InputDecoration(labelText: "Start", border: OutlineInputBorder()),
                          items: validStartHours.map((h) => DropdownMenuItem(value: h, child: Text(TimeOfDay(hour: h, minute: 0).format(context)))).toList(),
                          onChanged: (val) { if (val != null) setState(() => selectedStartHour = val); },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedDuration,
                          decoration: const InputDecoration(labelText: "Duration", border: OutlineInputBorder()),
                          items: List.generate(maxDuration, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text("$d Hr"))).toList(),
                          onChanged: (val) { if (val != null) setState(() => selectedDuration = val); },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("Visual Timeline", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(10, (index) {
                      int hour = 8 + index;
                      bool isBreak = hour == 13;
                      bool isSelected = !isBreak && hour >= selectedStartHour && hour < selectedStartHour + selectedDuration;
                      return Expanded(
                        child: InkWell(
                          onTap: isBreak ? null : () {
                            setState(() {
                              if (hour < selectedStartHour || (hour - selectedStartHour + 1) > 3 || (selectedStartHour < 13 && hour >= 13)) {
                                selectedStartHour = hour;
                                selectedDuration = 1;
                              } else {
                                selectedDuration = hour - selectedStartHour + 1;
                              }
                            });
                          },
                          child: Container(
                            height: 30,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: isBreak ? Colors.grey.withValues(alpha: 0.3) : isSelected ? Colors.blue : Colors.transparent,
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: isBreak ? const Icon(Icons.block, size: 12) : isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  final provider = Provider.of<TimetableProvider>(context, listen: false);
                  final slotData = TimeSlot(
                    id: slot?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    subjectName: selectedSubject,
                    startTimeHour: startTime.hour,
                    startTimeMinute: 0,
                    endTimeHour: endTime.hour,
                    endTimeMinute: 0,
                  );
                  isEditing ? provider.updateSlot(dayOfWeek, slotData) : provider.addSlot(dayOfWeek, slotData);
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- DATA PROCESSING & QR ---

  Future<void> _processImportedData(String qrData) async {
    try {
      final Map<String, dynamic> data = jsonDecode(qrData);
      final subjectProvider = Provider.of<SubjectProvider>(context, listen: false);
      final timetableProvider = Provider.of<TimetableProvider>(context, listen: false);

      final Set<String> allSubjects = {};
      data.forEach((day, slots) { for (var slot in slots as List) { allSubjects.add(slot['n']); } });

      final existingSubjects = subjectProvider.subjects.map((s) => s.name).toSet();
      for (var name in allSubjects) {
        if (!existingSubjects.contains(name)) {
          await subjectProvider.addSubject(Subject(id: DateTime.now().millisecondsSinceEpoch.toString() + name.hashCode.toString(), name: name));
        }
      }

      for (var entry in data.entries) {
        final dayNum = int.tryParse(entry.key);
        if (dayNum == null) continue;
        final existing = timetableProvider.getScheduleForDay(dayNum)?.slots ?? [];
        for (var s in existing) { await timetableProvider.deleteSlot(s.id); }
        for (var slot in entry.value as List) {
          await timetableProvider.addSlot(dayNum, TimeSlot(
            id: DateTime.now().millisecondsSinceEpoch.toString() + slot['n'].hashCode.toString(),
            subjectName: slot['n'],
            startTimeHour: slot['a'],
            startTimeMinute: 0,
            endTimeHour: slot['b'],
            endTimeMinute: 0,
          ));
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Imported successfully!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import Error: $e")));
    }
  }

  void _showQROptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.qr_code), title: const Text("Export QR"), onTap: () { Navigator.pop(context); _exportTimetable(); }),
            ListTile(leading: const Icon(Icons.qr_code_scanner), title: const Text("Import QR"), onTap: () { Navigator.pop(context); _importTimetable(); }),
          ],
        ),
      ),
    );
  }

  void _exportTimetable() async {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    if (provider.timetable.isEmpty) return;
    final Map<String, dynamic> exportData = {};
    provider.timetable.forEach((day, slots) {
      exportData[day.toString()] = slots.map((s) => {'n': s.subjectName, 'a': s.startTimeHour, 'b': s.endTimeHour}).toList();
    });
    final jsonString = jsonEncode(exportData);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Timetable QR"),
        content: SizedBox(width: 250, height: 250, child: QrImageView(data: jsonString, version: QrVersions.auto)),
        actions: [
          TextButton(onPressed: () => _shareQRCode(jsonString), child: const Text("Share")),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  Future<void> _shareQRCode(String data) async {
    final painter = QrPainter(data: data, version: QrVersions.auto, color: Colors.black, emptyColor: Colors.white, gapless: true);
    final pic = await painter.toImageData(1000);
    final temp = await getTemporaryDirectory();
    final file = await File('${temp.path}/qr.png').writeAsBytes(pic!.buffer.asUint8List());
    await Share.shareXFiles([XFile(file.path)]);
  }

  void _importTimetable() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _QRScannerScreen(onScan: (data) { Navigator.pop(context); _processImportedData(data); })));
  }
}

class _QRScannerScreen extends StatelessWidget {
  final Function(String) onScan;
  const _QRScannerScreen({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR")),
      body: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.first;
          if (barcode.rawValue != null) onScan(barcode.rawValue!);
        },
      ),
    );
  }
}