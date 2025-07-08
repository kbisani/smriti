class MainUser {
  final String id;
  final String name;
  final String avatarPath;
  final DateTime createdAt;

  MainUser({
    required this.id,
    required this.name,
    required this.avatarPath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarPath': avatarPath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MainUser.fromJson(Map<String, dynamic> json) => MainUser(
    id: json['id'],
    name: json['name'],
    avatarPath: json['avatarPath'],
    createdAt: DateTime.parse(json['createdAt']),
  );
} 