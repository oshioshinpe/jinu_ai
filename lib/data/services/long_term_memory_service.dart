import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/ai_models.dart';

const prefsLtmKey = 'long_term_memory';

class LongTermMemoryService with ChangeNotifier {
  SharedPreferences? _prefs;
  List<MemoryItem> _memoryItems = [];
  final _uuid = const Uuid();

  List<MemoryItem> get memoryItems => _memoryItems;

  LongTermMemoryService() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadMemory();
  }

  Future<void> loadMemory() async {
    final jsonS = _prefs!.getString(prefsLtmKey);
    if (jsonS != null && jsonS.isNotEmpty) {
      try {
        final List<dynamic> arr = json.decode(jsonS);
        _memoryItems = arr
            .cast<Map<String, dynamic>>()
            .map((j) => MemoryItem.fromJson(j))
            .toList();
        _memoryItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } catch (e, s) {
        if (kDebugMode) {
          print("LTM load error: $e\n$s");
        }
        _memoryItems = [];
        await _prefs!.remove(prefsLtmKey);
      }
    }
    notifyListeners();
  }

  Future<void> _saveMemory() async {
    _memoryItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final jsonS = json.encode(_memoryItems.map((i) => i.toJson()).toList());
    await _prefs!.setString(prefsLtmKey, jsonS);
  }

  Future<Map<String, Object?>> saveMemoryItem(
      String key, String content) async {
    final trimmedKey = key.trim();
    final trimmedContent = content.trim();
    if (trimmedKey.isEmpty || trimmedContent.isEmpty) {
      return {'status': 'Error', 'message': 'Key and content required'};
    }
    final idx = _memoryItems
        .indexWhere((i) => i.key.toLowerCase() == trimmedKey.toLowerCase());
    String msg;
    if (idx >= 0) {
      _memoryItems[idx].content = trimmedContent;
      _memoryItems[idx].timestamp = DateTime.now();
      msg = "Updated memory '$trimmedKey'";
    } else {
      _memoryItems.add(MemoryItem(
          id: _uuid.v4(),
          key: trimmedKey,
          content: trimmedContent,
          timestamp: DateTime.now()));
      msg = "Saved new memory '$trimmedKey'";
    }
    await _saveMemory();
    notifyListeners();
    return {'status': 'Success', 'message': msg};
  }

  Map<String, Object?> retrieveMemoryItems(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return {'status': 'Error', 'message': 'Empty query'};
    final found = _memoryItems.where((i) {
      return i.key.toLowerCase().contains(q) ||
          i.content.toLowerCase().contains(q);
    }).toList();
    if (found.isEmpty) {
      return {'status': 'Success', 'message': "No memory items for '$query'"};
    }
    found.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final sb = StringBuffer();
    for (var i = 0; i < found.length; i++) {
      final it = found[i];
      sb.writeln("${i + 1}. ${it.key}: ${it.content} (${it.timestamp})");
    }
    return {'status': 'Success', 'message': sb.toString()};
  }

  Future<void> deleteMemoryItemById(String id) async {
    _memoryItems.removeWhere((i) => i.id == id);
    await _saveMemory();
    notifyListeners();
  }
}