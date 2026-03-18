import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:high_school/domain/repositories/student_assignment_details_repository.dart';
import 'package:high_school/domain/repositories/teacher_dashboard_repository.dart';
import 'package:high_school/domain/repositories/teacher_classes_repository.dart';
import 'package:high_school/data/repositories/auth_repository_impl.dart';
import 'package:high_school/data/repositories/classes_repository_impl.dart';
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
import 'package:high_school/data/repositories/student_assignment_details_repository_impl.dart';
import 'package:high_school/data/repositories/teacher_dashboard_repository_impl.dart';
import 'package:high_school/data/repositories/teacher_classes_repository_impl.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/providers/subscription_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Repositories
  final AuthRepository authRepo = AuthRepositoryImpl(prefs);
  final ClassesRepository classesRepo = ClassesRepositoryImpl(prefs);
  final LessonsRepository lessonsRepo = LessonsRepositoryImpl();
  final AssignmentsRepository assignmentsRepo = AssignmentsRepositoryImpl();
  final StudentsRepository studentsRepo = StudentsRepositoryImpl();
  final TimetableRepository timetableRepo = TimetableRepositoryImpl(prefs);
  final LiveSessionsRepository liveSessionsRepo = LiveSessionsRepositoryImpl(prefs);
  final NotificationsRepository notificationsRepo =
      NotificationsRepositoryImpl();
  final SubscriptionRepository subscriptionRepo =
      SubscriptionRepositoryImpl(prefs);
  final SubjectsRepository subjectsRepo = SubjectsRepositoryImpl(prefs);
  final StudentDashboardRepository studentDashboardRepo =
      StudentDashboardRepositoryImpl(prefs);
  final StudentClassesRepository studentClassesRepo =
      StudentClassesRepositoryImpl(prefs);
  final StudentAssignmentDetailsRepository studentAssignmentDetailsRepo =
      StudentAssignmentDetailsRepositoryImpl(prefs);
  final TeacherDashboardRepository teacherDashboardRepo =
      TeacherDashboardRepositoryImpl(prefs);
  final TeacherClassesRepository teacherClassesRepo =
      TeacherClassesRepositoryImpl(prefs, classesRepo);

  // Providers
  final authProvider = AuthProvider(authRepo);
  await authProvider.restoreSession();

  final languageProvider = LanguageProvider(prefs);
  final subscriptionProvider = SubscriptionProvider(subscriptionRepo);

  final router = await AppRouter.createRouter();

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
        Provider<StudentAssignmentDetailsRepository>.value(value: studentAssignmentDetailsRepo),
        Provider<TeacherDashboardRepository>.value(value: teacherDashboardRepo),
        Provider<TeacherClassesRepository>.value(value: teacherClassesRepo),
      ],
      child: MaterialApp.router(
        title: 'Nouadhibou High School',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
}
