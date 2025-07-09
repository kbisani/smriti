class SubUserProfile {
  final String id;
  final String name;
  final String initials;
  final String relation;
  final String? profileImageUrl;
  final String languagePreference;

  final String? bio;
  final DateTime? birthDate;
  final String? birthPlace;
  final List<String>? tags;

  final DateTime createdAt;
  final DateTime? lastInteractionAt;
  final bool archived;

  SubUserProfile({
    required this.id,
    required this.name,
    required this.initials,
    required this.relation,
    this.profileImageUrl,
    required this.languagePreference,
    this.bio,
    this.birthDate,
    this.birthPlace,
    this.tags,
    required this.createdAt,
    this.lastInteractionAt,
    this.archived = false,
  });

  SubUserProfile copyWith({
    String? id,
    String? name,
    String? initials,
    String? relation,
    String? profileImageUrl,
    String? languagePreference,
    String? bio,
    DateTime? birthDate,
    String? birthPlace,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? lastInteractionAt,
    bool? archived,
  }) {
    return SubUserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      initials: initials ?? this.initials,
      relation: relation ?? this.relation,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      languagePreference: languagePreference ?? this.languagePreference,
      bio: bio ?? this.bio,
      birthDate: birthDate ?? this.birthDate,
      birthPlace: birthPlace ?? this.birthPlace,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'initials': initials,
    'relation': relation,
    'profileImageUrl': profileImageUrl,
    'languagePreference': languagePreference,
    'bio': bio,
    'birthDate': birthDate?.toIso8601String(),
    'birthPlace': birthPlace,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
    'lastInteractionAt': lastInteractionAt?.toIso8601String(),
    'archived': archived,
  };

  factory SubUserProfile.fromJson(Map<String, dynamic> json) => SubUserProfile(
    id: json['id'],
    name: json['name'],
    initials: json['initials'],
    relation: json['relation'],
    profileImageUrl: json['profileImageUrl'],
    languagePreference: json['languagePreference'],
    bio: json['bio'],
    birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
    birthPlace: json['birthPlace'],
    tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
    createdAt: DateTime.parse(json['createdAt']),
    lastInteractionAt: json['lastInteractionAt'] != null ? DateTime.parse(json['lastInteractionAt']) : null,
    archived: json['archived'] ?? false,
  );
} 