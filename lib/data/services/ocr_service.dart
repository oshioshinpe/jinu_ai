import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import '../models/ocr_models.dart';

class OcrService {
  final String _apiKey;
  static const String _baseUrl = 'https://api.avalai.ir/v1/ocr';

  OcrService(this._apiKey);

  Future<OcrResponse> processFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      // Build the document payload conditionally
      Map<String, String> documentPayload;

      if (mimeType.startsWith('image/')) {
        documentPayload = {
          'type': 'image_url', // Correct type
          'image_url': 'data:$mimeType;base64,$base64String' // Correct key
        };
      } else if (mimeType == 'application/pdf') {
        documentPayload = {
          'type': 'document_url', // Correct type
          'document_url': 'data:$mimeType;base64,$base64String' // Correct key
        };
      } else {
        throw Exception('Unsupported file type: $mimeType');
      }

      final requestPayload = OcrRequest(
        document: documentPayload, // Use the correctly constructed payload
      );

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestPayload.toJson()),
      );

      if (response.statusCode == 200) {
        // Use utf8.decode to prevent potential character encoding issues
        return OcrResponse.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        // Provide the full response body for better debugging
        throw Exception(
            'API Error: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      // Re-throw to be handled by the UI layer
      throw Exception('Failed to process file: $e');
    }
  }
}