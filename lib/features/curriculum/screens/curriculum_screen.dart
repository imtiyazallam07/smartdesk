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
                  SizedBox(height: 100),
                  Center(
                      child:
                          Icon(Icons.wifi_off, size: 60, color: Colors.grey)),
                  SizedBox(height: 20),
                  Center(child: Text("No notices available offline.")),
                ],
              ))
            : data == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
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
