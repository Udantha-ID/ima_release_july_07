import 'package:flutter/material.dart';
import 'package:test_app/VehicleUtilization/vehicle_utilization_screen.dart';
import 'package:test_app/AirportParking/parking_stats_screen.dart';
import 'package:test_app/Reports/sr_booking_dashboard_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Reports'),
        surfaceTintColor: Colors.white,
        backgroundColor: const Color(0xFFF5F7FA),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          const SizedBox(height: 20),
          const _ReportSectionTitle('Fleet & parking'),
          const SizedBox(height: 8),
          _ReportCard(
            item: _ReportItem(
              title: 'Vehicle Utilization',
              subtitle:
                  'View vehicle usage, utilization and status insights',
              imagePath: 'assets/vehicleUtilization.png',
              icon: Icons.pie_chart_outline,
              color: const Color(0xFF0B63CE),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VehicleUtilizationScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            item: _ReportItem(
              title: 'Parking Dashboard',
              subtitle:
                  'Bookings, active sessions, revenue & handover overview',
              imagePath: 'assets/airportparking.png',
              icon: Icons.local_parking_rounded,
              color: const Color(0xFF1565C0),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ParkingStatsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const _ReportSectionTitle('SR Rent A Car'),
          const SizedBox(height: 8),
          _ReportCard(
            item: _ReportItem(
              title: 'Booking dashboard',
              subtitle:
                  'Contact inquiries, WhatsApp, email & active enquiries',
              imagePath: 'assets/sr.png',
              icon: Icons.dashboard_outlined,
              color: const Color(0xFF1565C0),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SrBookingDashboardScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSectionTitle extends StatelessWidget {
  final String title;

  const _ReportSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final _ReportItem item;

  const _ReportCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E8EF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (item.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    item.imagePath!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2A3A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7A90),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Color(0xFF7F8A99)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportItem {
  final String title;
  final String subtitle;
  final String? imagePath;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ReportItem({
    required this.title,
    required this.subtitle,
    this.imagePath,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
