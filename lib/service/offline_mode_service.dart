import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soundswarm/model/youtube_video.dart';
import 'package:soundswarm/service/recent_songs_service.dart';
import 'dart:io';
import 'dart:convert';

class OfflineModeService {
  // Guardar resultados de búsqueda reciente
  static Future<void> saveRecentSearch(
    String query,
    List<YouTubeVideo> results,
  ) async {
    await RecentSongsService.saveRecentSearch(query, results);
  }

  // Obtener resultados de búsqueda
  static Future<List<YouTubeVideo>> getSearchResults(String query) async {
    // Buscar resultados exactos
    final exactResults = await RecentSongsService.getSearchResults(query);

    if (exactResults.isNotEmpty) {
      return exactResults;
    }

    // Si no hay resultados exactos, buscar coincidencias parciales
    final allRecent = await RecentSongsService.getRecentSongs();
    final queryLower = query.toLowerCase();

    // Filtrar por título o canal
    final matchingResults =
        allRecent.where((video) {
          return video.title.toLowerCase().contains(queryLower) ||
              video.channelTitle.toLowerCase().contains(queryLower);
        }).toList();

    return matchingResults;
  }

  // Obtener canciones reproducidas recientemente
  static Future<List<YouTubeVideo>> getRecentSongs() async {
    return await RecentSongsService.getRecentSongs();
  }

  // Guardado de canciones favoritas para offline
  static Future<void> saveOfflineSongs(List<YouTubeVideo> songs) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/offline_songs.json');

    final List<Map<String, dynamic>> songsData =
        songs
            .map(
              (song) => {
                'videoId': song.videoId,
                'title': song.title,
                'thumbnailUrl': song.thumbnailUrl,
                'channelTitle': song.channelTitle,
                'description': song.description,
              },
            )
            .toList();

    await file.writeAsString(jsonEncode(songsData));
  }

  static Future<List<YouTubeVideo>> getOfflineSongs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_songs.json');

      if (!file.existsSync()) {
        return [];
      }

      final data = await file.readAsString();
      final List<dynamic> songsData = jsonDecode(data);

      return _convertToYouTubeVideos(songsData);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading offline songs: $e');
      }
      return [];
    }
  }

  // Utilidad para convertir datos JSON a objetos YouTubeVideo
  static List<YouTubeVideo> _convertToYouTubeVideos(List<dynamic> data) {
    return data
        .map(
          (item) => YouTubeVideo(
            videoId: item['videoId'],
            title: item['title'],
            thumbnailUrl: item['thumbnailUrl'],
            channelTitle: item['channelTitle'],
            description: item['description'],
          ),
        )
        .toList();
  }
}
