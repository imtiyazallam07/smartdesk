import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _prefKeyJoiningYear = 'joining_year';
  int? _selectedYear;
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
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    if (_selectedYear == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyJoiningYear, _selectedYear!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings saved successfully")),
      );
    }
    Navigator.pop(context);
  }

  // Calculate current academic year (e.g., 1st Year, 2nd Year)
  String _calculateAcademicYear() {
    if (_selectedYear == null) return "Unknown";

    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Academic year usually starts in July/August (Month 7 or 8)
    // Formula: (Current - Joining) + (Month >= 7 ? 1 : 0)
    // Example: Joined 2023.
    // June 2024 (Month 6): 2024-2023 = 1. (1st Year)
    // Aug 2024 (Month 8): 2024-2023 = 1. Plus 1 = 2. (2nd Year)
    
    int academicYear = (currentYear - _selectedYear!);
    if (currentMonth >= 7) {
      academicYear += 1;
    } else {
      // If we are in early months (Jan-June), we are still in the academic year started previous calendar year
      // e.g., Joined 2023. Jan 2024. 2024-2023 = 1. Correct (1st Year).
      // e.g., Joined 2023. Jan 2025. 2025-2023 = 2. Correct (2nd Year).
      
      // Edge case: Current year is same as joining year (e.g. Joined 2026, Date Jan 2026?? Unlikely for academic join)
      // If Joined 2026, Date Aug 2026 -> 2026-2026 = 0 + 1 = 1st Year.
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
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // THEME CARD
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "App Appearance",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Theme Mode:", style: TextStyle(fontSize: 16)),
                              Consumer<ThemeProvider>(
                                builder: (context, themeProvider, child) {
                                  return DropdownButton<ThemeMode>(
                                    value: themeProvider.themeMode,
                                    underline: Container(), // Hide default underline
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
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Academic Profile",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                  });
                                },
                              ),
                            ),
                          ),
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
                  const Spacer(),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _selectedYear == null ? null : _saveData,
                      child: const Text("Save Settings", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
