import 'dart:convert';

class ProfileMemory {
  String? name;
  int? birthYear;
  String? birthPlace;
  List<Map<String, dynamic>> events;
  List<Map<String, dynamic>> relationships;

  ProfileMemory({
    this.name,
    this.birthYear,
    this.birthPlace,
    List<Map<String, dynamic>>? events,
    List<Map<String, dynamic>>? relationships,
  })  : events = events ?? [],
        relationships = relationships ?? [];

  factory ProfileMemory.fromJson(Map<String, dynamic> json) => ProfileMemory(
        name: json['name'],
        birthYear: json['birthYear'],
        birthPlace: json['birthPlace'],
        events: (json['events'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
        relationships: (json['relationships'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (birthYear != null) 'birthYear': birthYear,
        if (birthPlace != null) 'birthPlace': birthPlace,
        'events': events,
        'relationships': relationships,
      };

  // Merge new facts into memory (simple append for now)
  void merge(ProfileMemory other) {
    name ??= other.name;
    birthYear ??= other.birthYear;
    birthPlace ??= other.birthPlace;
    // Add new events if not already present
    for (final event in other.events) {
      if (!events.any((e) => e.toString() == event.toString())) {
        events.add(event);
      }
    }
    // Add new relationships if not already present
    for (final rel in other.relationships) {
      if (!relationships.any((r) => r.toString() == rel.toString())) {
        relationships.add(rel);
      }
    }
  }

  static ProfileMemory fromJsonString(String jsonStr) => ProfileMemory.fromJson(jsonDecode(jsonStr));
  String toJsonString() => jsonEncode(toJson());
} 