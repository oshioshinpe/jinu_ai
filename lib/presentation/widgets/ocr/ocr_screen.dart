import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:super_clipboard/super_clipboard.dart';
import '../../../data/services/ocr_service.dart';
import '../../../data/models/ocr_models.dart';
import '../../../core/constants/app_constants.dart';
import 'text_editor_screen.dart';

class OcrScreen extends StatefulWidget {
  final Function(String)? onTextExtracted;
  
  const OcrScreen({super.key, this.onTextExtracted});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  // IMPORTANT: Replace with your actual API key
  final OcrService _ocrService = OcrService('aa-b1BFjpcQHWHDgTWnpsfTGm7CwueIsSjrbl8UMD5ezCLaBPHY');

  final List<OcrTask> _tasks = [];
  final List<OcrHistoryItem> _history = [];

  bool _isProcessing = false;
  double _progress = 0.0;
  String _progressMessage = "";

  @override
  void initState() {
    super.initState();
    // In a real app, you would load history from storage here
  }

  // --- File/Task Management ---

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result != null) {
      _addFilesToQueue(result.paths.map((path) => File(path!)).toList());
    }
  }
  
  Future<void> _scanDocument() async {
     try {
      final scannedImages = await FlutterDocScanner().getScannedDocumentAsImages() ?? [];
      if (scannedImages.isNotEmpty) {
        _addFilesToQueue(scannedImages.map((img) => File(img['path'])).toList());
         _showSnackbar("Scanned documents added to queue.", isError: false);
      }
     } on PlatformException {
        _showSnackbar('Failed to get scanned documents.', isError: true);
     }
  }

  Future<void> _pasteFromClipboard() async {
    final reader = await ClipboardReader.readClipboard();
    if (reader.canProvide(Formats.png)) {
      final img = await reader.read(Formats.png);
      if(img != null) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(path);
        await file.writeAsBytes(img);
        _addFilesToQueue([file]);
        _showSnackbar("Image from clipboard added to queue.", isError: false);
      }
    } else {
       _showSnackbar("No image found on the clipboard.", isError: true);
    }
  }

  void _addFilesToQueue(List<File> files) {
    setState(() {
      for (var file in files) {
        final task = OcrTask(id: DateTime.now().millisecondsSinceEpoch.toString(), file: file);
        _tasks.add(task);
      }
    });
  }

  // --- BATCH PROCESSING ---

  Future<void> _startProcessing() async {
    if (_isProcessing || _tasks.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressMessage = "Starting process...";
    });

    int successfulCount = 0;
    int failedCount = 0;

    for (int i = 0; i < _tasks.length; i++) {
        final task = _tasks[i];
        
        setState(() {
          task.status = TaskStatus.processing;
          _progress = (i) / _tasks.length;
          _progressMessage = "Processing ${p.basename(task.file.path)} (${i+1}/${_tasks.length})";
        });

        try {
          final result = await _ocrService.processFile(task.file);

          setState(() {
            task.status = TaskStatus.success;
            task.ocrResultText = result.fullMarkdownText;
            successfulCount++;
          });
        } catch (e) {
          setState(() {
            task.status = TaskStatus.failed;
            task.errorMessage = e.toString();
            failedCount++;
          });
        }
    }

    _moveToHistory();

    setState(() {
      _isProcessing = false;
      _progress = 1.0;
      _progressMessage = "Processing Complete!";
   });
   _showSnackbar("Batch complete: $successfulCount succeeded, $failedCount failed.", isError: failedCount > 0);
  }

  void _moveToHistory() {
     final List<OcrHistoryItem> newHistory = _tasks.map((task) => OcrHistoryItem(
        id: task.id,
        inputFileName: p.basename(task.file.path),
        outputText: task.ocrResultText ?? task.errorMessage ?? "No output",
        timestamp: DateTime.now(),
        wasSuccessful: task.status == TaskStatus.success
      )).toList();

      setState(() {
        _history.insertAll(0, newHistory);
        _tasks.clear();
      });
      // In a real app, save _history to storage here
  }
  
  // --- UI Methods ---

  void _showResult(OcrHistoryItem item) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => TextEditorScreen(
        content: item.outputText,
        fileName: item.inputFileName,
        isEditable: item.wasSuccessful,
        onUseInChat: widget.onTextExtracted,
      )
    ));
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("OCR Service"),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          children: [
            _buildActionButtons(),
            const SizedBox(height: AppConstants.spacingL),
            if (_isProcessing) _buildProgressIndicator(),
            Expanded(
              child: _tasks.isNotEmpty 
                  ? _buildTaskList() 
                  : _buildHistoryList(),
            ),
          ],
        ),
      ),
      floatingActionButton: _tasks.isNotEmpty && !_isProcessing
          ? FloatingActionButton.extended(
              onPressed: _startProcessing,
              label: const Text("Process Queue"),
              icon: const Icon(Icons.start),
              backgroundColor: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }
  
  // --- WIDGET BUILDERS ---

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _actionButton(Icons.attach_file, "Pick Files", _pickFiles),
        _actionButton(Icons.camera_alt_outlined, "Scan", _scanDocument),
        _actionButton(Icons.content_paste, "Paste", _pasteFromClipboard),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isProcessing ? null : onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(AppConstants.spacingM),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          child: Icon(icon, size: 28),
        ),
        const SizedBox(height: AppConstants.spacingS),
        Text(
          label, 
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
      child: Column(
        children: [
          Text(
            _progressMessage, 
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return _buildCard(
      title: "Processing Queue (${_tasks.length})",
      child: ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return ListTile(
            leading: _getStatusIcon(task.status),
            title: Text(
              p.basename(task.file.path), 
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.close, 
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              onPressed: _isProcessing ? null : () => setState(() => _tasks.removeAt(index)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Text(
          "No history yet.\nAdd files to get started!", 
          textAlign: TextAlign.center, 
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }
    return _buildCard(
      title: "History",
      child: ListView.builder(
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          return Card(
            color: Theme.of(context).colorScheme.surfaceVariant,
            margin: const EdgeInsets.symmetric(vertical: AppConstants.spacingXS),
            child: ListTile(
              leading: Icon(
                item.wasSuccessful ? Icons.check_circle : Icons.error,
                color: item.wasSuccessful 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text(
                item.inputFileName, 
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Text(
                item.timestamp.toLocal().toString().substring(0, 16), 
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              onTap: () => _showResult(item),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppConstants.spacingXS, bottom: AppConstants.spacingS),
          child: Text(
            title, 
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }

  Icon _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.queued:
        return Icon(Icons.hourglass_empty, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6));
      case TaskStatus.processing:
        return Icon(Icons.sync, color: Theme.of(context).colorScheme.primary);
      case TaskStatus.success:
        return Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary);
      case TaskStatus.failed:
        return Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error);
    }
  }
}