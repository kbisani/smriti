import 'package:hive/hive.dart';
import '../models/profile.dart';
import 'profile_storage.dart';

class HiveProfileStorage implements ProfileStorage {
  static const String boxName = 'profiles';

  Future<Box<Profile>> _getBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox<Profile>(boxName);
    }
    return Hive.box<Profile>(boxName);
  }

  @override
  Future<List<Profile>> getProfiles() async {
    final box = await _getBox();
    return box.values.toList();
  }

  @override
  Future<void> addProfile(Profile profile) async {
    final box = await _getBox();
    await box.put(profile.id, profile);
  }

  @override
  Future<void> updateProfile(Profile profile) async {
    final box = await _getBox();
    await box.put(profile.id, profile);
  }

  @override
  Future<void> deleteProfile(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }
} 