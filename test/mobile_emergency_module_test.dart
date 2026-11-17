import 'dart:async';
import 'dart:convert';

import 'package:emergency_help/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GeolocatorPlatform _originalGeolocator = GeolocatorPlatform.instance;
final geo.GeocodingPlatform? _originalGeocoding = geo.GeocodingPlatform.instance;

const MethodChannel _urlLauncherChannel =
    MethodChannel('plugins.flutter.io/url_launcher');

Position _testPosition(double latitude, double longitude) => Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2026, 11, 17, 10),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.always;
  int streamRequestCount = 0;

  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streamRequestCount++;
    return _controller.stream;
  }

  void emit(Position position) => _controller.add(position);
  void emitError(Object error) => _controller.addError(error);
  Future<void> close() => _controller.close();
}

class FakeGeocodingPlatform extends geo.GeocodingPlatform {
  int calls = 0;
  bool fail = false;
  Duration delay = Duration.zero;

  @override
  Future<List<geo.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (fail) throw Exception('geocoder unavailable');
    return [
      geo.Placemark.fromMap(<String, dynamic>{
        'locality': 'Cairo',
        'administrativeArea': 'Cairo Governorate',
        'country': 'Egypt',
      }),
    ];
  }
}

List<MethodCall> mockUrlLauncher({
  bool canLaunch = true,
  bool throwOnCanLaunch = false,
}) {
  final calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_urlLauncherChannel, (call) async {
    calls.add(call);
    if (call.method == 'canLaunch') {
      if (throwOnCanLaunch) {
        throw PlatformException(code: 'launcher-test-failure');
      }
      return canLaunch;
    }
    if (call.method == 'launch') return true;
    return null;
  });
  return calls;
}

class FailingFirebaseCoreApi implements TestFirebaseCoreHostApi {
  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async {
    throw PlatformException(code: 'firebase-test-failure');
  }

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    throw PlatformException(code: 'firebase-test-failure');
  }

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async {
    throw PlatformException(code: 'firebase-test-failure');
  }
}

Future<void> _deleteFirebaseApps() async {
  for (final app in Firebase.apps.toList()) {
    await app.delete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    clearEmergencyStateForTesting();
    geocodeTimeout = const Duration(seconds: 5);
    addressCacheTtl = const Duration(minutes: 10);
    NotificationService.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    LiveLocationService.clearCustomLocation();
    LiveLocationService.lastKnownPosition = null;
    LiveLocationService.lastSource = LocationSource.fallback;
    LiveLocationService.lastAccuracyMeters = null;
    LiveLocationService.lastUpdateTime = null;
    LiveLocationService.lastAddressInfo = null;
    LiveLocationService.stopTracking();
  });

  tearDown(() {
    GeolocatorPlatform.instance = _originalGeolocator;
    if (_originalGeocoding != null) {
      geo.GeocodingPlatform.instance = _originalGeocoding;
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncherChannel, null);
  });

  group('formatAddressLabel', () {
    test('orders neighborhood -> street -> city -> governorate -> country', () {
      expect(
        formatAddressLabel(
          subLocality: 'Maadi',
          thoroughfare: 'Corniche',
          locality: 'Cairo',
          administrativeArea: 'Cairo Governorate',
          country: 'Egypt',
        ),
        'Maadi, Corniche, Cairo, Cairo Governorate, Egypt',
      );
    });

    test('skips blanks and duplicates without inventing data', () {
      expect(
        formatAddressLabel(
          subLocality: '  Helwan  ',
          thoroughfare: '',
          locality: 'Helwan',
          country: null,
        ),
        'Helwan',
      );
      expect(formatAddressLabel(), '');
    });
  });

  group('AddressInfo', () {
    test('unverified address never presents a fabricated address', () {
      const info = AddressInfo();
      expect(info.hasAddress, isFalse);
      expect(info.displayFor(const LatLng(29.8, 31.3)),
          contains('Address unavailable'));
    });

    test('verified address is shown as-is', () {
      const info = AddressInfo(label: 'Maadi, Cairo, Egypt', verified: true);
      expect(info.hasAddress, isTrue);
      expect(info.displayFor(const LatLng(29.9, 31.3)), 'Maadi, Cairo, Egypt');
    });
  });

  group('getAreaName (coarse demo metadata only)', () {
    test('maps known Egypt boxes', () {
      expect(getAreaName(const LatLng(29.86, 31.30)), 'Helwan, Cairo');
      expect(getAreaName(const LatLng(29.96, 31.28)), 'Maadi, Cairo');
      expect(getAreaName(const LatLng(31.20, 29.95)), 'Alexandria');
      expect(getAreaName(const LatLng(27.25, 33.85)), 'Hurghada');
    });

    test('outside all boxes returns coordinates, not a fake city', () {
      expect(getAreaName(const LatLng(0, 0)),
          'Current Location (0.000, 0.000)');
    });

    test('manual selection label only applies near the selected point', () {
      LiveLocationService.setCustomLocation(const LatLng(30.0444, 31.2357),
          label: 'Tahrir Square (manual)');
      expect(getAreaName(const LatLng(30.045, 31.236)), 'Tahrir Square (manual)');
      expect(getAreaName(const LatLng(31.2, 29.9)), 'Alexandria');
    });
  });

  group('LocationResult source labeling', () {
    test('only live GPS and last known count as real', () {
      const pos = LatLng(30, 31);
      final now = DateTime.now();
      expect(LocationResult(position: pos, source: LocationSource.liveGps, timestamp: now).sourceLabel, 'LIVE GPS');
      expect(LocationResult(position: pos, source: LocationSource.lastKnown, timestamp: now).isReal, isTrue);
      expect(LocationResult(position: pos, source: LocationSource.cached, timestamp: now).sourceLabel, 'CACHED');
      expect(LocationResult(position: pos, source: LocationSource.simulated, timestamp: now).sourceLabel, 'SIMULATED');
      expect(LocationResult(position: pos, source: LocationSource.manualSelection, timestamp: now).isReal, isFalse);
      expect(LocationResult(position: pos, source: LocationSource.fallback, timestamp: now).sourceLabel, 'FALLBACK (not real)');
    });
  });

  group('LiveLocationService permission messages', () {
    test('covers every geolocator permission state in this SDK version', () {
      expect(LiveLocationService.permissionMessage(LocationPermission.denied),
          contains('denied'));
      expect(
          LiveLocationService.permissionMessage(LocationPermission.deniedForever),
          contains('permanently denied'));
      expect(
          LiveLocationService.permissionMessage(LocationPermission.unableToDetermine),
          contains('Unable'));
      expect(LiveLocationService.permissionMessage(LocationPermission.always),
          'Location permission granted');
    });
  });

  group('GPS provenance and tracking lifecycle', () {
    test('clearing a manual location removes every stale GPS-derived value', () {
      LiveLocationService.setCustomLocation(
        const LatLng(30.0444, 31.2357),
        label: 'Manual point',
      );
      expect(LiveLocationService.customSelectedPosition, isNotNull);
      expect(LiveLocationService.lastSource, LocationSource.manualSelection);

      LiveLocationService.clearCustomLocation();

      expect(LiveLocationService.customSelectedPosition, isNull);
      expect(LiveLocationService.customSelectedLabel, isNull);
      expect(LiveLocationService.lastKnownPosition, isNull);
      expect(LiveLocationService.lastSource, LocationSource.fallback);
      expect(LiveLocationService.lastAccuracyMeters, isNull);
      expect(LiveLocationService.lastUpdateTime, isNull);
      expect(LiveLocationService.lastAddressInfo, isNull);
    });

    test('stream errors cancel the subscription and retry preserves client ids',
        () async {
      final fake = FakeGeolocatorPlatform();
      GeolocatorPlatform.instance = fake;
      final updatesA = <LatLng>[];
      final updatesB = <LatLng>[];

      final idA = LiveLocationService.startTracking(onUpdate: updatesA.add);
      final idB = LiveLocationService.startTracking(onUpdate: updatesB.add);
      await Future<void>.delayed(Duration.zero);
      expect(fake.streamRequestCount, 1);
      expect(LiveLocationService.streamHealthy, isTrue);

      fake.emit(_testPosition(30.01, 31.01));
      await Future<void>.delayed(Duration.zero);
      expect(updatesA, hasLength(1));
      expect(updatesB, hasLength(1));
      expect(LiveLocationService.lastSource, LocationSource.liveGps);

      fake.emitError('stream broken');
      await Future<void>.delayed(Duration.zero);
      expect(LiveLocationService.lastStreamError, 'stream broken');
      expect(LiveLocationService.streamHealthy, isFalse);

      fake.permission = LocationPermission.denied;
      await LiveLocationService.retryStream();
      expect(LiveLocationService.lastStreamError,
          'Location permission denied');
      expect(LiveLocationService.streamHealthy, isFalse);

      fake.permission = LocationPermission.always;
      await LiveLocationService.retryStream();
      expect(LiveLocationService.lastStreamError, isNull);
      expect(LiveLocationService.streamHealthy, isTrue);

      fake.emit(_testPosition(30.02, 31.02));
      await Future<void>.delayed(Duration.zero);
      expect(updatesA, hasLength(2));
      expect(updatesB, hasLength(2));

      LiveLocationService.stopTracking(idA);
      LiveLocationService.stopTracking(idB);
      await fake.close();
    });

    test('manual selection suppresses the live stream while active', () async {
      final fake = FakeGeolocatorPlatform();
      GeolocatorPlatform.instance = fake;
      final updates = <LatLng>[];

      LiveLocationService.startTracking(onUpdate: updates.add);
      await Future<void>.delayed(Duration.zero);
      expect(fake.streamRequestCount, 1);

      LiveLocationService.setCustomLocation(const LatLng(30.1, 31.1));
      await Future<void>.delayed(Duration.zero);
      expect(fake.streamRequestCount, 1);
      expect(updates.single.latitude, 30.1);
      expect(LiveLocationService.lastSource, LocationSource.manualSelection);

      fake.emit(_testPosition(30.9, 31.9));
      await Future<void>.delayed(Duration.zero);
      expect(updates, hasLength(1));

      LiveLocationService.clearCustomLocation();
      await Future<void>.delayed(Duration.zero);
      expect(LiveLocationService.lastKnownPosition, isNull);
      expect(updates, hasLength(1));
      await fake.close();
    });
  });

  group('Reverse geocoding cache', () {
    test('failures are not cached and a later success is used', () async {
      final fake = FakeGeocodingPlatform()..fail = true;
      geo.GeocodingPlatform.instance = fake;
      const loc = LatLng(30.0444, 31.2357);

      final failed = await lookupAddress(loc);
      expect(failed.hasAddress, isFalse);
      expect(fake.calls, 1);

      fake.fail = false;
      final success = await lookupAddress(loc);
      expect(success.hasAddress, isTrue);
      expect(fake.calls, 2);
    });

    test('successful results expire and are refreshed', () async {
      final fake = FakeGeocodingPlatform();
      geo.GeocodingPlatform.instance = fake;
      addressCacheTtl = Duration.zero;
      const loc = LatLng(30.0444, 31.2357);

      await lookupAddress(loc);
      await lookupAddress(loc);

      expect(fake.calls, 2);
    });

    test('a slow geocoder times out instead of hanging the UI', () async {
      final fake = FakeGeocodingPlatform()
        ..delay = const Duration(milliseconds: 40);
      geo.GeocodingPlatform.instance = fake;
      geocodeTimeout = const Duration(milliseconds: 2);

      final info = await lookupAddress(const LatLng(30.0444, 31.2357));

      expect(info.hasAddress, isFalse);
      expect(fake.calls, 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });

  group('Tile error/recovery state', () {
    test('a recovered tile layer clears its previous failure state', () {
      final state = TileLoadState();
      expect(state.failed, isFalse);
      state.markFailed();
      expect(state.failed, isTrue);
      state.markRecovered();
      expect(state.failed, isFalse);
    });
  });

  group('SMS and dialer launcher behavior', () {
    test('SMS URI keeps recipient 123 and the encoded location body', () async {
      final calls = mockUrlLauncher(canLaunch: true);

      final launched =
          await sendEmergencySmsForTesting(const LatLng(30.0444, 31.2357));

      expect(launched, isTrue);
      final canCall = calls.firstWhere((c) => c.method == 'canLaunch');
      final launchCall = calls.firstWhere((c) => c.method == 'launch');
      final url = canCall.arguments['url'] as String;
      expect(url, startsWith('sms:123?body='));
      expect(launchCall.arguments['url'], url);
      final body = Uri.decodeComponent(url.split('?body=').last);
      expect(body, contains('EMERGENCY SOS'));
      expect(body, contains('30.0444,31.2357'));
    });

    test('unavailable or throwing launcher returns false without throwing',
        () async {
      mockUrlLauncher(canLaunch: false);
      expect(await sendEmergencySmsForTesting(const LatLng(30, 31)), isFalse);
      expect(await openDialerForTesting('123'), isFalse);

      mockUrlLauncher(throwOnCanLaunch: true);
      expect(await sendEmergencySmsForTesting(const LatLng(30, 31)), isFalse);
      expect(await openDialerForTesting('123'), isFalse);
    });
  });

  group('EmergencySession persistence', () {
    test('JSON roundtrip preserves source, accuracy, address and timeline', () {
      final session = EmergencySession(
        id: 's1',
        location: const LatLng(29.9, 31.3),
        startTime: DateTime.utc(2026, 11, 17, 10, 30),
        source: LocationSource.liveGps,
        accuracyMeters: 4.8,
        addressLabel: 'Maadi, Cairo, Egypt',
        status: EmergencyStatus.resolved,
      );
      session.addEvent('SOS pressed');

      final decoded = EmergencySession.fromJson(
          jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>);

      expect(decoded.id, 's1');
      expect(decoded.location.latitude, closeTo(29.9, 1e-9));
      expect(decoded.source, LocationSource.liveGps);
      expect(decoded.sourceLabel, 'LIVE GPS');
      expect(decoded.accuracyMeters, closeTo(4.8, 1e-9));
      expect(decoded.addressLabel, 'Maadi, Cairo, Egypt');
      expect(decoded.timeline, hasLength(1));
      expect(decoded.timeline.single, contains('SOS pressed'));
      expect(decoded.status, EmergencyStatus.resolved);
    });

    test('legacy JSON without new fields still loads safely', () {
      final decoded = EmergencySession.fromJson({
        'id': 'old',
        'lat': 30.0,
        'lng': 31.0,
        'startTime': '2025-01-01T00:00:00.000Z',
        'status': 'resolved',
        'responderName': 'Old responder',
      });
      expect(decoded.source, LocationSource.lastKnown);
      expect(decoded.accuracyMeters, isNull);
      expect(decoded.addressLabel, isNull);
      expect(decoded.timeline, isEmpty);
      expect(decoded.status, EmergencyStatus.resolved);
      expect(decoded.assignedResponder, isNull);
    });

    test('responder details survive a JSON roundtrip', () {
      final responder = Responder(
        id: 'responder-1',
        name: 'Test Paramedic',
        type: ResponderType.paramedic,
        specialty: 'Emergency Care',
        location: const LatLng(30.05, 31.24),
        address: 'Cairo',
        phone: '123',
      );
      final session = EmergencySession(
        id: 's-responder',
        location: const LatLng(30.04, 31.23),
        startTime: DateTime.utc(2026, 11, 17),
        status: EmergencyStatus.resolved,
        assignedResponder: assignedResponderForTesting(responder, 1.2),
      );

      final restored = EmergencySession.fromJson(
        jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
      );

      expect(restored.assignedResponder, isNotNull);
      expect(restored.assignedResponder!.responder.id, 'responder-1');
      expect(restored.assignedResponder!.responder.name, 'Test Paramedic');
      expect(restored.assignedResponder!.responder.phone, '123');
      expect(restored.assignedResponder!.responder.type,
          ResponderType.paramedic);
      expect(restored.assignedResponder!.distKm, closeTo(1.2, 1e-9));
    });

    test('malformed records are skipped and orphaned active sessions resolve',
        () async {
      final responder = Responder(
        id: 'responder-2',
        name: 'Saved Responder',
        type: ResponderType.doctor,
        specialty: 'Emergency Medicine',
        location: const LatLng(30.05, 31.24),
        address: 'Cairo',
        phone: '137',
      );
      final active = EmergencySession(
        id: 'active-1',
        location: const LatLng(30.04, 31.23),
        startTime: DateTime.utc(2026, 11, 17),
        status: EmergencyStatus.active,
        assignedResponder: assignedResponderForTesting(responder, 0.8),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'emergency_history': <String>[
          jsonEncode(active.toJson()),
          '{ this is not json',
        ],
        'emergency_active_session_id': 'active-1',
      });

      await loadPersistedHistoryForTesting();

      final sessions = emergencySessionsForTesting;
      expect(sessions, hasLength(1));
      expect(sessions.single.id, 'active-1');
      expect(sessions.single.status, EmergencyStatus.resolved);
      expect(sessions.single.timeline.last, contains('auto-resolved'));
      expect(sessions.single.timeline.last,
          contains('live tracking does not continue'));
      expect(sessions.single.assignedResponder?.responder.phone, '137');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('emergency_active_session_id'), isNull);
    });

    test('active-session identity is written and cleared on disk', () async {
      final session = EmergencySession(
        id: 'active-2',
        location: const LatLng(30.04, 31.23),
        startTime: DateTime.utc(2026, 11, 17),
        status: EmergencyStatus.active,
      );
      setActiveSessionForTesting(session);
      await persistHistoryForTesting();

      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('emergency_active_session_id'), 'active-2');

      setActiveSessionForTesting(null);
      await persistHistoryForTesting();

      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('emergency_active_session_id'), isNull);
    });
  });

  group('Firebase and notifications', () {
    test('initialization failure returns false and no token is available',
        () async {
      TestFirebaseCoreHostApi.setUp(FailingFirebaseCoreApi());
      await _deleteFirebaseApps();

      final ready = await initializeFirebaseSafely(force: true);

      expect(ready, isFalse);
      expect(await NotificationService.getToken(), isNull);
      expect(NotificationService.permissionStatus, isNull);
    });

    test('initialization success returns true with mocked core', () async {
      TestFirebaseCoreHostApi.setUp(MockFirebaseApp());
      await _deleteFirebaseApps();

      final ready = await initializeFirebaseSafely(force: true);

      expect(ready, isTrue);
      // No backend is configured, so no token is sent or registered anywhere.
      expect(NotificationService.lastNotificationPayload, isNull);
    });

    test('payloads are recorded locally without delivery or dispatch claims',
        () async {
      NotificationService.handlePayloadForTesting(
        const RemoteMessage(
          messageId: 'msg-1',
          data: <String, dynamic>{'kind': 'test'},
          notification: RemoteNotification(title: 'Local title', body: 'Body'),
        ),
      );

      final payload = NotificationService.lastNotificationPayload;
      expect(payload, isNotNull);
      expect(payload!['messageId'], 'msg-1');
      expect(payload['source'], 'test');
      expect((payload['data'] as Map<String, dynamic>)['kind'], 'test');
    });
  });

  group('Frozen UI preservation', () {
    testWidgets('app shell and onboarding screen keep the baseline structure',
        (tester) async {
      await tester.pumpWidget(const EmergencyHelpApp());

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.debugShowCheckedModeBanner, isFalse);
      expect(app.title, 'Nabd');
      expect(find.byType(GetStartedScreen), findsOneWidget);

      final stack = tester.widget<Stack>(find.byType(Stack).first);
      expect(stack.fit, StackFit.expand);
      final image = tester.widget<Image>(find.byType(Image).first);
      expect(image.fit, BoxFit.cover);
    });

    testWidgets('bottom navigation labels and order remain unchanged',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      final bar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(
        bar.items.map((item) => item.label).toList(),
        <String>['Home', 'Map', 'History', 'Profile'],
      );
      expect(bar.currentIndex, 0);
    });
  });
}
