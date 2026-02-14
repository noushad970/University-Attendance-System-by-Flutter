import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_panel.dart';
import 'student_home_screen.dart';
import 'cr_home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final rollController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> loginUser() async {
    if (rollController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Roll & Password")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(rollController.text.trim())
          .get();

      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found")),
        );
        setState(() => isLoading = false);
        return;
      }

      if (doc['password'] != passwordController.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Wrong Password")),
        );
        setState(() => isLoading = false);
        return;
      }

      String role = doc['role'];

      if (role == "Admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminPanel(),
          ),
        );
      } else if (role == "CR") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CRHomeScreen(
              universityId: doc['universityId'],
              departmentId: doc['departmentId'],
              batch: doc['batch'],
              roll: doc['roll'],
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StudentHomeScreen(
              universityId: doc['universityId'],
              departmentId: doc['departmentId'],
              batch: doc['batch'],
              role: doc['role'],
              roll: doc['roll'],
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: rollController,
              decoration: const InputDecoration(
                labelText: "Roll ID",
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 20),

            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
              ),
              obscureText: true,
            ),

            const SizedBox(height: 30),

            isLoading
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: loginUser,
                        child: const Text("Login"),
                      ),

                      const SizedBox(height: 15),

                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Don't have an account? Register",
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
