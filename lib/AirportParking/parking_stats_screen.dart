import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../Services/parking_stats_service.dart';

class ParkingStatsScreen extends StatefulWidget {
  const ParkingStatsScreen({super.key});

  @override
  State<ParkingStatsScreen> createState() => _ParkingStatsScreenState();
}

class _ParkingStatsScreenState extends State<ParkingStatsScreen> {
  static const _bg = Color(0xFFF5F7FA);

  late DateTime _fromDate;
  late DateTime _toDate;
  late int _revenueYear;
  int? _revenueMonth;

  Future<ParkingDashboardData>? _future;

  // Quick-select chips
  static const _quickLabels = ['Today', 'Yesterday', 'This Week', 'This Month'];
  int _activeQuick = 0; // 0 = Today

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _fromDate = today;
    _toDate = today;
    _revenueYear = today.year;
    _revenueMonth = null;
    _load();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _load() {
    setState(() {
      _future = ParkingStatsService.fetchDashboard(
        startDate: ParkingStatsService.formatApiDate(_fromDate),
        endDate: ParkingStatsService.formatApiDate(_toDate),
        year: _revenueYear.toString(),
        month: _revenueMonth?.toString(),
      );
    });
  }

  void _applyQuick(int index) {
    final today = _dateOnly(DateTime.now());
    DateTime from;
    DateTime to;
    switch (index) {
      case 0: // Today
        from = to = today;
        break;
      case 1: // Yesterday
        from = to = today.subtract(const Duration(days: 1));
        break;
      case 2: // This Week
        final weekday = today.weekday; // 1=Mon … 7=Sun
        from = today.subtract(Duration(days: weekday - 1));
        to = today;
        break;
      case 3: // This Month
        from = DateTime(today.year, today.month, 1);
        to = today;
        break;
      default:
        from = to = today;
    }
    setState(() {
      _activeQuick = index;
      _fromDate = from;
      _toDate = to;
    });
    _load();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
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
        _activeQuick = -1; // custom
        _fromDate = _dateOnly(picked.start);
        _toDate = _dateOnly(picked.end);
      });
      _load();
    }
  }

  Future<void> _pickRevenueYear() async {
    final now = DateTime.now();
    final years = List.generate(6, (i) => now.year - i);

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _YearMonthPicker(
        years: years,
        selectedYear: _revenueYear,
        selectedMonth: _revenueMonth,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _revenueYear = selected['year'] as int;
        _revenueMonth = selected['month'] as int?;
      });
      _load();
    }
  }

  String _dateRangeLabel() {
    final fmt = DateFormat('d MMM yyyy');
    if (_fromDate == _toDate ||
        (_fromDate.year == _toDate.year &&
            _fromDate.month == _toDate.month &&
            _fromDate.day == _toDate.day)) {
      return fmt.format(_fromDate);
    }
    return '${DateFormat('d MMM').format(_fromDate)} – ${fmt.format(_toDate)}';
  }

  String _revenueFilterLabel() {
    if (_revenueMonth != null) {
      final monthName = DateFormat('MMMM').format(DateTime(_revenueYear, _revenueMonth!));
      return '$monthName $_revenueYear';
    }
    return '$_revenueYear';
  }

  String _revenueTypeLabel(String rawType) {
    switch (rawType) {
      case 'current_year_default':
        return 'Annual Revenue ($_revenueYear)';
      case 'current_month_default':
        return 'Monthly Revenue';
      case 'date_range':
        return 'Revenue for Period';
      default:
        return 'Revenue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          'Parking Dashboard',
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
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _FiltersBar(
            quickLabels: _quickLabels,
            activeQuick: _activeQuick,
            dateRangeLabel: _dateRangeLabel(),
            revenueFilterLabel: _revenueFilterLabel(),
            onQuickTap: _applyQuick,
            onCustomTap: _pickCustomRange,
            onRevenueTap: _pickRevenueYear,
          ),
          Expanded(
            child: FutureBuilder<ParkingDashboardData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _LoadingView();
                }
                if (snap.hasError) {
                  return _ErrorView(
                    message: snap.error.toString().replaceFirst('Exception: ', ''),
                    onRetry: _load,
                  );
                }
                final data = snap.data!;
                return _DashboardBody(
                  data: data,
                  revenueTypeLabel: _revenueTypeLabel(data.stats.revenueType),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filters Bar ─────────────────────────────────────────────────────────────

class _FiltersBar extends StatelessWidget {
  final List<String> quickLabels;
  final int activeQuick;
  final String dateRangeLabel;
  final String revenueFilterLabel;
  final ValueChanged<int> onQuickTap;
  final VoidCallback onCustomTap;
  final VoidCallback onRevenueTap;

  const _FiltersBar({
    required this.quickLabels,
    required this.activeQuick,
    required this.dateRangeLabel,
    required this.revenueFilterLabel,
    required this.onQuickTap,
    required this.onCustomTap,
    required this.onRevenueTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick-select chips row
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: quickLabels.length + 1, // +1 for custom
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i < quickLabels.length) {
                  final isActive = activeQuick == i;
                  return _Chip(
                    label: quickLabels[i],
                    isActive: isActive,
                    onTap: () => onQuickTap(i),
                  );
                }
                // Custom date range chip
                return _Chip(
                  label: activeQuick == -1 ? dateRangeLabel : 'Custom',
                  isActive: activeQuick == -1,
                  icon: Icons.date_range_rounded,
                  onTap: onCustomTap,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Revenue filter row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bar_chart_rounded, size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 5),
              Text(
                'Revenue Filter:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRevenueTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        revenueFilterLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: Color(0xFF1565C0)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;
  final IconData? icon;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isActive,
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
          color: isActive ? const Color(0xFF1565C0) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFF1565C0)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: isActive ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Body ───────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  final ParkingDashboardData data;
  final String revenueTypeLabel;

  const _DashboardBody({required this.data, required this.revenueTypeLabel});

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    final handover = data.handover;
    final fmt = NumberFormat('#,##0', 'en_US');

    return RefreshIndicator(
      color: Colors.blue,
      backgroundColor: Colors.white,
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // ── Revenue Hero Card (top) ──
          _RevenueCard(
            revenue: stats.revenue,
            revenueTypeLabel: revenueTypeLabel,
            formatted: 'LKR ${fmt.format(stats.revenue)}',
            totalBookings: stats.totalBookings,
            startDate: data.startDate,
            endDate: data.endDate,
          ),
          const SizedBox(height: 16),

          // // ── Period label ──
          // _PeriodHeader(startDate: data.startDate, endDate: data.endDate),
          const SizedBox(height: 20),

          // ── Stats Grid ──
          _SectionTitle(label: 'Parking Activity'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _StatCard(
                label: 'Currently Parked',
                value: stats.totalParkedVehicles.toString(),
                icon: Icons.local_parking_rounded,
                color: const Color(0xFF1565C0),
                bgColor: const Color(0xFFEEF4FF),
              ),
              _StatCard(
                label: 'Active Sessions',
                value: stats.activeParkingCount.toString(),
                icon: Icons.directions_car_rounded,
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
              ),
              _StatCard(
                label: 'Completed',
                value: stats.totalCompletedParking.toString(),
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
              ),
              _StatCard(
                label: 'Total Bookings',
                value: stats.totalBookings.toString(),
                icon: Icons.bookmark_outline_rounded,
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Handover Card ──
          _SectionTitle(label: 'Cash Handover'),
          const SizedBox(height: 10),
          _HandoverCard(handover: handover, fmt: fmt),
        ],
      ),
    );
  }
}


class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1E2A3A),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
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

class _RevenueCard extends StatelessWidget {
  final int revenue;
  final String revenueTypeLabel;
  final String formatted;
  final int totalBookings;
  final String startDate;
  final String endDate;

  const _RevenueCard({
    required this.revenue,
    required this.revenueTypeLabel,
    required this.formatted,
    required this.totalBookings,
    required this.startDate,
    required this.endDate,
  });

  String _shortDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      return DateFormat('d MMM yyyy').format(d);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSameDay = startDate == endDate;
    final periodLabel = isSameDay
        ? _shortDate(startDate)
        : '${_shortDate(startDate)} – ${_shortDate(endDate)}';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A6FD4), Color(0xFF003580)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.38),
            blurRadius: 22,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Decorative circles ──
            Positioned(
              right: -28,
              top: -28,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              right: 32,
              bottom: -40,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: label + icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bar_chart_rounded,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              revenueTypeLabel,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Revenue label
                  Text(
                    'Total Revenue',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Big amount
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatted,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        height: 1.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 14),

                  // Bottom row: period + bookings
                  Row(
                    children: [
                      // Period
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 12, color: Colors.white70),
                          const SizedBox(width: 5),
                          Text(
                            periodLabel,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Bookings pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bookmark_rounded,
                                size: 11, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              '$totalBookings Bookings',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

class _HandoverCard extends StatelessWidget {
  final ParkingHandover handover;
  final NumberFormat fmt;

  const _HandoverCard({required this.handover, required this.fmt});

  String _formatDatetime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final d = DateTime.parse(raw);
      return DateFormat('d MMM yyyy, h:mm a').format(d);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8EF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash Handover',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E2A3A),
                        ),
                      ),
                      if (!handover.hasHandover)
                        Text(
                          'No handover recorded',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
                // Amount badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: handover.cashHandover > 0
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: handover.cashHandover > 0
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    'LKR ${fmt.format(handover.cashHandover)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: handover.cashHandover > 0
                          ? const Color(0xFFD97706)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
            if (handover.hasHandover) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
              _HandoverRow(
                icon: Icons.person_outline_rounded,
                label: 'Handed over by',
                value: handover.handoverByName ?? '—',
              ),
              const SizedBox(height: 8),
              _HandoverRow(
                icon: Icons.schedule_rounded,
                label: 'Date & Time',
                value: _formatDatetime(handover.handoverDatetime),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HandoverRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HandoverRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 7),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E2A3A),
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Loading / Error States ───────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF1565C0),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading dashboard...',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFEF4444),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load data',
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
            const SizedBox(height: 20),
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
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Year / Month Picker Bottom Sheet ────────────────────────────────────────

class _YearMonthPicker extends StatefulWidget {
  final List<int> years;
  final int selectedYear;
  final int? selectedMonth;

  const _YearMonthPicker({
    required this.years,
    required this.selectedYear,
    this.selectedMonth,
  });

  @override
  State<_YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<_YearMonthPicker> {
  late int _year;
  int? _month;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.selectedYear;
    _month = widget.selectedMonth;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Revenue Period',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E2A3A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Year',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.years.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final y = widget.years[i];
                  final isSelected = _year == y;
                  return GestureDetector(
                    onTap: () => setState(() => _year = y),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1565C0)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        y.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Month (optional — leave blank for full year)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // "All Year" chip
                GestureDetector(
                  onTap: () => setState(() => _month = null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _month == null
                          ? const Color(0xFF1565C0)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'All Year',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _month == null
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                ..._months.asMap().entries.map((e) {
                  final idx = e.key + 1;
                  final isSelected = _month == idx;
                  return GestureDetector(
                    onTap: () => setState(() => _month = idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1565C0)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        e.value.substring(0, 3),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, {'year': _year, 'month': _month}),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Apply',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
