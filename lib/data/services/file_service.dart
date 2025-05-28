import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:jinu/data/models/file_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
// Optional: import 'package:image_gallery_saver/image_gallery_saver.dart';

enum FileSource { gallery, camera, storage }

class FileService {
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  // Optional: final _gallerySaver = ImageGallerySaver();
  final Uuid _uuid = const Uuid();

  // --- Permission Handling ---

  Future<bool> _requestPermission(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) {
      return true;
    } else if (status.isDenied || status.isPermanentlyDenied) {
      final newStatus = await permission.request();
      return newStatus.isGranted;
    }
    return false; // Should not happen unless restricted
  }

  Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true; // No explicit permission needed for web picker
    // Android 13+ uses specific media permissions
    if (Platform.isAndroid) {
        // Check Android version maybe? Or just request all potentially needed
        bool photosGranted = await _requestPermission(Permission.photos);
        bool videosGranted = await _requestPermission(Permission.videos);
        bool audioGranted = await _requestPermission(Permission.audio);
        // For older Android or general files, request storage
        bool storageGranted = await _requestPermission(Permission.storage);
        // Return true if any relevant permission is granted
        return photosGranted || videosGranted || audioGranted || storageGranted;
    } else if (Platform.isIOS) {
        // On iOS, photo permission covers gallery access
        return await _requestPermission(Permission.photos);
    } else {
        // Assume general storage for other platforms (like Desktop)
        return await _requestPermission(Permission.storage);
    }
  }


  Future<bool> requestCameraPermission() async {
    if (kIsWeb) return true; // Browser handles camera permission
    return _requestPermission(Permission.camera);
  }

  Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) return true; // Browser handles mic permission
    return _requestPermission(Permission.microphone);
  }

  // --- File Picking ---

  /// Picks a file from device storage.
  /// Allows specifying allowed extensions (e.g., ['jpg', 'pdf', 'doc']).
  Future<FileModel?> pickFile({List<String>? allowedExtensions}) async {
    if (!await requestStoragePermission()) {
      debugPrint("Storage permission denied.");
      return null;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final mimeType = getMimeType(file.path);
        return FileModel.fromFile(file, mimeType: mimeType);
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
    return null;
  }

  /// Picks an image from the gallery.
  Future<FileModel?> pickImageFromGallery() async {
    if (!await requestStoragePermission()) {
      debugPrint("Storage permission denied.");
      return null;
    }
    
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        final fileObj = File(file.path);
        final mimeType = getMimeType(file.path);
        return FileModel.fromFile(fileObj, mimeType: mimeType);
      }
    } catch (e) {
      debugPrint("Error picking image from gallery: $e");
    }
    return null;
  }

    /// Takes a photo using the camera.
  Future<FileModel?> takePhotoWithCamera() async {
     if (!await requestCameraPermission()) {
      debugPrint("Camera permission denied.");
      return null;
    }
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final mimeType = getMimeType(pickedFile.path);
        return FileModel.fromFile(file, mimeType: mimeType);
      }
    } catch (e) {
      debugPrint("Error taking photo: $e");
    }
    return null;
  }

  // --- MIME Type ---

  /// Gets the MIME type of a file based on its path/extension.
  String? getMimeType(String filePath) {
    return lookupMimeType(filePath);
  }

  // --- Audio Recording ---

  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;

  /// Starts audio recording. Returns true if successful, false otherwise.
  Future<bool> startRecording() async {
    if (_isRecording) return false; // Already recording

    if (!await requestMicrophonePermission()) {
      debugPrint("Microphone permission denied.");
      return false;
    }

    try {
       final dir = await getTemporaryDirectory();
       // Use a unique filename
       _currentRecordingPath = '${dir.path}/${_uuid.v4()}.m4a'; // m4a is widely compatible

       // Ensure recorder is ready
       if (!await _audioRecorder.hasPermission()) {
           debugPrint("Audio recorder does not have permission (should have been requested).");
           return false;
       }

       // Start recording to file
       await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _currentRecordingPath!);

       _isRecording = await _audioRecorder.isRecording();
       debugPrint("Recording started: $_isRecording, Path: $_currentRecordingPath");
       return _isRecording;

    } catch (e) {
        debugPrint("Error starting recording: $e");
        _isRecording = false;
        // Clean up the path if recording failed
        if (_currentRecordingPath != null) {
          await _tryDeleteFile(_currentRecordingPath!);
          _currentRecordingPath = null;
        }
        return false;
    }
  }

  /// Stops the current audio recording and returns the File object.
  /// Returns null if not recording or an error occurs.
  Future<FileModel?> stopRecording() async {
    if (!_isRecording || _currentRecordingPath == null) return null;

    try {
      final path = await _audioRecorder.stop(); // Returns the path
      _isRecording = false;
      debugPrint("Recording stopped. File at: $path");

      if (path != null) {
        final recordedFile = File(path);
        final mimeType = getMimeType(path);
        // Verify file exists before returning
        if (await recordedFile.exists() && await recordedFile.length() > 0) {
             _currentRecordingPath = null; // Clear path after successful stop
             return FileModel.fromFile(recordedFile, mimeType: mimeType);
        } else {
             debugPrint("Recorded file is empty or does not exist at path: $path");
             _currentRecordingPath = null;
             await _tryDeleteFile(path); // Clean up empty/invalid file
             return null;
        }
      } else {
         debugPrint("Recorder stop method returned null path.");
         _currentRecordingPath = null;
         return null;
      }
    } catch (e) {
      debugPrint("Error stopping recording: $e");
      _isRecording = false;
       // Attempt cleanup even on error
      if (_currentRecordingPath != null) {
          await _tryDeleteFile(_currentRecordingPath!);
      }
      _currentRecordingPath = null;
      return null;
    }
  }

  /// Cancels the current recording and deletes the temporary file.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _audioRecorder.stop(); // Stop recording first
      debugPrint("Recording cancelled.");
    } catch (e) {
      debugPrint("Error stopping during cancel: $e");
      // Continue to attempt deletion
    } finally {
       _isRecording = false;
       if (_currentRecordingPath != null) {
           await _tryDeleteFile(_currentRecordingPath!);
           _currentRecordingPath = null;
       }
    }
  }

  // Helper to safely delete a file
  Future<void> _tryDeleteFile(String filePath) async {
      try {
          final file = File(filePath);
          if (await file.exists()) {
              await file.delete();
              debugPrint("Deleted temporary file: $filePath");
          }
      } catch (e) {
          debugPrint("Error deleting file $filePath: $e");
      }
  }


  // --- File Saving ---

  /// Saves a file (e.g., received audio) to the device's downloads or documents directory.
  /// Returns the path where the file was saved, or null on failure.
  Future<String?> saveFileToAppDirectory(FileModel fileModel, String desiredName) async {
      if (kIsWeb) {
          debugPrint("File saving to specific directory not directly supported on web.");
          // On web, you might trigger a download via dart:html anchor element
          return null;
      }
      try {
          // Get a suitable directory (Downloads is often restricted, Documents or AppSupport is better)
          Directory? directory;
          if (Platform.isAndroid) {
              directory = await getExternalStorageDirectory(); // Or getApplicationDocumentsDirectory()
              // Creating a specific subfolder might be good practice
                directory = Directory('${directory!.path}/MyAppFiles');
                if (!await directory.exists()) {
                    await directory.create(recursive: true);
                }
                      } else if (Platform.isIOS || Platform.isMacOS) {
              directory = await getApplicationDocumentsDirectory();
          } else {
              directory = await getDownloadsDirectory(); // Best guess for Desktop Linux/Windows
          }


          final String savePath = '${directory!.path}/$desiredName';
          await fileModel.file.copy(savePath);
          debugPrint("File saved to: $savePath");
          return savePath;


      } catch (e) {
          debugPrint("Error saving file: $e");
          return null;
      }
  }


  /// Saves an image file to the device's photo gallery.
  /// Requires image_gallery_saver package (optional).
  //  Future<bool> saveImageToGallery(FileModel fileModel) async {
  //     if (kIsWeb) {
  //         debugPrint("Saving to gallery not applicable on web.");
  //         return false;
  //     }
  //     if (!await requestStoragePermission()) { // Or specific photo add permission if available
  //         debugPrint("Storage/Photo permission denied for saving to gallery.");
  //         return false;
  //     }
  //     // try {
  //     //     final result = await ImageGallerySaver.saveFile(fileModel.path!);
  //     //     debugPrint("Save image to gallery result: $result");
  //     //     return result['isSuccess'] ?? false;
  //     // } catch (e) {
  //     //     debugPrint("Error saving image to gallery: $e");
  //     //     return false;
  //     // }
  // }


  // --- Cleanup ---
  void dispose() {
      _audioRecorder.dispose(); // Release recorder resources
  }
} 