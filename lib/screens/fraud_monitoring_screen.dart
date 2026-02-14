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
  GoogleMapController? mapController;
  Map<int, Map<String, dynamic>> allLocationData = {};

  @override
  void initState() {
    super.initState();
    _loadFraudDetection();
  }

  Future<void> _loadFraudDetection() async {
    try {
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

      final locationData = sessionDoc['locationData'] ?? {};
      final attendanceData = sessionDoc['attendance'] ?? {};

      // Store all location data for later access
      final allLocationData = <int, Map<String, dynamic>>{};

      final records = <AttendanceRecord>[];

      for (final roll in attendanceData.keys) {
        final isPresent = attendanceData[roll] ?? false;
        if (isPresent && locationData.containsKey(roll)) {
          final locData = locationData[roll];
          allLocationData[int.parse(roll)] = locData;
          records.add(AttendanceRecord(
            roll: int.parse(roll),
            latitude: locData['latitude'] ?? 0,
            longitude: locData['longitude'] ?? 0,
            macAddress: locData['macAddress'] ?? 'UNKNOWN',
            timestamp: locData['timestamp']?.toDate() ?? DateTime.now(),
          ));
        }
      }

      if (records.isNotEmpty) {
        final result = FraudDetectionService.detectCheating(records);
        setState(() {
          detectionResult = result;
          this.allLocationData = allLocationData;
        });
      }
    } catch (e) {
      print('Error loading fraud detection: $e');
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

      final attendanceData = sessionDoc['attendance'] as Map<String, dynamic>? ?? {};

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
            content: Text('Attendance closed. ${allCheaters.length} cheaters marked'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error closing attendance: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fraud Monitoring"),
        elevation: 0,
      ),
      body: detectionResult == null
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  /// TAB BAR
                  const TabBar(
                    tabs: [
                      Tab(text: "📍 Location Map"),
                      Tab(text: "🚨 Cheaters List"),
                      Tab(text: "📱 MAC Address"),
                    ],
                  ),

                  /// TAB CONTENT
                  Expanded(
                    child: TabBarView(
                      children: [
                        /// MAP TAB
                        _buildMapTab(),

                        /// CHEATERS LIST TAB
                        _buildCheatersList(),

                        /// MAC ADDRESS TAB
                        _buildMacAddressTab(),
                      ],
                    ),
                  ),

                  /// ACTION BUTTONS
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Back"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: _confirmAndClose,
                            child: const Text("Confirm & Close"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMapTab() {
    if (detectionResult?.locationStats['centerLatitude'] == null) {
      return const Center(child: Text("No location data available"));
    }

    final centerLat = detectionResult!.locationStats['centerLatitude'] as double;
    final centerLon = detectionResult!.locationStats['centerLongitude'] as double;
    final allDistances =
        detectionResult!.locationStats['allDistances'] as Map<int, double>;

    final markers = <Marker>{};

    // Add center marker
    markers.add(
      Marker(
        markerId: const MarkerId('center'),
        position: LatLng(centerLat, centerLon),
        infoWindow: const InfoWindow(title: '📍 Class Center Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    // Add student markers
    allDistances.forEach((roll, distance) {
      final isCheater = detectionResult!.outlierLocationRolls.contains(roll);
      markers.add(
        Marker(
          markerId: MarkerId('student_$roll'),
          position: LatLng(
            centerLat + (distance / 111000) * (roll % 2 == 0 ? 1 : -1),
            centerLon + (distance / 111000) * (roll % 3 == 0 ? 1 : -1),
          ),
          infoWindow: InfoWindow(
            title: 'Student ID: $roll',
            snippet: '${distance.toStringAsFixed(2)}m away',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isCheater ? BitmapDescriptor.hueRed : BitmapDescriptor.hueBlue,
          ),
        ),
      );
    });

    return GoogleMap(
      onMapCreated: (controller) {
        mapController = controller;
      },
      initialCameraPosition: CameraPosition(
        target: LatLng(centerLat, centerLon),
        zoom: 18,
      ),
      markers: markers,
      zoomControlsEnabled: true,
    );
  }

  Widget _buildCheatersList() {
    final duplicateMacCheaters = detectionResult?.duplicateMacRolls ?? [];
    final locationCheaters = detectionResult?.outlierLocationRolls ?? [];
    final allStudentData = detectionResult?.locationStats['allDistances'] as Map<int, double>? ?? {};

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
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
                ...duplicateMacCheaters.map((roll) => _buildStudentCard(roll, 'MAC Address Match', Colors.red)),
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
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
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
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                  ),
                ),
                ...manuallyRemovedStudents.map((roll) => _buildStudentCard(roll, 'Marked for removal', Colors.purple)),
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
          child: Text(roll.toString(), style: const TextStyle(color: Colors.white)),
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
      return const Center(child: Text("No location/MAC data available"));
    }

    final sortedRolls = allLocationData.keys.toList()..sort();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Student ID", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("MAC Address", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Latitude", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Longitude", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Distance", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: sortedRolls.map((roll) {
            final locData = allLocationData[roll];
            final distance = detectionResult?.locationStats['allDistances'][roll] ?? 0.0;
            final isDuplicateMAC = detectionResult?.duplicateMacRolls.contains(roll) ?? false;
            final isOutlier = detectionResult?.outlierLocationRolls.contains(roll) ?? false;

            String status = "✅ OK";
            Color statusColor = Colors.green;

            if (isDuplicateMAC) {
              status = "🚨 Duplicate MAC";
              statusColor = Colors.red;
            } else if (isOutlier) {
              status = "⚠️ Outlier Location";
              statusColor = Colors.orange;
            }

            return DataRow(
              cells: [
                DataCell(Text(roll.toString())),
                DataCell(Container(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    locData?['macAddress'] ?? 'UNKNOWN',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                )),
                DataCell(Text((locData?['latitude'] ?? 0).toStringAsFixed(6))),
                DataCell(Text((locData?['longitude'] ?? 0).toStringAsFixed(6))),
                DataCell(Text('${distance.toStringAsFixed(2)}m')),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

}
