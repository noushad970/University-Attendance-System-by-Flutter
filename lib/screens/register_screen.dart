import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final rollController = TextEditingController();
  final passwordController = TextEditingController();
  final adminPasswordController = TextEditingController();
  final TextEditingController universityNameController =
      TextEditingController();

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
    universityNameController.dispose();
    super.dispose();
  }

  /// ==============================
  /// REGISTER FUNCTION
  /// ==============================
  Future<void> registerUser() async {
    if (rollController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    // Validate role-specific required fields
    if (selectedRole == "Student" || selectedRole == "CR") {
      if (selectedUniversityId == null ||
          selectedBatchId == null ||
          selectedDepartmentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Select University, Batch & Department"),
          ),
        );
        return;
      }
    } else if (selectedRole == "UniversityAdmin") {
      if (universityNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Enter University Name")));
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      // Verify global Admin secret only for Admin role
      if (selectedRole == "Admin") {
        final configDoc = await FirebaseFirestore.instance
            .collection('config')
            .doc('admin_settings')
            .get();
        String correctPassword = configDoc['adminPassword'];
        if (adminPasswordController.text.trim() != correctPassword) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Wrong Admin Password")));
          setState(() => isLoading = false);
          return;
        }
      }

      final String rollId = rollController.text.trim();

      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(rollId)
          .get();

      if (existingUser.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("User already exists")));
        setState(() => isLoading = false);
        return;
      }

      // --- Role-specific roll validations ---
      final int? rollNum = int.tryParse(rollId);
      if (rollNum == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Roll must be a number")));
        setState(() => isLoading = false);
        return;
      }

      // Dept reference (only used for Student/CR roles) - safe because earlier we required selections
      final deptRef = FirebaseFirestore.instance
          .collection('universities')
          .doc(selectedUniversityId)
          .collection('batches')
          .doc(selectedBatchId)
          .collection('departments')
          .doc(selectedDepartmentId);

      final deptDoc = await deptRef.get();
      final crVal = deptDoc.data()?['crRoll'];
      final int? deptCrRoll = (crVal is int)
          ? crVal
          : int.tryParse(crVal?.toString() ?? '');

      // If registering as CR, the entered roll must match department CR
      if (selectedRole == "CR") {
        if (deptCrRoll == null || deptCrRoll != rollNum) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "CR roll must match the selected department's CR roll",
              ),
            ),
          );
          setState(() => isLoading = false);
          return;
        }
      }

      // If registering as Student, prevent CR roll usage and verify roll exists in subjects
      if (selectedRole == "Student") {
        if (deptCrRoll != null && deptCrRoll == rollNum) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "This roll is assigned as CR — please select CR as role",
              ),
            ),
          );
          setState(() => isLoading = false);
          return;
        }

        // Verify student roll exists within department subjects (startRoll..endRoll or extraRolls)
        final subjectsSnap = await deptRef.collection('subjects').get();
        bool found = false;
        for (final s in subjectsSnap.docs) {
          final data = s.data();
          final start = data['startRoll'];
          final end = data['endRoll'];
          final extra = (data['extraRolls'] is List)
              ? List.from(data['extraRolls'])
              : null;

          final int? startRoll = (start is int)
              ? start
              : int.tryParse(start?.toString() ?? '');
          final int? endRoll = (end is int)
              ? end
              : int.tryParse(end?.toString() ?? '');

          if (startRoll != null &&
              endRoll != null &&
              rollNum >= startRoll &&
              rollNum <= endRoll) {
            found = true;
            break;
          }

          if (extra != null) {
            for (final e in extra) {
              final int? ex = (e is int)
                  ? e
                  : int.tryParse(e?.toString() ?? '');
              if (ex == rollNum) {
                found = true;
                break;
              }
            }
            if (found) break;
          }
        }

        if (!found) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Invalid roll — not found in this department's student list",
              ),
            ),
          );
          setState(() => isLoading = false);
          return;
        }
      }

      String? createdUniversityId;

      // If registering as UniversityAdmin, ensure only one university per owner and create it
      if (selectedRole == "UniversityAdmin") {
        // Check if this owner already created a university
        final existingOwned = await FirebaseFirestore.instance
            .collection('universities')
            .where('ownerRoll', isEqualTo: int.parse(rollId))
            .limit(1)
            .get();
        if (existingOwned.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You already own a university")),
          );
          setState(() => isLoading = false);
          return;
        }

        final uniRef = await FirebaseFirestore.instance
            .collection('universities')
            .add({
              'name': universityNameController.text.trim(),
              'ownerRoll': int.parse(rollId),
              'createdAt': Timestamp.now(),
            });
        createdUniversityId = uniRef.id;
      }

      // Default fallback values (string "1") for nullable fields
      final String defaultString = "1";
      final String universityIdToSave = (selectedRole == "Admin")
          ? defaultString
          : (selectedRole == "UniversityAdmin"
                ? (createdUniversityId ?? defaultString)
                : (selectedUniversityId ?? defaultString));
      final String departmentIdToSave =
          (selectedRole == "Student" || selectedRole == "CR")
          ? (selectedDepartmentId ?? defaultString)
          : defaultString;
      final String batchToSave =
          (selectedRole == "Student" || selectedRole == "CR")
          ? (selectedBatchId ?? defaultString)
          : defaultString;

      // Ensure uniqueness of roll within the same university only
      final existingQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('roll', isEqualTo: int.parse(rollId))
          .where('universityId', isEqualTo: universityIdToSave)
          .limit(1)
          .get();
      if (existingQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User already exists in this university"),
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('users').add({
        'roll': int.parse(rollId),
        'password': passwordController.text.trim(),
        'role': selectedRole,
        'universityId': universityIdToSave,
        'departmentId': departmentIdToSave,
        'batch': batchToSave,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Registration Successful")));

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
                    DropdownMenuItem(
                      value: "UniversityAdmin",
                      child: Text("University Admin"),
                    ),
                    DropdownMenuItem(
                      value: "Admin",
                      child: Text("Admin (Global)"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value!;
                      selectedUniversityId = null;
                      selectedDepartmentId = null;
                      selectedBatchId = null;
                      universityNameController.clear();
                      adminPasswordController.clear();
                    });
                  },
                ),

                const SizedBox(height: 20),

                // University name input for UniversityAdmin role
                if (selectedRole == "UniversityAdmin")
                  _buildTextField(
                    controller: universityNameController,
                    label: "University Name",
                    icon: Icons.apartment,
                  ),

                const SizedBox(height: 20),

                // UNIVERSITY SELECT for Student/CR
                if (selectedRole != "Admin" &&
                    selectedRole != "UniversityAdmin")
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('universities')
                        .snapshots(),
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

                // BATCH SELECT for Student/CR
                if (selectedRole != "Admin" &&
                    selectedRole != "UniversityAdmin" &&
                    selectedUniversityId != null)
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

                // DEPARTMENT SELECT for Student/CR
                if (selectedRole != "Admin" &&
                    selectedRole != "UniversityAdmin" &&
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
                _buildTextField(
                  controller: rollController,
                  label: "Roll ID",
                  icon: Icons.perm_identity,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // Password
                _buildTextField(
                  controller: passwordController,
                  label: "Password",
                  icon: Icons.lock,
                  obscureText: true,
                ),
                const SizedBox(height: 20),

                // Admin secret password
                if (selectedRole == "Admin")
                  _buildTextField(
                    controller: adminPasswordController,
                    label: "Admin Secret Password",
                    icon: Icons.vpn_key,
                    obscureText: true,
                  ),

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

  /// ---------------- Dropdown builder ----------------
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
