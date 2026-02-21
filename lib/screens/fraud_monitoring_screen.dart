import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/fraud_detection_service.dart';

class FraudMonitoringScreen extends StatefulWidget {
  final String universityId;
  final String departmentId;
  final String batch;
  final String subjectId;
  final String sessionId;

  const FraudMonitoringScreen({
    super.key,
    required this.universityId,
    required this.departmentId,
    required this.batch,
    required this.subjectId,
    required this.sessionId,
  });

  @override
  State<FraudMonitoringScreen> createState() => _FraudMonitoringScreenState();
}

class _FraudMonitoringScreenState extends State<FraudMonitoringScreen> {
  CheatDetectionResult? detectionResult;
  List<int> manuallyRemovedStudents = [];
  Map<int, Map<String, dynamic>> allLocationData = {};

  @override
  void initState() {
    super.initState();
    _loadFraudDetection();
  }

  Future<void> _loadFraudDetection() async {
    try {
      print('Loading fraud detection for session: ${widget.sessionId}');

      final sessionDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(widget.batch)
          .collection('departments')
          .doc(widget.departmentId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('attendanceSessions')
          .doc(widget.sessionId)
          .get();

      print('Session doc exists: ${sessionDoc.exists}');
      print('Session data: ${sessionDoc.data()}');

      final locationData = sessionDoc['locationData'] ?? {};
      final attendanceData = sessionDoc['attendance'] ?? {};
      // Optional CR center from session
      final crCenterLat = (sessionDoc.data()?['crCenterLat'] as num?)
          ?.toDouble();
      final crCenterLon = (sessionDoc.data()?['crCenterLon'] as num?)
          ?.toDouble();

      print('Location data keys: ${locationData.keys}');
      print('Attendance data keys: ${attendanceData.keys}');

      // Store all location data for later access
      allLocationData = <int, Map<String, dynamic>>{};

      final records = <AttendanceRecord>[];
      final deviceMap = <String, List<int>>{};

      for (final roll in attendanceData.keys) {
        final isPresent = attendanceData[roll] ?? false;
        if (!isPresent) continue;

        if (locationData.containsKey(roll)) {
          final locData = locationData[roll];
          if (locData is Map) {
            allLocationData[int.parse(roll)] = Map<String, dynamic>.from(
              locData,
            );

            final deviceId = locData['deviceId'];
            if (deviceId is String && deviceId.isNotEmpty) {
              deviceMap.putIfAbsent(deviceId, () => []).add(int.parse(roll));
            }

            final lat = locData['latitude'];
            final lon = locData['longitude'];
            if (lat is num && lon is num) {
              records.add(
                AttendanceRecord(
                  roll: int.parse(roll),
                  latitude: lat.toDouble(),
                  longitude: lon.toDouble(),
                  deviceId: deviceId is String ? deviceId : '',
                  timestamp: (locData['timestamp'] is Timestamp)
                      ? (locData['timestamp'] as Timestamp).toDate()
                      : DateTime.now(),
                ),
              );
            }
          }
        }
      }

      print('Records collected: ${records.length}');

      final duplicateDevices = <int>[];
      for (final rolls in deviceMap.values) {
        if (rolls.length > 1) {
          duplicateDevices.addAll(rolls);
        }
      }

      CheatDetectionResult? result;

      if (records.isNotEmpty) {
        if (crCenterLat != null && crCenterLon != null) {
          result = FraudDetectionService.detectCheatingWithCenter(
            records,
            crCenterLat,
            crCenterLon,
            radiusMeters: 20000,
          );
        } else {
          result = FraudDetectionService.detectCheating(records);
        }
        // merge duplicate device detection
        result = CheatDetectionResult(
          duplicateMacRolls: <int>{
            ...result.duplicateMacRolls,
            ...duplicateDevices,
          }.toList(),
          outlierLocationRolls: result.outlierLocationRolls,
          locationStats: result.locationStats,
        );
      } else {
        result = CheatDetectionResult(
          duplicateMacRolls: duplicateDevices,
          outlierLocationRolls: [],
          locationStats: {
            'centerLatitude': crCenterLat ?? 0.0,
            'centerLongitude': crCenterLon ?? 0.0,
            'meanDistance': 0.0,
            'stdDeviation': 0.0,
            'allDistances': <int, double>{},
          },
        );
      }

      if (mounted) {
        setState(() {
          detectionResult = result;
        });
      }
    } catch (e) {
      print('Error loading fraud detection: $e');
      // Set empty result to prevent infinite loading
      if (mounted) {
        setState(() {
          detectionResult = CheatDetectionResult(
            duplicateMacRolls: [],
            outlierLocationRolls: [],
            locationStats: {
              'centerLatitude': 0.0,
              'centerLongitude': 0.0,
              'meanDistance': 0.0,
              'stdDeviation': 0.0,
              'allDistances': <int, double>{},
            },
          );
        });
      }
    }
  }

  void _removeStudentAttendance(int roll) {
    setState(() {
      manuallyRemovedStudents.add(roll);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marked student $roll for removal'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              manuallyRemovedStudents.remove(roll);
            });
          },
        ),
      ),
    );
  }

  Future<void> _confirmAndClose() async {
    try {
      // Get current session data
      final sessionDoc = await FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(widget.batch)
          .collection('departments')
          .doc(widget.departmentId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('attendanceSessions')
          .doc(widget.sessionId)
          .get();

      final attendanceData =
          sessionDoc['attendance'] as Map<String, dynamic>? ?? {};

      // Remove marked students from attendance
      final updatedAttendance = Map<String, dynamic>.from(attendanceData);
      for (final studentRoll in manuallyRemovedStudents) {
        updatedAttendance[studentRoll.toString()] = false;
      }

      // Get all cheaters
      final allCheaters = <int>{
        ...?detectionResult?.duplicateMacRolls,
        ...?detectionResult?.outlierLocationRolls,
        ...manuallyRemovedStudents,
      }.toList();

      // Update session with final data
      await FirebaseFirestore.instance
          .collection('universities')
          .doc(widget.universityId)
          .collection('batches')
          .doc(widget.batch)
          .collection('departments')
          .doc(widget.departmentId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('attendanceSessions')
          .doc(widget.sessionId)
          .update({
            'isActive': false,
            'closedAt': DateTime.now(),
            'detectedCheaters': allCheaters,
            'attendance': updatedAttendance,
          });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attendance closed. ${allCheaters.length} cheaters marked',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error closing attendance: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Fraud Monitoring"), elevation: 0),
      body: detectionResult == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Loading fraud detection data..."),
                ],
              ),
            )
          : DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  /// TAB BAR
                  const TabBar(
                    tabs: [
                      Tab(text: "📊 Scatter Plot"),
                      Tab(text: "🚨 Cheaters List"),
                      Tab(text: "📱 MAC Address"),
                    ],
                  ),

                  /// TAB CONTENT
                  Expanded(
                    child: TabBarView(
                      children: [
                        /// SCATTER PLOT TAB
                        _buildScatterTab(),

                        /// CHEATERS LIST TAB
                        _buildCheatersList(),

                        /// MAC ADDRESS TAB
                        _buildMacAddressTab(),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Back"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: _confirmAndClose,
                          child: const Text("Confirm & Close"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildScatterTab() {
    // Collect valid latitude/longitude pairs
    final points = <int, LatLng>{};
    for (final entry in allLocationData.entries) {
      final locData = entry.value;
      final lat = locData['latitude'];
      final lon = locData['longitude'];
      if (lat is num && lon is num) {
        points[entry.key] = LatLng(lat.toDouble(), lon.toDouble());
      }
    }

    if (points.isEmpty) {
      return const Center(child: Text("No location data available"));
    }

    // Compute center from detectionResult if available, else mean of points
    final centerLat =
        (detectionResult?.locationStats['centerLatitude'] as double?) ??
        (points.values.map((p) => p.latitude).reduce((a, b) => a + b) /
            points.length);
    final centerLon =
        (detectionResult?.locationStats['centerLongitude'] as double?) ??
        (points.values.map((p) => p.longitude).reduce((a, b) => a + b) /
            points.length);

    final isOutlierSet = Set<int>.from(
      detectionResult?.outlierLocationRolls ?? const <int>[],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: CustomPaint(
                painter: _ScatterPainter(
                  points: points,
                  center: LatLng(centerLat, centerLon),
                  outliers: isOutlierSet,
                ),
                child: Container(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _LegendDot(color: Colors.green, label: 'Center'),
                  SizedBox(width: 12),
                  _LegendDot(color: Colors.blue, label: 'Present'),
                  SizedBox(width: 12),
                  _LegendDot(color: Colors.red, label: 'Outlier'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCheatersList() {
    final duplicateMacCheaters = detectionResult?.duplicateMacRolls ?? [];
    final locationCheaters = detectionResult?.outlierLocationRolls ?? [];
    final allStudentData =
        detectionResult?.locationStats['allDistances'] as Map<int, double>? ??
        {};

    return SingleChildScrollView(
      child: Column(
        children: [
          /// DUPLICATE MAC SECTION
          if (duplicateMacCheaters.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade100,
                  child: const Text(
                    "🚨 Same Device (MAC Address) - DEFINITE CHEATERS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                ...duplicateMacCheaters.map(
                  (roll) =>
                      _buildStudentCard(roll, 'MAC Address Match', Colors.red),
                ),
              ],
            ),

          /// LOCATION OUTLIERS SECTION
          if (locationCheaters.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange.shade100,
                  child: const Text(
                    "📍 Suspicious Location - POSSIBLE CHEATERS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                ...locationCheaters.map((roll) {
                  final distance = allStudentData[roll] ?? 0;
                  return _buildStudentCard(
                    roll,
                    '${distance.toStringAsFixed(2)}m from class center',
                    Colors.orange,
                  );
                }),
              ],
            ),

          if (duplicateMacCheaters.isEmpty && locationCheaters.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "✅ No cheaters detected!",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),

          /// MANUALLY REMOVED SECTION
          if (manuallyRemovedStudents.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.purple.shade100,
                  child: const Text(
                    "📝 Manually Marked for Removal",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
                ...manuallyRemovedStudents.map(
                  (roll) => _buildStudentCard(
                    roll,
                    'Marked for removal',
                    Colors.purple,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStudentCard(int roll, String reason, Color color) {
    final isManuallyRemoved = manuallyRemovedStudents.contains(roll);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(
            roll.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text("Student ID: $roll"),
        subtitle: Text(reason),
        trailing: isManuallyRemoved
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => _removeStudentAttendance(roll),
                icon: const Icon(Icons.remove_circle),
                label: const Text("Remove"),
              ),
      ),
    );
  }

  Widget _buildMacAddressTab() {
    if (allLocationData.isEmpty) {
      return const Center(child: Text("No location/device data available"));
    }

    final sortedRolls = allLocationData.keys.toList()..sort();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(
              label: Text(
                "Student ID",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                "Device ID",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                "Latitude",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                "Longitude",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                "Distance",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                "Status",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: sortedRolls.map((roll) {
            final locData = allLocationData[roll];
            final distance =
                detectionResult?.locationStats['allDistances'][roll];
            final latValue = locData?['latitude'];
            final lonValue = locData?['longitude'];
            final isDuplicateDevice =
                detectionResult?.duplicateMacRolls.contains(roll) ?? false;
            final isOutlier =
                detectionResult?.outlierLocationRolls.contains(roll) ?? false;

            String status = "✅ OK";
            Color statusColor = Colors.green;

            if (isDuplicateDevice) {
              status = "🚨 Duplicate Device";
              statusColor = Colors.red;
            } else if (isOutlier) {
              status = "⚠️ Outlier Location";
              statusColor = Colors.orange;
            }

            return DataRow(
              cells: [
                DataCell(Text(roll.toString())),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      locData?['deviceId'] ?? 'UNKNOWN',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    latValue is num
                        ? latValue.toDouble().toStringAsFixed(6)
                        : '-',
                  ),
                ),
                DataCell(
                  Text(
                    lonValue is num
                        ? lonValue.toDouble().toStringAsFixed(6)
                        : '-',
                  ),
                ),
                DataCell(
                  Text(
                    distance is num ? '${distance.toStringAsFixed(2)}m' : '-',
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      border: Border.all(color: statusColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ScatterPainter extends CustomPainter {
  final Map<int, LatLng> points;
  final LatLng center;
  final Set<int> outliers;

  _ScatterPainter({
    required this.points,
    required this.center,
    required this.outliers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLon = double.infinity, maxLon = -double.infinity;
    for (final p in points.values) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    const padding = 0.00005;
    minLat -= padding;
    maxLat += padding;
    minLon -= padding;
    maxLon += padding;

    double latRange = (maxLat - minLat).abs();
    double lonRange = (maxLon - minLon).abs();
    if (latRange == 0) latRange = 1e-9;
    if (lonRange == 0) lonRange = 1e-9;

    Offset toCanvas(LatLng geo) {
      final x = ((geo.longitude - minLon) / lonRange) * (size.width - 20) + 10;
      final y = ((maxLat - geo.latitude) / latRange) * (size.height - 20) + 10;
      return Offset(x, y);
    }

    final presentPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    final outlierPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    final centerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    points.forEach((roll, latLng) {
      final pt = toCanvas(latLng);
      Paint paint;
      if (outliers.contains(roll)) {
        paint = outlierPaint;
      } else {
        paint = presentPaint;
      }
      canvas.drawCircle(pt, 4, paint);
    });

    // Draw center
    {
      final pt = toCanvas(center);
      canvas.drawCircle(pt, 6, centerPaint);
    }

    final border = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.center != center ||
        oldDelegate.outliers != outliers;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
