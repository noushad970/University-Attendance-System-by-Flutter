import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceService {

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static Future<void> startAttendance(
      String universityId,
      String departmentId,
      String subjectId) async {

    await _firestore
        .collection('universities')
        .doc(universityId)
        .collection('departments')
        .doc(departmentId)
        .collection('subjects')
        .doc(subjectId)
        .collection('attendanceSessions')
        .add({
      'date': DateTime.now(),
      'isActive': true,
      'presentStudents': [],
    });
  }

  static Future<void> giveAttendance(
      String universityId,
      String departmentId,
      String subjectId,
      String sessionId,
      int rollNumber) async {

    final docRef = _firestore
        .collection('universities')
        .doc(universityId)
        .collection('departments')
        .doc(departmentId)
        .collection('subjects')
        .doc(subjectId)
        .collection('attendanceSessions')
        .doc(sessionId);

    await docRef.update({
      'presentStudents': FieldValue.arrayUnion([rollNumber])
    });
  }

  static Future<void> closeAttendance(
      String universityId,
      String departmentId,
      String subjectId,
      String sessionId) async {

    await _firestore
        .collection('universities')
        .doc(universityId)
        .collection('departments')
        .doc(departmentId)
        .collection('subjects')
        .doc(subjectId)
        .collection('attendanceSessions')
        .doc(sessionId)
        .update({
      'isActive': false
    });
  }
}
