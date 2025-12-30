class MediaItem {
  final String url;
  final String type; // image | video
  final int order;

  MediaItem({
    required this.url,
    required this.type,
    required this.order,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type,
      'order': order,
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      url: map['url'],
      type: map['type'],
      order: map['order'],
    );
  }
}
