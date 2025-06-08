# Integration Guide

This guide shows how to integrate the new AI processing features with your existing Flutter chat UI.

## Quick Start

### 1. Update your main chat page to use the enhanced widgets:

```dart
// In your chat_page.dart
import '../../widgets/chat/chat_input.dart';
import '../../widgets/chat/chat_message_bubble.dart';

// Replace your existing ChatInput and ChatMessageBubble with the enhanced versions
```

### 2. Add the new BLoC events to handle advanced message operations:

```dart
// Add these events to your chat_event.dart
class DeleteChatMessage extends ChatEvent {
  final String messageId;
  const DeleteChatMessage({required this.messageId});
}

class EditChatMessage extends ChatEvent {
  final String messageId;
  final String newContent;
  const EditChatMessage({required this.messageId, required this.newContent});
}

class ResendChatMessage extends ChatEvent {
  final String messageId;
  const ResendChatMessage({required this.messageId});
}

class RegenerateResponse extends ChatEvent {
  final String messageId;
  const RegenerateResponse({required this.messageId});
}

class AddMockMessage extends ChatEvent {
  final String role;
  final String content;
  const AddMockMessage({required this.role, required this.content});
}
```

### 3. Update your Message entity to support metadata:

```dart
// In your message.dart entity
class Message extends Equatable {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? metadata; // Add this field

  const Message({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isLoading = false,
    this.error,
    this.metadata, // Add this parameter
  });

  // Update copyWith method to include metadata
  Message copyWith({
    String? id,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }
}
```

### 4. Initialize the services in your dependency injection:

```dart
// In your injection_container.dart
import '../data/services/openai_service.dart';
import '../data/services/ocr_service.dart';
import '../data/services/file_service.dart';
import '../data/services/chat_history_service.dart';
import '../data/services/long_term_memory_service.dart';

void init() {
  // Register services
  sl.registerLazySingleton(() => OpenAIService('your-api-key'));
  sl.registerLazySingleton(() => OcrService('your-ocr-api-key'));
  sl.registerLazySingleton(() => FileService());
  sl.registerLazySingleton(() => ChatHistoryService());
  sl.registerLazySingleton(() => LongTermMemoryService());
}
```

### 5. Add OCR functionality to your app:

```dart
// Add a floating action button or menu item to access OCR
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OcrScreen(
          onTextExtracted: (text) {
            // Handle extracted text
            context.read<ChatBloc>().add(
              SendChatMessage(content: text)
            );
          },
        ),
      ),
    );
  },
  child: Icon(Icons.document_scanner),
)
```

## Key Features Usage

### Voice Recording
The enhanced chat input automatically handles voice recording with proper permissions. Users can:
- Tap the microphone button to start/stop recording
- See visual feedback during recording
- Automatic transcription (when implemented)

### File Attachments
Users can attach files by:
- Clicking the attachment button
- Selecting files from storage
- Viewing file previews before sending
- Automatic content extraction for text files

### OCR Integration
- Access via the document scanner button
- Support for images and PDFs
- Batch processing capabilities
- Direct integration with chat input

### Advanced Message Controls
Each message bubble now includes action buttons for:
- Copying individual messages or code blocks
- Editing user messages
- Deleting messages
- Resending messages (with warning)
- Regenerating AI responses
- Exporting messages as files

### Markdown Rendering
All messages are automatically rendered with:
- Proper markdown formatting
- Syntax-highlighted code blocks
- Copy/export buttons for code
- Responsive text sizing

## Customization

### Theming
The widgets automatically adapt to your app's theme. You can customize colors by updating your theme:

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.light,
  ),
  // The widgets will automatically use these colors
)
```

### API Configuration
Update the API keys in the service files:

```dart
// In ocr_service.dart
final OcrService _ocrService = OcrService('your-actual-api-key');

// In openai_service.dart
OpenAIService('your-openai-api-key')
```

### Feature Toggles
You can disable specific features by modifying the widgets:

```dart
// In chat_input.dart, remove buttons you don't want:
// Comment out OCR button
// IconButton(
//   icon: const Icon(Icons.document_scanner),
//   onPressed: isLoading ? null : _openOcr,
//   tooltip: 'OCR scan',
// ),
```

## Testing

The implementation includes comprehensive error handling and user feedback. Test the following scenarios:

1. **File Operations**: Try different file types and sizes
2. **OCR Processing**: Test with various image qualities
3. **Voice Recording**: Test permission handling
4. **Message Operations**: Test edit, delete, resend functionality
5. **Export Features**: Test file exports and downloads

## Performance Considerations

- **Large Files**: The file service includes size limits and compression
- **OCR Processing**: Batch processing prevents UI blocking
- **Memory Management**: Services properly dispose of resources
- **Caching**: Chat history is efficiently cached locally

This integration provides a complete, production-ready AI chat experience with advanced features while maintaining clean architecture and good performance.