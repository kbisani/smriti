import '../models/profile.dart';

abstract class ProfileStorage {
  Future<List<Profile>> getProfiles();
  Future<void> addProfile(Profile profile);
  Future<void> updateProfile(Profile profile);
  Future<void> deleteProfile(String id);
} 