import 'package:flutter/material.dart';

Future<TimeOfDay?> showTimePickerSheet(
  BuildContext context, {
  TimeOfDay? initial,
  String title = 'Select Time',
}) async {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _TimePickerSheet(
      initial: initial ?? TimeOfDay.now(),
      title: title,
    ),
  );
}

class _TimePickerSheet extends StatefulWidget {
  final TimeOfDay initial;
  final String title;
  const _TimePickerSheet({required this.initial, required this.title});

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    _hour   = widget.initial.hour;
    _minute = widget.initial.minute;
    _hourCtrl   = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2A3A),
            ),
          ),
          const SizedBox(height: 8),

          // Column labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Hour',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: Center(
                    child: Text(
                      'Minute',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Wheel row
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Selection highlight
                Positioned(
                  child: IgnorePointer(
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      // Hour wheel
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: _hourCtrl,
                          itemExtent: 48,
                          perspective: 0.003,
                          diameterRatio: 1.6,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) =>
                              setState(() => _hour = i),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 24,
                            builder: (ctx, i) {
                              final selected = _hour == i;
                              return Center(
                                child: Text(
                                  i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: selected ? 22 : 17,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: selected
                                        ? const Color(0xFF1565C0)
                                        : Colors.black38,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Colon separator
                      const Text(
                        ':',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1565C0),
                        ),
                      ),

                      // Minute wheel
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: _minuteCtrl,
                          itemExtent: 48,
                          perspective: 0.003,
                          diameterRatio: 1.6,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) =>
                              setState(() => _minute = i),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 60,
                            builder: (ctx, i) {
                              final selected = _minute == i;
                              return Center(
                                child: Text(
                                  i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: selected ? 22 : 17,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: selected
                                        ? const Color(0xFF1565C0)
                                        : Colors.black38,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Preview
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1565C0),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        TimeOfDay(hour: _hour, minute: _minute),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
