import 'package:hive/hive.dart';
import '../models/sub_user_profile.dart';

class SubUserProfileStorage {
  static const String boxName = 'sub_user_profiles';

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox(boxName);
    }
    return Hive.box(boxName);
  }

  Future<List<SubUserProfile>> getProfiles() async {
    final box = await _getBox();
    return box.values
        .map((e) => SubUserProfile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addProfile(SubUserProfile profile) async {
    final box = await _getBox();
    await box.put(profile.id, profile.toJson());
  }

  Future<void> updateProfile(SubUserProfile profile) async {
    final box = await _getBox();
    await box.put(profile.id, profile.toJson());
  }

  Future<void> deleteProfile(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }
} 