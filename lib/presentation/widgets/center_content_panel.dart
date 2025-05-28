import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jinu/data/models/chat_message.dart';
import 'package:jinu/data/models/chat_session_item.dart';
import 'package:jinu/presentation/providers/settings_provider.dart';
import 'package:jinu/presentation/screens/settings_page.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../providers/chat_providers.dart';
import '../../data/services/chat_history_service.dart';
import 'chat_message_widget.dart';
import 'dynamic_input_field.dart';
import 'package:just_audio/just_audio.dart';

final isWebSearchEnabledProvider = StateProvider<bool>((ref) => false);
final voiceOutputEnabledProvider = StateProvider<bool>((ref) => false);
final bool jumpbool = false;
class CenterContentPanel extends ConsumerStatefulWidget {
  final bool isMobileLayout;
  const CenterContentPanel({super.key, required this.isMobileLayout});

  @override
  ConsumerState<CenterContentPanel> createState() => _CenterContentPanelState();
}

class _CenterContentPanelState extends ConsumerState<CenterContentPanel> {
  final ScrollController _scrollController = ScrollController();
  final Uuid _uuid = const Uuid();
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer?.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        debugPrint("TTS playback completed.");
        ref.read(newTtsFileProvider.notifier).state = null; // Clear the provider
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _scrollToBottom({required bool jumpbool, double? specificPosition}) {
    if (!mounted || !_scrollController.hasClients) return;
    Future.delayed(Duration(milliseconds: jumpbool ? 50 : 200), () {
      if (!mounted || !_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final viewportHeight = _scrollController.position.viewportDimension;
      final contentHeight = _scrollController.position.extentTotal;

      // Scroll if near bottom, content doesn't fill viewport, jump requested, or streaming
      final shouldScroll = jumpbool ||
          (maxScroll - currentScroll < 300) ||
          (contentHeight < viewportHeight) ||
          ref.read(activeChatMessagesProvider).any((m) => m.isStreaming);

      if (shouldScroll) {
        if (jumpbool) {
          _scrollController.jumpTo(specificPosition ?? maxScroll);
        } else {
          _scrollController.animateTo(
            specificPosition ?? maxScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuad,
          );
        }
      }
    });
  }

  void _sendTextMessage(String text) {
    final isWebSearchActive = ref.read(isWebSearchEnabledProvider);
    final voiceOutputActive = ref.read(voiceOutputEnabledProvider);
    ref.read(chatControllerProvider.notifier).sendMessageStreaming(
          text,
          isWebSearchEnabled: isWebSearchActive,
          voiceOutputEnabled: voiceOutputActive,
        );
  }

Future<void> _handleFileUpload(ChatMessage placeholder, File file) async {
  final activeSessionId = ref.read(activeChatIdProvider);
  if (activeSessionId == null) {
    debugPrint("Cannot send file: No active session.");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: No active chat session.")),
      );
    }
    return;
  }

  // Check if message with this ID already exists to prevent duplicates
  final existingMessages = ref.read(activeChatMessagesProvider);
  if (existingMessages.any((msg) => msg.id == placeholder.id)) {
    debugPrint("Message with ID ${placeholder.id} already exists, skipping duplicate");
    return;
  }

  // Add placeholder to chat history ONLY ONCE
  await ref.read(chatHistoryServiceProvider).addMessageToSession(activeSessionId, placeholder);
  _scrollToBottom(jumpbool: true);

  // Process file based on content type WITHOUT creating another message
  if (placeholder.contentType == ContentType.audio) {
    ref.read(chatControllerProvider.notifier).transcribeAndSendAudio(file);
  } else {
    // Make sure sendMessageWithAttachment doesn't create duplicate user message
    ref.read(chatControllerProvider.notifier).sendMessageWithAttachment(placeholder, file);
  }
}

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(activeChatMessagesProvider);
    final currentSession = ref.watch(activeChatSessionProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final chatControllerState = ref.watch(chatControllerProvider);
    final isWebSearch = ref.watch(isWebSearchEnabledProvider);
    final voiceOutput = ref.watch(voiceOutputEnabledProvider);
    final settings = ref.watch(settingsServiceProvider);

    // Auto-scroll on message updates or streaming
    ref.listen<List<ChatMessage>>(activeChatMessagesProvider, (prev, next) {
      if (prev == null || next.length > prev.length || next.any((m) => m.isStreaming)) {
        _scrollToBottom(jumpbool: next.any((m) => m.isStreaming));
      } else if (prev != null && next.length == prev.length) {
        // Check if any message content has changed (streaming updates)
        bool hasContentChanged = false;
        for (int i = 0; i < next.length && i < prev.length; i++) {
          if (next[i].content != prev[i].content || next[i].isStreaming != prev[i].isStreaming) {
            hasContentChanged = true;
            break;
          }
        }
        if (hasContentChanged) {
          _scrollToBottom(jumpbool: false);
        }
      }
    });

    ref.listen<bool>(isLoadingProvider, (_, nextIsLoading) {
      if (nextIsLoading || !nextIsLoading) {
        _scrollToBottom(jumpbool: true);
      }
    });

    ref.listen<ChatSessionItem?>(activeChatSessionProvider, (prev, nextSession) {
      if (nextSession != null && (prev == null || prev.id != nextSession.id)) {
        _scrollToBottom(jumpbool: true, specificPosition: 0.0);
        Future.delayed(const Duration(milliseconds: 200), () => _scrollToBottom(jumpbool: true));
      }
    });

    // Play TTS audio when new file is available
    ref.listen<File?>(newTtsFileProvider, (_, newFile) async {
      if (newFile != null && _audioPlayer != null) {
        try {
          await _audioPlayer!.setFilePath(newFile.path);
          await _audioPlayer!.play();
        } catch (e) {
          debugPrint("Error playing TTS audio: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error playing AI voice: $e')),
            );
          }
        }
      }
    });

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          if (!widget.isMobileLayout)
            _buildDesktopTopBar(
              context,
              currentSession?.displayTitle ?? "New Chat",
            ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isMobileLayout ? 12.0 : 24.0,
              vertical: 6.0,
            ),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: widget.isMobileLayout ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
              children: [
      // settings.defaultchatmodel.contains("web"))
                  _buildToggleSwitch(
                    label: 'Web Search:',
                    value: isWebSearch,
                    onChanged: isLoading
                        ? null
                        : (value) {
                            ref.read(isWebSearchEnabledProvider.notifier).state = value;
                          },
                  ), 
                const SizedBox(width: 16),
                _buildToggleSwitch(
                  label: 'Voice Mode:',
                  value: voiceOutput,
                  onChanged: isLoading
                      ? null
                      : (value) {
                          ref.read(voiceOutputEnabledProvider.notifier).state = value;
                        },
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.isMobileLayout ? 8.0 : 24.0),
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: _buildChatListOrPlaceholder(context, messages, currentSession),
              ),
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            ),
          chatControllerState.maybeWhen(
            error: (error, stackTrace) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[700]!, width: 0.5),
                ),
                child: Text(
                  "Error: $error",
                  style: TextStyle(color: Colors.red[200], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.isMobileLayout ? 10.0 : 24.0,
              8.0,
              widget.isMobileLayout ? 10.0 : 24.0,
              widget.isMobileLayout ? 12.0 : 20.0,
            ),
            child: DynamicInputField(
              isLoading: isLoading,
              onSendText: _sendTextMessage,
              onSendFile: _handleFileUpload,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(width: 4),
        SizedBox(
          height: 24,
          width: 40,
          child: Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Theme.of(context).colorScheme.primary,
              activeTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              inactiveThumbColor: Colors.grey[500],
              inactiveTrackColor: Colors.grey[800],
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTopBar(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1.0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _buildTopBarButton(
            context,
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
  // Widget _buildWebSearchToggle() {
  //   final isWebSearchEnabled = ref.watch(isWebSearchEnabledProvider);
  //   return Row(
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       const Text('Web Search', style: TextStyle(fontSize: 12)),
  //       const SizedBox(width: 4),
  //       Switch(
  //         value: isWebSearchEnabled,
  //         onChanged: isWebSearchEnabledProvider.overrideWith()
  //             ? null
  //             : (value) => ref.read(isWebSearchEnabledProvider.notifier).state = value,
  //         activeColor: Theme.of(context).colorScheme.primary,
  //       ),
  //     ],
  //   );
  // }

  Widget _buildTopBarButton(BuildContext context,
      {required IconData icon, required String tooltip, VoidCallback? onPressed}) {
    return IconButton(
      icon: Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: 20,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildChatListOrPlaceholder(
      BuildContext context, List<ChatMessage> messages, ChatSessionItem? currentSession) {
    if (currentSession == null && messages.isEmpty) {
      return _buildGettingStartedPlaceholder(context, "No chat selected");
    } else if (messages.isEmpty && currentSession != null) {
      return _buildGettingStartedPlaceholder(context, "Send a message, image, or audio to start this chat...");
    } else {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return ChatMessageWidget(key: ValueKey(message.id), message: message);
        },
      );
    }
  }

  Widget _buildGettingStartedPlaceholder(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Your conversation will appear here. Ask questions, upload files, or record audio.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}