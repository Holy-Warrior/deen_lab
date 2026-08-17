class QiblaDirection {
  const QiblaDirection({
    required this.latitude,
    required this.longitude,
    required this.direction,
  });

  final double latitude;
  final double longitude;
  final double direction;

  factory QiblaDirection.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;

    return QiblaDirection(
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      direction: (data['direction'] as num).toDouble(),
    );
  }
}
