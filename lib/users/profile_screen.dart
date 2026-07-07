import 'package:flutter/material.dart';
import 'package:test_app/Services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int selectedTab = 0;

  // Leave balance state
  Map<String, dynamic>? leaveBalance;
  bool loadingLeave = true;
  String? leaveError;

  String? profilePhotoUrl;
  bool photoLoading = false;

  Future<void> _loadProfilePhoto() async {
  setState(() => photoLoading = true);
  try {
    final employeeId = widget.user["employeeId"]?.toString() ?? "";
    if (employeeId.isEmpty) {
      setState(() => profilePhotoUrl = null);
      return;
    }
    final photo = await ApiService.getProfilePhoto(employeeId: int.parse(employeeId));
    setState(() {
      profilePhotoUrl = (photo?["fileUrl"] as String?)?.trim();
    });
  } catch (_) {
    setState(() => profilePhotoUrl = null);
  } finally {
    setState(() => photoLoading = false);
  }
}

  @override
  void initState() {
    super.initState();
    _loadLeaveBalance();
    _loadProfilePhoto();

  }

  Future<void> _loadLeaveBalance() async {
    try {
      setState(() {
        loadingLeave = true;
        leaveError = null;
      });

      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isEmpty) {
        setState(() {
          loadingLeave = false;
          leaveError = "employeeId not found";
        });
        return;
      }

      final res = await ApiService.getLeaveBalance(employeeId: employeeId);

      if (res["success"] == true) {
        setState(() {
          leaveBalance = Map<String, dynamic>.from(res["data"] ?? {});
          loadingLeave = false;
        });
      } else {
        setState(() {
          loadingLeave = false;
          leaveError = res["message"]?.toString() ?? "Failed to load leave balance";
        });
      }
    } catch (e) {
      setState(() {
        loadingLeave = false;
        leaveError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final blue = Colors.blue[800]!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          children: [
            const SizedBox(height: 8),

            _profileCard(blue, widget.user),
            const SizedBox(height: 16),

            _sectionTitle('Contact Information'),
            const SizedBox(height: 10),

            _infoCard(
              children: [
                _InfoRow(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: (u["workEmail"] ?? "-").toString(),
                ),
                const _DividerLine(),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  title: 'Phone',
                  value: (u["phone"] ?? "-").toString(),
                ),
                const _DividerLine(),
                _InfoRow(
                  icon: Icons.apartment_outlined,
                  title: 'Department',
                  value: (u["department"] ?? "-").toString(),
                ),
                const _DividerLine(),
                _InfoRow(
                  icon: Icons.work_outline,
                  title: 'Job Title',
                  value: (u["jobTitle"] ?? "-").toString(),
                ),
                const _DividerLine(),
                _InfoRow(
                  icon: Icons.calendar_month_outlined,
                  title: 'Date of Birth',
                  value: (u["dateOfBirth"] ?? "-").toString(),
                ),
                const _DividerLine(),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  value: (u["workLocationName"] ?? "Seeduwa").toString(),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _sectionTitle('Employment Details'),
            const SizedBox(height: 10),
            _infoCard(
              children: [
                _InfoRow(
                  icon: Icons.person_outline,
                  title: 'Reporting Manager',
                  value: (u["reportingManagerName"] ?? "-").toString(),
                ),
                const _DividerLine(),
                _InfoRow(
                  icon: Icons.calendar_month_outlined,
                  title: 'Join Date',
                  value: (u["dateOfJoining"] ?? "-").toString(),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _sectionTitle('Leave Balance Summary'),
            const SizedBox(height: 10),

            // Dynamic Leave Balance Summary
            _buildLeaveBalanceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveBalanceCard() {
    if (loadingLeave) {
      return _infoCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        children: const [
          Center(child: CircularProgressIndicator(
            color: Colors.blue,
            strokeWidth: 3,
          )),
        ],
      );
    }

    if (leaveError != null) {
      return _infoCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        children: [
          Text("Leave error: $leaveError"),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _loadLeaveBalance,
            child: const Text("Retry"),
          ),
        ],
      );
    }

    // When user has no leave balance data, show 0/0 for each type (same as dashboard)
    final balance = leaveBalance ?? {};
    double d(dynamic v) => double.tryParse(v?.toString() ?? "0") ?? 0;

    final annualRemaining = d(balance["annual_days"]);
    final medicalRemaining = d(balance["medical_days"]);
    final casualRemaining = d(balance["casual_days"]);

    // Use API totals; when user has no leaves of any type, show 0/0
    final annualTotal = d(balance["annual_total"]);
    final medicalTotal = d(balance["medical_total"]);
    final casualTotal = d(balance["casual_total"]);

    final annualUsed = (annualTotal - annualRemaining).clamp(0.0, annualTotal).toDouble();
    final medicalUsed = (medicalTotal - medicalRemaining).clamp(0.0, medicalTotal).toDouble();
    final casualUsed = (casualTotal - casualRemaining).clamp(0.0, casualTotal).toDouble();

    return _infoCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      children: [
        _LeaveBar(title: 'Annual Leaves', used: annualUsed, total: annualTotal),
        const SizedBox(height: 12),
        _LeaveBar(title: 'Medical Leaves', used: medicalUsed, total: medicalTotal),
        const SizedBox(height: 12),
        _LeaveBar(title: 'Casual Leaves', used: casualUsed, total: casualTotal),
      ],
    );
  }

  // ---------------- UI Widgets ----------------
Widget _profileCard(Color blue, Map<String, dynamic> user) {
  final name = (user["name"] ?? "").toString();
  final department = (user["department"] ?? "").toString();
  final employeeCode = (user["employeeCode"] ?? "").toString();

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(
        colors: [
          Color(0xFF1565C0), // Dark Blue
          Color(0xFF42A5F5), // Light Blue
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        /// PROFILE IMAGE
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 84,
            height: 84,
            child: profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty
                ? Image.network(
                    profilePhotoUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;

                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/profile.png',
                        fit: BoxFit.cover,
                      );
                    },
                  )
                : Image.asset(
                    'assets/profile.png',
                    fit: BoxFit.cover,
                  ),
          ),
        ),

        const SizedBox(width: 14),

        /// USER DETAILS
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name.isEmpty ? "Unknown" : name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                department.isEmpty
                    ? "No Department"
                    : "$department Department",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "Code: ${employeeCode.isEmpty ? "-" : employeeCode}",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  Widget _sectionTitle(String title) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 18, color: Color(0xFF1E88E5)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E2A3A),
          ),
        ),
      ],
    );
  }

  Widget _infoCard({required List<Widget> children, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(children: children),
    );
  }
}

// ---------------- SMALL WIDGETS ----------------

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1E88E5)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7A90),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF1E2A3A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFEAEFF6)),
    );
  }
}

// Color by usage: green (low) → blue (middle) → red (near total)
Color _leaveProgressColor(double value) {
  final v = value.clamp(0.0, 1.0);
  if (v <= 0.5) {
    return Color.lerp(Colors.green, Colors.blue, v / 0.5)!;
  }
  return Color.lerp(Colors.blue, Colors.red, (v - 0.5) / 0.5)!;
}

class _LeaveBar extends StatelessWidget {
  final String title;
  final double used;
  final double total;

  const _LeaveBar({required this.title, required this.used, required this.total});

  @override
  Widget build(BuildContext context) {
    final remaining = total - used;
    final ratio = total == 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    String fmt(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2A3A),
                ),
              ),
            ),
            Text(
              '${fmt(used)}/${fmt(total)}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E88E5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            valueColor: AlwaysStoppedAnimation<Color>(_leaveProgressColor(ratio)),
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Used: ${fmt(used)} days   •   Remaining: ${fmt(remaining)} days',
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF6B7A90),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
