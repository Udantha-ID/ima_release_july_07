import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:test_app/Leaves/dashbord_screen.dart';
import 'login_screen.dart';
import 'Leaves/top_banner.dart';
import 'Leaves/reliaver_request_screen.dart';
import 'Leaves/leave_request_screen.dart';
import 'vehicle_home_screen.dart';
import 'ui/dialogs/logout_dialog.dart';
import 'ui/dialogs/privacy_notice_dialog.dart';
import 'ui/dialogs/biometric_enable_dialog.dart';
import 'Reports/reports_screen.dart';
import '../QRCode/Vehicle_qr_screen.dart';
import '../users/biometric_enabled_screen.dart';
import 'Meeting&Events/dashbord_screen.dart';
import 'AirportParking/airport_parking_screen.dart';
import 'users/gate_pass_screen.dart';
import '../users/vehicle_screen.dart';
import '../users/personal_vehicle_screen.dart' as pvs;
import 'Vehicle/personal_request_screen.dart';
import 'ITSupport/it_support_home_screen.dart';
import 'ITSupport/ticket_conversation_screen.dart';
import 'Services/ticket_api_service.dart';
import 'package:test_app/Services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final Map<String, dynamic> user;
  final String name;
  final String? successMessage;

  const HomeScreen({
    Key? key,
    required this.name,
    required this.username,
    required this.user,
    this.successMessage,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const blue = Color(0xFF0060A6);
  bool _privacyNoticeShown = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String? _profilePhotoUrl;
  bool _photoLoading = false;
  // Check the user is in the list of HR management
  bool get isHrManagement {
    final id = (widget.user["employeeId"] ?? widget.user["employeeId"])
            ?.toString() ??
        "";
    return ["26","11","14","24","25","19"]
        .contains(id);
  }

  // ── Airport Parking access ────────────────────────────────────────────────
  // Add or remove employee IDs here to control who can open the module.
  static const _airportParkingAllowedIds = ["26","11","14","19","24","29","52","61","80"];

  bool get isAirportParkingAllowed {
    final id =
        (widget.user["employeeId"] ?? widget.user["employee_id"] ?? widget.user["id"])
            ?.toString()
            .trim() ??
        "";
    return _airportParkingAllowedIds.contains(id);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfilePhoto() async {
    if (!mounted) return;
    setState(() => _photoLoading = true);
    String? url;
    try {
      final employeeId = (widget.user["employeeId"] ?? widget.user["employee_id"] ?? widget.user["id"])?.toString() ?? "";
      if (employeeId.isNotEmpty) {
        final photo = await ApiService.getProfilePhoto(employeeId: int.parse(employeeId));
        url = (photo?["fileUrl"] as String?)?.trim();
      }
    } catch (_) {
      url = null;
    }
    if (!mounted) return;
    setState(() {
      _profilePhotoUrl = url;
      _photoLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _setupFcmListeners();
    _loadProfilePhoto();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = widget.successMessage;
      if (msg != null && msg.trim().isNotEmpty) {
        TopBanner.show(
          context,
          title: "Welcome",
          message: msg,
          icon: Icons.check_circle,
          rightButtonText: "OK",
        );
      }
      _showPrivacyNoticeAfterLogin();
    });
  }

  //Show privacy notice dialog after login
  Future<void> _showPrivacyNoticeAfterLogin() async {
    if (!mounted || _privacyNoticeShown) return;
    _privacyNoticeShown = true;

    // Small delay avoids clashing with welcome banner animation.
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await showPrivacyNoticeDialog(context);

    if (!mounted) return;
    await showBiometricEnableDialogIfNeeded(context);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    // services list (easy to add more)
    final rawServices = <_ServiceItem>[
      _ServiceItem(
        image: 'assets/456123.png',
        label: "Apply Leave",
        description: "Apply & Track your Leaves",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/personal-vehicle.png',
        label: "Vehicle Request (Personal Use)",
        description: "Request Vehicles for Personal Requirements",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => pvs.VehicleScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/office-vehicle.png',
        label: "Vehicle Request (Office Use)",
        description: "Request Vehicles for Official Requirements",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VehicleScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/123456.png',
        label: "Shuttle & Transfer Movement",
        description: "Manage Shuttle and Transfer vehicle Movement",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VehicleHomeScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/gatepass.png',
        label: "Gate Pass",
        description: "Gate Pass Request for Personal Requirements during Office Hours",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GatePassScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/qr.png',
        label: "Fuel QR Code",
        description: "Scan and manage fuel QR codes for vehicles",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VehicleQrScreen(user: widget.user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/airportparking.png',
        label: "Airport Parking Customer Handling",
        description: "Airport Parking Customer Handling",
        disabled: !isAirportParkingAllowed,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AirportParkingScreen(user: user),
            ),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/itSupport.png',
        label: "IT Support Desk",
        description: "Raise and track IT support tickets",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ITSupportHomeScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/report.png',
        label: "Reports",
        description: "View and export HR and operational reports",
        disabled: !isHrManagement,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReportsScreen(),
            ),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/meeting&event.png',
        label: "Meeting & Events",
        description: "Schedule and manage meetings and events",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MeetingDashboardScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/setting.png',
        label: "Settings",
        description: "Manage your account and app preferences",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SettingsScreen()),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/help.png',
        label: "Help",
        description: "Get assistance and user guide",
        disabled: false,
        onTap: () => showBottomMessage("Help is coming soon 🚧"),
      ),
      _ServiceItem(
        image: 'assets/project.png',
        label: "Project & Task",
        description: "Manage projects and assign team tasks",
        disabled: true,
        onTap: () => showBottomMessage("Project & Task is coming soon 🚧"),
      ),
      _ServiceItem(
        image: 'assets/finance.png',
        label: "Finance & Accounting",
        description: "Track financial records and accounting",
        disabled: true,
        onTap: () => showBottomMessage("Finance & Accounting is coming soon 🚧"),
      ),
    ];
    final allServices = <_ServiceItem>[
      ...rawServices.where((s) => !s.disabled),
      ...rawServices.where((s) => s.disabled),
    ];
    final services = _searchQuery.isEmpty
        ? allServices
        : allServices.where((s) {
            final q = _searchQuery.toLowerCase();
            return s.label.toLowerCase().contains(q) ||
                s.description.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: Colors.white,

      // footer fixed
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: const [
              Expanded(child: Divider(color: blue, thickness: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Explore Holdings',
                  style: TextStyle(
                    color: blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(child: Divider(color: blue, thickness: 1)),
            ],
          ),
        ),
      ),

      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildHeroHeader(),
                Positioned(
                  bottom: -28,
                  left: 16,
                  right: 16,
                  child: _buildFloatingSearchCard(),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Services",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: blue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: services.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFCCD5E0)),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No services found for "$_searchQuery"',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF8A97AD)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 12),
                              itemCount: services.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final s = services[i];
                                return _serviceCard(
                                  imagePath: s.image,
                                  iconData: s.icon,
                                  label: s.label,
                                  description: s.description,
                                  onTap: s.onTap,
                                  isDisabled: s.disabled,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HERO HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPad + 24, 20, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0060A6), Color(0xFF0B3E73)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name row with logout icon on the right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hello, ${widget.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _greeting,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const _GreetingEmoji(),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showLogoutConfirmationDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout_outlined, color: Colors.white, size: 16),
                      SizedBox(width: 5),
                      Text('Logout', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Designation & Department with avatar on the right
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (widget.user['designation'] ?? widget.user['jobTitle'] ?? widget.user['job_title'] ?? '').toString().isNotEmpty
                          ? (widget.user['designation'] ?? widget.user['jobTitle'] ?? widget.user['job_title']).toString()
                          : '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (widget.user['department'] ?? '').toString().isNotEmpty
                          ? '${widget.user['department']} Department'
                          : '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _heroProfileAvatar(),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Explore Holdings Staff App\nSimple. Smart. Secure.",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroProfileAvatar() {
    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
      ),
      child: ClipOval(
        child: (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
            ? Image.network(
                _profilePhotoUrl!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.white24,
                  child: const Icon(Icons.person, color: Colors.white, size: 38),
                ),
              )
            : _photoLoading
                ? Container(
                    color: Colors.white24,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.white24,
                    child: const Icon(Icons.person, color: Colors.white, size: 38),
                  ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAIN MENU — replaces the old standalone logout icon button
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFloatingSearchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        style: const TextStyle(fontSize: 13.5, color: Colors.black87),
        decoration: InputDecoration(
          hintText: "Search services...",
          hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFFAAB4C4)),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF4FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_rounded, color: blue, size: 18),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFF8A97AD)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  void _setupFcmListeners() {
    // Foreground tap — app is open
    FirebaseMessaging.onMessage.listen((message) {
      // OS shows the banner; nothing extra needed
    });

    // Tap while app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Tap from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleNotificationTap(message);
    });
  }

  void _handleNotificationTap(RemoteMessage message) async {
    if (!mounted) return;
    final type = message.data["type"];

    switch (type) {
      // ── LEAVE MANAGEMENT ────────────────────────────────────────────────────
      case "reliever_request":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => RelieverRequestView(user: widget.user)));
        break;

      case "reliever_accepted":
      case "leave_approved":
      case "leave_rejected":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => DashboardScreen(user: widget.user)));
        break;

      case "manager_leave_approval":
        final managerId = (widget.user["employee_id"] ??
                widget.user["employeeId"] ??
                widget.user["id"] ?? "")
            .toString();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => LeaveRequestScreen(managerId: managerId)));
        break;

      // ── GATE PASS ──────────────────────────────────────────────────────────
      case "gate_pass_approval":
      case "gate_pass_companion":
      case "gate_pass_approved":
      case "gate_pass_rejected":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => GatePassScreen(user: widget.user)));
        break;

      // ── OFFICE VEHICLE: manager needs to approve ─────────────────────────────
      case "vehicle_request_approval":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => VehicleScreen(user: widget.user, initialTab: 2)));
        break;

      // ── OFFICE VEHICLE: employee feedback / companion added ───────────────────
      case "vehicle_request_companion":
      case "vehicle_approved":
      case "vehicle_rejected":
      case "vehicle_changed_mid_trip":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => VehicleScreen(user: widget.user, initialTab: 1)));
        break;

      // ── PERSONAL VEHICLE: manager needs to approve ────────────────────────────
      case "personal_vehicle_approval":
      case "personal_vehicle_forwarded":
      case "personal_vehicle_gm_approval":
        final managerId = (widget.user["employee_id"] ??
                widget.user["employeeId"] ??
                widget.user["id"] ?? "")
            .toString();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => PersonalRequestScreen(managerId: managerId)));
        break;

      // ── PERSONAL VEHICLE: employee feedback ───────────────────────────────────
      case "personal_vehicle_approved":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => pvs.VehicleScreen(user: widget.user, initialTab: 1)));
        break;

      // ── MEETING & EVENTS ───────────────────────────────────────────────────
      case "meeting_invite":
      case "meeting_cancelled":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => MeetingDashboardScreen(user: widget.user)));
        break;

      // ── IT SUPPORT TICKETS ─────────────────────────────────────────────────
      case "new_ticket":
      case "ticket_reply":
      case "ticket_resolved":
        final ticketId =
            int.tryParse((message.data["ticketId"] ?? "").toString());
        if (ticketId != null && ticketId > 0) {
          await _openTicketConversation(ticketId);
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => ITSupportHomeScreen(user: widget.user)));
        }
        break;

      default:
        debugPrint("Unhandled notification type: $type");
    }
  }

  Future<void> _openTicketConversation(int ticketId) async {
    bool isAgent = false;
    try {
      final agentIds = await TicketApiService.getItAgentIds();
      final empId = (widget.user["employee_id"] ??
              widget.user["employeeId"] ??
              widget.user["id"] ?? "")
          .toString()
          .trim();
      isAgent = agentIds.contains(empId);
    } catch (_) {}

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketConversationScreen(
          ticketId: ticketId,
          user:     widget.user,
          isAgent:  isAgent,
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmationDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (_) => LogoutDialog(
        onLogout: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
      ),
    );
  }

  void showBottomMessage(String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E63B5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            height: 70,
            alignment: Alignment.center,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  Widget _serviceCard({
    String? imagePath,
    IconData? iconData,
    required String label,
    String description = "",
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return Opacity(
      opacity: isDisabled ? 0.40 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isDisabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE4EBF8)),
              boxShadow: [
                BoxShadow(
                  color: blue.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon box
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: imagePath != null
                        ? Image.asset(
                            imagePath,
                            width: 68,
                            height: 68,
                            fit: BoxFit.contain,
                          )
                        : iconData != null
                            ? Icon(iconData, size: 36, color: blue)
                            : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 16),
                // Label + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: blue,
                          height: 1.2,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2B2B30),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isDisabled ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                  color: isDisabled ? const Color(0xFFB0BCCC) : const Color(0xFF2B2B30),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _GreetingEmoji extends StatelessWidget {
  const _GreetingEmoji();

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final emoji = h < 12 ? '☀️' : h < 17 ? '🌤️' : '🌙';
    return Text(emoji, style: const TextStyle(fontSize: 13));
  }
}

// helper model
class _ServiceItem {
  final String? image;
  final IconData? icon;
  final String label;
  final String description;
  final bool disabled;
  final VoidCallback onTap;

  _ServiceItem({
    this.image,
    this.icon,
    required this.label,
    this.description = "",
    required this.disabled,
    required this.onTap,
  }) : assert(image != null || icon != null,
            'Provide either an image asset or an icon for the service.');
}
