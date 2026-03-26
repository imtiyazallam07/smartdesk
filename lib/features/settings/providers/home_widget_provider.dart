import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user preferences for which home-screen widgets are visible.
class HomeWidgetProvider with ChangeNotifier {
  static const _keyTimetable = 'home_widget_timetable';
  static const _keyTasks = 'home_widget_tasks';
  static const _keyBooks = 'home_widget_books';

  bool _showTimetable = true;
  bool _showTasks = true;
  bool _showBooks = true;

  bool get showTimetable => _showTimetable;
  bool get showTasks => _showTasks;
  bool get showBooks => _showBooks;

  HomeWidgetProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _showTimetable = prefs.getBool(_keyTimetable) ?? true;
    _showTasks = prefs.getBool(_keyTasks) ?? true;
    _showBooks = prefs.getBool(_keyBooks) ?? true;
    notifyListeners();
  }

  Future<void> setShowTimetable(bool value) async {
    _showTimetable = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTimetable, value);
  }

  Future<void> setShowTasks(bool value) async {
    _showTasks = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTasks, value);
  }

  Future<void> setShowBooks(bool value) async {
    _showBooks = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBooks, value);
  }
}
