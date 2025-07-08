import 'package:hive/hive.dart';
import '../models/profile.dart';
import 'profile_storage.dart';

class HiveProfileStorage implements ProfileStorage {
  static const String boxName = 'profiles';

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox(boxName);
    }
    return Hive.box(boxName);
  }

  @override
  Future<List<Profile>> getProfiles() async {
    final box = await _getBox();
    return box.values
        .map((e) => Profile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<void> addProfile(Profile profile) async {
    final box = await _getBox();
    await box.put(profile.id, profile.toJson());
  }

  @override
  Future<void> updateProfile(Profile profile) async {
    final box = await _getBox();
    await box.put(profile.id, profile.toJson());
  }

  @override
  Future<void> deleteProfile(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }
} 