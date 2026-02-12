import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CRHomeScreen extends StatelessWidget {
  final String roll;
  final String universityId;
  final String departmentId;

  const CRHomeScreen({
    super.key,
    required this.roll,
    required this.universityId,
    required this.departmentId,
  });

  /// ==============================
  /// CREATE ATTENDANCE SESSION
  /// ==============================
  Future<void> createAttendance(
      String subjectId) async {

    await FirebaseFirestore.instance
        .collection('attendance_sessions')
        .add({
      'subjectId': subjectId,
      'universityId': universityId,
      'departmentId': departmentId,
      'createdBy': roll,
      'createdAt': Timestamp.now(),
      'isOpen': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CR Dashboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            Text(
              "CR: $roll",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Manage Subjects",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            /// Load Subjects
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('universities')
                    .doc(universityId)
                    .collection('departments')
                    .doc(departmentId)
                    .collection('subjects')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("No subjects available"));
                  }

                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      return Card(
                        child: ListTile(
                          title: Text(doc['name']),
                          subtitle: Text(
                              "Roll Range: ${doc['startRoll']} - ${doc['endRoll']}"),
                          trailing: ElevatedButton(
                            child: const Text("Start Attendance"),
                            onPressed: () async {
                              await createAttendance(doc.id);

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Attendance Started")),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
