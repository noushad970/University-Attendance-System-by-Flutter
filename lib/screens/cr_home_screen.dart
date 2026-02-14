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

  /// ==========================
  /// Stylized Subject Card
  /// ==========================
  Widget subjectCard(BuildContext context, String name, bool isCR,
      VoidCallback onTap) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 30),
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: Colors.deepPurple.withOpacity(0.2),
          highlightColor: Colors.deepPurple.withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: isCR
                  ? LinearGradient(
                      colors: [Colors.green.shade200, Colors.green.shade400])
                  : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isCR ? Colors.white : Colors.black87),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      isCR ? "CR" : "Student",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCR ? Colors.white : Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isCR ? Icons.admin_panel_settings : Icons.arrow_forward_ios,
                      color: isCR ? Colors.white : Colors.grey,
                      size: 20,
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ==========================
  /// UI
  /// ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Batch Dashboard"),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
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
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final subjects = snapshot.data!.docs;

              if (subjects.isEmpty) {
                return const Center(
                  child: Text(
                    "No subjects added yet",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return subjectCard(context, subject['name'], isCR, () {
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
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}
