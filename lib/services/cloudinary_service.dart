import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // Check these carefully!
  static const String cloudName = "dtcsadykn"; 
  static const String uploadPreset = "driver_setup"; 

  static Future<String?> uploadImage(File imageFile) async {
    try {
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
      
      final request = http.MultipartRequest("POST", url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        print("✅ Cloudinary Upload Success: ${jsonResponse['secure_url']}");
        return jsonResponse['secure_url']; 
      } else {
        // THIS WILL SHOW YOU THE EXACT ERROR IN CONSOLE
        print("❌ Cloudinary Error: $responseBody");
        return null;
      }
    } catch (e) {
      print("❌ Cloudinary Catch: $e");
      return null;
    }
  }
}