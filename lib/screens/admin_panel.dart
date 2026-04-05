import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';

class AdminPanel extends StatefulWidget {
  final String? universityId;

  const AdminPanel({super.key, this.universityId});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with TickerProviderStateMixin {
  final TextEditingController universityController = TextEditingController();
  final TextEditingController batchController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController startRollController = TextEditingController();
  final TextEditingController endRollController = TextEditingController();
  final TextEditingController extraRollController = TextEditingController();
  final TextEditingController crRollController =
      TextEditingController(); // now used for Department CR Roll

  String? selectedUniversity;
  String? selectedBatch;
  String? selectedDepartment;

  @override
  void initState() {
    super.initState();
    selectedUniversity = widget.universityId;
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

  Future<String?> _resolveCurrentRoll(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('saved_roll');
      if (saved != null && saved.isNotEmpty) return saved;
    } catch (_) {}

    // If not found, ask the user to input their roll id
    final TextEditingController _rollController = TextEditingController();
    final entered = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Roll ID'),
        content: TextField(
          controller: _rollController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Your Roll ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _rollController.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (entered == null || entered.isEmpty) return null;
    return entered;
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final rollId = await _resolveCurrentRoll(context);
    if (rollId == null) return;

    final confirmed = await _confirmAndDeleteAccount(context);
    if (!confirmed) return;

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
  /// FIRESTORE FUNCTIONS
  /// ==========================
  Future<void> createUniversity() async {
    if (universityController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter University Name")));
      return;
    }
    await FirebaseFirestore.instance
        .collection('universities')
        .doc(universityController.text.trim())
        .set({
          'name': universityController.text.trim(),
          'createdAt': Timestamp.now(),
        });
    universityController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("University Created")));
  }

  Future<void> createBatch() async {
    if (batchController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter Batch Name")));
      return;
    }
    await FirebaseFirestore.instance
        .collection('universities')
        .doc(selectedUniversity)
        .collection('batches')
        .doc(batchController.text.trim())
        .set({
          'name': batchController.text.trim(),
          'createdAt': Timestamp.now(),
        });
    batchController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Batch Created")));
  }

  Future<void> createDepartment() async {
    if (departmentController.text.isEmpty || crRollController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Department Name & CR Roll")),
      );
      return;
    }
    final int? crRoll = int.tryParse(crRollController.text.trim());
    if (crRoll == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("CR Roll must be a number")));
      return;
    }
    await FirebaseFirestore.instance
        .collection('universities')
        .doc(selectedUniversity)
        .collection('batches')
        .doc(selectedBatch)
        .collection('departments')
        .doc(departmentController.text.trim())
        .set({
          'name': departmentController.text.trim(),
          'crRoll': crRoll,
          'createdAt': Timestamp.now(),
        });
    departmentController.clear();
    crRollController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Department Created")));
  }

  Future<void> createSubject() async {
    if (subjectController.text.isEmpty ||
        startRollController.text.isEmpty ||
        endRollController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Fill all Subject fields")));
      return;
    }

    int startRoll = int.parse(startRollController.text.trim());
    int endRoll = int.parse(endRollController.text.trim());

    List<int> extraRolls = [];
    if (extraRollController.text.isNotEmpty) {
      extraRolls = extraRollController.text
          .split(',')
          .map((e) => int.parse(e.trim()))
          .toList();
    }

    await FirebaseFirestore.instance
        .collection('universities')
        .doc(selectedUniversity)
        .collection('batches')
        .doc(selectedBatch)
        .collection('departments')
        .doc(selectedDepartment)
        .collection('subjects')
        .add({
          'name': subjectController.text.trim(),
          'startRoll': startRoll,
          'endRoll': endRoll,
          'extraRolls': extraRolls,
          'createdAt': Timestamp.now(),
        });

    subjectController.clear();
    startRollController.clear();
    endRollController.clear();
    extraRollController.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Subject Created")));
  }

  /// ==========================
  /// STYLIZED BUTTON
  /// ==========================
  Widget animatedButton(String text, VoidCallback onPressed) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, scale, child) {
        return InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.deepPurpleAccent.withOpacity(0.3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.deepPurple, Colors.purpleAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purpleAccent.withOpacity(0.4),
                  offset: const Offset(0, 5),
                  blurRadius: 10,
                ),
              ],
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  /// ==========================
  /// STYLIZED TEXTFIELD
  /// ==========================
  Widget styledTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.purple.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.deepPurple),
            borderRadius: BorderRadius.circular(12),
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
        title: const Text("Admin Panel"),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: 1,
              child: const Text(
                "Create University",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            styledTextField(
              controller: universityController,
              label: "University Name",
            ),
            animatedButton("Create University", createUniversity),
            const Divider(height: 40, thickness: 2, color: Colors.deepPurple),

            // 🟣 SELECT UNIVERSITY
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('universities')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return DropdownButtonFormField<String?>(
                  initialValue: selectedUniversity,
                  decoration: InputDecoration(
                    labelText: "Select University",
                    filled: true,
                    fillColor: Colors.purple.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem<String?>(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedUniversity = value;
                      selectedBatch = null;
                      selectedDepartment = null;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // 🔵 CREATE BATCH
            if (selectedUniversity != null) ...[
              const Text(
                "Create Batch",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.deepPurple,
                ),
              ),
              styledTextField(
                controller: batchController,
                label: "Batch Name (e.g., 2023)",
              ),
              animatedButton("Create Batch", createBatch),
            ],

            const SizedBox(height: 20),

            // 🔵 SELECT BATCH
            if (selectedUniversity != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('universities')
                    .doc(selectedUniversity)
                    .collection('batches')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  return DropdownButtonFormField<String?>(
                    initialValue: selectedBatch,
                    decoration: InputDecoration(
                      labelText: "Select Batch",
                      filled: true,
                      fillColor: Colors.purple.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: snapshot.data!.docs.map((doc) {
                      return DropdownMenuItem<String?>(
                        value: doc.id,
                        child: Text(doc['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBatch = value;
                        selectedDepartment = null;
                      });
                    },
                  );
                },
              ),

            const SizedBox(height: 20),

            // 🟢 CREATE DEPARTMENT
            if (selectedBatch != null) ...[
              const Text(
                "Create Department",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.deepPurple,
                ),
              ),
              styledTextField(
                controller: departmentController,
                label: "Department Name",
              ),
              styledTextField(
                controller: crRollController,
                label: "Department CR Roll",
                keyboardType: TextInputType.number,
              ),
              animatedButton("Create Department", createDepartment),
            ],

            const SizedBox(height: 20),

            // 🟢 SELECT DEPARTMENT
            if (selectedBatch != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('universities')
                    .doc(selectedUniversity)
                    .collection('batches')
                    .doc(selectedBatch)
                    .collection('departments')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  return DropdownButtonFormField<String?>(
                    initialValue: selectedDepartment,
                    decoration: InputDecoration(
                      labelText: "Select Department",
                      filled: true,
                      fillColor: Colors.purple.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: snapshot.data!.docs.map((doc) {
                      return DropdownMenuItem<String?>(
                        value: doc.id,
                        child: Text(
                          (doc['name'] ?? '1') +
                              ' • CR: ' +
                              (doc['crRoll']?.toString() ?? '1'),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDepartment = value;
                      });
                    },
                  );
                },
              ),

            const SizedBox(height: 30),

            // 🔴 CREATE SUBJECT
            if (selectedDepartment != null) ...[
              const Text(
                "Create Subject",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.deepPurple,
                ),
              ),
              styledTextField(
                controller: subjectController,
                label: "Subject Name",
              ),
              styledTextField(
                controller: startRollController,
                label: "Start Student ID",
                keyboardType: TextInputType.number,
              ),
              styledTextField(
                controller: endRollController,
                label: "End Student ID",
                keyboardType: TextInputType.number,
              ),
              styledTextField(
                controller: extraRollController,
                label: "Extra Student IDs (comma separated)",
              ),
              animatedButton("Create Subject", createSubject),
            ],
          ],
        ),
      ),
    );
  }
}
