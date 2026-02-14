import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final rollController = TextEditingController();
  final passwordController = TextEditingController();
  final adminPasswordController = TextEditingController();

  String? selectedUniversityId;
  String? selectedDepartmentId;
  String? selectedBatchId;

  String selectedRole = "Student";

  bool isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    rollController.dispose();
    passwordController.dispose();
    adminPasswordController.dispose();
    super.dispose();
  }

  /// ==============================
  /// REGISTER FUNCTION
  /// ==============================
  Future<void> registerUser() async {
    if (rollController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (selectedRole != "Admin") {
      if (selectedUniversityId == null ||
          selectedBatchId == null ||
          selectedDepartmentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select University, Batch & Department")),
        );
        return;
      }
    }

    setState(() => isLoading = true);

    try {
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

      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(rollController.text.trim())
          .get();

      if (existingUser.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User already exists")),
        );
        setState(() => isLoading = false);
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(rollController.text.trim())
          .set({
        'roll': int.parse(rollController.text.trim()),
        'password': passwordController.text.trim(),
        'role': selectedRole,
        'universityId': selectedRole == "Admin" ? null : selectedUniversityId,
        'departmentId': selectedRole == "Admin" ? null : selectedDepartmentId,
        'batch': selectedRole == "Admin" ? null : selectedBatchId,
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
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Fill in the details below to register",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),

                const SizedBox(height: 30),

                // ROLE SELECT
                _buildDropdown<String>(
                  value: selectedRole,
                  hint: "Select Role",
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
                      selectedBatchId = null;
                    });
                  },
                ),

                const SizedBox(height: 20),

                // UNIVERSITY SELECT
                if (selectedRole != "Admin")
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('universities').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return Container();
                      return _buildDropdown<String?>(
                        value: selectedUniversityId,
                        hint: "Select University",
                        items: snapshot.data!.docs.map((doc) {
                          return DropdownMenuItem<String?>(
                            value: doc.id,
                            child: Text(doc['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedUniversityId = value;
                            selectedBatchId = null;
                            selectedDepartmentId = null;
                          });
                        },
                      );
                    },
                  ),

                const SizedBox(height: 20),

                // BATCH SELECT
                if (selectedRole != "Admin" && selectedUniversityId != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('universities')
                        .doc(selectedUniversityId)
                        .collection('batches')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return Container();
                      return _buildDropdown<String?>(
                        value: selectedBatchId,
                        hint: "Select Batch",
                        items: snapshot.data!.docs.map((doc) {
                          return DropdownMenuItem<String?>(
                            value: doc.id,
                            child: Text(doc['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedBatchId = value;
                            selectedDepartmentId = null;
                          });
                        },
                      );
                    },
                  ),

                const SizedBox(height: 20),

                // DEPARTMENT SELECT
                if (selectedRole != "Admin" &&
                    selectedUniversityId != null &&
                    selectedBatchId != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('universities')
                        .doc(selectedUniversityId)
                        .collection('batches')
                        .doc(selectedBatchId)
                        .collection('departments')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return Container();
                      return _buildDropdown<String?>(
                        value: selectedDepartmentId,
                        hint: "Select Department",
                        items: snapshot.data!.docs.map((doc) {
                          return DropdownMenuItem<String?>(
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

                // Roll ID
                _buildTextField(controller: rollController, label: "Roll ID", icon: Icons.perm_identity, keyboardType: TextInputType.number),
                const SizedBox(height: 20),

                // Password
                _buildTextField(controller: passwordController, label: "Password", icon: Icons.lock, obscureText: true),
                const SizedBox(height: 20),

                // Admin secret password
                if (selectedRole == "Admin")
                  _buildTextField(controller: adminPasswordController, label: "Admin Secret Password", icon: Icons.vpn_key, obscureText: true),

                const SizedBox(height: 30),

                // REGISTER BUTTON
                isLoading
                    ? const CircularProgressIndicator()
                    : _buildGradientButton(
                        text: "Register",
                        onPressed: registerUser,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ---------------- TextField builder ----------------
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
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// ---------------- Dropdown builder ----------------
  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.deepPurple),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  /// ---------------- Gradient Button ----------------
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
