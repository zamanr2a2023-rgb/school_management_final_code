import 'package:flutter/foundation.dart';
import 'package:high_school/data/datasources/auth_remote_datasource.dart';
import 'package:high_school/domain/entities/user_entity.dart';
import 'package:high_school/domain/repositories/auth_repository.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider(this._authRepository);

  final AuthRepository _authRepository;

  UserEntity? get user => _authRepository.currentUser;
  bool get isAuthenticated => _authRepository.isAuthenticated;

  /// Last error message from login/register API (e.g. validation message). Cleared on next attempt.
  String? lastAuthError;

  Future<void> restoreSession() async {
    lastAuthError = null;
    await _authRepository.restoreSession();
    notifyListeners();
  }

  Future<bool> sendOtp(String phone) async {
    lastAuthError = null;
    try {
      await _authRepository.sendOtp(phone);
      notifyListeners();
      return true;
    } on AuthApiException catch (e) {
      lastAuthError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    lastAuthError = null;
    try {
      await _authRepository.verifyOtp(phone, otp);
      notifyListeners();
      return true;
    } on AuthApiException catch (e) {
      lastAuthError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String emailOrPhone, String password) async {
    lastAuthError = null;
    try {
      final ok = await _authRepository.login(emailOrPhone, password);
      if (ok) notifyListeners();
      return ok;
    } on AuthApiException catch (e) {
      lastAuthError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    lastAuthError = null;
    await _authRepository.logout();
    notifyListeners();
  }

  Future<void> syncUserFromProfile({
    required String name,
    required String phone,
  }) async {
    await _authRepository.applyProfileUpdate(name: name, phone: phone);
    notifyListeners();
  }

  /// Prefer after profile save: loads latest name/phone from GET /users/me.
  Future<bool> refreshUserFromServer() async {
    final ok = await _authRepository.refreshCurrentUserFromServer();
    notifyListeners();
    return ok;
  }

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
  }) async {
    lastAuthError = null;
    try {
      final ok = await _authRepository.register(
        name: name,
        phone: phone,
        pin: pin,
        role: role,
        grade: grade,
        subject: subject,
        subjectId: subjectId,
        assignedSubjectIds: assignedSubjectIds,
        assignedSubjects: assignedSubjects,
        assignedGradeIds: assignedGradeIds,
        assignedGrades: assignedGrades,
      );
      if (ok) notifyListeners();
      return ok;
    } on AuthApiException catch (e) {
      lastAuthError = e.message;
      notifyListeners();
      return false;
    }
  }
}
