import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_panel.dart';
import 'student_home_screen.dart';
import 'cr_home_screen.dart';
import 'register_screen.dart';
import 'university_admin_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final rollController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool isAutoLoginInProgress = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Fade-in animation for the login form
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    _tryAutoLogin();
  }

  @override
  void dispose() {
    _animationController.dispose();
    rollController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    final roll = rollController.text.trim();
    final password = passwordController.text.trim();

    if (roll.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter Roll & Password")));
      return;
    }

    await _loginWithCredentials(roll, password, isAuto: false);
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRoll = prefs.getString('saved_roll');
    final savedPassword = prefs.getString('saved_password');

    if (savedRoll == null || savedPassword == null) return;

    if (!mounted) return;
    setState(() => isAutoLoginInProgress = true);

    rollController.text = savedRoll;
    passwordController.text = savedPassword;

    await _loginWithCredentials(savedRoll, savedPassword, isAuto: true);

    if (mounted) {
      setState(() => isAutoLoginInProgress = false);
    }
  }

  Future<void> _loginWithCredentials(
    String roll,
    String password, {
    required bool isAuto,
  }) async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(roll)
          .get();

      if (!doc.exists) {
        if (!isAuto) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("User not found")));
        }
        await _clearSavedLogin();
        return;
      }

      if (doc['password'] != password) {
        if (!isAuto) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Wrong Password")));
        }
        await _clearSavedLogin();
        return;
      }

      await _saveLogin(roll, password);

      final rawRole = doc['role'];
      final role = (rawRole is String) ? rawRole.trim() : rawRole.toString();

      if (!mounted) return;

      if (role == "Admin" || role == "Admin (Global)") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminPanel()),
        );
      } else if (role == "UniversityAdmin" || role == "University Admin") {
        final String uniId = (doc['universityId'] is String)
            ? (doc['universityId'] as String)
            : doc['universityId'].toString();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UniversityAdminPage(
              universityId: uniId,
              ownerRoll: doc['roll'],
            ),
          ),
        );
      } else if (role == "CR") {
        final String uniId = (doc['universityId'] ?? '').toString();
        final String depId = (doc['departmentId'] ?? '').toString();
        final String batchId = (doc['batch'] ?? '').toString();
        if (uniId.isEmpty ||
            depId.isEmpty ||
            batchId.isEmpty ||
            uniId == '1' ||
            depId == '1' ||
            batchId == '1') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your account is missing University/Batch/Department. Please re-register with a valid selection.',
              ),
            ),
          );
          await _clearSavedLogin();
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CRHomeScreen(
              universityId: uniId,
              departmentId: depId,
              batch: batchId,
              roll: doc['roll'],
            ),
          ),
        );
      } else if (role == "Student") {
        final String uniId = (doc['universityId'] ?? '').toString();
        final String depId = (doc['departmentId'] ?? '').toString();
        final String batchId = (doc['batch'] ?? '').toString();
        if (uniId.isEmpty ||
            depId.isEmpty ||
            batchId.isEmpty ||
            uniId == '1' ||
            depId == '1' ||
            batchId == '1') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your account is missing University/Batch/Department. Please re-register with a valid selection.',
              ),
            ),
          );
          await _clearSavedLogin();
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StudentHomeScreen(
              universityId: uniId,
              departmentId: depId,
              batch: batchId,
              role: doc['role'],
              roll: doc['roll'],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unknown role: $role')));
      }
    } catch (e) {
      if (!isAuto) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _saveLogin(String roll, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_roll', roll);
    await prefs.setString('saved_password', password);
  }

  Future<void> _clearSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_roll');
    await prefs.remove('saved_password');
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo / Icon
                Container(
                  height: screenHeight * 0.2,
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.deepPurple, Colors.purpleAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.transparent,
                      child: const Icon(
                        Icons.school,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Welcome text
                const Text(
                  "Welcome Back!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Login to your account",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),

                const SizedBox(height: 40),

                // Roll ID TextField
                _buildTextField(
                  controller: rollController,
                  label: "Roll ID",
                  icon: Icons.perm_identity,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // Password TextField
                _buildTextField(
                  controller: passwordController,
                  label: "Password",
                  icon: Icons.lock,
                  obscureText: true,
                ),
                const SizedBox(height: 40),

                // Login button
                isLoading
                    ? const CircularProgressIndicator()
                    : AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Colors.deepPurple, Colors.purpleAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: loginUser,
                            splashColor: Colors.white24,
                            highlightColor: Colors.white10,
                            child: const Center(
                              child: Text(
                                "Login",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 20),

                // Register link
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text(
                    "Don't have an account? Register",
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- TextField builder ----------------
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Colors.deepPurple),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
