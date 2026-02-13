import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectDetailsScreen extends StatelessWidget {
  final String universityId;
  final String departmentId;
  final String subjectId;
  final String role;
  final int userRoll;

  const SubjectDetailsScreen({
    super.key,
    required this.universityId,
    required this.departmentId,
    required this.subjectId,
    required this.role,
    required this.userRoll,
  });

  /// 🔹 Get All Rolls (Range + Extra)
  Future<List<int>> getAllRolls() async {
    final doc = await FirebaseFirestore.instance
        .collection('universities')
        .doc(universityId)
        .collection('departments')
        .doc(departmentId)
        .collection('subjects')
        .doc(subjectId)
        .get();

    int startRoll = doc['startRoll'];
    int endRoll = doc['endRoll'];
    List extra = doc['extraRolls'] ?? [];

    List<int> rolls = [];

    for (int i = startRoll; i <= endRoll; i++) {
      rolls.add(i);
    }

    rolls.addAll(extra.cast<int>());
    rolls.sort();

    return rolls;
  }

  /// 🔹 Start Attendance (Create Full Column)
  Future<void> startAttendance(List<int> rolls) async {
    Map<String, bool> attendanceMap = {};

    for (var roll in rolls) {
      attendanceMap[roll.toString()] = false;
    }

    await FirebaseFirestore.instance
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
      'attendance': attendanceMap,
    });
  }

  /// 🔹 Close Attendance
  Future<void> closeAttendance(String sessionId) async {
    await FirebaseFirestore.instance
        .collection('universities')
        .doc(universityId)
        .collection('departments')
        .doc(departmentId)
        .collection('subjects')
        .doc(subjectId)
        .collection('attendanceSessions')
        .doc(sessionId)
        .update({'isActive': false});
  }

  /// 🔹 Update Attendance
  Future<void> updateAttendance(
      String sessionId, int roll, bool value) async {
    await FirebaseFirestore.instance
        .collection('universities')
        .doc(universityId)
        .collection('departments')
        .doc(departmentId)
        .collection('subjects')
        .doc(subjectId)
        .collection('attendanceSessions')
        .doc(sessionId)
        .update({
      'attendance.${roll.toString()}': value
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Subject Attendance")),

      body: Column(
        children: [

          /// 🔴 CR START BUTTON
          if (role == "CR")
            FutureBuilder<List<int>>(
              future: getAllRolls(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return ElevatedButton(
                  onPressed: () async =>
                      await startAttendance(snapshot.data!),
                  child: const Text("Start Attendance"),
                );
              },
            ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('universities')
                .doc(universityId)
                .collection('departments')
                .doc(departmentId)
                .collection('subjects')
                .doc(subjectId)
                .collection('attendanceSessions')
                .where('isActive', isEqualTo: true)
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox();
              }

              final sessionId = snapshot.data!.docs.first.id;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Live Attendance Running",
                    style: TextStyle(color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  if (role == "CR")
                    ElevatedButton(
                      onPressed: () async {
                        await closeAttendance(sessionId);
                      },
                      child: const Text("Close Attendance"),
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),

          /// 📊 EXCEL STYLE TABLE
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('universities')
                  .doc(universityId)
                  .collection('departments')
                  .doc(departmentId)
                  .collection('subjects')
                  .doc(subjectId)
                  .collection('attendanceSessions')
                  .orderBy('date')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final sessions = snapshot.data!.docs;

                return FutureBuilder<List<int>>(
                  future: getAllRolls(),
                  builder: (context, rollSnapshot) {
                    if (!rollSnapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final rolls = rollSnapshot.data!;

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          const DataColumn(
                              label: Text("Roll No")),
                          ...sessions.map((session) {
                            DateTime date =
                                (session['date'] as Timestamp)
                                    .toDate();
                            return DataColumn(
                              label: Text(
                                  "${date.day}-${date.month}-${date.year}"),
                            );
                          }).toList(),
                        ],
                        rows: rolls.map((roll) {
                          return DataRow(
                            cells: [
                              DataCell(
                                  Text(roll.toString())),

                              ...sessions.map((session) {

                                Map attendance =
                                    session['attendance'];

                                bool isPresent =
                                    attendance[roll.toString()] ??
                                        false;

                                bool isActive =
                                    session['isActive'];

                                return DataCell(
                                  Checkbox(
                                    value: isPresent,
                                    onChanged: (!isActive)
                                        ? null
                                        : (value) async {
                                            if (role == "Student" && roll !=
                                                    userRoll) {
                                              return;
                                            }

                                            await updateAttendance(
                                                session.id,
                                                roll,
                                                !isPresent);
                                          },
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
