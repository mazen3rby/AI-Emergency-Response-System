import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() {
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

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  static const Color brandRed = Color(0xFFE92335);
  static const Color darkText = Color(0xFF202329);
  static const Color mutedText = Color(0xFF777E82);
  static const Color pageBackground = Color(0xFFFFF7F8);

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
                  onTap: () => showEmergencyDialog(context),
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
                  onTap: () => showLocationOptions(context),
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
                        const Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Your Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: darkText)),
                            SizedBox(height: 4),
                            Row(children: [Icon(Icons.circle, size: 7, color: Color(0xFF20B66B)), SizedBox(width: 6), Text('Cairo, Egypt', style: TextStyle(fontSize: 11, color: mutedText))]),
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

              // Real Google Maps preview focused on Helwan City.
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
                      Positioned.fill(
                        child: IgnorePointer(
                          child: GoogleMap(
                            initialCameraPosition: const CameraPosition(
                              target: LatLng(29.8414, 31.3008),
                              zoom: 13.5,
                            ),
                            cameraTargetBounds: CameraTargetBounds(
                              LatLngBounds(
                                southwest: LatLng(29.78, 31.22),
                                northeast: LatLng(29.91, 31.39),
                              ),
                            ),
                            minMaxZoomPreference:
                            const MinMaxZoomPreference(12, 19),
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            myLocationButtonEnabled: false,
                            myLocationEnabled: false,
                            compassEnabled: false,
                            markers: {
                              Marker(
                                markerId: MarkerId('helwan-center'),
                                position: LatLng(29.8414, 31.3008),
                                infoWindow: InfoWindow(title: 'Helwan City'),
                              ),
                            },
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_rounded,
                                  color: brandRed, size: 15),
                              SizedBox(width: 6),
                              Text(
                                'Helwan City',
                                style: TextStyle(
                                  color: darkText,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(Icons.chevron_right_rounded,
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

class _NabdCurrentLocationMarker extends StatelessWidget {
  const _NabdCurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFE92335).withOpacity(0.13),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFFE92335),
            shape: BoxShape.circle,
          ),
          child: Container(
            margin: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
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
    BuildContext context,
    ) {
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
                  'Detect your current location',
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
                        'Current location selected.',
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

class NearbyHelpScreen
    extends StatelessWidget {
  const NearbyHelpScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFFFF9FA),

      appBar: AppBar(
        title: const Text(
          'Nearby Help',

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
            'People Near You',

            style: TextStyle(
              fontSize: 22,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            'Helpers available near your current location.',

            style: TextStyle(
              color:
              Color(0xFF777E82),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          HelperCard(
            name:
            'Ahmed Hassan',

            role:
            'First Aid Volunteer',

            distance:
            '0.4 km',

            icon:
            Icons.person,
          ),

          HelperCard(
            name:
            'Dr. Mohamed Ali',

            role:
            'Doctor',

            distance:
            '0.8 km',

            icon:
            Icons.medical_services,
          ),

          HelperCard(
            name:
            'Sara Ahmed',

            role:
            'Nurse',

            distance:
            '1.2 km',

            icon:
            Icons.health_and_safety,
          ),

          HelperCard(
            name:
            'Emergency Volunteer',

            role:
            'Emergency Responder',

            distance:
            '1.6 km',

            icon:
            Icons.volunteer_activism,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HELPER CARD
// ============================================================

class HelperCard
    extends StatelessWidget {
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

        leading: CircleAvatar(
          radius: 25,

          backgroundColor:
          const Color(
            0xFFFFE9EC,
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
          name,

          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        subtitle:
        Text(
          '$role • $distance',
        ),

        trailing:
        ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(
                context)
                .showSnackBar(
              SnackBar(
                content: Text(
                  'Request sent to $name',
                ),
              ),
            );
          },

          style:
          ElevatedButton.styleFrom(
            backgroundColor:
            const Color(
              0xFFE92335,
            ),

            foregroundColor:
            Colors.white,
          ),

          child:
          const Text(
            'Help',
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MAP SCREEN
// ============================================================

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng helwan = LatLng(29.8414, 31.3008);

  GoogleMapController? _mapController;
  bool _locationEnabled = false;
  bool _loadingLocation = false;
  LatLng? _currentPosition;

  Future<void> _useCurrentLocation() async {
    if (_loadingLocation) return;
    setState(() => _loadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable Location on the emulator.')),
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

      final position = await Geolocator.getCurrentPosition();
      final current = LatLng(position.latitude, position.longitude);
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(current, 16));

      if (mounted) {
        setState(() {
          _currentPosition = current;
          _locationEnabled = true;
        });
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      const Marker(
        markerId: MarkerId('helwan-center'),
        position: helwan,
        infoWindow: InfoWindow(title: 'Helwan City, Cairo'),
      ),
    };
    if (_currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('current-location'),
        position: _currentPosition!,
        infoWindow: const InfoWindow(title: 'Your current location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9FA),
      appBar: AppBar(
        title: const Text('Helwan Map', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172027),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: helwan, zoom: 13.5),
            onMapCreated: (controller) => _mapController = controller,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: _locationEnabled,
            compassEnabled: true,
            markers: markers,
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_rounded, color: Color(0xFFE92335), size: 19),
                  SizedBox(width: 7),
                  Text('Helwan City', style: TextStyle(
                      fontWeight: FontWeight.w800, color: Color(0xFF202329))),
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
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HISTORY
// ============================================================

class HistoryScreen
    extends StatelessWidget {
  const HistoryScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFFFF9FA),

      appBar: AppBar(
        title: const Text(
          'History',

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

      body: Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            Container(
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
                Icons.history_rounded,

                size: 45,

                color:
                Color(0xFFE92335),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'No Emergency History',

              style: TextStyle(
                fontSize: 20,

                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Your emergency activities will appear here.',

              textAlign:
              TextAlign.center,

              style: TextStyle(
                color:
                Color(0xFF777E82),
              ),
            ),
          ],
        ),
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
