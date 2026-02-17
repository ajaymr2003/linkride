import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _key = 'ride_search_history';

  // --- SAVE A SEARCH ---
  static Future<void> addSearch({
    required Map<String, dynamic> source,
    required Map<String, dynamic> dest,
    required DateTime date,
    required int passengers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Get existing list
    List<String> history = prefs.getStringList(_key) ?? [];

    // 2. Create new item map
    Map<String, dynamic> newItem = {
      'source': source,
      'destination': dest,
      'passengers': passengers,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // 3. Encode to JSON String
    String jsonString = json.encode(newItem);

    // 4. Remove duplicates (if exact same route exists, remove old one to push new to top)
    history.removeWhere((item) {
      final decoded = json.decode(item);
      return decoded['source']['name'] == source['name'] && 
             decoded['destination']['name'] == dest['name'];
    });

    // 5. Add to top
    history.insert(0, jsonString);

    // 6. Limit to 5 items
    if (history.length > 5) {
      history = history.sublist(0, 5);
    }

    // 7. Save
    await prefs.setStringList(_key, history);
  }

  // --- GET HISTORY ---
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_key) ?? [];

    return history.map((item) => json.decode(item) as Map<String, dynamic>).toList();
  }

  // --- CLEAR HISTORY ---
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}