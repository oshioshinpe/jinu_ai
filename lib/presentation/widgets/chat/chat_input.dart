import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../../data/services/file_service.dart';
import '../ocr/ocr_screen.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({super.key});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  bool _isComposing = false;
  bool _isRecording = false;
  bool _includeWeb = false;
  File? _selectedImage;
  File? _selectedFile;
  String? _ocrText;
  String? _recordedAudioPath;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Auto-scroll to show input when focused
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final isLoading = state.isLoading || state.isStreaming;
        
        return Column(
          children: [
            // OCR Text Preview Popup
            if (_ocrText != null) _buildOcrPreview(),
            
            // Main Input Container
            Container(
              padding: ResponsiveUtils.responsivePadding(),
              child: Column(
                children: [
                  // Attachment previews
                  if (_selectedImage != null || _selectedFile != null)
                    _buildAttachmentPreview(),
                  
                  // Main input row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Text input field
                              TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                enabled: !isLoading,
                                maxLines: ResponsiveUtils.responsiveValue(
                                  mobile: 6.0,
                                  tablet: 8.0,
                                  desktop: 10.0,
                                ).round(),
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: isLoading 
                                      ? 'AI is thinking...' 
                                      : 'Type your message...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: AppConstants.spacingL,
                                    vertical: ResponsiveUtils.responsiveValue(
                                      mobile: AppConstants.spacingM,
                                      tablet: AppConstants.spacingL,
                                      desktop: AppConstants.spacingL,
                                    ),
                                  ),
                                ),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: ResponsiveUtils.responsiveFontSize(
                                    baseFontSize: 14,
                                  ),
                                ),
                                onChanged: (text) {
                                  setState(() {
                                    _isComposing = text.trim().isNotEmpty || 
                                                  _selectedImage != null || 
                                                  _selectedFile != null ||
                                                  _ocrText != null;
                                  });
                                },
                                onSubmitted: _isComposing && !isLoading 
                                    ? (_) => _sendMessage() 
                                    : null,
                                textInputAction: TextInputAction.send,
                                keyboardType: TextInputType.multiline,
                              ),
                              
                              // Action buttons row
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppConstants.spacingM,
                                  vertical: AppConstants.spacingS,
                                ),
                                child: Row(
                                  children: [
                                    // Web search toggle
                                    IconButton(
                                      icon: Icon(
                                        _includeWeb ? Icons.public : Icons.public_off,
                                        color: _includeWeb 
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                      onPressed: isLoading ? null : () {
                                        setState(() {
                                          _includeWeb = !_includeWeb;
                                        });
                                      },
                                      tooltip: 'Toggle web search',
                                    ),
                                    
                                    // File attachment
                                    IconButton(
                                      icon: const Icon(Icons.attach_file),
                                      onPressed: isLoading ? null : _attachFile,
                                      tooltip: 'Attach file',
                                    ),
                                    
                                    // Image attachment
                                    IconButton(
                                      icon: const Icon(Icons.image),
                                      onPressed: isLoading ? null : _attachImage,
                                      tooltip: 'Attach image',
                                    ),
                                    
                                    // OCR
                                    IconButton(
                                      icon: const Icon(Icons.document_scanner),
                                      onPressed: isLoading ? null : _openOcr,
                                      tooltip: 'OCR scan',
                                    ),
                                    
                                    // Voice recording
                                    IconButton(
                                      icon: Icon(
                                        _isRecording ? Icons.mic_off : Icons.mic,
                                        color: _isRecording 
                                            ? Theme.of(context).colorScheme.error
                                            : null,
                                      ),
                                      onPressed: isLoading ? null : _toggleRecording,
                                      tooltip: _isRecording ? 'Stop recording' : 'Voice input',
                                    ),
                                    
                                    const Spacer(),
                                    
                                    // Character count
                                    Text(
                                      '${_controller.text.length}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      _buildSendButton(isLoading),
                    ],
                  ),
                  
                  // Keyboard shortcut hint
                  if (ResponsiveUtils.isDesktop)
                    Padding(
                      padding: const EdgeInsets.only(top: AppConstants.spacingS),
                      child: Text(
                        'Press Ctrl+Enter to send',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSendButton(bool isLoading) {
    return Container(
      decoration: BoxDecoration(
        color: _isComposing && !isLoading
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
      ),
      child: IconButton(
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : Icon(
                Icons.send,
                color: _isComposing && !isLoading
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        onPressed: _isComposing && !isLoading ? _sendMessage : null,
        tooltip: 'Send message',
      ),
    );
  }

  Widget _buildOcrPreview() {
    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.document_scanner,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 16,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: Text(
                  'OCR text will be sent with your next message',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 16,
                ),
                onPressed: () {
                  setState(() {
                    _ocrText = null;
                    _isComposing = _controller.text.trim().isNotEmpty || 
                                  _selectedImage != null || 
                                  _selectedFile != null;
                  });
                },
                tooltip: 'Remove OCR text',
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingS),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingS),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            child: Text(
              _ocrText!.length > 100 
                  ? '${_ocrText!.substring(0, 100)}...'
                  : _ocrText!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      child: Row(
        children: [
          if (_selectedImage != null) _buildImagePreview(),
          if (_selectedFile != null) _buildFilePreview(),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(right: AppConstants.spacingS),
      child: Stack(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
              image: DecorationImage(
                image: FileImage(_selectedImage!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                  _isComposing = _controller.text.trim().isNotEmpty || 
                                _selectedFile != null ||
                                _ocrText != null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    return Container(
      margin: const EdgeInsets.only(right: AppConstants.spacingS),
      padding: const EdgeInsets.all(AppConstants.spacingS),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, size: 16),
          const SizedBox(width: AppConstants.spacingS),
          Text(
            _selectedFile!.path.split('/').last,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: AppConstants.spacingS),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedFile = null;
                _isComposing = _controller.text.trim().isNotEmpty || 
                              _selectedImage != null ||
                              _ocrText != null;
              });
            },
            child: Icon(
              Icons.close,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    String finalMessage = text;
    
    // Append OCR text if available
    if (_ocrText != null) {
      finalMessage = text.isEmpty 
          ? _ocrText! 
          : '$text\n\n--- OCR Text ---\n$_ocrText';
    }
    
    if (finalMessage.isNotEmpty || _selectedImage != null || _selectedFile != null) {
      // TODO: Implement sending with attachments
      context.read<ChatBloc>().add(SendChatMessage(content: finalMessage));
      
      _controller.clear();
      setState(() {
        _isComposing = false;
        _selectedImage = null;
        _selectedFile = null;
        _ocrText = null;
      });
      _focusNode.requestFocus();
    }
  }

  Future<void> _attachFile() async {
    try {
      final result = await FileService.pickAndReadFile();
      if (result != null) {
        setState(() {
          _selectedFile = File(result.fileName);
          _isComposing = true;
        });
        
        // Show file content in message
        final content = 'File: ${result.fileName}\n\n${result.content}';
        _controller.text = content;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _attachImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isComposing = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _openOcr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => OcrScreen(
          onTextExtracted: (text) {
            setState(() {
              _ocrText = text;
              _isComposing = true;
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      
      if (path != null) {
        _recordedAudioPath = path;
        // TODO: Implement audio transcription
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio recorded. Transcription coming soon!')),
        );
      }
    } else {
      // Start recording
      final permission = await Permission.microphone.request();
      if (permission.isGranted) {
        try {
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
            ),
          );
          setState(() {
            _isRecording = true;
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting recording: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
    }
  }
}