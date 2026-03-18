# High School Management Backend API Documentation

## Postman Collection

A Postman collection with **all endpoints** from this document is available as:

**`docs/High_School_Management_API.postman_collection.json`**

- **Import in Postman:** File → Import → Upload the JSON file.
- **Collection variables:** `base_url` (default: `http://103.208.181.235:5005`), `token`, `admin_token`, `teacher_token`, `student_token`, `grade_id`, `subject_id`, `class_id`, `lesson_id`, `assignment_id`, `session_id`, `student_id`, `submission_id`, `user_id`. Set `token` (or role-specific token) after login for protected routes.
- **Auth:** Collection uses Bearer token; set `token` in collection variables after `POST /auth/login` (e.g. from response `data.token`).

---

## API List (All Endpoints)

- **Base & Health**
  - `GET /health`
  - `GET /`
  - `GET /uploads/...`

- **Auth APIs**
  - `POST /auth/register` (Public)
  - `POST /auth/login` (Public)
  - `POST /otp/send` (Public)
  - `POST /otp/verify` (Public)
  - `POST /otp/resend` (Public)
  - `GET /sms/statistics` (Public)
  - `GET /auth/me` (Auth)

- **Student Screen APIs**
  - **Home Dashboard**
    - `GET /students/dashboard` (Student)
    - `GET /students/progress/overview` (Student)
  - **Classes**
    - `GET /students/student/classes` (Student)
    - `GET /classes/student/my` (Student)
    - 'GET /classes/student/:classId' (Student) // Singel classs  
    

  - **Timetable**
    - `GET /students/timetable` (Student)
  - **Live Sessions**
    - `GET /sessions/student` (Student)
    - `GET /sessions/student/:id` (Student)
    - `GET /sessions/:id` (Auth)
    - `POST /sessions/:id/join` (Student)
  - **Assignments**
    - `GET /assignments/student/my` (Student)
    - `GET /assignments/scope?gradeId={{grade_id}}&subjectId={{subject_id}}` (Student)
    - `GET /assignments/:assignmentId` (Student)
  - **Submit Assignment**
    - `POST /submission/:assignmentId/submit` (Student)
    - `GET /submission/assignments/:assignmentId/submission/me` (Student)
  - **Lessons**
    - `GET /lesson/scope?gradeId={{grade_id}}&subjectId={{subject_id}}` (Student)
    - `GET /lesson/:lessonId` (Student)

- **Teacher Screen APIs**
  - **Dashboard**
    - `GET /teachers/dashboard` (Teacher)
  - **Classes**
    - `GET /classes/my` (Teacher)
    - `GET /classes/:classId` (Teacher, Admin)
  - **Students**
    - `GET /teachers/students?search=` (Teacher)
    - `GET /teachers/stats/students?subject=&gradeLevel=&search=` (Teacher)
    - `GET /teachers/students/:studentId/progress?classId={{class_id}}` (Teacher)
    - `GET /teachers/students/:studentId/attendance?classId={{class_id}}` (Teacher)
    - `POST /teachers/students/:studentId/attendance` (Teacher)
  - **Lessons**
    - `POST /lesson` (Teacher/Admin)
    - `PATCH /lesson/:lessonId` (Teacher/Admin)
    - `DELETE /lesson/:lessonId` (Teacher/Admin)
  - **Assignments**
    - `POST /assignments` (Teacher)
    - `PATCH /assignments/:assignmentId` (Teacher/Admin)
    - `DELETE /assignments/:assignmentId` (Teacher/Admin)
    - `GET /assignments/:assignmentId/submissions` (Teacher)
  - **Grade Submission**
    - `PATCH /submission/submissions/:submissionId/grade` (Teacher)
  - **Live Sessions**
    - `POST /sessions` (Teacher)
    - `GET /sessions/teacher` (Teacher)
    - `GET /sessions/teacher/:id` (Teacher)
    - `PUT /sessions/:id` (Teacher)
    - `PUT /sessions/:id/complete` (Teacher)
    - `DELETE /sessions/:id` (Teacher/Admin)
  - **Attendance**
    - `POST /attendance/classes/:classId` (Teacher/Admin)
    - `GET /attendance/classes/:classId?from=&to=` (Teacher/Admin)
    - `GET /attendance/students/:studentId/summary?from=&to=` (Teacher/Admin)

- **Admin Panel APIs (`/admin`)**
  - **Dashboard**
    - `GET /admin/dashboard/overview`
  - **User Management**
    - `GET /admin/users/stats`
    - `GET /admin/users`
    - `POST /admin/users`
    - `PATCH /admin/users/:id/status`
    - `PATCH /admin/users/:id`
    - `DELETE /admin/users/:id`
  - **Classes & Content (Classes tab)**
    - `GET /admin/classes?page=1&limit=20`
    - `POST /admin/classes`
    - `PATCH /admin/classes/:id`
    - `DELETE /admin/classes/:id`
    - `GET /admin/subjects/summary`
    - `GET /admin/grades/sections`
    - `GET /admin/content/stats`
  - **Classes & Content (Content Library / Lessons tab)**
    - `GET /admin/lessons/meta`
    - `GET /admin/lessons?page=1&limit=20&status=all&contentType=all`
    - `GET /admin/lessons/:id`
    - `PATCH /admin/lessons/:id`
    - `DELETE /admin/lessons/:id`
  - **Assignments**
    - `GET /admin/assignments/stats`
    - `GET /admin/assignments`
    - `POST /admin/assignments`
    - `PATCH /admin/assignments/:id`
    - `GET /admin/assignments/:id/submissions`
  - **Live Sessions**
    - `GET /admin/live-sessions/stats`
    - `GET /admin/live-sessions`
    - `POST /admin/live-sessions`
    - `PATCH /admin/live-sessions/:id`
    - `PATCH /admin/live-sessions/:id/approve`
    - `PATCH /admin/live-sessions/:id/reject`
    - `DELETE /admin/live-sessions/:id`
  - **Timetable**
    - `GET /admin/timetable/meta`
    - `GET /admin/timetable`
    - `POST /admin/timetable/entries`
    - `PATCH /admin/timetable/entries/:id`
    - `DELETE /admin/timetable/entries/:id`
  - **Notifications**
    - `GET /admin/notifications/stats`
    - `GET /admin/notifications/:id/stats`
    - `GET /admin/notifications`
    - `POST /admin/notifications`
    - `PATCH /admin/notifications/:id`
  - **Settings**
    - `GET /admin/settings/subjects-grades`
    - `GET /admin/settings`
    - `PATCH /admin/settings/general`
    - `PATCH /admin/settings/theme`
    - `PATCH /admin/settings/security`
  - **Analytics**
    - `GET /admin/analytics/overview?from=&to=`
    - `GET /admin/analytics/student-progress?from=&to=`
    - `GET /admin/analytics/teacher-activity?from=&to=`

- **Core Non-Admin APIs**
  - **Users**
    - `POST /users` (Admin)
    - `GET /users/me` (Auth)
    - `GET /users` (Admin)
    - `GET /users/:id` (Admin)
    - `PATCH /users/:id/assigned-subjects` (Admin)
    - `PATCH /users/:id` (Admin)
    - `DELETE /users/:id` (Admin)
  - **Classes**
    - `POST /classes` (Admin)
    - `GET /classes/my` (Teacher)
    - `GET /classes/student/my` (Student)
    - `GET /classes/admin` (Admin)
    - `GET /classes/:classId` (Admin, Teacher)
    - `PATCH /classes/:classId/schedule` (Admin)
    - `PUT /classes/:classId/schedule` (Admin)
  - **Profiles**
    - `POST /profiles` (Auth)
    - `POST /profiles/:userId` (Admin)
    - `GET /profiles/me` (Auth)
    - `PATCH /profiles/me` (Auth)
    - `DELETE /profiles/me` (Auth)
    - `GET /profiles` (Admin)
    - `GET /profiles/:id` (Admin)
    - `PATCH /profiles/:id` (Admin)
    - `DELETE /profiles/:id` (Admin)
  - **Attendance**
    - `POST /attendance/classes/:classId` (Teacher/Admin)
    - `GET /attendance/classes/:classId?from=&to=` (Teacher/Admin)
    - `GET /attendance/students/:studentId/summary?from=&to=` (Teacher/Admin)
  - **Subjects**
    - `GET /subjects` (Auth)
    - `GET /subjects/:id` (Auth)
    - `POST /subjects` (Admin)
    - `PATCH /subjects/:id` (Admin)
    - `DELETE /subjects/:id` (Admin)
  - **Grades**
    - `GET /grades` (Auth)
    - `GET /grades/:id` (Auth)
    - `POST /grades` (Admin)
    - `PATCH /grades/:id` (Admin)
    - `DELETE /grades/:id` (Admin)

## Base Info
- Base URL: `{{base_url}}/api/v1`
- Auth: `Authorization: Bearer {{token}}`
- Health: `GET /health`
- Root ping: `GET /`
- Static uploads: `GET /uploads/...`

## Common Response Shapes
- Success (most routes):
```json
{
  "status": "success",
  "message": "Request successful",
  "data": {}
}
```
- Success (some routes):
```json
{
  "success": true,
  "data": {}
}
```
- Error:
```json
{
  "status": "fail",
  "message": "Error message"
}
```

## GET API Response — data তে কী কী আসে

নিচের তালিকায় প্রতিটি GET API এর `data` (অথবা response body) তে কোন কোন ফিল্ড/অবজেক্ট আসে সেটা দেওয়া হয়েছে। সব জায়গায় বাহিরের wrapper (`status`, `message`, `data` বা `success`, `data`) একই রকম; শুধু `data` এর ভেতরের structure আলাদা।

### Base & Health
- **`GET /health`** — Plain text: `"API is healthy"`.
- **`GET /`** — Root ping (implementation-specific; সাধারণত plain text বা minimal JSON).

### Auth
- **`GET /sms/statistics`** — `data`: SMS provider এর response যেরকম আসে (balance/statistics object — provider-dependent).
- **`GET /auth/me`** — `data`: `{ id, role, name, phone, gradeId?, gradeLevel?, assignedSubjectIds?, assignedSubjects?, subjectId?, subject?, assignedGradeIds?, assignedGrades? }` (role অনুযায়ী শুধু প্রযোজ্য ফিল্ডগুলো).

### Student
- **`GET /students/dashboard`** — `data`: `{ cards: { enrolledClasses, pendingAssignments, completed, liveSessions }, activeLiveSessions: [{ id, title, subject, date, time, status, zoomLink }], upcomingAssignments: [{ id, title, dueAt, points, myStatus }], progressOverview: [{ subject, percentage }] }`.
- **`GET /students/progress/overview`** — `data`: `{ overview: [{ subject, totalScore, totalPoints, gradedCount, percentage }], summary: { averagePercentage, subjectsCount, gradedAssignments } }`.
- **`GET /students/student/classes`** / **`GET /classes/student/my`** — `data`: Array of `{ classId, subject, gradeLevel, teacher: { id, name }, studentsCount, maxStudents, status }`.
- **`GET /students/timetable`** — `data`: `{ today: "mon"|"tue"|..., groupedByDay: { sun: [], mon: [], ... } }` — প্রতিটি slot: `{ classId, subject, gradeLevel, teacher: { id, name }, startMin, endMin, startTime, endTime }`.
- **`GET /sessions/student`** — `data`: Session documents array (populate teacher); প্রতিটিতে `myAttendance`, `hasJoined` সহ।
- **`GET /sessions/student/:id`** / **`GET /sessions/:id`** — `data`: Single session (teacher, attendance.student populated).
- **`GET /assignments/student/my`** — `data`: `{ data: assignment[], meta: { studentGrade, studentSubjects, matchedAssignmentCount } }` — প্রতিটি assignment এ `myStatus`, `myGrade` থাকতে পারে।
- **`GET /assignments/scope?gradeId=&subjectId=`** — `data`: Assignment array with `myStatus`, `myGrade` per item.
- **`GET /assignments/:assignmentId`** — `data`: `{ assignment, submission }` (student এর নিজের submission থাকলে).
- **`GET /submission/assignments/:assignmentId/submission/me`** — `data`: Single submission document (latest by submittedAt) অথবা null — fields: `submittedAt`, `status`, `grade`, `file`, `textAnswer` ইত্যাদি।
- **`GET /lesson/scope?gradeId=&subjectId=`** — `data`: Lesson array (gradeId, subjectId populated); student এর জন্য শুধু `status: "published"`.
- **`GET /lesson/:lessonId`** — `data`: Single lesson (gradeId, subjectId populated); fields: `title`, `description`, `contentType`, `chapter`, `status`, `files`, `date`, ইত্যাদি।

### Teacher
- **`GET /teachers/dashboard`** — `data`: `{ cards: { myClasses, totalStudents, pendingGrading, graded }, todaysClasses: [{ classId, subject, gradeLevel, studentsCount, startMin, endMin }], upcomingLiveSessions, recentSubmissions: [{ assignmentId, student: { id, name }, submittedAt, graded }], myClassesPreview: [{ id, subject, gradeLevel, studentsCount }] }`.
- **`GET /classes/my`** — `data`: Class documents array (teacher এর নিজের classes) — `_id`, `subject`, `subjectId`, `gradeLevel`, `gradeId`, `teacher`, `students`, `maxStudents`, `status`, `schedule`, `createdAt`.
- **`GET /classes/:classId`** — `data`: Single class (same fields as above).
- **`GET /teachers/students?search=`** — `data`: `{ data: [{ id, name, email, phone, gradeLevel, subjects, avgGrade, classes: [{ classId, subject, gradeLevel }], classesCount }], meta: { total } }`.
- **`GET /teachers/stats/students?subject=&gradeLevel=&search=`** — `data`: `{ totalStudents, subject, gradeLevel, students: [{ id, name, avgGrade, gradeLevel, classes }] }`.
- **`GET /teachers/students/:studentId/progress?classId=`** — `data`: `{ student, selectedClassId, performanceOverview: { overallGrade, assignmentCompletion, attendanceRate, lastActivity, gradedAssignments, totalAssignments }, attendanceTracking: { summary: { present, absent, late, total, attendanceRate }, recentRecords }, assignmentProgress: [{ assignmentId, title, dueAt, points, status, score }] }`.
- **`GET /teachers/students/:studentId/attendance?classId=`** — `data`: `{ summary: { present, absent, late, total, attendanceRate }, recentRecords: [{ classId, date, status }] }`.
- **`GET /assignments/:assignmentId/submissions`** — `data`: `{ assignment, submissions }` — submissions এ প্রতিটিতে `studentId` (populate name, role), `submittedAt`, `grade`, `status` ইত্যাদি।
- **`GET /sessions/teacher`** — `data`: Session array (teacher populate, approvalStatus populated).
- **`GET /sessions/teacher/:id`** — Same as single session by id.
- **`GET /attendance/classes/:classId?from=&to=`** — `data`: Attendance sheets array — প্রতিটিতে `date`, `records` (studentId populated: _id, name, gradeLevel), `status`, `notes`.
- **`GET /attendance/students/:studentId/summary?from=&to=`** — `data`: `{ student, totals: { Present, Absent, Late, total, presentRate }, records: [{ classId, date, status, notes, gradeLevel, subject, teacher }] }`.

### Admin
- **`GET /admin/dashboard/overview`** — `data`: `{ cards: { totalStudents, totalTeachers, activeClasses, liveSessionsToday, assignmentsPending, engagementRate }, cardsDelta: { totalStudentsPct, totalTeachersPct, ... }, weeklyActivity: [{ day, date, students, teachers, sessions }], studentDistributionByGrade: [{ grade, count, percentage }], averageSubjectPerformance: [{ subject, averagePercentage, gradedCount }], recentActivities: [{ id, actor, actorRole, action, entityType, entityId, summary, metadata, createdAt }] }`.
- **`GET /admin/users/stats`** — `data`: `{ totalStudents, totalTeachers, activeUsers, inactiveUsers, totalUsers }`.
- **`GET /admin/users`** — `data`: `{ data: [{ id, name, phone, email, role, status, gradeId, gradeLevel, subjectId, subject, assignedGradeIds, assignedGrades, assignedSubjectIds, assignedSubjects, assignedClasses, assignedClassesCount, createdVia, joinDate, createdAt, updatedAt }], meta: { page, limit, total, totalPages } }`.
- **`GET /admin/classes?page=&limit=`** — `data`: `{ data: class[], meta: { page, limit, total, totalPages } }` — class এ teacher/students populate থাকতে পারে।
- **`GET /admin/subjects/summary`** — `data`: Subjects summary (list/count).
- **`GET /admin/grades/sections`** — `data`: Grades/sections list.
- **`GET /admin/content/stats`** — `data`: Content (lessons/assignments) related counts/stats.
- **`GET /admin/lessons/meta`** — Meta for filters (grades, subjects, status options ইত্যাদি).
- **`GET /admin/lessons?page=&limit=&status=&contentType=`** — `data`: `{ data: lesson[], meta: { page, limit, total, totalPages } }` — gradeId, subjectId, classId, createdBy populated.
- **`GET /admin/lessons/:id`** — `data`: Single lesson (same populates).
- **`GET /admin/assignments/stats`** — `data`: Counts by status (active, upcoming, closed, draft, total).
- **`GET /admin/assignments`** — `data`: `{ data: assignment[], meta }` — assignment এ gradeId, subjectId, classInfo ইত্যাদি।
- **`GET /admin/assignments/:id/submissions`** — `data`: `{ assignment, submissions }`.
- **`GET /admin/live-sessions/stats`** — `data`: `{ todaysSessions, liveNow, pendingApproval, avgAttendance }`.
- **`GET /admin/live-sessions`** — `data`: `{ data: session[], meta: { tab, page, limit, total, totalPages } }` — session এ id, title, teacher, grade, subject, date, time, duration, zoomLink, status, pendingApproval, attendanceRate, joinedCount, totalAttendance ইত্যাদি।
- **`GET /admin/timetable/meta`** — `data`: Meta for timetable (grades, sections, teachers ইত্যাদি).
- **`GET /admin/timetable`** — `data`: Timetable entries (mode=general|class, day/gradeId/section filter অনুযায়ী).
- **`GET /admin/notifications/stats`** — `data`: Notification counts/stats.
- **`GET /admin/notifications/:id/stats`** — `data`: Single notification stats (delivered, read ইত্যাদি).
- **`GET /admin/notifications`** — `data`: Notifications list with meta.
- **`GET /admin/settings/subjects-grades`** — `data`: `{ subjects, grades }`.
- **`GET /admin/settings`** — `data`: `{ general: {}, theme: {}, security: {}, other: {} }` — key-value by group.
- **`GET /admin/analytics/overview?from=&to=`** — `data`: Analytics overview (totalActiveUsers, dailyActiveUsers, totalUsers, avgSessionDuration, studentsByDay, teachersByDay, attendance breakdown, submission weekly, pending weekly, grade performance ইত্যাদি).
- **`GET /admin/analytics/student-progress?from=&to=`** — `data`: Student progress analytics.
- **`GET /admin/analytics/teacher-activity?from=&to=`** — `data`: Teacher activity analytics.

### Core (Users, Classes, Profiles, Attendance, Subjects, Grades)
- **`GET /users/me`** — `data`: Current user object (id, role, name, phone, gradeId/gradeLevel বা subjectId/subject, assigned* fields).
- **`GET /users`** (Admin) — `data`: User array (filter by role, status, createdVia).
- **`GET /users/:id`** (Admin) — `data`: Single user document.
- **`GET /classes/my`** (Teacher) — Same as Teacher section above.
- **`GET /classes/student/my`** (Student) — Same as Student classes above.
- **`GET /classes/admin`** — `data`: All classes for admin.
- **`GET /classes/:classId`** — `data`: Single class.
- **`GET /profiles/me`** — `data`: Profile for current user (user populated; role-based teacherInfo/studentInfo সহ); role, name, email, phone profile থেকে আসে না (user থেকে).
- **`GET /profiles`** (Admin) — `data`: Profile array (filter by role).
- **`GET /profiles/:id`** (Admin) — `data`: Single profile.
- **`GET /attendance/classes/:classId?from=&to=`** — Same as Teacher attendance above.
- **`GET /attendance/students/:studentId/summary?from=&to=`** — Same as Teacher section above.
- **`GET /subjects`** — `data`: Subject array (name, code, description, color, isActive ইত্যাদি).
- **`GET /subjects/:id`** — `data`: Single subject.
- **`GET /grades`** — `data`: Grade array (label, isActive ইত্যাদি).
- **`GET /grades/:id`** — `data`: Single grade.

---
- `base_url`
- `admin_token`
- `teacher_token`
- `student_token`
- `grade_id`
- `subject_id`
- `class_id`
- `lesson_id`
- `assignment_id`
- `session_id`
- `student_id`
- `submission_id`
- `phone`
- `otp`

---

## 1) Auth APIs

### `POST /auth/register` (Public)
Create student/teacher/admin account.

Student example:
```json
{
  "role": "student",
  "name": "Fatima Ahmed",
  "phone": "24587569",
  "pin": "1234",
  "confirmPin": "1234",
  "gradeId": "{{grade_id}}",
  "assignedSubjectIds": ["{{subject_id}}"]
}
```

Teacher example:
```json
{
  "role": "teacher",
  "name": "Alice",
  "phone": "34587569",
  "pin": "1234",
  "confirmPin": "1234",
  "subjectId": "{{subject_id}}",
  "assignedGradeIds": ["{{grade_id}}"]
}
```

Notes:
- If you send labels instead of IDs, use:
  - `gradeLevel`, `assignedSubjects`, `subject`, `assignedGrades`
- `assignedGrades` must be labels (`"4th"`, `"5th"`, `"6th"`, `"7th"`), not ObjectId.

### `POST /auth/login` (Public)
```json
{
  "phone": "24587569",
  "pin": "1234"
}
```

### `POST /otp/send` (Public)
Send OTP to phone via SMS provider.
```json
{
  "phone": "33445566"
}
```

### `POST /otp/verify` (Public)
Verify received OTP code.
```json
{
  "phone": "33445566",
  "otp": "4821"
}
```

### `POST /otp/resend` (Public)
Resend OTP for active OTP session.
```json
{
  "phone": "33445566"
}
```

### `GET /sms/statistics` (Public)
Fetch SMS provider statistics/balance.

### `GET /auth/me` (Auth)

---

## 2) Student Screen APIs

### Home Dashboard
- `GET /students/dashboard` (Student)
- `GET /students/progress/overview` (Student)

### Classes
- `GET /students/student/classes` (Student)
- `GET /classes/student/my` (Student)

### Timetable
- `GET /students/timetable` (Student)

### Live Sessions
- `GET /sessions/student` (Student)
- `GET /sessions/student/:id` (Student)
- `GET /sessions/:id` (Auth)
- `POST /sessions/:id/join` (Student)

### Assignments
- `GET /assignments/student/my` (Student)
- `GET /assignments/scope?gradeId={{grade_id}}&subjectId={{subject_id}}` (Student)
- `GET /assignments/:assignmentId` (Student)

### Submit Assignment
- `POST /submission/:assignmentId/submit` (Student, `multipart/form-data`)
  - file key: `file` (optional)
  - text key: `textAnswer` (optional)
- `GET /submission/assignments/:assignmentId/submission/me` (Student)

### Lessons
- `GET /lesson/scope?gradeId={{grade_id}}&subjectId={{subject_id}}` (Student)
- `GET /lesson/:lessonId` (Student)

---

## 3) Teacher Screen APIs

### Dashboard
- `GET /teachers/dashboard` (Teacher)

### Classes
- `GET /classes/my` (Teacher)
- `GET /classes/:classId` (Teacher, Admin)

### Students
- `GET /teachers/students?search=` (Teacher)
- `GET /teachers/stats/students?subject=&gradeLevel=&search=` (Teacher)
- `GET /teachers/students/:studentId/progress?classId={{class_id}}` (Teacher)
- `GET /teachers/students/:studentId/attendance?classId={{class_id}}` (Teacher)
- `POST /teachers/students/:studentId/attendance` (Teacher)
```json
{
  "classId": "{{class_id}}",
  "status": "Present",
  "date": "2026-02-24"
}
```

### Lessons
- `POST /lesson` (Teacher/Admin, `multipart/form-data`)
- `PATCH /lesson/:lessonId` (Teacher/Admin, `multipart/form-data`)
- `DELETE /lesson/:lessonId` (Teacher/Admin)

Create lesson form-data fields:
- `title` (required)
- `description`
- `contentType` (`text`, `pdf`, `video`, `image`, `quiz`, required)
- `chapter` (required)
- `status` (`draft` or `published`)
- `gradeId` (required)
- `subjectId` (required)
- `classId` (optional)
- `date` (optional, ISO/string)
- `files` (required when `contentType=pdf|video|image`)

### Assignments
- `POST /assignments` (Teacher, `multipart/form-data`)
- `PATCH /assignments/:assignmentId` (Teacher/Admin)
- `DELETE /assignments/:assignmentId` (Teacher/Admin)
- `GET /assignments/:assignmentId/submissions` (Teacher)

Create assignment fields:
- `title` (required)
- `description`
- `dueDate` (required, `YYYY-MM-DD`)
- `dueTime` (optional, `HH:mm`)
- `points` (required, >0)
- `gradeId` (required)
- `subjectId` (required)
- `classId` (optional)
- file key: `file` (optional)

### Grade Submission
- `PATCH /submission/submissions/:submissionId/grade` (Teacher)
```json
{
  "score": 90,
  "feedback": "Good work"
}
```

### Live Sessions
- `POST /sessions` (Teacher)
- `GET /sessions/teacher` (Teacher)
- `GET /sessions/teacher/:id` (Teacher)
- `PUT /sessions/:id` (Teacher)
- `PUT /sessions/:id/complete` (Teacher)
- `DELETE /sessions/:id` (Teacher/Admin)

Create session example:
```json
{
  "title": "Mathematics Q&A Session",
  "gradeId": "{{grade_id}}",
  "subjectId": "{{subject_id}}",
  "classId": "{{class_id}}",
  "className": "5th Grade - Math A",
  "date": "2026-02-25",
  "time": "10:00",
  "duration": 60,
  "zoomLink": "https://zoom.us/j/12345678901"
}
```

### Attendance
- `POST /attendance/classes/:classId` (Teacher/Admin)
- `GET /attendance/classes/:classId?from=&to=` (Teacher/Admin)
- `GET /attendance/students/:studentId/summary?from=&to=` (Teacher/Admin)

Mark class attendance:
```json
{
  "date": "2026-02-24",
  "records": [
    { "studentId": "{{student_id_1}}", "status": "Present", "notes": "On time" },
    { "studentId": "{{student_id_2}}", "status": "Late", "notes": "10 min late" },
    { "studentId": "{{student_id_3}}", "status": "Absent", "notes": "Sick leave" }
  ]
}
```

Status values:
- `Present`
- `Absent`
- `Late`

Important:
- Class must already contain students in `class.students`.
- Assign class students using admin class update:
  - `PATCH /admin/classes/:id`
  - body: `{ "students": ["studentId1", "studentId2"] }`

---

## 4) Admin Panel APIs (`/admin`)

### Dashboard
- `GET /admin/dashboard/overview`

### User Management
- `GET /admin/users/stats`
- `GET /admin/users`
- `POST /admin/users`
- `PATCH /admin/users/:id/status`
- `PATCH /admin/users/:id`
- `DELETE /admin/users/:id`

### Classes & Content (Classes tab)
- `GET /admin/classes?page=1&limit=20`
- `POST /admin/classes` (teacherId optional)
- `PATCH /admin/classes/:id`
- `DELETE /admin/classes/:id`
- `GET /admin/subjects/summary`
- `GET /admin/grades/sections`
- `GET /admin/content/stats`

### Classes & Content (Content Library / Lessons tab)
- `GET /admin/lessons/meta`
- `GET /admin/lessons?page=1&limit=20&status=all&contentType=all`
- `GET /admin/lessons/:id`
- `PATCH /admin/lessons/:id`
- `DELETE /admin/lessons/:id`

### Assignments
- `GET /admin/assignments/stats`
- `GET /admin/assignments`
- `POST /admin/assignments` (`multipart/form-data`)
- `PATCH /admin/assignments/:id` (`multipart/form-data`)
- `GET /admin/assignments/:id/submissions`

### Live Sessions
- `GET /admin/live-sessions/stats`
- `GET /admin/live-sessions`
- `POST /admin/live-sessions`
- `PATCH /admin/live-sessions/:id`
- `PATCH /admin/live-sessions/:id/approve`
- `PATCH /admin/live-sessions/:id/reject`
- `DELETE /admin/live-sessions/:id`

### Timetable
- `GET /admin/timetable/meta`
- `GET /admin/timetable`
- `POST /admin/timetable/entries`
- `PATCH /admin/timetable/entries/:id`
- `DELETE /admin/timetable/entries/:id`

### Notifications
- `GET /admin/notifications/stats`
- `GET /admin/notifications/:id/stats`
- `GET /admin/notifications`
- `POST /admin/notifications`
- `PATCH /admin/notifications/:id`

### Settings
- `GET /admin/settings/subjects-grades`
- `GET /admin/settings`
- `PATCH /admin/settings/general`
- `PATCH /admin/settings/theme`
- `PATCH /admin/settings/security`

### Analytics
- `GET /admin/analytics/overview?from=&to=`
- `GET /admin/analytics/student-progress?from=&to=`
- `GET /admin/analytics/teacher-activity?from=&to=`

---

## 5) Core Non-Admin APIs

### Users
- `POST /users` (Admin)
- `GET /users/me` (Auth)
- `GET /users` (Admin)
- `GET /users/:id` (Admin)
- `PATCH /users/:id/assigned-subjects` (Admin)
- `PATCH /users/:id` (Admin)
- `DELETE /users/:id` (Admin)

### Classes
- `POST /classes` (Admin)
- `GET /classes/my` (Teacher)
- `GET /classes/student/my` (Student)
- `GET /classes/admin` (Admin)
- `GET /classes/:classId` (Admin, Teacher)
- `PATCH /classes/:classId/schedule` (Admin)
- `PUT /classes/:classId/schedule` (Admin)

### Profiles
- `POST /profiles` (Auth, `multipart/form-data`)
- `POST /profiles/:userId` (Admin, `multipart/form-data`)
- `GET /profiles/me` (Auth)
- `PATCH /profiles/me` (Auth, `multipart/form-data`)
- `DELETE /profiles/me` (Auth)
- `GET /profiles` (Admin)
- `GET /profiles/:id` (Admin)
- `PATCH /profiles/:id` (Admin, `multipart/form-data`)
- `DELETE /profiles/:id` (Admin)

### Attendance
- `POST /attendance/classes/:classId` (Teacher/Admin)
- `GET /attendance/classes/:classId?from=&to=` (Teacher/Admin)
- `GET /attendance/students/:studentId/summary?from=&to=` (Teacher/Admin)

### Subjects
- `GET /subjects` (Auth)
- `GET /subjects/:id` (Auth)
- `POST /subjects` (Admin)
- `PATCH /subjects/:id` (Admin)
- `DELETE /subjects/:id` (Admin)

### Grades
- `GET /grades` (Auth)
- `GET /grades/:id` (Auth)
- `POST /grades` (Admin)
- `PATCH /grades/:id` (Admin)
- `DELETE /grades/:id` (Admin)

---

## 6) Suggested Postman Test Order (Screen-by-Screen)

1. `POST /auth/login` (admin)  
2. Admin setup: grades, subjects, class, teacher, student  
3. `POST /auth/login` (teacher)  
4. Teacher quick actions: create lesson, assignment, session  
5. `POST /auth/login` (student)  
6. Student home: dashboard, progress overview  
7. Student classes + timetable  
8. Student assignments + submit  
9. Student live sessions + join  
10. Teacher students tab: progress + attendance + mark attendance  
11. Admin panel routes (`/admin/...`) verification

---

## 7) Important Implementation Notes
- Prefer ID-first payloads:
  - `gradeId`, `subjectId`, `assignedGradeIds`, `assignedSubjectIds`, `classId`
- String fallbacks are still supported in some flows:
  - `gradeLevel`, `subject`, `assignedGrades`, `assignedSubjects`
- File upload keys:
  - Lessons: `files`
  - Assignments: `file` (teacher routes), `files` (admin routes)
  - Submissions: `file`
  - Profiles: `profileImage`
- `POST /admin/classes`: `teacherId` is optional. Backend can auto-assign matching teacher.
- S3 upload support:
  - Set `USE_S3=true` and configure:
    - `AWS_REGION`
    - `AWS_S3_BUCKET`
    - `AWS_ACCESS_KEY_ID`
    - `AWS_SECRET_ACCESS_KEY`
  - Install deps:
    - `@aws-sdk/client-s3`
    - `multer-s3`
  - If `USE_S3` is false, uploads continue to local `/uploads`.

---

## 8) Demo Payloads For All POST APIs (Postman Ready)

Base prefix for all routes below: `{{base_url}}/api/v1`

### Auth

`POST /auth/register` (student)
```json
{
  "role": "student",
  "name": "Fatima Ahmed",
  "phone": "24587569",
  "pin": "1234",
  "confirmPin": "1234",
  "gradeId": "{{grade_id}}",
  "assignedSubjectIds": ["{{subject_id}}"]
}
```

`POST /auth/register` (teacher)
```json
{
  "role": "teacher",
  "name": "Mohammed Ould",
  "phone": "34587569",
  "pin": "1234",
  "confirmPin": "1234",
  "subjectId": "{{subject_id}}",
  "assignedGradeIds": ["{{grade_id}}"]
}
```

`POST /auth/login`
```json
{
  "phone": "24587569",
  "pin": "1234"
}
```

`POST /otp/send`
```json
{
  "phone": "33445566"
}
```

`POST /otp/verify`
```json
{
  "phone": "33445566",
  "otp": "4821"
}
```

`POST /otp/resend`
```json
{
  "phone": "33445566"
}
```

`GET /sms/statistics`

### Users

`POST /users` (admin create user)
```json
{
  "role": "student",
  "name": "Mariam Ould",
  "phone": "24567890",
  "pin": "1234",
  "gradeId": "{{grade_id}}",
  "assignedSubjectIds": ["{{subject_id}}"]
}
```

### Classes

`POST /classes` (admin)
```json
{
  "subjectId": "{{subject_id}}",
  "gradeId": "{{grade_id}}",
  "teacherId": "{{teacher_id}}",
  "maxStudents": 30,
  "status": "active",
  "schedule": [
    { "day": "mon", "startMin": 540, "endMin": 600 },
    { "day": "wed", "startMin": 540, "endMin": 600 }
  ]
}
```

### Lessons

`POST /lesson` (`multipart/form-data`, teacher/admin)

Form-data keys:
- `title`: `Introduction to Algebra`
- `description`: `Basic algebra concepts`
- `contentType`: `text` or `pdf`
- `chapter`: `Chapter 1`
- `status`: `published`
- `gradeId`: `{{grade_id}}`
- `subjectId`: `{{subject_id}}`
- `classId`: `{{class_id}}` (optional)
- `date`: `2026-02-24` (optional)
- `files`: upload file(s), required if `contentType=pdf`

### Assignments

`POST /assignments` (`multipart/form-data`, teacher)

Form-data keys:
- `title`: `Quadratic Equations Worksheet`
- `description`: `Solve problems 1-20`
- `dueDate`: `2026-02-27`
- `dueTime`: `10:00`
- `points`: `100`
- `gradeId`: `{{grade_id}}`
- `subjectId`: `{{subject_id}}`
- `classId`: `{{class_id}}` (optional)
- `file`: upload file (optional)

### Sessions

`POST /sessions` (teacher create live session)
```json
{
  "title": "Mathematics Q&A Session",
  "gradeId": "{{grade_id}}",
  "subjectId": "{{subject_id}}",
  "classId": "{{class_id}}",
  "className": "5th Grade - Math A",
  "date": "2026-02-25",
  "time": "10:00",
  "duration": 60,
  "zoomLink": "https://zoom.us/j/12345678901"
}
```

`POST /sessions/:id/join` (student)
```json
{}
```

### Submissions

`POST /submission/:assignmentId/submit` (`multipart/form-data`, student)

Form-data keys:
- `file`: upload file (optional)
- `textAnswer`: `My written response...` (optional)

### Profiles

`POST /profiles` (`multipart/form-data`, auth user)
```json
{
  "email": "fatima@gmail.com",
  "address": "Nouadhibou, Mauritania",
  "studentInfo": {
    "parentName": "Ahmed Hassan",
    "parentPhone": "45678902",
    "parentEmail": "parent@gmail.com"
  }
}
```

`POST /profiles/:userId` (`multipart/form-data`, admin)
```json
{
  "email": "teacher@gmail.com",
  "address": "Nouakchott, Mauritania",
  "teacherInfo": {
    "department": "Science",
    "qualifications": "BSc Physics",
    "officeHours": "Mon-Wed 10:00-12:00",
    "bio": "Physics teacher"
  }
}
```

### Attendance

`POST /attendance/classes/:classId` (teacher/admin)
```json
{
  "date": "2026-02-24",
  "records": [
    { "studentId": "{{student_id_1}}", "status": "Present", "notes": "On time" },
    { "studentId": "{{student_id_2}}", "status": "Late", "notes": "10 min late" }
  ]
}
```

### Teacher

`POST /teachers/students/:studentId/attendance` (teacher)
```json
{
  "classId": "{{class_id}}",
  "status": "Present",
  "date": "2026-02-24"
}
```

### Subjects

`POST /subjects` (admin)
```json
{
  "name": "Mathematics",
  "code": "MATH",
  "description": "Mathematics subject",
  "color": "#1f3c88"
}
```

### Grades

`POST /grades` (admin)
```json
{
  "label": "5th"
}
```

### Admin - Users

`POST /admin/users`
```json
{
  "role": "teacher",
  "name": "John Smith",
  "phone": "39876543",
  "pin": "1234",
  "subjectId": "{{subject_id}}",
  "assignedGradeIds": ["{{grade_id}}"]
}
```

### Admin - Classes

`POST /admin/classes` (teacherId optional)
```json
{
  "subjectId": "{{subject_id}}",
  "gradeId": "{{grade_id}}",
  "teacherId": "{{teacher_id}}",
  "students": ["{{student_id_1}}", "{{student_id_2}}"],
  "maxStudents": 35,
  "status": "active",
  "schedule": [
    { "day": "mon", "startMin": 540, "endMin": 600 }
  ]
}
```

### Admin - Assignments

`POST /admin/assignments` (`multipart/form-data`)

Form-data keys:
- `classId`: `{{class_id}}`
- `title`: `Chapter 5 Homework`
- `description`: `Complete all exercises`
- `dueDate`: `2026-02-28`
- `dueTime`: `12:00`
- `points`: `100`
- `status`: `active`
- `lateAllowed`: `true`
- `files`: upload file(s) optional

### Admin - Live Sessions

`POST /admin/live-sessions`
```json
{
  "teacherId": "{{teacher_id}}",
  "title": "Algebra Live Session",
  "gradeId": "{{grade_id}}",
  "subjectId": "{{subject_id}}",
  "classId": "{{class_id}}",
  "className": "5th Grade - Math A",
  "date": "2026-02-26",
  "time": "09:00",
  "duration": 60,
  "zoomLink": "https://zoom.us/j/12345678901"
}
```

### Admin - Timetable

`POST /admin/timetable/entries`
```json
{
  "type": "class",
  "gradeId": "{{grade_id}}",
  "section": "A",
  "subjectId": "{{subject_id}}",
  "teacherId": "{{teacher_id}}",
  "classId": "{{class_id}}",
  "room": "Room 101",
  "day": "mon",
  "startMin": 540,
  "endMin": 600,
  "isActive": true
}
```

### Admin - Notifications

`POST /admin/notifications`
```json
{
  "title": "Exam Schedule Update",
  "message": "Midterm exams start next week.",
  "channel": "announcement",
  "priority": "high",
  "targetType": "roles",
  "target": {
    "roles": ["student", "teacher"]
  },
  "action": "send_now"
}
```
