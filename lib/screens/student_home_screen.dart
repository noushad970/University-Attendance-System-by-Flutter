import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'subject_details_screen.dart';

class StudentHomeScreen extends StatefulWidget {
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

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _refreshTick = 0;

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshTick++;
    });
    // Add small delay to show refresh indicator
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<bool> isBatchCR() async {
    final batchDoc = await FirebaseFirestore.instance
        .collection('universities')
        .doc(widget.universityId)
        .collection('batches')
        .doc(widget.batch)
        .get();

    if (!batchDoc.exists || batchDoc['crRoll'] == null) {
      return false;
    }

    int crRoll = batchDoc['crRoll'];
    return crRoll == widget.roll;
  }

  Future<Set<String>> getLiveSubjectIds(
      List<QueryDocumentSnapshot> subjects) async {
    final liveIds = <String>{};

    for (final subject in subjects) {
      final liveSession = await FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(widget.batch)
          .collection('departments')
          .doc(widget.departmentId)
          .collection('subjects')
          .doc(subject.id)
          .collection('attendanceSessions')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (liveSession.docs.isNotEmpty) {
        liveIds.add(subject.id);
      }
    }

    return liveIds;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: const Text("My Subjects"),
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _refreshTick++;
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        key: ValueKey(_refreshTick),
        future: isBatchCR(),
        builder: (context, crSnapshot) {
          if (!crSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          bool isCR = crSnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            key: ValueKey(_refreshTick),
            stream: FirebaseFirestore.instance
                .collection('universities')
                .doc(widget.universityId)
                .collection('batches')
                .doc(widget.batch)
                .collection('departments')
                .doc(widget.departmentId)
                .collection('subjects')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No subjects available",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                );
              }

              final subjects = snapshot.data!.docs;

              return FutureBuilder<Set<String>>(
                future: getLiveSubjectIds(subjects),
                builder: (context, liveSnapshot) {
                  if (!liveSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final liveIds = liveSnapshot.data!;
                  final liveSubjects = subjects
                      .where((subject) => liveIds.contains(subject.id))
                      .toList();
                  final otherSubjects = subjects
                      .where((subject) => !liveIds.contains(subject.id))
                      .toList();

                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      children: [
                        if (liveSubjects.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 6, 16, 4),
                            child: Text(
                              "Live Attendance",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                          ...liveSubjects.map((subject) => _buildSubjectTile(
                                context,
                                subject,
                                isCR,
                                isLive: true,
                              )),
                        ],
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                          child: Text(
                            "All Subjects",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        ...otherSubjects.map((subject) => _buildSubjectTile(
                              context,
                              subject,
                              isCR,
                              isLive: false,
                            )),
                      ],
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

  Widget _buildSubjectTile(BuildContext context, QueryDocumentSnapshot subject,
      bool isCR, {required bool isLive}) {
    final subjectName = subject['name'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 3,
      shadowColor: Colors.deepPurple.withOpacity(0.3),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text(
          subjectName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple,
          ),
        ),
        subtitle: Text(
          isCR ? "You are Batch CR" : "Student",
          style: TextStyle(
            color: isCR ? Colors.green : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "LIVE",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.deepPurple),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubjectDetailsScreen(
                universityId: widget.universityId,
                departmentId: widget.departmentId,
                batch: widget.batch,
                subjectId: subject.id,
                role: isCR ? "CR" : "Student",
                userRoll: widget.roll,
              ),
            ),
          );
        },
      ),
    );
  }
}
