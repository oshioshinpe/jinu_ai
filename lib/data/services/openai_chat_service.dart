import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jinu/presentation/providers/settings_provider.dart';
import 'package:mime/mime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:jinu/data/models/chat_message.dart';
import 'package:jinu/data/services/http_api_client_service.dart';
import 'package:jinu/data/services/long_term_memory_service.dart';
import 'package:jinu/presentation/providers/canvas_mode_providers.dart';

// Unique ID generator
const uuid = Uuid();

// AI Companion Service with HTTP API and Memory integration
class AICompanionService {
  final http.Client _httpClient = http.Client();
  final HttpApiClientService? _httpApiClient;
  final LongTermMemoryService? _memoryService;
  final CanvasModeNotifier? _canvasModeNotifier;

  AICompanionService({
    HttpApiClientService? httpApiClient,
    LongTermMemoryService? memoryService,
    CanvasModeNotifier? canvasModeNotifier,
  }) : _httpApiClient = httpApiClient,
       _memoryService = memoryService,
       _canvasModeNotifier = canvasModeNotifier {
    // Initialize OpenAI SDK
    OpenAI.requestsTimeOut = const Duration(minutes: 20);
  }

  // Send GET request after AI response
  Future<Map<String, dynamic>> _sendResponseGetRequest() async {
    try {
      // Get settings dynamically instead of static access
      final responseUrl = 'http://api.avalai.ir/user/credit';
      final response = await _httpClient.get(Uri.parse(responseUrl));
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

  // Safe image processing with memory management
  Future<String> _processImageSafely(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      
      // Reduce size limit for better memory management
      if (fileSize > 10 * 1024 * 1024) { // 10MB limit
        throw Exception('Image file too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). Maximum size is 10MB.');
      }
      
      // Process in chunks to avoid memory issues
      final bytes = await _readFileInChunks(imageFile);
      final base64Image = await _encodeBase64Async(bytes);
      
      String? mimeType = lookupMimeType(imageFile.path);
      mimeType ??= 'image/jpeg';
      
      return 'data:$mimeType;base64,$base64Image';
    } catch (e) {
      debugPrint('Error processing image: $e');
      rethrow;
    }
  }

  Future<Uint8List> _readFileInChunks(File file) async {
    const chunkSize = 1024 * 1024; // 1MB chunks
    final bytes = <int>[];
    final stream = file.openRead();
    
    try {
      await for (final chunk in stream) {
        bytes.addAll(chunk);
        // Add memory pressure check
        if (bytes.length > 12 * 1024 * 1024) { // 12MB total limit
          throw Exception('File too large for processing');
        }
      }
      
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('Error reading file in chunks: $e');
      rethrow;
    }
  }

  Future<String> _encodeBase64Async(Uint8List bytes) async {
    try {
      // Use compute to run base64 encoding in isolate to avoid blocking UI
      return await compute(_base64EncodeIsolate, bytes);
    } catch (e) {
      debugPrint('Error encoding base64: $e');
      rethrow;
    }
  }

  // Static function for isolate
  static String _base64EncodeIsolate(Uint8List bytes) {
    return base64Encode(bytes);
  }

  // Improved image message handling
  Future<void> _handleImageMessage(
    ChatMessage message, 
    List<OpenAIChatCompletionChoiceMessageContentItemModel> contentParts
  ) async {
    if (message.contentType != ContentType.image || message.filePath == null) {
      return;
    }
    
    try {
      final imageFile = File(message.filePath!);
      
      // Validate file path
      if (!_isValidFilePath(message.filePath!)) {
        throw FileSystemException('Invalid file path', message.filePath);
      }
      
      // Check file exists with timeout
      final exists = await _checkFileExistsWithTimeout(imageFile);
      if (!exists) {
        throw FileSystemException('Image file not found', message.filePath);
      }
      
      final base64Image = await _processImageSafely(imageFile);
      contentParts.add(
        OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(base64Image),
      );
      
    } on FileSystemException catch (e) {
      debugPrint('File system error: $e');
      contentParts.add(
        OpenAIChatCompletionChoiceMessageContentItemModel.text(
          '[Error: File access issue - ${e.message}]',
        ),
      );
    } on OutOfMemoryError catch (e) {
      debugPrint('Memory error processing image: $e');
      contentParts.add(
        OpenAIChatCompletionChoiceMessageContentItemModel.text(
          '[Error: Image too large for device memory]',
        ),
      );
    } catch (e) {
      debugPrint('Unexpected error processing image: $e');
      contentParts.add(
        OpenAIChatCompletionChoiceMessageContentItemModel.text(
          '[Error: Failed to process image - $e]',
        ),
      );
    }
  }

  bool _isValidFilePath(String path) {
    try {
      if (path.isEmpty) return false;
      final file = File(path);
      // Basic validation - check if path can be parsed
      return file.path.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkFileExistsWithTimeout(File file) async {
    try {
      return await file.exists().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
    } catch (e) {
      debugPrint('Error checking file existence: $e');
      return false;
    }
  }

  // Transcribe audio file to text
  Future<String> transcribeAudio(File audioFile) async {
    try {
      // Validate file exists and has content
      if (!await audioFile.exists()) {
        throw Exception('Audio file does not exist: ${audioFile.path}');
      }
      
      final fileSize = await audioFile.length();
      if (fileSize == 0) {
        throw Exception('Audio file is empty: ${audioFile.path}');
      }
      
      // Check file size limit (25MB for Whisper)
      if (fileSize > 25 * 1024 * 1024) {
        throw Exception('Audio file too large: ${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB. Maximum size is 25MB.');
      }
      
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

  // AI Tools for function calling (Memory + HTTP API)
  List<OpenAIToolModel> get _aiTools => [
    // Memory Tools
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
    
    // HTTP API Tools
    OpenAIToolModel(
      type: 'function',
      function: OpenAIFunctionModel(
        name: 'http_get_request',
        description: 'Make an HTTP GET request to retrieve data from an API endpoint',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description': 'The complete URL to make the GET request to (must include http:// or https://)',
            },
            'headers': {
              'type': 'string',
              'description': 'Optional headers in format "key1:value1,key2:value2" (e.g., "Authorization:Bearer token,Content-Type:application/json")',
            },
            'query_params': {
              'type': 'string',
              'description': 'Optional query parameters in format "key1=value1&key2=value2" (e.g., "page=1&limit=10")',
            },
          },
          'required': ['url'],
        },
      ),
    ),
    OpenAIToolModel(
      type: 'function',
      function: OpenAIFunctionModel(
        name: 'http_post_request',
        description: 'Make an HTTP POST request to send data to an API endpoint',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description': 'The complete URL to make the POST request to (must include http:// or https://)',
            },
            'headers': {
              'type': 'string',
              'description': 'Optional headers in format "key1:value1,key2:value2" (e.g., "Authorization:Bearer token,Content-Type:application/json")',
            },
            'query_params': {
              'type': 'string',
              'description': 'Optional query parameters in format "key1=value1&key2=value2"',
            },
            'body': {
              'type': 'string',
              'description': 'Request body as JSON string or plain text',
            },
          },
          'required': ['url'],
        },
      ),
    ),
    OpenAIToolModel(
      type: 'function',
      function: OpenAIFunctionModel(
        name: 'http_patch_request',
        description: 'Make an HTTP PATCH request to partially update data at an API endpoint',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description': 'The complete URL to make the PATCH request to (must include http:// or https://)',
            },
            'headers': {
              'type': 'string',
              'description': 'Optional headers in format "key1:value1,key2:value2" (e.g., "Authorization:Bearer token,Content-Type:application/json")',
            },
            'query_params': {
              'type': 'string',
              'description': 'Optional query parameters in format "key1=value1&key2=value2"',
            },
            'body': {
              'type': 'string',
              'description': 'Request body as JSON string or plain text',
            },
          },
          'required': ['url'],
        },
      ),
    ),
    OpenAIToolModel(
      type: 'function',
      function: OpenAIFunctionModel(
        name: 'http_put_request',
        description: 'Make an HTTP PUT request to completely update/replace data at an API endpoint',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description': 'The complete URL to make the PUT request to (must include http:// or https://)',
            },
            'headers': {
              'type': 'string',
              'description': 'Optional headers in format "key1:value1,key2:value2" (e.g., "Authorization:Bearer token,Content-Type:application/json")',
            },
            'query_params': {
              'type': 'string',
              'description': 'Optional query parameters in format "key1=value1&key2=value2"',
            },
            'body': {
              'type': 'string',
              'description': 'Request body as JSON string or plain text',
            },
          },
          'required': ['url'],
        },
      ),
    ),
    OpenAIToolModel(
      type: 'function',
      function: OpenAIFunctionModel(
        name: 'http_delete_request',
        description: 'Make an HTTP DELETE request to remove data from an API endpoint',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description': 'The complete URL to make the DELETE request to (must include http:// or https://)',
            },
            'headers': {
              'type': 'string',
              'description': 'Optional headers in format "key1:value1,key2:value2" (e.g., "Authorization:Bearer token,Content-Type:application/json")',
            },
            'query_params': {
              'type': 'string',
              'description': 'Optional query parameters in format "key1=value1&key2=value2"',
            },
          },
          'required': ['url'],
        },
      ),
    ),
    // Canvas Mode Tool
    OpenAIToolModel(
      type: 'function',
      function: OpenAIFunctionModel(
        name: 'open_canvas_mode',
        description:
            'Open a full-screen code editor (canvas mode) for writing, editing, and running code. Use this when the user wants to write substantial code, create a program, or work on coding projects.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'language': {
              'type': 'string',
              'description': 'Programming language for the code editor',
              'enum': ['dart', 'javascript', 'python', 'java', 'cpp'],
            },
            'code': {
              'type': 'string',
              'description': 'Initial code content to display in the editor (optional)',
            },
            'fileName': {
              'type': 'string',
              'description': 'Suggested file name for the code (optional)',
            },
          },
          'required': ['language'],
        },
      ),
    ),
  ];

  // Mock memory storage (for local fallback when memory service is not available)
  final Map<String, String> _memoryStore = {};

  Future<String> _handleSaveMemory(OpenAIResponseToolCall toolCall) async {
    try {
      final decodedArgs = jsonDecode(toolCall.function.arguments);
      final key = decodedArgs['key'] as String;
      final content = decodedArgs['content'] as String;

      debugPrint('Saving to memory - Key: $key, Content: $content');
      
      // Use actual memory service if available, otherwise use local storage
      if (_memoryService != null) {
        final result = await _memoryService!.saveMemoryItem(key, content);
        if (result['status'] == 'Success') {
          return result['message'] as String;
        } else {
          return 'Failed to save memory: ${result['message']}';
        }
      } else {
        // Fallback to local storage
        _memoryStore[key] = content;
        return "Successfully saved memory with key '$key' (local storage)";
      }
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
      
      // Use actual memory service if available, otherwise use local storage
      if (_memoryService != null) {
        final result = _memoryService!.retrieveMemoryItems(query);
        if (result['status'] == 'Success') {
          return result['data'] as String? ?? result['message'] as String;
        } else {
          return 'Memory search failed: ${result['message']}';
        }
      } else {
        // Fallback to local storage
        final memories =
            _memoryStore.entries
                .where(
                  (entry) =>
                      entry.key.contains(query) || entry.value.contains(query),
                )
                .map((entry) => 'Key: ${entry.key}, Content: ${entry.value}')
                .toList();

        if (memories.isEmpty) {
          return "No memories found matching '$query' (local storage)";
        } else {
          return "Found ${memories.length} memories matching '$query' (local storage): ${memories.join('; ')}";
        }
      }
    } catch (e) {
      debugPrint('Error searching memory: $e');
      return 'Error searching memory: $e';
    }
  }

  // HTTP API Tool Handlers
  Future<String> _handleHttpGetRequest(OpenAIResponseToolCall toolCall) async {
    if (_httpApiClient == null) {
      return 'HTTP API client not available';
    }

    try {
      final decodedArgs = jsonDecode(toolCall.function.arguments);
      final url = decodedArgs['url'] as String;
      final headersString = decodedArgs['headers'] as String?;
      final queryParamsString = decodedArgs['query_params'] as String?;

      // Validate URL
      if (!HttpApiClientService.isValidUrl(url)) {
        return 'Invalid URL format: $url';
      }

      // Parse headers and query parameters
      final headers = HttpApiClientService.parseHeadersString(headersString);
      final queryParams = HttpApiClientService.parseQueryParamsString(queryParamsString);

      debugPrint('Making HTTP GET request to: $url');
      
      final response = await _httpApiClient!.makeGetRequest(
        url: url,
        headers: headers,
        queryParameters: queryParams,
      );

      return _formatHttpResponse(response);
    } catch (e) {
      debugPrint('Error in HTTP GET request: $e');
      return 'HTTP GET request failed: $e';
    }
  }

  Future<String> _handleHttpPostRequest(OpenAIResponseToolCall toolCall) async {
    if (_httpApiClient == null) {
      return 'HTTP API client not available';
    }

    try {
      final decodedArgs = jsonDecode(toolCall.function.arguments);
      final url = decodedArgs['url'] as String;
      final headersString = decodedArgs['headers'] as String?;
      final queryParamsString = decodedArgs['query_params'] as String?;
      final body = decodedArgs['body'] as String?;

      // Validate URL
      if (!HttpApiClientService.isValidUrl(url)) {
        return 'Invalid URL format: $url';
      }

      // Parse headers and query parameters
      final headers = HttpApiClientService.parseHeadersString(headersString);
      final queryParams = HttpApiClientService.parseQueryParamsString(queryParamsString);

      debugPrint('Making HTTP POST request to: $url');
      
      final response = await _httpApiClient!.makePostRequest(
        url: url,
        headers: headers,
        queryParameters: queryParams,
        body: body,
      );

      return _formatHttpResponse(response);
    } catch (e) {
      debugPrint('Error in HTTP POST request: $e');
      return 'HTTP POST request failed: $e';
    }
  }

  Future<String> _handleHttpPatchRequest(OpenAIResponseToolCall toolCall) async {
    if (_httpApiClient == null) {
      return 'HTTP API client not available';
    }

    try {
      final decodedArgs = jsonDecode(toolCall.function.arguments);
      final url = decodedArgs['url'] as String;
      final headersString = decodedArgs['headers'] as String?;
      final queryParamsString = decodedArgs['query_params'] as String?;
      final body = decodedArgs['body'] as String?;

      // Validate URL
      if (!HttpApiClientService.isValidUrl(url)) {
        return 'Invalid URL format: $url';
      }

      // Parse headers and query parameters
      final headers = HttpApiClientService.parseHeadersString(headersString);
      final queryParams = HttpApiClientService.parseQueryParamsString(queryParamsString);

      debugPrint('Making HTTP PATCH request to: $url');
      
      final response = await _httpApiClient!.makePatchRequest(
        url: url,
        headers: headers,
        queryParameters: queryParams,
        body: body,
      );

      return _formatHttpResponse(response);
    } catch (e) {
      debugPrint('Error in HTTP PATCH request: $e');
      return 'HTTP PATCH request failed: $e';
    }
  }

  Future<String> _handleHttpPutRequest(OpenAIResponseToolCall toolCall) async {
    if (_httpApiClient == null) {
      return 'HTTP API client not available';
    }

    try {
      final decodedArgs = jsonDecode(toolCall.function.arguments);
      final url = decodedArgs['url'] as String;
      final headersString = decodedArgs['headers'] as String?;
      final queryParamsString = decodedArgs['query_params'] as String?;
      final body = decodedArgs['body'] as String?;

      // Validate URL
      if (!HttpApiClientService.isValidUrl(url)) {
        return 'Invalid URL format: $url';
      }

      // Parse headers and query parameters
      final headers = HttpApiClientService.parseHeadersString(headersString);
      final queryParams = HttpApiClientService.parseQueryParamsString(queryParamsString);

      debugPrint('Making HTTP PUT request to: $url');
      
      final response = await _httpApiClient!.makePutRequest(
        url: url,
        headers: headers,
        queryParameters: queryParams,
        body: body,
      );

      return _formatHttpResponse(response);
    } catch (e) {
      debugPrint('Error in HTTP PUT request: $e');
      return 'HTTP PUT request failed: $e';
    }
  }

  Future<String> _handleHttpDeleteRequest(OpenAIResponseToolCall toolCall) async {
    if (_httpApiClient == null) {
      return 'HTTP API client not available';
    }

    try {
      final decodedArgs = jsonDecode(toolCall.function.arguments);
      final url = decodedArgs['url'] as String;
      final headersString = decodedArgs['headers'] as String?;
      final queryParamsString = decodedArgs['query_params'] as String?;

      // Validate URL
      if (!HttpApiClientService.isValidUrl(url)) {
        return 'Invalid URL format: $url';
      }

      // Parse headers and query parameters
      final headers = HttpApiClientService.parseHeadersString(headersString);
      final queryParams = HttpApiClientService.parseQueryParamsString(queryParamsString);

      debugPrint('Making HTTP DELETE request to: $url');
      
      final response = await _httpApiClient!.makeDeleteRequest(
        url: url,
        headers: headers,
        queryParameters: queryParams,
      );

      return _formatHttpResponse(response);
    } catch (e) {
      debugPrint('Error in HTTP DELETE request: $e');
      return 'HTTP DELETE request failed: $e';
    }
  }

  // Handle canvas mode tool call
  Future<String> _handleCanvasMode(OpenAIResponseToolCall toolCall) async {
    try {
      final decodedArgs = jsonDecode(toolCall.function.arguments);
      final language = decodedArgs['language'] as String;
      final code = decodedArgs['code'] as String?;
      final fileName = decodedArgs['fileName'] as String?;

      debugPrint('Opening canvas mode - Language: $language, Code: ${code?.substring(0, 50) ?? 'None'}...');
      
      // Trigger canvas mode through the provider
      if (_canvasModeNotifier != null) {
        _canvasModeNotifier!.enableCanvasMode(
          code: code,
          language: language,
          fileName: fileName,
        );
        return 'Canvas mode opened successfully for $language programming. The full-screen code editor is now available.';
      } else {
        return 'Canvas mode is not available at the moment.';
      }
    } catch (e) {
      debugPrint('Error opening canvas mode: $e');
      return 'Failed to open canvas mode: $e';
    }
  }

  // Format HTTP response for AI consumption
  String _formatHttpResponse(Map<String, dynamic> response) {
    final buffer = StringBuffer();
    
    if (response['success'] == true) {
      buffer.writeln('✅ HTTP ${response['method']} request successful');
      buffer.writeln('Status Code: ${response['statusCode']}');
      buffer.writeln('URL: ${response['url']}');
      
      if (response['contentType'] != null) {
        buffer.writeln('Content-Type: ${response['contentType']}');
      }
      
      if (response['responseSize'] != null) {
        final sizeKB = (response['responseSize'] as int) / 1024;
        buffer.writeln('Response Size: ${sizeKB.toStringAsFixed(1)} KB');
      }
      
      buffer.writeln('\nResponse Body:');
      final body = response['body'];
      if (body is String) {
        // Truncate very long responses
        if (body.length > 2000) {
          buffer.writeln('${body.substring(0, 2000)}...\n[Response truncated - showing first 2000 characters]');
        } else {
          buffer.writeln(body);
        }
      } else {
        // Pretty print JSON
        try {
          final prettyJson = const JsonEncoder.withIndent('  ').convert(body);
          if (prettyJson.length > 2000) {
            buffer.writeln('${prettyJson.substring(0, 2000)}...\n[Response truncated - showing first 2000 characters]');
          } else {
            buffer.writeln(prettyJson);
          }
        } catch (e) {
          buffer.writeln(body.toString());
        }
      }
    } else {
      buffer.writeln('❌ HTTP ${response['method']} request failed');
      buffer.writeln('URL: ${response['url']}');
      if (response['statusCode'] != null) {
        buffer.writeln('Status Code: ${response['statusCode']}');
      }
      buffer.writeln('Error: ${response['error']}');
    }
    
    return buffer.toString();
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
            // Memory Tools
            case 'save_to_memory':
              final result = await _handleSaveMemory(toolCall);
              toolResults.add(result);
              break;
            case 'search_memory':
              final result = await _handleSearchMemory(toolCall);
              toolResults.add(result);
              break;
            
            // HTTP API Tools
            case 'http_get_request':
              final result = await _handleHttpGetRequest(toolCall);
              toolResults.add(result);
              break;
            case 'http_post_request':
              final result = await _handleHttpPostRequest(toolCall);
              toolResults.add(result);
              break;
            case 'http_patch_request':
              final result = await _handleHttpPatchRequest(toolCall);
              toolResults.add(result);
              break;
            case 'http_put_request':
              final result = await _handleHttpPutRequest(toolCall);
              toolResults.add(result);
              break;
            case 'http_delete_request':
              final result = await _handleHttpDeleteRequest(toolCall);
              toolResults.add(result);
              break;
            
            // Canvas Mode Tool
            case 'open_canvas_mode':
              final result = await _handleCanvasMode(toolCall);
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
          try {
            final audioFile = File(message.filePath!);
            if (await audioFile.exists()) {
              final transcribedText = await transcribeAudio(audioFile);
              finalText =
                  message.content.isNotEmpty
                      ? '$finalText\n[Audio Transcription]: $transcribedText'
                      : transcribedText;
            } else {
              finalText = message.content.isNotEmpty
                  ? '$finalText\n[Error: Audio file not found]'
                  : '[Error: Audio file not found]';
            }
          } catch (e) {
            debugPrint('Error transcribing audio: $e');
            finalText = message.content.isNotEmpty
                ? '$finalText\n[Error transcribing audio: $e]'
                : '[Error transcribing audio: $e]';
          }
        }

        if (finalText.isNotEmpty) {
          contentParts.add(
            OpenAIChatCompletionChoiceMessageContentItemModel.text(finalText),
          );
        }

        // Handle image messages with improved safety
        if (message.contentType == ContentType.image &&
            message.filePath != null) {
          await _handleImageMessage(message, contentParts);
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
        tools: _aiTools,
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
          try {
            final audioFile = File(message.filePath!);
            if (await audioFile.exists()) {
              final transcribedText = await transcribeAudio(audioFile);
              finalText =
                  message.content.isNotEmpty
                      ? '$finalText\n[Audio Transcription]: $transcribedText'
                      : transcribedText;
            } else {
              finalText = message.content.isNotEmpty
                  ? '$finalText\n[Error: Audio file not found]'
                  : '[Error: Audio file not found]';
            }
          } catch (e) {
            debugPrint('Error transcribing audio: $e');
            finalText = message.content.isNotEmpty
                ? '$finalText\n[Error transcribing audio: $e]'
                : '[Error transcribing audio: $e]';
          }
        }

        if (finalText.isNotEmpty) {
          contentParts.add(
            OpenAIChatCompletionChoiceMessageContentItemModel.text(finalText),
          );
        }

        // Handle image messages with improved safety
        if (message.contentType == ContentType.image &&
            message.filePath != null) {
          await _handleImageMessage(message, contentParts);
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
        tools: _aiTools,
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