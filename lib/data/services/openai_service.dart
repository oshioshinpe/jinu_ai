import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/ai_models.dart';

class OpenAIService {
  final String apiKey;
  final http.Client _client = http.Client();
  OpenAIService(this.apiKey);

  /// Generic SSE parser for the /v1/responses endpoint.
  Stream<ResponseEvent> streamChat({
    required List<ChatInput> input,
    String? instructions,
    List<Tool>? tools,
  }) async* {
    final uri = Uri.parse("https://api.avalai.ir/v1/responses");
    final payload = <String, dynamic>{
      "model": "gpt-4.1-mini",
      "input": input.map((i) => i.toJson()).toList(),
      "stream": true,
    };
    if (instructions != null) payload["instructions"] = instructions;
    if (tools != null) payload["tools"] = tools.map((t) => t.toJson()).toList();

    final request = http.Request("POST", uri)
      ..headers["Content-Type"] = "application/json"
      ..headers["Authorization"] = "Bearer $apiKey"
      ..body = json.encode(payload);

    final streamed = await _client.send(request);
    final utf8Stream = streamed.stream.transform(utf8.decoder);
    String? currentEvent;
    await for (final line in utf8Stream.transform(const LineSplitter())) {
      if (line.startsWith("event:")) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith("data:")) {
        final raw = line.substring(5).trim();
        if (raw == "[DONE]") break;
        final jsonData = json.decode(raw) as Map<String, dynamic>;
        yield ResponseEvent.fromRaw(currentEvent ?? jsonData["type"], jsonData);
      }
    }
  }

  /// TTS
  Future<File> generateSpeech(
    String text, {
    String voice = "alloy",
    double speed = 1.0,
    String format = "mp3",
  }) async {
    final uri = Uri.parse("https://api.avalai.ir/v1/audio/speech");
    final body = {
      "model": "gpt-4o-mini-tts",
      "input": text,
      "voice": voice,
      "speed": speed,
      "response_format": format,
    };
    final res = await _client.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey",
      },
      body: json.encode(body),
    );
    final bytes = res.bodyBytes;
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/tts_output.$format");
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Streaming transcription
  Stream<TranscriptEvent> transcribeAudio(File audioFile) async* {
    final uri = Uri.parse("https://api.avalai.ir/v1/audio/transcriptions");
    final req = http.MultipartRequest("POST", uri)
      ..headers["Authorization"] = "Bearer $apiKey"
      ..fields["model"] = "gpt-4o-mini-transcribe"
      ..fields["stream"] = "true"
      ..files.add(await http.MultipartFile.fromPath("file", audioFile.path));

    final streamed = await req.send();
    final utf8Stream = streamed.stream.transform(utf8.decoder);
    await for (final line in utf8Stream.transform(const LineSplitter())) {
      if (line.startsWith("data:")) {
        final raw = line.substring(5).trim();
        if (raw == "[DONE]") break;
        final j = json.decode(raw) as Map<String, dynamic>;
        yield TranscriptEvent.fromJson(j);
      }
    }
  }

  void dispose() {
    _client.close();
  }
}