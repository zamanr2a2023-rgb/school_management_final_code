import 'package:high_school/domain/entities/teacher_profile_me_entity.dart';

abstract class TeacherProfileRepository {
  /// GET /profiles/me (teacher payload). Null if not configured, unauthorized, or error.
  Future<TeacherProfileMe?> getMyProfile();

  /// PATCH /profiles/me when API is configured (same endpoint for student and teacher).
  Future<bool?> updateMyProfile({
    required String name,
    required String phone,
    required String address,
    String? profileImagePath,
  });
}
