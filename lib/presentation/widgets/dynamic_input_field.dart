import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jinu/data/models/chat_message.dart';
import 'package:jinu/data/models/file_model.dart';
import 'package:jinu/data/services/file_service.dart';
import 'package:jinu/presentation/providers/file_service_provider.dart';
//import 'package:jinu/data/models/file_model.dart';
import 'package:jinu/presentation/providers/chat_providers.dart';
import 'package:uuid/uuid.dart'; // Import the chat controller provider

typedef SendTextCallback = void Function(String text);
typedef SendFileCallback = void Function(ChatMessage placeholder, File file);

class DynamicInputField extends ConsumerStatefulWidget {
  final bool isLoading;
  final SendTextCallback onSendText;
  final SendFileCallback onSendFile;

  const DynamicInputField({
    super.key,
    required this.isLoading,
    required this.onSendText,
    required this.onSendFile,
  });

  @override
  ConsumerState<DynamicInputField> createState() => _DynamicInputFieldState();
}

enum _PickSource { gallery, camera, fileStorage }

class _DynamicInputFieldState extends ConsumerState<DynamicInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showSendButton = false;
  bool _isRecordingAudio = false;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateSendButtonVisibility);
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.removeListener(_updateSendButtonVisibility);
    _controller.dispose();
    _focusNode.dispose();
    _recordingTimer?.cancel();
    final fileService = ref.read(fileServiceProvider);
    if (fileService.isRecording) {
      fileService.cancelRecording().catchError((e) {
        debugPrint("Error cancelling recording on dispose: $e");
      });
    }
    super.dispose();
  }

  void _updateSendButtonVisibility() {
    if (mounted) {
      setState(() {
        _showSendButton = _controller.text.trim().isNotEmpty;
      });
    }
  }

  void _handleSendText() {
    final text = _controller.text.trim();
    if (!widget.isLoading && text.isNotEmpty) {
      widget.onSendText(text);
      _controller.clear();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      // Check if Shift is pressed for new line
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored; // Allow new line
      }
      
      // For desktop/web platforms, require Ctrl+Enter to send
      // For mobile platforms, Enter alone should not send (use send button instead)
      final bool isDesktopPlatform = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
      final bool isWebPlatform = kIsWeb;
      
      if (isDesktopPlatform || isWebPlatform) {
        // Desktop/Web: Require Ctrl+Enter to send
        if (HardwareKeyboard.instance.isControlPressed) {
          if (_showSendButton && !_isRecordingAudio && !widget.isLoading) {
            _handleSendText();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored; // Don't send on Enter alone
      } else {
        // Mobile: Don't send on Enter, use send button instead
        return KeyEventResult.ignored;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handleAttachment() async {
    if (widget.isLoading || _isRecordingAudio) return;
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Wrap(
                children: <Widget>[
                  _buildFileUploadOption(
                    icon: Icons.photo_library_outlined,
                    text: 'Pick Image from Gallery',
                    onTap: () => _pickAndSendFile(_PickSource.gallery),
                  ),
                  _buildFileUploadOption(
                    icon: Icons.camera_alt_outlined,
                    text: 'Take Photo with Camera',
                    onTap: () => _pickAndSendFile(_PickSource.camera),
                  ),
                  _buildFileUploadOption(
                    icon: Icons.attach_file_outlined,
                    text: 'Pick Audio or Other File',
                    onTap: () => _pickAndSendFile(_PickSource.fileStorage),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildFileUploadOption({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 26,
      ),
      title: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      horizontalTitleGap: 8.0,
    );
  }

Future<void> _pickAndSendFile(_PickSource source) async {
  if (widget.isLoading) return;
  final fileService = ref.read(fileServiceProvider);
  FileModel? pickedFileModel;
  ContentType contentType = ContentType.file;

  try {
    switch (source) {
      case _PickSource.gallery:
        pickedFileModel = await fileService.pickImageFromGallery();
        if (pickedFileModel != null) contentType = ContentType.image;
        break;
      case _PickSource.camera:
        pickedFileModel = await fileService.takePhotoWithCamera();
        if (pickedFileModel != null) contentType = ContentType.image;
        break;
      case _PickSource.fileStorage:
        pickedFileModel = await fileService.pickFile(allowedExtensions: null);
        if (pickedFileModel != null) {
          final mime = pickedFileModel.mimeType;
          if (mime != null) {
            if (mime.startsWith('image/')) {
              contentType = ContentType.image;
            } else if (mime.startsWith('audio/')) {
              contentType = ContentType.audio;
            }
          }
        }
        break;
    }

    if (pickedFileModel != null) {
      // Create placeholder with unique ID
      final placeholder = ChatMessage(
        id: const Uuid().v4(), // Ensure unique ID
        sender: MessageSender.user,
        content: contentType == ContentType.audio
            ? '[Audio: ${pickedFileModel.file.path.split('/').last}]'
            : contentType == ContentType.image
            ? '[Image: ${pickedFileModel.file.path.split('/').last}]'
            : '[File: ${pickedFileModel.file.path.split('/').last}]',
        timestamp: DateTime.now(),
        filePath: pickedFileModel.file.path,
        contentType: contentType,
        fileName: pickedFileModel.file.path.split('/').last,
        mimeType: pickedFileModel.mimeType,
        fileSize: await pickedFileModel.file.length().catchError((e) {
          debugPrint("Error getting file size: $e");
          return 0;
        }), // Add file size with error handling
      );
      
      // Only call onSendFile once
      widget.onSendFile(placeholder, pickedFileModel.file);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File selection cancelled or failed.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e, s) {
    debugPrint("Error picking/sending file: $e\n$s");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error selecting file: ${e.toString().substring(0, min(e.toString().length, 50))}...',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

  Future<void> _startAudioRecording() async {
    if (widget.isLoading || _isRecordingAudio) return;
    final fileService = ref.read(fileServiceProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final granted = await fileService.requestMicrophonePermission();
    if (!granted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone permission denied. Please enable it in settings.',
          ),
        ),
      );
      return;
    }

    try {
      bool success = await fileService.startRecording();
      if (success) {
        if (mounted) {
          setState(() {
            _isRecordingAudio = true;
            _recordingDuration = Duration.zero;
          });
        }
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted || !_isRecordingAudio) {
            timer.cancel();
            return;
          }
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        });
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Failed to start recording.')),
        );
      }
    } catch (e) {
      debugPrint("Error starting recording: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
      if (mounted) setState(() => _isRecordingAudio = false);
    }
  }

  Future<void> _stopAudioRecordingAndSend() async {
    if (!mounted || !_isRecordingAudio) return;
    _recordingTimer?.cancel();
    final fileService = ref.read(fileServiceProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (mounted) setState(() => _isRecordingAudio = false);

    try {
      FileModel? audioFileModel = await fileService.stopRecording();
      if (mounted) {
        _recordingDuration = Duration.zero;
      }

      if (audioFileModel != null) {
        final placeholder = ChatMessage(
          id: const Uuid().v4(), // Ensure unique ID for audio recording
          sender: MessageSender.user,
          content:
              '[Audio Recording: ${audioFileModel.file.path.split('/').last}]',
          timestamp: DateTime.now(),
          filePath: audioFileModel.file.path,
          contentType: ContentType.audio,
          fileName: audioFileModel.file.path.split('/').last,
          mimeType: audioFileModel.mimeType,
          fileSize: await audioFileModel.file.length().catchError((e) {
            debugPrint("Error getting audio file size: $e");
            return 0;
          }),
        );
        widget.onSendFile(placeholder, audioFileModel.file);
      } else if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Recording captured no audio or failed.'),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error stopping/sending recording: $e");
      if (mounted) {
        _recordingDuration = Duration.zero;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error processing recording: $e')),
        );
      }
    }
  }

  Future<void> _cancelAudioRecording() async {
    if (!mounted || !_isRecordingAudio) return;
    _recordingTimer?.cancel();
    final fileService = ref.read(fileServiceProvider);
    try {
      await fileService.cancelRecording();
    } catch (e) {
      debugPrint("Error cancelling recording: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isRecordingAudio = false;
          _recordingDuration = Duration.zero;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  String _getHintText() {
    final bool isDesktopPlatform = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final bool isWebPlatform = kIsWeb;
    
    if (isDesktopPlatform || isWebPlatform) {
      return 'Type a message (Ctrl+Enter to send, Shift+Enter for new line)';
    } else {
      return 'Type a message (Shift+Enter for new line, tap send button)';
    }
  }

  String _getSendButtonTooltip() {
    final bool isDesktopPlatform = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final bool isWebPlatform = kIsWeb;
    
    if (isDesktopPlatform || isWebPlatform) {
      return 'Send Message (Ctrl+Enter)';
    } else {
      return 'Send Message';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canInteractGenerally = !widget.isLoading && !_isRecordingAudio;
    final theme = Theme.of(context);

    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color:
              _isRecordingAudio
                  ? Colors.red.withOpacity(0.1)
                  : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(30.0),
          border: Border.all(
            color:
                _focusNode.hasFocus
                    ? theme.colorScheme.primary.withOpacity(0.8)
                    : theme.dividerColor,
            width: _focusNode.hasFocus ? 1.8 : 1.2,
          ),
          boxShadow:
              _focusNode.hasFocus
                  ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                  : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: canInteractGenerally ? _handleAttachment : null,
              tooltip: 'Attach Image, Audio, or File',
              color:
                  canInteractGenerally
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.disabledColor,
              iconSize: 26,
              splashRadius: 22,
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      (theme.textTheme.bodyLarge?.fontSize ?? 16.0) * 6.0 +
                      24.0,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: _isRecordingAudio
                        ? 'Recording... Tap stop to send'
                        : _getHintText(),
                    hintStyle: TextStyle(
                      color: theme.hintColor,
                      fontSize: 15.5,
                    ),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    isCollapsed: true,
                  ),
                  style: TextStyle(
                    fontSize: 15.5,
                    color: theme.colorScheme.onSurface,
                    height: 1.45,
                  ),
                  maxLines: null,
                  minLines: 1,
                  enabled: canInteractGenerally,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  onTapOutside: (event) {
                    if (_focusNode.hasFocus) _focusNode.unfocus();
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            _buildDynamicActionButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicActionButton(BuildContext context) {
    final theme = Theme.of(context);
    final bool generalLoadingNotRecording =
        widget.isLoading && !_isRecordingAudio;

    return SizedBox(
      height: 48,
      width: _isRecordingAudio ? null : 48,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutQuad,
          switchOutCurve: Curves.easeInQuad,
          child:
              generalLoadingNotRecording
                  ? _buildLoadingIndicator(theme)
                  : _isRecordingAudio
                  ? _buildRecordingControls(theme)
                  : _showSendButton
                  ? _buildSendButton(theme)
                  : _buildMicButton(theme),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(ThemeData theme) {
    return IconButton(
      key: const ValueKey('loading_indicator'),
      icon: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: theme.disabledColor,
        ),
      ),
      onPressed: null,
      tooltip: 'Processing...',
    );
  }

  Widget _buildRecordingControls(ThemeData theme) {
    return Row(
      key: const ValueKey('recording_controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.stop_circle_outlined,
            color: Colors.redAccent,
            size: 28,
          ),
          onPressed: _stopAudioRecordingAndSend,
          tooltip: 'Stop and Send Recording',
          splashRadius: 22,
        ),
        IconButton(
          icon: Icon(
            Icons.cancel_rounded,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            size: 22,
          ),
          onPressed: _cancelAudioRecording,
          tooltip: 'Cancel Recording',
          splashRadius: 18,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2.0, right: 8.0),
          child: Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    return IconButton(
      key: const ValueKey('send_button'),
      icon: Icon(
        Icons.send_rounded,
        size: 24,
        color: theme.colorScheme.primary,
      ),
      onPressed: widget.isLoading ? null : _handleSendText,
      tooltip: _getSendButtonTooltip(),
    );
  }

  Widget _buildMicButton(ThemeData theme) {
    return IconButton(
      key: const ValueKey('mic_button'),
      icon: Icon(
        Icons.mic_none_rounded,
        size: 26,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onPressed: widget.isLoading ? null : _startAudioRecording,
      tooltip: 'Record Audio',
    );
  }
}