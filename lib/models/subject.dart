class Subject {
  final String id;
  final String name;

  Subject({required this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  static Subject fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'],
      name: map['name'],
    );
  }
}
