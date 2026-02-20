import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
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

  // Show full attendance sheet UI (CR by default). Students see buttons first.
  bool _showAttendanceSheet = false;

  @override
  void initState() {
    super.initState();
    universityId = widget.universityId;
    departmentId = widget.departmentId;
    batch = widget.batch;
    subjectId = widget.subjectId;
    role = widget.role;
    userRoll = widget.userRoll;

    _showAttendanceSheet = role == 'CR';
  }

  /// 🔹 Fetch header info: university, batch, department, subject
  Future<Map<String, String>> getHeaderInfo() async {
    try {
      final univDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(universityId)
          .get();
      final batchDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(universityId)
          .collection('batches')
          .doc(batch)
          .get();
      final deptDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(universityId)
          .collection('batches')
          .doc(batch)
          .collection('departments')
          .doc(departmentId)
          .get();
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

      return {
        'university': univDoc['name'] ?? 'University',
        'batch': batchDoc['name'] ?? 'Batch',
        'department': deptDoc['name'] ?? 'Department',
        'subject': subjDoc['name'] ?? 'Subject',
      };
    } catch (_) {
      return {
        'university': 'University',
        'batch': 'Batch',
        'department': 'Department',
        'subject': 'Subject',
      };
    }
  }

  /// 🔹 Get all rolls including extra
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

    final rolls = [for (int i = startRoll; i <= endRoll; i++) i];
    rolls.addAll(extra.cast<int>());
    rolls.sort();
    return rolls;
  }

  /// 🔹 Start a new attendance session
  Future<void> startAttendance(List<int> rolls) async {
    try {
      // Ensure there is no active session already for this subject
      final activeQuery = await FirebaseFirestore.instance
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
          .get();

      if (activeQuery.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'An active attendance session already exists. Please close it before starting a new one.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // If no active session, proceed to create one
      final attendanceMap = {for (var r in rolls) r.toString(): false};

      // Get CR's current location to use as the center
      final position = await FraudDetectionService.getCurrentLocation();

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
            // Save center from CR location if available
            if (position != null) 'crCenterLat': position.latitude,
            if (position != null) 'crCenterLon': position.longitude,
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start attendance: $e')),
        );
      }
    }
  }

  /// 🔹 Close attendance session
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
        .update({'isActive': false, 'closedAt': DateTime.now()});
  }

  /// 🔹 Update attendance (Student & CR)
  Future<void> updateAttendance(String sessionId, int roll, bool value) async {
    try {
      // Persist deviceId and user location with the attendance
      final deviceId = await FraudDetectionService.getDeviceId();
      final position = await FraudDetectionService.getCurrentLocation();

      final Map<String, dynamic> locPayload = {
        'deviceId': deviceId,
        'timestamp': Timestamp.now(),
      };
      if (position != null) {
        locPayload['latitude'] = position.latitude;
        locPayload['longitude'] = position.longitude;
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
          .update({
            'attendance.${roll.toString()}': value,
            'locationData.${roll.toString()}': locPayload,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attendance ${value ? 'marked present' : 'marked absent'} for $roll${position == null ? ' (no location)' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update attendance: $e')),
        );
      }
    }
  }

  /// 🔹 Detect cheating for a session
  Future<CheatDetectionResult?> detectCheatingInSession(
    String sessionId,
  ) async {
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
      final macMap = <String, List<int>>{};

      for (final roll in attendanceData.keys) {
        final isPresent = attendanceData[roll] ?? false;
        if (isPresent && locationData.containsKey(roll)) {
          final loc = locationData[roll];
          final mac = loc['macAddress'];
          if (mac is String && mac.isNotEmpty) {
            macMap.putIfAbsent(mac, () => []).add(int.parse(roll));
          }
          final lat = loc['latitude'];
          final lon = loc['longitude'];
          if (lat is num && lon is num) {
            records.add(
              AttendanceRecord(
                roll: int.parse(roll),
                latitude: lat.toDouble(),
                longitude: lon.toDouble(),
                deviceId: mac ?? 'UNKNOWN',
                timestamp: loc['timestamp']?.toDate() ?? DateTime.now(),
              ),
            );
          }
        }
      }

      final duplicateMacs = <int>[];
      for (var rolls in macMap.values) {
        if (rolls.length > 1) duplicateMacs.addAll(rolls);
      }

      if (records.isEmpty && duplicateMacs.isEmpty) return null;
      final result = FraudDetectionService.detectCheating(records);
      return CheatDetectionResult(
        duplicateMacRolls: [...duplicateMacs, ...result.duplicateMacRolls],
        outlierLocationRolls: result.outlierLocationRolls,
        locationStats: result.locationStats,
      );
    } catch (e) {
      return null;
    }
  }

  /// Student: Give attendance if a live session exists
  Future<void> _giveAttendance() async {
    try {
      // First verify student ID exists in this subject
      final rolls = await getAllRolls();
      if (!rolls.contains(userRoll)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your student ID is not registered for this subject',
              ),
            ),
          );
        }
        return;
      }

      final liveQuery = await FirebaseFirestore.instance
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
          .get();

      if (liveQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No live session available')),
          );
        }
        return;
      }

      final sessionId = liveQuery.docs.first.id;
      await updateAttendance(sessionId, userRoll, true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Attendance submitted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error giving attendance: $e')));
      }
    }
  }

  void _showAttendancePage() {
    setState(() {
      _showAttendanceSheet = true;
    });
  }

  /// 🔹 Print attendance sheet as PDF (CR only)
  Future<void> _printAttendancePdf() async {
    try {
      // Fetch all sessions for this subject
      final sessionsSnap = await FirebaseFirestore.instance
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
          .get();

      final sessions = sessionsSnap.docs;
      if (sessions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No attendance sessions available')),
          );
        }
        return;
      }

      final rolls = await getAllRolls();
      final presentCount = <int, int>{for (var r in rolls) r: 0};

      for (final s in sessions) {
        final attendance = s['attendance'] as Map<String, dynamic>? ?? {};
        for (final r in rolls) {
          if (attendance[r.toString()] == true) {
            presentCount[r] = (presentCount[r] ?? 0) + 1;
          }
        }
      }

      final total = sessions.length;

      // Build PDF
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Attendance Report',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text('Subject: $subjectId'),
              pw.Text('Total sessions: $total'),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: [
                  'Student ID',
                  'Present',
                  'Total Sessions',
                  'Percentage',
                ],
                data: rolls.map((r) {
                  final present = presentCount[r] ?? 0;
                  final pct = total > 0 ? (present / total) * 100 : 0.0;
                  return [
                    r.toString(),
                    present.toString(),
                    total.toString(),
                    '${pct.toStringAsFixed(2)}%',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Generated: ${DateTime.now()}'),
            ];
          },
        ),
      );

      // Send to printer / share dialog
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Subject Attendance"),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<Map<String, String>>(
        future: getHeaderInfo(),
        builder: (context, headerSnapshot) {
          if (!headerSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final header = headerSnapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 📌 Header Info
                Card(
                  color: Colors.deepPurple.shade50,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "University: ${header['university']}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Batch: ${header['batch']}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Department: ${header['department']}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Subject: ${header['subject']}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 🔴 CR Start Attendance
                if (role == "CR")
                  FutureBuilder<List<int>>(
                    future: getAllRolls(),
                    builder: (context, rollsSnap) {
                      if (!rollsSnap.hasData) return const SizedBox();
                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("Start Attendance"),
                        onPressed: () async =>
                            await startAttendance(rollsSnap.data!),
                      );
                    },
                  ),

                if (role == "Student" && !_showAttendanceSheet) ...[
                  // Student view: Give Attendance & View Sheet buttons
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text("Give Attendance"),
                    onPressed: _giveAttendance,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    icon: const Icon(Icons.visibility),
                    label: const Text("View Attendance Sheet"),
                    onPressed: _showAttendancePage,
                  ),
                ],

                const SizedBox(height: 10),

                // 🔴 Live Attendance Controls
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
                  builder: (context, liveSnap) {
                    if (!liveSnap.hasData || liveSnap.data!.docs.isEmpty) {
                      return const SizedBox();
                    }
                    final sessionId = liveSnap.data!.docs.first.id;

                    return Column(
                      children: [
                        Text(
                          "⚡ Live Attendance Running",
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (role == "CR")
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                icon: const Icon(Icons.warning),
                                label: const Text("Check Cheaters"),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FraudMonitoringScreen(
                                        universityId: universityId,
                                        departmentId: departmentId,
                                        batch: batch,
                                        subjectId: subjectId,
                                        sessionId: sessionId,
                                      ),
                                    ),
                                  );
                                  if (result == true && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Attendance closed successfully",
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text("Close Attendance"),
                                onPressed: () async {
                                  await closeAttendance(sessionId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Attendance closed normally",
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 10),

                // 📊 Attendance Table
                if (_showAttendanceSheet) ...[
                  if (role == 'CR')
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                        ),
                        icon: const Icon(Icons.print),
                        label: const Text('Print Attendance PDF'),
                        onPressed: _printAttendancePdf,
                      ),
                    ),

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
                      builder: (context, sessionSnap) {
                        if (!sessionSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final sessions = sessionSnap.data!.docs;

                        return FutureBuilder<List<int>>(
                          future: getAllRolls(),
                          builder: (context, rollSnap) {
                            if (!rollSnap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final rolls = rollSnap.data!;

                            return SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 20,
                                  dataRowMinHeight: 60,
                                  dataRowMaxHeight: 80,
                                  columns: [
                                    const DataColumn(
                                      label: Text(
                                        "Roll No",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    ...sessions.map((s) {
                                      final date = (s['date'] as Timestamp)
                                          .toDate();
                                      return DataColumn(
                                        label: Text(
                                          "${date.day}-${date.month}-${date.year}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                  rows: rolls.map((roll) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(roll.toString())),
                                        ...sessions.map((s) {
                                          final attendance =
                                              s['attendance'] ?? {};
                                          final isPresent =
                                              attendance[roll.toString()] ??
                                              false;
                                          final isActive =
                                              s['isActive'] ?? false;
                                          return DataCell(
                                            isActive
                                                ? Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        roll.toString(),
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Colors.deepPurple,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Transform.scale(
                                                        scale: 0.9,
                                                        child: Checkbox(
                                                          value: isPresent,
                                                          onChanged: (val) async {
                                                            if (role ==
                                                                    "Student" &&
                                                                roll !=
                                                                    userRoll) {
                                                              return;
                                                            }
                                                            await updateAttendance(
                                                              s.id,
                                                              roll,
                                                              !isPresent,
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : Checkbox(
                                                    value: isPresent,
                                                    onChanged: null,
                                                  ),
                                          );
                                        }),
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
              ],
            ),
          );
        },
      ),
    );
  }
}
