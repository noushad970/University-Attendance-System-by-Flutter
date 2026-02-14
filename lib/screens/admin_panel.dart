import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanel extends StatefulWidget {
  final String? universityId;

  const AdminPanel({super.key, this.universityId});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {

  final TextEditingController universityController =
      TextEditingController();
  final TextEditingController batchController =
      TextEditingController();
  final TextEditingController departmentController =
      TextEditingController();
  final TextEditingController subjectController =
      TextEditingController();
  final TextEditingController startRollController =
      TextEditingController();
  final TextEditingController endRollController =
      TextEditingController();
  final TextEditingController extraRollController =
      TextEditingController();
  final TextEditingController crRollController =
      TextEditingController();

  String? selectedUniversity;
  String? selectedBatch;
  String? selectedDepartment;

  @override
  void initState() {
    super.initState();
    selectedUniversity = widget.universityId;
  }

  /// ==========================
  /// CREATE UNIVERSITY
  /// ==========================
  Future<void> createUniversity() async {
    if (universityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter University Name")),
      );
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("University Created")),
    );
  }

  /// ==========================
  /// CREATE BATCH
  /// ==========================
  Future<void> createBatch() async {
    if (batchController.text.isEmpty || crRollController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all Batch fields")),
      );
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Batch Created")),
    );
  }

  /// ==========================
  /// CREATE DEPARTMENT
  /// ==========================
  Future<void> createDepartment() async {
    if (departmentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Department Name")),
      );
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Department Created")),
    );
  }

  /// ==========================
  /// CREATE SUBJECT
  /// ==========================
  Future<void> createSubject() async {
    if (subjectController.text.isEmpty || 
        startRollController.text.isEmpty || 
        endRollController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all Subject fields")),
      );
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Subject Created")),
    );
  }

  /// ==========================
  /// UI
  /// ==========================
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            /// � CREATE UNIVERSITY
            const Text("Create University",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),

            TextField(
              controller: universityController,
              decoration:
                  const InputDecoration(labelText: "University Name"),
            ),

            ElevatedButton(
              onPressed: createUniversity,
              child: const Text("Create University"),
            ),

            const Divider(height: 40),

            /// 🟣 SELECT UNIVERSITY
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('universities')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                return DropdownButton<String?>(
                  value: selectedUniversity,
                  hint: const Text("Select University"),
                  isExpanded: true,
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

            /// 🔵 CREATE BATCH
            if (selectedUniversity != null) ...[
              const Text("Create Batch",
                  style: TextStyle(fontWeight: FontWeight.bold)),

              TextField(
                controller: batchController,
                decoration:
                    const InputDecoration(labelText: "Batch Name (e.g., 2023)"),
              ),

              TextField(
                controller: crRollController,
                decoration:
                    const InputDecoration(labelText: "Batch CR Roll"),
                keyboardType: TextInputType.number,
              ),

              ElevatedButton(
                onPressed: createBatch,
                child: const Text("Create Batch"),
              ),
            ],

            const SizedBox(height: 20),

            /// 🔵 SELECT BATCH
            if (selectedUniversity != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('universities')
                    .doc(selectedUniversity)
                    .collection('batches')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();

                  return DropdownButton<String?>(
                    value: selectedBatch,
                    hint: const Text("Select Batch"),
                    isExpanded: true,
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

            /// 🟢 CREATE DEPARTMENT
            if (selectedBatch != null) ...[
              const Text("Create Department",
                  style: TextStyle(fontWeight: FontWeight.bold)),

              TextField(
                controller: departmentController,
                decoration:
                    const InputDecoration(labelText: "Department Name"),
              ),

              ElevatedButton(
                onPressed: createDepartment,
                child: const Text("Create Department"),
              ),
            ],

            const SizedBox(height: 20),

            /// 🟢 SELECT DEPARTMENT
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

                  return DropdownButton<String?>(
                    value: selectedDepartment,
                    hint: const Text("Select Department"),
                    isExpanded: true,
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

            /// 🔴 CREATE SUBJECT
            if (selectedDepartment != null) ...[
              const Text("Create Subject",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),

              TextField(
                controller: subjectController,
                decoration:
                    const InputDecoration(labelText: "Subject Name"),
              ),

              TextField(
                controller: startRollController,
                decoration:
                    const InputDecoration(labelText: "Start Student ID"),
                keyboardType: TextInputType.number,
              ),

              TextField(
                controller: endRollController,
                decoration:
                    const InputDecoration(labelText: "End Student ID"),
                keyboardType: TextInputType.number,
              ),

              TextField(
                controller: extraRollController,
                decoration: const InputDecoration(
                    labelText:
                        "Extra Student IDs (comma separated for re-admitted students)"),
              ),

              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: createSubject,
                child: const Text("Create Subject"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
