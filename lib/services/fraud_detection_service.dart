import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FraudDetectionService {
  static const _deviceIdKey = 'device_id';

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final deviceInfo = DeviceInfoPlugin();
    String id = '';
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        // Prefer the system-provided id field when available (AndroidDeviceInfo.id)
        final systemId = info.id;
        if (systemId.isNotEmpty) {
          id = systemId;
        }

        // If system id is not available, fall back to a hashed fingerprint
        if (id.isEmpty) {
          final parts = <String>[
            info.brand,
            info.model,
            info.manufacturer,
            info.device,
            info.product,
            info.hardware,
            info.display,
            info.board,
            info.host,
            info.type,
            info.isPhysicalDevice.toString(),
          ];
          final candidate = parts.where((p) => p.isNotEmpty).join('|');
          if (candidate.isNotEmpty) {
            id = _sha256(candidate);
          }
        }
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        id = info.identifierForVendor ?? '';
      }
    } catch (_) {}

    if (id.isEmpty) {
      id = _randomUuid();
    }
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String _randomUuid() {
    final rand = math.Random.secure();
    String hex(int length) => List.generate(
      length,
      (_) => rand.nextInt(16),
    ).map((v) => v.toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}';
  }

  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return null;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (_) {
      return null;
    }
  }

  /// Basic mean-based outlier detection (kept for fallback)
  static CheatDetectionResult detectCheating(List<AttendanceRecord> records) {
    if (records.isEmpty) {
      return CheatDetectionResult(
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
    }
    final meanLat =
        records.map((r) => r.latitude).reduce((a, b) => a + b) / records.length;
    final meanLon =
        records.map((r) => r.longitude).reduce((a, b) => a + b) /
        records.length;
    return detectCheatingWithCenter(
      records,
      meanLat,
      meanLon,
      radiusMeters: 20,
    );
  }

  /// Advanced detection using CR-defined center radius and duplicate device IDs
  static CheatDetectionResult detectCheatingWithCenter(
    List<AttendanceRecord> records,
    double centerLat,
    double centerLon, {
    double radiusMeters = 20,
  }) {
    // Distances to CR center
    final Map<int, double> distances = {};
    for (final r in records) {
      distances[r.roll] = _haversineDistance(
        centerLat,
        centerLon,
        r.latitude,
        r.longitude,
      );
    }

    // Outliers: outside radiusMeters
    final outliers = <int>[];
    distances.forEach((roll, d) {
      if (d > radiusMeters) outliers.add(roll);
    });

    // Duplicate device IDs
    final deviceMap = <String, List<int>>{};
    for (final r in records) {
      if (r.deviceId.isNotEmpty) {
        deviceMap.putIfAbsent(r.deviceId, () => []).add(r.roll);
      }
    }
    final duplicateDeviceRolls = <int>[];
    for (final rolls in deviceMap.values) {
      if (rolls.length > 1) duplicateDeviceRolls.addAll(rolls);
    }

    return CheatDetectionResult(
      // reuse duplicateMacRolls field to carry duplicate device ID rolls
      duplicateMacRolls: duplicateDeviceRolls,
      outlierLocationRolls: outliers,
      locationStats: {
        'centerLatitude': centerLat,
        'centerLongitude': centerLon,
        'meanDistance': _mean(distances.values),
        'stdDeviation': _stdDev(distances.values),
        'allDistances': distances,
      },
    );
  }

  static double _mean(Iterable<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _stdDev(Iterable<double> values) {
    if (values.isEmpty) return 0.0;
    final m = _mean(values);
    double variance = 0.0;
    for (final v in values) {
      variance += math.pow(v - m, 2).toDouble();
    }
    variance /= values.length;
    return math.sqrt(variance);
  }

  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371000;
    final double dLat = _toRad(lat2 - lat1);
    final double dLon = _toRad(lon2 - lon1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double degree) => degree * math.pi / 180;
}

class AttendanceRecord {
  final int roll;
  final double latitude;
  final double longitude;
  final String deviceId;
  final DateTime timestamp;
  AttendanceRecord({
    required this.roll,
    required this.latitude,
    required this.longitude,
    required this.deviceId,
    required this.timestamp,
  });
}

class CheatDetectionResult {
  final List<int> duplicateMacRolls; // holds duplicate device IDs
  final List<int> outlierLocationRolls;
  final Map<String, dynamic> locationStats;
  CheatDetectionResult({
    required this.duplicateMacRolls,
    required this.outlierLocationRolls,
    required this.locationStats,
  });
}
