import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateUniversityScreen extends StatefulWidget {
  const CreateUniversityScreen({super.key});

  @override
  State<CreateUniversityScreen> createState() => _CreateUniversityScreenState();
}

class _CreateUniversityScreenState extends State<CreateUniversityScreen> {
  final nameController = TextEditingController();

  Future<void> createUniversity() async {
    if (nameController.text.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('universities').add({
      'name': nameController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user?.uid ?? 'unknown',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("University Created Successfully")),
    );

    nameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create University")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "University Name"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: createUniversity,
              child: const Text("Create University"),
            ),
          ],
        ),
      ),
    );
  }
}
