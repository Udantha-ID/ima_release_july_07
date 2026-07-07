import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Services/ticket_api_service.dart';
import 'create_ticket_screen.dart';
import 'ticket_conversation_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const MyTicketsScreen({super.key, required this.user});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  int _selectedTab = 0;
  bool _loading = false;
  String? _errorText;
  List<Map<String, dynamic>> _tickets = [];

  static const _tabs = ['All', 'Open', 'In Progress', 'Resolved'];

  String _employeeId() {
    final u = widget.user;
    final v = u["employee_id"] ?? u["employeeId"] ?? u["id"] ?? u["user_id"];
    return (v ?? "").toString().trim();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      setState(() { _loading = true; _errorText = null; });
      final res = await TicketApiService.getMyTickets(employeeId: _employeeId());
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
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'IT Support Desk',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF1E2A3A)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF1565C0), size: 28),
            tooltip: 'New Ticket',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateTicketScreen(user: widget.user)),
              );
              _refresh();
            },
          ),
        ],
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
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF1565C0), strokeWidth: 2)),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                            label: const Text('Retry', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  if (!_loading && _errorText == null && filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          const Icon(Icons.confirmation_number_outlined,
                              size: 56, color: Color(0xFFCCD5E0)),
                          const SizedBox(height: 12),
                          const Text('No tickets found',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF8A97AD))),
                          const SizedBox(height: 6),
                          const Text('Tap + to raise a new support ticket',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFFAAB4C4))),
                        ],
                      ),
                    ),
                ],
              );
            }

            final t = filtered[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TicketCard(
                ticket: t,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TicketConversationScreen(
                        ticketId: int.tryParse((t["id"] ?? "").toString()) ?? 0,
                        user: widget.user,
                        isAgent: false,
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
      floatingActionButton: (!_loading && _errorText == null && _tickets.isEmpty)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1565C0),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreateTicketScreen(user: widget.user)),
                );
                _refresh();
              },
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Ticket',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented tabs
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
// Ticket card
// ─────────────────────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status      = (ticket["status"] ?? "").toString();
    final title       = (ticket["title"] ?? "").toString();
    final description = (ticket["description"] ?? "").toString();
    final updatedAt   = (ticket["updatedAt"] ?? ticket["createdAt"] ?? "").toString();
    final unread      = int.tryParse((ticket["unreadCount"] ?? "0").toString()) ?? 0;

    // Don't repeat issue title in chip when it matches the ticket title

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
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left status accent bar
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
                // Card content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title + status pill ───────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E2A3A),
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ticketStatusPill(status),
                          ],
                        ),
                        // ── Description preview ──────────────────────────
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8A97AD),
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 9),
                        // ── Time + unread badge ───────────────────────────
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 11, color: Color(0xFFCCD5E0)),
                            const SizedBox(width: 4),
                            Text(
                              ticketTimeAgo(updatedAt),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFAAB4C4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (unread > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD10A0A),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$unread new',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
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
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers (used by my_tickets and agent_inbox)
// ─────────────────────────────────────────────────────────────────────────────

Widget ticketStatusPill(String status) {
  Color bg, border, text, iconColor;
  IconData icon;
  String label;

  switch (status) {
    case 'open':
      bg = const Color(0xFFFFF3CD); border = const Color(0xFFFFE49A);
      text = const Color(0xFF8A6D3B); iconColor = const Color(0xFF8A6D3B);
      icon = Icons.hourglass_bottom; label = 'Open'; break;
    case 'in_progress':
      bg = const Color(0xFFE3F2FD); border = const Color(0xFF90CAF9);
      text = const Color(0xFF1565C0); iconColor = const Color(0xFF1565C0);
      icon = Icons.chat_bubble_outline; label = 'In Progress'; break;
    case 'resolved':
      bg = const Color(0xFFCDEED3); border = const Color(0xFF9AD7A6);
      text = const Color(0xFF2E7D32); iconColor = const Color(0xFF2E7D32);
      icon = Icons.check_circle; label = 'Resolved'; break;
    default:
      // Unknown / loading state — neutral grey so it doesn't mislead
      bg = const Color(0xFFEEEEEE); border = const Color(0xFFDDDDDD);
      text = const Color(0xFF9E9E9E); iconColor = const Color(0xFF9E9E9E);
      icon = Icons.help_outline; label = '—';
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: text)),
      ],
    ),
  );
}

String ticketTimeAgo(String dateStr) {
  if (dateStr.isEmpty) return '';
  try {
    final dt   = DateTime.parse(dateStr);
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  } catch (_) {
    return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
  }
}
