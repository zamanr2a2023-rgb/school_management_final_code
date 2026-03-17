import '../entities/user_entity.dart';

abstract class AuthRepository {
  UserEntity? get currentUser;
  bool get isAuthenticated;
  Future<void> restoreSession();
  Future<bool> login(String emailOrPhone, String password);
  Future<void> logout();
  Future<void> sendOtp(String phone);
  Future<void> verifyOtp(String phone, String otp);
  Future<bool> register({
    required String name,
    required String phone,
    required String pin,
    required String role,
    String? grade,
    String? subject,
    String? subjectId,
    List<String>? assignedSubjectIds,
    List<String>? assignedSubjects,
    List<String>? assignedGradeIds,
    List<String>? assignedGrades,
  });
}
