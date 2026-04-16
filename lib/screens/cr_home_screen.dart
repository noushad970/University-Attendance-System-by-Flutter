import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'subject_details_screen.dart';

class CRHomeScreen extends StatefulWidget {
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

  @override
  State<CRHomeScreen> createState() => _CRHomeScreenState();
}

class _CRHomeScreenState extends State<CRHomeScreen> {
  final TextEditingController assignCrController = TextEditingController();
  final TextEditingController addStudentController = TextEditingController();
  bool isBusy = false;

  @override
  void dispose() {
    assignCrController.dispose();
    addStudentController.dispose();
    super.dispose();
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

  Future<String?> _findUserDocId(int roll) async {
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('roll', isEqualTo: roll)
        .where('universityId', isEqualTo: widget.universityId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  }

  Future<void> _assignCR() async {
    final text = assignCrController.text.trim();
    final int? newCr = int.tryParse(text);
    if (newCr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid numeric Roll ID')),
      );
      return;
    }

    setState(() => isBusy = true);
    try {
      // Validate newCr exists in department (subjects ranges or students array)
      final deptRef = FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(widget.batch)
          .collection('departments')
          .doc(widget.departmentId);

      final deptDoc = await deptRef.get();
      if (!deptDoc.exists) throw 'Department not found';

      bool existsInSubjects = false;
      final subjectsSnap = await deptRef.collection('subjects').get();
      for (final s in subjectsSnap.docs) {
        final data = s.data();
        final start = data['startRoll'];
        final end = data['endRoll'];
        final extra = (data['extraRolls'] is List)
            ? List.from(data['extraRolls'])
            : null;
        final int? startRoll = (start is int)
            ? start
            : int.tryParse(start?.toString() ?? '');
        final int? endRoll = (end is int)
            ? end
            : int.tryParse(end?.toString() ?? '');
        if (startRoll != null &&
            endRoll != null &&
            newCr >= startRoll &&
            newCr <= endRoll) {
          existsInSubjects = true;
          break;
        }
        if (extra != null) {
          for (final e in extra) {
            final int? ex = (e is int) ? e : int.tryParse(e?.toString() ?? '');
            if (ex == newCr) {
              existsInSubjects = true;
              break;
            }
          }
          if (existsInSubjects) break;
        }
      }

      final studentsArray = (deptDoc.data()?['students'] is List)
          ? List.from(deptDoc.data()?['students'])
          : <dynamic>[];
      final bool existsInArray = studentsArray.any(
        (e) => (e is int ? e : int.tryParse(e?.toString() ?? '')) == newCr,
      );

      if (!existsInSubjects && !existsInArray) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CR must be an existing student in this department'),
          ),
        );
        setState(() => isBusy = false);
        return;
      }

      // Update department crRoll
      await deptRef.update({'crRoll': newCr});

      // Update user role to CR (if user exists)
      final userDocId = await _findUserDocId(newCr);
      if (userDocId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userDocId)
            .update({
              'role': 'CR',
              'departmentId': widget.departmentId,
              'batch': widget.batch,
            });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New CR assigned successfully')),
      );
      assignCrController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => isBusy = false);
  }

  Future<void> _leaveCRShip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave CRship'),
        content: const Text(
          'Are you sure you want to leave CRship? You must assign a new CR first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => isBusy = true);
    try {
      final deptRef = FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(widget.batch)
          .collection('departments')
          .doc(widget.departmentId);
      final deptDoc = await deptRef.get();
      if (!deptDoc.exists) throw 'Department not found';
      final crVal = deptDoc.data()?['crRoll'];
      final int? currentCr = (crVal is int)
          ? crVal
          : int.tryParse(crVal?.toString() ?? '');
      if (currentCr != null && currentCr == widget.roll) {
        // There must be another CR assigned before leaving
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assign a new CR before leaving CRship'),
          ),
        );
        setState(() => isBusy = false);
        return;
      }

      // Current department crRoll is not this user - safe to leave: update this user's role to Student
      final userDocId = await _findUserDocId(widget.roll);
      if (userDocId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userDocId)
            .update({'role': 'Student'});
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You have left CRship')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => isBusy = false);
  }

  Future<void> _addStudent() async {
    final text = addStudentController.text.trim();
    final int? newRoll = int.tryParse(text);
    if (newRoll == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid numeric Roll ID')),
      );
      return;
    }
    setState(() => isBusy = true);
    try {
      final deptRef = FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(widget.batch)
          .collection('departments')
          .doc(widget.departmentId);
      final deptDoc = await deptRef.get();
      if (!deptDoc.exists) throw 'Department not found';
      final studentsArray = (deptDoc.data()?['students'] is List)
          ? List.from(deptDoc.data()?['students'])
          : <dynamic>[];
      if (studentsArray.any(
        (e) => (e is int ? e : int.tryParse(e?.toString() ?? '')) == newRoll,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student already present')),
        );
        setState(() => isBusy = false);
        return;
      }
      studentsArray.add(newRoll);
      await deptRef.update({'students': studentsArray});
      addStudentController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Student added')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => isBusy = false);
  }

  Future<void> _removeStudent(int removeRoll) async {
    setState(() => isBusy = true);
    try {
      final deptRef = FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(widget.batch)
          .collection('departments')
          .doc(widget.departmentId);
      final deptDoc = await deptRef.get();
      if (!deptDoc.exists) throw 'Department not found';
      final studentsArray = (deptDoc.data()?['students'] is List)
          ? List.from(deptDoc.data()?['students'])
          : <dynamic>[];
      studentsArray.removeWhere(
        (e) => (e is int ? e : int.tryParse(e?.toString() ?? '')) == removeRoll,
      );
      await deptRef.update({'students': studentsArray});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Student removed')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => isBusy = false);
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Deleting account...')));
    try {
      // find user doc and delete
      final userDocId = await _findUserDocId(widget.roll);
      if (userDocId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userDocId)
            .delete();
      }

      // clear saved preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('saved_roll');
        await prefs.remove('saved_password');
        await prefs.remove('saved_role');
        await prefs.remove('saved_university');
      } catch (_) {}

      // sign out firebase auth if used
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
                  'Batch Dashboard',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            );
          },
        ),
        actions: [
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
                .doc(widget.universityId)
                .collection('batches')
                .doc(widget.batch)
                .collection('departments')
                .doc(widget.departmentId)
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

              // CR management section - only visible to current CR
              Widget crManagementSection() {
                if (!isCR) return const SizedBox.shrink();
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('universities')
                      .doc(widget.universityId)
                      .collection('batches')
                      .doc(widget.batch)
                      .collection('departments')
                      .doc(widget.departmentId)
                      .get(),
                  builder: (context, depSnap) {
                    final students = <int>[];
                    if (depSnap.hasData && depSnap.data!.exists) {
                      final docData = depSnap.data!.data();
                      if (docData is Map<String, dynamic>) {
                        final arr = docData['students'];
                        if (arr is List) {
                          for (final e in arr) {
                            if (e == null) continue;
                            final int? v = (e is int)
                                ? e
                                : int.tryParse(e.toString());
                            if (v != null) students.add(v);
                          }
                        }
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Assign new CR',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: assignCrController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter Roll ID to assign as CR',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: isBusy ? null : _assignCR,
                                    child: isBusy
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Assign CR'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Leave CRship',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: isBusy ? null : _leaveCRShip,
                                    child: const Text('Leave CRship'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Manage Students',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: addStudentController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'Add Roll ID to department list',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: isBusy ? null : _addStudent,
                                        child: const Text('Add'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Department Students:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: students
                                        .map(
                                          (s) => Chip(
                                            label: Text(s.toString()),
                                            deleteIcon: const Icon(Icons.close),
                                            onDeleted: () => _removeStudent(s),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: subjects.length + (isCR ? 1 : 0),
                itemBuilder: (context, index) {
                  if (isCR && index == 0) {
                    return crManagementSection();
                  }
                  final subject = subjects[isCR ? index - 1 : index];
                  return subjectCard(
                    context,
                    subject['name'] ?? 'Subject',
                    isCR,
                    () {
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
