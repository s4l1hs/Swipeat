class Profile {
  final String id;
  final String name;
  final int? age;
  final String? bio;
  final List<String> photos;
  final List<String> interests;

  Profile({
    required this.id,
    required this.name,
    this.age,
    this.bio,
    this.photos = const [],
    this.interests = const [],
  });

  Profile copyWith({
    String? id,
    String? name,
    int? age,
    String? bio,
    List<String>? photos,
    List<String>? interests,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      bio: bio ?? this.bio,
      photos: photos ?? this.photos,
      interests: interests ?? this.interests,
    );
  }
}
