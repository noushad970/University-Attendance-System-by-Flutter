import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'subject_details_screen.dart';

class CRHomeScreen extends StatelessWidget {
  final String universityId;
  final String departmentId;
  final String batch;
  final int roll;

  const CRHomeScreen({
    super.key,
    required this.universityId,
    required this.departmentId,
    required this.batch,
    required this.roll,
  });

  Future<bool> isBatchCR() async {
    final batchDoc = await FirebaseFirestore.instance
        .collection('universities')
        .doc(universityId)
        .collection('batches')
        .doc(batch)
        .get();

    int crRoll = batchDoc['crRoll'];
    return crRoll == roll;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Batch Dashboard")),

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
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, snapshot) {

              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator());
              }

              final subjects = snapshot.data!.docs;

              return ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {

                  final subject = subjects[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(subject['name']),
                      subtitle: Text(
                        isCR
                            ? "You are Batch CR"
                            : "Student",
                        style: TextStyle(
                          color:
                              isCR ? Colors.green : Colors.black,
                        ),
                      ),
                      trailing: Icon(
                        isCR
                            ? Icons.admin_panel_settings
                            : Icons.arrow_forward,
                        color:
                            isCR ? Colors.green : Colors.grey,
                      ),
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
