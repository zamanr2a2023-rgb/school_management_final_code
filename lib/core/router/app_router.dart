import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/domain/entities/user_entity.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/presentation/providers/auth_provider.dart';
import 'package:high_school/presentation/screens/auth/language_selection_screen.dart';
import 'package:high_school/presentation/screens/auth/login_screen.dart';
import 'package:high_school/presentation/screens/auth/register_screen.dart';
import 'package:high_school/presentation/screens/auth/otp_send_screen.dart';
import 'package:high_school/presentation/screens/auth/otp_verify_screen.dart';
import 'package:high_school/presentation/screens/student/student_dashboard_screen.dart';
import 'package:high_school/presentation/screens/student/classes_list_screen.dart';
import 'package:high_school/presentation/screens/student/class_details_screen.dart';
import 'package:high_school/presentation/screens/student/lesson_details_screen.dart';
import 'package:high_school/presentation/screens/student/assignments_list_screen.dart';
import 'package:high_school/presentation/screens/student/assignment_details_screen.dart';
import 'package:high_school/presentation/screens/student/timetable_screen.dart';
import 'package:high_school/presentation/screens/student/live_sessions_screen.dart';
import 'package:high_school/presentation/screens/student/live_session_detail_screen.dart';
import 'package:high_school/presentation/screens/student/student_profile_screen.dart';
import 'package:high_school/presentation/screens/student/subscription_screen.dart';
import 'package:high_school/presentation/screens/teacher/teacher_dashboard_screen.dart';
import 'package:high_school/presentation/screens/teacher/teacher_classes_list_screen.dart';
import 'package:high_school/presentation/screens/teacher/teacher_class_details_screen.dart';
import 'package:high_school/presentation/screens/teacher/teacher_assignment_details_screen.dart';
import 'package:high_school/presentation/screens/teacher/teacher_students_list_screen.dart';
import 'package:high_school/presentation/screens/teacher/teacher_student_detail_screen.dart';
import 'package:high_school/presentation/screens/teacher/teacher_live_sessions_screen.dart';
import 'package:high_school/presentation/screens/teacher/teacher_analytics_screen.dart';
import 'package:high_school/presentation/screens/teacher/teacher_profile_screen.dart';
import 'package:high_school/presentation/screens/notifications_screen.dart';
import 'package:high_school/presentation/screens/sitemap_screen.dart';
import 'package:high_school/presentation/widgets/layout_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRouter {
  static Future<GoRouter> createRouter() async {
    final prefs = await SharedPreferences.getInstance();
    final languageSelected =
        prefs.getBool(AppConstants.languageSelectedKey) ?? false;
    final sessionUserId = prefs.getString(AppConstants.sessionUserIdKey);
    final sessionRole = prefs.getString(AppConstants.sessionRoleKey);

    String initialLocation = '/language';
    if (languageSelected) {
      if (sessionUserId != null) {
        initialLocation = sessionRole == 'teacher'
            ? '/teacher/dashboard'
            : '/student/dashboard';
      } else {
        initialLocation = '/login';
      }
    }

    return GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) async {
        final prefs = await SharedPreferences.getInstance();
        final languageSelected =
            prefs.getBool(AppConstants.languageSelectedKey) ?? false;
        final auth = context.read<AuthProvider>();
        final isAuthenticated = auth.isAuthenticated;
        final user = auth.user;
        final loc = state.matchedLocation;
        final isLanguage = loc == '/language';
        final isLogin = loc == '/login';
        final isRegister = loc == '/register';

        if (!languageSelected && !isLanguage) return '/language';
        if (languageSelected &&
            !isAuthenticated &&
            !isLogin &&
            !isRegister &&
            !loc.startsWith('/sitemap')) return '/login';
        if (isAuthenticated && (isLogin || isRegister || isLanguage)) {
          if (user?.role == UserRole.student) return '/student/dashboard';
          if (user?.role == UserRole.teacher) return '/teacher/dashboard';
          return '/login';
        }
        if (isAuthenticated && user != null) {
          if (loc.startsWith('/student/') && user.role != UserRole.student)
            return '/teacher/dashboard';
          if (loc.startsWith('/teacher/') && user.role != UserRole.teacher)
            return '/student/dashboard';
        }
        return null;
      },
      routes: [
        GoRoute(
            path: '/language',
            builder: (_, __) => const LanguageSelectionScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(
          path: '/otp/send',
          builder: (_, state) {
            final phone = state.extra is String ? state.extra as String : '';
            return OtpSendScreen(phone: phone);
          },
        ),
        GoRoute(
          path: '/otp/verify',
          builder: (_, state) {
            final phone = state.extra is String ? state.extra as String : '';
            return OtpVerifyScreen(phone: phone);
          },
        ),
        GoRoute(
          path: '/sitemap',
          builder: (_, __) => const LayoutWidget(child: SitemapScreen()),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const LayoutWidget(child: NotificationsScreen()),
        ),
        // Student
        GoRoute(
          path: '/student/dashboard',
          builder: (_, __) =>
              const LayoutWidget(child: StudentDashboardScreen()),
        ),
        GoRoute(
          path: '/student/classes',
          builder: (_, __) => const LayoutWidget(child: ClassesListScreen()),
        ),
        GoRoute(
          path: '/student/classes/:classId',
          builder: (_, state) => LayoutWidget(
            child:
                ClassDetailsScreen(classId: state.pathParameters['classId']!),
          ),
        ),
        GoRoute(
          path: '/student/lessons/:lessonId',
          builder: (_, state) => LayoutWidget(
            child: LessonDetailsScreen(
                lessonId: state.pathParameters['lessonId']!),
          ),
        ),
        GoRoute(
          path: '/student/assignments',
          builder: (_, __) =>
              const LayoutWidget(child: AssignmentsListScreen()),
        ),
        GoRoute(
          path: '/student/assignments/:assignmentId',
          builder: (_, state) {
            final assignmentId = state.pathParameters['assignmentId']!;
            final passedAssignment = state.extra is AssignmentEntity
                ? state.extra as AssignmentEntity
                : null;
            return LayoutWidget(
              child: AssignmentDetailsScreen(
                assignmentId: assignmentId,
                passedAssignment: passedAssignment,
              ),
            );
          },
        ),
        GoRoute(
          path: '/student/timetable',
          builder: (_, __) => const LayoutWidget(child: TimetableScreen()),
        ),
        GoRoute(
          path: '/student/live-sessions',
          builder: (_, __) => const LayoutWidget(child: LiveSessionsScreen()),
        ),
        GoRoute(
          path: '/student/live-sessions/:sessionId',
          builder: (_, state) {
            final sessionId = state.pathParameters['sessionId']!;
            final passedSession = state.extra is LiveSessionEntity
                ? state.extra as LiveSessionEntity
                : null;
            return LayoutWidget(
              child: LiveSessionDetailScreen(
                sessionId: sessionId,
                passedSession: passedSession,
              ),
            );
          },
        ),
        GoRoute(
          path: '/student/profile',
          builder: (_, __) => const LayoutWidget(child: StudentProfileScreen()),
        ),
        GoRoute(
          path: '/student/subscription',
          builder: (_, __) => const LayoutWidget(child: SubscriptionScreen()),
        ),
        // Teacher
        GoRoute(
          path: '/teacher/dashboard',
          builder: (_, __) =>
              const LayoutWidget(child: TeacherDashboardScreen()),
        ),
        GoRoute(
          path: '/teacher/classes',
          builder: (_, __) =>
              const LayoutWidget(child: TeacherClassesListScreen()),
        ),
        GoRoute(
          path: '/teacher/classes/:classId',
          builder: (_, state) => LayoutWidget(
            child: TeacherClassDetailsScreen(
                classId: state.pathParameters['classId']!),
          ),
        ),
        GoRoute(
          path: '/teacher/assignments/:assignmentId',
          builder: (_, state) => LayoutWidget(
            child: TeacherAssignmentDetailsScreen(
                assignmentId: state.pathParameters['assignmentId']!),
          ),
        ),
        GoRoute(
          path: '/teacher/students',
          builder: (_, __) =>
              const LayoutWidget(child: TeacherStudentsListScreen()),
        ),
        GoRoute(
          path: '/teacher/students/:studentId',
          builder: (_, state) => LayoutWidget(
            child: TeacherStudentDetailScreen(
                studentId: state.pathParameters['studentId']!),
          ),
        ),
        GoRoute(
          path: '/teacher/timetable',
          builder: (_, __) => const LayoutWidget(child: TimetableScreen()),
        ),
        GoRoute(
          path: '/teacher/live-sessions',
          builder: (_, __) =>
              const LayoutWidget(child: TeacherLiveSessionsScreen()),
        ),
        GoRoute(
          path: '/teacher/analytics',
          builder: (_, __) =>
              const LayoutWidget(child: TeacherAnalyticsScreen()),
        ),
        GoRoute(
          path: '/teacher/profile',
          builder: (_, __) => const LayoutWidget(child: TeacherProfileScreen()),
        ),
      ],
    );
  }
}
