import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/utils/app_date_format.dart';
import 'package:high_school/core/network/unauthorized_handler.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/core/router/app_router.dart';
import 'package:high_school/domain/repositories/auth_repository.dart';
import 'package:high_school/domain/repositories/classes_repository.dart';
import 'package:high_school/domain/repositories/lessons_repository.dart';
import 'package:high_school/domain/repositories/assignments_repository.dart';
import 'package:high_school/domain/repositories/students_repository.dart';
import 'package:high_school/domain/repositories/timetable_repository.dart';
import 'package:high_school/domain/repositories/live_sessions_repository.dart';
import 'package:high_school/domain/repositories/notifications_repository.dart';
import 'package:high_school/domain/repositories/subscription_repository.dart';
import 'package:high_school/domain/repositories/subjects_repository.dart';
import 'package:high_school/domain/repositories/student_dashboard_repository.dart';
import 'package:high_school/domain/repositories/student_classes_repository.dart';
import 'package:high_school/domain/repositories/student_profile_repository.dart';
import 'package:high_school/domain/repositories/student_assignment_details_repository.dart';
import 'package:high_school/domain/repositories/teacher_dashboard_repository.dart';
import 'package:high_school/domain/repositories/teacher_classes_repository.dart';
import 'package:high_school/domain/repositories/teacher_profile_repository.dart';
import 'package:high_school/domain/repositories/teacher_students_repository.dart';
import 'package:high_school/domain/repositories/class_chat_repository.dart';
import 'package:high_school/data/repositories/auth_repository_impl.dart';
import 'package:high_school/data/repositories/class_chat_repository_impl.dart';
import 'package:high_school/data/datasources/class_chat_remote_datasource.dart';
import 'package:high_school/data/datasources/class_chat_socket_client.dart';
import 'package:high_school/core/services/push_notification_service.dart';
import 'package:high_school/core/services/class_chat_in_app_service.dart';
import 'package:high_school/domain/entities/user_entity.dart';
import 'package:high_school/data/repositories/classes_repository_impl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:high_school/data/repositories/lessons_repository_impl.dart';
import 'package:high_school/data/repositories/assignments_repository_impl.dart';
import 'package:high_school/data/repositories/students_repository_impl.dart';
import 'package:high_school/data/repositories/timetable_repository_impl.dart';
import 'package:high_school/data/repositories/live_sessions_repository_impl.dart';
import 'package:high_school/data/repositories/notifications_repository_impl.dart';
import 'package:high_school/data/repositories/subscription_repository_impl.dart';
import 'package:high_school/data/repositories/subjects_repository_impl.dart';
import 'package:high_school/data/repositories/student_dashboard_repository_impl.dart';
import 'package:high_school/data/repositories/student_classes_repository_impl.dart';
import 'package:high_school/data/repositories/student_profile_repository_impl.dart';
import 'package:high_school/data/repositories/student_assignment_details_repository_impl.dart';
import 'package:high_school/data/repositories/teacher_dashboard_repository_impl.dart';
import 'package:high_school/data/repositories/teacher_classes_repository_impl.dart';
import 'package:high_school/data/repositories/teacher_profile_repository_impl.dart';
import 'package:high_school/data/repositories/teacher_students_repository_impl.dart';
import 'package:high_school/data/datasources/assignments_remote_datasource.dart';
import 'package:high_school/data/datasources/lessons_remote_datasource.dart';
import 'package:high_school/data/datasources/student_lesson_remote_datasource.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/providers/subscription_provider.dart';
import 'package:high_school/core/l10n/app_translations.dart' as app_lang;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(AppDateFormat.locale);
  final prefs = await SharedPreferences.getInstance();

  // Background FCM handler (no-op if Firebase not configured)
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {}

  // Repositories
  final AuthRepository authRepo = AuthRepositoryImpl(prefs);
  final ClassesRepository classesRepo = ClassesRepositoryImpl(prefs);
  final LessonsRepository lessonsRepo = LessonsRepositoryImpl();
  final AssignmentsRepository assignmentsRepo = AssignmentsRepositoryImpl(prefs);
  final StudentsRepository studentsRepo = StudentsRepositoryImpl();
  final TimetableRepository timetableRepo = TimetableRepositoryImpl(prefs);
  final TeacherDashboardRepository teacherDashboardRepo =
      TeacherDashboardRepositoryImpl(prefs);
  final StudentDashboardRepository studentDashboardRepo =
      StudentDashboardRepositoryImpl(prefs);
  final LiveSessionsRepository liveSessionsRepo = LiveSessionsRepositoryImpl(
    prefs,
    teacherDashboard: teacherDashboardRepo,
    studentDashboard: studentDashboardRepo,
  );
  final NotificationsRepository notificationsRepo =
      NotificationsRepositoryImpl();
  final SubscriptionRepository subscriptionRepo =
      SubscriptionRepositoryImpl(prefs);
  final SubjectsRepository subjectsRepo = SubjectsRepositoryImpl(prefs);
  final StudentClassesRepository studentClassesRepo =
      StudentClassesRepositoryImpl(prefs);
  final StudentProfileRepository studentProfileRepo =
      StudentProfileRepositoryImpl(prefs);
  final StudentAssignmentDetailsRepository studentAssignmentDetailsRepo =
      StudentAssignmentDetailsRepositoryImpl(prefs);
  final TeacherClassesRepository teacherClassesRepo =
      TeacherClassesRepositoryImpl(prefs, classesRepo);
  final TeacherProfileRepository teacherProfileRepo =
      TeacherProfileRepositoryImpl(prefs);
  final TeacherStudentsRepository teacherStudentsRepo =
      TeacherStudentsRepositoryImpl(prefs, studentsRepo, classesRepo);
  final LessonsRemoteDatasource lessonsRemoteDatasource =
      LessonsRemoteDatasource(prefs);
  final AssignmentsRemoteDatasource assignmentsRemoteDatasource =
      AssignmentsRemoteDatasource(prefs);
  final StudentLessonRemoteDatasource studentLessonRemoteDatasource =
      StudentLessonRemoteDatasource(prefs);
  final ClassChatRemoteDatasource classChatRemoteDatasource =
      ClassChatRemoteDatasource(prefs);
  final ClassChatSocketClient classChatSocketClient =
      ClassChatSocketClient(prefs);
  final ClassChatRepository classChatRepo =
      ClassChatRepositoryImpl(classChatRemoteDatasource, classChatSocketClient);

  final pushService =
      PushNotificationService(prefs, classChatRemoteDatasource);

  // Providers
  final authProvider = AuthProvider(authRepo);
  authProvider.beforeLogout = () => pushService.clearTokenOnLogout();
  await authProvider.restoreSession();

  final languageProvider = LanguageProvider(prefs);
  final subscriptionProvider = SubscriptionProvider(subscriptionRepo);

  final router = await AppRouter.createRouter();

  pushService.onOpenClassChat = (classId) {
    final role = authProvider.user?.role;
    if (role == UserRole.teacher) {
      router.go('/teacher/classes/$classId/chat');
    } else {
      router.go('/student/classes/$classId/chat');
    }
  };

  final classChatInAppService = ClassChatInAppService(
    classChatSocketClient,
    pushService,
    authProvider,
  );

  authProvider.addListener(() {
    if (authProvider.isAuthenticated) {
      pushService.syncTokenWithBackend();
    }
  });

  UnauthorizedHandler.onUnauthorized = () async {
    await authProvider.logout();
    router.go('/login');
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(
            value: subscriptionProvider),
        Provider<ClassesRepository>.value(value: classesRepo),
        Provider<LessonsRepository>.value(value: lessonsRepo),
        Provider<AssignmentsRepository>.value(value: assignmentsRepo),
        Provider<StudentsRepository>.value(value: studentsRepo),
        Provider<TimetableRepository>.value(value: timetableRepo),
        Provider<LiveSessionsRepository>.value(value: liveSessionsRepo),
        Provider<NotificationsRepository>.value(value: notificationsRepo),
        Provider<SubscriptionRepository>.value(value: subscriptionRepo),
        Provider<SubjectsRepository>.value(value: subjectsRepo),
        Provider<StudentDashboardRepository>.value(value: studentDashboardRepo),
        Provider<StudentClassesRepository>.value(value: studentClassesRepo),
        Provider<StudentProfileRepository>.value(value: studentProfileRepo),
        Provider<StudentAssignmentDetailsRepository>.value(
            value: studentAssignmentDetailsRepo),
        Provider<TeacherDashboardRepository>.value(value: teacherDashboardRepo),
        Provider<TeacherClassesRepository>.value(value: teacherClassesRepo),
        Provider<TeacherProfileRepository>.value(value: teacherProfileRepo),
        Provider<TeacherStudentsRepository>.value(value: teacherStudentsRepo),
        Provider<LessonsRemoteDatasource>.value(value: lessonsRemoteDatasource),
        Provider<AssignmentsRemoteDatasource>.value(
            value: assignmentsRemoteDatasource),
        Provider<StudentLessonRemoteDatasource>.value(
            value: studentLessonRemoteDatasource),
        Provider<ClassChatRepository>.value(value: classChatRepo),
        Provider<PushNotificationService>.value(value: pushService),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            locale: Locale(languageProvider.language.code),
            supportedLocales:
                app_lang.AppLanguage.values.map((e) => Locale(e.code)).toList(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          );
        },
      ),
    ),
  );

  // After first frame so iOS debug can attach the Dart VM service quickly.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_bootstrapPushAndChat(pushService, classChatInAppService, authProvider));
  });
}

Future<void> _bootstrapPushAndChat(
  PushNotificationService pushService,
  ClassChatInAppService classChatInAppService,
  AuthProvider authProvider,
) async {
  await pushService.init();
  classChatInAppService.start();
  if (authProvider.isAuthenticated) {
    await pushService.syncTokenWithBackend();
  }
}
