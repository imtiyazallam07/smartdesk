import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/subject.dart';
import '../providers/subject_provider.dart';
import '../providers/timetable_provider.dart';


class SubjectManagementScreen extends StatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  State<SubjectManagementScreen> createState() => _SubjectManagementScreenState();
}

class _SubjectManagementScreenState extends State<SubjectManagementScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<SubjectProvider>(context, listen: false).loadSubjects());
  }

  // --- NEW DELETE DIALOG FUNCTION ---
  void _showDeleteConfirmationDialog(BuildContext context, Subject subject) {
    final TextEditingController confirmController = TextEditingController();
    final ValueNotifier<bool> isDeleteEnabled = ValueNotifier(false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Delete ${subject.name}?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This action is destructive and permanent. All data associated with this subject will be removed.",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text("To confirm, please type 'delete' below:"),
              TextField(
                controller: confirmController,
                decoration: const InputDecoration(
                  hintText: "type 'delete' here",
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // Check if the input matches 'delete' (case-insensitive)
                  isDeleteEnabled.value = value.toLowerCase() == 'delete';
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isDeleteEnabled,
              builder: (context, enabled, child) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enabled ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: enabled
                      ? () async {
                          // Show Loading Dialog
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return const AlertDialog(
                                content: Row(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(width: 20),
                                    Text("Deleting subject data..."),
                                  ],
                                ),
                              );
                            },
                          );

                          // Perform Delete
                          await Provider.of<SubjectProvider>(context, listen: false)
                              .deleteSubject(subject.id);
                          
                          // Refresh Timetable to remove cascading deleted slots
                          if (context.mounted) {
                            await Provider.of<TimetableProvider>(context, listen: false)
                                .refreshTimetable();
                          }

                          // Dismiss Loading Dialog (use generic navigator to match showDialog)
                          if (context.mounted) Navigator.of(context).pop();

                          // Dismiss Confirmation Dialog
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      : null, // Button is disabled if text doesn't match
                  child: const Text("DELETE"),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Subjects")),
      body: Consumer<SubjectProvider>(
        builder: (context, provider, child) {
          if (provider.subjects.isEmpty) {
            return const Center(child: Text("No subjects added yet."));
          }
          return ListView.builder(
            itemCount: provider.subjects.length,
            itemBuilder: (context, index) {
              final subject = provider.subjects[index];
              return ListTile(
                title: Text(subject.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  // Updated to call the confirmation dialog
                  onPressed: () => _showDeleteConfirmationDialog(context, subject),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Subject"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter subject name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final subject = Subject(
                  id: const Uuid().v4(),
                  name: controller.text.trim(),
                );
                Provider.of<SubjectProvider>(context, listen: false).addSubject(subject);
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }
}