class YouTubeVideo {
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final String videoId;

  YouTubeVideo({
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.videoId,
  });

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    return YouTubeVideo(
      title: snippet['title'],
      channelTitle: snippet['channelTitle'],
      thumbnailUrl: snippet['thumbnails']['default']['url'],
      videoId: json['id']['videoId'], // Extraer el ID del video
    );
  }
}