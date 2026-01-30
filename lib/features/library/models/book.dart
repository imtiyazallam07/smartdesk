class Book {
  final int? id;
  final String title;
  final String returnDate;
  final String? issueDate;
  final String? accessionNumber;
  final String? author;
  final int isReturned;

  Book({
    this.id,
    required this.title,
    required this.returnDate,
    this.issueDate,
    this.accessionNumber,
    this.author,
    this.isReturned = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'returnDate': returnDate,
      'issueDate': issueDate,
      'accessionNumber': accessionNumber,
      'author': author,
      'isReturned': isReturned,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      returnDate: map['returnDate'],
      issueDate: map['issueDate'],
      accessionNumber: map['accessionNumber'],
      author: map['author'],
      isReturned: map['isReturned'] ?? 0,
    );
  }

  Book copy({
    int? id,
    String? title,
    String? returnDate,
    String? issueDate,
    String? accessionNumber,
    String? author,
    int? isReturned,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      returnDate: returnDate ?? this.returnDate,
      issueDate: issueDate ?? this.issueDate,
      accessionNumber: accessionNumber ?? this.accessionNumber,
      author: author ?? this.author,
      isReturned: isReturned ?? this.isReturned,
    );
  }
}
