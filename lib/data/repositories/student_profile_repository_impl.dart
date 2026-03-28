import 'package:high_school/data/datasources/student_profile_remote_datasource.dart';
import 'package:high_school/domain/entities/student_profile_me_entity.dart';
import 'package:high_school/domain/repositories/student_profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentProfileRepositoryImpl implements StudentProfileRepository {
  StudentProfileRepositoryImpl(SharedPreferences prefs)
      : _remote = StudentProfileRemoteDatasource(prefs);

  final StudentProfileRemoteDatasource _remote;

  @override
  Future<StudentProfileMe?> getMyProfile() => _remote.getMyProfile();

  @override
  Future<bool?> updateMyProfile({
    required String name,
    required String phone,
    required String address,
    String? profileImagePath,
  }) async {
    if (!_remote.isConfigured) return null;
    final ok = await _remote.patchMyProfile(
      name: name,
      phone: phone,
      address: address,
      profileImagePath: profileImagePath,
    );
    return ok;
  }
}
