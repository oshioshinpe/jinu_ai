import 'dart:convert';
import 'dart:io';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jinu/presentation/providers/settings_provider.dart';
import 'package:mime/mime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:jinu/data/models/chat_message.dart';

// Unique ID generator
const uuid = Uuid();

// AI Companion Service without Pinecone integration
class AICompanionService {
  static final String _openAIApiKey =
      settingsService.apitokenmain; // Replace with actual API key
  static final String _openAIBaseUrl = settingsService.custoombaseurl;
  static final String _responseUrl =
      'http://api.avalai.ir/user/credit'; // Replace with actual server URL
  final http.Client _httpClient = http.Client();

  AICompanionService() {
    // Initialize OpenAI SDK

    OpenAI.requestsTimeOut = const Duration(minutes: 20);
  }

  // Send GET request after AI response
  Future<Map<String, dynamic>> _sendResponseGetRequest() async {
    try {
      final response = await _httpClient.get(Uri.parse(_responseUrl));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse is Map<String, dynamic> && jsonResponse.length == 4) {
          return jsonResponse;
        } else {
          throw Exception('Invalid JSON response format');
        }
      } else {
        throw Exception(
          'GET request failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error in GET request: $e');
      return {'error': 'Failed to fetch response: $e'};
    }
  }

  // List available models
  Future<List<OpenAIModelModel>> getModelList() async {
    try {
      final models = await OpenAI.instance.model.list();
      return models;
    } catch (e) {
      debugPrint('Error listing models: $e');
      throw RequestFailedException('Failed to list models: $e', 500);
    }
  }

  // Retrieve model details
  Future<OpenAIModelModel> getModelInfo(String modelId) async {
    try {
      final model = await OpenAI.instance.model.retrieve(modelId);
      return model;
    } catch (e) {
      debugPrint('Error retrieving model $modelId: $e');
      throw RequestFailedException('Failed to retrieve model: $e', 500);
    }
  }

  // Transcribe audio file to text
  Future<String> transcribeAudio(File audioFile) async {
    try {
      final transcription = await OpenAI.instance.audio.createTranscription(
        file: audioFile,
        model: 'whisper-1',
        responseFormat: OpenAIAudioResponseFormat.text,
      );
      return transcription.text;
    } catch (e) {
      debugPrint('Error transcribing audio: $e');
      throw RequestFailedException('Failed to transcribe audio: $e', 500);
    }
  }

  // Create speech from text
  Future<File> createSpeech(String text, String outputFileName) async {
    try {
      final speechFile = await OpenAI.instance.audio.createSpeech(
        model: 'tts-1',
        input: text,
        voice: 'nova',
        responseFormat: OpenAIAudioSpeechResponseFormat.mp3,
        outputDirectory: await Directory('speechOutput').create(),
        outputFileName: outputFileName,
      );
      return speechFile;
    } catch (e) {
      debugPrint('Error creating speech: $e');
      throw RequestFailedException('Failed to create speech: $e', 500);
    }
  }

  // Generate image from prompt
  Future<String> createImage(String prompt) async {
    try {
      final image = await OpenAI.instance.image.create(
        prompt: prompt,
        n: 1,
        size: OpenAIImageSize.size1024,
        responseFormat: OpenAIImageResponseFormat.url,
      );
      final imageUrl = image.data.first.url;
      await _sendResponseGetRequest();
      return imageUrl ?? '';
    } catch (e) {
      debugPrint('Error creating image: $e');
      throw RequestFailedException('Failed to create image: $e', 500);
    }
  }

  // Create embeddings for text
  Future<List<double>> createEmbeddings(String text) async {
    try {
      final embedding = await OpenAI.instance.embedding.create(
        model: 'text-embedding-ada-002',
        input: text,
      );
      final embeddingVector = embedding.data.first.embeddings;
      await _sendResponseGetRequest();
      return embeddingVector;
    } catch (e) {
      debugPrint('Error creating embeddings: $e');
      throw RequestFailedException('Failed to create embeddings: $e', 500);
    }
  }

  // Retrieve file content
  Future<dynamic> retrieveFileContent(String fileId) async {
    try {
      final fileContent = await OpenAI.instance.file.retrieveContent(fileId);
      await _sendResponseGetRequest();
      return fileContent;
    } catch (e) {
      debugPrint('Error retrieving file content: $e');
      throw RequestFailedException('Failed to retrieve file content: $e', 500);
    }
  }

  // Memory tools for function calling
  final List<OpenAIToolModel> _memoryTools = [
    OpenAIToolModel(
      type: 'function',
      function: OpenAIFunctionModel(
        name: 'save_to_memory',
        description:
            'Save important information to long-term memory for future reference',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description':
                  'A short, descriptive title or topic for this memory (3-5 words)',
            },
            'content': {
              'type': 'string',
              'description': 'The detailed information to remember',
            },
          },
          'required': ['key', 'content'],
        },
      ),
    ),
    OpenAIToolModel(
      type: 'function',
      function: OpenAIFunctionModel(
        name: 'search_memory',
        description: 'Search long-term memory for relevant information',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'The search term or topic to look up in memory',
            },
          },
          'required': ['query'],
        },
      ),
    ),
  ];

  // Mock memory storage (for local fallback)
  final Map<String, String> _memoryStore = {};

  Future<String> _handleSaveMemory(OpenAIResponseToolCall toolCall) async {
    try {
      final decodedArgs = jsonDecode(toolCall.function.arguments);
      final key = decodedArgs['key'] as String;
      final content = decodedArgs['content'] as String;

      debugPrint('Saving to memory - Key: $key, Content: $content');
      _memoryStore[key] = content;
      return "Successfully saved memory with key '$key'";
    } catch (e) {
      debugPrint('Error saving memory: $e');
      return 'Failed to save memory: $e';
    }
  }

  Future<String> _handleSearchMemory(OpenAIResponseToolCall toolCall) async {
    try {
      final decodedArgs = jsonDecode(toolCall.function.arguments);
      final query = decodedArgs['query'] as String;

      debugPrint('Searching memory for: $query');
      final memories =
          _memoryStore.entries
              .where(
                (entry) =>
                    entry.key.contains(query) || entry.value.contains(query),
              )
              .map((entry) => 'Key: ${entry.key}, Content: ${entry.value}')
              .toList();

      if (memories.isEmpty) {
        return "No memories found matching '$query'";
      } else {
        return "Found ${memories.length} memories matching '$query': ${memories.join('; ')}";
      }
    } catch (e) {
      debugPrint('Error searching memory: $e');
      return 'Error searching memory: $e';
    }
  }

  Future<List<String>> handleToolCalls(
    OpenAIChatCompletionModel chatCompletion,
  ) async {
    final message = chatCompletion.choices.first.message;
    final List<String> toolResults = [];

    if (message.haveToolCalls) {
      for (var toolCall in message.toolCalls!) {
        try {
          switch (toolCall.function.name) {
            case 'save_to_memory':
              final result = await _handleSaveMemory(toolCall);
              toolResults.add(result);
              break;
            case 'search_memory':
              final result = await _handleSearchMemory(toolCall);
              toolResults.add(result);
              break;
            default:
              toolResults.add('Unknown function: ${toolCall.function.name}');
          }
        } catch (e) {
          debugPrint('Error handling tool call: $e');
          toolResults.add('Error handling ${toolCall.function.name}: $e');
        }
      }
    }
    return toolResults;
  }

  // Generate chat completion
  Future<OpenAIChatCompletionModel> generateChatCompletion({
    required String model,
    required List<ChatMessage> messages,
    required double temperature,
    int? maxTokens,
    double? topP,
    Map<String, dynamic>? webSearchOptions,
    String? sessionId,
  }) async {
    try {
      List<OpenAIChatCompletionChoiceMessageModel> openAIMessages = [];

      for (var message in messages) {
        List<OpenAIChatCompletionChoiceMessageContentItemModel> contentParts =
            [];
        String finalText = message.content;

        if (message.contentType == ContentType.audio &&
            message.filePath != null) {
          final transcribedText = await transcribeAudio(
            File(message.filePath!),
          );
          finalText =
              message.content.isNotEmpty
                  ? '$finalText\n[Audio Transcription]: $transcribedText'
                  : transcribedText;
        }

        if (finalText.isNotEmpty) {
          contentParts.add(
            OpenAIChatCompletionChoiceMessageContentItemModel.text(finalText),
          );
        }

        if (message.contentType == ContentType.image &&
            message.filePath != null) {
          final imageFile = File(message.filePath!);
          final bytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(bytes);
          String? mimeType = lookupMimeType(message.filePath!);
          mimeType ??= 'image/jpeg';

          contentParts.add(
            OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(
              'data:$mimeType;base64,$base64Image',
            ),
          );
        }

        if (contentParts.isNotEmpty) {
          openAIMessages.add(
            OpenAIChatCompletionChoiceMessageModel(
              content: contentParts,
              role: OpenAIChatMessageRole.user,
            ),
          );
        }
      }

      final chatCompletion = await OpenAI.instance.chat.create(
        model: model,
        messages: openAIMessages,
        tools: _memoryTools,
        temperature: temperature,
        maxTokens: maxTokens,
        topP: topP,
      );

      await _sendResponseGetRequest();
      return chatCompletion;
    } catch (e) {
      debugPrint('Error generating chat completion: $e');
      throw RequestFailedException(
        'Failed to generate chat completion: $e',
        500,
      );
    }
  }

  // Stream chat completion
  Stream<OpenAIStreamChatCompletionModel> generateChatCompletionStream({
    required String model,
    required List<ChatMessage> messages,
    required double temperature,
    int? maxTokens,
    double? topP,
    String? sessionId,
  }) async* {
    try {
      List<OpenAIChatCompletionChoiceMessageModel> openAIMessages = [];

      // Process messages (same as in the original code)
      for (var message in messages) {
        List<OpenAIChatCompletionChoiceMessageContentItemModel> contentParts =
            [];
        String finalText = message.content;

        if (message.contentType == ContentType.audio &&
            message.filePath != null) {
          final transcribedText = await transcribeAudio(
            File(message.filePath!),
          );
          finalText =
              message.content.isNotEmpty
                  ? '$finalText\n[Audio Transcription]: $transcribedText'
                  : transcribedText;
        }

        if (finalText.isNotEmpty) {
          contentParts.add(
            OpenAIChatCompletionChoiceMessageContentItemModel.text(finalText),
          );
        }

        if (message.contentType == ContentType.image &&
            message.filePath != null) {
          final imageFile = File(message.filePath!);
          final bytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(bytes);
          String? mimeType = lookupMimeType(message.filePath!);
          mimeType ??= 'image/jpeg';

          contentParts.add(
            OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(
              'data:$mimeType;base64,$base64Image',
            ),
          );
        }

        if (contentParts.isNotEmpty) {
          openAIMessages.add(
            OpenAIChatCompletionChoiceMessageModel(
              content: contentParts,
              role: OpenAIChatMessageRole.user,
            ),
          );
        }
      }

      // Create stream with the correct parameters
      final chatStream = OpenAI.instance.chat.createStream(
        model: model,
        messages: openAIMessages,
        tools: _memoryTools,
        temperature: temperature,
        maxTokens: maxTokens,
        topP: topP,
      );

      // Yield each stream chunk as it arrives
      await for (final streamChunk in chatStream) {
        yield streamChunk;
      }

      // Send GET request after stream completes
      await _sendResponseGetRequest();
    } catch (e) {
      debugPrint('Error in stream chat completion: $e');
      throw RequestFailedException('Failed to stream chat completion: $e', 500);
    }
  }

  // Transcribe audio file
  Future<String?> transcribeAudioFile({required String filePath}) async {
    try {
      return await transcribeAudio(File(filePath));
    } catch (e) {
      debugPrint('Error transcribing audio file: $e');
      return null;
    }
  }

  // Create audio speech
  Future<File?> createAudioSpeech({
    required String textContent,
    required String filename,
  }) async {
    try {
      return await createSpeech(textContent, filename);
    } catch (e) {
      debugPrint('Error creating audio speech: $e');
      return null;
    }
  }
}

// Custom exception for request failures
class RequestFailedException implements Exception {
  final String message;
  final int statusCode;

  RequestFailedException(this.message, this.statusCode);

  @override
  String toString() => 'RequestFailedException: $message (Status: $statusCode)';
}