import 'package:soundswarm/model/youtube_video.dart';

class PlaylistPlayerController {
  final List<YouTubeVideo> songs;
  int _currentIndex = 0;

  PlaylistPlayerController(this.songs);

  YouTubeVideo? get currentSong =>
      songs.isNotEmpty ? songs[_currentIndex] : null;

  bool get hasNext => _currentIndex < songs.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  void next() {
    if (hasNext) _currentIndex++;
  }

  void previous() {
    if (hasPrevious) _currentIndex--;
  }

  void playFirst() {
    _currentIndex = 0;
  }

  void playLast() {
    _currentIndex = songs.length - 1;
  }
}
