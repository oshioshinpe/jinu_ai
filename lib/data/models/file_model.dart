import 'dart:io';

class FileModel {
  final File file;
  final String? mimeType;
  final String? name;
  final DateTime? creationDate;
  final int? size;
  final String? path;
  final bool isImage;
  final bool isAudio;
  final bool isVideo;

  FileModel({
    required this.file,
    this.mimeType,
    this.name,
    this.creationDate,
    this.size,
    this.path,
    this.isImage = false,
    this.isAudio = false,
    this.isVideo = false,
  });

  factory FileModel.fromFile(File file, {String? mimeType}) {
    final path = file.path;
    final fileName = path.split('/').last;
    
    // Safely get file stats with error handling
    FileStat? fileStat;
    try {
      fileStat = file.statSync();
    } catch (e) {
      // If we can't get file stats, use defaults
      fileStat = null;
    }

    // Determine file type based on mimeType or extension
    final isImage = mimeType?.startsWith('image/') ?? false;
    final isAudio = mimeType?.startsWith('audio/') ?? false;
    final isVideo = mimeType?.startsWith('video/') ?? false;

    return FileModel(
      file: file,
      mimeType: mimeType,
      name: fileName,
      creationDate: fileStat?.modified,
      size: fileStat?.size ?? 0,
      path: path,
      isImage: isImage,
      isAudio: isAudio,
      isVideo: isVideo,
    );
  }

  // Helper method to check if file is supported
  bool get isSupported => isImage || isAudio || isVideo;

  // Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'mimeType': mimeType,
      'size': size,
      'creationDate': creationDate?.toIso8601String(),
      'isImage': isImage,
      'isAudio': isAudio,
      'isVideo': isVideo,
    };
  }

  // Create from map for deserialization
  factory FileModel.fromMap(Map<String, dynamic> map) {
    return FileModel(
      file: File(map['path']),
      mimeType: map['mimeType'],
      name: map['name'],
      size: map['size'],
      creationDate: map['creationDate'] != null ? DateTime.parse(map['creationDate']) : null,
      path: map['path'],
      isImage: map['isImage'] ?? false,
      isAudio: map['isAudio'] ?? false,
      isVideo: map['isVideo'] ?? false,
    );
  }

  @override
  String toString() {
    return 'FileModel(name: $name, mimeType: $mimeType, size: $size, isImage: $isImage, isAudio: $isAudio, isVideo: $isVideo)';
  }
}