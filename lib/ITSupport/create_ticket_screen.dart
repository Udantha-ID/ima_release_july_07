import 'package:flutter/material.dart';
import '../Services/ticket_api_service.dart';
import '../Leaves/top_banner.dart';
import '../ui/dialogs/submit_ticket_dialog.dart';
import '../ui/widgets/common_form_widgets.dart';

class CreateTicketScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CreateTicketScreen({super.key, required this.user});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  int _step = 0;

  int?    _selectedPlatformId;
  String  _selectedPlatformName = '';
  int?    _selectedIssueId;
  String  _selectedIssueTitle   = '';

  List<Map<String, dynamic>> _platforms    = [];
  List<Map<String, dynamic>> _issues       = [];
  bool    _loadingPlatforms = false;
  bool    _loadingIssues    = false;
  bool    _submitting       = false;
  String? _platformsError;
  String? _issuesError;

  final _formKey         = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController  = TextEditingController();

  String _employeeId() {
    final u = widget.user;
    final v = u["employee_id"] ?? u["employeeId"] ?? u["id"] ?? u["user_id"];
    return (v ?? "").toString().trim();
  }

  @override
  void initState() {
    super.initState();
    _loadPlatforms();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadPlatforms() async {
    setState(() { _loadingPlatforms = true; _platformsError = null; });
    try {
      final res = await TicketApiService.getPlatforms();
      if (mounted) {
        setState(() => _platforms =
            List<Map<String, dynamic>>.from(res["data"] ?? []));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _platformsError =
            e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) { setState(() => _loadingPlatforms = false); }
    }
  }

  Future<void> _loadIssues(int platformId) async {
    setState(() { _loadingIssues = true; _issuesError = null; _issues = []; });
    try {
      final res = await TicketApiService.getCommonIssues(platformId: platformId);
      if (mounted) {
        setState(() => _issues =
            List<Map<String, dynamic>>.from(res["data"] ?? []));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _issuesError =
            e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) { setState(() => _loadingIssues = false); }
    }
  }

  void _selectPlatform(Map<String, dynamic> p) {
    final id   = int.tryParse((p["id"] ?? "").toString()) ?? 0;
    final name = (p["name"] ?? "").toString();
    setState(() {
      _selectedPlatformId   = id;
      _selectedPlatformName = name;
      _step = 1;
    });
    _loadIssues(id);
  }

  void _selectIssue(Map<String, dynamic>? issue) {
    if (issue == null) {
      setState(() {
        _selectedIssueId    = null;
        _selectedIssueTitle = 'Custom Issue';
        _titleController.clear();
        _descController.clear();
        _step = 2;
      });
    } else {
      final id    = int.tryParse((issue["id"] ?? "").toString()) ?? 0;
      final title = (issue["title"] ?? "").toString();
      final desc  = (issue["description"] ?? "").toString();
      setState(() {
        _selectedIssueId    = id;
        _selectedIssueTitle = title;
        _titleController.text = title;
        _descController.text  = desc;
        _step = 2;
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirmed = await showSubmitTicketDialog(
      context:      context,
      platformName: _selectedPlatformName,
      issueTitle:   _selectedIssueTitle,
      ticketTitle:  _titleController.text.trim(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await TicketApiService.createTicket(
        employeeId:    _employeeId(),
        platformId:    _selectedPlatformId!,
        commonIssueId: _selectedIssueId,
        title:         _titleController.text.trim(),
        description:   _descController.text.trim(),
      );
      if (!mounted) return;
      TopBanner.show(context,
          title: 'Ticket Submitted',
          message: 'Your support ticket has been raised successfully.',
          icon: Icons.check_circle,
          isSuccess: true);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(context,
          title: 'Submission Failed',
          message: e.toString().replaceFirst("Exception: ", ""),
          icon: Icons.error_outline,
          isSuccess: false);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _appBarTitle() {
    switch (_step) {
      case 0:  return 'Select Category';
      case 1:  return 'Select Issue';
      default: return 'Describe Your Issue';
    }
  }

  void _onBack() {
    if (_step > 0) {
      setState(() => _step -= 1);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E2A3A)),
          onPressed: _onBack,
        ),
        title: Text(_appBarTitle(),
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 17,
                color: Color(0xFF1E2A3A))),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _StepBar(currentStep: _step),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: _step == 0
            ? _PlatformStep(
                key: const ValueKey(0),
                platforms: _platforms,
                loading: _loadingPlatforms,
                error: _platformsError,
                onRetry: _loadPlatforms,
                onSelect: _selectPlatform,
              )
            : _step == 1
                ? _IssueStep(
                    key: const ValueKey(1),
                    platformName: _selectedPlatformName,
                    issues: _issues,
                    loading: _loadingIssues,
                    error: _issuesError,
                    onRetry: () => _loadIssues(_selectedPlatformId!),
                    onSelect: _selectIssue,
                  )
                : _FormStep(
                    key: const ValueKey(2),
                    formKey: _formKey,
                    platformName: _selectedPlatformName,
                    issueTitle: _selectedIssueTitle,
                    titleController: _titleController,
                    descController: _descController,
                    submitting: _submitting,
                    onSubmit: _submit,
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  final int currentStep;

  const _StepBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const labels = ['Category', 'Issue', 'Details'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            _StepDot(index: i, current: currentStep, label: labels[i]),
            if (i < labels.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: i < currentStep
                        ? const Color(0xFF1565C0)
                        : const Color(0xFFE4EBF8),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int    index;
  final int    current;
  final String label;

  const _StepDot({
    required this.index,
    required this.current,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final done   = index < current;
    final active = index == current;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active
                ? const Color(0xFF1565C0)
                : const Color(0xFFE4EBF8),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : const Color(0xFFAAB4C4),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: active || done ? FontWeight.w800 : FontWeight.w500,
            color: active || done
                ? const Color(0xFF1565C0)
                : const Color(0xFFAAB4C4),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 0 — Platform / Category grid
// ─────────────────────────────────────────────────────────────────────────────

class _PlatformStep extends StatelessWidget {
  final List<Map<String, dynamic>> platforms;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _PlatformStep({
    super.key,
    required this.platforms,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(
          color: Color(0xFF1565C0), strokeWidth: 2));
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        const Text(
          'What type of issue are you experiencing?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select the category that best matches your problem.',
          style: TextStyle(fontSize: 13, color: Color(0xFF8A97AD)),
        ),
        const SizedBox(height: 16),
        // ── Grid ────────────────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: platforms.length,
          itemBuilder: (_, i) {
            final p = platforms[i];
            return _PlatformCard(
              platform: p,
              accentColor: _accentFor(p["name"] ?? "", i),
              onTap: () => onSelect(p),
            );
          },
        ),
      ],
    );
  }

  static Color _accentFor(String name, int index) {
    final n = name.toLowerCase();
    if (n.contains('erp') || n.contains('software')) { return const Color(0xFF1565C0); }
    if (n.contains('network') || n.contains('wifi') || n.contains('internet')) {
      return const Color(0xFF0097A7);
    }
    if (n.contains('email') || n.contains('office') || n.contains('365')) {
      return const Color(0xFFE65100);
    }
    if (n.contains('hardware') || n.contains('peripheral') || n.contains('device')) {
      return const Color(0xFF6A1B9A);
    }
    if (n.contains('portal') || n.contains('customer') || n.contains('crm')) {
      return const Color(0xFF2E7D32);
    }
    if (n.contains('mobile') || n.contains('phone')) { return const Color(0xFF0288D1); }
    const fallback = [
      Color(0xFF1565C0), Color(0xFF00695C), Color(0xFF6A1B9A),
      Color(0xFFE65100), Color(0xFF1976D2), Color(0xFF2E7D32),
    ];
    return fallback[index % fallback.length];
  }
}

class _PlatformCard extends StatelessWidget {
  final Map<String, dynamic> platform;
  final Color accentColor;
  final VoidCallback onTap;

  const _PlatformCard({
    required this.platform,
    required this.accentColor,
    required this.onTap,
  });

  static IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('erp')) { return Icons.dashboard_rounded; }
    if (n.contains('customer') || n.contains('portal')) { return Icons.shopping_cart_outlined; }
    if (n.contains('wifi') || n.contains('network') || n.contains('internet')) {
      return Icons.wifi_rounded;
    }
    if (n.contains('email') || n.contains('office')) { return Icons.mail_outline_rounded; }
    if (n.contains('hardware') || n.contains('periph')) { return Icons.computer_rounded; }
    if (n.contains('mobile') || n.contains('phone')) { return Icons.smartphone_rounded; }
    return Icons.help_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final name = (platform["name"] ?? "").toString();
    final desc = (platform["description"] ?? "").toString();
    final bg   = Color.lerp(accentColor, Colors.white, 0.92) ?? Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(name), size: 24, color: accentColor),
              ),
              const SizedBox(height: 12),
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E2A3A))),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF8A97AD),
                        fontWeight: FontWeight.w500)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Issue list
// ─────────────────────────────────────────────────────────────────────────────

class _IssueStep extends StatelessWidget {
  final String platformName;
  final List<Map<String, dynamic>> issues;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<Map<String, dynamic>?> onSelect;

  const _IssueStep({
    super.key,
    required this.platformName,
    required this.issues,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Selected platform chip ──────────────────────────────────────────
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF4FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFCCDDFF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.devices_outlined,
                            size: 12, color: Color(0xFF1565C0)),
                        const SizedBox(width: 5),
                        Text(platformName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1565C0))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Select the closest match for your issue',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF8A97AD),
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE8EDF5)),

        if (loading)
          const Expanded(
            child: Center(child: CircularProgressIndicator(
                color: Color(0xFF1565C0), strokeWidth: 2)),
          )
        else if (error != null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.redAccent),
                  const SizedBox(height: 10),
                  Text(error!, textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                    label: const Text('Retry',
                        style: TextStyle(color: Colors.white)),
                  ),
                ]),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              itemCount: issues.length + 1,
              separatorBuilder: (_, i) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i < issues.length) {
                  final issue = issues[i];
                  return _IssueCard(
                    index: i,
                    title: (issue["title"] ?? "").toString(),
                    description: (issue["description"] ?? "").toString(),
                    onTap: () => onSelect(issue),
                  );
                }
                return _IssueCard(
                  index: -1,
                  title: 'Other — Describe your own issue',
                  description:
                      'My problem isn\'t listed above. I\'ll describe it manually.',
                  isOther: true,
                  onTap: () => onSelect(null),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _IssueCard extends StatelessWidget {
  final int    index;
  final String title;
  final String description;
  final bool   isOther;
  final VoidCallback onTap;

  const _IssueCard({
    required this.index,
    required this.title,
    required this.description,
    this.isOther = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        isOther ? const Color(0xFF1565C0) : const Color(0xFF334155);
    final cardBg =
        isOther ? const Color(0xFFEEF4FF) : Colors.white;
    final border =
        isOther ? const Color(0xFFCCDDFF) : const Color(0xFFE8EDF5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left index or icon column
                Container(
                  width: 52,
                  decoration: BoxDecoration(
                    color: isOther
                        ? const Color(0xFFCCDDFF).withValues(alpha: 0.5)
                        : const Color(0xFFF4F7FC),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                  child: Center(
                    child: isOther
                        ? const Icon(Icons.edit_note_rounded,
                            size: 22, color: Color(0xFF1565C0))
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF8A97AD),
                            ),
                          ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            )),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8A97AD),
                                  fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: Icon(Icons.chevron_right_rounded,
                        size: 20, color: Color(0xFFB0BCCC)),
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
// Step 2 — Describe Your Issue form
// ─────────────────────────────────────────────────────────────────────────────

class _FormStep extends StatelessWidget {
  final GlobalKey<FormState>    formKey;
  final String                  platformName;
  final String                  issueTitle;
  final TextEditingController   titleController;
  final TextEditingController   descController;
  final bool                    submitting;
  final VoidCallback            onSubmit;

  const _FormStep({
    super.key,
    required this.formKey,
    required this.platformName,
    required this.issueTitle,
    required this.titleController,
    required this.descController,
    required this.submitting,
    required this.onSubmit,
  });

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
      ),
      errorStyle: const TextStyle(
          color: Color(0xFFD32F2F), fontWeight: FontWeight.w700, fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Title field ────────────────────────────────────────────────
            Row(
              children: const [
                Icon(Icons.title_rounded,
                    size: 15, color: Color(0xFF1565C0)),
                SizedBox(width: 6),
                Text('Issue Title',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2A3A))),
                SizedBox(width: 4),
                Text('*',
                    style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('A short, clear summary of your problem',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A97AD))),
            const SizedBox(height: 8),
            TextFormField(
              controller: titleController,
              decoration:
                  _inputDecoration('e.g. Cannot connect to company WiFi'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E2A3A)),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 20),

            // ── Description field ──────────────────────────────────────────
            Row(
              children: const [
                Icon(Icons.description_outlined,
                    size: 15, color: Color(0xFF1565C0)),
                SizedBox(width: 6),
                Text('Description',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2A3A))),
                SizedBox(width: 4),
                Text('*',
                    style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Include steps to reproduce, error messages, or screenshots info',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A97AD))),
            const SizedBox(height: 8),
            TextFormField(
              controller: descController,
              decoration: _inputDecoration(
                  'Describe what happened and what you expected…'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E2A3A)),
              maxLines: 5,
              minLines: 5,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Description is required'
                  : null,
            ),
            const SizedBox(height: 12),

            // ── Tip ────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDE7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.tips_and_updates_outlined,
                      size: 14, color: Color(0xFF8A6D3B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: More detail helps IT agents resolve your issue faster.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A6D3B),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Submit button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: GradientSubmitButton(
                label: 'Review & Submit',
                isLoading: submitting,
                onPressed: onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
