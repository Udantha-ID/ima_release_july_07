import 'dart:ui';
import 'package:flutter/material.dart';

Future<bool>? _personalVehiclePolicyDialogInFlight;

Future<bool> showPersonalVehiclePolicyDialog({
  required BuildContext context,
}) async {
  // Prevent multiple dialogs from stacking if this is triggered twice quickly
  // (e.g., due to multiple post-frame callbacks or duplicate navigation events).
  final existing = _personalVehiclePolicyDialogInFlight;
  if (existing != null) return existing;

  final future = showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (ctx) => const _PersonalVehiclePolicyDialog(),
  ).then((result) => result == true);

  _personalVehiclePolicyDialogInFlight = future;
  return future.whenComplete(() {
    _personalVehiclePolicyDialogInFlight = null;
  });
}

class _PersonalVehiclePolicyDialog extends StatefulWidget {
  const _PersonalVehiclePolicyDialog();

  @override
  State<_PersonalVehiclePolicyDialog> createState() =>
      _PersonalVehiclePolicyDialogState();
}

class _PersonalVehiclePolicyDialogState
    extends State<_PersonalVehiclePolicyDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = (width * 0.94).clamp(300.0, 760.0);
    final canAgree = _isChecked;

    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(color: Colors.black.withOpacity(0.15)),
        ),
        Center(
          child: Theme(
            data: Theme.of(context).copyWith(
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.white,
              dialogBackgroundColor: Colors.white,
              colorScheme: const ColorScheme.light(
                surface: Colors.white,
                onSurface: Color(0xFF1E2A3A),
                primary: Color(0xFF1565C0),
              ),
              popupMenuTheme: const PopupMenuThemeData(
                color: Colors.white,
                surfaceTintColor: Colors.white,
              ),
            ),
            child: Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: const Color(0xFFC9C7C7),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.policy_outlined, color: Color(0xFF1565C0)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Personal Usage Policy",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E2A3A),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: "Decline and close",
                            color: const Color(0xFF1E2A3A),
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Text(
                        "Please review the policy and confirm your agreement to continue.",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5F6F86),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD6E4FF)),
                          ),
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                              child: _buildPolicyContent(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _isChecked,
                            onChanged: (v) =>
                                setState(() => _isChecked = v ?? false),
                            activeColor: const Color(0xFF1565C0),
                            checkColor: Colors.white,
                          ),
                          const Expanded(
                            child: Text(
                              "I have read and agree to this policy.",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E2A3A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1565C0),
                                side: const BorderSide(color: Color(0xFFC4C4C4), width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text("Decline"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: canAgree
                                      ? const LinearGradient(
                                          colors: [Color(0xFF1565C0), Color(0xFF003580)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: canAgree ? null : const Color(0xFFB0BECF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ElevatedButton(
                                  onPressed: canAgree
                                      ? () => Navigator.pop(context, true)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    disabledBackgroundColor: Colors.transparent,
                                    disabledForegroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "Agree & Continue",
                                      maxLines: 1,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyContent() {
    final lines = _policyText.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((raw) {
        final line = raw.trimRight();
        if (line.trim().isEmpty) {
          return const SizedBox(height: 8);
        }

        final trimmed = line.trimLeft();
        if (trimmed.startsWith('- ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.fiber_manual_record,
                    size: 8,
                    color: Color(0xFF1E2A3A),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trimmed.substring(2),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xFF1E2A3A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final isMainHeading = RegExp(r'^\d+\.\s').hasMatch(trimmed);
        final isTitle =
            trimmed == "PERSONAL USAGE OF COMPANY VEHICLES POLICY" ||
            trimmed.startsWith("Company:") ||
            trimmed.startsWith("Effective Date:");

        return Padding(
          padding: EdgeInsets.only(bottom: isMainHeading ? 7 : 5),
          child: Text(
            trimmed,
            style: TextStyle(
              fontSize: isTitle ? 12.8 : 12.6,
              height: 1.4,
              color: const Color(0xFF1E2A3A),
              fontWeight: (isMainHeading || isTitle)
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

const String _policyText = '''
PERSONAL USAGE OF COMPANY VEHICLES POLICY
Company: Explore Vacations / SR Rent A Car / Europcar Sri Lanka / Elite Rent A Car
Effective Date: 01.04.2026

1. Purpose
This policy regulates and controls personal use of company-owned vehicles by staff, ensuring transparency, accountability, and protection of company assets while maintaining operational efficiency.

2. Eligibility
- Applicable to all permanent staff of the company.
- Temporary staff and outsourced personnel are not eligible unless specifically approved by management.

3. Entitlement
Each eligible staff member is entitled to the following categories:

3.1 FOC (Free of Charge) Usage
- Maximum 2 requests per calendar year.
- Maximum 2 days per request.
- Applicable ONLY for Mini and Sedan category vehicles.
- Subject to availability and approval.

3.2 ID50 (Internal Discount 50%) Usage
- Maximum 3 requests per calendar year.
- Charged at 50% of the standard rental rate.
- Maximum 3 days per request.
- Applicable for Mini, Sedan, and Compact SUV categories.
- Subject to availability and approval.

3.3 Vehicle Category Restrictions
- Luxury category vehicles are strictly not permitted under this policy.
- Category allocation is subject to fleet availability and operational priority.

4. Request and Approval Process
- All requests must be submitted through the official Staff Application (Vehicle Request Module).
- Requests must be made at least 48 hours in advance.
- Approval authority: Group General Manager (GGM).
- Requests without system approval are considered unauthorized.

5. Operational Restrictions
- Vehicles for staff personal use will not be approved during peak operational seasons.
- Vehicles for staff personal use will not be approved when fleet utilization exceeds 70%.
- Customer bookings and operational requirements always take priority.

6. Vehicle Allocation Rules
- Vehicles are allocated based on availability and operational priority.
- Specific vehicle models or variants cannot be guaranteed.

7. Usage Conditions
- Vehicle must be used only by the approved staff member.
- Sub-letting, lending, or third-party driving is strictly prohibited.
- Vehicles must not be used for commercial or income-generating purposes.

8. Fuel Policy
- FOC usage: Vehicle must be returned with the same fuel level.
- ID50 usage: Fuel cost is fully borne by the staff member.

9. Vehicle Movement Control
- All vehicle movements must be recorded in designated company WhatsApp group(s).
- Failure to record movement is treated as a policy violation.

10. Liability and Responsibility
The staff member is fully responsible for:
- Traffic fines and violations.
- Any damages during the usage period.
- Insurance excess/deductibles in case of accidents.
- Negligence or misuse of the vehicle.

11. Restrictions
- No long-distance travel without prior approval.
- No illegal or unsafe use.
- No off-road usage unless explicitly approved.

12. Monitoring and Limits
- Entitlements (FOC and ID50) are tracked through the Staff Application system.
- Once annual limits are reached, no further usage under this policy is granted.
- Any additional usage is charged at full standard rental rates.

13. Misuse and Disciplinary Action
Serious violations include:
- Unauthorized vehicle usage.
- Bypassing the approval system.
- Failure to log vehicle movement.
- Exceeding approved duration.
- Using vehicles for personal financial gain.

Disciplinary action includes:
- Immediate suspension of vehicle privileges.
- Written warning.
- Further disciplinary action, including termination for repeated offenses.

14. Management Rights
The company reserves the right to:
- Approve or reject any request at its discretion.
- Restrict usage based on operational needs.
- Amend or withdraw this policy at any time.

''';
