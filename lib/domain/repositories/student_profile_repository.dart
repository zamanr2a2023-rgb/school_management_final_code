import 'package:high_school/domain/entities/student_profile_me_entity.dart';

abstract class StudentProfileRepository {
  /// GET /profiles/me. Null if not configured, unauthorized, or error.
  Future<StudentProfileMe?> getMyProfile();

  /// PATCH /profiles/me when API is configured.
  /// Returns `true` if the server accepted, `false` on error, `null` if API is not used (caller may apply local-only changes).
  Future<bool?> updateMyProfile({
    required String name,
    required String phone,
    required String address,
    String? profileImagePath,
  });
}
