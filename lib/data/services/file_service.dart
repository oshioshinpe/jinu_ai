import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import '../models/ai_models.dart';

class FileService {
  // File type options for saving
  static const List<String> supportedExtensions = [
    'txt',
    'json',
    'csv',
    'js',
    'dart',
    'xml',
    'html',
    'md',
    'py',
    'java',
    'cpp',
    'c',
    'css',
    'yaml',
    'yml',
  ];

  // Icons based on file types
  static const Map<String, String> fileTypeIcons = {
    'text/plain': 'text_snippet_outlined',
    'text/csv': 'table_chart_outlined',
    'application/json': 'data_object',
    'text/javascript': 'code',
    'application/dart': 'developer_mode',
    'application/xml': 'code',
    'text/html': 'web',
    'text/markdown': 'article',
    'text/x-python': 'code',
    'text/x-java-source': 'code',
    'text/x-c': 'code',
    'text/css': 'palette',
    'application/x-yaml': 'settings',
  };

  // File size formatting
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Determine icon based on MIME type
  static String getFileIcon(String? mimeType) {
    if (mimeType == null) return 'insert_drive_file';

    for (var entry in fileTypeIcons.entries) {
      if (mimeType.contains(entry.key)) return entry.value;
    }

    return 'insert_drive_file';
  }

  // Pick and read file content
  static Future<FileContentModel?> pickAndReadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
        final extension = result.files.single.extension ?? '';
        
        return FileContentModel(
          fileName: result.files.single.name,
          content: content,
          extension: extension,
          mimeType: mimeType,
          size: result.files.single.size,
        );
      }
    } catch (e) {
      throw Exception('Failed to pick and read file: $e');
    }
    return null;
  }

  // Save content to file
  static Future<String> saveContentToFile({
    required String content,
    required String fileName,
    required String extension,
    String? directoryPath,
  }) async {
    try {
      // Get directory path if not provided
      String? dirPath = directoryPath;
      if (dirPath == null) {
        dirPath = await FilePicker.platform.getDirectoryPath();
        if (dirPath == null) throw Exception('No directory selected');
      }

      // Create full file path
      String fullPath = '$dirPath/$fileName.$extension';

      // Write content to file
      final file = File(fullPath);
      await file.writeAsString(content);

      return fullPath;
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  // Export code block to file
  static Future<String> exportCodeBlock({
    required String code,
    required String language,
    String? fileName,
  }) async {
    try {
      final name = fileName ?? 'code_block_${DateTime.now().millisecondsSinceEpoch}';
      final extension = _getExtensionForLanguage(language);
      
      return await saveContentToFile(
        content: code,
        fileName: name,
        extension: extension,
      );
    } catch (e) {
      throw Exception('Failed to export code block: $e');
    }
  }

  // Get file extension based on programming language
  static String _getExtensionForLanguage(String language) {
    switch (language.toLowerCase()) {
      case 'dart':
        return 'dart';
      case 'javascript':
      case 'js':
        return 'js';
      case 'python':
      case 'py':
        return 'py';
      case 'java':
        return 'java';
      case 'cpp':
      case 'c++':
        return 'cpp';
      case 'c':
        return 'c';
      case 'html':
        return 'html';
      case 'css':
        return 'css';
      case 'json':
        return 'json';
      case 'xml':
        return 'xml';
      case 'yaml':
      case 'yml':
        return 'yml';
      case 'markdown':
      case 'md':
        return 'md';
      case 'sql':
        return 'sql';
      case 'bash':
      case 'shell':
        return 'sh';
      default:
        return 'txt';
    }
  }

  // Get programming language from file extension
  static String getLanguageFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'dart':
        return 'dart';
      case 'js':
        return 'javascript';
      case 'py':
        return 'python';
      case 'java':
        return 'java';
      case 'cpp':
      case 'cc':
      case 'cxx':
        return 'cpp';
      case 'c':
        return 'c';
      case 'html':
      case 'htm':
        return 'html';
      case 'css':
        return 'css';
      case 'json':
        return 'json';
      case 'xml':
        return 'xml';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'md':
        return 'markdown';
      case 'sql':
        return 'sql';
      case 'sh':
      case 'bash':
        return 'bash';
      case 'ts':
        return 'typescript';
      case 'php':
        return 'php';
      case 'rb':
        return 'ruby';
      case 'go':
        return 'go';
      case 'rs':
        return 'rust';
      case 'swift':
        return 'swift';
      case 'kt':
        return 'kotlin';
      default:
        return 'plaintext';
    }
  }

  // Check if file is text-based
  static bool isTextFile(String mimeType) {
    return mimeType.startsWith('text/') ||
        mimeType == 'application/json' ||
        mimeType == 'application/xml' ||
        mimeType == 'application/javascript' ||
        mimeType == 'application/x-yaml';
  }

  // Get temporary directory for file operations
  static Future<Directory> getTempDirectory() async {
    return await getTemporaryDirectory();
  }

  // Get downloads directory
  static Future<Directory?> getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    }
    return null;
  }
}