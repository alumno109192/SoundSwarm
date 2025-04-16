import 'package:soundswarm/model/youtube_video.dart';

class Playlist {
  String id;
  String name;
  String? description;
  String? thumbnailUrl;
  DateTime createdAt;
  List<YouTubeVideo> songs;


  // Getter formal para songs
  List<YouTubeVideo> get getSongs => songs;
  
  // Setter formal para songs
  set setSongs(List<YouTubeVideo> newSongs) => songs = newSongs;


  Playlist({
    required this.id,
    required this.name,
    this.description,
    this.thumbnailUrl,
    required this.createdAt,
    required this.songs,
  });

  // Convertir a/desde JSON para almacenamiento
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'thumbnailUrl': thumbnailUrl,
    'createdAt': createdAt.toIso8601String(),
    'songs': songs.map((song) => song.toJson()).toList(),
  };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      thumbnailUrl: json['thumbnailUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      songs: (json['songs'] as List)
          .map((songJson) => YouTubeVideo.fromJson(songJson))
          .toList(),
    );
  }

  // Crear nueva playlist vacía
  factory Playlist.create(String name, {String? description}) {
    return Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
      songs: [],
    );
  }

  // Métodos para manipular canciones
  void addSong(YouTubeVideo song) {
    if (!songs.any((s) => s.videoId == song.videoId)) {
      songs.add(song);
    }
  }

  void removeSong(String videoId) {
    songs.removeWhere((song) => song.videoId == videoId);
  }
}