class Avatar {
  final int id;
  final String avatarPath;

  Avatar({required this.id, required this.avatarPath});

  factory Avatar.fromJson(Map<String, dynamic> json) {
    return Avatar(id: json['id'], avatarPath: json['avatar']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'avatar': avatarPath};
  }
}
