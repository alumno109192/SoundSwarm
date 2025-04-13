import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:soundswarm/model/youtube_video.dart';

class YouTubeApiService {
  final String apiKey = 'AIzaSyCOJ6QuVNRH_cJ5_PNrNUF8St9XMJmBHL4';
  final String baseUrl = 'https://www.googleapis.com/youtube/v3/search';

  Future<List<YouTubeVideo>> searchVideos(String query) async {
    final url = Uri.parse('$baseUrl?part=snippet&type=video&q=$query&key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List items = data['items'];
      return items.map((item) => YouTubeVideo.fromJson(item)).toList();
    } else {
      throw Exception('Error al buscar en YouTube: ${response.reasonPhrase}');
    }
  }
}