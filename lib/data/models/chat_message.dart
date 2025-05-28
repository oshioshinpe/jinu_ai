// lib/data/models/chat_message.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:uuid/uuid.dart';
// Keep for potential future color use

const _uuid = Uuid();

enum MessageSender { user, ai, system }
enum ContentType { text, image, audio, file /* Generic file type */ }
enum OpenAIRole { system, user, assistant }

class ChatMessage {
  final String id;
  // Removed chatId as it's implicit within ChatSessionItem.messages
  final MessageSender sender;
  final String content; // Text, URL, or path
  final ContentType contentType;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // For errors, API details, etc.
  final bool isUserMessage; // Helper
  final OpenAIRole? openAIRole;
  final String? filePath; // NEW: Local path for image/audio/file (if applicable)
  final String? fileUrl;  // NEW: Remote URL for image/audio/file (if uploaded)
  final String? fileName; // NEW: Original name of the uploaded file
  final int? fileSize;   // NEW: Size in bytes
  final String? mimeType; // NEW: MIME type of the file
  ChatMessage({
    String? id,
    required this.sender,
    required this.content,
    this.contentType = ContentType.text,
    DateTime? timestamp,
    this.metadata,
    this.openAIRole,
    this.filePath,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,    
  }) : id = id ?? _uuid.v4(),
       timestamp = timestamp ?? DateTime.now(),
       isUserMessage = sender == MessageSender.user;

       ChatMessage copyWith({
    String? id,
    MessageSender? sender,
    String? content,
    DateTime? timestamp,
    ContentType? contentType,
    String? filePath, // Allow clearing by passing null explicitly? Consider Optional<T>
    ValueGetter<String?>? fileUrl, // Use ValueGetter for nullable fields
    ValueGetter<String?>? fileName,
    ValueGetter<int?>? fileSize,
    ValueGetter<String?>? mimeType,
    ValueGetter<Map<String, dynamic>?>? metadata,
  }) {
    // Handle explicit nulls for nullable fields if needed, otherwise use ??
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      contentType: contentType ?? this.contentType,
      filePath: filePath ?? this.filePath, // Careful: Overwrites with null if filePath is null
      fileUrl: fileUrl != null ? fileUrl() : this.fileUrl,
      fileName: fileName != null ? fileName() : this.fileName,
      fileSize: fileSize != null ? fileSize() : this.fileSize,
      mimeType: mimeType != null ? mimeType() : this.mimeType,
      metadata: metadata != null ? metadata() : this.metadata,
    );
  }
   bool get isFileBased =>
      contentType == ContentType.image ||
      contentType == ContentType.audio ||
      contentType == ContentType.file;


// Helper typedef for cleaner nullable field updates in copyWith

  // --- Serialization ---
  Map<String, dynamic> toJson() => 
     {
    'id': id,
    'sender': sender.name.toString(), // Store enum name as string
    'content': content,
    'contentType': contentType.name, // Store enum name as string
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
    'openAIRole': openAIRole?.name,
    'filePath': filePath,
    'fileUrl': fileUrl,
    'fileName': fileName,
    'fileSize': fileSize,
    'mimeType': mimeType,
    };
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    try {
      return ChatMessage(
        id: json['id'] ?? _uuid.v4(),
        sender: MessageSender.values.firstWhere(
              (e) => e.name == json['sender'],
          orElse: () => MessageSender.system, // Default on error
        ),
        content: json['content']?.toString() ?? '', // Ensure content is string
        contentType: ContentType.values.firstWhere(
              (e) => e.name == json['contentType'],
          orElse: () => ContentType.text, // Default on error
        ),
        timestamp: json['timestamp'] != null 
            ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
            : DateTime.now(),
        metadata: json['metadata'] != null
            ? Map<String, dynamic>.from(json['metadata'])
            : null,
        openAIRole: json['openAIRole'] != null
            ? OpenAIRole.values.firstWhere(
                (e) => e.name == json['openAIRole'],
                orElse: () => OpenAIRole.user,
              )
            : null,
        filePath: json['filePath'],
        fileUrl: json['fileUrl'],
        fileName: json['fileName'],
        fileSize: json['fileSize'],
        mimeType: json['mimeType'],
      );
    } catch (e, s) {
      debugPrint("Error deserializing ChatMessage: $e\nStack: $s");
      debugPrint("Problematic JSON: $json");
      // Return a default/error message on failure
      return ChatMessage(
        id: _uuid.v4(),
        sender: MessageSender.system,
        content: "[Error loading message: Invalid format]",
        timestamp: DateTime.now(),
        metadata: {'error': true, 'details': e.toString()},
       filePath: null, // Careful: Overwrites with null if filePath is null
      fileUrl: null,
      fileName: null,
      fileSize: null,
      mimeType: null,
      );
    }
  }

  // Helper getter for display
  String get text => content;

  // Add helper method to convert from OpenAI message format
  factory ChatMessage.fromOpenAI(Map<String, dynamic> openAIMessage) {
    try {
      final role = OpenAIRole.values.firstWhere(
        (e) => e.name == openAIMessage['role'],
        orElse: () => OpenAIRole.user,
      );

      return ChatMessage(
        sender: role == OpenAIRole.assistant
            ? MessageSender.ai
            : role == OpenAIRole.user
                ? MessageSender.user
                : MessageSender.system,
        content: openAIMessage['content']?.toString() ?? '',
        openAIRole: role,
        metadata: {
          'openai': true,
          ...?openAIMessage['metadata'],
        },
      filePath: null, // Careful: Overwrites with null if filePath is null
      fileUrl: null,
      fileName: null,
      fileSize: null,
      mimeType: null,
      );
    } catch (e, s) {
      debugPrint("Error converting OpenAI message: $e\nStack: $s");
      return ChatMessage(
        sender: MessageSender.system,
        content: "[Error converting OpenAI message]",
        metadata: {'error': true, 'details': e.toString()},
        filePath: null, // Careful: Overwrites with null if filePath is null
      fileUrl: null,
      fileName: null,
      fileSize: null,
      mimeType: null,
      );
    }
  }
}