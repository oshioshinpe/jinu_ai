
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/file_service.dart';

/// Provides an instance of [FileService].
///
/// This provider manages the lifecycle of the [FileService], including
/// calling its `dispose` method when the provider is no longer in use.
final fileServiceProvider = Provider<FileService>((ref) {
  final fileService = FileService();
  
  // Properly dispose of the service when the provider is disposed
  ref.onDispose(() => fileService.dispose());

  return fileService;
});