import 'subject_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentHomeScreen extends StatelessWidget {
  final String roll;
  final String universityId;
  final String departmentId;

  const StudentHomeScreen({
    super.key,
    required this.roll,
    required this.universityId,
    required this.departmentId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Dashboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// Student Info
            Text(
              "Welcome: $roll",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Your Subjects",
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
                          onTap: () {
                            Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => SubjectDetailsScreen(
      universityId: universityId,
      departmentId: departmentId,
      subjectId: doc.id,
      role: "Student",
      userRoll: int.parse(roll), // 👈 PASS HERE
    ),
  ),
);

                          },
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
