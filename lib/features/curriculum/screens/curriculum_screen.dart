import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/widgets/web_view_screen.dart';

class CurriculumPage extends StatefulWidget {
  final String jsonUrl;

  const CurriculumPage({
    super.key,
    required this.jsonUrl,
  });

  @override
  State<CurriculumPage> createState() => _CurriculumPageState();
}

class _CurriculumPageState extends State<CurriculumPage> {
  Map<String, dynamic>? data;
  bool offline = false;
  late final String cacheKey;
  
  int? _joiningYear;
  String? _studentBranch;

  @override
  void initState() {
    super.initState();
    cacheKey = "curriculum_${widget.jsonUrl.hashCode}";
    loadData();
  }

  // -------------------------------------------------------------
  // Load cached JSON
  // -------------------------------------------------------------
  Future<Map<String, dynamic>?> loadCachedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw == null) return null;

    return jsonDecode(raw);
  }

  // -------------------------------------------------------------
  // Save JSON to cache
  // -------------------------------------------------------------
  Future<void> saveCachedData(Map<String, dynamic> json) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, jsonEncode(json));
  }

  // -------------------------------------------------------------
  // Load from Internet → Cache → Fallback to Cache
  // -------------------------------------------------------------
  Future<void> loadData() async {
    // Load User Settings First
    final prefs = await SharedPreferences.getInstance();
    _joiningYear = prefs.getInt('joining_year');
    _studentBranch = prefs.getString('student_branch');

    final conn = await Connectivity().checkConnectivity();

    if (conn.contains(ConnectivityResult.none)) {
      final cached = await loadCachedData();
      if (cached != null) {
        setState(() {
          data = cached;
          offline = true;
        });
      } else {
        setState(() {
          data = null;
          offline = true;
        });
      }
      return;
    }
    try {
      final response = await http.get(Uri.parse(widget.jsonUrl));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        await saveCachedData(json);

        setState(() {
          data = json;
          offline = false;
        });
      } else {
        final cached = await loadCachedData();
        if (cached != null) {
          setState(() {
            data = cached;
            offline = true;
          });
        } else {
          setState(() => offline = true);
        }
      }
    } catch (e) {
      final cached = await loadCachedData();
      if (cached != null) {
        setState(() {
          data = cached;
          offline = true;
        });
      } else {
        setState(() => offline = true);
      }
    }
  }



  // -------------------------------------------------------------
  // Tile Builder
  // -------------------------------------------------------------
  Widget buildTile(String title, List list) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              return ListTile(
                title: Text(
                  item["name"],
                  softWrap: true,
                ),
                trailing: const Icon(Icons.open_in_new, color: Colors.blue),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebViewScreen(
                      title: item['name'],
                      url: item["url"],
                    ),
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------

  Widget _buildPersonalizedViewButton() {
    if (data == null) return const SizedBox.shrink();
    
    // Getting user settings from SharedPrefs directly here or extracting from state
    // Ideally we should have loaded it. Let's load it in loadData or use a FutureBuilder
    // For simplicity, let's assume we load it. 
    // Wait, I need to read prefs. I'll read it in async function and store in state.
    
    if (_joiningYear == null || _studentBranch == null) return const SizedBox.shrink();

    // Key format: btech2024
    String key = "btech$_joiningYear";
    
    if (!data!.containsKey(key)) {
       // Fallback for older/newer years not in JSON
       // Maybe try to find closest? Or just hide? 
       // For now, hide if key doesn't exist.
       return const SizedBox.shrink();
    }

    final List list = data![key];
    final personalizedItem = list.firstWhere(
      (item) => item['name'] == _studentBranch,
      orElse: () => null,
    );

    if (personalizedItem == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 2,
          ),
          icon: const Icon(Icons.auto_awesome),
          label: Text(
            "View your ${personalizedItem['name']} Curriculum",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewScreen(
                title: personalizedItem['name'],
                url: personalizedItem["url"],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Curriculum"),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: offline && data == null
            ? Center(
                child: ListView(
                children: [
                  const SizedBox(height: 100),
                  const Center(
                      child:
                          Icon(Icons.wifi_off, size: 60, color: Colors.grey)),
                  const SizedBox(height: 20),
                  const Center(child: Text("No notices available offline.")),
                ],
              ))
            : data == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      // Personalized Button
                      _buildPersonalizedViewButton(),
                      
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          "All Curriculums",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey),
                        ),
                      ),
                      
                      if (data!.containsKey("btech2020"))
                        buildTile(
                            "B.Tech Admission Batch 2020", data!["btech2020"]),
                      if (data!.containsKey("btech2021"))
                        buildTile(
                            "B.Tech Admission Batch 2021", data!["btech2021"]),
                      if (data!.containsKey("btech2022"))
                        buildTile(
                            "B.Tech Admission Batch 2022", data!["btech2022"]),
                      if (data!.containsKey("btech2023"))
                        buildTile(
                            "B.Tech Admission Batch 2023", data!["btech2023"]),
                      if (data!.containsKey("btech2024"))
                        buildTile("B.Tech Admission Batch 2024, 2025 and 2026",
                            data!["btech2024"]),
                      if (data!.containsKey("mca"))
                        buildTile("MCA", data!["mca"]),
                    ],
                  ),
      ),
    );
  }
}
