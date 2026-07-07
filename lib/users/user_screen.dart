import 'package:flutter/material.dart';
import 'profile_screen.dart';
import '../Leaves/leave_history_screen.dart';
import '../Leaves/reliaver_request_screen.dart';

class UserScreen extends StatefulWidget {
  
  final Map<String, dynamic> user;
  final int initialTab;

  const UserScreen({super.key, required this.user, this.initialTab = 0,});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  late int selectedTab;

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialTab;
  }

  String getAppBarTitle() {
  switch (selectedTab) {
    case 0:
      return 'Profile';
    case 1:
      return 'Leave History';
    case 2:
      return 'Reliever Request';
    default:
      return 'Employee';
  }
}

        @override
        Widget build(BuildContext context) {
          final blue = Colors.blue[800]!;

          return Scaffold(
            backgroundColor: Colors.white,
              appBar: AppBar(
                  backgroundColor: Colors.white,
                  iconTheme: const IconThemeData(
                  color: Colors.black87,
                ),
            title: Text(
        getAppBarTitle(),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),

      ),

      // Column: Top buttons + changing content
      body: Column(
        children: [
          // 3 buttons always visible
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _tabButton(
                    label: "Profile",
                    icon: Icons.person_outline,
                    isActive: selectedTab == 0,
                    onTap: () => setState(() => selectedTab = 0),
                    activeColor: blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tabButton(
                    label: "Leave History",
                    icon: Icons.history,
                    isActive: selectedTab == 1,
                    onTap: () => setState(() => selectedTab = 1),
                    activeColor: blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tabButton(
                    label: "Reliever\nRequest",
                    icon: Icons.group_outlined,
                    isActive: selectedTab == 2,
                    onTap: () => setState(() => selectedTab = 2),
                    activeColor: blue,
                  ),
                ),
              ],
            ),
          ),

          //Only this part changes
          Expanded(
            child: IndexedStack(
              index: selectedTab,
              children: [
                ProfileScreen(user: widget.user),// tab 0
                LeaveHistoryScreen(user: widget.user), // tab 1
                RelieverRequestView(user: widget.user),// tab 2
              ],
            ),
          ),
        ],
      ),
    );
  }

  // same button UI you already use
  Widget _tabButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE1E6EF),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : Colors.black87),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
