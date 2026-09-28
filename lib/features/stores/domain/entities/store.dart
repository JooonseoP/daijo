class Store {
  const Store({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is Store &&
      other.id == id &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(id, name, latitude, longitude, radius);
}
