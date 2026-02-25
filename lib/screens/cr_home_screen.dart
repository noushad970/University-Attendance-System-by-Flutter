import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
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
    try {
      final deptDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(universityId)
          .collection('batches')
          .doc(batch)
          .collection('departments')
          .doc(departmentId)
          .get();
      if (!deptDoc.exists) return false;
      final data = deptDoc.data();
      if (data == null) return false;
      final crVal = data['crRoll'];
      final int? crRoll = (crVal is int)
          ? crVal
          : int.tryParse(crVal?.toString() ?? '');
      return crRoll != null && crRoll == roll;
    } catch (_) {
      return false;
    }
  }

  /// ==========================
  /// Stylized Subject Card
  /// ==========================
  Widget subjectCard(
    BuildContext context,
    String name,
    bool isCR,
    VoidCallback onTap,
  ) {
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
                      colors: [Colors.green.shade200, Colors.green.shade400],
                    )
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
                      color: isCR ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      isCR ? "CR" : "Student",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCR ? Colors.white : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isCR
                          ? Icons.admin_panel_settings
                          : Icons.arrow_forward_ios,
                      color: isCR ? Colors.white : Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
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
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('universities')
              .doc(universityId)
              .get(),
          builder: (context, snap) {
            String uniName = 'University';
            if (snap.hasData && snap.data!.exists) {
              final data = snap.data!.data();
              if (data is Map<String, dynamic>) {
                uniName = (data['name'] as String?) ?? 'University';
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uniName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Batch Dashboard',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {}
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: isBatchCR(),
        builder: (context, crSnapshot) {
          if (crSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (crSnapshot.hasError) {
            return Center(child: Text('Failed to load CR status'));
          }
          if (!crSnapshot.hasData) {
            return const Center(child: Text('No data'));
          }

          final bool isCR = crSnapshot.data!;

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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load subjects'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No subjects added yet",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              final subjects = snapshot.data!.docs;

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return subjectCard(
                    context,
                    subject['name'] ?? 'Subject',
                    isCR,
                    () {
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
