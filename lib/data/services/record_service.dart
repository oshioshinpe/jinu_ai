import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:openai_dart/openai_dart.dart';

class RecordService {
 final AudioRecorder _audioRecorder = AudioRecorder();
 final OpenAIClient client;
 
 String? _currentRecordingPath;
 bool _isRecording = false;
 
 bool get isRecording => _isRecording;

 RecordService({required this.client});

 Future<void> startRecording() async {
 if (_isRecording) return;

 try {
 // Request microphone permissions
 var status = await Permission.microphone.request();
 if (!status.isGranted) {
 throw Exception('Microphone permission not granted');
 }

 // Generate a unique filename for the recording
 final directory = await getTemporaryDirectory();
 final timestamp = DateTime.now().millisecondsSinceEpoch;
 _currentRecordingPath = '${directory.path}/recording_$timestamp.wav';

 // Start recording
 await _audioRecorder.start(
 RecordConfig(
 encoder: AudioEncoder.wav,
 bitRate: 128000,
 sampleRate: 44100,
 numChannels: 1,
 ),
 path: _currentRecordingPath!,
 );

 _isRecording = true;
 } catch (e) {
 debugPrint('Error starting recording: $e');
 rethrow;
 }
 }

 Future<String?> stopRecording() async {
 if (!_isRecording) return null;

 try {
 await _audioRecorder.stop();
 _isRecording = false;

 return _currentRecordingPath;
 } catch (e) {
 debugPrint('Error stopping recording: $e');
 return null;
 }
 }

 Future<String?> transcribeAudio(String audioFilePath) async {
 try {
 // Read audio file as bytes
 final File audioFile = File(audioFilePath);
 final audioBytes = await audioFile.readAsBytes();

 // Create OpenAI chat completion request with audio
 final res = await client.createChatCompletion(
 request: CreateChatCompletionRequest(
 model: ChatCompletionModel.model(
 ChatCompletionModels.gpt4oAudioPreview,
 ),
 modalities: [
 ChatCompletionModality.text,
 ChatCompletionModality.audio,
 ],
 audio: ChatCompletionAudioOptions(
 voice: ChatCompletionAudioVoice.alloy,
 format: ChatCompletionAudioFormat.wav,
 ),
 messages: [
 ChatCompletionMessage.user(
 content: ChatCompletionUserMessageContent.parts([
 ChatCompletionMessageContentPart.text(
 text: 'Transcribe the audio accurately',
 ),
 ChatCompletionMessageContentPart.audio(
 inputAudio: ChatCompletionMessageInputAudio(
 data: base64Encode(audioBytes),
 format: ChatCompletionMessageInputAudioFormat.wav,
 ),
 ),
 ]),
 ),
 ],
 ),
 );

 // Process the response
 return res.choices.first.message.content;
 } catch (e) {
 debugPrint('Error transcribing audio: $e');
 return null;
 }
 }

 // Cleanup method to ensure resources are released
 void dispose() {
 _audioRecorder.dispose();
 }
}