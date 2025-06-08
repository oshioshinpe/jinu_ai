import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/plaintext.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/services/file_service.dart';

class TextEditorScreen extends StatefulWidget {
  final String content;
  final String fileName;
  final bool isEditable;
  final Function(String)? onUseInChat;

  const TextEditorScreen({
    super.key,
    required this.content,
    required this.fileName,
    this.isEditable = true,
    this.onUseInChat,
  });

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late CodeController _controller;
  bool _showingInChat = false;

  @override
  void initState() {
    super.initState();
    _controller = CodeController(
      text: widget.content,
      language: widget.fileName.endsWith('.md') ? markdown : plaintext,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Content copied to clipboard')),
    );
  }

  void _useInChat() {
    if (widget.onUseInChat != null) {
      widget.onUseInChat!(_controller.text);
      setState(() {
        _showingInChat = true;
      });
      
      // Show popup notification
      _showChatPopup();
    }
  }

  void _showChatPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.chat, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppConstants.spacingS),
            const Text('Text Added to Chat'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The extracted text will be sent with your next message.'),
            const SizedBox(height: AppConstants.spacingM),
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingS),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
              ),
              child: Text(
                _controller.text.length > 100 
                    ? '${_controller.text.substring(0, 100)}...'
                    : _controller.text,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Close text editor too
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAsFile() async {
    try {
      final fileName = await _showFileNameDialog();
      if (fileName == null || fileName.isEmpty) return;

      final extension = await _showExtensionDialog();
      if (extension == null) return;

      final filePath = await FileService.saveContentToFile(
        content: _controller.text,
        fileName: fileName,
        extension: extension,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showFileNameDialog() async {
    final controller = TextEditingController(
      text: widget.fileName.split('.').first,
    );

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter file name',
            labelText: 'File Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showExtensionDialog() async {
    String selectedExtension = 'txt';

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select File Type'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedExtension,
                decoration: const InputDecoration(labelText: 'File Extension'),
                items: FileService.supportedExtensions.map((ext) {
                  return DropdownMenuItem(value: ext, child: Text('.$ext'));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedExtension = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(selectedExtension),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'Copy to clipboard',
          ),
          if (widget.onUseInChat != null)
            IconButton(
              icon: Icon(
                _showingInChat ? Icons.check_circle : Icons.chat,
                color: _showingInChat ? Colors.green : null,
              ),
              onPressed: _showingInChat ? null : _useInChat,
              tooltip: _showingInChat ? 'Added to chat' : 'Use in chat',
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAsFile,
            tooltip: 'Save as file',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          children: [
            if (!widget.isEditable)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      size: 16,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Text(
                        'This content is read-only due to processing errors',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!widget.isEditable) const SizedBox(height: AppConstants.spacingM),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
                child: CodeTheme(
                  data: CodeThemeData(styles: githubTheme),
                  child: CodeField(
                    controller: _controller,
                    readOnly: !widget.isEditable,
                    textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Text(
                    'Characters: ${_controller.text.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}