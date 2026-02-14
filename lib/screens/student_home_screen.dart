import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'subject_details_screen.dart';

class StudentHomeScreen extends StatelessWidget {
  final String universityId;
  final String departmentId;
  final String batch;
  final int roll;
  final String role;

  const StudentHomeScreen({
    super.key,
    required this.universityId,
    required this.departmentId,
    required this.batch,
    required this.roll,
    required this.role,
  });

  Future<bool> isBatchCR() async {
    final batchDoc = await FirebaseFirestore.instance
        .collection('universities')
        .doc(universityId)
        .collection('batches')
        .doc(batch)
        .get();

    if (!batchDoc.exists || batchDoc['crRoll'] == null) {
      return false;
    }

    int crRoll = batchDoc['crRoll'];
    return crRoll == roll;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Subjects"),
      ),

      body: FutureBuilder<bool>(
        future: isBatchCR(),
        builder: (context, crSnapshot) {
          if (!crSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          bool isCR = crSnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('universities')
                .doc(universityId)
                .collection('batches')
                .doc(batch)
                .collection('departments')
                .doc(departmentId)
                .collection('subjects')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (context, snapshot) {

              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator());
              }

              if (snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No subjects available",
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              final subjects = snapshot.data!.docs;

              return ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];

                  String subjectName = subject['name'];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(subjectName),
                      subtitle: Text(
                          isCR ? "You are Batch CR" : "Student"),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubjectDetailsScreen(
                              universityId: universityId,
                              departmentId: departmentId,
                              batch: batch,
                              subjectId: subject.id,
                              role: isCR ? "CR" : "Student",
                              userRoll: roll,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
