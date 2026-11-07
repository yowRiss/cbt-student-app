class UserModel {
  final dynamic id;
  final String name;
  final String email;
  final String? studentNumber;
  final String? studentClass;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.studentNumber,
    this.studentClass,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      studentNumber: json['student_number'],
      studentClass: json['student_class'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'student_number': studentNumber,
    'student_class': studentClass,
  };
}
