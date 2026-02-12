import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final rollController = TextEditingController();
  final passwordController = TextEditingController();
  final adminPasswordController = TextEditingController();

  String? selectedUniversityId;
  String? selectedDepartmentId;
  String selectedRole = "Student";

  bool isLoading = false;

  /// ==============================
  /// REGISTER FUNCTION
  /// ==============================
  Future<void> registerUser() async {
    if (rollController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    /// If NOT admin → university & department required
    if (selectedRole != "Admin") {
      if (selectedUniversityId == null ||
          selectedDepartmentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select University & Department")),
        );
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      /// 🔐 ADMIN PASSWORD CHECK
      if (selectedRole == "Admin") {
        final configDoc = await FirebaseFirestore.instance
            .collection('config')
            .doc('admin_settings')
            .get();

        String correctPassword = configDoc['adminPassword'];

        if (adminPasswordController.text.trim() != correctPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Wrong Admin Password")),
          );
          setState(() => isLoading = false);
          return;
        }
      }

      /// 🧑 SAVE USER
      await FirebaseFirestore.instance
          .collection('users')
          .doc(rollController.text.trim())
          .set({
        'roll': rollController.text.trim(),
        'password': passwordController.text.trim(),
        'role': selectedRole,
        'universityId':
            selectedRole == "Admin" ? null : selectedUniversityId,
        'departmentId':
            selectedRole == "Admin" ? null : selectedDepartmentId,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration Successful")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  /// ==============================
  /// UI
  /// ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            /// ROLE SELECT
            DropdownButtonFormField<String>(
              value: selectedRole,
              items: const [
                DropdownMenuItem(value: "Student", child: Text("Student")),
                DropdownMenuItem(value: "CR", child: Text("CR")),
                DropdownMenuItem(value: "Admin", child: Text("Admin")),
              ],
              onChanged: (value) {
                setState(() {
                  selectedRole = value!;
                  selectedUniversityId = null;
                  selectedDepartmentId = null;
                });
              },
              decoration: const InputDecoration(labelText: "Select Role"),
            ),

            const SizedBox(height: 20),

            /// UNIVERSITY (ONLY IF NOT ADMIN)
            if (selectedRole != "Admin")
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('universities')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Container();

                  return DropdownButtonFormField<String>(
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

            /// DEPARTMENT (ONLY IF NOT ADMIN)
            if (selectedRole != "Admin" && selectedUniversityId != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('universities')
                    .doc(selectedUniversityId)
                    .collection('departments')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Container();

                  return DropdownButtonFormField<String>(
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

            const SizedBox(height: 20),

            /// ROLL
            TextField(
              controller: rollController,
              decoration: const InputDecoration(labelText: "Roll ID"),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 20),

            /// PASSWORD
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),

            const SizedBox(height: 20),

            /// ADMIN SECRET PASSWORD
            if (selectedRole == "Admin")
              TextField(
                controller: adminPasswordController,
                decoration: const InputDecoration(
                    labelText: "Admin Secret Password"),
                obscureText: true,
              ),

            const SizedBox(height: 30),

            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: registerUser,
                    child: const Text("Register"),
                  ),
          ],
        ),
      ),
    );
  }
}
