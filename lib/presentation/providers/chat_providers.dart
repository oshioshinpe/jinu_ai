import 'dart:convert';
import 'dart:io';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:jinu/core/constants.dart';
import 'package:jinu/data/services/chat_history_service.dart';
import 'package:jinu/presentation/providers/api_providers.dart';
import 'package:mime/mime.dart';
import 'package:pinecone/pinecone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:jinu/data/models/chat_message.dart';
import 'package:jinu/data/models/chat_session_item.dart';
import 'package:jinu/presentation/providers/settings_provider.dart';
class ChatController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  ChatController(this.ref) : super(const AsyncData(null));


//  ChatController(this.ref) : super(const AsyncData(null));

  Future<void> sendMessageWithAttachment(
    ChatMessage userMessagePlaceholder,
    File attachmentFile,
  ) async {
    state = const AsyncLoading();
    ref.read(isLoadingProvider.notifier).state = true;

    final contentType = _determineContentType(userMessagePlaceholder.mimeType);
    debugPrint("Sending attachment of type: $contentType");

    if (contentType == ContentType.image) {
      await _sendImageMessage(
        userMessagePlaceholder.content,
        attachmentFile,
      );
    } else if (contentType == ContentType.audio) {
      await _transcribeAndSendAudio(attachmentFile);
    } else {
      debugPrint("Generic file attached, not processed by LLM.");
      ref.read(isLoadingProvider.notifier).state = false;
      state = const AsyncData(null);
    }
  }

  ContentType _determineContentType(String? mimeType) {
    if (mimeType == null) return ContentType.file;
    if (mimeType.startsWith('image/')) return ContentType.image;
    if (mimeType.startsWith('audio/')) return ContentType.audio;
    return ContentType.file;
  }

  Future<void> _sendImageMessage(String text, File imageFile) async {
    // Logic for sending image with text to OpenAI API
    try {
      // Placeholder for API call with image
      debugPrint("Sending image: ${imageFile.path}");
      // Add logic to handle image with base64 encoding if necessary
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError("Failed to send image: $e", StackTrace.current);
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _transcribeAndSendAudio(File audioFile) async {
    // Placeholder for audio transcription logic
    try {
      debugPrint("Transcribing audio: ${audioFile.path}");
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError("Failed to transcribe audio: $e", StackTrace.current);
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
    }
  }
final isLoadingProvider = StateProvider<bool>((ref) => false);
final chatControllerProvider =
    StateNotifierProvider<ChatController, AsyncValue<void>>(
        (ref) => ChatController(ref));

// Streaming response providers
final streamingMessageProvider = StateProvider<String?>((ref) => null);
final isStreamingProvider = StateProvider<bool>((ref) => false);
final streamingMessageIdProvider = StateProvider<String?>((ref) => null);


  Future<void> sendMessageStreaming(
    String text, {
    File? imageFile,
    required bool isWebSearchEnabled,
    required bool voiceOutputEnabled,
  }) async {
    state = const AsyncLoading();
    ref.read(isLoadingProvider.notifier).state = true;
    ref.read(isStreamingProvider.notifier).state = true;
    ref.read(streamingMessageProvider.notifier).state = "";
    
    final historyService = ref.read(chatHistoryServiceProvider);
    final settings = ref.read(settingsServiceProvider);
    final chatService = ref.read(aiCompanionServiceProvider);
    final titleService = ref.read(titleGeneratorServiceProvider);

    String? currentSessionId = historyService.activeChatId;
    ChatSessionItem? currentSession;
    if (currentSessionId == null) {
      currentSession = await historyService.startNewChat();
      currentSessionId = currentSession.id;
    } else {
      currentSession = historyService.getSessionById(currentSessionId);
    }
    
    final historyEnabled = settings.historychatenabled;
    final String modelToUse;
    if (imageFile != null) {
      modelToUse =
          settings.visionprocessingmodel.isNotEmpty
              ? settings.visionprocessingmodel
              : "gpt-4o-mini";
    } else if (isWebSearchEnabled) {
      modelToUse = "gpt-4o-mini-search-preview";
    } else {
      modelToUse = settings.defaultchatmodel;
    }
    
    if (historyEnabled) {
      currentSession = historyService.getSessionById(currentSessionId);
      if (currentSession == null) {
        currentSession = await historyService.startNewChat();
        currentSessionId = currentSession.id;
      }
    } else {
      state = AsyncError("Chat history is disabled", StackTrace.current);
      ref.read(isLoadingProvider.notifier).state = false;
      ref.read(isStreamingProvider.notifier).state = false;
      return;
    }

    final userMessage = ChatMessage(
      sender: MessageSender.user,
      content: text,
      timestamp: DateTime.now(),
      filePath: imageFile?.path,
      contentType: imageFile != null ? ContentType.image : ContentType.text,
      fileName: imageFile?.path.split('/').last,
    );

    try {
      await historyService.addMessageToSession(currentSessionId, userMessage);
      currentSession = historyService.getSessionById(currentSessionId);
    } catch (e, s) {
      state = AsyncError("Failed to save user message", s);
      ref.read(isLoadingProvider.notifier).state = false;
      ref.read(isStreamingProvider.notifier).state = false;
      return;
    }

    // Generate title if needed
    final bool isFirstUserMessage =
        currentSession?.messages
            .where((m) => m.sender == MessageSender.user)
            .length ==
        1;
    if (settings.autotitle &&
        isFirstUserMessage &&
        historyEnabled &&
        text.isNotEmpty) {
      try {
        final generatedTitle = await titleService.generateTitle(text);
        await historyService.updateSessionTitle(
          currentSessionId,
          generatedTitle,
        );
      } catch (e) {}
    }

    // Prepare messages for API
    List<ChatMessage> messagesForApi = [];
    final systemPrompt = settings.systemInstruction;
    if (systemPrompt.isNotEmpty) {
      messagesForApi.add(
        ChatMessage(
          sender: MessageSender.system,
          content: systemPrompt,
          contentType: ContentType.text,
          openAIRole: OpenAIRole.system,
        ),
      );
    }

    List<ChatMessage> historyMessages = currentSession!.messages;
    if (settings.historybufferlength > 0 &&
        historyMessages.length > settings.historybufferlength) {
      messagesForApi.addAll(
        historyMessages.sublist(
          historyMessages.length - settings.historybufferlength,
        ),
      );
    } else if (settings.historybufferlength == 0) {
      if (!messagesForApi.contains(userMessage)) {
        messagesForApi.add(userMessage);
      }
    } else {
      messagesForApi.addAll(historyMessages);
    }

    try {
      // Create a placeholder AI message for streaming
      final aiMessageId = const Uuid().v4();
      ref.read(streamingMessageIdProvider.notifier).state = aiMessageId;
      
      final aiMessage = ChatMessage(
        id: aiMessageId,
        sender: MessageSender.ai,
        content: "",
        timestamp: DateTime.now(),
        contentType: ContentType.text,
      );
      
      // Add placeholder message to history
      await historyService.addMessageToSession(currentSessionId, aiMessage);
      
      // Start streaming
      String accumulatedContent = "";
      final responseStream = chatService.generateChatCompletionStream(
        model: modelToUse,
        messages: messagesForApi,
        temperature: settings.temperature,
        maxTokens: settings.maxOutputTokens > 0 ? settings.maxOutputTokens : null,
        topP: settings.topP,
      );

      await for (final streamChunk in responseStream) {
        if (streamChunk.choices.isNotEmpty) {
          final delta = streamChunk.choices.first.delta;
          if (delta.content != null && delta.content!.isNotEmpty) {
            for (final contentItem in delta.content!) {
              if (contentItem.text != null) {
                accumulatedContent += contentItem.text!;
                ref.read(streamingMessageProvider.notifier).state = accumulatedContent;
              }
            }
          }
        }
      }

      // Update the final message in history
      final finalAiMessage = aiMessage.copyWith(content: accumulatedContent);
      await historyService.updateMessageInSession(currentSessionId, aiMessageId, finalAiMessage);

      // Handle TTS if enabled
      if (voiceOutputEnabled && accumulatedContent.isNotEmpty) {
        try {
          final ttsFileName = "ai_response_${DateTime.now().millisecondsSinceEpoch}";
          final ttsAudioFile = await chatService.createAudioSpeech(
            textContent: accumulatedContent,
            filename: ttsFileName,
          );
          if (ttsAudioFile != null) {
            ref.read(newTtsFileProvider.notifier).state = ttsAudioFile;
          }
        } catch (e) {
          debugPrint('TTS Error: $e');
        }
      }

      state = const AsyncData(null);
    } catch (e, s) {
      String errorMsg = e.toString().replaceFirst("Exception: ", "");
      state = AsyncError("AI Error: $errorMsg", s);
      if (historyEnabled) {
        final errorMessage = ChatMessage(
          sender: MessageSender.system,
          content: "Error: Failed to get response.\n$errorMsg",
          timestamp: DateTime.now(),
          metadata: {'error': true},
        );
        try {
          await historyService.addMessageToSession(
            currentSessionId,
            errorMessage,
          );
        } catch (histErr) {}
      }
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
      ref.read(isStreamingProvider.notifier).state = false;
      ref.read(streamingMessageProvider.notifier).state = null;
      ref.read(streamingMessageIdProvider.notifier).state = null;
    }
  }

  Future<void> sendMessage(
    String text, {
    File? imageFile,
    required bool isWebSearchEnabled,
    required bool voiceOutputEnabled,
  }) async {
    state = const AsyncLoading();
    ref.read(isLoadingProvider.notifier).state = true;
    final historyService = ref.read(chatHistoryServiceProvider);
    final settings = ref.read(settingsServiceProvider);
    final chatService = ref.read(aiCompanionServiceProvider);
    final titleService = ref.read(titleGeneratorServiceProvider);

    String? currentSessionId = historyService.activeChatId;
    ChatSessionItem? currentSession;
    if (currentSessionId == null) {
      currentSession = await historyService.startNewChat();
      currentSessionId = currentSession.id;
    } else {
      currentSession = historyService.getSessionById(currentSessionId);
    }
    final historyEnabled = settings.historychatenabled;
    final String modelToUse;
    if (imageFile != null) {
      modelToUse =
          settings.visionprocessingmodel.isNotEmpty
              ? settings.visionprocessingmodel
              : "gpt-4o-mini";
    } else if (isWebSearchEnabled) {
      modelToUse = "gpt-4o-mini-search-preview";
    } else {
      modelToUse = settings.defaultchatmodel;
    }
    if (historyEnabled) {
      currentSession = historyService.getSessionById(currentSessionId);
      if (currentSession == null) {
        currentSession = await historyService.startNewChat();
        currentSessionId = currentSession.id;
      }
    } else {
      state = AsyncError("Chat history is disabled", StackTrace.current);
      ref.read(isLoadingProvider.notifier).state = false;
      return;
    }

    final userMessage = ChatMessage(
      sender: MessageSender.user,
      content: text,
      timestamp: DateTime.now(),
      filePath: imageFile?.path,
      contentType: imageFile != null ? ContentType.image : ContentType.text,
      fileName: imageFile?.path.split('/').last,
    );

    try {
      await historyService.addMessageToSession(currentSessionId, userMessage);
      currentSession = historyService.getSessionById(currentSessionId);
    } catch (e, s) {
      state = AsyncError("Failed to save user message", s);
      ref.read(isLoadingProvider.notifier).state = false;
      return;
    }

    final bool isFirstUserMessage =
        currentSession?.messages
            .where((m) => m.sender == MessageSender.user)
            .length ==
        1;
    if (settings.autotitle &&
        isFirstUserMessage &&
        historyEnabled &&
        text.isNotEmpty) {
      try {
        final generatedTitle = await titleService.generateTitle(text);
        await historyService.updateSessionTitle(
          currentSessionId,
          generatedTitle,
        );
      } catch (e) {}
    }

    List<ChatMessage> messagesForApi = [];
    final systemPrompt = settings.systemInstruction;
    if (systemPrompt.isNotEmpty) {
      messagesForApi.add(
        ChatMessage(
          sender: MessageSender.system,
          content: systemPrompt,
          contentType: ContentType.text,
          openAIRole: OpenAIRole.system,
        ),
      );
    }

    List<ChatMessage> historyMessages = currentSession!.messages;
    if (settings.historybufferlength > 0 &&
        historyMessages.length > settings.historybufferlength) {
      messagesForApi.addAll(
        historyMessages.sublist(
          historyMessages.length - settings.historybufferlength,
        ),
      );
    } else if (settings.historybufferlength == 0) {
      if (!messagesForApi.contains(userMessage)) {
        messagesForApi.add(userMessage);
      }
    } else {
      messagesForApi.addAll(historyMessages);
    }

    Map<String, dynamic>? webSearchOptions;
    if (isWebSearchEnabled) {
      webSearchOptions = {
        'web_search_options': {
          'user_location': {
            'type': 'approximate',
            'approximate': {
              'country':
                  settings.customsearchlocation.isNotEmpty
                      ? settings.customsearchlocation
                      : 'GB',
            },
          },
        },
      };
    }

    try {
      final response = await chatService.generateChatCompletion(
        model: modelToUse,
        messages: messagesForApi,
        temperature: settings.temperature,
        maxTokens:
            settings.maxOutputTokens > 0 ? settings.maxOutputTokens : null,
        topP: settings.topP,
        webSearchOptions: webSearchOptions,
        sessionId: currentSessionId,
      );

      final aiContent =
          response.choices.first.message.content?.first.text ??
          "AI Response was empty.";
      final Map<String, dynamic> aiMetadata = {
        'model_name': response.choices.first.message.toMap()['model'],
        'finish_reason': response.choices.first.finishReason,
        'usage_prompt_tokens': response.usage.promptTokens,
        'usage_completion_tokens': response.usage.completionTokens,
        'usage_total_tokens': response.usage.totalTokens,
        'response_id': response.id,
      };
      aiMetadata.removeWhere(
        (key, value) => key.startsWith('usage_') && value == null,
      );

      final aiMessage = ChatMessage.fromJson({
        'role': response.choices.first.message.role.name,
        'content': aiContent,
        'metadata': aiMetadata,
      });

      if (historyEnabled) {
        await historyService.addMessageToSession(currentSessionId, aiMessage);
      }

      if (voiceOutputEnabled) {
        try {
          final ttsFileName =
              "ai_response_${DateTime.now().millisecondsSinceEpoch}";
          final ttsAudioFile = await chatService.createAudioSpeech(
            textContent: aiContent,
            filename: ttsFileName,
          );
          if (ttsAudioFile != null) {
            ref.read(newTtsFileProvider.notifier).state = ttsAudioFile;
          }
        } catch (e) {}
      }

      if (response.choices.first.message.haveToolCalls) {
        try {
          final toolResults = await chatService.handleToolCalls(response);
          for (final toolResult in toolResults) {
            final toolMessage = ChatMessage(
              sender: MessageSender.system,
              content: toolResult,
              timestamp: DateTime.now(),
              contentType: ContentType.text,
              metadata: {'tool_result': true},
            );
            if (historyEnabled) {
              await historyService.addMessageToSession(
                currentSessionId,
                toolMessage,
              );
            }
          }

          final toolCalls =
              response.choices.first.message.toMap()['tool_calls']
                  as List<Map<String, dynamic>>;
          final toolCallMessages =
              toolCalls
                  .map(
                    (toolCall) => ChatMessage.fromOpenAIResponse(
                      id: aiContent,
                      role: OpenAIRole.tool.toString(),
                    ),
                  )
                  .toList();
          final followUpResponse = await chatService.generateChatCompletion(
            model: modelToUse,
            messages: [
              ...messagesForApi,
              ...toolCallMessages,
              ChatMessage(
                content:
                    "The requested actions have been completed. Please confirm to the user what was done.",
                sender: MessageSender.system,
              ),
            ],
            temperature: settings.temperature,
            maxTokens:
                settings.maxOutputTokens > 0 ? settings.maxOutputTokens : null,
            topP: settings.topP,
            sessionId: currentSessionId,
          );

          final followUpContent =
              followUpResponse.choices.first.message.content?.first.text ??
              "Follow-up AI Response was empty.";
          final followUpMessage = ChatMessage.fromJson({
            'role': followUpResponse.choices.first.message.role.name,
            'content': followUpContent,
            'metadata': {
              'model_name':
                  followUpResponse.choices.first.message.toMap()['model'],
              'finish_reason': followUpResponse.choices.first.finishReason,
              'response_id': followUpResponse.id,
            },
          });
          if (historyEnabled) {
            await historyService.addMessageToSession(
              currentSessionId,
              followUpMessage,
            );
          }
        } catch (e) {}
      }

      state = const AsyncData(null);
    } catch (e, s) {
      String errorMsg = e.toString().replaceFirst("Exception: ", "");
      state = AsyncError("AI Error: $errorMsg", s);
      if (historyEnabled) {
        final errorMessage = ChatMessage(
          sender: MessageSender.system,
          content: "Error: Failed to get response.\n$errorMsg",
          timestamp: DateTime.now(),
          metadata: {'error': true},
        );
        try {
          await historyService.addMessageToSession(
            currentSessionId,
            errorMessage,
          );
        } catch (histErr) {}
      }
    } finally {
      ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  Future<void> transcribeAndSendAudio(File audioFile) async {
    final isWebSearchEnabled = ref.read(isWebSearchEnabledProvider);
    final voiceOutputEnabled = ref.read(voiceOutputEnabledProvider);
    state = const AsyncLoading();
    ref.read(isLoadingProvider.notifier).state = true;
    final historyService = ref.read(chatHistoryServiceProvider);
    final settings = ref.read(settingsServiceProvider);
    final chatService = ref.read(aiCompanionServiceProvider);
    String? currentSessionId = historyService.activeChatId;

    try {
      if (currentSessionId != null && settings.historychatenabled) {
        final audioPlaceholderMsg = ChatMessage(
          sender: MessageSender.user,
          content: "[Processing audio: ${audioFile.path.split('/').last}...]",
          timestamp: DateTime.now(),
          contentType: ContentType.audio,
          filePath: audioFile.path,
        );
        await historyService.addMessageToSession(
          currentSessionId,
          audioPlaceholderMsg,
        );
      }

      final transcribedText = await chatService.transcribeAudioFile(
        filePath: audioFile.path,
      );
      if (transcribedText != null && transcribedText.isNotEmpty) {
        await sendMessage(
          transcribedText,
          imageFile: null,
          isWebSearchEnabled: isWebSearchEnabled,
          voiceOutputEnabled: voiceOutputEnabled,
        );
      } else {
        throw Exception("Transcription failed or produced empty text.");
      }
    } catch (e, s) {
      String errorMsg = e.toString().replaceFirst("Exception: ", "");
      state = AsyncError("Audio Processing Error: $errorMsg", s);
      if (currentSessionId != null && settings.historychatenabled) {
        final errorMessage = ChatMessage(
          sender: MessageSender.system,
          content: "Error processing audio file: $errorMsg",
          timestamp: DateTime.now(),
          metadata: {'error': true},
        );
        try {
          await historyService.addMessageToSession(
            currentSessionId,
            errorMessage,
          );
        } catch (histErr) {}
      }
      ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  void createNewChat() {
    final historyEnabled = ref.read(chatHistoryEnabledProvider);
    if (!historyEnabled) {
      return;
    }
    ref.read(chatHistoryServiceProvider).startNewChat();
  }

  void selectChat(String sessionId) {
    final historyEnabled = ref.read(chatHistoryEnabledProvider);
    if (!historyEnabled) {
      return;
    }
    ref.read(chatHistoryServiceProvider).setActiveChatId(sessionId);
  }

  void deleteChat(String sessionId) {
    final historyEnabled = ref.read(chatHistoryEnabledProvider);
    if (!historyEnabled) {
      return;
    }
    ref.read(chatHistoryServiceProvider).deleteChatSession(sessionId);
  }

  Future<List<OpenAIModelModel>> getModelList() async {
    final chatService = ref.read(aiCompanionServiceProvider);
    return await chatService.getModelList();
  }

  Future<OpenAIModelModel> getModelInfo(String modelId) async {
    final chatService = ref.read(aiCompanionServiceProvider);
    return await chatService.getModelInfo(modelId);
  }

  Future<String> generateImage(String prompt) async {
    final chatService = ref.read(aiCompanionServiceProvider);
    return await chatService.createImage(prompt);
  }

  Future<List<double>> createEmbeddings(String text) async {
    final chatService = ref.read(aiCompanionServiceProvider);
    return await chatService.createEmbeddings(text);
  }

  Future<dynamic> retrieveFileContent(String fileId) async {
    final chatService = ref.read(aiCompanionServiceProvider);
    return await chatService.retrieveFileContent(fileId);
  }
}

// Providers
final isLoadingProvider = StateProvider<bool>((ref) => false);
final isWebSearchEnabledProvider = StateProvider<bool>((ref) => false);
final voiceOutputEnabledProvider = StateProvider<bool>((ref) => false);
final newTtsFileProvider = StateProvider<File?>((ref) => null);
final chatControllerProvider =
    StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
      return ChatController(ref);
    });