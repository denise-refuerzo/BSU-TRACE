import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart'; // Modern gallery saver
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class QrDownloadModal extends StatefulWidget {
  final String qrData;
  final String documentTitle;

  const QrDownloadModal({
    Key? key, 
    required this.qrData,
    this.documentTitle = "Document",
  }) : super(key: key);

  @override
  _QrDownloadModalState createState() => _QrDownloadModalState();
}

class _QrDownloadModalState extends State<QrDownloadModal> {
  final ScreenshotController screenshotController = ScreenshotController();
  bool _isSaving = false;

  Future<void> _saveAsImage() async {
    setState(() => _isSaving = true);
    
    try {
      // Check and request permissions using Gal's native handler
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }

      final Uint8List? imageBytes = await screenshotController.capture();
      
      if (imageBytes != null) {
        // Save to gallery, creating a specific album for your app
        await Gal.putImageBytes(imageBytes, album: 'BSU Trace');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Code saved to gallery!')),
          );
          Navigator.of(context).pop(); 
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
    
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _saveAsPdf() async {
    setState(() => _isSaving = true);
    
    final Uint8List? imageBytes = await screenshotController.capture();

    if (imageBytes != null) {
      final pdf = pw.Document();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'BSU-Trace QR: ${widget.documentTitle}', 
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)
                  ),
                  pw.SizedBox(height: 20),
                  pw.Image(image, width: 250, height: 250),
                  pw.SizedBox(height: 20),
                  pw.Text('Scan this code to track or update the document status.'),
                ]
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'BSU_Trace_QR_${widget.documentTitle.replaceAll(' ', '_')}.pdf',
      );
      
      if (mounted) Navigator.of(context).pop(); 
    }
    
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            const Text(
              'Download QR Code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Screenshot(
              controller: screenshotController,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: QrImageView(
                  data: widget.qrData,
                  version: QrVersions.auto,
                  size: 180.0,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isSaving)
              const CircularProgressIndicator()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saveAsImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Save to Gallery'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _saveAsPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export as PDF'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            )
          ],
        ),
      ),
    );
  }
}