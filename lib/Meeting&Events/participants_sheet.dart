import 'package:flutter/material.dart';

Color _participantStatusColor(String status) {
  switch (status.toLowerCase()) {
    case "accepted":
      return const Color(0xFF2E7D32);
    case "declined":
    case "rejected":
      return const Color(0xFFD32F2F);
    default:
      return const Color(0xFF1565C0);
  }
}

void showParticipantsSheet({
  required BuildContext context,
  required String title,
  required List<int> memberIds,
  required Map<String, String> responseStatus,
  required Map<int, String> staffNameById,
  required Future<Map<String, dynamic>?> Function(int employeeId) getPhotoFuture,
}) {
  if (memberIds.isEmpty) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Participants",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF4A5568),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: memberIds.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 15, color: Color(0xFFF1F2F5)),
                  itemBuilder: (_, index) {
                    final memberId = memberIds[index];
                    final status =
                        responseStatus[memberId.toString()]?.toLowerCase() ?? "pending";
                    final statusColor = _participantStatusColor(status);
                    final displayName = staffNameById[memberId] ?? "Unknown Employee";

                    return Row(
                      children: [
                        FutureBuilder<Map<String, dynamic>?>(
                          future: getPhotoFuture(memberId),
                          builder: (_, snap) {
                            final url = (snap.data?["fileUrl"] ?? "")
                                .toString()
                                .trim();
                            return CircleAvatar(
                              radius: 19,
                              backgroundColor: const Color(0xFFEAF1FF),
                              backgroundImage:
                                  url.isNotEmpty ? NetworkImage(url) : null,
                              child: url.isEmpty
                                  ? const Icon(Icons.person, color: Colors.black54)
                                  : null,
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
