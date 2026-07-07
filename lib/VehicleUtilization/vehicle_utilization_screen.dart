import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_app/Constants/app_colors.dart';
import 'package:test_app/Models/vehicle_utilization_model.dart';
import 'package:test_app/Services/vehicle_utilization_service.dart';

class VehicleUtilizationScreen extends StatefulWidget {
  final String? from;
  final String? to;

  const VehicleUtilizationScreen({
    super.key,
    this.from,
    this.to,
  });

  @override
  State<VehicleUtilizationScreen> createState() =>
      _VehicleUtilizationScreenState();
}

class _VehicleUtilizationScreenState extends State<VehicleUtilizationScreen> {
  /// Filter tabs: always show all standard utilization statuses (counts may be 0).
  static const List<String> _kFilterStatusTabs = [
    'Excellent',
    'Not Utilized',
    'Good',
    'Fair',
    'Under Utilized',
  ];

  late Future<VehicleUtilizationResponse> _future;
  late DateTime _fromDate;
  late DateTime _toDate;
  String _searchQuery = '';
  int _selectedStatusFilter = 0; // 0 = All, 1..5 = _kFilterStatusTabs index
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    if (widget.from?.trim().isNotEmpty == true) {
      _fromDate = _dateOnly(VehicleUtilizationService.parseApiDate(widget.from!));
      _toDate = widget.to?.trim().isNotEmpty == true
          ? _dateOnly(VehicleUtilizationService.parseApiDate(widget.to!))
          : _fromDate;
    } else {
      _fromDate = today;
      _toDate = today;
    }
    _future = _fetchVehicleUtilization();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    final x = _dateOnly(a);
    final y = _dateOnly(b);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  Future<VehicleUtilizationResponse> _fetchVehicleUtilization() async {
    final fromStr = VehicleUtilizationService.formatApiDate(_fromDate);
    // Single day: API expects only `from` (e.g. ?from=2026-04-01).
    if (_isSameCalendarDay(_fromDate, _toDate)) {
      return VehicleUtilizationService.fetchUtilization(from: fromStr);
    }
    return VehicleUtilizationService.fetchUtilization(
      from: fromStr,
      to: VehicleUtilizationService.formatApiDate(_toDate),
    );
  }

  void _retry() {
    setState(() {
      _future = _fetchVehicleUtilization();
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _dateOnly(_fromDate),
        end: _dateOnly(_toDate),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryStart,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = _dateOnly(picked.start);
        _toDate = _dateOnly(picked.end);
        _future = _fetchVehicleUtilization();
      });
    }
  }

  Future<void> _selectSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOnly(_fromDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryStart,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final d = _dateOnly(picked);
      setState(() {
        _fromDate = d;
        _toDate = d;
        _future = _fetchVehicleUtilization();
      });
    }
  }

  void _resetToToday() {
    final t = _dateOnly(DateTime.now());
    setState(() {
      _fromDate = t;
      _toDate = t;
      _future = _fetchVehicleUtilization();
    });
  }

  String _periodTitleText() {
    if (_isSameCalendarDay(_fromDate, _toDate)) {
      return _formatDisplayDateLong(_fromDate);
    }
    return '${_formatDisplayDate(_fromDate)} – ${_formatDisplayDate(_toDate)}';
  }

  List<VehicleUtilizationItem> _filterVehicles(List<VehicleUtilizationItem> vehicles) {
    if (_searchQuery.trim().isEmpty) return vehicles;
    final query = _searchQuery.toLowerCase();
    return vehicles
        .where((v) => v.vehicleNo.toLowerCase().contains(query))
        .toList();
  }

  Map<String, int> _statusCounts(List<VehicleUtilizationItem> vehicles) {
    final map = <String, int>{};
    for (final v in vehicles) {
      final key = v.utilizationStatus.trim().isEmpty ? 'Unknown' : v.utilizationStatus.trim();
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  List<VehicleUtilizationItem> _applyStatusFilter(
    List<VehicleUtilizationItem> vehicles,
    List<String> statusTabs,
  ) {
    if (_selectedStatusFilter == 0) return vehicles;
    final idx = _selectedStatusFilter - 1;
    if (idx < 0 || idx >= statusTabs.length) return vehicles;
    final selected = statusTabs[idx];
    return vehicles
        .where((v) {
          final status = v.utilizationStatus.trim().isEmpty ? 'Unknown' : v.utilizationStatus.trim();
          return status == selected;
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        backgroundColor: const Color(0xFFF5F7FA),
        title: Text(
          'Vehicle Utilization',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: FutureBuilder<VehicleUtilizationResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading data...',
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load utilization data',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryStart,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final result = snapshot.data!;
          final allVehicles = result.data;
          final searchFilteredVehicles = _filterVehicles(allVehicles);
          final statusCounts = _statusCounts(searchFilteredVehicles);
          final filteredVehicles = _applyStatusFilter(
            searchFilteredVehicles,
            _kFilterStatusTabs,
          );
          
          final averageUsage = allVehicles.isEmpty
              ? 0.0
              : allVehicles.map((e) => e.usagePercent).reduce((a, b) => a + b) /
                  allVehicles.length;
          
          final statusCount = _buildStatusCount(allVehicles);

          return RefreshIndicator(
            onRefresh: () async => _retry(),
            color: Colors.blue,
            backgroundColor: Colors.white,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Date Range Card
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryStart, AppColors.primaryEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryStart.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Period',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _periodTitleText(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${result.period.totalDays} day${result.period.totalDays == 1 ? '' : 's'}',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.edit_calendar, color: Colors.white),
                        tooltip: 'Change period',
                        color: Colors.white,
                        onSelected: (value) {
                          switch (value) {
                            case 'today':
                              _resetToToday();
                              break;
                            case 'single':
                              _selectSingleDate();
                              break;
                            case 'range':
                              _selectDateRange();
                              break;
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'today',
                            child: Text('Today'),
                          ),
                          PopupMenuItem(
                            value: 'single',
                            child: Text('One day…'),
                          ),
                          PopupMenuItem(
                            value: 'range',
                            child: Text('Date range…'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.directions_car,
                        title: 'Total Vehicles',
                        value: result.totals.vehicles.toString(),
                        color: const Color(0xFF003580),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.check_circle,
                        title: 'Utilized',
                        value: result.totals.utilizedVehicles.toString(),
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.cancel,
                        title: 'Not Utilized',
                        value: result.totals.notUtilizedVehicles.toString(),
                        color: const Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.analytics,
                        title: 'Avg Usage',
                        value: '${averageUsage.toStringAsFixed(1)}%',
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Donut Chart
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Utilized vs Not Utilized',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pie Chart
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 380 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.05;

                          final legendWidth = compact ? 126.0 : 142.0;
                          final chartSize = max(
                            138.0,
                            min(
                              compact ? 182.0 : 196.0,
                              constraints.maxWidth - legendWidth - 28,
                            ),
                          );

                          final totalVehicles = max(result.totals.vehicles, 1);
                          final utilizedFrac =
                              result.totals.utilizedVehicles / totalVehicles;
                          final px = chartSize.floorToDouble().clamp(120.0, 240.0);

                          Widget chartWidget = SizedBox(
                            width: px,
                            height: px,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                RepaintBoundary(
                                  child: ColoredBox(
                                    color: Colors.white,
                                    child: CustomPaint(
                                      size: Size(px, px),
                                      painter: _UtilizationDonutPainter(
                                        utilizedFraction: utilizedFrac,
                                        utilizedColor: const Color(0xFF1565C0),
                                        notUtilizedColor: const Color(0xFFFF9800),
                                        devicePixelRatio:
                                            MediaQuery.devicePixelRatioOf(
                                                context),
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      result.totals.vehicles.toString(),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 20,
                                        color: const Color(0xFF1E2A3A),
                                      ),
                                    ),
                                    Text(
                                      'Total',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );

                          Widget legendWidget = Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: legendWidth,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _LegendItem(
                                    color: const Color(0xFF1565C0),
                                    label: 'Utilized',
                                    count: result.totals.utilizedVehicles,
                                    percentage: _percentage(
                                      result.totals.utilizedVehicles,
                                      result.totals.vehicles,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _LegendItem(
                                    color: const Color(0xFFFF9800),
                                    label: 'Not Utilized',
                                    count: result.totals.notUtilizedVehicles,
                                    percentage: _percentage(
                                      result.totals.notUtilizedVehicles,
                                      result.totals.vehicles,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Center(child: chartWidget),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 4,
                                child: legendWidget,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Status Overview
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pie_chart, color: AppColors.primaryStart),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Utilization Status Overview',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _showUtilizationRangeGuide(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryStart.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.primaryStart,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: statusCount.entries.map((entry) {
                          return _StatusChip(
                            title: entry.key,
                            count: entry.value,
                            total: allVehicles.length,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by vehicle number...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primaryStart),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.black38),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Status filter chips — centered when they fit; horizontal scroll when overflow
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _VehicleFilterChip(
                              label: 'All (${searchFilteredVehicles.length})',
                              active: _selectedStatusFilter == 0,
                              onTap: () => setState(() => _selectedStatusFilter = 0),
                            ),
                            ...List.generate(_kFilterStatusTabs.length, (i) {
                              final status = _kFilterStatusTabs[i];
                              final count = statusCounts[status] ?? 0;
                              final selected = _selectedStatusFilter == i + 1;
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _VehicleFilterChip(
                                  label: '$status ($count)',
                                  active: selected,
                                  onTap: () => setState(() => _selectedStatusFilter = i + 1),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Vehicle List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Vehicle List',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryStart.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${filteredVehicles.length} vehicles',
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryStart,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Vehicle Cards
                if (filteredVehicles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No vehicles found',
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredVehicles.map((vehicle) {
                    return _VehicleCard(vehicle: vehicle);
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showUtilizationRangeGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.speed_rounded, color: AppColors.primaryStart),
                  const SizedBox(width: 8),
                  Text(
                    'Utilization Range Guide',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'How vehicle utilization status is determined',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Gradient bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 28,
                  child: Row(
                    children: [
                      _BarSegment(flex: 1,  color: const Color(0xFFF44336), label: '0%'),
                      _BarSegment(flex: 49, color: const Color(0xFFFF9800), label: '1–49%'),
                      _BarSegment(flex: 15, color: const Color(0xFF1565C0), label: '50–64%'),
                      _BarSegment(flex: 11, color: const Color(0xFF8BC34A), label: '65–75%'),
                      _BarSegment(flex: 25, color: const Color(0xFF4CAF50), label: '>75%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Status rows
              const _RangeRow(
                color: Color(0xFFF44336),
                status: 'Not Utilized',
                range: '0%',
                icon: Icons.cancel_rounded,
              ),
              const _RangeRow(
                color: Color(0xFFFF9800),
                status: 'Under Utilized',
                range: '1% – 49%',
                icon: Icons.trending_down_rounded,
              ),
              const _RangeRow(
                color: Color(0xFF1565C0),
                status: 'Fair',
                range: '50% – 64%',
                icon: Icons.horizontal_rule_rounded,
              ),
              const _RangeRow(
                color: Color(0xFF8BC34A),
                status: 'Good',
                range: '65% – 75%',
                icon: Icons.trending_up_rounded,
              ),
              const _RangeRow(
                color: Color(0xFF4CAF50),
                status: 'Excellent',
                range: 'Above 75%',
                icon: Icons.check_circle_rounded,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BarSegment extends StatelessWidget {
  final int flex;
  final Color color;
  final String label;

  const _BarSegment({
    required this.flex,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        color: color,
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  final Color color;
  final String status;
  final String range;
  final IconData icon;

  const _RangeRow({
    required this.color,
    required this.status,
    required this.range,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF1E2A3A),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              range,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
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

/// Crisp donut ring drawn with [Canvas] (avoids third-party pie dithering on some Android GPUs).
class _UtilizationDonutPainter extends CustomPainter {
  _UtilizationDonutPainter({
    required this.utilizedFraction,
    required this.utilizedColor,
    required this.notUtilizedColor,
    required this.devicePixelRatio,
  });

  final double utilizedFraction;
  final Color utilizedColor;
  final Color notUtilizedColor;
  final double devicePixelRatio;

  static double _snapToDevicePixels(double logical, double dpr) {
    if (!dpr.isFinite || dpr <= 0) return logical;
    return (logical * dpr).round() / dpr;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final dpr = devicePixelRatio;
    final center = Offset(
      _snapToDevicePixels(w / 2, dpr),
      _snapToDevicePixels(h / 2, dpr),
    );
    final minSide = min(w, h);
    final stroke = _snapToDevicePixels(minSide * 0.22, dpr).clamp(8.0, minSide * 0.45);
    final radius = _snapToDevicePixels(
      (minSide / 2) * 0.92 - stroke / 2,
      dpr,
    ).clamp(stroke / 2 + 1, minSide / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, 0, 2 * pi, false, ring..color = notUtilizedColor);

    final frac = utilizedFraction.clamp(0.0, 1.0);
    final sweep = 2 * pi * frac;
    if (sweep > 1e-4) {
      canvas.drawArc(
        rect,
        -pi / 2,
        sweep,
        false,
        ring..color = utilizedColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UtilizationDonutPainter oldDelegate) {
    return oldDelegate.utilizedFraction != utilizedFraction ||
        oldDelegate.utilizedColor != utilizedColor ||
        oldDelegate.notUtilizedColor != notUtilizedColor ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final double percentage;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$count (${percentage.toStringAsFixed(1)}%)',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String title;
  final int count;
  final int total;

  const _StatusChip({
    required this.title,
    required this.count,
    required this.total,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return const Color(0xFF4CAF50);
      case 'good':
        return const Color(0xFF8BC34A);
      case 'fair':
        return const Color(0xFF1565C0);
      case 'under utilized':
        return const Color(0xFFFF9800);
      case 'not utilized':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(title);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$title: $count',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final VehicleUtilizationItem vehicle;

  const _VehicleCard({required this.vehicle});

  Color _getStatusColor() {
    if (vehicle.usagePercent >= 80) return const Color(0xFF4CAF50);
    if (vehicle.usagePercent >= 50) return const Color(0xFF8BC34A);
    if (vehicle.usagePercent >= 25) return const Color(0xFFFFEB3B);
    if (vehicle.usagePercent > 0) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  IconData _getStatusIcon() {
    if (vehicle.isUtilized) return Icons.check_circle;
    return Icons.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.vehicleNo,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        vehicle.company,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${vehicle.usagePercent.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.info_outline,
                    label: 'Status',
                    value: vehicle.vehicleStatus,
                  ),
                  const Divider(height: 16),
                  _InfoRow(
                    icon: Icons.assessment,
                    label: 'Utilization',
                    value: vehicle.utilizationStatus,
                  ),
                  const Divider(height: 16),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Used Days',
                    value: '${vehicle.usedDays}/${vehicle.totalDays} days',
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _VehicleFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _VehicleFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryStart : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primaryStart : const Color(0xFFE1E6EF),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF1E2A3A),
          ),
        ),
      ),
    );
  }
}

Map<String, int> _buildStatusCount(List<VehicleUtilizationItem> items) {
  final map = <String, int>{};
  for (final item in items) {
    final key = item.utilizationStatus.trim().isEmpty
        ? 'Unknown'
        : item.utilizationStatus.trim();
    map[key] = (map[key] ?? 0) + 1;
  }
  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final e in entries) e.key: e.value};
}

double _percentage(int value, int total) {
  if (total == 0) return 0;
  return (value / total) * 100;
}

String _formatDisplayDate(DateTime d) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
}

String _formatDisplayDateLong(DateTime d) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
}
