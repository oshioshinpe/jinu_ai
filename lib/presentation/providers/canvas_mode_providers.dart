import 'package:flutter_riverpod/flutter_riverpod.dart';

// Canvas mode state provider
final canvasModeProvider = StateNotifierProvider<CanvasModeNotifier, CanvasModeState>((ref) {
  return CanvasModeNotifier();
});

// Canvas mode state
class CanvasModeState {
  final bool isActive;
  final String? code;
  final String? language;
  final String? fileName;

  const CanvasModeState({
    this.isActive = false,
    this.code,
    this.language,
    this.fileName,
  });

  CanvasModeState copyWith({
    bool? isActive,
    String? code,
    String? language,
    String? fileName,
  }) {
    return CanvasModeState(
      isActive: isActive ?? this.isActive,
      code: code ?? this.code,
      language: language ?? this.language,
      fileName: fileName ?? this.fileName,
    );
  }
}

// Canvas mode notifier
class CanvasModeNotifier extends StateNotifier<CanvasModeState> {
  CanvasModeNotifier() : super(const CanvasModeState());

  void enableCanvasMode({
    String? code,
    String? language,
    String? fileName,
  }) {
    state = state.copyWith(
      isActive: true,
      code: code,
      language: language,
      fileName: fileName,
    );
  }

  void disableCanvasMode() {
    state = const CanvasModeState(isActive: false);
  }

  void updateCode(String code) {
    state = state.copyWith(code: code);
  }

  void updateLanguage(String language) {
    state = state.copyWith(language: language);
  }

  void updateFileName(String fileName) {
    state = state.copyWith(fileName: fileName);
  }
}