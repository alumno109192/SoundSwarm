class YouTubeVideo {
  final String videoId;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String channelTitle;
  final String publishedAt;

  YouTubeVideo({
    required this.videoId,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.publishedAt,
  });

  // Método toJson correcto (cambiar de factory a método de instancia)
  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'title': title,
    'description': description,
    'thumbnailUrl': thumbnailUrl,
    'channelTitle': channelTitle,
    'publishedAt': publishedAt,
  };

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    // Obtener el ID del video de forma segura
    final String videoId = json['id']?['videoId'] ?? '';
    
    // Acceder al snippet de forma segura
    final snippet = json['snippet'] as Map<String, dynamic>?;
    
    if (snippet == null) {
      // Si el snippet es nulo, crear un objeto con valores predeterminados
      return YouTubeVideo(
        videoId: videoId,
        title: 'Sin título',
        description: '',
        thumbnailUrl: '',
        channelTitle: '',
        publishedAt: '',
      );
    }
    
    // Obtener la URL de la miniatura más grande disponible de forma segura
    final thumbnails = snippet['thumbnails'] as Map<String, dynamic>?;
    String thumbnailUrl = '';
    
    if (thumbnails != null) {
      // Intentar obtener miniaturas en orden de preferencia: high, medium, default
      if (thumbnails['high'] != null) {
        thumbnailUrl = thumbnails['high']['url'] ?? '';
      } else if (thumbnails['medium'] != null) {
        thumbnailUrl = thumbnails['medium']['url'] ?? '';
      } else if (thumbnails['default'] != null) {
        thumbnailUrl = thumbnails['default']['url'] ?? '';
      }
    }
    
    return YouTubeVideo(
      videoId: videoId,
      title: snippet['title'] ?? 'Sin título',
      description: snippet['description'] ?? '',
      thumbnailUrl: thumbnailUrl,
      channelTitle: snippet['channelTitle'] ?? '',
      publishedAt: snippet['publishedAt'] ?? '',
    );
  }
}