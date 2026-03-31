import '../../domain/entities/assignment_entity.dart';
import '../../domain/entities/class_entity.dart';
import '../../domain/entities/lesson_entity.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/entities/student_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/timetable_entity.dart';

class MockData {
  static final List<ClassEntity> classes = [
    ClassEntity(id: 'class1', name: 'Mathematics', subject: 'Mathematics', category: 'Core', teacher: 'Mohammed Ould', teacherId: 'teacher1', students: 28, color: '#1F3C88', schedule: 'Mon, Wed, Fri 10:00 AM', room: 'Room 201', level: '4th Grade', schoolYear: '2024-2025'),
    ClassEntity(id: 'class2', name: 'Arabic', subject: 'Arabic', category: 'Language', teacher: 'Aisha Mint', teacherId: 'teacher2', students: 25, color: '#2E7D32', schedule: 'Tue, Thu 9:00 AM', room: 'Room 105', level: '5th Grade', schoolYear: '2024-2025'),
    ClassEntity(id: 'class3', name: 'Physics', subject: 'Physics', category: 'Core', teacher: 'Omar Salem', teacherId: 'teacher3', students: 30, color: '#7B1FA2', schedule: 'Mon, Wed, Fri 2:00 PM', room: 'Lab 3', level: '6th Grade', schoolYear: '2024-2025'),
    ClassEntity(id: 'class4', name: 'French', subject: 'French', category: 'Language', teacher: 'Marie Diallo', teacherId: 'teacher4', students: 22, color: '#F4B400', schedule: 'Tue, Thu 11:00 AM', room: 'Room 302', level: '7th Grade', schoolYear: '2024-2025'),
    ClassEntity(id: 'class5', name: 'Chemistry', subject: 'Chemistry', category: 'Core', teacher: 'Hassan Brahim', teacherId: 'teacher5', students: 24, color: '#D32F2F', schedule: 'Mon, Wed 1:00 PM', room: 'Lab 1', level: '5th Grade', schoolYear: '2024-2025'),
    ClassEntity(id: 'class6', name: 'SVT', subject: 'SVT', category: 'Core', teacher: 'Khadija Sow', teacherId: 'teacher6', students: 26, color: '#388E3C', schedule: 'Tue, Thu 2:00 PM', room: 'Lab 2', level: '6th Grade', schoolYear: '2024-2025'),
    ClassEntity(id: 'class7', name: 'English', subject: 'English', category: 'Language', teacher: 'John Smith', teacherId: 'teacher7', students: 20, color: '#0288D1', schedule: 'Mon, Fri 9:00 AM', room: 'Room 204', level: '4th Grade', schoolYear: '2024-2025'),
    ClassEntity(id: 'class8', name: 'Modern Skills', subject: 'Modern Skills', category: 'Elective', teacher: 'Sarah Johnson', teacherId: 'teacher8', students: 18, color: '#FF6F00', schedule: 'Wed, Fri 3:00 PM', room: 'Computer Lab', level: '7th Grade', schoolYear: '2024-2025'),
    ClassEntity(id: 'class9', name: 'Mathematics', subject: 'Mathematics', category: 'Core', teacher: 'Mohammed Ould', teacherId: 'teacher1', students: 22, color: '#1F3C88', schedule: 'Tue, Thu 10:00 AM', room: 'Room 203', level: '5th Grade', schoolYear: '2024-2025'),
    ClassEntity(id: 'class10', name: 'Mathematics', subject: 'Mathematics', category: 'Core', teacher: 'Mohammed Ould', teacherId: 'teacher1', students: 25, color: '#1F3C88', schedule: 'Mon, Wed, Fri 11:00 AM', room: 'Room 202', level: '6th Grade', schoolYear: '2024-2025'),
    ClassEntity(id: 'class11', name: 'Mathematics', subject: 'Mathematics', category: 'Core', teacher: 'Mohammed Ould', teacherId: 'teacher1', students: 20, color: '#1F3C88', schedule: 'Tue, Thu 1:00 PM', room: 'Room 106', level: '7th Grade', schoolYear: '2024-2025'),
  ];

  static final List<LessonEntity> lessons = [
    LessonEntity(id: 'lesson1', classId: 'class1', title: 'Quadratic Equations', description: 'Introduction to quadratic equations', type: LessonType.video, content: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', date: '2026-01-20', duration: '45 min', status: LessonStatus.published, lastUpdated: '2026-01-19', module: 'Chapter 3'),
    LessonEntity(id: 'lesson2', classId: 'class1', title: 'Solving Systems of Equations', description: 'Methods for solving systems', type: LessonType.pdf, content: '/files/systems-equations.pdf', date: '2026-01-22', status: LessonStatus.published, lastUpdated: '2026-01-21', module: 'Chapter 4'),
    LessonEntity(id: 'lesson3', classId: 'class2', title: 'Classical Arabic Poetry', description: 'Study of pre-Islamic poetry', type: LessonType.text, content: 'Classical Arabic poetry...', date: '2026-01-21', status: LessonStatus.published, lastUpdated: '2026-01-20', module: 'Module 2'),
    LessonEntity(id: 'lesson4', classId: 'class3', title: "Newton's Laws of Motion", description: 'Three fundamental laws', type: LessonType.video, content: 'https://www.youtube.com/watch?v=sample', date: '2026-01-20', duration: '50 min', status: LessonStatus.published, lastUpdated: '2026-01-19', module: 'Chapter 5'),
  ];

  static final List<AssignmentEntity> assignments = [
    AssignmentEntity(id: 'assign1', classId: 'class1', title: 'Quadratic Equations Worksheet', description: 'Solve problems 1-20', dueDate: '2026-01-27', points: 100, status: AssignmentStatus.pending),
    AssignmentEntity(id: 'assign2', classId: 'class1', title: 'Systems of Equations Project', description: 'Create a real-world application', dueDate: '2026-01-30', points: 150, status: AssignmentStatus.submitted, grade: 135, feedback: 'Great work!'),
    AssignmentEntity(id: 'assign3', classId: 'class2', title: 'Poetry Analysis', description: 'Analyze three poems', dueDate: '2026-01-28', points: 100, status: AssignmentStatus.graded, grade: 92, feedback: 'Excellent analysis.'),
    AssignmentEntity(id: 'assign4', classId: 'class3', title: 'Motion Lab Report', description: 'Document your findings', dueDate: '2026-02-01', points: 120, status: AssignmentStatus.pending),
  ];

  static final List<SubmissionEntity> submissions = [
    SubmissionEntity(id: 'sub1', assignmentId: 'assign1', studentId: 'student1', studentName: 'Fatima Ahmed', fileUrl: '/files/fatima-worksheet.pdf', submittedAt: '2026-01-26T14:30:00', status: 'submitted'),
    SubmissionEntity(id: 'sub2', assignmentId: 'assign1', studentId: 'student2', studentName: 'Ali Hassan', fileUrl: '/files/ali-worksheet.pdf', submittedAt: '2026-01-26T16:20:00', status: 'graded', grade: 95, feedback: 'Excellent work!'),
    SubmissionEntity(id: 'sub3', assignmentId: 'assign1', studentId: 'student3', studentName: 'Mariam Ould', submittedAt: '2026-01-27T10:00:00', status: 'submitted'),
  ];

  static final List<StudentEntity> students = [
    StudentEntity(id: 'student1', name: 'Fatima Ahmed', email: 'fatima.ahmed@school.mr', grade: 92),
    StudentEntity(id: 'student2', name: 'Ali Hassan', email: 'ali.hassan@school.mr', grade: 88),
    StudentEntity(id: 'student3', name: 'Mariam Ould', email: 'mariam.ould@school.mr', grade: 95),
    StudentEntity(id: 'student4', name: 'Omar Abdallah', email: 'omar.abdallah@school.mr', grade: 85),
    StudentEntity(id: 'student5', name: 'Aisha Salem', email: 'aisha.salem@school.mr', grade: 90),
    StudentEntity(id: 'student6', name: 'Mohammed Mint', email: 'mohammed.mint@school.mr', grade: 87),
  ];

  static final List<TimetableEntryEntity> timetable = [
    TimetableEntryEntity(id: 'tt1', day: 'Monday', time: '10:00 - 11:00', classId: 'class1', className: 'Mathematics - 4th Grade', teacher: 'Mohammed Ould', room: 'Room 201'),
    TimetableEntryEntity(id: 'tt2', day: 'Monday', time: '11:00 - 12:00', classId: 'class10', className: 'Mathematics - 6th Grade', teacher: 'Mohammed Ould', room: 'Room 202'),
    TimetableEntryEntity(id: 'tt5', day: 'Tuesday', time: '9:00 - 10:00', classId: 'class2', className: 'Arabic', teacher: 'Aisha Mint', room: 'Room 105'),
    TimetableEntryEntity(id: 'tt10', day: 'Wednesday', time: '9:00 - 10:00', classId: 'class7', className: 'English', teacher: 'John Smith', room: 'Room 204'),
    TimetableEntryEntity(id: 'tt20', day: 'Friday', time: '9:00 - 10:00', classId: 'class7', className: 'English', teacher: 'John Smith', room: 'Room 204'),
  ];

  static final List<LiveSessionEntity> liveSessions = [
    LiveSessionEntity(id: 'live1', classId: 'class1', title: 'Advanced Mathematics - Live Q&A', date: '2026-01-25', time: '10:00 AM', platform: LiveSessionPlatform.zoom, link: 'https://zoom.us/j/1234567890', isActive: true),
    LiveSessionEntity(id: 'live2', classId: 'class3', title: 'Physics Lab Session', date: '2026-01-25', time: '2:00 PM', platform: LiveSessionPlatform.meet, link: 'https://meet.google.com/abc-defg-hij', isActive: true),
    LiveSessionEntity(id: 'live3', classId: 'class2', title: 'Arabic Poetry Discussion', date: '2026-01-26', time: '9:00 AM', platform: LiveSessionPlatform.zoom, link: 'https://zoom.us/j/9876543210', isActive: false),
  ];

  static final List<NotificationEntity> notifications = [
    NotificationEntity(id: 'not1', type: NotificationType.student, from: 'Fatima Ahmed', message: 'Submitted assignment: Quadratic Equations Worksheet', timestamp: '2026-01-29T14:30:00', read: false),
    NotificationEntity(id: 'not2', type: NotificationType.student, from: 'Ali Hassan', message: 'Question about Systems of Equations lesson', timestamp: '2026-01-29T10:15:00', read: false),
    NotificationEntity(id: 'not3', type: NotificationType.admin, from: 'Administration', message: 'Reminder: Submit mid-term grades by February 5th', timestamp: '2026-01-28T09:00:00', read: true),
  ];

  static final List<StudentSubscriptionEntity> studentSubscriptions = [
    StudentSubscriptionEntity(studentId: 'student1', planId: 'plan2', enrolledClassIds: ['class1', 'class2', 'class3', 'class4', 'class5'], startDate: '2026-01-01', endDate: '2026-02-01', status: 'active'),
    StudentSubscriptionEntity(studentId: 'demo_student', planId: 'plan2', enrolledClassIds: ['class1', 'class2', 'class3', 'class4', 'class5'], startDate: '2026-01-01', endDate: '2026-02-01', status: 'active'),
  ];

  static const List<AttendanceRecord> attendanceRecords = [
    AttendanceRecord(id: 'att1', studentId: 'student1', classId: 'class1', date: '2026-01-20', status: 'present'),
    AttendanceRecord(id: 'att2', studentId: 'student1', classId: 'class1', date: '2026-01-22', status: 'present'),
    AttendanceRecord(id: 'att3', studentId: 'student1', classId: 'class1', date: '2026-01-24', status: 'late', notes: 'Arrived 10 minutes late'),
    AttendanceRecord(id: 'att4', studentId: 'student1', classId: 'class1', date: '2026-01-27', status: 'absent', notes: 'Sick leave'),
    AttendanceRecord(id: 'att5', studentId: 'student1', classId: 'class1', date: '2026-01-29', status: 'present'),
    AttendanceRecord(id: 'att6', studentId: 'student2', classId: 'class1', date: '2026-01-20', status: 'present'),
    AttendanceRecord(id: 'att7', studentId: 'student2', classId: 'class1', date: '2026-01-22', status: 'absent'),
    AttendanceRecord(id: 'att8', studentId: 'student3', classId: 'class1', date: '2026-01-20', status: 'present'),
    AttendanceRecord(id: 'att9', studentId: 'student3', classId: 'class1', date: '2026-01-24', status: 'present'),
  ];

  static const List<StudentProgressData> studentProgressList = [
    StudentProgressData(studentId: 'student1', classId: 'class1', overallGrade: 92, assignmentsCompleted: 3, assignmentsTotal: 4, present: 3, absent: 1, late: 1, total: 5, lastActivity: '2026-01-26T14:30:00'),
    StudentProgressData(studentId: 'student2', classId: 'class1', overallGrade: 88, assignmentsCompleted: 2, assignmentsTotal: 4, present: 2, absent: 2, late: 1, total: 5, lastActivity: '2026-01-27T16:20:00'),
    StudentProgressData(studentId: 'student3', classId: 'class1', overallGrade: 95, assignmentsCompleted: 4, assignmentsTotal: 4, present: 4, absent: 0, late: 1, total: 5, lastActivity: '2026-01-29T09:15:00'),
    StudentProgressData(studentId: 'student4', classId: 'class1', overallGrade: 65, assignmentsCompleted: 1, assignmentsTotal: 4, present: 2, absent: 3, late: 0, total: 5, lastActivity: '2026-01-25T10:00:00'),
    StudentProgressData(studentId: 'student5', classId: 'class1', overallGrade: 78, assignmentsCompleted: 2, assignmentsTotal: 4, present: 2, absent: 2, late: 1, total: 5, lastActivity: '2026-01-28T11:00:00'),
  ];
}

class AttendanceRecord {
  final String id;
  final String studentId;
  final String classId;
  final String date;
  final String status;
  final String? notes;
  const AttendanceRecord({required this.id, required this.studentId, required this.classId, required this.date, required this.status, this.notes});
}

class StudentProgressData {
  final String studentId;
  final String classId;
  final int overallGrade;
  final int assignmentsCompleted;
  final int assignmentsTotal;
  final int present;
  final int absent;
  final int late;
  final int total;
  final String lastActivity;
  const StudentProgressData({
    required this.studentId,
    required this.classId,
    required this.overallGrade,
    required this.assignmentsCompleted,
    required this.assignmentsTotal,
    required this.present,
    required this.absent,
    required this.late,
    required this.total,
    required this.lastActivity,
  });
}
