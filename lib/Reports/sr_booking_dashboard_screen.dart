import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:test_app/Services/sr_booking_dashboard_service.dart';

class SrBookingDashboardScreen extends StatefulWidget {
  const SrBookingDashboardScreen({super.key});

  @override
  State<SrBookingDashboardScreen> createState() =>
      _SrBookingDashboardScreenState();
}

class _SrBookingDashboardScreenState extends State<SrBookingDashboardScreen> {
  static const _bg = Color(0xFFF5F7FA);

  Future<SrBookingDashboardData>? _future;

  /// 0 = server default (no query), 1 = this_month, 2 = today, -1 = custom dates
  int _chipIndex = 1;
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, String>? _queryForChip() {
    switch (_chipIndex) {
      case 0:
        return null;
      case 1:
        return const {'type': 'this_month'};
      case 2:
        return const {'type': 'today'};
      case -1:
        if (_customFrom != null && _customTo != null) {
          final fmt = DateFormat('yyyy-MM-dd');
          return {
            'type': 'custom',
            'from_date': fmt.format(_customFrom!),
            'to_date': fmt.format(_customTo!),
          };
        }
        return const {'type': 'custom'};
      default:
        return null;
    }
  }

  Future<void> _reload() async {
    final future =
        SrBookingDashboardService.fetch(query: _queryForChip());
    if (mounted) setState(() => _future = future);
    await future;
  }

  void _setChip(int index) {
    setState(() => _chipIndex = index);
    _reload();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialStart = _customFrom ?? _dateOnly(now);
    final initialEnd = _customTo ?? initialStart;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1565C0),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _chipIndex = -1;
        _customFrom = _dateOnly(picked.start);
        _customTo = _dateOnly(picked.end);
      });
      _reload();
    }
  }

  String _filterSummary(SrBookingFilter f) {
    final type = f.type.trim().toLowerCase().replaceAll(' ', '_');
    String period;
    switch (type) {
      case 'this_month':
        period = 'This month';
        break;
      case 'today':
        period = 'Today';
        break;
      case 'custom':
      case 'custom_range':
      case 'range':
        final from = f.fromDate.trim();
        final to = f.toDate.trim();
        if (from.isNotEmpty && to.isNotEmpty) {
          try {
            final a = DateFormat('yyyy-MM-dd').parse(from);
            final b = DateFormat('yyyy-MM-dd').parse(to);
            period =
                '${DateFormat('d MMM yyyy').format(a)} – ${DateFormat('d MMM yyyy').format(b)}';
          } catch (_) {
            period = from.isNotEmpty ? '$from – $to' : 'Custom range';
          }
        } else {
          period = 'Custom range';
        }
        break;
      default:
        period = f.type.isEmpty ? 'Default' : f.type.replaceAll('_', ' ');
    }
    return period;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          'SR Booking Dashboard',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF1E2A3A),
          ),
        ),
        backgroundColor: _bg,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E2A3A)),
        actions: [
          IconButton(
            onPressed: () => _reload(),
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Period',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      _FilterChip(
                        label: 'Default',
                        selected: _chipIndex == 0,
                        onTap: () => _setChip(0),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'This month',
                        selected: _chipIndex == 1,
                        onTap: () => _setChip(1),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Today',
                        selected: _chipIndex == 2,
                        onTap: () => _setChip(2),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: _chipIndex == -1 &&
                                _customFrom != null &&
                                _customTo != null
                            ? '${DateFormat('d MMM').format(_customFrom!)} – ${DateFormat('d MMM').format(_customTo!)}'
                            : 'Custom',
                        selected: _chipIndex == -1,
                        icon: Icons.date_range_rounded,
                        onTap: _pickCustomRange,
                      ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<SrBookingDashboardData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1565C0),
                      strokeWidth: 3,
                    ),
                  );
                }
                if (snap.hasError) {
                  return _SrErrorBody(
                    message: snap.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    onRetry: () => _reload(),
                  );
                }
                final data = snap.data!;
                return RefreshIndicator(
                  color: const Color(0xFF1565C0),
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _FilterBanner(
                        summary: _filterSummary(data.filter),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Booking leads',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E2A3A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _SrStatCard(
                              label: 'Contact form',
                              value: data.contactFormInquiries.toString(),
                              icon: Icons.contact_mail_outlined,
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SrStatCard(
                              label: 'WhatsApp',
                              value: data.whatsappBookings.toString(),
                              icon: Icons.chat_rounded,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SrStatCard(
                              label: 'Direct email',
                              value: data.directEmailBookings.toString(),
                              icon: Icons.mail_outline_rounded,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SrStatCard(
                              label: 'Active enquiries',
                              value:
                                  data.activeBookingEnquiries.toString(),
                              icon: Icons.pending_actions_rounded,
                              color: const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'srilankarentacar.com',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF1565C0)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBanner extends StatelessWidget {
  final String summary;

  const _FilterBanner({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF003580)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 18, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Showing statistics for',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SrStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SrStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SrErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SrErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFEF4444),
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Could not load dashboard',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E2A3A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

