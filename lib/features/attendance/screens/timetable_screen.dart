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
    if (initialIndex >= 6 || initialIndex < 0) initialIndex = 0;
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

  // --- CORE UI ---

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

  // --- EXPORT QR (MATCHING IMAGE DESIGN) ---

  void _exportTimetable() async {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    if (provider.timetable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Timetable is empty")));
      return;
    }

    final Map<String, dynamic> exportData = {};
    provider.timetable.forEach((day, slots) {
      exportData[day.toString()] = slots.map((s) => {'n': s.subjectName, 'a': s.startTimeHour, 'b': s.endTimeHour}).toList();
    });
    final jsonString = jsonEncode(exportData);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: const Color(0xFF1E2124), // Match dark screenshot background
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Export Timetable",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              // White box for QR visibility
              Container(
                padding: const EdgeInsets.all(15), // 15px UI Padding
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: QrImageView(
                    data: jsonString,
                    version: QrVersions.auto,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _btn(Icons.share, "Share", () => _handleAction(jsonString, isShare: true)),
                  _btn(Icons.save_alt, "Save", () => _handleAction(jsonString, isShare: false)),
                  _btn(null, "Close", () => Navigator.pop(context)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(IconData? icon, String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 18, color: Colors.blue.shade300),
          if (icon != null) const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.blue.shade300, fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _handleAction(String data, {required bool isShare}) async {
    try {
      final Uint8List bytes = await _renderQRImage(data);
      if (isShare) {
        final temp = await getTemporaryDirectory();
        final file = await File('${temp.path}/qr.png').writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)]);
      } else {
        final result = await ImageGallerySaver.saveImage(bytes, name: "QR_${DateTime.now().millisecondsSinceEpoch}");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['isSuccess'] ? "Saved!" : "Failed")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<Uint8List> _renderQRImage(String data) async {
    const double size = 1000.0;
    const double padding = 80.0; // Visual 20px padding for high-res output
    const double total = size + (padding * 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, total, total), Paint()..color = Colors.white);

    final painter = QrPainter(data: data, version: QrVersions.auto, color: Colors.black, emptyColor: Colors.white, gapless: true);
    canvas.save();
    canvas.translate(padding, padding);
    painter.paint(canvas, const Size(size, size));
    canvas.restore();

    final img = await recorder.endRecording().toImage(total.toInt(), total.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // --- SLOT MANAGEMENT (FIXED DROPDOWN TYPES) ---

  void _showEditSlotDialog(BuildContext context, {required int dayOfWeek, TimeSlot? slot}) {
    final subjects = Provider.of<SubjectProvider>(context, listen: false).subjects;
    if (subjects.isEmpty) return;

    String selectedSub = slot?.subjectName ?? subjects.first.name;
    int startHr = slot?.startTimeHour ?? 8;
    int duration = slot != null ? (slot.endTimeHour - slot.startTimeHour) : 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(slot == null ? "Add Class" : "Edit Class"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedSub,
                items: subjects.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s.name, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => selectedSub = v!),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  DropdownButton<int>(
                    value: startHr,
                    items: [8, 9, 10, 11, 12, 14, 15, 16, 17].map<DropdownMenuItem<int>>((h) => DropdownMenuItem<int>(value: h, child: Text("$h:00"))).toList(),
                    onChanged: (v) => setState(() => startHr = v!),
                  ),
                  DropdownButton<int>(
                    value: duration,
                    items: [1, 2, 3].map<DropdownMenuItem<int>>((d) => DropdownMenuItem<int>(value: d, child: Text("$d Hr"))).toList(),
                    onChanged: (v) => setState(() => duration = v!),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                final p = Provider.of<TimetableProvider>(context, listen: false);
                final newSlot = TimeSlot(
                  id: slot?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  subjectName: selectedSub,
                  startTimeHour: startHr,
                  startTimeMinute: 0,
                  endTimeHour: startHr + duration,
                  endTimeMinute: 0,
                );
                slot == null ? p.addSlot(dayOfWeek, newSlot) : p.updateSlot(dayOfWeek, newSlot);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  // --- SERVER IMPORT (FIXED DROPDOWN TYPES) ---

  Future<void> _showServerImportBottomSheet() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final res = await http.get(Uri.parse('https://smartdesk-backend-timetable.imtiyazallam07.workers.dev/available_timetable.json'));
      if (!mounted) return;
      Navigator.pop(context);

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List<String> years = data.keys.toList()..sort((a, b) => b.compareTo(a));
        String? selectedYear;
        String? selectedSection;

        showModalBottomSheet(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setSheetState) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    hint: const Text("Admission Year"),
                    value: selectedYear,
                    items: years.map<DropdownMenuItem<String>>((y) => DropdownMenuItem<String>(value: y, child: Text(y))).toList(),
                    onChanged: (val) => setSheetState(() { selectedYear = val; selectedSection = null; }),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    hint: const Text("Section"),
                    value: selectedSection,
                    items: (selectedYear != null ? List<String>.from(data[selectedYear]) : [])
                        .map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setSheetState(() => selectedSection = val),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedSection == null ? null : () {
                        Navigator.pop(context);
                        _fetchTimetableFromServer(selectedSection!);
                      },
                      child: const Text("Import"),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  // --- UTILS & DATA PROCESSING ---

  Future<void> _fetchTimetableFromServer(String section) async {
    try {
      final res = await http.get(Uri.parse('https://smartdesk-backend-timetable.imtiyazallam07.workers.dev/$section.json'));
      if (res.statusCode == 200) await _processImportedData(res.body);
    } catch (_) {}
  }

  Future<void> _processImportedData(String qrData) async {
    try {
      final Map<String, dynamic> data = jsonDecode(qrData);
      final subP = Provider.of<SubjectProvider>(context, listen: false);
      final timeP = Provider.of<TimetableProvider>(context, listen: false);

      for (var entry in data.entries) {
        final dayNum = int.tryParse(entry.key);
        if (dayNum == null) continue;

        // Add missing subjects
        for (var slot in entry.value as List) {
          if (!subP.subjects.any((s) => s.name == slot['n'])) {
            await subP.addSubject(Subject(id: DateTime.now().millisecondsSinceEpoch.toString(), name: slot['n']));
          }
        }

        // Clear existing for that day and add new
        final existing = timeP.getScheduleForDay(dayNum)?.slots ?? [];
        for (var s in existing) await timeP.deleteSlot(s.id);

        for (var slot in entry.value as List) {
          await timeP.addSlot(dayNum, TimeSlot(
            id: DateTime.now().millisecondsSinceEpoch.toString() + slot['n'].hashCode.toString(),
            subjectName: slot['n'],
            startTimeHour: slot['a'],
            startTimeMinute: 0,
            endTimeHour: slot['b'],
            endTimeMinute: 0,
          ));
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Success!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildDaySchedule(int dayOfWeek) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final slots = provider.getScheduleForDay(dayOfWeek)?.slots ?? [];
        if (slots.isEmpty) return const Center(child: Text("Empty Day", style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.class_outlined, color: Colors.blue),
                title: Text(slot.subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(slot.timeString),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => provider.deleteSlot(slot.id),
                ),
                onTap: () => _showEditSlotDialog(context, dayOfWeek: dayOfWeek, slot: slot),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.book, color: Colors.blue,), title: const Text("Manage Subjects"), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectManagementScreen())); }),
            ListTile(leading: const Icon(Icons.add_task, color: Colors.green,), title: const Text("Add Time Slot"), onTap: () { Navigator.pop(context); _showEditSlotDialog(context, dayOfWeek: _tabController.index + 1); }),
            ListTile(leading: const Icon(Icons.cloud_download, color: Colors.amber,), title: const Text("Server Import"), onTap: () { Navigator.pop(context); _showServerImportBottomSheet(); }),
          ],
        ),
      ),
    );
  }

  void _showQROptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.qr_code, color: Colors.blue,), title: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [Text("Export as QR Code"), Text("Share Your timetable", style: TextStyle(fontSize: 12),)],), onTap: () { Navigator.pop(context); _exportTimetable(); }),
            ListTile(leading: const Icon(Icons.qr_code_scanner, color: Colors.green,), title: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [Text("Import from QR Code"), Text("Scan a timetable QR", style: TextStyle(fontSize: 12))],), onTap: () { Navigator.pop(context); _importTimetable(); }),
          ],
        ),
      ),
    );
  }

  void _importTimetable() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _QRScannerScreen(onScan: (d) { Navigator.pop(context); _processImportedData(d); })));
  }
}

class _QRScannerScreen extends StatelessWidget {
  final Function(String) onScan;
  const _QRScannerScreen({required this.onScan});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan")),
      body: MobileScanner(onDetect: (cap) {
        final b = cap.barcodes.first;
        if (b.rawValue != null) onScan(b.rawValue!);
      }),
    );
  }
}