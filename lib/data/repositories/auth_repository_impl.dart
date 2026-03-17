import 'dart:convert';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/data/datasources/auth_remote_datasource.dart';
import 'package:high_school/domain/entities/user_entity.dart';
import 'package:high_school/domain/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._prefs) : _remote = AuthRemoteDatasource();

  final SharedPreferences _prefs;
  final AuthRemoteDatasource _remote;
  UserEntity? _currentUser;

  @override
  UserEntity? get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  Future<void> sendOtp(String phone) async {
    if (!_remote.isConfigured) return;
    await _remote.sendOtp(phone);
  }

  @override
  Future<void> verifyOtp(String phone, String otp) async {
    if (!_remote.isConfigured) return;
    await _remote.verifyOtp(phone: phone, otp: otp);
  }

  @override
  Future<void> restoreSession() async {
    // API session: token + user json stored after login/register
    final token = _prefs.getString(AppConstants.sessionTokenKey);
    final userJson = _prefs.getString(AppConstants.sessionUserJsonKey);
    if (token != null && token.isNotEmpty && userJson != null && userJson.isNotEmpty) {
      try {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        final user = _userFromMap(map);
        if (user != null) {
          _currentUser = user;
          return;
        }
      } catch (_) {}
    }

    // Legacy / mock session
    final id = _prefs.getString(AppConstants.sessionUserIdKey);
    if (id == null) return;
    if (id == _demoStudent.id) {
      _currentUser = _demoStudent;
      await _prefs.setString(AppConstants.sessionRoleKey, 'student');
      return;
    }
    if (id == _demoTeacher.id) {
      _currentUser = _demoTeacher;
      await _prefs.setString(AppConstants.sessionRoleKey, 'teacher');
      return;
    }
    final raw = _prefs.getString(AppConstants.registeredUsersKey);
    final list = raw != null ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    for (final u in list) {
      if (u['id'] == id) {
        if (u['role'] == 'teacher' && u['status'] == 'pending') return;
        _currentUser = UserEntity(
          id: u['id'] as String,
          name: u['name'] as String,
          email: u['email'] as String? ?? '${u['phone']}@school.mr',
          role: u['role'] == 'teacher' ? UserRole.teacher : UserRole.student,
          grade: u['grade'] as String?,
          subject: u['subject'] as String?,
        );
        await _prefs.setString(AppConstants.sessionRoleKey, _currentUser!.role == UserRole.teacher ? 'teacher' : 'student');
        return;
      }
    }
  }

  static UserEntity? _userFromMap(Map<String, dynamic> m) {
    final id = m['id']?.toString();
    final name = m['name']?.toString();
    if (id == null || name == null) return null;
    final roleStr = m['role']?.toString() ?? '';
    final role = roleStr == 'teacher' ? UserRole.teacher : UserRole.student;
    final email = m['email']?.toString() ?? '${m['phone'] ?? id}@school.mr';
    final grade = m['grade']?.toString();
    final subject = m['subject']?.toString();
    return UserEntity(
      id: id,
      name: name,
      email: email,
      role: role,
      grade: grade,
      subject: subject,
    );
  }

  Future<void> _saveApiSession(String token, Map<String, dynamic> user) async {
    await _prefs.setString(AppConstants.sessionTokenKey, token);
    await _prefs.setString(AppConstants.sessionUserJsonKey, jsonEncode(user));
    final id = user['id']?.toString();
    if (id != null) await _prefs.setString(AppConstants.sessionUserIdKey, id);
    final role = user['role']?.toString() ?? 'student';
    await _prefs.setString(AppConstants.sessionRoleKey, role);
  }

  static const _demoStudent = UserEntity(
    id: 'demo_student',
    name: 'Fatima Al-Hassan',
    email: 'fatima@school.mr',
    role: UserRole.student,
    grade: '10th Grade',
  );
  static const _demoTeacher = UserEntity(
    id: 'demo_teacher',
    name: 'Mohammed El-Amin',
    email: 'mohammed@school.mr',
    role: UserRole.teacher,
    subject: 'Mathematics',
  );

  @override
  Future<bool> login(String emailOrPhone, String password) async {
    if (_remote.isConfigured) {
      try {
        final res = await _remote.login(emailOrPhone, password);
        await _saveApiSession(res.token, res.user);
        _currentUser = _userFromMap(res.user);
        return _currentUser != null;
      } on AuthApiException {
        rethrow;
      }
    }

    if ((emailOrPhone == AppConstants.demoStudentPhone && password == AppConstants.demoStudentPin)) {
      _currentUser = _demoStudent;
      await _prefs.setString(AppConstants.sessionUserIdKey, _demoStudent.id);
      await _prefs.setString(AppConstants.sessionRoleKey, 'student');
      return true;
    }
    if ((emailOrPhone == AppConstants.demoTeacherPhone && password == AppConstants.demoTeacherPin)) {
      _currentUser = _demoTeacher;
      await _prefs.setString(AppConstants.sessionUserIdKey, _demoTeacher.id);
      await _prefs.setString(AppConstants.sessionRoleKey, 'teacher');
      return true;
    }
    final raw = _prefs.getString(AppConstants.registeredUsersKey);
    final list = raw != null ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    for (final u in list) {
      if ((u['phone'] == emailOrPhone || u['email'] == emailOrPhone) && u['password'] == password) {
        if (u['role'] == 'teacher' && u['status'] == 'pending') return false;
        _currentUser = UserEntity(
          id: u['id'] as String,
          name: u['name'] as String,
          email: u['email'] as String? ?? '${u['phone']}@school.mr',
          role: u['role'] == 'teacher' ? UserRole.teacher : UserRole.student,
          grade: u['grade'] as String?,
          subject: u['subject'] as String?,
        );
        await _prefs.setString(AppConstants.sessionUserIdKey, _currentUser!.id);
        await _prefs.setString(AppConstants.sessionRoleKey, _currentUser!.role == UserRole.teacher ? 'teacher' : 'student');
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    await _prefs.remove(AppConstants.sessionUserIdKey);
    await _prefs.remove(AppConstants.sessionRoleKey);
    await _prefs.remove(AppConstants.sessionTokenKey);
    await _prefs.remove(AppConstants.sessionUserJsonKey);
  }

  @override
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
    if (_remote.isConfigured) {
      try {
        final res = role == 'student'
            ? await _remote.register(
                role: role,
                name: name,
                phone: phone,
                pin: pin,
                gradeLevel: grade,
                gradeId: null,
                assignedSubjectIds: assignedSubjectIds,
                assignedSubjects: assignedSubjects,
              )
            : await _remote.register(
                role: role,
                name: name,
                phone: phone,
                pin: pin,
                subjectId: subjectId,
                subject: subject,
                assignedGradeIds: assignedGradeIds,
                assignedGrades: assignedGrades,
              );
        await _saveApiSession(res.token, res.user);
        final user = _userFromMap(res.user);
        // Teacher pending: API may return status pending; don't auto-login
        final status = res.user['status']?.toString();
        if (role == 'teacher' && status == 'pending') {
          await logout();
          return true;
        }
        _currentUser = user;
        return true;
      } on AuthApiException {
        rethrow;
      }
    }

    final raw = _prefs.getString(AppConstants.registeredUsersKey);
    final list = raw != null ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    if (list.any((u) => u['phone'] == phone)) return false;
    final newUser = {
      'id': 'user_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'email': '$phone@school.mr',
      'phone': phone,
      'password': pin,
      'role': role,
      'grade': grade,
      'subject': subject,
      'status': role == 'teacher' ? 'pending' : 'approved',
      'createdAt': DateTime.now().toIso8601String(),
    };
    list.add(newUser);
    await _prefs.setString(AppConstants.registeredUsersKey, jsonEncode(list));
    if (role == 'student') {
      _currentUser = UserEntity(
        id: newUser['id'] as String,
        name: name,
        email: newUser['email'] as String,
        role: UserRole.student,
        grade: grade,
      );
    }
    return true;
  }
}
