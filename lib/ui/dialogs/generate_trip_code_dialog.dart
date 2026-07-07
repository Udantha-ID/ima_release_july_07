import 'dart:ui';
import 'package:flutter/material.dart';

class GenerateTripCodeDialog extends StatelessWidget {
  final VoidCallback onGenerate;

  const GenerateTripCodeDialog({
    super.key,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0060A6);
    final w = MediaQuery.of(context).size.width;
    final dialogW = (w * 0.90).clamp(300.0, 420.0);

    return Stack(
      children: [
        // Blur background
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(color: Colors.transparent),
        ),

        Center(
          child: Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox(
              width: dialogW,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.qr_code_rounded, color: blue),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Generate Trip Code",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      "This action cannot be undone.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      "Are you sure you want to generate a trip code and move this trip to Start Trip?",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),

                    const SizedBox(height: 18),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Color(0xFF0060A6), // Text color
                              side: const BorderSide(color: Color.fromARGB(255, 196, 196, 196), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF0060A6),
                                  Color(0xFF003580),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onGenerate();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Generate",
                                style: TextStyle(color: Colors.white),
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
      ],
    );
  }
}