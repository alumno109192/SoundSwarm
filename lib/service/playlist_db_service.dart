import 'package:soundswarm/model/playlist.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../model/youtube_video.dart';

class PlaylistDbService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'playlists.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE songs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            videoId TEXT,
            title TEXT,
            thumbnailUrl TEXT,
            audioUrl TEXT,
            playlistId TEXT
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<Database> _getDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'soundswarm.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS songs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          videoId TEXT,
          title TEXT,
          channelTitle TEXT,
          thumbnailUrl TEXT,
          description TEXT,
          durationSeconds INTEGER,
          publishedAt TEXT,
          audioUrl TEXT,
          audioUrlTimestamp INTEGER,
          playlistId TEXT
        )
      ''');
      },
    );
  }

  static Future<void> addSongToPlaylist(
    String playlistId,
    YouTubeVideo song,
  ) async {
    final db = await database;
    await db.insert(
      'songs',
      song.toMap(playlistId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<YouTubeVideo>> getSongsFromPlaylist(
    String playlistId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'songs',
      where: 'playlistId = ?',
      whereArgs: [playlistId],
    );
    return maps.map((map) => YouTubeVideo.fromMap(map)).toList();
  }

  static Future<void> removeSongFromPlaylist(
    String playlistId,
    String videoId,
  ) async {
    final db = await database;
    await db.delete(
      'songs',
      where: 'playlistId = ? AND videoId = ?',
      whereArgs: [playlistId, videoId],
    );
  }

  static Future<void> saveSongToSqlite(
    String playlistId,
    YouTubeVideo song,
  ) async {
    final db = await _getDatabase();
    await db.insert(
      'songs',
      song.toMap(playlistId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<YouTubeVideo>> getSongsFromDatabase(
    String playlistId,
  ) async {
    final db = await _getDatabase();
    final maps = await db.query(
      'songs',
      where: 'playlistId = ?',
      whereArgs: [playlistId],
    );
    return maps.map((map) => YouTubeVideo.fromMap(map)).toList();
  }

  static Future<void> savePlaylistsToDatabase(List<Playlist> playlists) async {
    final db = await _getDatabase();

    // Borra todas las canciones existentes (opcional, para evitar duplicados)
    await db.delete('songs');

    // Inserta todas las canciones de todas las playlists
    for (final playlist in playlists) {
      for (final song in playlist.songs) {
        await db.insert(
          'songs',
          song.toMap(playlist.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }
}
