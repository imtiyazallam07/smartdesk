import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../services/database_helper.dart';

class SubjectProvider with ChangeNotifier {
  List<Subject> _subjects = [];
  List<Subject> get subjects => _subjects;

  Future<void> loadSubjects() async {
    _subjects = await DatabaseHelper.instance.getAllSubjects();
    notifyListeners();
  }

  Future<void> addSubject(Subject subject) async {
    await DatabaseHelper.instance.addSubject(subject);
    await loadSubjects();
  }

  Future<void> deleteSubject(String id) async {
    await DatabaseHelper.instance.deleteSubject(id);
    await loadSubjects();
  }
}
