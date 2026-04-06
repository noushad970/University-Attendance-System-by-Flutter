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
  List<DropdownMenuItem<String>> _universityItems = [];
  String? _selectedUniversityId;
  final List<String> _roles = ['Admin', 'University Admin', 'CR', 'Student'];
  String? _selectedRole;

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

    // load universities for selection
    _loadUniversities();

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

    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a role')));
      return;
    }

    if (!(_selectedRole == 'Admin') &&
        !(_selectedRole == 'Admin (Global)') &&
        _selectedUniversityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your University')),
      );
      return;
    }

    await _loginWithCredentials(roll, password, isAuto: false);
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRoll = prefs.getString('saved_roll');
    final savedPassword = prefs.getString('saved_password');
    final savedRole = prefs.getString('saved_role');
    final savedUniversity = prefs.getString('saved_university');

    if (savedRoll == null || savedPassword == null || savedRole == null) return;

    if (!mounted) return;
    setState(() => isAutoLoginInProgress = true);

    rollController.text = savedRoll;
    passwordController.text = savedPassword;
    _selectedRole = savedRole;
    _selectedUniversityId = savedUniversity;

    // Attempt auto-login using saved credentials (silent)
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
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
      // Find user by roll (and by university when applicable) instead of doc(roll)
      final int? rollInt = int.tryParse(roll);
      if (rollInt == null) {
        if (!isAuto) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Roll must be a number")),
          );
        }
        await _clearSavedLogin();
        return;
      }

      Query query = FirebaseFirestore.instance
          .collection('users')
          .where('roll', isEqualTo: rollInt);
      // For non-admin roles, ensure lookup is scoped to selected university
      if (!(_selectedRole == 'Admin') && !(_selectedRole == 'Admin (Global)')) {
        if (_selectedUniversityId != null) {
          query = query.where('universityId', isEqualTo: _selectedUniversityId);
        }
      }

      final querySnap = await query.limit(1).get();
      if (querySnap.docs.isEmpty) {
        if (!isAuto) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("User not found")));
        }
        await _clearSavedLogin();
        return;
      }

      final doc = querySnap.docs.first;

      if (doc['password'] != password) {
        if (!isAuto) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Wrong Password")));
        }
        await _clearSavedLogin();
        return;
      }

      // Validate selected role (user must choose role on login)
      final rawRole = doc['role'];
      final role = (rawRole is String) ? rawRole.trim() : rawRole.toString();
      if (_selectedRole == null) {
        if (!isAuto) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Please select a role')));
        }
        return;
      }
      // Normalize checks: Admin may be stored as 'Admin' or 'Admin (Global)'
      if (_selectedRole == 'Admin') {
        if (!(role == 'Admin' || role == 'Admin (Global)')) {
          if (!isAuto) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selected role does not match account'),
              ),
            );
          }
          await _clearSavedLogin();
          return;
        }
      } else if (_selectedRole == 'University Admin') {
        if (!(role.toLowerCase().contains('university'))) {
          if (!isAuto) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selected role does not match account'),
              ),
            );
          }
          await _clearSavedLogin();
          return;
        }
      } else if (_selectedRole == 'CR') {
        if (role != 'CR') {
          if (!isAuto) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selected role does not match account'),
              ),
            );
          }
          await _clearSavedLogin();
          return;
        }
      } else if (_selectedRole == 'Student') {
        if (role != 'Student') {
          if (!isAuto) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selected role does not match account'),
              ),
            );
          }
          await _clearSavedLogin();
          return;
        }
      }

      // For non-admin roles ensure university matches selected
      final storedUni = (doc['universityId'] ?? '').toString();
      if (!(_selectedRole == 'Admin') && !(_selectedRole == 'Admin (Global)')) {
        if (_selectedUniversityId == null ||
            _selectedUniversityId != storedUni) {
          if (!isAuto) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Selected university does not match account. Please choose the correct university.',
                ),
              ),
            );
          }
          await _clearSavedLogin();
          return;
        }
      }

      // Persist login details including role and university
      await _saveLogin(
        roll,
        password,
        role: _selectedRole!,
        universityId: _selectedUniversityId,
      );

      if (!mounted) return;

      if (role == "Admin" || role == "Admin (Global)") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminPanel()),
        );
      } else if (role == "UniversityAdmin" || role == "University Admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UniversityAdminPage(
              universityId:
                  _selectedUniversityId ??
                  (doc['universityId'] ?? '').toString(),
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
              universityId: _selectedUniversityId ?? uniId,
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
              universityId: _selectedUniversityId ?? uniId,
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

  // Save login credentials and optional role/university for auto-login
  Future<void> _saveLogin(
    String roll,
    String password, {
    String? role,
    String? universityId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_roll', roll);
    await prefs.setString('saved_password', password);
    if (role != null) await prefs.setString('saved_role', role);
    if (universityId != null) {
      await prefs.setString('saved_university', universityId);
    }
  }

  // Clear saved credentials (used when login fails)
  Future<void> _clearSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_roll');
    await prefs.remove('saved_password');
    await prefs.remove('saved_role');
    await prefs.remove('saved_university');
  }

  Future<void> _loadUniversities() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('universities')
          .orderBy('name')
          .get();
      final List<DropdownMenuItem<String>> items = [];
      for (var doc in snap.docs) {
        items.add(DropdownMenuItem(value: doc.id, child: Text(doc['name'])));
      }
      setState(() {
        _universityItems = items;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading universities: $e")));
    }
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
                  height: screenHeight * 0.18,
                  alignment: Alignment.center,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.deepPurple, Colors.purpleAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.school, size: 60, color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
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

                const SizedBox(height: 24),

                // Role selector
                _buildDropdown<String?>(
                  value: _selectedRole,
                  hint: 'Select Role',
                  items: _roles
                      .map(
                        (r) =>
                            DropdownMenuItem<String?>(value: r, child: Text(r)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedRole = v),
                ),

                const SizedBox(height: 16),

                // University selector for non-admin roles
                if (_selectedRole != null && _selectedRole != 'Admin')
                  _buildDropdown<String?>(
                    value: _selectedUniversityId,
                    hint: 'Select University',
                    items: _universityItems,
                    onChanged: (v) => setState(() => _selectedUniversityId = v),
                  ),

                const SizedBox(height: 16),

                // Roll ID
                _buildTextField(
                  controller: rollController,
                  label: 'Roll ID',
                  icon: Icons.perm_identity,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Password
                _buildTextField(
                  controller: passwordController,
                  label: 'Password',
                  icon: Icons.lock,
                  obscureText: true,
                ),
                const SizedBox(height: 20),

                // Login button
                _buildGradientButton(
                  text: isLoading ? 'Please wait...' : 'Login',
                  onPressed: isLoading ? () {} : loginUser,
                ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RegisterScreen()),
                    );
                  },
                  child: Text(
                    'Don\'t have an account? Register here',
                    style: TextStyle(color: Colors.deepPurple),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- TextField builder (same as register theme) ----------------
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

  // ---------------- Dropdown builder (same as register theme) ----------------
  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.deepPurple),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  // ---------------- Gradient Button (same as register theme) ----------------
  Widget _buildGradientButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return AnimatedContainer(
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
          onTap: onPressed,
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
