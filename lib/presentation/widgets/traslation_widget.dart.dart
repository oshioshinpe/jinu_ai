import 'dart:convert'; // For base64 encoding images
import 'dart:io'; // For Platform.environment, File operations
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:jinu/data/utils/theme_for_translator.dart';
import 'package:jinu/presentation/providers/settings_provider.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:jinu/data/services/record_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Assuming these are in lib/services/
import 'package:jinu/data/services/tiktoken_service.dart';
import 'package:jinu/data/services/permission_service.dart';

// --- Data Models ---
class TranslationHistoryItem {
  final String id;
  final String sourceText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final TranslationMode mode;
  final DateTime timestamp;

  TranslationHistoryItem({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.mode,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceText': sourceText,
    'translatedText': translatedText,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'mode': mode.toString(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory TranslationHistoryItem.fromJson(Map<String, dynamic> json) =>
      TranslationHistoryItem(
        id: json['id'],
        sourceText: json['sourceText'],
        translatedText: json['translatedText'],
        sourceLanguage: json['sourceLanguage'],
        targetLanguage: json['targetLanguage'],
        mode: TranslationMode.values.firstWhere(
          (e) => e.toString() == json['mode'],
        ),
        timestamp: DateTime.parse(json['timestamp']),
      );
}

// --- Main Screen ---
enum TranslationMode { text, images, documents, websites, audioFile }

class TranslateScreen extends ConsumerStatefulWidget {
  TranslateScreen({super.key});
  @override
  ConsumerState<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends ConsumerState<TranslateScreen> {
  TranslationMode _currentMode = TranslationMode.text;
  String _sourceLanguage = 'Detect language';
  String _targetLanguage = 'English';
  final TextEditingController _sourceTextController = TextEditingController();
  String _translatedText = '';
  final int _maxLength = 5000; // Increased max length for input
  int _currentTokenCount = 0;

  bool _isLoading = false;
  double _translationProgress = 0.0; // For chunked translation
  String _loadingMessage = "Translating...";

  late OpenAIClient _openAIClient;
  final PermissionService _permissionService = PermissionService();
  final Uuid _uuid = const Uuid();
  late RecordService _recordService;

  XFile? _pickedImageFile;
  PlatformFile? _pickedAudioFile;

  // Dummy language list - Consider making this more dynamic or comprehensive
  final List<String> _allLanguages = [
    'Detect language', 'English', 'Spanish', 'French', 'German', 'Persian',
    'Arabic',
    'Chinese (Simplified)',
    'Japanese',
    'Russian',
    'Korean',
    'Italian',
    'Portuguese',
    'Hindi',
    'Turkish',
    'Dutch',
    'Polish', // Add more common languages
  ];

  @override
  void initState() {
    super.initState();
    // final apiKey = Platform.environment['OPENAI_API_KEY'] ?? dotenv.env['OPENAI_API_KEY'];
    // if (apiKey == null || apiKey.isEmpty) {
    //   // Critical: Handle missing API key. Show an error, disable functionality.
    //   print("CRITICAL: OPENAI_API_KEY not found.");
    //   // You might want to show a dialog to the user here.
    // }
    _openAIClient = OpenAIClient(
      apiKey: "aa-b1BFjpcQHWHDgTWnpsfTGm7CwueIsSjrbl8UMD5ezCLaBPHY",
      baseUrl: "https://api.avalai.ir/v1",
    );

    _recordService = RecordService(client: _openAIClient);

    _sourceTextController.addListener(() {
      setState(() {
        _currentTokenCount = TiktokenService.countTokens(
          _sourceTextController.text,
        );
      });
    });
    _loadDefaultLanguages();
  }

  Future<void> _loadDefaultLanguages() async {
    // Could load preferred languages from SharedPreferences here if needed
  }

  @override
  void dispose() {
    _sourceTextController.dispose();
    super.dispose();
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  String _getLanguageCodeForOpenAI(String languageName) {
    // This is a simplification. OpenAI doesn't use codes for detection,
    // but for specific language requests, full names are usually fine.
    // For some APIs or models, specific ISO codes might be needed.
    // For chat completion prompts, human-readable names are generally okay.
    return languageName;
  }

  Future<void> _triggerTranslation() async {
    if (_isLoading) return;

    final String textToTranslate = _sourceTextController.text.trim();
    String effectiveSourceLang = _sourceLanguage;

    if (_currentMode == TranslationMode.text) {
      if (textToTranslate.isEmpty) {
        _showErrorSnackbar('Please enter text to translate.');
        return;
      }
    } else if (_currentMode == TranslationMode.images) {
      if (_pickedImageFile == null) {
        _showErrorSnackbar('Please pick an image to translate.');
        return;
      }
    } else if (_currentMode == TranslationMode.audioFile) {
      if (_pickedAudioFile == null) {
        _showErrorSnackbar('Please pick an audio file to translate.');
        return;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_currentMode.name} mode translation not fully implemented yet.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _translatedText = '';
      _translationProgress = 0.0;
      _loadingMessage = "Processing...";
    });

    try {
      if (_currentMode == TranslationMode.text) {
        await _translateText(
          textToTranslate,
          effectiveSourceLang,
          _targetLanguage!,
        );
      } else if (_currentMode == TranslationMode.images) {
        await _translateImageContent(
          _pickedImageFile!,
          effectiveSourceLang,
          _targetLanguage!,
        );
      } else if (_currentMode == TranslationMode.audioFile) {
        await _translateAudioFile(
          _pickedAudioFile!,
          effectiveSourceLang,
          _targetLanguage!,
        );
      }
    } catch (e) {
      print("Error during translation: $e");
      _showErrorSnackbar('Translation failed: ${e.toString()}');
      setState(() {
        _translatedText = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
        _translationProgress = 0.0;
      });
    }
  }

  Future<void> _translateText(
    String text,
    String sourceLang,
    String targetLang,
  ) async {
    setState(() => _loadingMessage = "Translating text...");
    // Max tokens for gpt-4o-mini is high (e.g., 128k context, but output is limited, e.g. 4k tokens)
    // Let's aim for ~3000 input tokens per chunk to be safe and allow for prompt/response.
    const maxTokensPerChunk = 3000;
    final totalTokens = TiktokenService.countTokens(text);

    String systemPrompt;
    if (sourceLang == 'Detect language') {
      systemPrompt =
          "You are an expert multilingual translator. First, detect the language of the provided text. Then, translate the detected text accurately into $targetLang";
    } else {
      systemPrompt =
          "You are an expert multilingual translator. Translate the following text from $sourceLang to $targetLang accurately. Respond only with the translated text.";
    }

    List<String> chunks = _splitTextIntoChunks(text, maxTokensPerChunk);
    StringBuffer translatedBuffer = StringBuffer();

    for (int i = 0; i < chunks.length; i++) {
      if (!mounted) return; // Check if widget is still in tree
      setState(() {
        _loadingMessage = "Translating chunk ${i + 1} of ${chunks.length}...";
        _translationProgress = (i + 1) / chunks.length;
      });

      final request = CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId('gpt-4o-mini'),
        messages: [
          ChatCompletionMessage.system(content: systemPrompt),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(chunks[i]),
          ),
        ],
        temperature:
            0.3, // Lower temperature for more deterministic translation
        // maxTokens: 4096, // Max output tokens, adjust if needed
      );

      // Using stream for potentially faster perceived response
      final stream = _openAIClient.createChatCompletionStream(request: request);
      StringBuffer chunkTranslation = StringBuffer();
      await for (final res in stream) {
        chunkTranslation.write(res.choices.first.delta.content ?? "");
        if (mounted) {
          // Update UI progressively
          setState(() {
            _translatedText =
                translatedBuffer.toString() + chunkTranslation.toString();
          });
        }
      }
      translatedBuffer.write(chunkTranslation.toString());
      if (chunks.length > 1 && i < chunks.length - 1) {
        translatedBuffer.write("\n\n"); // Add separator for multi-chunk
      }
    }

    if (mounted) {
      final finalTranslation = translatedBuffer.toString().trim();
      setState(() {
        _translatedText = finalTranslation;
      });
      if (finalTranslation.isNotEmpty &&
          !finalTranslation.startsWith("Error:")) {
        _saveToHistory(
          text,
          finalTranslation,
          sourceLang,
          targetLang,
          TranslationMode.text,
        );
      }
    }
  }

  Future<void> _translateImageContent(
    XFile imageFile,
    String sourceLang,
    String targetLang,
  ) async {
    setState(() => _loadingMessage = "Processing image...");
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    String detectedTextPrompt =
        "Extract all text from this image. If no text is found, respond with 'No text found in image.'";
    if (sourceLang != 'Detect language') {
      detectedTextPrompt += " The text is expected to be in $sourceLang.";
    }

    // Step 1: Extract text using gpt-4o (which is multi-modal)
    final extractionRequest = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(
        'gpt-4.1-mini',
      ), // Use gpt-4o for vision
      messages: [
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.parts([
            ChatCompletionMessageContentPart.text(text: detectedTextPrompt),
            ChatCompletionMessageContentPart.image(
              imageUrl: ChatCompletionMessageImageUrl(
                url:
                    'data:image/jpeg;base64,$base64Image', // Assuming JPEG, adjust if needed
              ),
            ),
          ]),
        ),
      ],
      maxTokens: 1000,
    );

    String extractedText = "";
    setState(() => _loadingMessage = "Extracting text from image...");
    try {
      final extractionStream = _openAIClient.createChatCompletionStream(
        request: extractionRequest,
      );
      StringBuffer tempExtractedText = StringBuffer();
      await for (final res in extractionStream) {
        tempExtractedText.write(res.choices.first.delta.content ?? "");
      }
      extractedText = tempExtractedText.toString().trim();

      if (extractedText.isEmpty ||
          extractedText.toLowerCase().contains("no text found")) {
        setState(
          () =>
              _translatedText =
                  "No text found in image or text extraction failed.",
        );
        return;
      }
      setState(() {
        _sourceTextController.text =
            "Extracted text: \n$extractedText"; // Show extracted text
        _currentTokenCount = TiktokenService.countTokens(
          _sourceTextController.text,
        );
      });
    } catch (e) {
      _showErrorSnackbar("Image text extraction failed: $e");
      setState(() => _translatedText = "Error extracting text from image.");
      return;
    }

    // Step 2: Translate the extracted text
    if (extractedText.isNotEmpty) {
      setState(() => _loadingMessage = "Translating extracted text...");
      await _translateText(
        extractedText,
        "Detect language",
        targetLang,
      ); // Always detect for extracted
      // History will be saved by _translateText
    }
  }

  Future<void> _translateAudioFile(
    PlatformFile audioFile,
    String sourceLang,
    String targetLang,
  ) async {
    if (audioFile.path == null) {
      _showErrorSnackbar("Audio file path is invalid.");
      return;
    }
    setState(() => _loadingMessage = "Transcribing audio...");
    final audioBytes = await File(audioFile.path!).readAsBytes();
    // Using base64 for audio input as per one of the examples for chat completion
    // Note: openai_dart might have a dedicated createTranscription method which could be more direct for Whisper.
    // The example provided uses chat completion with audio data.

    final transcriptionRequest = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(
        'gpt-4.1-mini',
      ), // gpt-4o supports audio
      messages: [
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.parts([
            ChatCompletionMessageContentPart.text(
              text:
                  'Transcribe this audio accurately. The language of the audio is likely $sourceLang, but auto-detect if unsure.',
            ),
            ChatCompletionMessageContentPart.audio(
              inputAudio: ChatCompletionMessageInputAudio(
                data: base64Encode(audioBytes),
                format:
                    ChatCompletionMessageInputAudioFormat.wav, // Send as base64
                // format: ChatCompletionMessageInputAudioFormat.wav, // Adjust format if known and supported
                // Ensure your input audio format is compatible or use a dedicated transcription endpoint if issues
              ),
            ),
          ]),
        ),
      ],
      // modalities: [ // This might be needed depending on the exact openai_dart version and model
      //   ChatCompletionModality.text,
      //   ChatCompletionModality.audio,
      // ],
      maxTokens: 1000,
    );

    String transcribedText = "";
    try {
      final transcriptionStream = _openAIClient.createChatCompletionStream(
        request: transcriptionRequest,
      );
      StringBuffer tempTranscribedText = StringBuffer();
      await for (final res in transcriptionStream) {
        tempTranscribedText.write(res.choices.first.delta.content ?? "");
      }
      transcribedText = tempTranscribedText.toString().trim();

      if (transcribedText.isEmpty ||
          transcribedText.toLowerCase().contains("could not transcribe")) {
        setState(
          () =>
              _translatedText =
                  "Audio transcription failed or no speech detected.",
        );
        return;
      }
      setState(() {
        _sourceTextController.text = "Transcribed text: \n$transcribedText";
        _currentTokenCount = TiktokenService.countTokens(
          _sourceTextController.text,
        );
      });
    } catch (e) {
      _showErrorSnackbar("Audio transcription failed: $e");
      setState(() => _translatedText = "Error during audio transcription.");
      return;
    }

    // Step 2: Translate the transcribed text
    if (transcribedText.isNotEmpty) {
      setState(() => _loadingMessage = "Translating transcribed text...");
      await _translateText(
        transcribedText,
        "Detect language",
        targetLang,
      ); // Assume auto-detect for transcript
    }
  }

  List<String> _splitTextIntoChunks(String text, int maxTokensPerChunk) {
    List<String> chunks = [];
    if (text.isEmpty) return chunks;

    int totalTokens = TiktokenService.countTokens(text);
    if (totalTokens <= maxTokensPerChunk) {
      chunks.add(text);
      return chunks;
    }

    // Simple split by attempting to maintain sentences/paragraphs
    // A more sophisticated approach would involve token-aware splitting.
    List<String> paragraphs = text.split(
      RegExp(r'\n\s*\n'),
    ); // Split by double newlines
    StringBuffer currentChunkBuffer = StringBuffer();
    int currentChunkTokens = 0;

    for (String p in paragraphs) {
      if (p.trim().isEmpty) continue;
      int paragraphTokens = TiktokenService.countTokens(p);

      if (currentChunkTokens + paragraphTokens <= maxTokensPerChunk) {
        currentChunkBuffer.write(p + "\n\n");
        currentChunkTokens += paragraphTokens;
      } else {
        // Paragraph is too big for current chunk, or itself too big
        if (currentChunkBuffer.isNotEmpty) {
          chunks.add(currentChunkBuffer.toString().trim());
          currentChunkBuffer.clear();
          currentChunkTokens = 0;
        }
        // If paragraph itself is too big, split it further (e.g., by sentences or hard char limit)
        if (paragraphTokens > maxTokensPerChunk) {
          List<String> sentences = p.split(RegExp(r'(?<=[.!?])\s+'));
          for (String s in sentences) {
            int sentenceTokens = TiktokenService.countTokens(s);
            if (currentChunkTokens + sentenceTokens <= maxTokensPerChunk) {
              currentChunkBuffer.write(s + " ");
              currentChunkTokens += sentenceTokens;
            } else {
              if (currentChunkBuffer.isNotEmpty) {
                chunks.add(currentChunkBuffer.toString().trim());
              }
              currentChunkBuffer.clear();
              currentChunkBuffer.write(s + " ");
              currentChunkTokens = sentenceTokens;
            }
          }
        } else {
          currentChunkBuffer.write(p + "\n\n");
          currentChunkTokens =
              paragraphTokens; // Start new chunk with this paragraph
        }
      }
    }
    if (currentChunkBuffer.isNotEmpty) {
      chunks.add(currentChunkBuffer.toString().trim());
    }

    // If any chunk is still too large after basic splitting (e.g. very long sentence), do a hard split.
    // This is a fallback.
    List<String> finalChunks = [];
    for (String chunk in chunks) {
      if (TiktokenService.countTokens(chunk) > maxTokensPerChunk) {
        // Hard split based on approximate character length per token
        int approxCharsPerToken = 3; // Estimate
        int maxLengthChars = maxTokensPerChunk * approxCharsPerToken;
        for (int i = 0; i < chunk.length; i += maxLengthChars) {
          finalChunks.add(
            chunk.substring(
              i,
              i + maxLengthChars > chunk.length
                  ? chunk.length
                  : i + maxLengthChars,
            ),
          );
        }
      } else {
        finalChunks.add(chunk);
      }
    }
    return finalChunks.isEmpty && text.isNotEmpty
        ? [text]
        : finalChunks; // Ensure at least one chunk if text exists
  }

  Future<void> _saveToHistory(
    String source,
    String translated,
    String sourceLang,
    String targetLang,
    TranslationMode mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyJson = prefs.getStringList('translationHistory') ?? [];

    final newItem = TranslationHistoryItem(
      id: _uuid.v4(),
      sourceText: source,
      translatedText: translated,
      sourceLanguage: sourceLang,
      targetLanguage: targetLang,
      mode: mode,
      timestamp: DateTime.now(),
    );
    historyJson.insert(0, jsonEncode(newItem.toJson())); // Add to top

    // Limit history size
    if (historyJson.length > 50) {
      historyJson = historyJson.sublist(0, 50);
    }
    await prefs.setStringList('translationHistory', historyJson);
  }

  void _swapLanguages() {
    if (_sourceLanguage == 'Detect language' &&
        _targetLanguage == 'Detect language') {
      return;
    }
    if (_sourceLanguage == 'Detect language') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot swap "Detect language" to be a target language directly. Please select a specific source language first.',
          ),
        ),
      );
      return;
    }
    setState(() {
      final tempLang = _sourceLanguage;
      _sourceLanguage = _targetLanguage!;
      _targetLanguage = tempLang;

      // Optionally swap text and re-translate
      if (_sourceTextController.text.isNotEmpty || _translatedText.isNotEmpty) {
        final currentSourceText = _sourceTextController.text;
        _sourceTextController.text =
            _translatedText.startsWith("Error:") ? "" : _translatedText;
        _translatedText = ""; // Clear previous translation to avoid confusion
        // If you want to auto-translate after swap:
        // if (_sourceTextController.text.isNotEmpty) {
        //   _triggerTranslation();
        // }
      }
    });
  }

  void _copyToClipboard(String text, String fieldName) {
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nothing to copy from $fieldName.')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$fieldName copied to clipboard.')));
  }

  Future<void> _saveToFile() async {
    if (_translatedText.isEmpty || _translatedText.startsWith("Error:")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid translation to save.')),
      );
      return;
    }

    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select an output file:',
        fileName:
            'translation_output_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt',
        type: FileType.custom,
        allowedExtensions: ['txt', 'md'], // Allow text and markdown
      );

      if (outputFile != null) {
        // Ensure the file has an extension if user didn't provide one
        String finalPath = outputFile;
        if (!outputFile.contains('.')) {
          finalPath += '.txt'; // Default to .txt
        }

        final file = File(finalPath);
        await file.writeAsString(_translatedText);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation saved to $finalPath')),
        );
      } else {
        // User canceled the picker
      }
    } catch (e) {
      _showErrorSnackbar('Error saving file: $e');
    }
  }

  Future<void> _pickImage() async {
    bool hasPermission = await _permissionService.requestPhotosPermission();
    if (!hasPermission) {
      // Optionally, request camera permission if you want to offer taking a picture
      bool hasCameraPermission =
          await _permissionService.requestCameraPermission();
      if (!hasCameraPermission) {
        _showErrorSnackbar('Photo library permission not granted.');
        return;
      }
    }

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _pickedImageFile = image;
          _sourceTextController.text =
              'Image selected: ${image.name}'; // Placeholder
          _translatedText = ''; // Clear previous translation
          _currentMode = TranslationMode.images; // Switch mode
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error picking image: $e');
    }
  }

  Future<void> _pickAudioFile() async {
    // File picker usually doesn't need explicit storage permission for picking.
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _pickedAudioFile = result.files.single;
          _sourceTextController.text =
              'Audio file selected: ${_pickedAudioFile!.name}';
          _translatedText = '';
          _currentMode = TranslationMode.audioFile; // Switch mode
        });
      } else {
        // User canceled the picker
      }
    } catch (e) {
      _showErrorSnackbar('Error picking audio file: $e');
    }
  }

  // --- UI BUILD METHODS ---
  Widget _buildModeButton(TranslationMode mode, IconData icon, String label) {
    final isSelected = _currentMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      child: TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor:
              isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
          foregroundColor:
              isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side:
              isSelected
                  ? BorderSide(color: colorScheme.primary, width: 1.5)
                  : BorderSide.none,
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        onPressed: () {
          setState(() {
            _currentMode = mode;
            _translatedText = ''; // Clear text when mode changes
            _pickedImageFile = null;
            _pickedAudioFile = null;
            if (mode != TranslationMode.text &&
                mode != TranslationMode.images &&
                mode != TranslationMode.audioFile) {
              _sourceTextController.text =
                  ''; // Clear source text for unimplemented modes
            }
            if (mode == TranslationMode.images) _pickImage();
            if (mode == TranslationMode.audioFile) {
              _pickAudioFile();
            } else if (mode == TranslationMode.documents ||
                mode == TranslationMode.websites) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label mode not fully implemented yet.'),
                ),
              );
            }
          });
        },
      ),
    );
  }

  Widget _buildLanguageSelector(bool isSource) {
    List<String> commonLanguages;
    String currentSelection;

    if (isSource) {
      commonLanguages = [
        'Detect language',
        'Persian',
        'English',
        'Spanish',
        'French',
      ];
      currentSelection = _sourceLanguage;
    } else {
      commonLanguages = ['English', 'Persian', 'Spanish', 'French', 'German'];
      currentSelection = _targetLanguage!;
    }

    // Ensure current selection is in the common list or add it
    if (!commonLanguages.contains(currentSelection)) {
      commonLanguages.insert(
        isSource ? 1 : 0,
        currentSelection,
      ); // Add it near the start
    }
    // Remove duplicates if any after adding
    commonLanguages = commonLanguages.toSet().toList();

    List<Widget> buttons =
        commonLanguages.take(5).map((lang) {
          // Show limited common ones
          bool isSelected = currentSelection == lang;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isSource) {
                    _sourceLanguage = lang;
                  } else {
                    _targetLanguage = lang;
                  }
                  // No auto-translate on lang change, user will press button
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  lang,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList();

    buttons.add(
      Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: IconButton(
          icon: Icon(
            Icons.arrow_drop_down_circle_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: "More languages",
          onPressed: () => _showLanguagePicker(isSource),
        ),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: buttons),
    );
  }

  void _showLanguagePicker(bool isSource) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Important for longer lists
      builder: (BuildContext context) {
        String? currentLang = isSource ? _sourceLanguage : _targetLanguage;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      isSource
                          ? "Select Source Language"
                          : "Select Target Language",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _allLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = _allLanguages[index];
                        if (!isSource && lang == 'Detect language') {
                          return const SizedBox.shrink();
                        }

                        return ListTile(
                          title: Text(lang),
                          selected: lang == currentLang,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withOpacity(0.5),
                          onTap: () {
                            setState(() {
                              if (isSource) {
                                _sourceLanguage = lang;
                              } else {
                                _targetLanguage = lang;
                              }
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTranslationPanels(BoxConstraints constraints) {
    bool isWideScreen = constraints.maxWidth > 350;

    Widget sourcePanel = Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: TextField(
                controller: _sourceTextController,
                maxLines: null,
                expands: true,
                maxLength: _maxLength,
                decoration: InputDecoration(
                  hintText:
                      _currentMode == TranslationMode.images
                          ? (_pickedImageFile != null
                              ? 'Image: ${_pickedImageFile!.name}\n(Extracted text will appear here after processing)'
                              : 'Pick an image for translation')
                          : _currentMode == TranslationMode.audioFile
                          ? (_pickedAudioFile != null
                              ? 'Audio: ${_pickedAudioFile!.name}\n(Transcript will appear here after processing)'
                              : 'Pick an audio file for translation')
                          : 'Enter text to translate...',
                  border: InputBorder.none,
                  counterText: '',
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                readOnly:
                    _currentMode == TranslationMode.images ||
                    _currentMode ==
                        TranslationMode
                            .audioFile, // Read-only if image/audio selected
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _recordService.isRecording
                        ? Icons.stop
                        : Icons.mic_none_outlined,
                    color: _recordService.isRecording ? Colors.red : Colors.green,
                  ),
                  tooltip:
                      _recordService.isRecording
                          ? "Stop Recording"
                          : "Voice input",
                  onPressed: () async {
                    if (_recordService.isRecording) {
                      final recordingPath =
                          await _recordService.stopRecording();
                      if (recordingPath != null) {
                        final transcription = await _recordService
                            .transcribeAudio(recordingPath);
                        if (transcription != null) {
                          setState(() {
                            _sourceTextController.text = transcription;
                            _currentTokenCount = TiktokenService.countTokens(
                              transcription,
                            );
                          });
                        } else {
                          _showErrorSnackbar("Failed to transcribe audio");
                        }
                      }
                    } else {
                      try {
                        await _recordService.startRecording();
                        _showErrorSnackbar("Recording started");
                      } catch (error) {
                        _showErrorSnackbar(
                          "Error starting recording: ${error.toString()}",
                        );
                      }
                    }
                  },
                ),
                if (_currentMode == TranslationMode.text)
                  IconButton(
                    icon: Icon(
                      Icons.paste,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    tooltip: "Paste from clipboard",
                    onPressed: () async {
                      final clipboardData = await Clipboard.getData(
                        Clipboard.kTextPlain,
                      );
                      if (clipboardData != null && clipboardData.text != null) {
                        _sourceTextController.text = clipboardData.text!;
                      }
                    },
                  ),
                if (_sourceTextController.text.isNotEmpty &&
                    _currentMode == TranslationMode.text)
                  IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    tooltip: "Clear text",
                    onPressed: () {
                      _sourceTextController.clear();
                      setState(() {
                        _translatedText = '';
                      });
                    },
                  ),
                const Spacer(),
                Text(
                  '${_sourceTextController.text.length} chars / $_currentTokenCount tokens',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                IconButton(
                  icon: Icon(
                    Icons.copy_outlined,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  tooltip: "Copy source text",
                  onPressed:
                      () => _copyToClipboard(
                        _sourceTextController.text,
                        'Source text',
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget targetPanel = Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(2.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Text(
              _isLoading && _translatedText.isEmpty
                  ? (_loadingMessage)
                  : (_translatedText.isEmpty
                      ? 'Translation will appear here.'
                      : _translatedText),
              style: TextStyle(
                fontSize: 16,
                color:
                    _translatedText.isEmpty
                        ? Colors.grey[500]
                        : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (_translatedText.isNotEmpty &&
              !_translatedText.startsWith("Error:"))
            Positioned(
              top: -8,
              right: -8,
              child: IconButton(
                icon: Icon(
                  Icons.copy_outlined,
                  color: Theme.of(context).iconTheme.color,
                ),
                tooltip: "Copy translated text",
                onPressed:
                    () => _copyToClipboard(_translatedText, 'Translated text'),
              ),
            ),
          if (_translatedText.isNotEmpty &&
              !_translatedText.startsWith("Error:"))
            Positioned(
              bottom: -8,
              right: -8,
              child: IconButton(
                icon: Icon(
                  Icons.save_alt_outlined,
                  color: Theme.of(context).iconTheme.color,
                ),
                tooltip: "Save translation to file",
                onPressed: _saveToFile,
              ),
            ),
        ],
      ),
    );

    final panelHeight =
        isWideScreen 
           ? double.infinity
           : (constraints.maxHeight * 0.30).clamp(230.0, 300.0);

    return isWideScreen
        ? Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: sourcePanel),
            const SizedBox(width: 3),
            Expanded(child: targetPanel),
          ],
        )
        : Column(
          children: [
            SizedBox(height: panelHeight, child: sourcePanel),
            const SizedBox(height: 3),
            SizedBox(height: panelHeight, child: targetPanel),
          ],
        );
  }

  Widget _buildBottomActions() {
    final customTheme = AppThemes.darkTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomActionItem(Icons.history, 'History', () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const TranslationHistoryScreen(),
              ),
            );
          }, customTheme.hintColor),
          // _buildBottomActionItem(Icons.star_border, 'Saved', () {
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     const SnackBar(content: Text('Saved feature not implemented')),
          //   );
          // }, customTheme.hoverColor),
          FloatingActionButton.extended(
            onPressed: _isLoading ? null : _triggerTranslation,
            label: Text(
              _isLoading ? "Processing..." : "Translate",
              style: const TextStyle(fontSize: 16),
            ),
            icon:
                _isLoading
                    ? SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.translate_rounded),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          // _buildBottomActionItem(Icons.settings_outlined, 'Settings', () {
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     const SnackBar(content: Text('Settings not implemented')),
          //   );
          //, customTheme.canvasColor),
        ],
      ),
    );
  }

  Widget _buildBottomActionItem(
    IconData icon,
    String label,
    VoidCallback onPressed,
    Color? iconColor,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: iconColor ?? Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: iconColor ?? Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsServiceProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), // Less top padding
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Placeholder for a logo or app name if desired
                      Text(
                        "AI Translator",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.dark_mode_outlined,
                          //: Icons.dark_mode_outlined,
                          color: AppThemes.darkTheme.hoverColor,
                        ),
                        tooltip: "Toggle Theme",
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildModeButton(
                          TranslationMode.text,
                          Icons.translate,
                          'Text',
                        ),
                        _buildModeButton(
                          TranslationMode.images,
                          Icons.image_search,
                          'Image',
                        ),
                        _buildModeButton(
                          TranslationMode.audioFile,
                          Icons.audiotrack_outlined,
                          'Audio File',
                        ),
                        _buildModeButton(
                          TranslationMode.documents,
                          Icons.description_outlined,
                          'Documents',
                        ),
                        _buildModeButton(
                          TranslationMode.websites,
                          Icons.language_outlined,
                          'Websites',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildLanguageSelector(true)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.0),
                        child: IconButton(
                          icon: Icon(
                            Icons.swap_horiz,
                            size: 28,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: _swapLanguages,
                          tooltip: 'Swap languages',
                        ),
                      ),
                      Expanded(child: _buildLanguageSelector(false)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_isLoading &&
                      _translationProgress > 0 &&
                      _translationProgress < 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _translationProgress,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _loadingMessage,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  Expanded(child: _buildTranslationPanels(constraints)),
                  const SizedBox(
                    height: 10,
                  ), // Removed to give more space to panels
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        /* TODO: Implement feedback */
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Feedback not implemented'),
                          ),
                        );
                      },
                      child: const Text(
                        'Send feedback',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  _buildBottomActions(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class TranslationHistoryScreen extends StatelessWidget {
  const TranslationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Translation History')),
      body: const Center(child: Text('Translation history will appear here')),
    );
  }
}