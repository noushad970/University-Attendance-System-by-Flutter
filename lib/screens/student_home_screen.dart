import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
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
    try {
      final deptDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(widget.batch)
          .collection('departments')
          .doc(widget.departmentId)
          .get();

      if (!deptDoc.exists) return false;
      final data = deptDoc.data();
      if (data == null) return false;
      final crVal = data['crRoll'];
      final int? crRoll = (crVal is int)
          ? crVal
          : int.tryParse(crVal?.toString() ?? '');
      return crRoll != null && crRoll == widget.roll;
    } catch (_) {
      return false;
    }
  }

  Future<Set<String>> getLiveSubjectIds(
    List<QueryDocumentSnapshot> subjects,
  ) async {
    final liveIds = <String>{};
    for (final subject in subjects) {
      try {
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
        if (liveSession.docs.isNotEmpty) liveIds.add(subject.id);
      } catch (_) {
        // ignore errors per subject
      }
    }
    return liveIds;
  }

  Future<bool> _confirmAndDeleteAccount(BuildContext context) async {
    final TextEditingController _confirmController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will permanently delete your account data. To confirm, type "are you sure" below.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              decoration: const InputDecoration(
                hintText: 'Type: are you sure',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = _confirmController.text.trim().toLowerCase();
              if (v == 'are you sure') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please type "are you sure" to confirm.'),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await _confirmAndDeleteAccount(context);
    if (!confirmed) return;

    final rollId = widget.roll.toString();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Deleting account...')));
    try {
      await FirebaseFirestore.instance.collection('users').doc(rollId).delete();

      // clear saved preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('saved_roll');
        await prefs.remove('saved_password');
        await prefs.remove('saved_role');
        await prefs.remove('saved_university');
      } catch (_) {}

      // sign out
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account deleted')));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('universities')
              .doc(widget.universityId)
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
                  'My Subjects',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _refreshTick++;
              });
            },
          ),
          IconButton(
            tooltip: 'Delete Account',
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: () => _deleteAccount(context),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('saved_roll');
                await prefs.remove('saved_password');
                await prefs.remove('saved_role');
                await prefs.remove('saved_university');
              } catch (_) {}
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
        key: ValueKey(_refreshTick),
        future: isBatchCR(),
        builder: (context, crSnapshot) {
          if (crSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (crSnapshot.hasError) {
            return Center(
              child: Text('Failed to load CR status: ${crSnapshot.error}'),
            );
          }
          if (!crSnapshot.hasData) {
            return const Center(child: Text('No data'));
          }

          final bool isCR = crSnapshot.data!;

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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Failed to load subjects: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                  if (liveSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (liveSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to check live sessions: ${liveSnapshot.error}',
                      ),
                    );
                  }
                  final liveIds = liveSnapshot.data ?? <String>{};
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
                          ...liveSubjects.map(
                            (subject) => _buildSubjectTile(
                              context,
                              subject,
                              isCR,
                              isLive: true,
                            ),
                          ),
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
                        ...otherSubjects.map(
                          (subject) => _buildSubjectTile(
                            context,
                            subject,
                            isCR,
                            isLive: false,
                          ),
                        ),
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

  Widget _buildSubjectTile(
    BuildContext context,
    QueryDocumentSnapshot subject,
    bool isCR, {
    required bool isLive,
  }) {
    final subjectName = subject['name'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      shadowColor: Colors.deepPurple.withOpacity(0.3),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
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
