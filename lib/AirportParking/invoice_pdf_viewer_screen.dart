import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../Services/airport_parking_service.dart';

/// Shows the invoice in a [WebView] using the **public HTTPS URL**, so no native
/// PDF plugin channel is required (fixes `channel-error` with [pdfx] /
/// [flutter_pdfview] under [DevicePreview] or broken plugin registration).
class InvoicePdfViewerScreen extends StatefulWidget {
  final File file;
  final String reference;

  const InvoicePdfViewerScreen({
    super.key,
    required this.file,
    required this.reference,
  });

  @override
  State<InvoicePdfViewerScreen> createState() => _InvoicePdfViewerScreenState();
}

class _InvoicePdfViewerScreenState extends State<InvoicePdfViewerScreen> {
  static const _blue2 = Color(0xFF003580);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  late final WebViewController _webController;
  late final Uri _pdfUri;

  bool _loading = true;
  String? _error;
  /// Start with Google’s embedded viewer — many Android WebViews render a blank
  /// page for raw PDF URLs; user can refresh / use toolbar to try direct URL.
  bool _useGoogleViewer = true;

  @override
  void initState() {
    super.initState();
    _pdfUri = AirportParkingService.invoiceRequestUri(widget.reference);
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFE5E7EB))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = error.description.isNotEmpty
                  ? error.description
                  : 'Could not load invoice page.';
            });
          },
        ),
      );
    _loadCurrentMode();
  }

  Uri get _webUri {
    if (_useGoogleViewer) {
      return Uri.parse(
        'https://docs.google.com/viewer?embedded=true&url='
        '${Uri.encodeComponent(_pdfUri.toString())}',
      );
    }
    return _pdfUri;
  }

  void _loadCurrentMode() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _webController.loadRequest(_webUri);
  }

  Future<void> _openInBrowser() async {
    final ok = await launchUrl(
      _pdfUri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open browser.')),
      );
    }
  }

  Future<void> _openDownloadedFile() async {
    final result = await OpenFile.open(widget.file.path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _shareInvoice() async {
    if (!await widget.file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice file is not available.')),
      );
      return;
    }

    final safeRef = widget.reference.trim().isEmpty
        ? 'invoice'
        : widget.reference.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');

    await SharePlus.instance.share(
      ShareParams(
        subject: 'Airport Parking Invoice $safeRef',
        text: 'Airport Parking invoice $safeRef',
        files: [
          XFile(
            widget.file.path,
            mimeType: 'application/pdf',
            name: 'airport_invoice_$safeRef.pdf',
          ),
        ],
      ),
    );
  }

  void _toggleViewerMode() {
    setState(() {
      _useGoogleViewer = !_useGoogleViewer;
    });
    _loadCurrentMode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Invoice',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            ),
            if (widget.reference.isNotEmpty)
              Text(
                widget.reference,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _textMuted,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh_rounded, color: _blue2),
            onPressed: _loadCurrentMode,
          ),
          IconButton(
            tooltip: 'Share invoice',
            icon: const Icon(Icons.share_rounded, color: _blue2),
            onPressed: _shareInvoice,
          ),
          IconButton(
            tooltip: 'Download invoice',
            icon: const Icon(Icons.download_rounded, color: _blue2),
            onPressed: _openDownloadedFile,
          ),
          // IconButton(
          //   tooltip: _useGoogleViewer
          //       ? 'Switch to direct PDF in WebView'
          //       : 'Switch to Google viewer',
          //   icon: Icon(
          //     _useGoogleViewer
          //         ? Icons.picture_as_pdf_outlined
          //         : Icons.chrome_reader_mode_outlined,
          //     color: _blue2,
          //   ),
          //   onPressed: _toggleViewerMode,
          // ),
          // IconButton(
          //   tooltip: 'Open in browser',
          //   icon: const Icon(Icons.language_rounded, color: _blue2),
          //   onPressed: _openInBrowser,
          // ),
          // IconButton(
          //   tooltip: 'Open downloaded file',
          //   icon: const Icon(Icons.folder_open_rounded, color: _blue2),
          //   onPressed: _openDownloadedFile,
          // ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Stack(
        children: [
          SizedBox(height: 100,),
          WebViewWidget(controller: _webController),
          if (_loading)
            const ColoredBox(
              color: Color(0xE6FFFFFF),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: _blue2,
                      strokeWidth: 2.5,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading invoice…',
                      style: TextStyle(
                        color: _textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null && !_loading)
            ColoredBox(
              color: const Color(0xFFF1F5F9),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: _blue2, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _openInBrowser,
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        label: const Text('Open in browser'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _toggleViewerMode,
                        child: Text(
                          _useGoogleViewer
                              ? 'Try direct PDF in WebView'
                              : 'Try Google viewer',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
