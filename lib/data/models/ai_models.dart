import 'dart:io';
import 'package:uuid/uuid.dart';

// Chat Input Models
class ChatInput {
  final String role; // "user", "assistant"
  final List<Content> content;
  ChatInput({required this.role, required this.content});

  Map<String, dynamic> toJson() => {
        "role": role,
        "content": content.map((c) => c.toJson()).toList(),
      };
}

abstract class Content {
  Map<String, dynamic> toJson();
}

class InputTextContent extends Content {
  final String text;
  InputTextContent(this.text);
  @override
  Map<String, dynamic> toJson() => {
        "type": "input_text",
        "text": text,
      };
}

class InputImageContent extends Content {
  final String imageUrl;
  InputImageContent(this.imageUrl);
  @override
  Map<String, dynamic> toJson() => {
        "type": "input_image",
        "image_url": imageUrl,
      };
}

// Chat Message Model
class ChatMessageModel {
  final String id;
  final String role; // "user" or "assistant"
  String text;
  String? imageUrl; // optional
  final DateTime timestamp;
  String? fileType; // Added for file type indication
  bool isMocked; // Added for mock messages

  ChatMessageModel({
    String? id,
    required this.role,
    required this.text,
    this.imageUrl,
    DateTime? timestamp,
    this.fileType,
    this.isMocked = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  factory ChatMessageModel.fromJson(Map<String, dynamic> j) {
    return ChatMessageModel(
      id: j['id'] as String?,
      role: j['role'] as String,
      text: j['text'] as String,
      imageUrl: j['imageUrl'] as String?,
      timestamp: DateTime.parse(j['timestamp'] as String),
      fileType: j['fileType'] as String?,
      isMocked: j['isMocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
        'imageUrl': imageUrl,
        'timestamp': timestamp.toIso8601String(),
        'fileType': fileType,
        'isMocked': isMocked,
      };

  ChatMessageModel copyWith({
    String? id,
    String? role,
    String? text,
    String? imageUrl,
    DateTime? timestamp,
    String? fileType,
    bool? isMocked,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      fileType: fileType ?? this.fileType,
      isMocked: isMocked ?? this.isMocked,
    );
  }
}

// Chat Session Model
class ChatSessionItem {
  String id;
  String title;
  DateTime createdAt;
  DateTime lastModified;
  List<ChatMessageModel> messages;
  int contextWindowSize; // Added for context management
  int usedTokens; // Added for context management

  ChatSessionItem({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastModified,
    required this.messages,
    this.contextWindowSize = 4096,
    this.usedTokens = 0,
  });

  factory ChatSessionItem.fromJson(Map<String, dynamic> j) {
    return ChatSessionItem(
      id: j['id'] as String,
      title: j['title'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      lastModified: DateTime.parse(j['lastModified'] as String),
      messages: (j['messages'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((m) => ChatMessageModel.fromJson(m))
          .toList(),
      contextWindowSize: j['contextWindowSize'] as int? ?? 4096,
      usedTokens: j['usedTokens'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastModified': lastModified.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'contextWindowSize': contextWindowSize,
        'usedTokens': usedTokens,
      };
}

// Response Event Model
class ResponseEvent {
  final String eventName; // e.g. "response.output_text.delta"
  final Map<String, dynamic> data;

  ResponseEvent(this.eventName, this.data);

  factory ResponseEvent.fromRaw(String eventName, Map<String, dynamic> json) {
    return ResponseEvent(eventName, json);
  }
}

// Transcript Event Model
class TranscriptEvent {
  final String type; // e.g. "transcript.text.delta" or "transcript.text.done"
  final String? delta;
  final String? text;

  TranscriptEvent({required this.type, this.delta, this.text});

  factory TranscriptEvent.fromJson(Map<String, dynamic> j) {
    return TranscriptEvent(
      type: j["type"] as String,
      delta: j["delta"] as String?,
      text: j["text"] as String?,
    );
  }
}

// Tool Model
class Tool {
  final String type; // e.g. "web_search_preview"
  Tool(this.type);

  Map<String, dynamic> toJson() => {
        "type": type,
      };
}

// Memory Item Model
class MemoryItem {
  String id;
  String key;
  String content;
  DateTime timestamp;

  MemoryItem({
    required this.id,
    required this.key,
    required this.content,
    required this.timestamp,
  });

  factory MemoryItem.fromJson(Map<String, dynamic> j) {
    return MemoryItem(
      id: j['id'] as String,
      key: j['key'] as String,
      content: j['content'] as String,
      timestamp: DateTime.parse(j['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}

// File Content Model for import/export
class FileContentModel {
  final String fileName;
  final String content;
  final String extension;
  final String mimeType;
  final int size;

  FileContentModel({
    required this.fileName,
    required this.content,
    required this.extension,
    required this.mimeType,
    required this.size,
  });
}

// OCR Result Model for chat integration
class OcrResultModel {
  final String extractedText;
  final String fileName;
  final DateTime timestamp;

  OcrResultModel({
    required this.extractedText,
    required this.fileName,
    required this.timestamp,
  });
}