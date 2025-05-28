// lib/presentation/providers/api_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/openai_chat_service.dart';
import '../../data/services/title_generator_service.dart';
import 'settings_provider.dart'; // Need settings for title generator API key/model
import 'http_api_client_provider.dart';
import 'memory_provider.dart';
import 'canvas_mode_providers.dart';

// Provider for the raw OpenAI Chat Service
  final container = ProviderContainer();
  final settingsService = container.read(settingsServiceProvider);
  final setsettingsService = settingsServiceProvider.overrideWith((ref) => settingsService);
  final apiKey = settingsService.apitokenmain;
  final title_model = settingsService.defaultchatmodel;

// Provider for AI Companion Service with HTTP API and Memory integration
final aiCompanionServiceProvider = Provider<AICompanionService>((ref) {
  // Get the HTTP API client, memory service, and canvas mode notifier
  final httpApiClient = ref.read(httpApiClientProvider);
  final memoryService = ref.read(longTermMemoryServiceProvider);
  final canvasModeNotifier = ref.read(canvasModeProvider.notifier);
  
  // Create the AI companion service with dependencies
  return AICompanionService(
    httpApiClient: httpApiClient,
    memoryService: memoryService,
    canvasModeNotifier: canvasModeNotifier,
  );
});

// Legacy provider for backward compatibility (if needed)
final openAIChatServiceProvider = Provider<AICompanionService>((ref) {
  return ref.read(aiCompanionServiceProvider);
});

// Provider for the Title Generator Service
// This service needs configuration (API key, model) likely from settings
final titleGeneratorServiceProvider = Provider<TitleGeneratorService>((ref) {

  // Pass the required API key and model from settings
  // Ensure your Settings Service has appropriate getters for these.
  // Use a placeholder or a specific small model if autotitlemodel isn't set.
  final firstUserMessage = "";

  return TitleGeneratorService(firstUserMessage: firstUserMessage, title_model: title_model);
});