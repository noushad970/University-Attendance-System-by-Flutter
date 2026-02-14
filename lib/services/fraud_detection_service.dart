import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:math';

class AttendanceRecord {
  final int roll;
  final double latitude;
  final double longitude;
  final String macAddress;
  final DateTime timestamp;

  AttendanceRecord({
    required this.roll,
    required this.latitude,
    required this.longitude,
    required this.macAddress,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'roll': roll,
      'latitude': latitude,
      'longitude': longitude,
      'macAddress': macAddress,
      'timestamp': timestamp,
    };
  }
}

class CheatDetectionResult {
  final List<int> duplicateMacRolls; // Students with same MAC
  final List<int> outlierLocationRolls; // Students from suspicious locations
  final Map<String, dynamic> locationStats;

  CheatDetectionResult({
    required this.duplicateMacRolls,
    required this.outlierLocationRolls,
    required this.locationStats,
  });
}

class FraudDetectionService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Get device MAC address
  static Future<String> getDeviceMacAddress() async {
    try {
      if (identical(0, -0.0)) {
        // iOS
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'UNKNOWN_MAC';
      } else {
        // Android
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id ?? 'UNKNOWN_MAC';
      }
    } catch (e) {
      return 'ERROR_MAC_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Request location permissions and get current location
  static Future<Position?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Create attendance record with location and MAC
  static Future<AttendanceRecord?> createAttendanceRecord(int roll) async {
    try {
      final position = await getCurrentLocation();
      if (position == null) return null;

      final macAddress = await getDeviceMacAddress();

      return AttendanceRecord(
        roll: roll,
        latitude: position.latitude,
        longitude: position.longitude,
        macAddress: macAddress,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Error creating attendance record: $e');
      return null;
    }
  }

  /// Detect cheating - duplicate MAC addresses
  static List<int> detectDuplicateMacs(List<AttendanceRecord> records) {
    final macMap = <String, List<int>>{};

    for (final record in records) {
      if (!macMap.containsKey(record.macAddress)) {
        macMap[record.macAddress] = [];
      }
      macMap[record.macAddress]!.add(record.roll);
    }

    final cheaters = <int>[];
    for (final rolls in macMap.values) {
      if (rolls.length > 1) {
        cheaters.addAll(rolls);
      }
    }

    return cheaters;
  }

  /// Calculate distance between two coordinates (in meters)
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Earth radius in meters

    final double dLat = _toRad(lat2 - lat1);
    final double dLon = _toRad(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double degree) {
    return degree * pi / 180;
  }

  /// Detect outlier locations
  static CheatDetectionResult detectCheating(List<AttendanceRecord> records) {
    // Detect duplicate MACs
    final duplicateMacs = detectDuplicateMacs(records);

    // Calculate center location (average of all coordinates)
    double centerLat = 0, centerLon = 0;
    for (final record in records) {
      centerLat += record.latitude;
      centerLon += record.longitude;
    }
    centerLat /= records.length;
    centerLon /= records.length;

    // Calculate distances from center
    final distances = <int, double>{};
    for (final record in records) {
      final distance = calculateDistance(
        centerLat,
        centerLon,
        record.latitude,
        record.longitude,
      );
      distances[record.roll] = distance;
    }

    // Calculate standard deviation to find outliers
    double meanDistance = 0;
    for (final distance in distances.values) {
      meanDistance += distance;
    }
    meanDistance /= distances.length;

    double variance = 0;
    for (final distance in distances.values) {
      variance += pow(distance - meanDistance, 2).toDouble();
    }
    variance /= distances.length;
    final stdDev = sqrt(variance);

    // Outliers are more than 2 standard deviations from mean
    final outliers = <int>[];
    for (final entry in distances.entries) {
      if ((entry.value - meanDistance).abs() > 2 * stdDev && stdDev > 0) {
        outliers.add(entry.key);
      }
    }

    return CheatDetectionResult(
      duplicateMacRolls: duplicateMacs,
      outlierLocationRolls: outliers,
      locationStats: {
        'centerLatitude': centerLat,
        'centerLongitude': centerLon,
        'meanDistance': meanDistance,
        'stdDeviation': stdDev,
        'allDistances': distances,
      },
    );
  }
}
