import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UniversityAdminPage extends StatefulWidget {
  final String universityId;
  final int ownerRoll;
  const UniversityAdminPage({
    super.key,
    required this.universityId,
    required this.ownerRoll,
  });

  @override
  State<UniversityAdminPage> createState() => _UniversityAdminPageState();
}

class _UniversityAdminPageState extends State<UniversityAdminPage> {
  final TextEditingController batchNameCtrl = TextEditingController();
  final TextEditingController deptNameCtrl = TextEditingController();
  final TextEditingController subjectNameCtrl = TextEditingController();
  final TextEditingController startRollCtrl = TextEditingController();
  final TextEditingController endRollCtrl = TextEditingController();
  final TextEditingController extraRollsCtrl = TextEditingController();
  final TextEditingController deptCrRollCtrl = TextEditingController();

  String? selectedBatchIdForDept; // batch to create departments under
  String?
  selectedDeptIdForSubject; // department to create subjects under (value format: batchId|deptId)

  bool isBusy = false;

  @override
  void dispose() {
    batchNameCtrl.dispose();
    deptCrRollCtrl.dispose();
    deptNameCtrl.dispose();
    subjectNameCtrl.dispose();
    startRollCtrl.dispose();
    endRollCtrl.dispose();
    extraRollsCtrl.dispose();
    super.dispose();
  }

  Future<void> _createBatch() async {
    if (batchNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter Batch name')));
      return;
    }
    setState(() => isBusy = true);
    try {
      await FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(batchNameCtrl.text.trim())
          .set({
            'name': batchNameCtrl.text.trim(),
            'createdAt': Timestamp.now(),
          });
      batchNameCtrl.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Batch created')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => isBusy = false);
  }

  Future<void> _createDepartment() async {
    if (deptNameCtrl.text.trim().isEmpty ||
        selectedBatchIdForDept == null ||
        deptCrRollCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a Batch, enter Department name and CR Roll'),
        ),
      );
      return;
    }
    final int? crRoll = int.tryParse(deptCrRollCtrl.text.trim());
    if (crRoll == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department CR Roll must be a number')),
      );
      return;
    }
    setState(() => isBusy = true);
    try {
      await FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(selectedBatchIdForDept)
          .collection('departments')
          .doc(deptNameCtrl.text.trim())
          .set({
            'name': deptNameCtrl.text.trim(),
            'crRoll': crRoll,
            'createdAt': Timestamp.now(),
          });
      deptNameCtrl.clear();
      deptCrRollCtrl.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Department created')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => isBusy = false);
  }

  Future<void> _createSubject() async {
    if (subjectNameCtrl.text.trim().isEmpty ||
        selectedDeptIdForSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a Department and fill Subject name & rolls'),
        ),
      );
      return;
    }
    final int? startRoll = int.tryParse(startRollCtrl.text.trim());
    final int? endRoll = int.tryParse(endRollCtrl.text.trim());
    if (startRoll == null || endRoll == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start/End Student ID must be numbers')),
      );
      return;
    }
    List<int> extraRolls = [];
    if (extraRollsCtrl.text.trim().isNotEmpty) {
      try {
        extraRolls = extraRollsCtrl.text
            .split(',')
            .map((e) => int.parse(e.trim()))
            .toList();
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Extra Student IDs must be comma-separated numbers'),
          ),
        );
        return;
      }
    }

    setState(() => isBusy = true);
    try {
      final ids = selectedDeptIdForSubject!.split(
        '|',
      ); // format: batchId|deptId
      final String batchId = ids[0];
      final String deptId = ids[1];

      await FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(batchId)
          .collection('departments')
          .doc(deptId)
          .collection('subjects')
          .add({
            'name': subjectNameCtrl.text.trim(),
            'startRoll': startRoll,
            'endRoll': endRoll,
            'extraRolls': extraRolls,
            'createdAt': Timestamp.now(),
          });

      subjectNameCtrl.clear();
      startRollCtrl.clear();
      endRollCtrl.clear();
      extraRollsCtrl.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subject created')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => isBusy = false);
  }

  Future<void> _deleteByRef(DocumentReference ref) async {
    try {
      await ref.delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('universities')
              .doc(widget.universityId)
              .snapshots(),
          builder: (context, snap) {
            String title = 'University Admin';
            if (snap.hasData && snap.data!.exists) {
              final data = snap.data!.data() as Map<String, dynamic>?;
              final name = data?['name'] as String?;
              if (name != null && name.isNotEmpty) title = name;
            }
            return Text(title);
          },
        ),
      ),
      body: isBusy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Manage Batches
                  const Text(
                    'Manage Batches',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: batchNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Batch name',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _createBatch,
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('universities')
                        .doc(widget.universityId)
                        .collection('batches')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox();
                      final batches = snap.data!.docs;
                      return Column(
                        children: batches.map((b) {
                          final bRef = b.reference;
                          return ListTile(
                            title: Text(b['name'] ?? '1'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteByRef(bRef),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const Divider(height: 32),

                  // Manage Departments under selected Batch
                  const Text(
                    'Manage Departments (under Batch)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('universities')
                        .doc(widget.universityId)
                        .collection('batches')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox();
                      final batchItems = snap.data!.docs
                          .map(
                            (b) => DropdownMenuItem<String>(
                              value: b.id,
                              child: Text(b['name'] ?? '1'),
                            ),
                          )
                          .toList();
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedBatchIdForDept,
                              items: batchItems,
                              decoration: const InputDecoration(
                                labelText: 'Select Batch',
                              ),
                              onChanged: (v) =>
                                  setState(() => selectedBatchIdForDept = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: deptNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Department name',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: deptCrRollCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Department CR Roll',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _createDepartment,
                            child: const Text('Create'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedBatchIdForDept != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('universities')
                          .doc(widget.universityId)
                          .collection('batches')
                          .doc(selectedBatchIdForDept)
                          .collection('departments')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox();
                        return Column(
                          children: snap.data!.docs.map((d) {
                            final dRef = d.reference;
                            return ListTile(
                              title: Text(d['name'] ?? '1'),
                              subtitle: Text(
                                'CR Roll: ' + (d['crRoll']?.toString() ?? '1'),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteByRef(dRef),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                  const Divider(height: 32),

                  // Manage Subjects under Department
                  const Text(
                    'Manage Subjects (under Department)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Department selector combining batchId|deptId value
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('universities')
                        .doc(widget.universityId)
                        .collection('batches')
                        .snapshots(),
                    builder: (context, batchesSnap) {
                      if (!batchesSnap.hasData) return const SizedBox();
                      return FutureBuilder<List<DropdownMenuItem<String>>>(
                        future: _buildDepartmentDropdownItems(),
                        builder: (context, depFuture) {
                          final items = depFuture.data ?? [];
                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedDeptIdForSubject,
                                  items: items,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Department',
                                  ),
                                  onChanged: (v) => setState(
                                    () => selectedDeptIdForSubject = v,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: subjectNameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Subject name',
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startRollCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Start Student ID',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: endRollCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'End Student ID',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: extraRollsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Extra Student IDs (comma separated)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _createSubject,
                        child: const Text('Add Subject'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  if (selectedDeptIdForSubject != null)
                    Builder(
                      builder: (context) {
                        final ids = selectedDeptIdForSubject!.split('|');
                        if (ids.length < 2 || ids[1].isEmpty)
                          return const SizedBox();
                        final batchId = ids[0];
                        final depId = ids[1];
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('universities')
                              .doc(widget.universityId)
                              .collection('batches')
                              .doc(batchId)
                              .collection('departments')
                              .doc(depId)
                              .collection('subjects')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, subSnap) {
                            if (!subSnap.hasData) return const SizedBox();
                            return Column(
                              children: subSnap.data!.docs.map((s) {
                                final sRef = s.reference;
                                final List<dynamic> extras =
                                    (s['extraRolls'] ?? []) as List<dynamic>;
                                final extrasStr = extras.isEmpty
                                    ? ''
                                    : (' • extras: ' + extras.join(','));
                                return ListTile(
                                  title: Text(
                                    (s['name'] ?? '1') +
                                        ' • [' +
                                        (s['startRoll']?.toString() ?? '1') +
                                        '-' +
                                        (s['endRoll']?.toString() ?? '1') +
                                        ']' +
                                        extrasStr,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteByRef(sRef),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
                    ),

                  const SizedBox(height: 24),
                  const Text(
                    'Note: University Admin cannot start attendance session and cannot create another university.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
    );
  }

  Future<List<DropdownMenuItem<String>>> _buildDepartmentDropdownItems() async {
    final List<DropdownMenuItem<String>> items = [];
    final batches = await FirebaseFirestore.instance
        .collection('universities')
        .doc(widget.universityId)
        .collection('batches')
        .get();
    for (final b in batches.docs) {
      final depSnap = await FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(b.id)
          .collection('departments')
          .get();
      for (final d in depSnap.docs) {
        items.add(
          DropdownMenuItem<String>(
            value: '${b.id}|${d.id}',
            child: Text('${b['name'] ?? '1'} • ${d['name'] ?? '1'}'),
          ),
        );
      }
    }
    return items;
  }
}
