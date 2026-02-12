import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final universityController = TextEditingController();
  final departmentController = TextEditingController();
  final subjectController = TextEditingController();
  final startRollController = TextEditingController();
  final endRollController = TextEditingController();
  final manualRollController = TextEditingController();
  String? selectedUniversityId;
  String? selectedDepartmentId;
  String? selectedSubjectId;

Future<void> addManualRoll() async {
  if (selectedUniversityId == null ||
      selectedDepartmentId == null ||
      selectedSubjectId == null ||
      manualRollController.text.isEmpty) {
    return;
  }

  int roll = int.parse(manualRollController.text.trim());

  await FirebaseFirestore.instance
      .collection('universities')
      .doc(selectedUniversityId)
      .collection('departments')
      .doc(selectedDepartmentId)
      .collection('subjects')
      .doc(selectedSubjectId)
      .update({
    'extraRolls': FieldValue.arrayUnion([roll])
  });

  manualRollController.clear();

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Roll Added Successfully")),
  );
}

  /// ==============================
  /// CREATE UNIVERSITY
  /// ==============================
  Future<void> createUniversity() async {
    await FirebaseFirestore.instance.collection('universities').add({
      'name': universityController.text.trim(),
      'createdAt': Timestamp.now(),
    });

    universityController.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("University Created")));
  }

  /// ==============================
  /// CREATE DEPARTMENT
  /// ==============================
  Future<void> createDepartment() async {
    if (selectedUniversityId == null) return;

    await FirebaseFirestore.instance
        .collection('universities')
        .doc(selectedUniversityId)
        .collection('departments')
        .add({
      'name': departmentController.text.trim(),
      'createdAt': Timestamp.now(),
    });

    departmentController.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Department Created")));
  }

  /// ==============================
  /// CREATE SUBJECT + ROLL RANGE
  /// ==============================
  Future<void> createSubject() async {
    if (selectedUniversityId == null || selectedDepartmentId == null) return;

    await FirebaseFirestore.instance
        .collection('universities')
        .doc(selectedUniversityId)
        .collection('departments')
        .doc(selectedDepartmentId)
        .collection('subjects')
        .add({
      'name': subjectController.text.trim(),
      'startRoll': int.parse(startRollController.text.trim()),
      'endRoll': int.parse(endRollController.text.trim()),
      'createdAt': Timestamp.now(),
    });

    subjectController.clear();
    startRollController.clear();
    endRollController.clear();

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Subject Created")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            /// -------------------
            /// CREATE UNIVERSITY
            /// -------------------
            const Text("Create University",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: universityController,
              decoration: const InputDecoration(labelText: "University Name"),
            ),
            ElevatedButton(
              onPressed: createUniversity,
              child: const Text("Create University"),
            ),

            const Divider(height: 40),

            /// -------------------
            /// SELECT UNIVERSITY
            /// -------------------
            const Text("Select University",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('universities')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Container();

                return DropdownButton<String>(
                  value: selectedUniversityId,
                  hint: const Text("Select University"),
                  isExpanded: true,
                  items: snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedUniversityId = value;
                      selectedDepartmentId = null;
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            /// -------------------
            /// CREATE DEPARTMENT
            /// -------------------
            const Text("Create Department",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            TextField(
              controller: departmentController,
              decoration: const InputDecoration(labelText: "Department Name"),
            ),
            ElevatedButton(
              onPressed: createDepartment,
              child: const Text("Create Department"),
            ),

            const SizedBox(height: 20),

            /// -------------------
            /// SELECT DEPARTMENT
            /// -------------------
            if (selectedUniversityId != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('universities')
                    .doc(selectedUniversityId)
                    .collection('departments')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Container();

                  return DropdownButton<String>(
                    value: selectedDepartmentId,
                    hint: const Text("Select Department"),
                    isExpanded: true,
                    items: snapshot.data!.docs.map((doc) {
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(doc['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDepartmentId = value;
                      });
                    },
                  );
                },
              ),

            const Divider(height: 40),
            
            /// -------------------
            /// CREATE SUBJECT
            /// -------------------
            const Text("Create Subject",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: "Subject Name"),
            ),

            TextField(
              controller: startRollController,
              decoration: const InputDecoration(labelText: "Start Roll"),
              keyboardType: TextInputType.number,
            ),

            TextField(
              controller: endRollController,
              decoration: const InputDecoration(labelText: "End Roll"),
              keyboardType: TextInputType.number,
            ),

            ElevatedButton(
              onPressed: createSubject,
              child: const Text("Create Subject"),
            ),
            const Divider(height: 40),

const Text(
  "Add Manual Roll To Subject",
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),

/// SELECT SUBJECT
if (selectedUniversityId != null &&
    selectedDepartmentId != null)
  StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('universities')
        .doc(selectedUniversityId)
        .collection('departments')
        .doc(selectedDepartmentId)
        .collection('subjects')
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return Container();

      return DropdownButton<String>(
        value: selectedSubjectId,
        hint: const Text("Select Subject"),
        isExpanded: true,
        items: snapshot.data!.docs.map((doc) {
          return DropdownMenuItem(
            value: doc.id,
            child: Text(doc['name']),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedSubjectId = value;
          });
        },
      );
    },
  ),

const SizedBox(height: 15),

TextField(
  controller: manualRollController,
  decoration: const InputDecoration(
    labelText: "Enter Roll Number",
  ),
  keyboardType: TextInputType.number,
),

const SizedBox(height: 10),

ElevatedButton(
  onPressed: addManualRoll,
  child: const Text("Add Roll"),
),

          ],
        ),
      ),
    );
  }
}
