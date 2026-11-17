import 'dart:convert';

import 'package:emergency_help/main.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  setUp(() {
    LiveLocationService.clearCustomLocation();
    LiveLocationService.lastKnownPosition = null;
    LiveLocationService.lastSource = LocationSource.fallback;
    LiveLocationService.lastAccuracyMeters = null;
    LiveLocationService.lastUpdateTime = null;
    LiveLocationService.lastAddressInfo = null;
    LiveLocationService.stopTracking();
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
    });
  });
}
