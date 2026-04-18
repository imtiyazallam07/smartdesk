import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/screens/about_screen.dart';
import '../providers/theme_provider.dart';
import '../services/backup_service.dart';
import 'dart:async';
import '../../attendance/providers/timetable_provider.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../attendance/providers/subject_provider.dart';
import '../../../services/widget_update_service.dart';
import '../../../shared/responsive_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _prefKeyJoiningYear = 'joining_year';
  static const String _prefKeyBranch = 'student_branch';
  int? _selectedYear;
  String? _selectedBranch;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedYear = prefs.getInt(_prefKeyJoiningYear);
      _selectedBranch = prefs.getString(_prefKeyBranch);
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    if (_selectedYear == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyJoiningYear, _selectedYear!);
    if (_selectedBranch != null) {
      await prefs.setString(_prefKeyBranch, _selectedBranch!);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings saved successfully")),
      );
      Navigator.pop(context);
    }
  }

  // Calculate current academic year (e.g., 1st Year, 2nd Year)
  String _calculateAcademicYear() {
    if (_selectedYear == null) return "Unknown";

    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Academic year usually starts in July/August (Month 7 or 8)
    // Formula: (Current - Joining) + (Month >= 7 ? 1 : 0)
    
    int academicYear = (currentYear - _selectedYear!);
    if (currentMonth >= 7) {
      academicYear += 1;
    } 
    
    // Safety check
    if (academicYear <= 0) academicYear = 1;

    // Suffix
    String suffix = "th";
    if (academicYear == 1) {
      suffix = "st";
    } else if (academicYear == 2) {
      suffix = "nd";
    } else if (academicYear == 3) {
      suffix = "rd";
    }

    return "$academicYear$suffix Year";
  }

  List<String> _getBranchesForYear(int year) {
    if (year < 2022) {
      return [
        "Civil Engineering",
        "Computer Science and Engineering",
        "Computer Science and Information Technology",
        "Electrical and Electronics Engineering",
        "Electrical Engineering",
        "Electronics and Communication Engineering",
        "Mechanical Engineering",
      ];
    } else {
      return [
        "Civil Engineering",
        "Computer Science and Engineering",
        "Computer Science and Information Technology",
        "CSE (AI and ML)",
        "CSE (Cybersecurity)",
        "CSE (Data Science)",
        "CSE (IoT)",
        "Electrical and Electronics Engineering",
        "Electrical Engineering",
        "Electronics and Communication Engineering",
        "Mechanical Engineering",
      ];
    }
  }

  List<int> _generateYearOptions() {
    final currentYear = DateTime.now().year;
    // Return [Current, Current-1, ..., Current-4]
    return List.generate(5, (index) => currentYear - index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(rw(context, 20), rw(context, 20), rw(context, 20), rw(context, 32)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // THEME CARD
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(rw(context, 16.0)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "App Appearance",
                            style: TextStyle(fontSize: rw(context, 18), fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: rw(context, 16)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Theme Mode:", style: TextStyle(fontSize: 16)),
                              Consumer<ThemeProvider>(
                                builder: (context, themeProvider, child) {
                                  return DropdownButton<ThemeMode>(
                                    value: themeProvider.themeMode,
                                    underline: Container(),
                                    icon: const Icon(Icons.palette),
                                    items: const [
                                      DropdownMenuItem(
                                        value: ThemeMode.system,
                                        child: Text("System Default"),
                                      ),
                                      DropdownMenuItem(
                                        value: ThemeMode.light,
                                        child: Text("Light Mode"),
                                      ),
                                      DropdownMenuItem(
                                        value: ThemeMode.dark,
                                        child: Text("Dark Mode"),
                                      ),
                                    ],
                                    onChanged: (ThemeMode? newMode) {
                                      if (newMode != null) {
                                        themeProvider.setTheme(newMode);
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),



                  // ACADEMIC PROFILE CARD
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(rw(context, 16.0)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Academic Profile",
                            style: TextStyle(fontSize: rw(context, 18), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          const Text("Select Joining Year:", style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedYear,
                                hint: const Text("Select Year"),
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
                                items: _generateYearOptions().map((year) {
                                  return DropdownMenuItem(
                                    value: year,
                                    child: Text(year.toString()),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedYear = value;
                                    if (_selectedYear != null) {
                                      final branches = _getBranchesForYear(_selectedYear!);
                                      if (_selectedBranch != null && !branches.contains(_selectedBranch)) {
                                        _selectedBranch = null;
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                          ),

                          if (_selectedYear != null) ...[
                            const SizedBox(height: 16),
                            const Text("Select Branch:", style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedBranch,
                                  hint: const Text("Select Branch"),
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down),
                                  items: _getBranchesForYear(_selectedYear!).map((branch) {
                                    return DropdownMenuItem(
                                      value: branch,
                                      child: Text(
                                        branch,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedBranch = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Current Status:", style: TextStyle(fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  _calculateAcademicYear(),
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // DATA BACKUP CARD
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(rw(context, 16.0)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Data Backup",
                            style: TextStyle(fontSize: rw(context, 18), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Export your tasks, timetable, attendance, and library records to a secure file, or restore them.",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.upload_rounded, size: 18),
                                  label: const Text("Export"),
                                  onPressed: () async {
                                    bool success = await BackupService.exportData(context);
                                    if (success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Backup exported successfully")),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: const Text("Import"),
                                  onPressed: () {
                                    _showImportWarningDialog(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // APP INFO CARD
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.info_outline_rounded, color: Colors.blue),
                      title: const Text("App Info & Feedback"),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SAVE BUTTON
                  SizedBox(
                    height: rw(context, 50),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rw(context, 10))),
                      ),
                      onPressed: _selectedYear == null ? null : _saveData,
                      child: Text("Save Settings", style: TextStyle(color: Colors.white, fontSize: rw(context, 16))),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showImportWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const _ImportWarningDialog();
      },
    );
  }
}

class _ImportWarningDialog extends StatefulWidget {
  const _ImportWarningDialog();

  @override
  State<_ImportWarningDialog> createState() => _ImportWarningDialogState();
}

class _ImportWarningDialogState extends State<_ImportWarningDialog> {
  int _countdown = 10;
  Timer? _timer;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _performImport() async {
    setState(() {
      _isImporting = true;
    });

    bool success = await BackupService.importData();

    if (!mounted) return;

    if (success) {
      if (mounted) {
        Provider.of<TimetableProvider>(context, listen: false).refreshTimetable();
        Provider.of<AttendanceProvider>(context, listen: false).loadAll();
        Provider.of<SubjectProvider>(context, listen: false).loadSubjects();
        WidgetUpdateService.updateAllWidgets();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Data restored successfully. Returning to Home."),
        ),
      );
      // Pop dialog
      Navigator.of(context).pop();
      // Pop to home to force refresh
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text("Warning"),
        ],
      ),
      content: const Text(
        "Importing a backup will remove all your current Tasks, Reminders, Attendance, and Library records. This action cannot be undone.\n\nAre you sure you want to proceed?",
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: (_countdown > 0 || _isImporting) ? null : _performImport,
          child: _isImporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(
                  _countdown > 0 ? "Continue ($_countdown)" : "Continue",
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}
