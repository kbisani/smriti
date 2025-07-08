import 'package:hive/hive.dart';
import '../models/main_user.dart';

class MainUserStorage {
  static const String boxName = 'settings';
  static const String mainUserKey = 'main_user';

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox(boxName);
    }
    return Hive.box(boxName);
  }

  Future<MainUser?> getMainUser() async {
    final box = await _getBox();
    final data = box.get(mainUserKey);
    if (data == null) return null;
    if (data is MainUser) return data;
    if (data is Map) return MainUser.fromJson(Map<String, dynamic>.from(data));
    return null;
  }

  Future<void> saveMainUser(MainUser user) async {
    final box = await _getBox();
    await box.put(mainUserKey, user.toJson());
  }
} 