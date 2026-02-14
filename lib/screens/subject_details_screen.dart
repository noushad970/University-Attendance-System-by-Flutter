import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fraud_detection_service.dart';
import 'fraud_monitoring_screen.dart';

class SubjectDetailsScreen extends StatefulWidget {
  final String universityId;
  final String departmentId;
  final String batch;
  final String subjectId;
  final String role;
  final int userRoll;

  const SubjectDetailsScreen({
    super.key,
    required this.universityId,
    required this.departmentId,
    required this.batch,
    required this.subjectId,
    required this.role,
    required this.userRoll,
  });

  @override
  State<SubjectDetailsScreen> createState() => _SubjectDetailsScreenState();
}

class _SubjectDetailsScreenState extends State<SubjectDetailsScreen> {
  late String universityId;
  late String departmentId;
  late String batch;
  late String subjectId;
  late String role;
  late int userRoll;

  @override
  void initState() {
    super.initState();
    universityId = widget.universityId;
    departmentId = widget.departmentId;
    batch = widget.batch;
    subjectId = widget.subjectId;
    role = widget.role;
    userRoll = widget.userRoll;
  }

  /// 🔹 Get Header Info
  Future<Map<String, String>> getHeaderInfo() async {
    try {
      // Get University name
      final univDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(universityId)
          .get();
      final universityName = univDoc['name'] ?? 'University';

      // Get Batch name
      final batchDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(universityId)
          .collection('batches')
          .doc(batch)
          .get();
      final batchName = batchDoc['name'] ?? 'Batch';

      // Get Department name
      final deptDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(universityId)
          .collection('batches')
          .doc(batch)
          .collection('departments')
          .doc(departmentId)
          .get();
      final departmentName = deptDoc['name'] ?? 'Department';

      // Get Subject name
      final subjDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(universityId)
          .collection('batches')
          .doc(batch)
          .collection('departments')
          .doc(departmentId)
          .collection('subjects')
          .doc(subjectId)
          .get();
      final subjectName = subjDoc['name'] ?? 'Subject';

      return {
        'university': universityName,
        'batch': batchName,
        'department': departmentName,
        'subject': subjectName,
      };
    } catch (e) {
      return {
        'university': 'University',
        'batch': 'Batch',
        'department': 'Department',
        'subject': 'Subject',
      };
    }
  }

  /// 🔹 Get All Rolls (Range + Extra)
  Future<List<int>> getAllRolls() async {
    final doc = await FirebaseFirestore.instance
        .collection('universities')
        .doc(universityId)
        .collection('batches')
        .doc(batch)
        .collection('departments')
        .doc(departmentId)
        .collection('subjects')
        .doc(subjectId)
        .get();

    int startRoll = doc['startRoll'];
    int endRoll = doc['endRoll'];
    List extra = doc['extraRolls'] ?? [];

    List<int> rolls = [];

    for (int i = startRoll; i <= endRoll; i++) {
      rolls.add(i);
    }

    rolls.addAll(extra.cast<int>());
    rolls.sort();

    return rolls;
  }

  /// 🔹 Start Attendance (Create Full Column)
  Future<void> startAttendance(List<int> rolls) async {
    Map<String, bool> attendanceMap = {};

    for (var roll in rolls) {
      attendanceMap[roll.toString()] = false;
    }

    await FirebaseFirestore.instance
        .collection('universities')
        .doc(universityId)
        .collection('batches')
        .doc(batch)
        .collection('departments')
        .doc(departmentId)
        .collection('subjects')
        .doc(subjectId)
        .collection('attendanceSessions')
        .add({
      'date': DateTime.now(),
      'isActive': true,
      'attendance': attendanceMap,
    });
  }

  /// 🔹 Close Attendance
  Future<void> closeAttendance(String sessionId) async {
    await FirebaseFirestore.instance
        .collection('universities')
        .doc(universityId)
        .collection('batches')
        .doc(batch)
        .collection('departments')
        .doc(departmentId)
        .collection('subjects')
        .doc(subjectId)
        .collection('attendanceSessions')
        .doc(sessionId)
        .update({
      'isActive': false,
      'closedAt': DateTime.now(),
    });
  }

  /// 🔹 Show Cheating Detection Dialog
  void showCheatingDetectionDialog(
      BuildContext context, String sessionId, CheatDetectionResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Attendance Fraud Detection"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.duplicateMacRolls.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "🚨 Same Device (MAC Address):",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    Text("Students: ${result.duplicateMacRolls.join(', ')}"),
                    const SizedBox(height: 12),
                  ],
                ),
              if (result.outlierLocationRolls.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "📍 Suspicious Location:",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    Text("Students: ${result.outlierLocationRolls.join(', ')}"),
                    const SizedBox(height: 12),
                  ],
                ),
              const Text(
                "Location Stats:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                  "Average Distance: ${(result.locationStats['meanDistance'] as double?)?.toStringAsFixed(2) ?? 'N/A'} m"),
              Text(
                  "Std Deviation: ${(result.locationStats['stdDeviation'] as double?)?.toStringAsFixed(2) ?? 'N/A'} m"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // Mark cheaters in database
              final cheatersSet = <int>{
                ...result.duplicateMacRolls,
                ...result.outlierLocationRolls,
              };

              await FirebaseFirestore.instance
                  .collection('universities')
                  .doc(universityId)
                  .collection('batches')
                  .doc(batch)
                  .collection('departments')
                  .doc(departmentId)
                  .collection('subjects')
                  .doc(subjectId)
                  .collection('attendanceSessions')
                  .doc(sessionId)
                  .update({
                'detectedCheaters': cheatersSet.toList(),
              });

              await closeAttendance(sessionId);

              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        "Closed with ${cheatersSet.length} suspected cheaters marked"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Confirm & Close"),
          ),
        ],
      ),
    );
  }

  /// 🔹 Update Attendance with Location & MAC Address
  Future<void> updateAttendance(
      String sessionId, int roll, bool value) async {
    try {
      // Get location and MAC address
      final record = await FraudDetectionService.createAttendanceRecord(roll);

      final updateData = {
        'attendance.${roll.toString()}': value,
      };

      // If location available, store it
      if (record != null) {
        updateData['locationData.${roll.toString()}'] = {
          'latitude': record.latitude,
          'longitude': record.longitude,
          'macAddress': record.macAddress,
          'timestamp': Timestamp.fromDate(record.timestamp),
        } as bool;
      }

      await FirebaseFirestore.instance
          .collection('universities')
          .doc(universityId)
          .collection('batches')
          .doc(batch)
          .collection('departments')
          .doc(departmentId)
          .collection('subjects')
          .doc(subjectId)
          .collection('attendanceSessions')
          .doc(sessionId)
          .update(updateData);
    } catch (e) {
      print('Error updating attendance: $e');
    }
  }

  /// 🔹 Detect Cheating Before Closing Attendance
  Future<CheatDetectionResult?> detectCheatingInSession(String sessionId) async {
    try {
      final sessionDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(universityId)
          .collection('batches')
          .doc(batch)
          .collection('departments')
          .doc(departmentId)
          .collection('subjects')
          .doc(subjectId)
          .collection('attendanceSessions')
          .doc(sessionId)
          .get();

      final locationData = sessionDoc['locationData'] ?? {};
      final attendanceData = sessionDoc['attendance'] ?? {};

      final records = <AttendanceRecord>[];

      for (final roll in attendanceData.keys) {
        final isPresent = attendanceData[roll] ?? false;
        if (isPresent && locationData.containsKey(roll)) {
          final locData = locationData[roll];
          records.add(AttendanceRecord(
            roll: int.parse(roll),
            latitude: locData['latitude'] ?? 0,
            longitude: locData['longitude'] ?? 0,
            macAddress: locData['macAddress'] ?? 'UNKNOWN',
            timestamp: locData['timestamp']?.toDate() ?? DateTime.now(),
          ));
        }
      }

      if (records.isEmpty) return null;

      return FraudDetectionService.detectCheating(records);
    } catch (e) {
      print('Error detecting cheating: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Subject Attendance")),

      body: FutureBuilder<Map<String, String>>(
        future: getHeaderInfo(),
        builder: (context, headerSnapshot) {
          if (!headerSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final headerInfo = headerSnapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                /// 📌 HEADER INFO
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "University: ${headerInfo['university']}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Batch: ${headerInfo['batch']}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Department: ${headerInfo['department']}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Subject: ${headerInfo['subject']}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

            /// 🔴 CR START BUTTON
            if (role == "CR")
              FutureBuilder<List<int>>(
                future: getAllRolls(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  return ElevatedButton(
                    onPressed: () async =>
                        await startAttendance(snapshot.data!),
                    child: const Text("Start Attendance"),
                  );
                },
              ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('universities')
                  .doc(universityId)
                  .collection('batches')
                  .doc(batch)
                  .collection('departments')
                  .doc(departmentId)
                  .collection('subjects')
                  .doc(subjectId)
                  .collection('attendanceSessions')
                  .where('isActive', isEqualTo: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox();
                }

                final sessionId = snapshot.data!.docs.first.id;

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Live Attendance Running",
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (role == "CR")
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FraudMonitoringScreen(
                                    universityId: universityId,
                                    departmentId: departmentId,
                                    batch: batch,
                                    subjectId: subjectId,
                                    sessionId: sessionId,
                                  ),
                                ),
                              );

                              // If returned true, attendance was closed
                              if (result == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Attendance closed successfully"),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.warning),
                            label: const Text("🚨 Check Cheaters"),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () async {
                              await closeAttendance(sessionId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Attendance closed normally"),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.close),
                            label: const Text("Close"),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 10),

            /// 📊 EXCEL STYLE TABLE
            SizedBox(
              height: 500,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('universities')
                    .doc(universityId)
                    .collection('batches')
                    .doc(batch)
                    .collection('departments')
                    .doc(departmentId)
                    .collection('subjects')
                    .doc(subjectId)
                    .collection('attendanceSessions')
                    .orderBy('date')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final sessions = snapshot.data!.docs;

                  return FutureBuilder<List<int>>(
                    future: getAllRolls(),
                    builder: (context, rollSnapshot) {
                      if (!rollSnapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final rolls = rollSnapshot.data!;

                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 20,
                            horizontalMargin: 10,
                            columns: [
                              const DataColumn(
                                  label: Text("Roll No",
                                      style: TextStyle(fontWeight: FontWeight.bold))),
                              ...sessions.map((session) {
                                DateTime date =
                                    (session['date'] as Timestamp)
                                        .toDate();
                                return DataColumn(
                                  label: Text(
                                      "${date.day}-${date.month}-${date.year}",
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                );
                              }).toList(),
                            ],
                            rows: rolls.map((roll) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                      Container(
                                        alignment: Alignment.centerLeft,
                                        child: Text(roll.toString(),
                                            style: const TextStyle(fontSize: 14)),
                                      )),

                                  ...sessions.map((session) {

                                    Map attendance =
                                        session['attendance'];

                                    bool isPresent =
                                        attendance[roll.toString()] ??
                                            false;

                                    bool isActive =
                                        session['isActive'];

                                    return DataCell(
                                      Container(
                                        alignment: Alignment.center,
                                        child: Checkbox(
                                          value: isPresent,
                                          onChanged: (!isActive)
                                              ? null
                                              : (value) async {
                                                  if (role == "Student" && roll !=
                                                          userRoll) {
                                                    return;
                                                  }

                                                  await updateAttendance(
                                                      session.id,
                                                      roll,
                                                      !isPresent);
                                                },
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
            ),
          );
        },
      ),
    );
  }
}
