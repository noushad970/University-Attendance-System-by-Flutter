import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateDepartmentScreen extends StatefulWidget {
  final String universityId;
  const CreateDepartmentScreen({super.key, required this.universityId});

  @override
  State<CreateDepartmentScreen> createState() => _CreateDepartmentScreenState();
}

class _CreateDepartmentScreenState extends State<CreateDepartmentScreen> {
  final nameController = TextEditingController();

  Future<void> createDepartment() async {
    if (nameController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('universities')
        .doc(widget.universityId)
        .collection('departments')
        .add({
      'name': nameController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Department Created Successfully")),
    );

    nameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Department")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Department Name"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: createDepartment,
              child: const Text("Create Department"),
            ),
          ],
        ),
      ),
    );
  }
}
