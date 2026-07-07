import 'package:flutter/material.dart';
import '../Services/ticket_api_service.dart';
import 'my_tickets_screen.dart';
import 'agent_inbox_screen.dart';

class ITSupportHomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ITSupportHomeScreen({super.key, required this.user});

  @override
  State<ITSupportHomeScreen> createState() => _ITSupportHomeScreenState();
}

class _ITSupportHomeScreenState extends State<ITSupportHomeScreen> {
  bool _loading = true;
  bool _isAgent = false;

  String _employeeId() {
    final u = widget.user;
    final v = u["employee_id"] ?? u["employeeId"] ?? u["id"] ?? u["user_id"];
    return (v ?? "").toString().trim();
  }

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    try {
      final ids = await TicketApiService.getItAgentIds();
      final empId = _employeeId();
      if (mounted) {
        setState(() {
          _isAgent = ids.contains(empId);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1565C0), strokeWidth: 2),
        ),
      );
    }

    if (_isAgent) {
      return AgentInboxScreen(user: widget.user);
    }
    return MyTicketsScreen(user: widget.user);
  }
}
