import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

/// Location-only cheating detection.
///
/// All device-id / MAC-address based detection has been removed. Cheaters
/// are now identified purely by their distance from the class center
/// (or, when no center is provided, by being outliers from the mean of
/// the submitted positions).
class FraudDetectionService {
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

  /// Basic mean-based outlier detection (kept for fallback when no CR
  /// center is known — uses the centroid of the submitted positions).
  static CheatDetectionResult detectCheating(List<AttendanceRecord> records) {
    if (records.isEmpty) {
      return CheatDetectionResult(
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

  /// Location-only detection using a CR-defined center and radius.
  /// Any student whose position is farther than [radiusMeters] from the
  /// center is flagged as a possible cheater.
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

    return CheatDetectionResult(
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
  AttendanceRecord({
    required this.roll,
    required this.latitude,
    required this.longitude,
  });
}

class CheatDetectionResult {
  final List<int> outlierLocationRolls;
  final Map<String, dynamic> locationStats;
  CheatDetectionResult({
    required this.outlierLocationRolls,
    required this.locationStats,
  });
}
