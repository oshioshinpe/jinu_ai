// lib/data/services/chat_history_service.dart
import 'dart:convert';
import 'package:flutter/material.dart'; // For ChangeNotifier and debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart'; // Assuming constants are defined here
import '../models/chat_session_item.dart'; // Import the model
import '../models/chat_message.dart'; // Import message model

var _uuid = const Uuid();

class ChatHistoryService with ChangeNotifier {
  SharedPreferences? _prefs;
  List<ChatSessionItem> _chatSessions = [];
  String? _activeChatId; // ID of the currently loaded chat

  List<ChatSessionItem> get chatSessions => _chatSessions;
  String? get activeChatId => _activeChatId;

  ChatHistoryService() {
    _init();
  }

  Future<void> _init() async {
    // Avoid multiple initializations
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    await loadHistoryIndex();

    // If no active chat is loaded, or the loaded one is invalid, try loading the first available one
    if (_activeChatId == null || _chatSessions.indexWhere((s) => s.id == _activeChatId) == -1) {
       if (_chatSessions.isNotEmpty) {
         setActiveChatId(_chatSessions.first.id); // Select the most recent
       } else {
         // Optional: Automatically start a new chat if history is empty on init
         startNewChat();
       }
    }
    debugPrint("ChatHistoryService Initialized. Active Chat ID: $_activeChatId");
  }

  Future<void> loadHistoryIndex() async {
    _prefs ??= await SharedPreferences.getInstance(); // Ensure prefs is initialized

    final List<String>? chatIds = _prefs!.getStringList(prefsHistoryIndexKey);

    _chatSessions = []; // Clear current sessions before loading
    if (chatIds != null) {
      List<String> validIds = []; // Keep track of IDs that load successfully
      for (String id in chatIds) {
        final session = await loadChatSession(
          id,
        ); // loadChatSession handles its own errors
        if (session != null) {
          _chatSessions.add(session);
          validIds.add(id); // Add to valid list
        } else {
          debugPrint(
            "Warning: Chat ID $id data is missing or corrupt. It will be removed from index.",
          );
          // Optionally remove the bad data immediately
           await _prefs!.remove('$prefsHistoryPrefix$id');
        }
      }
      // Cleanup: Remove bad IDs from the index if any were found
      if (validIds.length != chatIds.length) {
        await _prefs!.setStringList(prefsHistoryIndexKey, validIds);
        debugPrint("Cleaned chat history index.");
      }
      // Sort by last modified descending (most recent first)
      _chatSessions.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    }

    // Load active chat ID after loading sessions
    _activeChatId = _prefs!.getString(prefsActiveChatIdKey);

    // Final check: ensure activeChatId still exists in the loaded sessions
    if (_activeChatId != null && !_chatSessions.any((s) => s.id == _activeChatId)) {
      debugPrint("Warning: Saved active chat ID '$_activeChatId' no longer exists in history. Clearing active ID.");
      _activeChatId = null;
      await _prefs!.remove(prefsActiveChatIdKey);
    }

    notifyListeners(); // Notify after loading everything
  }

  Future<ChatSessionItem?> loadChatSession(String id) async {
    _prefs ??= await SharedPreferences.getInstance();
    final String? sessionJson = _prefs!.getString('$prefsHistoryPrefix$id');
    if (sessionJson != null) {
      try {
        // The ChatSessionItem.fromJson handles its internal try-catch
        return ChatSessionItem.fromJson(jsonDecode(sessionJson));
      } catch (e, s) { // Catch outer decoding error
        debugPrint("Error decoding chat session $id: $e");
        debugPrint("Stack trace: $s");
        debugPrint("Corrupted JSON: $sessionJson");
        // Optionally remove the corrupted entry
         await _prefs!.remove('$prefsHistoryPrefix$id');
        return null;
      }
    }
    return null;
  }

  // Updates or adds a session and persists it
  Future<void> saveChatSession(ChatSessionItem session) async {
    _prefs ??= await SharedPreferences.getInstance();
    session.lastModified = DateTime.now(); // Update timestamp on save
    final String sessionJson = jsonEncode(session.toJson()); // Assumes session.toJson is safe
    await _prefs!.setString('$prefsHistoryPrefix${session.id}', sessionJson);

    // Ensure the session ID is in the index
    final List<String> chatIds = _prefs!.getStringList(prefsHistoryIndexKey) ?? [];
    if (!chatIds.contains(session.id)) {
      // Add new IDs to the beginning (making it the most recent in the index)
      chatIds.insert(0, session.id);
      await _prefs!.setStringList(prefsHistoryIndexKey, chatIds);
    }

    // Update the session in the local list or add it
    final index = _chatSessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _chatSessions[index] = session;
    } else {
       _chatSessions.insert(0, session); // Add new sessions to the beginning
    }
    // Re-sort after potential update affecting lastModified (already sorted after add)
    _chatSessions.sort((a, b) => b.lastModified.compareTo(a.lastModified));


    // If this saved session is the currently active one, ensure it's marked
    if (_activeChatId == session.id) {
        // No need to call setActiveChatId again if it's already active
    } else {
        // If saving implicitly makes it active (e.g., new chat), call setActive
         setActiveChatId(session.id); // Or handle activation logic elsewhere
    }


    notifyListeners(); // Notify after all updates
  }

  // Adds a message to an existing session and saves it
  Future<void> addMessageToSession(String sessionId, ChatMessage message) async {
    final session = _chatSessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw Exception("Session $sessionId not found")
    );
    
    // If it's an OpenAI message, ensure the role is preserved
    if (message.metadata?['openai'] == true) {
      session.messages.add(message);
    } else {
      // For non-OpenAI messages, create a new message preserving the content
      session.messages.add(ChatMessage(
        sender: message.sender,
        content: message.content,
        contentType: message.contentType,
        metadata: message.metadata,
        openAIRole: message.openAIRole,
      ));
    }
    
    await saveChatSession(session);
  }

   // Updates the title of an existing session
  Future<void> updateSessionTitle(String sessionId, String newTitle) async {
    final index = _chatSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      _chatSessions[index].title = newTitle;
      await saveChatSession(_chatSessions[index]); // Save updates timestamp
    } else {
       debugPrint("Warning: Cannot update title for non-existent session $sessionId");
    }
  }

  // Updates an existing message in a session
  Future<void> updateMessageInSession(String sessionId, String messageId, ChatMessage updatedMessage) async {
    final session = _chatSessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw Exception("Session $sessionId not found")
    );
    
    final messageIndex = session.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      session.messages[messageIndex] = updatedMessage;
      await saveChatSession(session);
      notifyListeners(); // Notify UI of the update
    } else {
      debugPrint("Warning: Cannot update non-existent message $messageId in session $sessionId");
    }
  }


  // Creates a new, empty chat session but DOES NOT save it until first message. Sets it active.
  ChatSessionItem startNewChat() {
    final newSession = ChatSessionItem(
      id: _uuid.v4(),
      title: 'New Chat', // Will be updated on first message
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      messages: [],
    );
    // Add visually to the list immediately (will be persisted on first save)
    _chatSessions.insert(0, newSession);
    // Set as active
    setActiveChatId(newSession.id); // This notifies listeners
    debugPrint("Started new chat session (not saved yet): ID = ${newSession.id}");
    return newSession; // Return the new session object
  }

  Future<void> deleteChatSession(String id) async {
    _prefs ??= await SharedPreferences.getInstance();
    // Remove from storage
    await _prefs!.remove('$prefsHistoryPrefix$id');

    // Remove from index
    final List<String> chatIds = _prefs!.getStringList(prefsHistoryIndexKey) ?? [];
    final bool removed = chatIds.remove(id);
    if (removed) await _prefs!.setStringList(prefsHistoryIndexKey, chatIds);

    // Remove from local list
    _chatSessions.removeWhere((session) => session.id == id);

    // If the deleted chat was active, select the next available or clear activeId
    if (_activeChatId == id) {
       if (_chatSessions.isNotEmpty){
          setActiveChatId(_chatSessions.first.id); // Select the most recent remaining
       } else {
         setActiveChatId(null); // No chats left
       }
    } else {
       notifyListeners(); // Notify even if active didn't change, as list did
    }

     debugPrint("Deleted Chat Session ID: $id");
  }

  // Helper to set the active chat ID - used when user selects from history or new chat starts
  void setActiveChatId(String? id) {
    // Prevent unnecessary updates and notifications
    if (_activeChatId == id) return;

    _activeChatId = id;
    // Save the active ID to SharedPreferences asynchronously
    if (id != null) {
      _prefs?.setString(prefsActiveChatIdKey, id);
    } else {
      _prefs?.remove(prefsActiveChatIdKey);
    }
    notifyListeners();
    debugPrint("Set active chat ID to: $id");
  }

  // Helper to get a session by ID without modifying state
  ChatSessionItem? getSessionById(String id) {
     try {
       return _chatSessions.firstWhere((s) => s.id == id);
     } catch (_) {
       return null;
     }
   }
}