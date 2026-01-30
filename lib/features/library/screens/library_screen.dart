import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../main.dart'; // For flutterLocalNotificationsPlugin
import '../models/book.dart';
import '../services/library_database_helper.dart';
import 'scanner_screen.dart';

// ---------------------------------------------------------
// NOTIFICATION SERVICE FOR LIBRARY
// ---------------------------------------------------------
class LibraryNotificationService {
  static const String channelId = 'library_deadlines';
  static const String channelName = 'Library Deadlines';

  static Future<void> scheduleBookNotifications(Book book) async {
    if (book.id == null) return;

    final DateTime returnDate = DateTime.parse(book.returnDate);
    final int bookId = book.id!;
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    final Map<int, int> triggers = {
      7: bookId * 10 + 0, // 7 days before
      3: bookId * 10 + 1, // 3 days before
      1: bookId * 10 + 2, // 1 day before
      0: bookId * 10 + 3, // On the day
    };

    for (var entry in triggers.entries) {
      final int daysBefore = entry.key;
      final int notificationId = entry.value;

      final DateTime triggerDate = returnDate.subtract(Duration(days: daysBefore));

      tz.TZDateTime scheduledTime = tz.TZDateTime(
        tz.local,
        triggerDate.year,
        triggerDate.month,
        triggerDate.day,
        7, 30, // 7:30 AM IST
      );

      if (scheduledTime.isBefore(now)) {
        if (scheduledTime.year == now.year &&
            scheduledTime.month == now.month &&
            scheduledTime.day == now.day) {
          scheduledTime = now.add(const Duration(seconds: 10));
        } else {
          continue;
        }
      }

      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          notificationId,
          daysBefore == 0 ? '📚 Return Book Today!' : '⏰ Book Return Reminder',
          daysBefore == 0
              ? 'Return "${book.title}" to the library today.'
              : '"${book.title}" is due in $daysBefore day${daysBefore > 1 ? 's' : ''}.',
          scheduledTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelName,
              channelDescription: 'Library book return reminders',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        // print("Error scheduling notification: $e");
      }
    }
  }

  static Future<void> cancelBookNotifications(int bookId) async {
    for (int i = 0; i < 4; i++) {
      await flutterLocalNotificationsPlugin.cancel(bookId * 10 + i);
    }
  }
}

class LibraryTrackerScreen extends StatelessWidget {
  const LibraryTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RecordTrackerPage();
  }
}

class RecordTrackerPage extends StatefulWidget {
  const RecordTrackerPage({super.key});

  @override
  State<RecordTrackerPage> createState() => _RecordTrackerPageState();
}

class _RecordTrackerPageState extends State<RecordTrackerPage> {
  List<Book> books = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    refreshBooks();
  }

  Future refreshBooks() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    books = await LibraryDatabaseHelper.instance.readAllBooks();
    if (!mounted) return;
    setState(() => isLoading = false);
  }

  List<Book> get activeBooks => books.where((b) => b.isReturned == 0).toList();
  List<Book> get historyBooks => books.where((b) => b.isReturned == 1).toList();

  String getDaysLeft(String returnDateStr) {
    DateTime deadline = DateTime.parse(returnDateStr);
    DateTime now = DateTime.now();
    DateTime dDate = DateTime(deadline.year, deadline.month, deadline.day);
    DateTime nDate = DateTime(now.year, now.month, now.day);
    int diff = dDate.difference(nDate).inDays;
    if (diff < 0) return "Overdue";
    if (diff == 0) return "Today";
    return "$diff Days Left";
  }

  Color getBadgeColor(String returnDateStr) {
    DateTime deadline = DateTime.parse(returnDateStr);
    DateTime now = DateTime.now();
    int diff = deadline.difference(now).inDays;
    if (diff < 0) return Colors.red.shade900;
    if (diff < 3) return Colors.redAccent;
    if (diff < 7) return Colors.orangeAccent;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("Library Record Tracker", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.blue,
            tabs: [Tab(text: "Current"), Tab(text: "History")],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            _buildBookList(activeBooks, isEmptyMessage: "No books issued."),
            _buildBookList(historyBooks, isEmptyMessage: "No history found."),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showFormBottomSheet(context),
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBookList(List<Book> bookList, {required String isEmptyMessage}) {
    if (bookList.isEmpty) {
      return Center(child: Text(isEmptyMessage, style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookList.length,
      itemBuilder: (context, index) {
        final book = bookList[index];
        return _buildBookCard(book);
      },
    );
  }

  Widget _buildBookCard(Book book) {
    final bool isHistory = book.isReturned == 1;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showOptionsSheet(book);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHistory
              ? (isDark ? const Color(0xFF1F242F) : Colors.grey[200])
              : (isDark ? const Color(0xFF161B22) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: isHistory ? Border.all(color: isDark ? Colors.white12 : Colors.grey[400]!) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    book.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isHistory
                          ? (isDark ? Colors.white54 : Colors.grey[600])
                          : (isDark ? Colors.white : Colors.black87),
                      decoration: isHistory ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isHistory)
                  const Chip(
                    label: Text("Returned", style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.grey, // Adaptive by default somewhat, but simple grey works
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  "Deadline: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(book.returnDate))}",
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                ),
                if (!isHistory) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getBadgeColor(book.returnDate),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      getDaysLeft(book.returnDate),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ]
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: isDark ? Colors.white24 : Colors.grey[300], height: 1),
            ),
            if (book.issueDate != null && book.issueDate!.isNotEmpty)
              _buildDetailRow("Issue Date:", DateFormat('dd/MM/yyyy').format(DateTime.parse(book.issueDate!))),
            if (book.accessionNumber != null && book.accessionNumber!.isNotEmpty)
              _buildDetailRow("Acc. No:", book.accessionNumber!),
            if (book.author != null && book.author!.isNotEmpty)
              _buildDetailRow("Author:", book.author!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color))),
        ],
      ),
    );
  }

  void _showOptionsSheet(Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 15),
              Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text("Edit Details"),
                onTap: () {
                  Navigator.pop(context);
                  _showFormBottomSheet(context, bookToEdit: book);
                },
              ),
              ListTile(
                leading: Icon(book.isReturned == 0 ? Icons.archive : Icons.unarchive, color: Colors.orangeAccent),
                title: Text(book.isReturned == 0 ? "Mark as Returned" : "Mark as Active"),
                subtitle: Text(book.isReturned == 0 ? "Move to history & Stop Alerts" : "Move to current list & Start Alerts"),
                onTap: () async {
                  Navigator.pop(context);
                  final int newStatus = book.isReturned == 0 ? 1 : 0;
                  final updatedBook = book.copy(isReturned: newStatus);
                  await LibraryDatabaseHelper.instance.update(updatedBook);

                  if (newStatus == 1) {
                    if (book.id != null) {
                      await LibraryNotificationService.cancelBookNotifications(book.id!);
                    }
                  } else {
                    if (book.id != null) {
                      await LibraryNotificationService.scheduleBookNotifications(updatedBook);
                    }
                  }

                  refreshBooks();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text("Delete Permanently"),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(book);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        title: const Text("Delete Record?"),
        content: Text("Are you sure you want to permanently delete '${book.title}'? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              if (book.id != null) {
                await LibraryNotificationService.cancelBookNotifications(book.id!);
                await LibraryDatabaseHelper.instance.delete(book.id!);
              }
              refreshBooks();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showFormBottomSheet(BuildContext context, {Book? bookToEdit}) {
    final bool isEditing = bookToEdit != null;
    final titleController = TextEditingController(text: bookToEdit?.title ?? '');
    final accController = TextEditingController(text: bookToEdit?.accessionNumber ?? '');
    final authorController = TextEditingController(text: bookToEdit?.author ?? '');

    DateTime? selectedReturnDate = isEditing ? DateTime.parse(bookToEdit.returnDate) : null;
    DateTime? selectedIssueDate = (isEditing && bookToEdit.issueDate != null) ? DateTime.parse(bookToEdit.issueDate!) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isEditing ? "Update Book Details" : "Add New Book", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildTextField(titleController, "Book Name (Required)"),
                  const SizedBox(height: 10),
                  _buildDatePicker(
                    label: selectedReturnDate == null ? "Select Return Date (Required)" : "Return: ${DateFormat('dd/MM/yyyy').format(selectedReturnDate!)}",
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedReturnDate ?? DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) setSheetState(() => selectedReturnDate = date);
                    },
                    isFilled: selectedReturnDate != null,
                  ),
                  const SizedBox(height: 20),
                  const Text("Optional Details", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  _buildDatePicker(
                    label: selectedIssueDate == null ? "Select Issue Date" : "Issued: ${DateFormat('dd/MM/yyyy').format(selectedIssueDate!)}",
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedIssueDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setSheetState(() => selectedIssueDate = date);
                    },
                    isFilled: selectedIssueDate != null,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    accController,
                    "Accession Number",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                        );
                        if (result != null && result is String) {
                          accController.text = result;
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 10),
                  _buildTextField(authorController, "Author Name"),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: () async {
                        if (titleController.text.isEmpty || selectedReturnDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill required fields")));
                          return;
                        }

                        var bookData = Book(
                          id: bookToEdit?.id,
                          title: titleController.text,
                          returnDate: selectedReturnDate!.toIso8601String(),
                          issueDate: selectedIssueDate?.toIso8601String(),
                          accessionNumber: accController.text,
                          author: authorController.text,
                          isReturned: bookToEdit?.isReturned ?? 0,
                        );

                        if (isEditing) {
                          await LibraryDatabaseHelper.instance.update(bookData);
                          if (bookData.id != null) {
                            await LibraryNotificationService.cancelBookNotifications(bookData.id!);
                            if (bookData.isReturned == 0) {
                              await LibraryNotificationService.scheduleBookNotifications(bookData);
                            }
                          }
                        } else {
                          final int id = await LibraryDatabaseHelper.instance.create(bookData);
                          final newBook = bookData.copy(id: id);
                          if (newBook.isReturned == 0) {
                            await LibraryNotificationService.scheduleBookNotifications(newBook);
                          }
                        }

                        if (context.mounted) Navigator.pop(context);
                        refreshBooks();
                      },
                      child: Text(isEditing ? "Save Changes" : "Add Book", style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {Widget? suffixIcon}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

Widget _buildDatePicker({required String label, required VoidCallback onTap, required bool isFilled}) {
  return Builder(
    builder: (context) {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
            border: isFilled ? Border.all(color: Colors.blue.withValues(alpha: 0.5)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: isFilled ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white38 : Colors.black38))),
              Icon(Icons.calendar_today, size: 18, color: isDark ? Colors.white38 : Colors.black38),
            ],
          ),
        ),
      );
    }
  );
}
