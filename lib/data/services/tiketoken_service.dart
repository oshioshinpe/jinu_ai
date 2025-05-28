import 'package:tiktoken/tiktoken.dart';

  class TiktokenService {
    static Tiktoken? _cl100kBase;

    static Tiktoken get _encoder {
      _cl100kBase ??= getEncoding("cl100k_base");
      return _cl100kBase!;
    }

    static int countTokens(String text) {
      try {
        return _encoder.encode(text).length;
      } catch (e) {
        // Fallback for safety, though tiktoken_dart should be robust
        print("Tiktoken encoding error: $e");
        return (text.length / 3.5).ceil(); // Rough estimate
      }
    }

    // This model name to encoding mapping might be useful if you use diverse models
    // static Tiktoken? encodingForModel(String modelName) {
    //   try {
    //     return getEncodingForModel(modelName);
    //   } catch (e) {
    //     print("No encoding found for model $modelName, using cl100k_base as default.");
    //     return getEncoding("cl100k_base");
    //   }
    // }
  }
  