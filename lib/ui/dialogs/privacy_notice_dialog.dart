import 'dart:ui';
import 'package:flutter/material.dart';

Future<void> showPrivacyNoticeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (_) => const _PrivacyNoticeDialog(),
  );
}

class _PrivacyNoticeDialog extends StatelessWidget {
  const _PrivacyNoticeDialog();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final dialogW = (w * 0.92).clamp(280.0, 620.0);

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
            ),
            child: Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: const Color(0xFFC9C7C7),
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: SizedBox(
                width: dialogW,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: Color(0xFF0060A6)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Privacy Notice",
                              style: TextStyle(fontSize: 16, 
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2A3A),
                              )
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "This app is developed for internal staff use within Explore Holdings.",
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF5F6F86),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD6E4FF)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NoticePoint("The mobile application does not store any data locally on the device."),
                            SizedBox(height: 8),
                            _NoticePoint("All data entered through the app is securely stored in the company ERP system."),
                            SizedBox(height: 8),
                            _NoticePoint("No data is shared with any third parties."),
                            SizedBox(height: 8),
                            _NoticePoint("No device or location tracking is performed."),
                            SizedBox(height: 8),
                            _NoticePoint("No background monitoring is enabled."),
                            SizedBox(height: 8),
                            _NoticePoint("The app is used only for internal operational purposes."),
                            SizedBox(height: 8),
                            _NoticePoint("Access is restricted to authorized staff only."),
                            SizedBox(height: 8),
                            _NoticePoint("Users are responsible for maintaining the confidentiality of login credentials."),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF003580)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "I Understand",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
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
}

class _NoticePoint extends StatelessWidget {
  final String text;
  const _NoticePoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF1E2A3A)),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Color(0xFF1E2A3A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
