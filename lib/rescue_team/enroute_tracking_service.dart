import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

// Singleton service that streams the current device's location directly to
// Firestore for as long as the member is "enroute" on a task. Tracking
// continues as long as the app process is alive (foreground OR background) —
// geolocator's built-in Android foreground-service notification is used so
// the OS doesn't kill the location stream when the app isn't on screen.
// If the app process is fully killed (swiped from recents), tracking will
// stop automatically — going beyond that would require a native background
// service, which is out of scope here.
//
// Location is written PER MEMBER (tasks/{taskId}.memberLocations.{uid}) —
// not a single shared field — because a task can have several members
// assigned to it at once, and each one's dot needs to move independently
// on the map.
class EnrouteTrackingService {
  EnrouteTrackingService._();
  static final EnrouteTrackingService instance = EnrouteTrackingService._();

  StreamSubscription<Position>? _subscription;
  String? _activeTaskId;

  bool get isTracking => _subscription != null;
  String? get activeTaskId => _activeTaskId;

  Future<bool> _ensurePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // Background permission is a separate/second prompt on Android 10+
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return true;
  }

  Future<bool> startTracking(String taskId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    // If we're already tracking a different task, stop that one first
    if (_subscription != null && _activeTaskId != taskId) {
      await stopTracking();
    }
    if (_subscription != null && _activeTaskId == taskId) {
      return true; // this task is already being tracked
    }

    final hasPermission = await _ensurePermission();
    if (!hasPermission) return false;

    _activeTaskId = taskId;

    final androidSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25, // meters — balances battery use against update frequency
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationText: 'Sharing your location for a rescue task',
        notificationTitle: 'Rescue task in progress',
        enableWakeLock: true,
      ),
    );

    _subscription = Geolocator.getPositionStream(locationSettings: androidSettings)
        .listen((Position position) {
      FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
        'memberLocations.$uid': {
          'lat': position.latitude,
          'lng': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    }, onError: (_) {
      // If the stream errors out (e.g. permission revoked mid-way), stop quietly
      stopTracking();
    });

    return true;
  }

  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
    _activeTaskId = null;
  }

  // Called from ViewTaskScreen's stream listener as a safety net — if the
  // task's status moves away from "enroute" (e.g. resolved from somewhere
  // else) while we're still tracking it, stop tracking immediately.
  void stopIfTaskNoLongerEnroute(String taskId, String currentStatus) {
    if (_activeTaskId == taskId && currentStatus != 'enroute') {
      stopTracking();
    }
  }

  // Called when a task is marked resolved — removes every assigned member's
  // last-known location from the task document so old dots don't linger on
  // the map for a task that's already done.
  static Future<void> clearAllMemberLocations(String taskId) async {
    await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
      'memberLocations': FieldValue.delete(),
      // Also clear the old single-field name in case any older task
      // documents still carry it, so nothing stale is left behind.
      'liveLocation': FieldValue.delete(),
    });
  }
}