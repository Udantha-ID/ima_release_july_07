import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Services/ticket_api_service.dart';
import '../Services/api_service.dart';
import '../Leaves/top_banner.dart';
import '../ui/dialogs/resolve_ticket_dialog.dart';
import '../ui/dialogs/cancel_ticket_dialog.dart';
import 'my_tickets_screen.dart' show ticketStatusPill;

class TicketConversationScreen extends StatefulWidget {
  final int ticketId;
  final Map<String, dynamic> user;
  final bool isAgent;

  const TicketConversationScreen({
    super.key,
    required this.ticketId,
    required this.user,
    required this.isAgent,
  });

  @override
  State<TicketConversationScreen> createState() => _TicketConversationScreenState();
}

class _TicketConversationScreenState extends State<TicketConversationScreen> {
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _messages = [];
  bool _loadingDetail   = true;
  bool _loadingMessages = true;
  bool _sendingMessage  = false;
  bool _resolving       = false;
  bool _cancelling      = false;
  String? _detailError;

  final _msgController  = TextEditingController();
  final _scrollCtrl     = ScrollController();

  String _employeeId() {
    final u = widget.user;
    final v = u["employee_id"] ?? u["employeeId"] ?? u["id"] ?? u["user_id"];
    return (v ?? "").toString().trim();
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadDetail(), _loadMessages()]);
    _markRead();
  }

  Future<void> _loadDetail() async {
    setState(() { _loadingDetail = true; _detailError = null; });
    try {
      final res = await TicketApiService.getTicketDetail(ticketId: widget.ticketId);
      if (mounted) setState(() => _detail = Map<String, dynamic>.from(res["data"] ?? {}));
    } catch (e) {
      if (mounted) setState(() => _detailError = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _loadingMessages = true);
    try {
      final res = await TicketApiService.getTicketMessages(ticketId: widget.ticketId);
      final raw = List<Map<String, dynamic>>.from(res["data"] ?? []);
      // Reverse so newest is at index 0 (bottom with reverse:true ListView)
      if (mounted) setState(() => _messages = raw.reversed.toList());
      _scrollToBottom();
    } catch (_) {
      // Messages failing silently — detail error is more prominent
    } finally {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  void _markRead() async {
    try {
      await TicketApiService.markMessagesRead(
        ticketId:   widget.ticketId,
        readerType: widget.isAgent ? 'agent' : 'user',
      );
    } catch (_) {}
  }

  Future<void> _refresh() async {
    await _loadMessages();
    await _loadDetail();
    _markRead();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(0);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sendingMessage) return;

    final senderType = widget.isAgent ? 'agent' : 'user';
    final senderId   = _employeeId();
    final now        = DateTime.now().toIso8601String();

    // Optimistic bubble
    final optimistic = {
      "id"         : "temp_${DateTime.now().millisecondsSinceEpoch}",
      "senderType" : senderType,
      "senderId"   : senderId,
      "senderName" : (widget.user["name"] ?? widget.user["username"] ?? "Me").toString(),
      "message"    : text,
      "createdAt"  : now,
      "_optimistic": true,
    };

    setState(() {
      _messages.insert(0, optimistic);
      _msgController.clear();
      _sendingMessage = true;
    });
    _scrollToBottom();

    try {
      await TicketApiService.sendTicketMessage(
        ticketId:   widget.ticketId,
        senderType: senderType,
        senderId:   senderId,
        message:    text,
      );
      // Refresh from server to get real IDs and any status change
      await _loadMessages();
      if (widget.isAgent) await _loadDetail();
    } catch (e) {
      if (!mounted) return;
      // Remove optimistic bubble on error
      setState(() => _messages.removeWhere((m) => m["_optimistic"] == true));
      TopBanner.show(context,
          title: 'Send Failed',
          message: e.toString().replaceFirst("Exception: ", ""),
          icon: Icons.error_outline,
          isSuccess: false);
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Future<void> _cancelTicket() async {
    final detail = _detail ?? {};
    final title  = (detail["title"] ?? "Ticket").toString();

    final confirmed = await showCancelTicketDialog(
      context:     context,
      ticketTitle: title,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await TicketApiService.cancelTicket(
        ticketId:   widget.ticketId,
        employeeId: _employeeId(),
      );
      if (!mounted) return;
      TopBanner.show(context,
          title: 'Ticket Cancelled',
          message: 'Your support ticket has been removed.',
          icon: Icons.delete_outline_rounded,
          isSuccess: true);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(context,
          title: 'Failed',
          message: e.toString().replaceFirst("Exception: ", ""),
          icon: Icons.error_outline,
          isSuccess: false);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _showResolveDialog() async {
    final detail  = _detail ?? {};
    final title   = (detail["title"] ?? "Ticket").toString();
    final empName = (detail["employeeName"] ?? "").toString();

    final note = await showResolveTicketDialog(
      context:      context,
      ticketTitle:  title,
      employeeName: empName.isNotEmpty ? empName : 'Employee',
    );

    if (note == null || !mounted) return;

    setState(() => _resolving = true);
    try {
      await TicketApiService.resolveTicket(
        ticketId:       widget.ticketId,
        agentId:        _employeeId(),
        resolutionNote: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      TopBanner.show(context,
          title: 'Ticket Resolved',
          message: 'The ticket has been marked as resolved.',
          icon: Icons.check_circle,
          isSuccess: true);
      await _loadDetail();
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(context,
          title: 'Failed',
          message: e.toString().replaceFirst("Exception: ", ""),
          icon: Icons.error_outline,
          isSuccess: false);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  String get _ticketStatus => (_detail?["status"] ?? "").toString();
  bool   get _isResolved   => _ticketStatus == 'resolved';

  bool _isSentByMe(Map<String, dynamic> msg) {
    final senderType = (msg["senderType"] ?? "").toString();
    return widget.isAgent ? senderType == 'agent' : senderType == 'user';
  }

  bool _showSenderName(int index) {
    if (index >= _messages.length - 1) return true;
    final currSender = (_messages[index]["senderId"] ?? "").toString();
    final nextSender = (_messages[index + 1]["senderId"] ?? "").toString();
    return currSender != nextSender;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDetail && _detail == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
          title: const Text('Loading...',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17,
                  color: Color(0xFF1E2A3A))),
        ),
        body: const Center(child: CircularProgressIndicator(
            color: Color(0xFF1565C0), strokeWidth: 2)),
      );
    }

    if (_detailError != null && _detail == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_detailError!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      );
    }

    final detail      = _detail ?? {};
    final title       = (detail["title"] ?? "Ticket").toString();
    final description = (detail["description"] ?? "").toString();
    final platform    = (detail["platformName"] ?? "").toString();
    final issue       = (detail["issueTitle"] ?? "").toString();
    final empName     = (detail["employeeName"] ?? "").toString();
    final empId       = int.tryParse((detail["employeeId"] ?? "").toString()) ?? 0;
    final createdAt   = (detail["createdAt"] ?? "").toString();
    final resolvedAt  = (detail["resolvedAt"] ?? "").toString();
    final resNote     = (detail["resolutionNote"] ?? "").toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15,
                    color: Color(0xFF1E2A3A))),
            if (widget.isAgent && empName.isNotEmpty)
              Text(empName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF8A97AD),
                      fontWeight: FontWeight.w500))
            else
              const Text('IT Support Ticket',
                  style: TextStyle(
                      fontSize: 11.5, color: Color(0xFF8A97AD),
                      fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          if (widget.isAgent && !_isResolved)
            _resolving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Color(0xFF2E7D32), strokeWidth: 2),
                    ),
                  )
                : GestureDetector(
                    onTap: _showResolveDialog,
                    child: Container(
                      margin: const EdgeInsets.only(right: 14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E7D32)
                                .withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.task_alt_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text('Resolve',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              )),
                        ],
                      ),
                    ),
                  ),
        ],
      ),
      body: Column(
        children: [
          // ── Info card ────────────────────────────────────────────────────
          _InfoCard(
            platform:    platform,
            issue:       issue,
            description: description,
            status:      _ticketStatus,
            createdAt:   createdAt,
            resolvedAt:  resolvedAt,
            resNote:     resNote,
            empName:     widget.isAgent ? empName : '',
            empId:       widget.isAgent ? empId : 0,
            isResolved:  _isResolved,
          ),

          // ── Messages ─────────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFF1565C0),
              backgroundColor: Colors.white,
              child: _loadingMessages && _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator(
                      color: Color(0xFF1565C0), strokeWidth: 2))
                  : _messages.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      size: 48, color: Color(0xFFCCD5E0)),
                                  SizedBox(height: 10),
                                  Text('No messages yet',
                                      style: TextStyle(fontSize: 14,
                                          color: Color(0xFF8A97AD),
                                          fontWeight: FontWeight.w600)),
                                  SizedBox(height: 4),
                                  Text('Send a message to start the conversation',
                                      style: TextStyle(fontSize: 12,
                                          color: Color(0xFFAAB4C4))),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          reverse: true,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final msg    = _messages[i];
                            final isMe   = _isSentByMe(msg);
                            final showName = !isMe && _showSenderName(i);
                            return _MessageBubble(
                              message:   msg,
                              isMe:      isMe,
                              showName:  showName,
                            );
                          },
                        ),
            ),
          ),

          // ── Input bar / resolved / waiting banner ────────────────────────
          if (_isResolved)
            _ResolvedBanner()
          else if (!widget.isAgent && _ticketStatus == 'open')
            _WaitingForAgentBanner(
              onCancel:   _cancelTicket,
              cancelling: _cancelling,
            )
          else
            _InputBar(
              controller: _msgController,
              sending: _sendingMessage,
              onSend: _sendMessage,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info card
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String platform;
  final String issue;
  final String description;
  final String status;
  final String createdAt;
  final String resolvedAt;
  final String resNote;
  final String empName;
  final int    empId;
  final bool   isResolved;

  const _InfoCard({
    required this.platform,
    required this.issue,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.resolvedAt,
    required this.resNote,
    required this.empName,
    required this.empId,
    required this.isResolved,
  });


  @override
  Widget build(BuildContext context) {
    final hasEmployee = empName.isNotEmpty;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Agent view: employee row ──────────────────────────────
                if (hasEmployee) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _MiniAvatar(id: empId, name: empName, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(empName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E2A3A),
                                )),
                            const Text('Reported a support ticket',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF8A97AD),
                                  fontWeight: FontWeight.w500,
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ticketStatusPill(status),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Employee view: status summary card ────────────────────
                if (!hasEmployee) ...[
                  _StatusSummaryCard(status: status, createdAt: createdAt),
                  const SizedBox(height: 10),
                ],

                // ── Description (agent view only) ────────────────────────
                if (hasEmployee && description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFBFD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE4EBF8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DESCRIPTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFAAB4C4),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status summary card — shown in the info card for the employee (user) view
// ─────────────────────────────────────────────────────────────────────────────

class _StatusSummaryCard extends StatelessWidget {
  final String status;
  final String createdAt;

  const _StatusSummaryCard({required this.status, required this.createdAt});

  String _fmtShort(String dt) {
    if (dt.isEmpty) return '';
    try {
      return DateFormat('MMM d, h:mm a').format(DateTime.parse(dt));
    } catch (_) {
      return dt.length >= 10 ? dt.substring(0, 10) : dt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cfg.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cfg.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cfg.icon, color: cfg.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: cfg.color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  cfg.description,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF8A97AD),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Opened',
                    style: TextStyle(
                        fontSize: 10, color: Color(0xFFAAB4C4),
                        fontWeight: FontWeight.w500)),
                Text(_fmtShort(createdAt),
                    style: const TextStyle(
                        fontSize: 10.5, color: Color(0xFF8A97AD),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  ({Color bg, Color border, Color color, Color iconBg, IconData icon,
      String label, String description}) _statusConfig(String s) {
    switch (s) {
      case 'open':
        return (
          bg: const Color(0xFFFFFDE7),
          border: const Color(0xFFFFE082),
          color: const Color(0xFF8A6D3B),
          iconBg: const Color(0xFFFFF9C4),
          icon: Icons.hourglass_top_rounded,
          label: 'Awaiting Response',
          description: 'Your ticket has been submitted and is waiting for an IT agent',
        );
      case 'in_progress':
        return (
          bg: const Color(0xFFE3F2FD),
          border: const Color(0xFF90CAF9),
          color: const Color(0xFF1565C0),
          iconBg: const Color(0xFFBBDEFB),
          icon: Icons.support_agent_rounded,
          label: 'In Progress',
          description: 'An IT agent is actively working on your issue',
        );
      case 'resolved':
        return (
          bg: const Color(0xFFE8F5E9),
          border: const Color(0xFFA5D6A7),
          color: const Color(0xFF2E7D32),
          iconBg: const Color(0xFFC8E6C9),
          icon: Icons.check_circle_rounded,
          label: 'Resolved',
          description: 'Your issue has been resolved',
        );
      default:
        return (
          bg: const Color(0xFFF4F7FC),
          border: const Color(0xFFE4EBF8),
          color: const Color(0xFF8A97AD),
          iconBg: const Color(0xFFE8EDF5),
          icon: Icons.help_outline_rounded,
          label: 'Support Ticket',
          description: 'Loading ticket status…',
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool showName;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showName,
  });

  String _fmtTime(String dt) {
    if (dt.isEmpty) return '';
    try {
      return DateFormat('h:mm a').format(DateTime.parse(dt));
    } catch (_) {
      return dt.length >= 16 ? dt.substring(11, 16) : '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final text       = (message["message"] ?? "").toString();
    final senderName = (message["senderName"] ?? "").toString();
    final createdAt  = (message["createdAt"] ?? "").toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showName && senderName.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                bottom: 3,
                left: isMe ? 0 : 4,
                right: isMe ? 4 : 0,
              ),
              child: Text(senderName,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: Color(0xFF8A97AD))),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) const SizedBox(width: 4),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF1565C0) : const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(16),
                      topRight:    const Radius.circular(16),
                      bottomLeft:  Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(text,
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.white : const Color(0xFF1E2A3A),
                        fontWeight: FontWeight.w500,
                      )),
                ),
              ),
              if (isMe) const SizedBox(width: 4),
            ],
          ),
          if (createdAt.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: 3,
                left: isMe ? 0 : 8,
                right: isMe ? 8 : 0,
                bottom: 6,
              ),
              child: Text(_fmtTime(createdAt),
                  style: const TextStyle(fontSize: 10, color: Color(0xFFAAB4C4),
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input bar
// ─────────────────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE4EBF8)),
              ),
              child: TextField(
                controller: widget.controller,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E2A3A)),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Color(0xFFAAB4C4), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: (_hasText && !widget.sending) ? widget.onSend : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: (_hasText && !widget.sending)
                    ? const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF003580)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: (_hasText && !widget.sending) ? null : const Color(0xFFE4EBF8),
                shape: BoxShape.circle,
              ),
              child: widget.sending
                  ? const Center(
                      child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)))
                  : Icon(Icons.send_rounded,
                      color: _hasText ? Colors.white : const Color(0xFFAAB4C4),
                      size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resolved banner (replaces input bar when ticket is resolved)
// ─────────────────────────────────────────────────────────────────────────────

class _ResolvedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF2E7D32)),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'This ticket has been resolved. No further replies can be sent.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waiting for agent banner — shown on user side when ticket is still 'open'
// ─────────────────────────────────────────────────────────────────────────────

class _WaitingForAgentBanner extends StatelessWidget {
  final VoidCallback onCancel;
  final bool cancelling;

  const _WaitingForAgentBanner({
    required this.onCancel,
    required this.cancelling,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.hourglass_top_rounded,
                  size: 15, color: Color(0xFF8A6D3B)),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Waiting for an IT agent to respond. You can reply once they accept your ticket.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF8A6D3B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: cancelling ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD32F2F),
                side: const BorderSide(color: Color(0xFFEF9A9A), width: 1.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                backgroundColor: const Color(0xFFFFF5F5),
              ),
              icon: cancelling
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: Color(0xFFD32F2F), strokeWidth: 2))
                  : const Icon(Icons.cancel_outlined, size: 16),
              label: Text(
                cancelling ? 'Cancelling…' : 'Cancel Ticket',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini avatar for info card employee photo
// ─────────────────────────────────────────────────────────────────────────────

class _MiniAvatar extends StatefulWidget {
  final int    id;
  final String name;
  final double size;

  const _MiniAvatar({required this.id, required this.name, this.size = 26});

  @override
  State<_MiniAvatar> createState() => _MiniAvatarState();
}

class _MiniAvatarState extends State<_MiniAvatar> {
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

    return FutureBuilder<Map<String, dynamic>?>(
      future: _photoFuture,
      builder: (_, snap) {
        final url = (snap.data?['fileUrl'] ?? '').toString().trim();
        final sz = widget.size;
        return Container(
          width: sz,
          height: sz,
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
                          fontSize: sz * 0.38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)))
              : null,
        );
      },
    );
  }
}
