import 'package:flutter/material.dart';
import '../Services/ticket_api_service.dart';
import '../Services/api_service.dart';
import 'my_tickets_screen.dart' show ticketStatusPill, ticketTimeAgo;
import 'ticket_conversation_screen.dart';

class AgentInboxScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AgentInboxScreen({super.key, required this.user});

  @override
  State<AgentInboxScreen> createState() => _AgentInboxScreenState();
}

class _AgentInboxScreenState extends State<AgentInboxScreen> {
  int _selectedTab = 0;
  bool _loading = false;
  String? _errorText;
  List<Map<String, dynamic>> _tickets = [];

  static const _tabs = ['All', 'Open', 'In Progress', 'Resolved'];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      setState(() { _loading = true; _errorText = null; });
      final res = await TicketApiService.getAgentTickets();
      final list = List<Map<String, dynamic>>.from(res["data"] ?? []);
      if (mounted) setState(() => _tickets = list);
    } catch (e) {
      if (mounted) setState(() => _errorText = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filtered() {
    if (_selectedTab == 0) return _tickets;
    final statusMap = {1: 'open', 2: 'in_progress', 3: 'resolved'};
    final s = statusMap[_selectedTab]!;
    return _tickets.where((t) => (t["status"] ?? "") == s).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'IT Support — Agent Inbox',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E2A3A)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF1565C0),
        backgroundColor: Colors.white,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
          itemCount: filtered.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SegmentTabs(
                      labels: _tabs,
                      selectedIndex: _selectedTab,
                      onChanged: (i) => setState(() => _selectedTab = i),
                    ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator(
                          color: Color(0xFF1565C0), strokeWidth: 2)),
                    ),
                  if (!_loading && _errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(_errorText!, textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54, fontSize: 13)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                            label: const Text('Retry',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  if (!_loading && _errorText == null && filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          const Icon(Icons.inbox_outlined,
                              size: 56, color: Color(0xFFCCD5E0)),
                          const SizedBox(height: 12),
                          Text(
                            _selectedTab == 0
                                ? 'No tickets in the system'
                                : 'No ${_tabs[_selectedTab].toLowerCase()} tickets',
                            style: const TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w700, color: Color(0xFF8A97AD)),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }

            final t = filtered[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AgentTicketCard(
                ticket: t,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TicketConversationScreen(
                        ticketId: int.tryParse((t["id"] ?? "").toString()) ?? 0,
                        user: widget.user,
                        isAgent: true,
                      ),
                    ),
                  );
                  _refresh();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented tabs (local copy — same logic as MyTicketsScreen)
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _pill(labels[i], i),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, int index) {
    final active = selectedIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0B5FA5) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10, offset: const Offset(0, 6))]
                : [],
          ),
          child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Agent ticket card — shows employee name + avatar + open-ticket accent
// ─────────────────────────────────────────────────────────────────────────────

class _AgentTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  const _AgentTicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status    = (ticket["status"] ?? "").toString();
    final title     = (ticket["title"] ?? "").toString();
    final platform  = (ticket["platformName"] ?? "").toString();
    final issue     = (ticket["issueTitle"] ?? "").toString();
    final updatedAt = (ticket["updatedAt"] ?? ticket["createdAt"] ?? "").toString();
    final unread    = int.tryParse((ticket["unreadCount"] ?? "0").toString()) ?? 0;
    final empName   = (ticket["employeeName"] ?? "").toString();
    final empId     = int.tryParse((ticket["employeeId"] ?? "").toString()) ?? 0;

    // Accent color per status
    final accentColor = status == 'open'
        ? const Color(0xFFFFB300)
        : status == 'in_progress'
            ? const Color(0xFF1565C0)
            : const Color(0xFF2E7D32);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EDF5)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar — colour reflects status
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Employee row ──────────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _EmployeeAvatar(id: empId, name: empName, radius: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    empName.isNotEmpty ? empName : 'Employee',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E2A3A),
                                    ),
                                  ),
                                  const Text(
                                    'Reported a support ticket',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF8A97AD),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Unread badge — top-right corner of card
                            if (unread > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD10A0A),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('$unread new',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    )),
                              ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ── Ticket title + status pill ────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ticketStatusPill(status),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // ── Platform · Issue + time ───────────────────────
                        Row(
                          children: [
                            const Icon(Icons.devices_outlined,
                                size: 12, color: Color(0xFFAAB4C4)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                platform +
                                    (issue.isNotEmpty ? '  ·  $issue' : ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFFAAB4C4),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 11, color: Color(0xFFCCD5E0)),
                                const SizedBox(width: 3),
                                Text(
                                  ticketTimeAgo(updatedAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFAAB4C4),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Employee avatar — same pattern as _CompanionPhoto in my_trip_screen
// ─────────────────────────────────────────────────────────────────────────────

class _EmployeeAvatar extends StatefulWidget {
  final int    id;
  final String name;
  final double radius;

  const _EmployeeAvatar({required this.id, required this.name, this.radius = 16});

  @override
  State<_EmployeeAvatar> createState() => _EmployeeAvatarState();
}

class _EmployeeAvatarState extends State<_EmployeeAvatar> {
  late final Future<Map<String, dynamic>?> _photoFuture;

  static const _colors = [
    Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100),
  ];

  @override
  void initState() {
    super.initState();
    _photoFuture = ApiService.getProfilePhoto(employeeId: widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final parts    = widget.name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty ? parts[0][0].toUpperCase() : '?');
    final bgColor = _colors[widget.id % _colors.length];
    final size    = widget.radius * 2;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _photoFuture,
      builder: (_, snap) {
        final url = (snap.data?['fileUrl'] ?? '').toString().trim();
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: url.isNotEmpty ? null : bgColor,
            shape: BoxShape.circle,
            image: url.isNotEmpty
                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                : null,
          ),
          child: url.isEmpty
              ? Center(
                  child: Text(initials,
                      style: TextStyle(
                          fontSize: widget.radius * 0.6,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)))
              : null,
        );
      },
    );
  }
}
