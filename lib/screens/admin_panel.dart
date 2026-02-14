import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final TextEditingController crRollController = TextEditingController();

  String? selectedUniversity;
  String? selectedBatch;
  String? selectedDepartment;

  @override
  void initState() {
    super.initState();
    selectedUniversity = widget.universityId;
  }

  /// ==========================
  /// FIRESTORE FUNCTIONS
  /// ==========================
  Future<void> createUniversity() async {
    if (universityController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter University Name")));
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("University Created")));
  }

  Future<void> createBatch() async {
    if (batchController.text.isEmpty || crRollController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Fill all Batch fields")));
      return;
    }
    await FirebaseFirestore.instance
        .collection('universities')
        .doc(selectedUniversity)
        .collection('batches')
        .doc(batchController.text.trim())
        .set({
      'name': batchController.text.trim(),
      'crRoll': int.tryParse(crRollController.text.trim()),
      'createdAt': Timestamp.now(),
    });
    batchController.clear();
    crRollController.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Batch Created")));
  }

  Future<void> createDepartment() async {
    if (departmentController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter Department Name")));
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
      'createdAt': Timestamp.now(),
    });
    departmentController.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Department Created")));
  }

  Future<void> createSubject() async {
    if (subjectController.text.isEmpty ||
        startRollController.text.isEmpty ||
        endRollController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Fill all Subject fields")));
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

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Subject Created")));
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
                )
              ],
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        );
      },
    );
  }

  /// ==========================
  /// STYLIZED TEXTFIELD
  /// ==========================
  Widget styledTextField(
      {required TextEditingController controller,
      required String label,
      TextInputType keyboardType = TextInputType.text}) {
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
              borderRadius: BorderRadius.circular(12)),
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
                    color: Colors.deepPurple),
              ),
            ),
            styledTextField(
                controller: universityController, label: "University Name"),
            animatedButton("Create University", createUniversity),
            const Divider(height: 40, thickness: 2, color: Colors.deepPurple),

            // 🟣 SELECT UNIVERSITY
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('universities').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return DropdownButtonFormField<String?>(
                  value: selectedUniversity,
                  decoration: InputDecoration(
                    labelText: "Select University",
                    filled: true,
                    fillColor: Colors.purple.shade50,
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              const Text("Create Batch",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)),
              styledTextField(controller: batchController, label: "Batch Name (e.g., 2023)"),
              styledTextField(
                  controller: crRollController,
                  label: "Batch CR Roll",
                  keyboardType: TextInputType.number),
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
                    value: selectedBatch,
                    decoration: InputDecoration(
                      labelText: "Select Batch",
                      filled: true,
                      fillColor: Colors.purple.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
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
              const Text("Create Department",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)),
              styledTextField(controller: departmentController, label: "Department Name"),
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
                    value: selectedDepartment,
                    decoration: InputDecoration(
                      labelText: "Select Department",
                      filled: true,
                      fillColor: Colors.purple.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: snapshot.data!.docs.map((doc) {
                      return DropdownMenuItem<String?>(
                        value: doc.id,
                        child: Text(doc['name']),
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
              const Text("Create Subject",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)),
              styledTextField(controller: subjectController, label: "Subject Name"),
              styledTextField(
                  controller: startRollController,
                  label: "Start Student ID",
                  keyboardType: TextInputType.number),
              styledTextField(
                  controller: endRollController,
                  label: "End Student ID",
                  keyboardType: TextInputType.number),
              styledTextField(
                  controller: extraRollController,
                  label: "Extra Student IDs (comma separated)"),
              animatedButton("Create Subject", createSubject),
            ],
          ],
        ),
      ),
    );
  }
}
