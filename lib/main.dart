import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as ll;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geocoding/geocoding.dart' as geo;

ll.LatLng toLl(LatLng p) => ll.LatLng(p.latitude, p.longitude);
LatLng toGMap(ll.LatLng p) => LatLng(p.latitude, p.longitude);

// ── Shared OSM tile configuration (no visual changes) ─────────
// Tracks tile failures internally so every map can reset its error state when
// tiles load again. No attribution widget or banner is added by this helper.
class TileLoadState {
  bool _failed = false;
  bool get failed => _failed;
  void markFailed() => _failed = true;
  void markRecovered() => _failed = false;
}

class _SuccessNotifyingImageProvider
    extends ImageProvider<_SuccessNotifyingImageProvider> {
  const _SuccessNotifyingImageProvider(this._delegate, this._onSuccess)
      : _delegateKey = null;

  const _SuccessNotifyingImageProvider._fromKey(
    this._delegateKey,
    this._onSuccess,
  ) : _delegate = null;

  // Kept dynamic because the underlying flutter_map provider has its own
  // generic key type.
  final dynamic _delegate;
  final Object? _delegateKey;
  final VoidCallback _onSuccess;

  @override
  ImageStream createStream(ImageConfiguration configuration) {
    final stream = ImageStream();
    stream.addListener(ImageStreamListener(
      (_, __) => scheduleMicrotask(_onSuccess),
      onError: (Object error, StackTrace? stackTrace) {},
    ));
    return stream;
  }

  @override
  Future<_SuccessNotifyingImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) async {
    final delegate = _delegate;
    if (delegate == null) return this;
    final delegateKey = await delegate.obtainKey(configuration) as Object;
    return _SuccessNotifyingImageProvider._fromKey(
      delegateKey,
      _onSuccess,
    );
  }

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    _SuccessNotifyingImageProvider key,
    ImageErrorListener handleError,
  ) {
    final delegate = _delegate;
    final delegateKey = key._delegateKey;
    if (delegate == null || delegateKey == null) return;
    // Delegate to the original provider so image caching and tile decoding
    // remain identical to the frozen UI; only the success listener is added.
    (delegate as dynamic).resolveStreamForKey(
      configuration,
      stream,
      delegateKey,
      handleError,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _SuccessNotifyingImageProvider &&
      other._delegateKey == _delegateKey;

  @override
  int get hashCode => _delegateKey.hashCode;
}

class _NotifyingNetworkTileProvider extends fmap.NetworkTileProvider {
  _NotifyingNetworkTileProvider({required this.onTileLoaded});

  final VoidCallback onTileLoaded;

  @override
  ImageProvider getImage(
    fmap.TileCoordinates coordinates,
    fmap.TileLayer options,
  ) {
    return _SuccessNotifyingImageProvider(
      super.getImage(coordinates, options),
      onTileLoaded,
    );
  }

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    fmap.TileCoordinates coordinates,
    fmap.TileLayer options,
    Future<void> cancelLoading,
  ) {
    return _SuccessNotifyingImageProvider(
      super.getImageWithCancelLoadingSupport(
        coordinates,
        options,
        cancelLoading,
      ),
      onTileLoaded,
    );
  }
}

fmap.TileLayer _osmTileLayer({
  required VoidCallback onTileError,
  required VoidCallback onTileLoaded,
}) {
  return fmap.TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.example.emergency_help',
    evictErrorTileStrategy: fmap.EvictErrorTileStrategy.notVisibleRespectMargin,
    errorTileCallback: (_, __, ___) => onTileError(),
    tileProvider: _NotifyingNetworkTileProvider(onTileLoaded: onTileLoaded),
  );
}

// ============================================================
// RESPONDER DATA MODEL  (Static – ready to swap with DB later)
// ============================================================

enum ResponderType { doctor, nurse, paramedic, volunteer }

Map<String, dynamic> _stringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry<String, dynamic>(k.toString(), v));
  }
  return <String, dynamic>{};
}

double? _finiteDouble(Object? value) {
  if (value is num) {
    final d = value.toDouble();
    return d.isFinite ? d : null;
  }
  if (value is String) return double.tryParse(value);
  return null;
}

class Responder {
  final String id;
  final String name;
  final ResponderType type;
  final String specialty;   // e.g. 'General Physician'
  final LatLng location;
  final String address;
  final String phone;
  final bool available;

  const Responder({
    required this.id,
    required this.name,
    required this.type,
    required this.specialty,
    required this.location,
    required this.address,
    required this.phone,
    this.available = true,
  });

  IconData get icon {
    switch (type) {
      case ResponderType.doctor:    return Icons.medical_services_rounded;
      case ResponderType.nurse:     return Icons.health_and_safety_rounded;
      case ResponderType.paramedic: return Icons.emergency_rounded;
      case ResponderType.volunteer: return Icons.volunteer_activism_rounded;
    }
  }

  String get typeLabel {
    switch (type) {
      case ResponderType.doctor:    return 'Doctor';
      case ResponderType.nurse:     return 'Nurse';
      case ResponderType.paramedic: return 'Paramedic';
      case ResponderType.volunteer: return 'First-Aid Volunteer';
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.name,
        'specialty': specialty,
        'lat': location.latitude,
        'lng': location.longitude,
        'address': address,
        'phone': phone,
        'available': available,
      };

  /// Restores only data that was actually saved. Missing/invalid fields are
  /// rejected instead of fabricating responder details.
  static Responder? fromJson(Object? raw) {
    final j = _stringKeyedMap(raw);
    final lat = _finiteDouble(j['lat']);
    final lng = _finiteDouble(j['lng']);
    final typeName = j['type'] as String?;
    if (lat == null || lng == null || typeName == null) return null;
    if (!ResponderType.values.any((e) => e.name == typeName)) return null;

    final id = j['id'] as String?;
    final name = j['name'] as String?;
    final phone = j['phone'] as String?;
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;

    return Responder(
      id: id,
      name: name,
      type: ResponderType.values.firstWhere((e) => e.name == typeName),
      specialty: (j['specialty'] as String?) ?? '',
      location: LatLng(lat, lng),
      address: (j['address'] as String?) ?? '',
      phone: phone ?? '',
      available: (j['available'] as bool?) ?? true,
    );
  }
}

// ── Extended static responder database (Cairo-wide, fallback for out-of-area) ──
const List<Responder> kResponders = [
  // ── Helwan Area ──
  Responder(
    id: 'r1',
    name: 'Dr. Ahmed Mostafa',
    type: ResponderType.doctor,
    specialty: 'General Physician',
    location: LatLng(29.8491, 31.3342),
    address: 'Al-Salam Clinic, Helwan, Cairo',
    phone: '01001234567',
  ),
  Responder(
    id: 'r2',
    name: 'Dr. Mona Khaled',
    type: ResponderType.doctor,
    specialty: 'Emergency Medicine',
    location: LatLng(29.8380, 31.2980),
    address: 'Helwan General Hospital, Cairo',
    phone: '01112345678',
  ),
  Responder(
    id: 'r3',
    name: 'Nurse Sara Youssef',
    type: ResponderType.nurse,
    specialty: 'Critical Care Nurse',
    location: LatLng(29.8450, 31.3150),
    address: 'Al-Maadi Medical Center, Cairo',
    phone: '01223456789',
  ),
  Responder(
    id: 'r4',
    name: 'Paramedic Hassan Ali',
    type: ResponderType.paramedic,
    specialty: 'Emergency Responder',
    location: LatLng(29.8530, 31.3050),
    address: 'Helwan Ambulance Station',
    phone: '01334567890',
  ),
  Responder(
    id: 'r5',
    name: 'Volunteer Omar Samir',
    type: ResponderType.volunteer,
    specialty: 'Certified First-Aid',
    location: LatLng(29.8360, 31.3200),
    address: 'Ain Helwan Area, Cairo',
    phone: '01445678901',
  ),
  Responder(
    id: 'r6',
    name: 'Dr. Laila Ibrahim',
    type: ResponderType.doctor,
    specialty: 'Cardiologist',
    location: LatLng(29.8600, 31.3100),
    address: 'Tibah Medical Tower, Helwan',
    phone: '01556789012',
  ),
  Responder(
    id: 'r7',
    name: 'Nurse Amira Fawzy',
    type: ResponderType.nurse,
    specialty: 'Pediatric Nurse',
    location: LatLng(29.8310, 31.3080),
    address: 'Children Clinic, Helwan',
    phone: '01667890123',
  ),
  // ── Maadi Area ──
  Responder(
    id: 'r8',
    name: 'Dr. Karim Nasser',
    type: ResponderType.doctor,
    specialty: 'Internal Medicine',
    location: LatLng(29.9602, 31.2569),
    address: 'Maadi Grand Mall Medical Center, Cairo',
    phone: '01778901234',
  ),
  Responder(
    id: 'r9',
    name: 'Paramedic Nada Salah',
    type: ResponderType.paramedic,
    specialty: 'Emergency Responder',
    location: LatLng(29.9530, 31.2510),
    address: 'Maadi Ambulance Post, Cairo',
    phone: '01889012345',
  ),
  Responder(
    id: 'r10',
    name: 'Dr. Hana Rashid',
    type: ResponderType.doctor,
    specialty: 'Pediatrician',
    location: LatLng(29.9650, 31.2600),
    address: 'Nile Badrawi Hospital, Maadi',
    phone: '01990123456',
  ),
  // ── Nasr City Area ──
  Responder(
    id: 'r11',
    name: 'Dr. Sherif Adel',
    type: ResponderType.doctor,
    specialty: 'Orthopedic Surgeon',
    location: LatLng(30.0626, 31.3281),
    address: 'Safa International Hospital, Nasr City',
    phone: '01101234567',
  ),
  Responder(
    id: 'r12',
    name: 'Nurse Rana Hossam',
    type: ResponderType.nurse,
    specialty: 'ER Nurse',
    location: LatLng(30.0580, 31.3320),
    address: 'Al-Ahly Club Medical Center, Nasr City',
    phone: '01202345678',
  ),
  // ── Downtown / Central Cairo ──
  Responder(
    id: 'r13',
    name: 'Dr. Yasmine Fouad',
    type: ResponderType.doctor,
    specialty: 'General & Emergency',
    location: LatLng(30.0444, 31.2357),
    address: 'Kasr Al-Ainy Hospital, Cairo',
    phone: '01303456789',
  ),
  Responder(
    id: 'r14',
    name: 'Paramedic Tamer Gamal',
    type: ResponderType.paramedic,
    specialty: 'Trauma Specialist',
    location: LatLng(30.0480, 31.2300),
    address: 'Cairo Ambulance Station, Downtown',
    phone: '01404567890',
  ),
  // ── Giza / Dokki Area ──
  Responder(
    id: 'r15',
    name: 'Dr. Basma Selim',
    type: ResponderType.doctor,
    specialty: 'Neurologist',
    location: LatLng(30.0195, 31.1990),
    address: 'Ain Shams Specialized Hospital, Giza',
    phone: '01505678901',
  ),
  Responder(
    id: 'r16',
    name: 'Volunteer Dina Wahba',
    type: ResponderType.volunteer,
    specialty: 'Certified First-Aid',
    location: LatLng(30.0350, 31.2100),
    address: 'Dokki Community Center, Giza',
    phone: '01606789012',
  ),
  // ── 6th October City ──
  Responder(
    id: 'r17',
    name: 'Dr. Walid Mansour',
    type: ResponderType.doctor,
    specialty: 'Cardiologist',
    location: LatLng(29.9660, 30.9202),
    address: 'October 6 International Hospital',
    phone: '01707890123',
  ),
  // ── New Cairo / Fifth Settlement ──
  Responder(
    id: 'r18',
    name: 'Dr. Nour Eldin',
    type: ResponderType.doctor,
    specialty: 'Emergency Medicine',
    location: LatLng(30.0131, 31.4244),
    address: 'As-Salam International Hospital, New Cairo',
    phone: '01808901234',
  ),
  Responder(
    id: 'r19',
    name: 'Nurse Marwa Farouk',
    type: ResponderType.nurse,
    specialty: 'ICU Nurse',
    location: LatLng(30.0220, 31.4310),
    address: 'Cleopatra Hospital, New Cairo',
    phone: '01909012345',
  ),
];

// ── Haversine distance in km ──────────────────────────────────
double _haversineKm(LatLng a, LatLng b) {
  const R = 6371.0;
  final dLat = _deg2rad(b.latitude  - a.latitude);
  final dLon = _deg2rad(b.longitude - a.longitude);
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(a.latitude)) *
          cos(_deg2rad(b.latitude)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  return R * 2 * atan2(sqrt(h), sqrt(1 - h));
}

double _deg2rad(double deg) => deg * pi / 180;

// ── Reverse geocoding (separate from GPS) ─────────────────────
// Provider: the `geocoding` package, which delegates to the platform geocoder
// (Android Geocoder). It may require network access; GPS does not.
//
// IMPORTANT: a bounding-box name from getAreaName() is coarse demo metadata.
// It must NEVER be presented as a verified reverse-geocoded address.
class AddressInfo {
  final String? label;
  final bool verified;

  const AddressInfo({this.label, this.verified = false});

  bool get hasAddress => verified && label != null && label!.isNotEmpty;

  String displayFor(LatLng loc) => hasAddress
      ? label!
      : 'Address unavailable (${loc.latitude.toStringAsFixed(4)}, '
          '${loc.longitude.toStringAsFixed(4)})';
}

/// Pure helper: most specific -> least specific, no duplicates, no invention.
String formatAddressLabel({
  String? subLocality,
  String? thoroughfare,
  String? locality,
  String? administrativeArea,
  String? country,
}) {
  final parts = <String>[];
  for (final value in [
    subLocality,
    thoroughfare,
    locality,
    administrativeArea,
    country,
  ]) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty || parts.contains(clean)) continue;
    parts.add(clean);
  }
  return parts.join(', ');
}

class _CachedAddress {
  final AddressInfo info;
  final DateTime expiresAt;

  const _CachedAddress(this.info, this.expiresAt);
}

final Map<String, _CachedAddress> _addressCache = {};

@visibleForTesting
Duration geocodeTimeout = const Duration(seconds: 5);

@visibleForTesting
Duration addressCacheTtl = const Duration(minutes: 10);

/// Real reverse geocoding. `verified` is false when the platform geocoder is
/// unavailable or returns no usable address. Failures are never cached, and
/// successful results expire so stale addresses are not reused indefinitely.
Future<AddressInfo> lookupAddress(LatLng loc) async {
  final key =
      '${loc.latitude.toStringAsFixed(5)},${loc.longitude.toStringAsFixed(5)}';
  final cached = _addressCache[key];
  final now = DateTime.now();
  if (cached != null && now.isBefore(cached.expiresAt)) return cached.info;
  if (cached != null) _addressCache.remove(key);

  try {
    final placemarks = await geo
        .placemarkFromCoordinates(loc.latitude, loc.longitude)
        .timeout(geocodeTimeout);
    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      final label = formatAddressLabel(
        subLocality: p.subLocality,
        thoroughfare: p.thoroughfare,
        locality: p.locality,
        administrativeArea: p.administrativeArea,
        country: p.country,
      );
      if (label.isNotEmpty) {
        final info = AddressInfo(label: label, verified: true);
        _addressCache[key] = _CachedAddress(
          info,
          now.add(addressCacheTtl),
        );
        return info;
      }
    }
  } catch (e) {
    debugPrint('Nabd: reverse geocoding unavailable: $e');
  }

  // Do not cache failures: a network outage must not permanently poison the
  // address for this coordinate.
  return const AddressInfo();
}

/// UI text helper. Never invents an address.
Future<String> describeAddress(LatLng loc) async =>
    (await lookupAddress(loc)).displayFor(loc);

/// Backwards-compatible wrapper. No hardcoded fallback is used as an address.
Future<String> reverseGeocodeAddress(LatLng loc) => describeAddress(loc);

String getAreaName(LatLng loc) {
  if (LiveLocationService.customSelectedLabel != null &&
      LiveLocationService.customSelectedPosition != null &&
      (LiveLocationService.customSelectedPosition!.latitude - loc.latitude).abs() < 0.01 &&
      (LiveLocationService.customSelectedPosition!.longitude - loc.longitude).abs() < 0.01) {
    return LiveLocationService.customSelectedLabel!;
  }
  final lat = loc.latitude;
  final lng = loc.longitude;
  // ── Greater Cairo ──
  if (lat >= 29.81 && lat <= 29.92 && lng >= 31.26 && lng <= 31.38) return 'Helwan, Cairo';
  if (lat >= 29.93 && lat <= 30.00 && lng >= 31.22 && lng <= 31.33) return 'Maadi, Cairo';
  if (lat >= 30.00 && lat <= 30.08 && lng >= 31.19 && lng <= 31.28) return 'Downtown Cairo';
  if (lat >= 30.00 && lat <= 30.08 && lng >= 31.14 && lng <= 31.21) return 'Dokki & Giza';
  if (lat >= 30.04 && lat <= 30.16 && lng >= 31.28 && lng <= 31.42) return 'Nasr City & Heliopolis';
  if (lat >= 29.95 && lat <= 30.10 && lng >= 31.38 && lng <= 31.56) return 'New Cairo (Tagamoa)';
  if (lat >= 29.86 && lat <= 30.08 && lng >= 30.82 && lng <= 31.08) return '6th of October City';
  if (lat >= 30.05 && lat <= 30.20 && lng >= 31.00 && lng <= 31.20) return 'Sheikh Zayed';
  if (lat >= 30.08 && lat <= 30.25 && lng >= 31.42 && lng <= 31.60) return 'Shorouk & Obour';
  if (lat >= 29.75 && lat <= 29.82 && lng >= 31.22 && lng <= 31.38) return 'Ain Helwan & Tebbin';
  // ── Alexandria ──
  if (lat >= 31.08 && lat <= 31.38 && lng >= 29.70 && lng <= 30.20) return 'Alexandria';
  // ── Delta ──
  if (lat >= 30.55 && lat <= 30.90 && lng >= 31.10 && lng <= 31.60) return 'Tanta & Gharbia';
  if (lat >= 30.55 && lat <= 30.80 && lng >= 31.60 && lng <= 32.00) return 'Mansoura & Dakahlia';
  if (lat >= 31.00 && lat <= 31.30 && lng >= 31.10 && lng <= 31.50) return 'Damietta';
  if (lat >= 30.30 && lat <= 30.70 && lng >= 31.70 && lng <= 32.20) return 'Ismailia';
  if (lat >= 30.55 && lat <= 31.00 && lng >= 32.00 && lng <= 32.60) return 'Port Said';
  if (lat >= 29.90 && lat <= 30.40 && lng >= 32.20 && lng <= 32.80) return 'Suez';
  // ── Upper Egypt ──
  if (lat >= 26.60 && lat <= 27.20 && lng >= 31.60 && lng <= 32.20) return 'Luxor';
  if (lat >= 23.90 && lat <= 24.20 && lng >= 32.70 && lng <= 33.00) return 'Aswan';
  if (lat >= 26.00 && lat <= 26.40 && lng >= 31.60 && lng <= 32.00) return 'Sohag';
  if (lat >= 26.90 && lat <= 27.60 && lng >= 30.70 && lng <= 31.60) return 'Assiut';
  if (lat >= 28.00 && lat <= 28.50 && lng >= 30.60 && lng <= 31.20) return 'Minya';
  if (lat >= 28.50 && lat <= 29.10 && lng >= 30.80 && lng <= 31.40) return 'Beni Suef';
  if (lat >= 29.10 && lat <= 29.60 && lng >= 30.90 && lng <= 31.50) return 'Fayoum';
  // ── Red Sea & Sinai ──
  if (lat >= 27.10 && lat <= 27.40 && lng >= 33.70 && lng <= 34.00) return 'Hurghada';
  if (lat >= 27.80 && lat <= 28.10 && lng >= 34.20 && lng <= 34.60) return 'Sharm El Sheikh';
  // ── Fallback: show coordinates ──
  return 'Current Location (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})';
}

List<Responder> _getRespondersForLocation(LatLng from) {
  final area = getAreaName(from);
  // Dynamically cluster realistic Egyptian emergency services directly around the user's real GPS position
  return [
    Responder(
      id: 'near_amb_1',
      name: 'Ambulance Rapid Response #12',
      type: ResponderType.paramedic,
      specialty: 'Emergency Mobile Ambulance Unit',
      location: LatLng(from.latitude + 0.0031, from.longitude + 0.0024),
      address: 'Ambulance Outpost, $area',
      phone: '123',
    ),
    Responder(
      id: 'near_hosp_1',
      name: 'General Emergency Hospital',
      type: ResponderType.doctor,
      specialty: 'Emergency Medicine & Trauma Center',
      location: LatLng(from.latitude - 0.0045, from.longitude + 0.0038),
      address: 'Central Emergency Hospital, $area',
      phone: '137',
    ),
    Responder(
      id: 'near_doc_1',
      name: 'Dr. Walid Mansour',
      type: ResponderType.doctor,
      specialty: 'Trauma & Emergency Care Specialist',
      location: LatLng(from.latitude + 0.0052, from.longitude - 0.0035),
      address: 'Specialized Medical Clinic, $area',
      phone: '01001234567',
    ),
    Responder(
      id: 'near_nurse_1',
      name: 'Nurse Sara Youssef',
      type: ResponderType.nurse,
      specialty: 'ICU & Critical Care Nurse',
      location: LatLng(from.latitude - 0.0032, from.longitude - 0.0028),
      address: 'Community Health Center, $area',
      phone: '01112345678',
    ),
    Responder(
      id: 'near_amb_2',
      name: 'Mobile ICU Ambulance Unit #05',
      type: ResponderType.paramedic,
      specialty: 'Advanced Intensive Care Ambulance',
      location: LatLng(from.latitude + 0.0068, from.longitude + 0.0055),
      address: 'Regional Dispatch Hub, $area',
      phone: '123',
    ),
    Responder(
      id: 'near_vol_1',
      name: 'Volunteer Omar Samir',
      type: ResponderType.volunteer,
      specialty: 'Egyptian Red Crescent First Responder',
      location: LatLng(from.latitude + 0.0018, from.longitude - 0.0016),
      address: 'First Aid Volunteer Post, $area',
      phone: '01556789012',
    ),
    Responder(
      id: 'near_doc_2',
      name: 'Dr. Mona Khaled',
      type: ResponderType.doctor,
      specialty: 'Cardiologist & Emergency Resuscitation',
      location: LatLng(from.latitude - 0.0065, from.longitude - 0.0048),
      address: 'Heart & Emergency Center, $area',
      phone: '01223456789',
    ),
    Responder(
      id: 'near_vol_2',
      name: 'Volunteer Aya Mahmoud',
      type: ResponderType.volunteer,
      specialty: 'Certified CPR & First Aid Volunteer',
      location: LatLng(from.latitude - 0.0021, from.longitude + 0.0042),
      address: 'Youth Volunteer Station, $area',
      phone: '01099887766',
    ),
  ];
}

List<_RespWithDist> _sortedByDistance(LatLng from) {
  final list = _getRespondersForLocation(from)
      .map((r) => _RespWithDist(r, _haversineKm(from, r.location)))
      .toList()
    ..sort((a, b) => a.distKm.compareTo(b.distKm));
  return list;
}

class _RespWithDist {
  final Responder responder;
  final double distKm;
  const _RespWithDist(this.responder, this.distKm);
  String get distLabel =>
      distKm < 1 ? '${(distKm * 1000).round()} m' : '${distKm.toStringAsFixed(1)} km';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'responder': responder.toJson(),
        'distKm': distKm,
      };

  static _RespWithDist? fromJson(Object? raw) {
    final j = _stringKeyedMap(raw);
    final responder = Responder.fromJson(j['responder']);
    final distKm = _finiteDouble(j['distKm']);
    if (responder == null || distKm == null || distKm < 0) return null;
    return _RespWithDist(responder, distKm);
  }
}

// ── Find nearest responder of specific type (or any type) ────────────────────
_RespWithDist? _nearestOfType(LatLng from, {ResponderType? type}) {
  final list = _getRespondersForLocation(from)
      .where((r) => type == null || r.type == type)
      .map((r) => _RespWithDist(r, _haversineKm(from, r.location)))
      .toList()
    ..sort((a, b) => a.distKm.compareTo(b.distKm));
  return list.isEmpty ? null : list.first;
}

// ── Estimated travel time (rough: 30 km/h city speed) ────────────────────────
String _estimatedETA(double distKm) {
  final minutes = (distKm / 30 * 60).round();
  if (minutes < 1)  return '< 1 min';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

// ── Open Google Maps navigation ───────────────────────────────
Future<void> _openDirections(LatLng from, LatLng to) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&origin=${from.latitude},${from.longitude}'
    '&destination=${to.latitude},${to.longitude}'
    '&travelmode=driving',
  );
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    // Launcher unavailable: leave the current screen intact.
  }
}

// ============================================================
// EMERGENCY STATE
// ============================================================

enum EmergencyStatus { idle, requesting, active, resolved }

/// Single source of truth for the SOS duplicate guard. Extracted only so it can
/// be unit-tested without opening a dialer or SMS composer.
@visibleForTesting
bool canTriggerSos({
  required EmergencyStatus status,
  required bool triggerInProgress,
}) =>
    status == EmergencyStatus.idle && !triggerInProgress;

class EmergencySession {
  final String id;
  LatLng location; // updated by the emergency-owned GPS stream
  final DateTime startTime;
  final LocationSource source;
  final double? accuracyMeters;
  final String? addressLabel;
  final List<String> timeline;
  EmergencyStatus status;
  _RespWithDist? assignedResponder;

  EmergencySession({
    required this.id,
    required this.location,
    required this.startTime,
    this.source = LocationSource.lastKnown,
    this.accuracyMeters,
    this.addressLabel,
    List<String>? timeline,
    this.status = EmergencyStatus.requesting,
    this.assignedResponder,
  }) : timeline = timeline ?? <String>[];

  String get sourceLabel {
    switch (source) {
      case LocationSource.liveGps:         return 'LIVE GPS';
      case LocationSource.lastKnown:       return 'LAST KNOWN';
      case LocationSource.cached:          return 'CACHED';
      case LocationSource.simulated:       return 'SIMULATED';
      case LocationSource.manualSelection: return 'MANUAL SELECTION';
      case LocationSource.fallback:        return 'FALLBACK (not real)';
    }
  }

  void addEvent(String event) =>
      timeline.add('${DateTime.now().toIso8601String()} · $event');

  // ── Persistence helpers ──
  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': location.latitude,
    'lng': location.longitude,
    'startTime': startTime.toIso8601String(),
    'status': status.name,
    'source': source.name,
    'accuracy': accuracyMeters,
    'address': addressLabel,
    'timeline': timeline,
    // Full record for restoration; legacy keys are kept for backward readers.
    'responder': assignedResponder?.toJson(),
    'responderName': assignedResponder?.responder.name,
    'responderDist': assignedResponder?.distLabel,
  };

  static EmergencySession fromJson(Map<String, dynamic> j) {
    final session = EmergencySession(
      id: j['id'] as String,
      location: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
      startTime: DateTime.parse(j['startTime'] as String),
      source: LocationSource.values.firstWhere(
        (e) => e.name == j['source'],
        orElse: () => LocationSource.lastKnown,
      ),
      accuracyMeters: j['accuracy'] == null
          ? null
          : (j['accuracy'] as num).toDouble(),
      addressLabel: j['address'] as String?,
      timeline: (j['timeline'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      status: EmergencyStatus.values.firstWhere(
        (e) => e.name == j['status'],
        orElse: () => EmergencyStatus.resolved,
      ),
      assignedResponder: _RespWithDist.fromJson(j['responder']),
    );
    return session;
  }
}

// ── Global active session (simple state – swap with Provider later) ──
EmergencySession? _activeSession;

/// Client id of the GPS stream owned by the active emergency, kept alive even
/// when the SOS screen is popped. Cleared on cancel/resolution.
int? _emergencyTrackToken;

// ── History list (saved locally, swap with DB later) ──
final List<EmergencySession> _emergencyHistory = [];

const String _historyPrefsKey = 'emergency_history';
const String _activeSessionPrefsKey = 'emergency_active_session_id';

/// All persistence goes through this tail so overlapping saves cannot interleave
/// and leave a partially written SharedPreferences state.
Future<void> _historyWriteTail = Future.value();

// ── Add/update a session in local history ──
// Does NOT invent a resolved status: the caller owns the real status.
Future<void> _saveToHistory(EmergencySession session) async {
  final index = _emergencyHistory.indexWhere((s) => s.id == session.id);
  if (index >= 0) {
    _emergencyHistory[index] = session;
  } else {
    _emergencyHistory.insert(0, session); // newest first
  }
  await _persistHistory(); // SharedPreferences; local only, no backend claim
}

// ── Persist history and active-session identity (serialized) ──
Future<void> _persistHistory() {
  final write = _historyWriteTail.then((_) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = _emergencyHistory
          .map((s) => jsonEncode(s.toJson()))
          .toList(growable: false);
      await prefs.setStringList(_historyPrefsKey, snapshot);

      final active = _activeSession;
      if (active != null && active.status != EmergencyStatus.resolved) {
        await prefs.setString(_activeSessionPrefsKey, active.id);
      } else {
        await prefs.remove(_activeSessionPrefsKey);
      }
      debugPrint('Nabd history: persisted ${_emergencyHistory.length} session(s)');
    } catch (e) {
      debugPrint('Nabd history: persist failed: $e');
    }
  });
  _historyWriteTail = write.catchError((_) {});
  return write;
}

// ── Load history from SharedPreferences on startup ──
Future<void> _loadPersistedHistory() async {
  await _historyWriteTail;
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_historyPrefsKey) ?? <String>[];
    _emergencyHistory.clear();

    for (final entry in jsonList) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is! Map<String, dynamic>) continue;
        final session = EmergencySession.fromJson(decoded);
        _emergencyHistory.add(session);
      } catch (e) {
        debugPrint('Nabd history: skipped malformed record: $e');
      }
    }

    final activeId = prefs.getString(_activeSessionPrefsKey);
    EmergencySession? orphan;
    for (final session in _emergencyHistory) {
      final unresolved = session.status == EmergencyStatus.active ||
          session.status == EmergencyStatus.requesting;
      if (!unresolved) continue;
      if (activeId != null && session.id == activeId) {
        orphan = session;
        break;
      }
      orphan ??= session;
    }

    // No process-owned stream can survive a restart. Close any unresolved
    // session honestly instead of implying live tracking continued.
    _activeSession = null;
    await prefs.remove(_activeSessionPrefsKey);
    if (orphan != null) {
      orphan.addEvent(
        'App restarted — local session auto-resolved; live tracking does not '
        'continue after process termination.',
      );
      orphan.status = EmergencyStatus.resolved;
    }
    await _persistHistory();

    debugPrint('Nabd history: loaded ${_emergencyHistory.length} session(s) from SharedPreferences');
  } catch (e) {
    debugPrint('Nabd history: load failed; starting empty: $e');
  }
}

// ============================================================
// NOTIFICATION SERVICE
// ============================================================

Future<bool>? _firebaseInitFuture;

/// Initializes Firebase at most once, unless a caller explicitly forces a
/// retry. A failure never prevents the local-only app from starting.
Future<bool> initializeFirebaseSafely({bool force = false}) {
  final existing = _firebaseInitFuture;
  if (!force && existing != null) return existing;
  final future = _performFirebaseInitialization();
  _firebaseInitFuture = future;
  return future;
}

Future<bool> _performFirebaseInitialization() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    return true;
  } catch (e) {
    debugPrint('Nabd Firebase: initialization failed; local mode continues: $e');
    return false;
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final ready = await initializeFirebaseSafely();
  if (!ready) return;
  // Payloads are recorded for diagnostics only. No delivery, dispatch or ETA
  // is claimed from a background FCM message.
  debugPrint('Nabd Firebase: background payload received: ${message.messageId}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static FirebaseMessaging? _fcm;
  static bool _initialized = false;
  static bool _firebaseReady = false;
  static int _nextNotificationId = 0;

  /// Last permission status returned by FCM. Null when Firebase is unavailable.
  static String? permissionStatus;

  /// Last payloads handled locally. They are records, not delivery receipts.
  static Map<String, dynamic>? lastNotificationPayload;
  static Map<String, dynamic>? initialNotificationPayload;

  static Future<void> init({required bool firebaseReady}) async {
    if (_initialized) return;

    // Local notifications setup — independent of Firebase availability.
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create notification channel (Android 8+)
    const channel = AndroidNotificationChannel(
      'nabd_emergency_channel',
      'Emergency Alerts',
      description: 'Nabd emergency notifications',
      importance: Importance.max,
      playSound: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    if (firebaseReady) {
      await _configureFirebaseMessaging();
    } else {
      debugPrint('Nabd Firebase: skipped messaging setup; local notifications only');
    }

    _initialized = true;
  }

  static Future<void> _configureFirebaseMessaging() async {
    try {
      _fcm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final settings = await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      permissionStatus = settings.authorizationStatus.name;

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (msg) => _recordPayload(msg, 'openedApp'),
      );

      final initialMsg = await _fcm!.getInitialMessage();
      if (initialMsg != null) {
        initialNotificationPayload = _payloadOf(initialMsg, 'coldStart');
      }
      _firebaseReady = true;
    } catch (e) {
      // Firebase is optional: local notifications and the local SOS record
      // continue to work even when messaging is not configured.
      debugPrint('Nabd Firebase: messaging setup failed; local mode continues: $e');
      _fcm = null;
      _firebaseReady = false;
    }
  }

  static Map<String, dynamic> _payloadOf(RemoteMessage msg, String source) =>
      <String, dynamic>{
        'source': source,
        'messageId': msg.messageId,
        'title': msg.notification?.title,
        'body': msg.notification?.body,
        'data': Map<String, dynamic>.from(msg.data),
      };

  static void _recordPayload(RemoteMessage msg, String source) {
    lastNotificationPayload = _payloadOf(msg, source);
    debugPrint('Nabd Firebase: payload stored from $source; '
        'delivery and dispatch are not confirmed');
  }

  static void _handleForegroundMessage(RemoteMessage msg) {
    _recordPayload(msg, 'foreground');
    unawaited(_showLocal(
      title: msg.notification?.title ?? 'Emergency Alert',
      body: msg.notification?.body ?? '',
    ));
  }

  static Future<void> showEmergencyAlert({
    required String title,
    required String body,
  }) => _showLocal(title: title, body: body);

  /// Neutralized demo entry point. It never claims a responder or ETA.
  static Future<void> showTestNotification() async {
    await showEmergencyAlert(
      title: 'Nabd local test notification',
      body: 'Local test only — no responder dispatched and no delivery confirmed.',
    );
  }

  static Future<void> _showLocal({
    required String title,
    required String body,
  }) async {
    // Microseconds plus a monotonic counter avoid same-second notification ID
    // collisions in the Android tray.
    final id = DateTime.now().microsecondsSinceEpoch + _nextNotificationId++;
    await _local.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'nabd_emergency_channel',
          'Emergency Alerts',
          channelDescription: 'Nabd emergency notifications',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Returns a token only after successful Firebase + messaging setup.
  /// The token is never sent to a backend from this module.
  static Future<String?> getToken() async {
    if (!_firebaseReady || _fcm == null) return null;
    try {
      return await _fcm!.getToken();
    } catch (_) {
      return null;
    }
  }

  static void resetForTesting() {
    _initialized = false;
    _firebaseReady = false;
    _fcm = null;
    _nextNotificationId = 0;
    permissionStatus = null;
    lastNotificationPayload = null;
    initialNotificationPayload = null;
  }

  @visibleForTesting
  static void handlePayloadForTesting(RemoteMessage message) =>
      _recordPayload(message, 'test');
}

// ============================================================
// LOCATION SOURCE TRACKING (GPS Source Labeling)
// ============================================================

enum LocationSource {
  liveGps,
  lastKnown,
  cached,
  simulated,       // emulator/mock provider
  manualSelection, // user picked from preset list
  fallback,        // hardcoded default — NOT real location
}

class LocationResult {
  final LatLng position;
  final LocationSource source;
  final double? accuracyMeters;
  final DateTime timestamp;

  const LocationResult({
    required this.position,
    required this.source,
    this.accuracyMeters,
    required this.timestamp,
  });

  String get sourceLabel {
    switch (source) {
      case LocationSource.liveGps:          return 'LIVE GPS';
      case LocationSource.lastKnown:        return 'LAST KNOWN';
      case LocationSource.cached:           return 'CACHED';
      case LocationSource.simulated:        return 'SIMULATED';
      case LocationSource.manualSelection:  return 'MANUAL SELECTION';
      case LocationSource.fallback:         return 'FALLBACK (not real)';
    }
  }

  bool get isReal => source == LocationSource.liveGps ||
                     source == LocationSource.lastKnown;
}

// ============================================================
// LIVE LOCATION SERVICE (Mobile Emergency Module)
// ============================================================

class LiveLocationService {
  static StreamSubscription<Position>? _sub;
  static final Map<int, void Function(LatLng)> _clients = {};
  static int _nextClientId = 0;
  static bool _streamSyncing = false;

  /// Internal health state. No UI is driven directly from these fields except
  /// the existing LIVE badge on the live-tracking screen.
  static Object? lastStreamError;
  static bool get streamHealthy => lastStreamError == null && _sub != null;

  static LatLng? lastKnownPosition;
  static LatLng? customSelectedPosition;
  static String? customSelectedLabel;
  static LocationSource lastSource = LocationSource.fallback;
  static double? lastAccuracyMeters;
  static DateTime? lastUpdateTime;
  static AddressInfo? lastAddressInfo;

  static String get lastSourceLabel {
    switch (lastSource) {
      case LocationSource.liveGps:         return 'LIVE GPS';
      case LocationSource.lastKnown:       return 'LAST KNOWN';
      case LocationSource.cached:          return 'CACHED';
      case LocationSource.simulated:       return 'SIMULATED';
      case LocationSource.manualSelection: return 'MANUAL SELECTION';
      case LocationSource.fallback:        return 'FALLBACK (not real)';
    }
  }

  /// Compact metadata line used by map/home location chips.
  static String get metadataLine {
    final parts = <String>[lastSourceLabel];
    if (lastAccuracyMeters != null) {
      parts.add('±${lastAccuracyMeters!.round()}m');
    }
    final t = lastUpdateTime;
    if (t != null) {
      parts.add('${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}');
    }
    return parts.join(' · ');
  }

  static void setCustomLocation(LatLng loc, {String? label}) {
    customSelectedPosition = loc;
    customSelectedLabel = label;
    lastKnownPosition = loc;
    lastSource = LocationSource.manualSelection;
    lastAccuracyMeters = null;
    lastUpdateTime = DateTime.now();
    lastAddressInfo = null;
    // A manually selected point must never be overwritten by an old live
    // stream while it is active.
    unawaited(_syncTrackingStream());
    for (final client in _clients.values.toList()) {
      client(loc);
    }
  }

  static void clearCustomLocation() {
    customSelectedPosition = null;
    customSelectedLabel = null;
    // Clear every value derived from the manual point so it cannot later be
    // presented as CACHED or LAST KNOWN GPS.
    lastKnownPosition = null;
    lastSource = LocationSource.fallback;
    lastAccuracyMeters = null;
    lastUpdateTime = null;
    lastAddressInfo = null;
    unawaited(_syncTrackingStream());
  }

  /// Starts (or joins) the single shared GPS stream.
  /// Returns a client id that MUST be passed to [stopTracking] when the
  /// owning screen/session is disposed. This prevents duplicate listeners.
  static int startTracking({required void Function(LatLng) onUpdate}) {
    final id = ++_nextClientId;
    _clients[id] = onUpdate;
    debugPrint('Nabd GPS: start client=$id total=${_clients.length}');
    if (customSelectedPosition != null) {
      onUpdate(customSelectedPosition!);
    }
    unawaited(_syncTrackingStream());
    return id;
  }

  static void _emit(Position pos) {
    lastStreamError = null;
    lastKnownPosition = LatLng(pos.latitude, pos.longitude);
    lastSource = pos.isMocked ? LocationSource.simulated : LocationSource.liveGps;
    lastAccuracyMeters = pos.accuracy;
    lastUpdateTime = DateTime.now();
    lastAddressInfo = null; // address must be re-resolved for a new position
    final posCopy = lastKnownPosition!;
    for (final client in _clients.values.toList()) {
      client(posCopy);
    }
  }

  /// Stops one client, or all clients when called without an id (full reset).
  static void stopTracking([int? clientId]) {
    if (clientId == null) {
      _clients.clear();
    } else {
      _clients.remove(clientId);
    }
    debugPrint('Nabd GPS: stop client=$clientId remaining=${_clients.length}');
    unawaited(_syncTrackingStream());
  }

  /// Re-attempts the shared stream after a permission/service error.
  /// Existing client ids are preserved.
  static Future<void> retryStream() async {
    lastStreamError = null;
    await _sub?.cancel();
    _sub = null;
    await _syncTrackingStream();
  }

  static Future<void> _syncTrackingStream() async {
    if (_streamSyncing) return;
    _streamSyncing = true;
    try {
      if (customSelectedPosition != null || _clients.isEmpty) {
        await _sub?.cancel();
        _sub = null;
        return;
      }
      if (_sub != null) return;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        lastStreamError = 'Location service disabled';
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        lastStreamError = 'Location permission denied';
        return;
      }

      lastStreamError = null;
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // meters — battery-aware
        ),
      ).listen(_emit, onError: (Object e) {
        lastStreamError = e;
        final failedSub = _sub;
        _sub = null;
        if (failedSub != null) {
          unawaited(failedSub.cancel().then((_) {}));
        }
        debugPrint('Nabd GPS stream error: $e');
      });
    } catch (e) {
      lastStreamError = e;
      await _sub?.cancel();
      _sub = null;
      debugPrint('Nabd GPS stream setup error: $e');
    } finally {
      _streamSyncing = false;
    }
  }

  static Future<void> openSettings() => Geolocator.openAppSettings();

  static String permissionMessage(LocationPermission p) {
    switch (p) {
      case LocationPermission.denied:
        return 'Location permission denied';
      case LocationPermission.deniedForever:
        return 'Location permission permanently denied — open app settings';
      case LocationPermission.unableToDetermine:
        return 'Unable to determine location permission';
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return 'Location permission granted';
    }
  }

  /// Builds a truthful fallback result from the last observed position.
  /// A mocked cached position must stay SIMULATED; ordinary cached positions
  /// keep their previous [ordinarySource] label.
  static LocationResult _lastKnownResult(LocationSource ordinarySource) {
    final source = lastSource == LocationSource.simulated
        ? LocationSource.simulated
        : ordinarySource;
    final now = DateTime.now();
    lastSource = source;
    lastUpdateTime = now;
    return LocationResult(
      position: lastKnownPosition!,
      source: source,
      accuracyMeters: lastAccuracyMeters,
      timestamp: now,
    );
  }

  /// Returns the current device position with source labeling.
  /// NEVER silently returns a hardcoded fallback as "real" location.
  static Future<LocationResult?> getCurrentPositionWithSource() async {
    if (customSelectedPosition != null) {
      return LocationResult(
        position: customSelectedPosition!,
        source: LocationSource.manualSelection,
        timestamp: DateTime.now(),
      );
    }
    try {
      // 1. Check location service
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Try cached before giving up
        final cached = await Geolocator.getLastKnownPosition();
        if (cached != null) {
          lastKnownPosition = LatLng(cached.latitude, cached.longitude);
          lastSource = cached.isMocked
              ? LocationSource.simulated
              : LocationSource.cached;
          lastAccuracyMeters = cached.accuracy;
          lastUpdateTime = DateTime.now();
          return LocationResult(
            position: lastKnownPosition!,
            source: lastSource,
            accuracyMeters: cached.accuracy,
            timestamp: lastUpdateTime!,
          );
        }
        // No cached position available, return null — do NOT fake it
        return null;
      }

      // 2. Check and request location permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever ||
          perm == LocationPermission.unableToDetermine) {
        debugPrint('Nabd: ${permissionMessage(perm)}');
        // Only a previously observed position may be returned, clearly cached.
        if (lastKnownPosition != null) {
          return _lastKnownResult(LocationSource.cached);
        }
        return null;
      }

      // 3. Try last known instantly (non-blocking)
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        lastKnownPosition = LatLng(cached.latitude, cached.longitude);
        // Remember mock provenance and real accuracy for the timeout fallback.
        lastSource = cached.isMocked
            ? LocationSource.simulated
            : LocationSource.lastKnown;
        lastAccuracyMeters = cached.accuracy;
      }

      // 4. Try high-precision GPS with 8s timeout
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 8),
          ),
        );
        lastKnownPosition = LatLng(pos.latitude, pos.longitude);
        lastSource = pos.isMocked ? LocationSource.simulated : LocationSource.liveGps;
        lastAccuracyMeters = pos.accuracy;
        lastUpdateTime = DateTime.now();
        return LocationResult(
          position: lastKnownPosition!,
          source: lastSource,
          accuracyMeters: pos.accuracy,
          timestamp: DateTime.now(),
        );
      } catch (_) {
        // High-precision timed out — try medium accuracy
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 5),
            ),
          );
          lastKnownPosition = LatLng(pos.latitude, pos.longitude);
          lastSource = pos.isMocked ? LocationSource.simulated : LocationSource.liveGps;
          lastAccuracyMeters = pos.accuracy;
          lastUpdateTime = DateTime.now();
          return LocationResult(
            position: lastKnownPosition!,
            source: lastSource,
            accuracyMeters: pos.accuracy,
            timestamp: DateTime.now(),
          );
        } catch (_) {
          // Fall back to cached/last known — labeled correctly
          if (lastKnownPosition != null) {
            return _lastKnownResult(LocationSource.lastKnown);
          }
          return null;
        }
      }
    } catch (_) {
      if (lastKnownPosition != null) {
        return _lastKnownResult(LocationSource.lastKnown);
      }
      return null;
    }
  }

  /// Legacy wrapper — returns position only, for backward compatibility.
  /// Now returns null instead of hardcoded fallback when GPS unavailable.
  static Future<LatLng?> getCurrentPosition() async {
    final result = await getCurrentPositionWithSource();
    return result?.position;
  }

  /// Prompts only when the device GPS is off or permission is not granted.
  /// Offers App Settings for permanently-denied/restricted permission states.
  static Future<void> promptEnableGps(BuildContext context) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      final perm = await Geolocator.checkPermission();
      final needsGps = !enabled;
      final needsPermission = perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever ||
          perm == LocationPermission.unableToDetermine;
      if ((!needsGps && !needsPermission) || !context.mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1D21),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFE92335).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off_rounded, color: Color(0xFFE92335), size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                needsGps ? 'تفعيل خدمة الموقع (GPS)' : 'صلاحية الموقع مطلوبة',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                needsGps
                    ? 'خدمة الـ GPS غير مفعلة على هاتفك.\nلتحديد مكانك وتوجيه أقرب إسعاف وطبيب إليك بدقة، يرجى تفعيل الموقع.'
                    : 'يجب السماح للتطبيق بالوصول إلى موقع الجهاز لتحديد مكانك بدقة.\n${permissionMessage(perm)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('لاحقاً', style: TextStyle(color: Colors.white54, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE92335),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.my_location_rounded, size: 20),
                      label: Text(
                        needsGps ? 'تفعيل الآن' : 'منح الصلاحية',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (needsGps) {
                          await Geolocator.openLocationSettings();
                        } else if (perm == LocationPermission.denied) {
                          await Geolocator.requestPermission();
                        } else {
                          await openSettings();
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (needsPermission && perm != LocationPermission.denied)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await openSettings();
                  },
                  child: const Text('Open App Settings',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    } catch (_) {}
  }
}

// ── SOS launch helpers ─────────────────────────────────────────
// These only OPEN a dialer/SMS/WhatsApp composer. They never place a call or
// send a message by themselves and never claim that a backend was contacted.
// Return value reports the real launch result so the UI can be honest.

Future<bool> _openDialer(String number) async {
  final uri = Uri(scheme: 'tel', path: number);
  try {
    if (!await canLaunchUrl(uri)) return false;
    return await launchUrl(uri);
  } catch (_) {
    return false;
  }
}

/// Opens the SMS composer with the current location link. Returns true only
/// when an SMS app was actually launched.
Future<bool> _sendEmergencySMS(LatLng location) async {
  final mapsLink =
      'https://maps.google.com/?q=${location.latitude},${location.longitude}';
  final address = LiveLocationService.lastAddressInfo?.hasAddress == true
      ? LiveLocationService.lastAddressInfo!.label
      : 'Address unavailable';
  final msg = Uri.encodeComponent(
    '🚨 EMERGENCY SOS! I need help!\nArea (approx.): ${getAreaName(location)}\n'
    'Address: $address\nMy location: $mapsLink\nPlease send help immediately.',
  );
  final smsUri = Uri.parse('sms:123?body=$msg');
  try {
    if (!await canLaunchUrl(smsUri)) return false;
    return await launchUrl(smsUri);
  } catch (_) {
    return false;
  }
}

/// Opens WhatsApp with a pre-filled message. Returns true only when WhatsApp
/// (or a browser fallback) was actually launched.
Future<bool> _sendEmergencyWhatsApp(LatLng location) async {
  final mapsLink =
      'https://maps.google.com/?q=${location.latitude},${location.longitude}';
  final address = LiveLocationService.lastAddressInfo?.hasAddress == true
      ? LiveLocationService.lastAddressInfo!.label
      : 'Address unavailable';
  final msg = Uri.encodeComponent(
    '🚨 EMERGENCY SOS! I need immediate help!\n'
    '📍 Area (approx.): ${getAreaName(location)}\n'
    '📍 Address: $address\n'
    '🗺️ My location: $mapsLink\n'
    'Please contact emergency responders (123) or come immediately!',
  );
  final waUri = Uri.parse('https://wa.me/?text=$msg');
  try {
    if (!await canLaunchUrl(waUri)) return false;
    return await launchUrl(waUri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load local history before the first frame when safe. Failures are handled
  // inside _loadPersistedHistory, so they never block app startup.
  await _loadPersistedHistory();

  runApp(const EmergencyHelpApp());

  // Firebase and notifications are initialized after the first frame, but in a
  // strict order: Firebase first, then messaging setup inside NotificationService.
  unawaited(_initBackgroundServices());
}

Future<void> _initBackgroundServices() async {
  final firebaseReady = await initializeFirebaseSafely();
  try {
    await NotificationService.init(firebaseReady: firebaseReady);
  } catch (e) {
    debugPrint('Nabd notifications: local setup failed; app continues: $e');
  }
}

class EmergencyHelpApp extends StatelessWidget {
  const EmergencyHelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nabd',

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE92335),
        ),
      ),

      // Original launch screen (matches base.apk)
      home: const GetStartedScreen(),
    );
  }
}

// ============================================================
// GET STARTED SCREEN
// ============================================================

// ============================================================
// GET STARTED SCREEN
// ============================================================

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [

          // ==================================================
          // YOUR ORIGINAL GET STARTED DESIGN
          // ==================================================

          Image.asset(
            'assets/images/onboarding_bg.png',
            fit: BoxFit.cover,
          ),
          // ==================================================
          // INVISIBLE CLICK AREA OVER THE ORIGINAL BUTTON
          // ==================================================

          Positioned(
            left: 70,
            right: 70,
            bottom: 55,
            height: 90,

            child: GestureDetector(
              behavior: HitTestBehavior.opaque,

              onTap: () {
                debugPrint('Nabd: GetStarted tapped -> HomeScreen');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HomeScreen(),
                  ),
                );
              },

              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOME SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    HomeContent(),
    MapScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,

        backgroundColor: Colors.white,
        elevation: 12,

        selectedItemColor:
        const Color(0xFFE92335),

        unselectedItemColor:
        const Color(0xFF8A8F92),

        selectedFontSize: 9,
        unselectedFontSize: 9,
        iconSize: 21,

        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.map_rounded),
            label: 'Map',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.person_outline_rounded,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOME CONTENT
// ============================================================

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  static const Color brandRed = Color(0xFFE92335);
  static const Color darkText = Color(0xFF202329);
  static const Color mutedText = Color(0xFF777E82);
  static const Color pageBackground = Color(0xFFFFF7F8);

  ll.LatLng? _userPosition = LiveLocationService.lastKnownPosition != null
      ? toLl(LiveLocationService.lastKnownPosition!)
      : null; // Start null — do NOT show hardcoded location
  String _locationDisplay = 'Detecting live GPS...';
  String _locationSourceLabel = '';
  String _addressLabel = 'Resolving address…';
  bool _hasRealLocation = false; // Track whether we have real GPS
  bool _isLocating = false;
  final fmap.MapController _previewMapController = fmap.MapController();
  final TileLoadState _previewTiles = TileLoadState();
  int? _trackingId;
  // Phase 6: Offline detection
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LiveLocationService.promptEnableGps(context);
    });
    _tryAutoDetectLocation();
    // Start live GPS tracking stream immediately upon opening
    _trackingId = LiveLocationService.startTracking(onUpdate: (loc) {
      if (!mounted) return;
      _applyLocation(toLl(loc));
    });
    // Phase 6: listen for connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted && offline != _isOffline) {
        setState(() => _isOffline = offline);
        if (offline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('No internet connection — map tiles unavailable'),
              ]),
              backgroundColor: const Color(0xFFE92335),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    if (_trackingId != null) LiveLocationService.stopTracking(_trackingId);
    super.dispose();
  }

  Future<void> _tryAutoDetectLocation() async {
    await _fetchLocation();
  }

  /// Single place that applies a new coordinate to Home UI.
  void _applyLocation(ll.LatLng position) {
    if (!mounted) return;
    final source = LiveLocationService.lastSource;
    final accuracy = LiveLocationService.lastAccuracyMeters;
    debugPrint('Nabd Home: ${position.latitude.toStringAsFixed(5)},'
        '${position.longitude.toStringAsFixed(5)} '
        'source=${LiveLocationService.lastSourceLabel} '
        'accuracy=${accuracy?.round()}m');
    setState(() {
      _userPosition = position;
      _hasRealLocation = source != LocationSource.fallback &&
          source != LocationSource.manualSelection;
      _locationSourceLabel = LiveLocationService.lastSourceLabel;
      _locationDisplay =
          '${position.latitude.toStringAsFixed(4)}, '
          '${position.longitude.toStringAsFixed(4)}'
          '${accuracy != null ? ' ±${accuracy.round()}m' : ''} '
          '[$_locationSourceLabel]';
    });
    try {
      _previewMapController.move(position, 14.5);
    } catch (_) {}
    _resolveAddress(position);
  }

  Future<void> _resolveAddress(ll.LatLng position) async {
    final gMapPos = LatLng(position.latitude, position.longitude);
    final info = await lookupAddress(gMapPos);
    debugPrint('Nabd address: ${info.verified ? info.label : 'unavailable'}');
    LiveLocationService.lastAddressInfo = info;
    if (!mounted) return;
    setState(() => _addressLabel = info.displayFor(gMapPos));
  }

  Future<void> _fetchLocation() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _locationDisplay = 'Detecting GPS location...';
    });
    try {
      final result = await LiveLocationService.getCurrentPositionWithSource();
      if (result != null && mounted) {
        LiveLocationService.lastSource = result.source;
        LiveLocationService.lastAccuracyMeters = result.accuracyMeters;
        LiveLocationService.lastUpdateTime = result.timestamp;
        _applyLocation(ll.LatLng(result.position.latitude, result.position.longitude));
      } else if (mounted) {
        debugPrint('Nabd Home: no location result (GPS off / permission / no fix)');
        setState(() {
          _locationDisplay = 'GPS unavailable — tap to retry';
          _addressLabel = 'Address unavailable';
          _hasRealLocation = false;
          _locationSourceLabel = '';
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Nabd Home: location error $e');
        setState(() {
          _locationDisplay = 'Location unavailable';
          _addressLabel = 'Address unavailable';
          _hasRealLocation = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontal = width < 360 ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Real Nabd logo asset + tagline and notification action.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFFFE8EC)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: brandRed.withOpacity(.06),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/images/nabd_logo.png',
                            height: 76,
                            width: 190,
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: brandRed,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.monitor_heart_rounded,
                                      color: Colors.white, size: 30),
                                ),
                                const SizedBox(width: 10),
                                const Text('نبض | Nabd',
                                    style: TextStyle(fontSize: 23,
                                        fontWeight: FontWeight.w900,
                                        color: brandRed)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Padding(
                            padding: EdgeInsets.only(left: 3),
                            child: Text(
                              'Help is closer than you think',
                              style: TextStyle(
                                fontSize: 11,
                                color: mutedText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Notifications',
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You are all caught up.')),
                        ),
                        icon: const Icon(Icons.notifications_none_rounded,
                            color: darkText, size: 25),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Emergency card
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EmergencySOSScreen()),
                  ),
                  child: Ink(
                    height: 174,
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF4654), Color(0xFFE8172C)],
                      ),
                      boxShadow: [
                        BoxShadow(color: brandRed.withOpacity(.19),
                            blurRadius: 18, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(children: [
                                Container(width: 23, height: 2, color: Colors.white),
                                const SizedBox(width: 8),
                                const Text('In an Emergency',
                                    style: TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w600, fontSize: 12)),
                              ]),
                              const SizedBox(height: 9),
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text('Call Now',
                                    style: TextStyle(color: Colors.white,
                                        fontSize: 34, height: 1.05,
                                        fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(height: 7),
                              const Text('Get immediate help from\nemergency services',
                                  style: TextStyle(color: Colors.white,
                                      fontSize: 11.5, height: 1.35)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 76, height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.white.withOpacity(.6), width: 5),
                              ),
                              child: const Icon(Icons.phone_rounded, color: brandRed, size: 34),
                            ),
                            const SizedBox(height: 9),
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(.2), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Main service tiles
              Row(
                children: [
                  Expanded(
                    child: _NabdServiceCard(
                      icon: Icons.medical_services_rounded,
                      title: 'First Aid',
                      subtitle: 'Simple guides for emergencies',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const FirstAidScreen())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NabdServiceCard(
                      icon: Icons.groups_rounded,
                      title: 'Nearby Help',
                      subtitle: 'Find helpers near your location',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const NearbyHelpScreen())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Location row
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => showLocationOptions(
                    context,
                    onUseCurrentLocation: _fetchLocation,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Container(width: 43, height: 43,
                            decoration: BoxDecoration(color: const Color(0xFFFFE9EC), borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.location_on_rounded, color: brandRed, size: 26)),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Your Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: darkText)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.circle, size: 7,
                                color: _hasRealLocation ? const Color(0xFF20B66B) : const Color(0xFFFFA726)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _userPosition != null
                                      ? _addressLabel
                                      : (_isLocating ? 'Detecting GPS...' : 'Tap to detect location'),
                                  style: const TextStyle(fontSize: 11, color: mutedText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                            if (_userPosition != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3, left: 13),
                                child: Text(
                                  _locationDisplay,
                                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF9BA1A6)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ]),
                        ),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                          decoration: BoxDecoration(color: const Color(0xFFFFE9EC), borderRadius: BorderRadius.circular(18)),
                          child: const Text('Change', style: TextStyle(color: brandRed, fontWeight: FontWeight.w700, fontSize: 10.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Live OpenStreetMap preview — dynamically centred on user's real GPS.
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapScreen()),
                ),
                child: Container(
                  height: 205,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1ED),
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: Stack(
                    children: [
                      if (_userPosition != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: fmap.FlutterMap(
                              mapController: _previewMapController,
                              options: fmap.MapOptions(
                                initialCenter: _userPosition!,
                                initialZoom: 14.5,
                                interactionOptions: const fmap.InteractionOptions(
                                  flags: fmap.InteractiveFlag.none,
                                ),
                              ),
                              children: [
                                _osmTileLayer(
                                  onTileError: () {
                                    if (mounted && !_previewTiles.failed) {
                                      setState(() => _previewTiles.markFailed());
                                    }
                                  },
                                  onTileLoaded: () {
                                    if (mounted && _previewTiles.failed) {
                                      setState(() => _previewTiles.markRecovered());
                                    }
                                  },
                                ),
                                fmap.MarkerLayer(
                                  markers: [
                                    fmap.Marker(
                                      point: _userPosition!,
                                      width: 46,
                                      height: 46,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: brandRed.withOpacity(0.22),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: const BoxDecoration(
                                              color: brandRed,
                                              shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                            ),
                                            child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Positioned.fill(
                          child: Center(
                            child: Text('Detecting live location…',
                                style: TextStyle(
                                    color: mutedText, fontSize: 12)),
                          ),
                        ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.96),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  color: brandRed, size: 15),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  _isLocating
                                      ? 'Detecting…'
                                      : (_userPosition != null
                                          ? _addressLabel
                                          : 'Location unavailable'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: darkText,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 17, color: darkText),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Open map',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MapScreen()),
                            ),
                            icon: const Icon(
                              Icons.navigation_rounded,
                              color: brandRed,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NabdServiceCard extends StatelessWidget {
  const _NabdServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 142,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9EC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFFE92335), size: 26),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF172027),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF777E82),
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// EMERGENCY DIALOG
// ============================================================

void showEmergencyDialog(
    BuildContext context,
    ) {
  showDialog(
    context: context,

    builder: (context) {
      return AlertDialog(
        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(
            22,
          ),
        ),

        title: const Row(
          children: [
            Icon(
              Icons.warning_rounded,

              color:
              Color(0xFFE92335),
            ),

            SizedBox(
              width: 8,
            ),

            Text(
              'Emergency Call',
            ),
          ],
        ),

        content: const Text(
          'Do you want to call emergency services now?\n\n'
              'Emergency number: 123',
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
              );
            },

            child: const Text(
              'Cancel',

              style: TextStyle(
                color:
                Colors.grey,
              ),
            ),
          ),

          ElevatedButton(
            style:
            ElevatedButton.styleFrom(
              backgroundColor:
              const Color(
                0xFFE92335,
              ),

              foregroundColor:
              Colors.white,
            ),

            onPressed: () async {
              Navigator.pop(
                context,
              );

              final Uri phoneUri =
              Uri(
                scheme: 'tel',
                path: '123',
              );

              try {
                final launched =
                await launchUrl(
                  phoneUri,
                );

                if (!launched &&
                    context.mounted) {
                  ScaffoldMessenger
                      .of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Calling is not available on this emulator.',
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger
                      .of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Calling is not available on this emulator.',
                      ),
                    ),
                  );
                }
              }
            },

            child:
            const Text(
              'Call 123',
            ),
          ),
        ],
      );
    },
  );
}

// ============================================================
// LOCATION OPTIONS
// ============================================================

void showLocationOptions(
  BuildContext context, {
  VoidCallback? onUseCurrentLocation,
  void Function(LatLng location, String label)? onLocationSelected,
}) {
  const cairoPresets = [
    (name: 'Downtown Cairo / Tahrir', lat: 30.0444, lng: 31.2357, icon: Icons.location_city_rounded),
    (name: 'Dokki & Giza', lat: 30.0385, lng: 31.2064, icon: Icons.apartment_rounded),
    (name: 'Cairo University Campus', lat: 30.0276, lng: 31.2089, icon: Icons.school_rounded),
    (name: 'Nasr City', lat: 30.0566, lng: 31.3444, icon: Icons.business_rounded),
    (name: 'Heliopolis / Masr El-Gedida', lat: 30.0886, lng: 31.3285, icon: Icons.flight_takeoff_rounded),
    (name: 'New Cairo (Tagamoa)', lat: 30.0131, lng: 31.4244, icon: Icons.domain_rounded),
    (name: 'Maadi', lat: 29.9602, lng: 31.2569, icon: Icons.park_rounded),
    (name: '6th of October City', lat: 29.9660, lng: 30.9202, icon: Icons.directions_car_rounded),
    (name: 'Alexandria Corniche', lat: 31.2001, lng: 29.9187, icon: Icons.waves_rounded),
    (name: 'Helwan Area', lat: 29.8414, lng: 31.3008, icon: Icons.near_me_rounded),
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.location_on_rounded, color: Color(0xFFE92335), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Select Emergency Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Responders and emergency map will automatically adapt to your location',
                style: TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // ── 1. Live GPS button ──
              Material(
                color: const Color(0xFFFFECEF),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    LiveLocationService.clearCustomLocation();
                    Navigator.pop(ctx);
                    onUseCurrentLocation?.call();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Detecting live device GPS location...'),
                          ],
                        ),
                        backgroundColor: Color(0xFFE92335),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE92335),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Use Live Device GPS (Auto-Detect)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF202329),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Real-time satellite & sensor coordinates',
                                style: TextStyle(fontSize: 11, color: Color(0xFF777E82)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFFE92335)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Or Choose an Egyptian Governorate / Area:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF424242)),
              ),
              const SizedBox(height: 8),

              // ── 2. Egyptian Presets List ──
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: cairoPresets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = cairoPresets[index];
                    final loc = LatLng(item.lat, item.lng);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFFF0F4F2),
                        child: Icon(item.icon, size: 18, color: const Color(0xFF333333)),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${item.lat.toStringAsFixed(4)}, ${item.lng.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey),
                      onTap: () {
                        LiveLocationService.setCustomLocation(loc, label: item.name);
                        Navigator.pop(ctx);
                        onLocationSelected?.call(loc, item.name);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Location updated to: ${item.name}'),
                            backgroundColor: const Color(0xFF20B66B),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ============================================================
// EMERGENCY SOS SCREEN  ← Mobile Emergency Module
// ============================================================

class EmergencySOSScreen extends StatefulWidget {
  const EmergencySOSScreen({super.key});

  @override
  State<EmergencySOSScreen> createState() => _EmergencySOSScreenState();
}

class _EmergencySOSScreenState extends State<EmergencySOSScreen>
    with TickerProviderStateMixin {
  static const Color brandRed   = Color(0xFFE92335);
  static const Color darkBg     = Color(0xFF0D0D0D);
  static const Color cardBg     = Color(0xFF1A1A1A);

  // State
  EmergencyStatus _status = EmergencyStatus.idle;
  LocationResult? _locationResult;
  LatLng?         _userLocation;
  String?         _addressLabel;
  _RespWithDist?  _nearestResponder;
  bool            _locationLoading = false;
  bool            _triggerInProgress = false;
  String?         _statusMessage;
  Timer?          _pingTimer;
  int?            _screenTrackToken;

  // Animations
  late AnimationController _pulseCtrl;
  late AnimationController _statusCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _statusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    final existing = _activeSession;
    if (existing != null && existing.status == EmergencyStatus.active) {
      // Re-entering during an active emergency: restore honest state instead of
      // allowing a duplicate SOS, and join the existing stream as a new client.
      _status = EmergencyStatus.active;
      _statusMessage = 'Emergency active — live GPS on this device. Complete your call to 123.';
      _locationResult = LocationResult(
        position: existing.location,
        source: existing.source,
        accuracyMeters: existing.accuracyMeters,
        timestamp: existing.startTime,
      );
      _userLocation = existing.location;
      _addressLabel = existing.addressLabel;
      _nearestResponder = existing.assignedResponder;
      _screenTrackToken = LiveLocationService.startTracking(
        onUpdate: _applyStreamedLocation,
      );
    } else {
      _fetchLocation();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _statusCtrl.dispose();
    _pingTimer?.cancel();
    // Stop only this screen's client. The emergency-owned client is stopped on
    // cancel/resolution. No global stopTracking() that would break other screens.
    if (_screenTrackToken != null) {
      LiveLocationService.stopTracking(_screenTrackToken);
      _screenTrackToken = null;
    }
    super.dispose();
  }

  // ── Get real device location with an explicit source label ──
  Future<void> _fetchLocation() async {
    setState(() => _locationLoading = true);
    final result = await LiveLocationService.getCurrentPositionWithSource();
    if (!mounted) return;
    setState(() {
      _locationResult = result;
      _userLocation = result?.position;
      _locationLoading = false;
      _addressLabel = result == null
          ? null
          : (LiveLocationService.lastAddressInfo?.hasAddress == true
              ? LiveLocationService.lastAddressInfo!.label
              : null);
      if (result != null) {
        final sorted = _sortedByDistance(result.position);
        _nearestResponder = sorted.isNotEmpty ? sorted.first : null;
      } else {
        _nearestResponder = null;
      }
    });
    if (result != null && _addressLabel == null) {
      // Reverse geocoding is separate from GPS and may be unavailable offline.
      final info = await lookupAddress(result.position);
      if (mounted && info.hasAddress) {
        setState(() => _addressLabel = info.label);
      }
    }
  }

  /// Applies a streamed GPS update without starting another listener.
  void _applyStreamedLocation(LatLng loc) {
    if (!mounted) return;
    final source = LiveLocationService.customSelectedPosition != null
        ? LocationSource.manualSelection
        : LiveLocationService.lastSource;
    setState(() {
      _locationResult = LocationResult(
        position: loc,
        source: source,
        accuracyMeters: LiveLocationService.lastAccuracyMeters,
        timestamp: DateTime.now(),
      );
      _userLocation = loc;
      _addressLabel = null;
      final sorted = _sortedByDistance(loc);
      _nearestResponder = sorted.isNotEmpty ? sorted.first : null;
    });
    lookupAddress(loc).then((info) {
      if (mounted && info.hasAddress) setState(() => _addressLabel = info.label);
    });
  }

  String get _locationSummaryLabel {
    final loc = _userLocation;
    if (loc == null || _locationResult == null) return 'GPS not available';
    final address = _addressLabel ?? 'Address unavailable';
    return '${_locationResult!.sourceLabel} · $address '
        '(${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})';
  }

  // ── Main SOS trigger ──
  Future<void> _triggerSOS() async {
    if (!canTriggerSos(
      status: _status,
      triggerInProgress: _triggerInProgress,
    )) {
      return;
    }
    _triggerInProgress = true;
    HapticFeedback.heavyImpact();

    setState(() {
      _status        = EmergencyStatus.requesting;
      _statusMessage = 'Getting your location…';
    });

    // 1. Real location only. Reuse a fresh result, otherwise re-read the device.
    LocationResult? result = _locationResult;
    if (result == null ||
        _userLocation == null ||
        result.position != _userLocation ||
        DateTime.now().difference(result.timestamp) > const Duration(seconds: 60)) {
      result = await LiveLocationService.getCurrentPositionWithSource();
    }
    if (!mounted) {
      _triggerInProgress = false;
      return;
    }
    if (result == null) {
      _triggerInProgress = false;
      setState(() {
        _status        = EmergencyStatus.idle;
        _statusMessage = 'No location available. Enable GPS / grant permission and retry.';
      });
      return;
    }
    final loc = result.position;

    // 2. Find nearest responder (demo clustering around the real position).
    final sorted = _sortedByDistance(loc);
    if (mounted) {
      setState(() {
        _locationResult = result;
        _userLocation = loc;
        _nearestResponder = sorted.isNotEmpty ? sorted.first : null;
        _statusMessage = 'Opening dialer for 123…';
      });
    }

    // 3. Create the local session BEFORE launching anything, so the SOS is
    //    recorded even if the user has no dialer/SMS app installed.
    final addressLabel = _addressLabel ??
        (LiveLocationService.lastAddressInfo?.hasAddress == true
            ? LiveLocationService.lastAddressInfo!.label
            : null) ??
        'Address unavailable';
    final session = EmergencySession(
      id:        DateTime.now().millisecondsSinceEpoch.toString(),
      location:  loc,
      startTime: DateTime.now(),
      source:    result.source,
      accuracyMeters: result.accuracyMeters,
      addressLabel: addressLabel,
      status:    EmergencyStatus.requesting,
      assignedResponder: sorted.isNotEmpty ? sorted.first : null,
    );
    session.addEvent('SOS pressed · ${result.sourceLabel} · $addressLabel');
    _activeSession = session;
    await _saveToHistory(session);

    // 4. Open dialer. We do NOT place the call — the user must complete it.
    final dialerOpened = await _openDialer('123');
    session.addEvent(dialerOpened
        ? 'Dialer opened for 123 (call not placed by app)'
        : 'No dialer available — call 123 manually');
    if (!mounted) {
      _triggerInProgress = false;
      return;
    }
    setState(() => _statusMessage = 'Opening SMS composer…');

    // 5. Open SMS composer with the real coordinates.
    bool smsOpened = false;
    try {
      smsOpened = await _sendEmergencySMS(loc);
    } catch (_) {
      smsOpened = false;
    }
    session.addEvent(smsOpened
        ? 'SMS composer opened with location link (not auto-sent)'
        : 'SMS app unavailable — location saved locally');
    await _saveToHistory(session);
    debugPrint('Nabd SOS: loc=${loc.latitude.toStringAsFixed(5)},'
        '${loc.longitude.toStringAsFixed(5)} source=${result.sourceLabel} '
        'accuracy=${result.accuracyMeters?.round()}m '
        'dialerOpened=$dialerOpened smsOpened=$smsOpened '
        'address="$addressLabel" (local only)');

    // 6. Activate session and start ONE tracked GPS client owned by this SOS.
    session.status = EmergencyStatus.active;
    session.addEvent('Emergency active locally — no backend delivery confirmed');
    await _saveToHistory(session);
    if (_emergencyTrackToken != null) {
      LiveLocationService.stopTracking(_emergencyTrackToken);
    }
    _emergencyTrackToken = LiveLocationService.startTracking(onUpdate: (newLoc) {
      _applyStreamedLocation(newLoc);
      if ((_haversineKm(session.location, newLoc) * 1000) > 20) {
        session.location = newLoc;
        session.addEvent('Location updated · ${LiveLocationService.lastSourceLabel}');
        unawaited(_saveToHistory(session));
      }
    });

    // 7. Local-only notification — no claim that a responder was dispatched.
    await NotificationService.showEmergencyAlert(
      title: '🚨 SOS recorded on this device',
      body: dialerOpened
          ? 'Dialer opened for 123. Complete the call to request help.'
          : 'No dialer available. Call 123 manually. Location saved locally.',
    );

    if (!mounted) {
      _triggerInProgress = false;
      return;
    }
    setState(() {
      _status = EmergencyStatus.active;
      _statusMessage = dialerOpened
          ? 'Dialer opened — complete the call to 123. Location saved locally.'
          : 'Call 123 manually. Location saved locally.';
      if (!smsOpened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS app unavailable. Your location is saved locally.')),
        );
      }
      _triggerInProgress = false;
    });

    // 8. Local reminder pings only — labelled as reminders, not responder ETA.
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        NotificationService.showEmergencyAlert(
          title: 'Nabd local reminder',
          body: dialerOpened
              ? 'Complete your call to 123 if you have not already.'
              : 'Call 123 manually to request help.',
        );
      }
    });
  }

  // ── Cancel emergency ──
  Future<void> _cancelEmergency() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Emergency?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel the emergency request?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brandRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _pingTimer?.cancel();
      _pingTimer = null;
      if (_emergencyTrackToken != null) {
        LiveLocationService.stopTracking(_emergencyTrackToken);
        _emergencyTrackToken = null;
      }
      final session = _activeSession;
      // Clear identity before persisting so the active-session key is removed.
      _activeSession = null;
      if (session != null) {
        session.addEvent('Emergency cancelled by user');
        session.status = EmergencyStatus.resolved;
        session.assignedResponder = null;
        await _saveToHistory(session);
      }
      setState(() {
        _status        = EmergencyStatus.idle;
        _statusMessage = 'Emergency cancelled. Local record kept in history.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _status == EmergencyStatus.active;
    final isRequesting = _status == EmergencyStatus.requesting;

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Emergency SOS',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          if (isActive)
            TextButton.icon(
              onPressed: _cancelEmergency,
              icon: const Icon(Icons.cancel_rounded, color: Colors.white60, size: 18),
              label: const Text('Cancel',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Status Banner ──
              if (_statusMessage != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF0A2E0A)
                        : const Color(0xFF2E0A0A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isActive
                            ? const Color(0xFF2E7D32)
                            : brandRed.withOpacity(.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive
                            ? Icons.check_circle_rounded
                            : Icons.hourglass_top_rounded,
                        color: isActive
                            ? const Color(0xFF4CAF50)
                            : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_statusMessage!,
                            style: TextStyle(
                                color: isActive
                                    ? const Color(0xFF81C784)
                                    : Colors.orange.shade200,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              // ── Big SOS Button ──
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Transform.scale(
                    scale: (isActive || isRequesting) ? _pulseAnim.value : 1.0,
                    child: child,
                  ),
                  child: GestureDetector(
                    onTap: _status == EmergencyStatus.idle ? _triggerSOS : null,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: isActive
                              ? [const Color(0xFFFF6B6B), brandRed]
                              : isRequesting
                                  ? [Colors.orange.shade300, Colors.orange]
                                  : [const Color(0xFFFF4654), brandRed],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isActive ? brandRed : Colors.orange)
                                .withOpacity(.5),
                            blurRadius: isActive ? 50 : 30,
                            spreadRadius: isActive ? 15 : 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isActive
                                ? Icons.emergency_rounded
                                : isRequesting
                                    ? Icons.hourglass_top_rounded
                                    : Icons.sos_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isActive
                                ? 'ACTIVE'
                                : isRequesting
                                    ? 'SENDING…'
                                    : 'SOS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _status == EmergencyStatus.idle
                    ? 'Tap to record SOS and open dialer'
                    : _status == EmergencyStatus.requesting
                        ? 'Please wait…'
                        : 'SOS recorded locally — complete the call to 123',
                style: TextStyle(
                    color: Colors.white.withOpacity(.5),
                    fontSize: 13),
              ),

              const SizedBox(height: 32),

              // ── Location Card ──
              _DarkCard(
                icon: Icons.location_on_rounded,
                iconColor: const Color(0xFF4FC3F7),
                title: 'Your Location',
                child: _locationLoading
                    ? const Row(
                        children: [
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4FC3F7)),
                          ),
                          SizedBox(width: 10),
                          Text('Detecting GPS…',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      )
                    : _userLocation == null
                        ? Row(
                            children: [
                              const Icon(Icons.gps_off_rounded,
                                  color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              const Text('GPS not available',
                                  style: TextStyle(color: Colors.orange)),
                              const Spacer(),
                              GestureDetector(
                                onTap: _fetchLocation,
                                child: const Text('Retry',
                                    style: TextStyle(
                                        color: Color(0xFF4FC3F7),
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.circle,
                                      size: 8, color: Color(0xFF4CAF50)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _locationSummaryLabel,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5),
                                    ),
                                  ),
                                ],
                              ),
                              if (isActive) ...[
                                const SizedBox(height: 4),
                                const Row(
                                  children: [
                                    Icon(Icons.cell_tower_rounded,
                                        size: 12, color: Color(0xFF4CAF50)),
                                    SizedBox(width: 4),
                                    Text('Live GPS stream (local device)',
                                        style: TextStyle(
                                            color: Color(0xFF4CAF50),
                                            fontSize: 11)),
                                  ],
                                ),
                              ],
                            ],
                          ),
              ),

              const SizedBox(height: 12),

              // ── Nearest Responder Card ──
              _DarkCard(
                icon: Icons.medical_services_rounded,
                iconColor: const Color(0xFFFF8A65),
                title: 'Nearest Responder',
                child: _nearestResponder == null
                    ? const Text('Searching for responders…',
                        style: TextStyle(color: Colors.white54))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: brandRed.withOpacity(.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                    _nearestResponder!.responder.icon,
                                    color: brandRed, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_nearestResponder!.responder.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14)),
                                    Text(
                                        '${_nearestResponder!.responder.typeLabel} · '
                                        '${_nearestResponder!.responder.specialty}',
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D47A1).withOpacity(.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                    _nearestResponder!.distLabel,
                                    style: const TextStyle(
                                        color: Color(0xFF82B1FF),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                          if (_userLocation != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openDirections(
                                        _userLocation!,
                                        _nearestResponder!.responder.location),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF4FC3F7),
                                      side: const BorderSide(
                                          color: Color(0xFF4FC3F7)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.directions_rounded,
                                        size: 16),
                                    label: const Text('Directions',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LiveTrackingMapScreen(
                                          userLocation: _userLocation!,
                                          responder: _nearestResponder!,
                                        ),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A3A1A),
                                      foregroundColor:
                                          const Color(0xFF81C784),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(
                                        Icons.track_changes_rounded,
                                        size: 16),
                                    label: const Text('Track',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: 12),

              // ── Quick Actions ──
              Row(
                children: [
                  Expanded(
                    child: _QuickActionBtn(
                      icon: Icons.call_rounded,
                      label: 'Call 123',
                      color: const Color(0xFF2E7D32),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final opened = await _openDialer('123');
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text(opened
                              ? 'Dialer opened for 123 — complete the call yourself.'
                              : 'No dialer available — call 123 manually.')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionBtn(
                      icon: Icons.sms_rounded,
                      label: 'SMS SOS',
                      color: const Color(0xFF1565C0),
                      onTap: _userLocation != null
                          ? () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final opened = await _sendEmergencySMS(_userLocation!);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text(opened
                                    ? 'SMS composer opened — message was not auto-sent.'
                                    : 'No SMS app available. Location saved locally.')),
                              );
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionBtn(
                      icon: Icons.chat_rounded,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: _userLocation != null
                          ? () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final opened = await _sendEmergencyWhatsApp(_userLocation!);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text(opened
                                    ? 'WhatsApp composer opened — message was not auto-sent.'
                                    : 'WhatsApp could not be opened. Try again later.')),
                              );
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionBtn(
                      icon: Icons.map_rounded,
                      label: 'Live Map',
                      color: const Color(0xFF6A1B9A),
                      onTap: _userLocation != null && _nearestResponder != null
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LiveTrackingMapScreen(
                                    userLocation: _userLocation!,
                                    responder: _nearestResponder!,
                                  ),
                                ),
                              )
                          : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Emergency Numbers Reference ──
              _DarkCard(
                icon: Icons.phone_rounded,
                iconColor: const Color(0xFFFFD54F),
                title: 'Egypt Emergency Numbers',
                child: Column(
                  children: [
                    _EmerNumRow(number: '123', label: 'Ambulance (الإسعاف)'),
                    _EmerNumRow(number: '122', label: 'Police (النجدة)'),
                    _EmerNumRow(number: '180', label: 'Fire Department (المطافئ)'),
                    _EmerNumRow(number: '137', label: 'Emergency Health & ICU (طوارئ الصحة)'),
                    _EmerNumRow(number: '16021', label: 'Poison Control Center (مركز السموم)'),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ── Disclaimer ──
              Text(
                '⚠️ This app assists during emergencies.\n'
                'Always call 123 for life-threatening situations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(.35),
                    fontSize: 11,
                    height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dark Card widget ──────────────────────────────────────────
class _DarkCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final Widget   child;

  const _DarkCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .5)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Quick Action button ───────────────────────────────────────
class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback? onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Emergency Number Row ──────────────────────────────────────
class _EmerNumRow extends StatelessWidget {
  final String number;
  final String label;

  const _EmerNumRow({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          GestureDetector(
            onTap: () => _openDialer(number),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2B1B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2E7D32)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.call_rounded,
                      size: 14, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 5),
                  Text(number,
                      style: const TextStyle(
                          color: Color(0xFF81C784),
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LIVE TRACKING MAP SCREEN  ← Mobile Emergency Module
// ============================================================

class LiveTrackingMapScreen extends StatefulWidget {
  final LatLng         userLocation;
  final _RespWithDist  responder;

  const LiveTrackingMapScreen({
    super.key,
    required this.userLocation,
    required this.responder,
  });

  @override
  State<LiveTrackingMapScreen> createState() => _LiveTrackingMapScreenState();
}

class _LiveTrackingMapScreenState extends State<LiveTrackingMapScreen> {
  static const Color brandRed = Color(0xFFE92335);

  final fmap.MapController _fmapCtrl = fmap.MapController();
  LatLng?              _liveLocation;
  // The existing badge is kept exactly as-is; its state now reflects a real
  // live stream instead of being permanently true.
  bool get _tracking =>
      LiveLocationService.lastSource == LocationSource.liveGps &&
      LiveLocationService.streamHealthy;
  int?                 _trackingClientId;
  final TileLoadState  _tileLoadState = TileLoadState();

  @override
  void initState() {
    super.initState();
    _liveLocation = widget.userLocation;
    // Join the shared GPS stream as this screen's own client.
    _trackingClientId = LiveLocationService.startTracking(onUpdate: (loc) {
      if (mounted) {
        setState(() => _liveLocation = loc);
        try {
          _fmapCtrl.move(toLl(loc), 15.0);
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    // Stop only this screen's client — never the shared stream used by others.
    if (_trackingClientId != null) {
      LiveLocationService.stopTracking(_trackingClientId);
      _trackingClientId = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Recalculate live distance
    final liveDist = _liveLocation != null
        ? _RespWithDist(
            widget.responder.responder,
            _haversineKm(_liveLocation!, widget.responder.responder.location),
          )
        : widget.responder;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Live Tracking',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          // Location area label
          if (_liveLocation != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Approx. ${getAreaName(_liveLocation!)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Get directions',
            icon: const Icon(Icons.directions_rounded, color: brandRed),
            onPressed: () => _liveLocation != null
                ? _openDirections(
                    _liveLocation!, widget.responder.responder.location)
                : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Full Map ──
          if (_liveLocation != null)
            fmap.FlutterMap(
              mapController: _fmapCtrl,
              options: fmap.MapOptions(
                initialCenter: toLl(_liveLocation!),
                initialZoom: 14.5,
              ),
              children: [
                _osmTileLayer(
                  onTileError: () {
                    if (mounted && !_tileLoadState.failed) {
                      setState(() => _tileLoadState.markFailed());
                    }
                  },
                  onTileLoaded: () {
                    if (mounted && _tileLoadState.failed) {
                      setState(() => _tileLoadState.markRecovered());
                    }
                  },
                ),
                fmap.PolylineLayer(
                  polylines: [
                    fmap.Polyline(
                      points: [toLl(_liveLocation!), toLl(widget.responder.responder.location)],
                      color: brandRed,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
                fmap.MarkerLayer(
                  markers: [
                    fmap.Marker(
                      point: toLl(_liveLocation!),
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.25),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2196F3),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 14),
                          ),
                        ],
                      ),
                    ),
                    fmap.Marker(
                      point: toLl(widget.responder.responder.location),
                      width: 46,
                      height: 46,
                      child: Container(
                        decoration: BoxDecoration(
                          color: brandRed,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
                        ),
                        child: Icon(widget.responder.responder.icon, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            const Center(
              child: CircularProgressIndicator(color: brandRed),
            ),

          // ── Live indicator badge ──
          if (_tracking)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF4CAF50), width: 1.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle,
                        size: 8, color: Color(0xFF4CAF50)),
                    SizedBox(width: 6),
                    Text('LIVE',
                        style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5)),
                  ],
                ),
              ),
            ),

          // ── Bottom responder panel ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(.4),
                      blurRadius: 20,
                      offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: brandRed.withOpacity(.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(widget.responder.responder.icon,
                            color: brandRed, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.responder.responder.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            Text(
                                '${widget.responder.responder.typeLabel} · '
                                '${widget.responder.responder.specialty}',
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(liveDist.distLabel,
                              style: const TextStyle(
                                  color: Color(0xFF82B1FF),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18)),
                          const Text('away',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openDialer(widget.responder.responder.phone),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4CAF50),
                            side: const BorderSide(
                                color: Color(0xFF2E7D32)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call Responder',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _liveLocation != null
                              ? () => _openDirections(_liveLocation!,
                                  widget.responder.responder.location)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.directions_rounded, size: 18),
                          label: const Text('Get Directions',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FIRST AID SCREEN
// ============================================================

class FirstAidScreen
    extends StatelessWidget {
  const FirstAidScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFFFF9FA),

      appBar: AppBar(
        title: const Text(
          'First Aid',

          style: TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        backgroundColor:
        Colors.white,

        foregroundColor:
        const Color(0xFF172027),

        elevation: 0,
      ),

      body: ListView(
        padding:
        const EdgeInsets.all(20),

        children: [
          const Text(
            'Emergency First Aid Guides',

            style: TextStyle(
              fontSize: 22,

              fontWeight:
              FontWeight.bold,

              color:
              Color(0xFF172027),
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            'Choose an emergency situation to see basic first aid guidance.',

            style: TextStyle(
              color:
              Color(0xFF777E82),
            ),
          ),

          const SizedBox(
            height: 25,
          ),

          FirstAidCard(
            icon:
            Icons.bloodtype,

            title:
            'Severe Bleeding',

            subtitle:
            'Basic steps to control bleeding.',
          ),

          FirstAidCard(
            icon:
            Icons.air,

            title:
            'Breathing Problems',

            subtitle:
            'What to do when someone has difficulty breathing.',
          ),

          FirstAidCard(
            icon:
            Icons.local_fire_department,

            title:
            'Burns',

            subtitle:
            'Basic first aid for minor burns.',
          ),

          FirstAidCard(
            icon:
            Icons.accessibility_new,

            title:
            'Unconscious Person',

            subtitle:
            'Immediate steps while waiting for help.',
          ),

          FirstAidCard(
            icon:
            Icons.favorite,

            title:
            'CPR',

            subtitle:
            'Basic CPR emergency guidance.',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FIRST AID CARD
// ============================================================

class FirstAidCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const FirstAidCard({
    super.key,

    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),

      color:
      Colors.white,

      elevation: 1,

      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(
          18,
        ),
      ),

      child: ListTile(
        contentPadding:
        const EdgeInsets.all(
          12,
        ),

        leading: Container(
          width: 48,
          height: 48,

          decoration:
          BoxDecoration(
            color:
            const Color(
              0xFFFFE9EC,
            ),

            borderRadius:
            BorderRadius.circular(
              14,
            ),
          ),

          child: Icon(
            icon,

            color:
            const Color(
              0xFFE92335,
            ),
          ),
        ),

        title: Text(
          title,

          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        subtitle:
        Text(subtitle),

        trailing:
        const Icon(
          Icons.arrow_forward_ios,

          size: 16,

          color:
          Color(0xFFE92335),
        ),

        onTap: () {
          showDialog(
            context: context,

            builder: (_) {
              return AlertDialog(
                title:
                Text(title),

                content:
                const Text(
                  'This section will provide detailed first aid instructions in the next development stage.',
                ),

                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },

                    child:
                    const Text(
                      'OK',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// NEARBY HELP
// ============================================================

// ============================================================
// NEARBY HELP SCREEN  – shows sorted list + opens map screen
// ============================================================

class NearbyHelpScreen extends StatefulWidget {
  const NearbyHelpScreen({super.key});

  @override
  State<NearbyHelpScreen> createState() => _NearbyHelpScreenState();
}

class _NearbyHelpScreenState extends State<NearbyHelpScreen> {
  static const Color brandRed = Color(0xFFE92335);

  LatLng? _userLocation;
  bool _loading = true;
  List<_RespWithDist> _sorted = [];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    // Use custom-selected location if available
    if (LiveLocationService.customSelectedPosition != null) {
      final loc = LiveLocationService.customSelectedPosition!;
      if (mounted) {
        setState(() {
          _userLocation = loc;
          _sorted = _sortedByDistance(loc);
          _loading = false;
        });
      }
      return;
    }
    final loc = await LiveLocationService.getCurrentPosition();
    if (loc != null && mounted) {
      setState(() {
        _userLocation = loc;
        _sorted = _sortedByDistance(loc);
        _loading = false;
      });
    } else {
      _fallback();
    }
  }

  // If GPS fails → show message, don't fake location
  void _fallback() {
    if (mounted) {
      setState(() {
        _userLocation = null;
        _sorted = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS unavailable — please enable location services or select a location manually.'),
          backgroundColor: Color(0xFFE92335),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final areaName = _userLocation != null
        ? 'Approx. ${getAreaName(_userLocation!)}'
        : 'Your Location';
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9FA),
      appBar: AppBar(
        title: const Text('Nearby Help',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172027),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Change Location',
            icon: const Icon(Icons.edit_location_alt_rounded, color: brandRed),
            onPressed: () => showLocationOptions(
              context,
              onUseCurrentLocation: () {
                setState(() => _loading = true);
                _loadLocation();
              },
              onLocationSelected: (loc, label) {
                setState(() {
                  _userLocation = loc;
                  _sorted = _sortedByDistance(loc);
                  _loading = false;
                });
              },
            ),
          ),
          if (_userLocation != null)
            IconButton(
              tooltip: 'View on map',
              icon: const Icon(Icons.map_rounded, color: brandRed),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NearbyResponderMapScreen(
                    userLocation: _userLocation!,
                    responders: _sorted,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: brandRed),
                  const SizedBox(height: 16),
                  Text('Finding responders near $areaName…',
                      style: const TextStyle(color: Color(0xFF777E82))),
                ],
              ))
          : Column(
              children: [
                // ── header banner ──
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: brandRed.withOpacity(.08),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: brandRed.withOpacity(.18), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: brandRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_sorted.length} responders near $areaName',
                          style: const TextStyle(
                              fontSize: 12,
                              color: brandRed,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NearbyResponderMapScreen(
                              userLocation: _userLocation!,
                              responders: _sorted,
                            ),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: brandRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Map View',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── sorted list ──
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: _sorted.length,
                    itemBuilder: (ctx, i) {
                      final item = _sorted[i];
                      final isNearest = i == 0;
                      return _ResponderCard(
                        item: item,
                        isNearest: isNearest,
                        userLocation: _userLocation!,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Single Responder Card ─────────────────────────────────────
class _ResponderCard extends StatelessWidget {
  final _RespWithDist item;
  final bool isNearest;
  final LatLng userLocation;

  const _ResponderCard({
    required this.item,
    required this.isNearest,
    required this.userLocation,
  });

  static const Color brandRed = Color(0xFFE92335);

  @override
  Widget build(BuildContext context) {
    final r = item.responder;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isNearest
            ? Border.all(color: brandRed, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isNearest
                    ? brandRed
                    : const Color(0xFFFFE9EC),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(r.icon,
                  color: isNearest ? Colors.white : brandRed, size: 26),
            ),
            const SizedBox(width: 12),
            // info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(r.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF172027))),
                      ),
                      if (isNearest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: brandRed,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Nearest',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('${r.typeLabel} · ${r.specialty}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF777E82))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 13, color: Color(0xFF777E82)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(r.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF777E82))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // distance chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.straighten_rounded,
                                size: 13, color: Color(0xFF3D5AFE)),
                            const SizedBox(width: 4),
                            Text(item.distLabel,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3D5AFE))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Directions button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openDirections(
                              userLocation, r.location),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.directions_rounded,
                              size: 16),
                          label: const Text('Directions',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // call button
                      InkWell(
                        onTap: () => _openDialer(r.phone),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.call_rounded,
                              size: 18, color: Color(0xFF2E7D32)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NEARBY RESPONDER MAP SCREEN
// – shows user + all responders on map, nearest auto-selected
// ============================================================

class NearbyResponderMapScreen extends StatefulWidget {
  final LatLng userLocation;
  final List<_RespWithDist> responders;

  const NearbyResponderMapScreen({
    super.key,
    required this.userLocation,
    required this.responders,
  });

  @override
  State<NearbyResponderMapScreen> createState() =>
      _NearbyResponderMapScreenState();
}

class _NearbyResponderMapScreenState
    extends State<NearbyResponderMapScreen> {
  static const Color brandRed = Color(0xFFE92335);

  final fmap.MapController _fmapCtrl = fmap.MapController();
  final TileLoadState _tileLoadState = TileLoadState();
  _RespWithDist? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.responders.isNotEmpty) {
      _selected = widget.responders.first; // nearest by default
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearest = widget.responders.isNotEmpty ? widget.responders.first : null;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9FA),
      appBar: AppBar(
        title: const Text('Nearest Responders',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172027),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ── Full Map ──
          fmap.FlutterMap(
            mapController: _fmapCtrl,
            options: fmap.MapOptions(
              initialCenter: toLl(widget.userLocation),
              initialZoom: 14.5,
            ),
            children: [
              _osmTileLayer(
                onTileError: () {
                  if (mounted && !_tileLoadState.failed) {
                    setState(() => _tileLoadState.markFailed());
                  }
                },
                onTileLoaded: () {
                  if (mounted && _tileLoadState.failed) {
                    setState(() => _tileLoadState.markRecovered());
                  }
                },
              ),
              if (_selected != null)
                fmap.PolylineLayer(
                  polylines: [
                    fmap.Polyline(
                      points: [toLl(widget.userLocation), toLl(_selected!.responder.location)],
                      color: brandRed,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              fmap.MarkerLayer(
                markers: [
                  // User marker
                  fmap.Marker(
                    point: toLl(widget.userLocation),
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withOpacity(0.25),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2196F3),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 14),
                        ),
                      ],
                    ),
                  ),
                  // Responder markers
                  ...widget.responders.map((item) {
                    final isSelected = _selected?.responder.id == item.responder.id;
                    return fmap.Marker(
                      point: toLl(item.responder.location),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selected = item);
                          _fmapCtrl.move(toLl(item.responder.location), 15.0);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? brandRed : const Color(0xFFFF9800),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
                          ),
                          child: Icon(item.responder.icon, color: Colors.white, size: 20),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // ── Legend ──
          Positioned(
            top: 12,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendChip(BitmapDescriptor.hueAzure,
                    Colors.blue, 'You'),
                const SizedBox(height: 6),
                _legendChip(BitmapDescriptor.hueRed,
                    brandRed, 'Selected'),
                const SizedBox(height: 6),
                _legendChip(BitmapDescriptor.hueOrange,
                    Colors.orange, 'Others'),
              ],
            ),
          ),

          // ── Bottom Panel – selected responder ──
          if (_selected != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, -4)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_selected == nearest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: brandRed.withOpacity(.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: brandRed.withOpacity(.3), width: 1),
                        ),
                        child: const Text('⭐ Nearest Responder',
                            style: TextStyle(
                                color: brandRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: brandRed,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(_selected!.responder.icon,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_selected!.responder.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Color(0xFF172027))),
                              const SizedBox(height: 2),
                              Text(
                                '${_selected!.responder.typeLabel} · '
                                '${_selected!.responder.specialty}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF777E82)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_selected!.distLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF3D5AFE))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            size: 14, color: Color(0xFF777E82)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(_selected!.responder.address,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF777E82))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Call button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _openDialer(_selected!.responder.phone),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2E7D32),
                              side: const BorderSide(
                                  color: Color(0xFF2E7D32)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.call_rounded, size: 18),
                            label: const Text('Call',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Directions button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => _openDirections(
                                widget.userLocation,
                                _selected!.responder.location),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandRed,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            icon: const Icon(
                                Icons.directions_rounded,
                                size: 20),
                            label: const Text(
                              'Get Directions',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // responder selector chips
                    if (widget.responders.length > 1) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.responders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            final item = widget.responders[i];
                            final isChosen =
                                _selected?.responder.id ==
                                    item.responder.id;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selected = item);
                                try {
                                  _fmapCtrl.move(toLl(item.responder.location), 15.0);
                                } catch (_) {}
                              },
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isChosen
                                      ? brandRed
                                      : const Color(0xFFF2F2F2),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item.responder.name.split(' ').first,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isChosen
                                        ? Colors.white
                                        : const Color(0xFF444444),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendChip(double hue, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 6)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10, height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// HelperCard kept for any legacy reference – not used in NearbyHelpScreen anymore
class HelperCard extends StatelessWidget {
  final String name;
  final String role;
  final String distance;
  final IconData icon;

  const HelperCard({
    super.key,
    required this.name,
    required this.role,
    required this.distance,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFFFFE9EC),
          child: Icon(icon, color: const Color(0xFFE92335)),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$role • $distance'),
        trailing: ElevatedButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Request sent to $name'))),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE92335),
            foregroundColor: Colors.white,
          ),
          child: const Text('Help'),
        ),
      ),
    );
  }
}

// ============================================================
// MAP SCREEN
// ============================================================

class MapScreen extends StatefulWidget {
  final ll.LatLng? initialLocation;
  const MapScreen({super.key, this.initialLocation});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final fmap.MapController _mapController = fmap.MapController();
  final TileLoadState _tileLoadState = TileLoadState();
  bool _loadingLocation = false;
  ll.LatLng? _currentPosition;
  String _addressLabel = 'Resolving address…';
  String _metadata = '';

  @override
  void initState() {
    super.initState();
    // Respect custom selected position first
    if (LiveLocationService.customSelectedPosition != null) {
      _currentPosition = ll.LatLng(
        LiveLocationService.customSelectedPosition!.latitude,
        LiveLocationService.customSelectedPosition!.longitude,
      );
    } else if (widget.initialLocation != null) {
      _currentPosition = widget.initialLocation;
    }
    _useCurrentLocation();
  }

  /// One-shot refresh used by both the initial load and the Recenter FAB.
  Future<void> _useCurrentLocation() async {
    if (_loadingLocation) return;
    setState(() => _loadingLocation = true);
    try {
      final result = await LiveLocationService.getCurrentPositionWithSource();
      if (result != null && mounted) {
        LiveLocationService.lastSource = result.source;
        LiveLocationService.lastAccuracyMeters = result.accuracyMeters;
        LiveLocationService.lastUpdateTime = result.timestamp;
        final current = ll.LatLng(
          result.position.latitude,
          result.position.longitude,
        );
        setState(() {
          _currentPosition = current;
          _metadata = result.sourceLabel +
              (result.accuracyMeters != null
                  ? ' · ±${result.accuracyMeters!.round()}m'
                  : '');
        });
        try {
          _mapController.move(current, 15.0);
        } catch (_) {}
        final info = await lookupAddress(result.position);
        if (mounted) {
          setState(() => _addressLabel = info.displayFor(result.position));
        }
      } else if (mounted) {
        setState(() {
          _metadata = 'NO LOCATION — enable GPS / grant permission';
          _addressLabel = 'Address unavailable';
        });
        if (LiveLocationService.customSelectedPosition == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No real device location available. Map not moved.'),
              backgroundColor: Color(0xFFE92335),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _showResponderDetails(Responder r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE9EC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(r.icon, color: const Color(0xFFE92335), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text('${r.typeLabel} · ${r.specialty}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(child: Text(r.address, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE92335),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.phone_rounded, size: 18),
                      label: const Text('Call Now', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _openDialer(r.phone),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE92335),
                        side: const BorderSide(color: Color(0xFFE92335)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: const Text('Directions', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        try {
                          final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${r.location.latitude},${r.location.longitude}');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        } catch (_) {
                          // Launcher unavailable: leave the current screen intact.
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Never render a map centred on hardcoded coordinates.
    final hasLocation = _currentPosition != null;
    final responders = hasLocation
        ? _getRespondersForLocation(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude))
        : <Responder>[];
    final areaLabel =
        hasLocation ? _addressLabel : 'Waiting for real device location…';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9FA),
      appBar: AppBar(
        title: const Text('Live Emergency Map', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172027),
        elevation: 0,
        actions: [
          // Change location button
          IconButton(
            tooltip: 'Change Location',
            icon: const Icon(Icons.edit_location_alt_rounded, color: Color(0xFFE92335)),
            onPressed: () => showLocationOptions(
              context,
              onUseCurrentLocation: _useCurrentLocation,
              onLocationSelected: (loc, label) {
                LiveLocationService.setCustomLocation(loc, label: label);
                final llLoc = ll.LatLng(loc.latitude, loc.longitude);
                setState(() {
                  _currentPosition = llLoc;
                  _addressLabel = label;
                  _metadata = 'MANUAL SELECTION (not live GPS)';
                });
                try { _mapController.move(llLoc, 15.0); } catch (_) {}
              },
            ),
          ),
          IconButton(
            tooltip: 'Map Legend',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Map Legend',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      // Phase 5: clearly label simulated responders
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '⚠️ All responders are simulated demo data (backend not connected yet)',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LegendRow(color: const Color(0xFFE53935), label: 'Doctor'),
                      _LegendRow(color: const Color(0xFF1E88E5), label: 'Nurse'),
                      _LegendRow(color: const Color(0xFFFB8C00), label: 'Paramedic'),
                      _LegendRow(color: const Color(0xFF43A047), label: 'Volunteer'),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!hasLocation)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_off_rounded,
                        size: 64, color: Color(0xFFB0B6BA)),
                    const SizedBox(height: 16),
                    const Text(
                      'No real location yet.\nEnable GPS or grant permission to show the map.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF777E82), fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _useCurrentLocation,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE92335),
                          foregroundColor: Colors.white),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh location'),
                    ),
                  ],
                ),
              ),
            )
          else
            fmap.FlutterMap(
            mapController: _mapController,
            options: fmap.MapOptions(
              initialCenter: _currentPosition!,
              initialZoom: 14.5,
            ),
            children: [
              _osmTileLayer(
                onTileError: () {
                  if (mounted && !_tileLoadState.failed) {
                    setState(() => _tileLoadState.markFailed());
                  }
                },
                onTileLoaded: () {
                  if (mounted && _tileLoadState.failed) {
                    setState(() => _tileLoadState.markRecovered());
                  }
                },
              ),
              fmap.MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    fmap.Marker(
                      point: _currentPosition!,
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.25),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2196F3),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ...responders.map((r) {
                    Color markerColor;
                    switch (r.type) {
                      case ResponderType.doctor: markerColor = const Color(0xFFE53935); break;
                      case ResponderType.nurse: markerColor = const Color(0xFF1E88E5); break;
                      case ResponderType.paramedic: markerColor = const Color(0xFFFB8C00); break;
                      case ResponderType.volunteer: markerColor = const Color(0xFF43A047); break;
                    }
                    return fmap.Marker(
                      point: toLl(r.location),
                      width: 54,
                      height: 62, // Phase 5: extra height for Demo badge
                      child: GestureDetector(
                        onTap: () => _showResponderDetails(r),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Phase 5: Demo badge — clearly marks simulated responders
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Demo',
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: markerColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
                              ),
                              child: Icon(r.icon, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          // GPS location chip (top-left) — address, coordinates, source and accuracy
          Positioned(
            left: 16,
            top: 16,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFFE92335), size: 19),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _loadingLocation ? 'Detecting...' : areaLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800,
                                color: Color(0xFF202329), fontSize: 12),
                          ),
                          if (_currentPosition != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${_currentPosition!.latitude.toStringAsFixed(4)}, '
                              '${_currentPosition!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                  color: Color(0xFF777E82), fontSize: 10),
                            ),
                          ],
                          if (_metadata.isNotEmpty)
                            Text(_metadata,
                                style: const TextStyle(
                                    color: Color(0xFF20B66B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_tileLoadState.failed)
            Positioned(
              left: 16,
              top: 130,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Map tiles unavailable offline — GPS still active',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          if (hasLocation)
            const Positioned(
              left: 8,
              bottom: 8,
              child: Text('© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 9, color: Color(0xFF777E82))),
            ),
          // Current location FAB — recenters on the latest real GPS fix
          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'currentLocationButton',
              tooltip: 'Recenter on live location',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFE92335),
              onPressed: _useCurrentLocation,
              child: _loadingLocation
                  ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE92335)))
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Legend row widget ─────────────────────────────────────────
class _LegendRow extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

// ============================================================
// FIND NEAREST SCREEN  — الشاشة الرئيسية للبحث عن أقرب مستجيب
// ============================================================

class FindNearestScreen extends StatefulWidget {
  const FindNearestScreen({super.key});

  @override
  State<FindNearestScreen> createState() => _FindNearestScreenState();
}

class _FindNearestScreenState extends State<FindNearestScreen>
    with TickerProviderStateMixin {
  static const Color brandRed = Color(0xFFE92335);
  static const Color darkBg   = Color(0xFF0D0D0D);
  static const Color cardBg   = Color(0xFF1A1A1A);

  // State
  LatLng?          _userLoc;
  _RespWithDist?   _nearest;
  bool             _loading = false;
  String?          _error;
  ResponderType?   _filterType;  // null = all types

  final fmap.MapController _fmapCtrl = fmap.MapController();
  final TileLoadState _tileLoadState = TileLoadState();
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // Filter tabs
  static const _filterOptions = [
    (label: 'All',        icon: Icons.people_rounded,          type: null),
    (label: 'Doctor',     icon: Icons.medical_services_rounded, type: ResponderType.doctor),
    (label: 'Nurse',      icon: Icons.health_and_safety_rounded, type: ResponderType.nurse),
    (label: 'Paramedic',  icon: Icons.emergency_rounded,        type: ResponderType.paramedic),
    (label: 'Volunteer',  icon: Icons.volunteer_activism_rounded, type: ResponderType.volunteer),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _detectAndFind();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectAndFind() async {
    setState(() { _loading = true; _error = null; });
    final loc = await LiveLocationService.getCurrentPosition();
    if (!mounted) return;
    if (loc != null) {
      _userLoc = loc;
    } else {
      // No GPS available — don't fake a location
      setState(() {
        _loading = false;
        _error = 'GPS unavailable. Please enable location services\nor select a location manually.';
      });
      return;
    }
    _findNearest();
  }

  void _findNearest() {
    if (_userLoc == null) return;
    final found = _nearestOfType(_userLoc!, type: _filterType);
    setState(() {
      _nearest  = found;
      _loading  = false;
    });
    // Animate map to show user and responder
    if (found != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_userLoc != null) {
          final centerLat = (_userLoc!.latitude + found.responder.location.latitude) / 2;
          final centerLng = (_userLoc!.longitude + found.responder.location.longitude) / 2;
          try {
            _fmapCtrl.move(ll.LatLng(centerLat, centerLng), 14.8);
          } catch (_) {}
        }
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Find Nearest Help',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Change Location',
            icon: const Icon(Icons.edit_location_alt_rounded, color: brandRed),
            onPressed: () => showLocationOptions(
              context,
              onUseCurrentLocation: _detectAndFind,
              onLocationSelected: (loc, label) {
                setState(() { _userLoc = loc; });
                _findNearest();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📍 Location set to $label'),
                    backgroundColor: Colors.green.shade700,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Refresh location',
            icon: const Icon(Icons.my_location_rounded, color: brandRed),
            onPressed: _detectAndFind,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ──────────────────────────────────
          Container(
            color: cardBg,
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _filterOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final opt = _filterOptions[i];
                final selected = _filterType == opt.type;
                return GestureDetector(
                  onTap: () {
                    setState(() => _filterType = opt.type);
                    _findNearest();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? brandRed : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? brandRed : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(opt.icon, size: 14,
                            color: selected ? Colors.white : Colors.white54),
                        const SizedBox(width: 6),
                        Text(opt.label,
                            style: TextStyle(
                                color: selected ? Colors.white : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Location Info Banner ──────────────────────────
          if (_userLoc != null)
            Container(
              color: const Color(0xFF141414),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFE92335), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${LiveLocationService.lastSourceLabel} · approx. ${getAreaName(_userLoc!)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${_userLoc!.latitude.toStringAsFixed(3)}, ${_userLoc!.longitude.toStringAsFixed(3)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),

          // ── Map ───────────────────────────────────────────
          Expanded(
            flex: 3,
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: brandRed.withOpacity(.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.my_location_rounded,
                                color: brandRed, size: 36),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Detecting your location…',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_off_rounded,
                                  color: Colors.white30, size: 64),
                              const SizedBox(height: 16),
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _detectAndFind,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: brandRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16))),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try Again',
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _userLoc == null
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No real device location available. Map is hidden instead of showing a fake location.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                          )
                        : fmap.FlutterMap(
                        mapController: _fmapCtrl,
                        options: fmap.MapOptions(
                          initialCenter: toLl(_userLoc!),
                          initialZoom: 14.5,
                        ),
                        children: [
                          _osmTileLayer(
                            onTileError: () {
                              if (mounted && !_tileLoadState.failed) {
                                setState(() => _tileLoadState.markFailed());
                              }
                            },
                            onTileLoaded: () {
                              if (mounted && _tileLoadState.failed) {
                                setState(() => _tileLoadState.markRecovered());
                              }
                            },
                          ),
                          if (_userLoc != null && _nearest != null)
                            fmap.PolylineLayer(
                              polylines: [
                                fmap.Polyline(
                                  points: [toLl(_userLoc!), toLl(_nearest!.responder.location)],
                                  color: brandRed,
                                  strokeWidth: 4.5,
                                ),
                              ],
                            ),
                          fmap.MarkerLayer(
                            markers: [
                              if (_userLoc != null)
                                fmap.Marker(
                                  point: toLl(_userLoc!),
                                  width: 48,
                                  height: 48,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2196F3).withOpacity(0.25),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2196F3),
                                          shape: BoxShape.circle,
                                          boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4)],
                                        ),
                                        child: const Icon(Icons.person, color: Colors.white, size: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_nearest != null)
                                fmap.Marker(
                                  point: toLl(_nearest!.responder.location),
                                  width: 46,
                                  height: 46,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: brandRed,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                                    ),
                                    child: Icon(_nearest!.responder.icon, color: Colors.white, size: 22),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
          ),

          // ── Bottom Panel ──────────────────────────────────
          if (!_loading && _error == null)
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.5),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: _nearest == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No responders found for this filter.',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Responder info row ──
                        Row(
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: brandRed.withOpacity(.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(_nearest!.responder.icon,
                                  color: brandRed, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_nearest!.responder.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15)),
                                  Text(
                                    '${_nearest!.responder.typeLabel} · ${_nearest!.responder.specialty}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_nearest!.responder.address,
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 10.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── Distance + ETA chips ──
                        Row(
                          children: [
                            _InfoChip(
                              icon: Icons.straighten_rounded,
                              label: _nearest!.distLabel,
                              color: const Color(0xFF82B1FF),
                            ),
                            const SizedBox(width: 10),
                            _InfoChip(
                              icon: Icons.timer_rounded,
                              label: 'ETA ${_estimatedETA(_nearest!.distKm)}',
                              color: const Color(0xFFA5D6A7),
                            ),
                            const Spacer(),
                            // Out-of-area badge
                            if (_nearest!.distKm > 15)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFA726).withOpacity(.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFFFA726).withOpacity(.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_rounded,
                                        size: 12, color: Color(0xFFFFA726)),
                                    SizedBox(width: 4),
                                    Text('Nearest Available',
                                        style: TextStyle(
                                            color: Color(0xFFFFA726),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Action buttons ──
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _openDialer(_nearest!.responder.phone),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF4CAF50),
                                  side: const BorderSide(
                                      color: Color(0xFF2E7D32)),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.call_rounded, size: 18),
                                label: const Text('Call Now',
                                    style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _userLoc != null
                                    ? () => _openDirections(
                                        _userLoc!,
                                        _nearest!.responder.location)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brandRed,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.directions_rounded, size: 18),
                                label: const Text('Directions',
                                    style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

// ── Small info chip ──────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
        ],
      ),
    );
  }
}

// ============================================================
// HISTORY
// ============================================================

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Color brandRed   = Color(0xFFE92335);
  static const Color pageBg     = Color(0xFFFFF9FA);
  static const Color darkText   = Color(0xFF202329);
  static const Color mutedText  = Color(0xFF777E82);

  final TileLoadState _historyTiles = TileLoadState();

  void _markHistoryTilesFailed() {
    if (mounted && !_historyTiles.failed) {
      setState(() => _historyTiles.markFailed());
    }
  }

  void _markHistoryTilesRecovered() {
    if (mounted && _historyTiles.failed) {
      setState(() => _historyTiles.markRecovered());
    }
  }

  // Format DateTime to readable string
  String _formatDate(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final hour   = dt.hour.toString().padLeft(2,'0');
    final minute = dt.minute.toString().padLeft(2,'0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  •  $hour:$minute';
  }

  String _duration(DateTime start) {
    final diff = DateTime.now().difference(start);
    if (diff.inDays > 0)   return '${diff.inDays}d ago';
    if (diff.inHours > 0)  return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Color _statusColor(EmergencyStatus s) {
    switch (s) {
      case EmergencyStatus.resolved:   return const Color(0xFF4CAF50);
      case EmergencyStatus.active:     return brandRed;
      case EmergencyStatus.requesting: return const Color(0xFFFFA726);
      case EmergencyStatus.idle:       return mutedText;
    }
  }

  String _statusLabel(EmergencyStatus s) {
    switch (s) {
      case EmergencyStatus.resolved:   return 'Resolved';
      case EmergencyStatus.active:     return 'Active';
      case EmergencyStatus.requesting: return 'Requesting';
      case EmergencyStatus.idle:       return 'Idle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = _emergencyHistory;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Emergency History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: darkText,
        elevation: 0,
        actions: [
          if (history.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear History'),
                    content: const Text('Are you sure you want to delete all emergency history?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: brandRed,
                            foregroundColor: Colors.white),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          _emergencyHistory.clear();
                          // Also clear the active-session identity on disk.
                          _activeSession = null;
                          await _persistHistory();
                          if (mounted) setState(() {});
                          navigator.pop();
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: Color(0xFFE92335)),
              label: const Text('Clear',
                  style: TextStyle(color: Color(0xFFE92335), fontSize: 13)),
            ),
        ],
      ),
      body: history.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final session = history[index];
                return _buildHistoryCard(session, index);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9EC),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: brandRed.withOpacity(.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.history_rounded,
                size: 50, color: brandRed),
          ),
          const SizedBox(height: 24),
          const Text('No Emergency History',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202329))),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Your emergency activities will appear here after your first SOS.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF777E82), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(EmergencySession session, int index) {
    final responder = session.assignedResponder;
    final statusColor = _statusColor(session.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
            Row(
              children: [
                // Index circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: brandRed.withOpacity(.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${_emergencyHistory.length - index}',
                      style: const TextStyle(
                          color: brandRed,
                          fontWeight: FontWeight.w900,
                          fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Emergency Request',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF202329))),
                      const SizedBox(height: 2),
                      Text(_formatDate(session.startTime),
                          style: const TextStyle(
                              color: Color(0xFF777E82),
                              fontSize: 11.5)),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: statusColor),
                      const SizedBox(width: 5),
                      Text(_statusLabel(session.status),
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // ── Location row ──
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: brandRed, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lat: ${session.location.latitude.toStringAsFixed(4)}, '
                    'Lng: ${session.location.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                        color: Color(0xFF555E63),
                        fontSize: 12),
                  ),
                ),
                Text(_duration(session.startTime),
                    style: const TextStyle(
                        color: Color(0xFF777E82),
                        fontSize: 11)),
              ],
            ),

            // ── Responder row (if assigned) ──
            if (responder != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(responder.responder.icon,
                        color: brandRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(responder.responder.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Color(0xFF202329))),
                          Text(
                            '${responder.responder.typeLabel} · '
                            '${responder.responder.specialty}',
                            style: const TextStyle(
                                color: Color(0xFF777E82),
                                fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(responder.distLabel,
                            style: const TextStyle(
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                        const Text('away',
                            style: TextStyle(
                                color: Color(0xFF777E82),
                                fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Action buttons ──
            Row(
              children: [
                // View on map
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _HistoryMapView(
                            session: session,
                            onTileError: _markHistoryTilesFailed,
                            onTileLoaded: _markHistoryTilesRecovered,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: brandRed,
                      side: BorderSide(color: brandRed.withOpacity(.4)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 15),
                    label: const Text('View on Map',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
                if (responder != null) ...[
                  const SizedBox(width: 8),
                  // Call responder
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _openDialer(responder.responder.phone),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.call_rounded, size: 15),
                      label: const Text('Call Again',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Map View ─────────────────────────────────────────
class _HistoryMapView extends StatelessWidget {
  final EmergencySession session;
  final VoidCallback? onTileError;
  final VoidCallback? onTileLoaded;

  const _HistoryMapView({
    required this.session,
    this.onTileError,
    this.onTileLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('sos_location'),
        position: session.location,
        infoWindow: const InfoWindow(
          title: '🚨 Emergency Location',
          snippet: 'SOS location recorded on this device',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    if (session.assignedResponder != null) {
      markers.add(Marker(
        markerId: MarkerId(session.assignedResponder!.responder.id),
        position: session.assignedResponder!.responder.location,
        infoWindow: InfoWindow(
          title: session.assignedResponder!.responder.name,
          snippet: session.assignedResponder!.responder.typeLabel,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen),
      ));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
        title: const Text('Emergency Location',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 0,
      ),
      body: fmap.FlutterMap(
        options: fmap.MapOptions(
          initialCenter: toLl(session.location),
          initialZoom: 14.5,
        ),
        children: [
          _osmTileLayer(
            onTileError: () => onTileError?.call(),
            onTileLoaded: () => onTileLoaded?.call(),
          ),
          fmap.MarkerLayer(
            markers: [
              fmap.Marker(
                point: toLl(session.location),
                width: 46,
                height: 46,
                child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
              ),
              if (session.assignedResponder != null)
                fmap.Marker(
                  point: toLl(session.assignedResponder!.responder.location),
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(session.assignedResponder!.responder.icon, color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PROFILE
// ============================================================

class ProfileScreen
    extends StatelessWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFFFF9FA),

      appBar: AppBar(
        title: const Text(
          'Profile',

          style: TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        backgroundColor:
        Colors.white,

        foregroundColor:
        const Color(0xFF172027),

        elevation: 0,
      ),

      body: ListView(
        padding:
        const EdgeInsets.all(
          20,
        ),

        children: [
          Center(
            child: Container(
              width: 90,
              height: 90,

              decoration:
              const BoxDecoration(
                color:
                Color(0xFFFFE9EC),

                shape:
                BoxShape.circle,
              ),

              child: const Icon(
                Icons.person,

                size: 50,

                color:
                Color(0xFFE92335),
              ),
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          const Center(
            child: Text(
              'Emergency HELP User',

              style: TextStyle(
                fontSize: 20,

                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(
            height: 30,
          ),

          ProfileOption(
            icon:
            Icons.person_outline,

            title:
            'Personal Information',
          ),

          ProfileOption(
            icon:
            Icons.location_on_outlined,

            title:
            'Location Settings',
          ),

          ProfileOption(
            icon:
            Icons.notifications_outlined,

            title:
            'Notifications',
          ),

          ProfileOption(
            icon:
            Icons.security_outlined,

            title:
            'Privacy & Security',
          ),

          ProfileOption(
            icon:
            Icons.info_outline,

            title:
            'About Emergency HELP',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PROFILE OPTION
// ============================================================

class ProfileOption
    extends StatelessWidget {
  final IconData icon;
  final String title;

  const ProfileOption({
    super.key,

    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color:
      Colors.white,

      elevation: 1,

      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),

      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
      ),

      child: ListTile(
        leading: Icon(
          icon,

          color:
          const Color(
            0xFFE92335,
          ),
        ),

        title:
        Text(title),

        trailing:
        const Icon(
          Icons.arrow_forward_ios,

          size: 15,
        ),

        onTap: () {
          ScaffoldMessenger.of(
              context)
              .showSnackBar(
            SnackBar(
              content: Text(
                '$title selected',
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// MAIN SERVICE CARD
// ============================================================

class MainServiceCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const MainServiceCard({
    super.key,

    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
      onTap,

      child: Container(
        height: 112,

        padding:
        const EdgeInsets.all(
          11,
        ),

        decoration:
        BoxDecoration(
          color:
          Colors.white,

          borderRadius:
          BorderRadius.circular(
            17,
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(
                0.045,
              ),

              blurRadius: 8,

              offset:
              const Offset(
                0,
                3,
              ),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Container(
              width: 38,
              height: 38,

              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFFFE9EC,
                ),

                borderRadius:
                BorderRadius.circular(
                  11,
                ),
              ),

              child: Icon(
                icon,

                color:
                const Color(
                  0xFFE92335,
                ),

                size: 21,
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            Text(
              title,

              style:
              const TextStyle(
                fontSize: 12,

                fontWeight:
                FontWeight.bold,

                color:
                Color(
                  0xFF172027,
                ),
              ),
            ),

            const SizedBox(
              height: 2,
            ),

            Text(
              subtitle,

              maxLines: 2,

              overflow:
              TextOverflow.ellipsis,

              style:
              const TextStyle(
                fontSize: 8.5,

                height: 1.2,

                color:
                Color(
                  0xFF777E82,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MAP MARKER
// ============================================================

class MapHelperMarker
    extends StatelessWidget {
  final IconData icon;

  const MapHelperMarker({
    super.key,

    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 35,
      height: 35,

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        shape:
        BoxShape.circle,

        border:
        Border.all(
          color:
          const Color(
            0xFFFFB5BC,
          ),

          width: 2,
        ),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              0.10,
            ),

            blurRadius: 4,
          ),
        ],
      ),

      child: Icon(
        icon,

        color:
        const Color(
          0xFFE92335,
        ),

        size: 17,
      ),
    );
  }
}

// ============================================================
// MAP PAINTER
// ============================================================

class MapPainter
    extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final background =
    Paint()
      ..color =
      const Color(
        0xFFE9F0EC,
      );

    canvas.drawRect(
      Offset.zero & size,
      background,
    );

    // River

    final riverPaint =
    Paint()
      ..color =
      const Color(
        0xFFB8DDEB,
      )

      ..strokeWidth = 22

      ..style =
          PaintingStyle.stroke;

    final river =
    Path();

    river.moveTo(
      -10,
      size.height * 0.75,
    );

    river.cubicTo(
      size.width * 0.25,
      size.height * 0.48,

      size.width * 0.52,
      size.height * 0.95,

      size.width + 10,
      size.height * 0.23,
    );

    canvas.drawPath(
      river,
      riverPaint,
    );

    // Main road

    final roadPaint =
    Paint()
      ..color =
          Colors.white

      ..strokeWidth = 9

      ..style =
          PaintingStyle.stroke;

    final road1 =
    Path();

    road1.moveTo(
      -10,
      size.height * 0.18,
    );

    road1.lineTo(
      size.width + 10,
      size.height * 0.78,
    );

    canvas.drawPath(
      road1,
      roadPaint,
    );

    // Second road

    final road2 =
    Path();

    road2.moveTo(
      size.width * 0.05,
      size.height + 10,
    );

    road2.lineTo(
      size.width * 0.86,
      -10,
    );

    canvas.drawPath(
      road2,
      roadPaint,
    );

    // Small roads

    final smallRoadPaint =
    Paint()
      ..color =
      const Color(
        0xFFD7DDD8,
      )

      ..strokeWidth = 2

      ..style =
          PaintingStyle.stroke;

    for (int i = 0; i < 6; i++) {
      final path =
      Path();

      path.moveTo(
        size.width * (i / 6),
        0,
      );

      path.lineTo(
        size.width *
            ((i + 1) / 7),

        size.height,
      );

      canvas.drawPath(
        path,
        smallRoadPaint,
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}

// ============================================================
// TEST HOOKS (no UI behavior)
// ============================================================

@visibleForTesting
_RespWithDist assignedResponderForTesting(Responder responder, double distKm) =>
    _RespWithDist(responder, distKm);

@visibleForTesting
Future<bool> openDialerForTesting(String number) => _openDialer(number);

@visibleForTesting
Future<bool> sendEmergencySmsForTesting(LatLng location) =>
    _sendEmergencySMS(location);

@visibleForTesting
Future<void> loadPersistedHistoryForTesting() => _loadPersistedHistory();

@visibleForTesting
void setActiveSessionForTesting(EmergencySession? session) =>
    _activeSession = session;

@visibleForTesting
Future<void> persistHistoryForTesting() => _persistHistory();

@visibleForTesting
List<EmergencySession> get emergencySessionsForTesting =>
    List<EmergencySession>.unmodifiable(_emergencyHistory);

@visibleForTesting
void clearEmergencyStateForTesting() {
  _emergencyHistory.clear();
  _activeSession = null;
  _historyWriteTail = Future.value();
  _addressCache.clear();
  LiveLocationService.lastStreamError = null;
}
