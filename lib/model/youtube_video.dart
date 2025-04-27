class YouTubeVideo {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final String? description;
  Duration? duration;
  final DateTime? publishedAt;

  // Añadir estos campos para el enlace de audio
  String? audioUrl;
  int? audioUrlTimestamp;

  YouTubeVideo({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    this.description,
    this.duration,
    this.publishedAt,
    this.audioUrl,
    this.audioUrlTimestamp,
  });

  // Actualizar método toJson para incluir el enlace de audio
  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'channelTitle': channelTitle,
      'thumbnailUrl': thumbnailUrl,
      'description': description,
      'durationSeconds': duration?.inSeconds,
      'publishedAt': publishedAt?.toIso8601String(),
      'audioUrl': audioUrl,
      'audioUrlTimestamp': audioUrlTimestamp,
    };
  }

  Map<String, dynamic> toMap(String playlistId) => {
    'videoId': videoId,
    'title': title,
    'channelTitle': channelTitle,
    'thumbnailUrl': thumbnailUrl,
    'description': description,
    'durationSeconds': duration?.inSeconds,
    'publishedAt': publishedAt?.toIso8601String(),
    'audioUrl': audioUrl,
    'audioUrlTimestamp': audioUrlTimestamp,
    'playlistId': playlistId,
  };

  factory YouTubeVideo.fromMap(Map<String, dynamic> map) => YouTubeVideo(
    videoId: map['videoId'] ?? '',
    title: map['title'] ?? '',
    channelTitle: map['channelTitle'] ?? '',
    thumbnailUrl: map['thumbnailUrl'] ?? '',
    description: map['description'],
    duration:
        map['durationSeconds'] != null
            ? Duration(seconds: map['durationSeconds'])
            : null,
    publishedAt:
        map['publishedAt'] != null
            ? DateTime.tryParse(map['publishedAt'])
            : null,
    audioUrl: map['audioUrl'],
    audioUrlTimestamp: map['audioUrlTimestamp'],
  );

  // Actualizar método fromJson para incluir el enlace de audio
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
      duration:
          json['durationSeconds'] != null
              ? Duration(seconds: json['durationSeconds'])
              : null,
      publishedAt:
          json['publishedAt'] != null
              ? DateTime.parse(json['publishedAt'])
              : null,
      audioUrl: json['audioUrl'],
      audioUrlTimestamp: json['audioUrlTimestamp'],
    );
  }

  // Método para comprobar si el enlace de audio ha expirado
  bool get isAudioUrlExpired {
    if (audioUrl == null || audioUrlTimestamp == null) return true;

    // Comprobar si el enlace tiene más de 1 hora
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - audioUrlTimestamp!;
    final oneHourInMs = 60 * 60 * 1000; // 1 hora en milisegundos

    return elapsed > oneHourInMs;
  }

  // Método para actualizar el enlace de audio
  YouTubeVideo copyWithAudioUrl(String url) {
    return YouTubeVideo(
      videoId: videoId,
      title: title,
      channelTitle: channelTitle,
      thumbnailUrl: thumbnailUrl,
      description: description,
      duration: duration,
      publishedAt: publishedAt,
      audioUrl: url,
      audioUrlTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
