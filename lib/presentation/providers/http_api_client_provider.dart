import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/http_api_client_service.dart';

/// Provider for HTTP API Client Service
final httpApiClientProvider = Provider<HttpApiClientService>((ref) {
  final service = HttpApiClientService();
  
  // Dispose the service when the provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});