import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/ai_models.dart';

const prefsHistoryIndexKey = 'chat_history_index';
const prefsHistoryPrefix = 'chat_session_';
const prefsActiveChatIdKey = 'active_chat_id';

class ChatHistoryService with ChangeNotifier {
  SharedPreferences? _prefs;
  List<ChatSessionItem> _chatSessions = [];
  String? _activeChatId;
  final _uuid = const Uuid();

  List<ChatSessionItem> get chatSessions => _chatSessions;
  String? get activeChatId => _activeChatId;
  ChatSessionItem? get activeSession => _activeChatId == null
      ? null
      : _chatSessions.firstWhere(
          (s) => s.id == _activeChatId,
          orElse: () {
            if (_chatSessions.isNotEmpty) {
              _activeChatId = _chatSessions.first.id; // Fallback
              _prefs?.setString(prefsActiveChatIdKey, _activeChatId!);
              return _chatSessions.first;
            }
            // Return a dummy ChatSessionItem to satisfy the return type
            return ChatSessionItem(
              id: '',
              title: '',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              lastModified: DateTime.fromMillisecondsSinceEpoch(0),
              messages: [],
            );
          },
        );

  ChatHistoryService() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadHistoryIndex(); // Loads sessions and activeChatId

    if (_activeChatId == null ||
        _chatSessions.every((s) => s.id != _activeChatId)) {
      if (_chatSessions.isNotEmpty) {
        _activeChatId = _chatSessions.first.id; // Default to the most recent
        await _prefs!.setString(prefsActiveChatIdKey, _activeChatId!);
      } else {
        startNewChat(); // Start a new one if history is completely empty
      }
    }
    notifyListeners();
  }

  Future<void> loadHistoryIndex() async {
    _prefs ??= await SharedPreferences.getInstance();
    final ids = _prefs!.getStringList(prefsHistoryIndexKey) ?? [];
    _chatSessions = [];
    List<String> validIds = [];

    for (var id in ids) {
      final jsonS = _prefs!.getString('$prefsHistoryPrefix$id');
      if (jsonS != null) {
        try {
          final item = ChatSessionItem.fromJson(json.decode(jsonS));
          _chatSessions.add(item);
          validIds.add(id);
        } catch (_) {
          // Log error or handle corrupted data, e.g., remove it
          await _prefs!.remove('$prefsHistoryPrefix$id');
        }
      }
    }
    _chatSessions.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    // If there was any corruption affecting the index, update it
    if (validIds.length != ids.length) {
      await _prefs!.setStringList(prefsHistoryIndexKey, validIds);
    }

    _activeChatId = _prefs!.getString(prefsActiveChatIdKey);
    // Ensure activeChatId is valid
    if (_activeChatId != null &&
        !_chatSessions.any((s) => s.id == _activeChatId)) {
      _activeChatId = _chatSessions.isNotEmpty ? _chatSessions.first.id : null;
      if (_activeChatId != null) {
        await _prefs!.setString(prefsActiveChatIdKey, _activeChatId!);
      } else {
        await _prefs!.remove(prefsActiveChatIdKey);
      }
    }
  }

  Future<void> saveChatSession(ChatSessionItem session) async {
    _prefs ??= await SharedPreferences.getInstance();
    session.lastModified = DateTime.now();
    
    // Auto-generate title if it's still "New Chat" and has messages
    if (session.title == 'New Chat' && session.messages.isNotEmpty) {
      session.title = _generateChatTitle(session.messages);
    }
    
    final jsonS = json.encode(session.toJson());
    await _prefs!.setString('$prefsHistoryPrefix${session.id}', jsonS);

    var ids = _prefs!.getStringList(prefsHistoryIndexKey) ?? [];
    ids.remove(session.id); // Remove if exists to re-add at top
    ids.insert(0, session.id);
    await _prefs!.setStringList(prefsHistoryIndexKey, ids);

    final idx = _chatSessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      _chatSessions[idx] = session;
    } else {
      _chatSessions.insert(0, session);
    }
    // Ensure sessions are sorted after any modification or addition
    _chatSessions.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    // If the saved session becomes the active one (e.g. new chat, or explicit save)
    // Or if no active chat is set, make this the active one.
    if (_activeChatId == null ||
        _activeChatId == session.id ||
        !_chatSessions.any((s) => s.id == _activeChatId)) {
      _activeChatId = session.id;
      await _prefs!.setString(prefsActiveChatIdKey, session.id);
    }
    notifyListeners();
  }

  String _generateChatTitle(List<ChatMessageModel> messages) {
    if (messages.isEmpty) return 'New Chat';
    
    final firstUserMessage = messages.firstWhere(
      (m) => m.role == 'user' && m.text.isNotEmpty,
      orElse: () => messages.first,
    );
    
    String title = firstUserMessage.text.trim();
    if (title.length > 50) {
      title = '${title.substring(0, 47)}...';
    }
    
    return title.isEmpty ? 'New Chat' : title;
  }

  Future<void> addMessageToSession(
    String sessionId,
    ChatMessageModel msg,
  ) async {
    // Ensure prefs is initialized
    _prefs ??= await SharedPreferences.getInstance();
    final session = _chatSessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () =>
          throw Exception("Session $sessionId not found for adding message"),
    );
    session.messages.add(msg);
    await saveChatSession(session); // This will update lastModified and re-sort
  }

  Future<void> deleteMessageFromSession(String sessionId, String messageId) async {
    final session = _chatSessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw Exception("Session $sessionId not found"),
    );
    session.messages.removeWhere((m) => m.id == messageId);
    await saveChatSession(session);
  }

  Future<void> deleteMessagesAfter(String sessionId, String messageId) async {
    final session = _chatSessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw Exception("Session $sessionId not found"),
    );
    
    final messageIndex = session.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      session.messages.removeRange(messageIndex + 1, session.messages.length);
      await saveChatSession(session);
    }
  }

  Future<void> updateMessage(String sessionId, String messageId, String newText) async {
    final session = _chatSessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw Exception("Session $sessionId not found"),
    );
    
    final messageIndex = session.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      session.messages[messageIndex].text = newText;
      await saveChatSession(session);
    }
  }

  ChatSessionItem startNewChat() {
    _prefs ??= SharedPreferences.getInstance()
        as SharedPreferences?; // Ensure initialized via _init or here.
    final newSession = ChatSessionItem(
      id: _uuid.v4(),
      title: 'New Chat', // Consider making title based on first message later
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      messages: [],
    );

    // Add to local list immediately for UI responsiveness
    _chatSessions.insert(0, newSession);
    _activeChatId = newSession.id; // Set as active

    // Persist the new session and update index.
    // This ensures the session JSON is saved, not just its ID in the index.
    saveChatSession(newSession); // This also calls notifyListeners()

    return newSession;
  }

  Future<void> deleteChatSession(String id) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('$prefsHistoryPrefix$id');
    var ids = _prefs!.getStringList(prefsHistoryIndexKey) ?? [];
    ids.remove(id);
    await _prefs!.setStringList(prefsHistoryIndexKey, ids);
    _chatSessions.removeWhere((s) => s.id == id);

    if (_activeChatId == id) {
      if (_chatSessions.isNotEmpty) {
        _activeChatId = _chatSessions.first.id;
        await _prefs!.setString(prefsActiveChatIdKey, _activeChatId!);
      } else {
        _activeChatId = null;
        await _prefs!.remove(prefsActiveChatIdKey);
        startNewChat(); // Optionally start a new chat if all are deleted
      }
    }
    notifyListeners();
  }

  void setActiveChatId(String? id) {
    _prefs ??= SharedPreferences.getInstance() as SharedPreferences?;
    if (_activeChatId == id) return; // No change

    if (id != null && _chatSessions.any((s) => s.id == id)) {
      _activeChatId = id;
      _prefs?.setString(prefsActiveChatIdKey, id);
    } else if (id == null) {
      _activeChatId = null;
      _prefs?.remove(prefsActiveChatIdKey);
    } else {
      // Invalid ID passed, do not change active chat, or default
      // For now, we just don't update if id is not in _chatSessions
      return;
    }
    notifyListeners();
  }

  // Export chat session as markdown
  String exportChatAsMarkdown(String sessionId) {
    final session = _chatSessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw Exception("Session $sessionId not found"),
    );

    final buffer = StringBuffer();
    buffer.writeln('# ${session.title}');
    buffer.writeln('');
    buffer.writeln('**Created:** ${session.createdAt.toLocal()}');
    buffer.writeln('**Last Modified:** ${session.lastModified.toLocal()}');
    buffer.writeln('');

    for (final message in session.messages) {
      final role = message.role == 'user' ? 'User' : 'Assistant';
      buffer.writeln('## $role');
      buffer.writeln('');
      if (message.fileType != null) {
        buffer.writeln('*[File: ${message.fileType}]*');
        buffer.writeln('');
      }
      buffer.writeln(message.text);
      buffer.writeln('');
      buffer.writeln('---');
      buffer.writeln('');
    }

    return buffer.toString();
  }

  // Export chat session as plain text
  String exportChatAsText(String sessionId) {
    final session = _chatSessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw Exception("Session $sessionId not found"),
    );

    final buffer = StringBuffer();
    buffer.writeln('${session.title}');
    buffer.writeln('Created: ${session.createdAt.toLocal()}');
    buffer.writeln('Last Modified: ${session.lastModified.toLocal()}');
    buffer.writeln('');

    for (final message in session.messages) {
      final role = message.role == 'user' ? 'User' : 'Assistant';
      buffer.writeln('$role: ${message.text}');
      if (message.fileType != null) {
        buffer.writeln('[File: ${message.fileType}]');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }
}