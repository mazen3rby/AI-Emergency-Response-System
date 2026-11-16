import 'dart:async';
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

ll.LatLng toLl(LatLng p) => ll.LatLng(p.latitude, p.longitude);
LatLng toGMap(ll.LatLng p) => LatLng(p.latitude, p.longitude);

// ============================================================
// RESPONDER DATA MODEL  (Static – ready to swap with DB later)
// ============================================================

enum ResponderType { doctor, nurse, paramedic, volunteer }

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

List<Responder> _getRespondersForLocation(LatLng from) {
  // Generate realistic emergency responders clustered around the user's real-time position
  return [
    Responder(
      id: 'near_doc_1',
      name: 'Dr. Walid Mansour',
      type: ResponderType.doctor,
      specialty: 'Emergency Medicine & Trauma',
      location: LatLng(from.latitude + 0.0035, from.longitude + 0.0028),
      address: 'Central Emergency Clinic',
      phone: '01001234567',
    ),
    Responder(
      id: 'near_nurse_1',
      name: 'Nurse Sara Youssef',
      type: ResponderType.nurse,
      specialty: 'Critical Care Nurse',
      location: LatLng(from.latitude - 0.0042, from.longitude + 0.0031),
      address: 'Community Health Center',
      phone: '01112345678',
    ),
    Responder(
      id: 'near_paramedic_1',
      name: 'Ambulance Rapid Response #4',
      type: ResponderType.paramedic,
      specialty: 'Emergency Ambulance Unit',
      location: LatLng(from.latitude + 0.0052, from.longitude - 0.0038),
      address: 'Ambulance Dispatch Station',
      phone: '123',
    ),
    Responder(
      id: 'near_doc_2',
      name: 'Dr. Mona Khaled',
      type: ResponderType.doctor,
      specialty: 'Cardiologist',
      location: LatLng(from.latitude - 0.0058, from.longitude - 0.0045),
      address: 'Specialized Medical Center',
      phone: '01223456789',
    ),
    Responder(
      id: 'near_vol_1',
      name: 'Volunteer Omar Samir',
      type: ResponderType.volunteer,
      specialty: 'Certified First Aid Responder',
      location: LatLng(from.latitude + 0.0022, from.longitude - 0.0018),
      address: 'Local First Aid Station',
      phone: '01556789012',
    ),
    ...kResponders,
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
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ============================================================
// EMERGENCY STATE
// ============================================================

enum EmergencyStatus { idle, requesting, active, resolved }

class EmergencySession {
  final String id;
  final LatLng location;
  final DateTime startTime;
  EmergencyStatus status;
  _RespWithDist? assignedResponder;

  EmergencySession({
    required this.id,
    required this.location,
    required this.startTime,
    this.status = EmergencyStatus.requesting,
    this.assignedResponder,
  });
}

// ── Global active session (simple state – swap with Provider later) ──
EmergencySession? _activeSession;

// ── History list (saved locally, swap with DB later) ──
final List<EmergencySession> _emergencyHistory = [];

// ── Add session to history helper ──
void _saveToHistory(EmergencySession session) {
  session.status = EmergencyStatus.resolved;
  _emergencyHistory.insert(0, session); // newest first
}

// ============================================================
// NOTIFICATION SERVICE
// ============================================================

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static FirebaseMessaging? _fcm;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    // Local notifications setup
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

    // Firebase Messaging
    try {
      _fcm = FirebaseMessaging.instance;
      await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        _showLocal(
          title: msg.notification?.title ?? 'Emergency Alert',
          body:  msg.notification?.body  ?? '',
        );
      });
    } catch (_) {
      // Firebase not configured yet – local notifications still work
    }

    _initialized = true;
  }

  static Future<void> showEmergencyAlert({
    required String title,
    required String body,
  }) => _showLocal(title: title, body: body);

  static Future<void> _showLocal({
    required String title,
    required String body,
  }) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
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

  static Future<String?> getToken() async {
    try {
      return await _fcm?.getToken();
    } catch (_) {
      return null;
    }
  }
}

// ============================================================
// LIVE LOCATION SERVICE
// ============================================================

class LiveLocationService {
  static StreamSubscription<Position>? _sub;
  static LatLng? lastKnownPosition;

  // Start streaming location every 5 seconds
  static void startTracking({required void Function(LatLng) onUpdate}) {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // meters
      ),
    ).listen((pos) {
      lastKnownPosition = LatLng(pos.latitude, pos.longitude);
      onUpdate(lastKnownPosition!);
    });
  }

  static void stopTracking() {
    _sub?.cancel();
    _sub = null;
  }

  static Future<LatLng?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      lastKnownPosition = LatLng(pos.latitude, pos.longitude);
      return lastKnownPosition;
    } catch (_) {
      return null;
    }
  }
}

// ── Send SMS with location link ────────────────────────────────
Future<void> _sendEmergencySMS(LatLng location) async {
  final mapsLink =
      'https://maps.google.com/?q=${location.latitude},${location.longitude}';
  final msg = Uri.encodeComponent(
    '🚨 EMERGENCY! I need help!\nMy location: $mapsLink\nPlease send help immediately.',
  );
  // Try WhatsApp first, fallback to SMS
  final smsUri = Uri.parse('sms:123?body=$msg');
  if (await canLaunchUrl(smsUri)) {
    await launchUrl(smsUri);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase (safe – won't crash if google-services.json missing)
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  // Initialize notifications
  await NotificationService.init();
  runApp(const EmergencyHelpApp());
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

      // البداية = GET STARTED فقط
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

  ll.LatLng? _userPosition;
  String _locationDisplay = 'Location not detected';
  bool _isLocating = false;
  final fmap.MapController _previewMapController = fmap.MapController();

  @override
  void initState() {
    super.initState();
    _tryAutoDetectLocation();
  }

  Future<void> _tryAutoDetectLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        _fetchLocation();
      }
    } catch (_) {}
  }

  Future<void> _fetchLocation() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _locationDisplay = 'Detecting GPS location...';
    });
    try {
      final pos = await LiveLocationService.getCurrentPosition();
      if (pos != null && mounted) {
        final userLl = ll.LatLng(pos.latitude, pos.longitude);
        setState(() {
          _userPosition = userLl;
          _locationDisplay = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        });
        try {
          _previewMapController.move(userLl, 14.5);
        } catch (_) {}
      } else if (mounted) {
        setState(() {
          _locationDisplay = 'Location disabled';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationDisplay = 'Location unavailable';
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
              const SizedBox(height: 12),

              // Find Nearest — full-width prominent card
              Material(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const FindNearestScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFF1A1A1A), Color(0xFF2A0A0F)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: brandRed.withOpacity(.18),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: brandRed.withOpacity(.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.near_me_rounded,
                              color: brandRed, size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Find Nearest Doctor',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                              SizedBox(height: 2),
                              Text('GPS route to the closest responder',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: brandRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Go →',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Location row
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => showLocationOptions(context, onUseCurrentLocation: _fetchLocation),
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
                            child: Icon(_userPosition != null ? Icons.my_location_rounded : Icons.location_on_rounded, color: brandRed, size: 26)),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_userPosition != null ? 'Your Current Location' : 'Your Location',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: darkText)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.circle, size: 7, color: _userPosition != null ? const Color(0xFF20B66B) : Colors.orange),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _userPosition != null ? _locationDisplay : 'Tap to activate live GPS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _userPosition != null ? darkText : mutedText,
                                    fontWeight: _userPosition != null ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ]),
                          ]),
                        ),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                          decoration: BoxDecoration(color: const Color(0xFFFFE9EC), borderRadius: BorderRadius.circular(18)),
                          child: Text(_userPosition != null ? 'Refresh' : 'Activate',
                              style: const TextStyle(color: brandRed, fontWeight: FontWeight.w700, fontSize: 10.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Interactive live Map preview
              GestureDetector(
                onTap: () {
                  if (_userPosition == null) {
                    _fetchLocation();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MapScreen(initialLocation: _userPosition)),
                    );
                  }
                },
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
                      Positioned.fill(
                        child: _userPosition != null
                            ? fmap.FlutterMap(
                                mapController: _previewMapController,
                                options: fmap.MapOptions(
                                  initialCenter: _userPosition!,
                                  initialZoom: 14.5,
                                  interactionOptions: const fmap.InteractionOptions(
                                    flags: fmap.InteractiveFlag.none,
                                  ),
                                ),
                                children: [
                                  fmap.TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.example.emergency_help',
                                  ),
                                  fmap.MarkerLayer(
                                    markers: [
                                      fmap.Marker(
                                        point: _userPosition!,
                                        width: 44,
                                        height: 44,
                                        child: const Icon(Icons.location_pin, color: brandRed, size: 40),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Container(
                                color: const Color(0xFFF3F5F4),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: brandRed.withOpacity(.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.my_location_rounded, color: brandRed, size: 28),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _isLocating ? 'Detecting your GPS location...' : 'Tap to Activate Live Map',
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: darkText, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Shows real streets & nearest emergency responders',
                                        style: TextStyle(color: mutedText, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
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
                              Icon(Icons.location_on_rounded,
                                  color: _userPosition != null ? brandRed : Colors.grey, size: 15),
                              const SizedBox(width: 6),
                              Text(
                                _userPosition != null ? 'Live Location Active' : 'Location Not Active',
                                style: const TextStyle(
                                  color: darkText,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
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
                          elevation: 2,
                          child: IconButton(
                            tooltip: 'Open live map',
                            onPressed: () {
                              if (_userPosition == null) {
                                _fetchLocation();
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => MapScreen(initialLocation: _userPosition)),
                                );
                              }
                            },
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
}) {
  showModalBottomSheet(
    context: context,

    shape:
    const RoundedRectangleBorder(
      borderRadius:
      BorderRadius.vertical(
        top: Radius.circular(25),
      ),
    ),

    builder: (context) {
      return SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.all(20),

          child: Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [
              Container(
                width: 45,
                height: 5,

                decoration:
                BoxDecoration(
                  color:
                  Colors.grey.shade300,

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              const Text(
                'Change Location',

                style: TextStyle(
                  fontSize: 20,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              ListTile(
                leading:
                const CircleAvatar(
                  backgroundColor:
                  Color(0xFFFFE9EC),

                  child: Icon(
                    Icons.my_location,

                    color:
                    Color(0xFFE92335),
                  ),
                ),

                title: const Text(
                  'Use Current Location',
                ),

                subtitle: const Text(
                  'Detect your live GPS position',
                ),

                onTap: () {
                  Navigator.pop(
                    context,
                  );
                  if (onUseCurrentLocation != null) {
                    onUseCurrentLocation();
                  }
                  ScaffoldMessenger
                      .of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Detecting GPS location...',
                      ),
                    ),
                  );
                },
              ),

              ListTile(
                leading:
                const CircleAvatar(
                  backgroundColor:
                  Color(0xFFFFE9EC),

                  child: Icon(
                    Icons.location_city,

                    color:
                    Color(0xFFE92335),
                  ),
                ),

                title: const Text(
                  'Choose Location Manually',
                ),

                subtitle: const Text(
                  'Select a location manually',
                ),

                onTap: () {
                  Navigator.pop(
                    context,
                  );

                  ScaffoldMessenger
                      .of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Manual location selection coming soon.',
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ============================================================
// EMERGENCY SOS SCREEN  ← Person 2 Main Feature
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
  LatLng?         _userLocation;
  _RespWithDist?  _nearestResponder;
  bool            _locationLoading = false;
  String?         _statusMessage;
  Timer?          _pingTimer;
  int             _pingCount = 0;

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

    _fetchLocation();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _statusCtrl.dispose();
    _pingTimer?.cancel();
    LiveLocationService.stopTracking();
    super.dispose();
  }

  // ── Get current GPS location ──
  Future<void> _fetchLocation() async {
    setState(() => _locationLoading = true);
    final loc = await LiveLocationService.getCurrentPosition();
    if (mounted) {
      setState(() {
        _userLocation   = loc;
        _locationLoading = false;
        if (loc != null) {
          final sorted = _sortedByDistance(loc);
          _nearestResponder = sorted.isNotEmpty ? sorted.first : null;
        }
      });
    }
  }

  // ── Main SOS trigger ──
  Future<void> _triggerSOS() async {
    if (_status != EmergencyStatus.idle) return;
    HapticFeedback.heavyImpact();

    setState(() {
      _status        = EmergencyStatus.requesting;
      _statusMessage = 'Getting your location…';
    });

    // 1. Get location
    LatLng? loc = _userLocation ?? await LiveLocationService.getCurrentPosition();
    if (loc == null) {
      setState(() {
        _status        = EmergencyStatus.idle;
        _statusMessage = 'Could not get location. Please enable GPS.';
      });
      return;
    }
    _userLocation = loc;

    // 2. Find nearest responder
    final sorted = _sortedByDistance(loc);
    _nearestResponder = sorted.isNotEmpty ? sorted.first : null;

    setState(() => _statusMessage = 'Calling emergency services…');
    await Future.delayed(const Duration(milliseconds: 600));

    // 3. Call 123
    final callUri = Uri(scheme: 'tel', path: '123');
    try {
      await launchUrl(callUri);
    } catch (_) {}

    // 4. Send SMS with location
    setState(() => _statusMessage = 'Sending your location via SMS…');
    await _sendEmergencySMS(loc);
    await Future.delayed(const Duration(milliseconds: 500));

    // 5. Create session & start live tracking
    _activeSession = EmergencySession(
      id:        DateTime.now().millisecondsSinceEpoch.toString(),
      location:  loc,
      startTime: DateTime.now(),
      status:    EmergencyStatus.active,
      assignedResponder: _nearestResponder,
    );

    LiveLocationService.startTracking(onUpdate: (newLoc) {
      if (mounted) setState(() => _userLocation = newLoc);
    });

    // 6. Fire local notification
    await NotificationService.showEmergencyAlert(
      title: '🚨 Emergency Request Sent',
      body:  _nearestResponder != null
          ? 'Nearest responder: ${_nearestResponder!.responder.name} · ${_nearestResponder!.distLabel}'
          : 'Emergency services notified. Help is on the way.',
    );

    // 7. Save session to history
    if (_activeSession != null) {
      _saveToHistory(_activeSession!);
    }

    setState(() {
      _status        = EmergencyStatus.active;
      _statusMessage = 'Help is on the way!';
    });

    // 8. Simulate responder ping every 30s
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pingCount++;
      if (mounted && _nearestResponder != null) {
        NotificationService.showEmergencyAlert(
          title: 'Responder Update',
          body:  '${_nearestResponder!.responder.name} is heading to you.',
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
      LiveLocationService.stopTracking();
      _activeSession = null;
      setState(() {
        _status        = EmergencyStatus.idle;
        _statusMessage = null;
        _pingCount     = 0;
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
                    ? 'Tap to send emergency alert'
                    : _status == EmergencyStatus.requesting
                        ? 'Please wait…'
                        : 'Emergency services notified',
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
                                  Text(
                                    '${_userLocation!.latitude.toStringAsFixed(5)}, '
                                    '${_userLocation!.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
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
                                    Text('Live tracking active',
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
                        await launchUrl(Uri(scheme: 'tel', path: '123'));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionBtn(
                      icon: Icons.sms_rounded,
                      label: 'Send SMS',
                      color: const Color(0xFF1565C0),
                      onTap: _userLocation != null
                          ? () => _sendEmergencySMS(_userLocation!)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionBtn(
                      icon: Icons.map_rounded,
                      label: 'Open Map',
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
                title: 'Emergency Numbers',
                child: Column(
                  children: [
                    _EmerNumRow(number: '123', label: 'Police'),
                    _EmerNumRow(number: '123', label: 'Ambulance'),
                    _EmerNumRow(number: '180', label: 'Fire Department'),
                    _EmerNumRow(number: '16021', label: 'Poison Control'),
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
            onTap: () => launchUrl(Uri(scheme: 'tel', path: number)),
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
// LIVE TRACKING MAP SCREEN  ← Person 2 Feature
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
  bool                 _tracking = true;

  @override
  void initState() {
    super.initState();
    _liveLocation = widget.userLocation;
    // Start updating live location
    LiveLocationService.startTracking(onUpdate: (loc) {
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
    LiveLocationService.stopTracking();
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
                fmap.TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.emergency_help',
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
                          onPressed: () async {
                            final uri = Uri(
                                scheme: 'tel',
                                path: widget.responder.responder.phone);
                            await launchUrl(uri);
                          },
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
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { _fallback(); return; }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) { _fallback(); return; }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _userLocation = loc;
          _sorted = _sortedByDistance(loc);
          _loading = false;
        });
      }
    } catch (_) {
      _fallback();
    }
  }

  // If GPS fails → use Helwan center as default
  void _fallback() {
    const helwan = LatLng(29.8414, 31.3008);
    if (mounted) {
      setState(() {
        _userLocation = helwan;
        _sorted = _sortedByDistance(helwan);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9FA),
      appBar: AppBar(
        title: const Text('Nearby Help',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172027),
        elevation: 0,
        actions: [
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
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: brandRed),
                  SizedBox(height: 16),
                  Text('Finding your location…',
                      style: TextStyle(color: Color(0xFF777E82))),
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
                          'Showing ${_sorted.length} responders sorted by distance',
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
                        onTap: () async {
                          final uri =
                              Uri(scheme: 'tel', path: r.phone);
                          await launchUrl(uri);
                        },
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
              fmap.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.emergency_help',
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
                            onPressed: () async {
                              final uri = Uri(
                                  scheme: 'tel',
                                  path: _selected!.responder.phone);
                              await launchUrl(uri);
                            },
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
  bool _loadingLocation = false;
  ll.LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _currentPosition = widget.initialLocation;
    }
    _useCurrentLocation();
  }

  Future<void> _useCurrentLocation() async {
    if (_loadingLocation) return;
    setState(() => _loadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS Location.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission was not granted.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final current = ll.LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = current;
        });
        try {
          _mapController.move(current, 15.0);
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
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
                      onPressed: () async {
                        final uri = Uri(scheme: 'tel', path: r.phone);
                        await launchUrl(uri);
                      },
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
                        final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${r.location.latitude},${r.location.longitude}');
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final effectiveLocation = _currentPosition ?? const ll.LatLng(30.0444, 31.2357);
    final responders = _getRespondersForLocation(toGMap(effectiveLocation));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9FA),
      appBar: AppBar(
        title: const Text('Live Emergency Map', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172027),
        elevation: 0,
        actions: [
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
                      const SizedBox(height: 16),
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
          fmap.FlutterMap(
            mapController: _mapController,
            options: fmap.MapOptions(
              initialCenter: effectiveLocation,
              initialZoom: 14.5,
            ),
            children: [
              fmap.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.emergency_help',
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
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _showResponderDetails(r),
                        child: Container(
                          decoration: BoxDecoration(
                            color: markerColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
                          ),
                          child: Icon(r.icon, color: Colors.white, size: 20),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            top: 16,
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
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFE92335), size: 19),
                  const SizedBox(width: 7),
                  Text(
                    _currentPosition != null
                        ? 'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                        : 'Detecting Location...',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF202329), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'currentLocationButton',
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
    if (loc == null) {
      setState(() { _loading = false; _error = 'Could not get your location.\nPlease enable GPS and try again.'; });
      return;
    }
    _userLoc = loc;
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
                    : fmap.FlutterMap(
                        mapController: _fmapCtrl,
                        options: fmap.MapOptions(
                          initialCenter: _userLoc != null ? toLl(_userLoc!) : const ll.LatLng(30.0444, 31.2357),
                          initialZoom: 14.5,
                        ),
                        children: [
                          fmap.TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.emergency_help',
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
                                onPressed: () async {
                                  final uri = Uri(
                                      scheme: 'tel',
                                      path: _nearest!.responder.phone);
                                  await launchUrl(uri);
                                },
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
                        onPressed: () {
                          setState(() => _emergencyHistory.clear());
                          Navigator.pop(context);
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
                      onPressed: () async {
                        final uri = Uri(
                            scheme: 'tel',
                            path: responder.responder.phone);
                        await launchUrl(uri);
                      },
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
  const _HistoryMapView({required this.session});

  @override
  Widget build(BuildContext context) {
    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('sos_location'),
        position: session.location,
        infoWindow: const InfoWindow(
          title: '🚨 Emergency Location',
          snippet: 'Your SOS was sent from here',
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
          fmap.TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.emergency_help',
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
