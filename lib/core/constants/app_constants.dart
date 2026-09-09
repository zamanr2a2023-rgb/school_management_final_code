class AppConstants {
  AppConstants._();

  /// Launcher / UI display name
  static const String appName = 'Garini';

  /// Brand logo (declared in pubspec.yaml)
  static const String logoAsset = 'assets/Logo.png';
  static const String languageSelectedKey = 'languageSelected';
  static const String languageKey = 'language';
  static const String registeredUsersKey = 'registeredUsers';
  static const String studentSubscriptionsKey = 'studentSubscriptions';
  static const String sessionUserIdKey = 'sessionUserId';
  static const String sessionRoleKey = 'sessionRole';
  static const String sessionTokenKey = 'sessionToken';
  static const String sessionUserJsonKey = 'sessionUserJson';

  /// Base URL for API (e.g. https://your-api.com). Empty = use mock auth only.
  // static const String apiBaseUrl = 'https://16.171.129.200';
    static const String apiBaseUrl = 'https://rimversion.com';
  // static const String apiBaseUrl = 'http://103.208.183.250:5005';
  // Demo accounts
  static const String demoStudentPhone = '12345678';
  static const String demoStudentPin = '1234';
  static const String demoTeacherPhone = '98765432';
  static const String demoTeacherPin = '5678';
}
