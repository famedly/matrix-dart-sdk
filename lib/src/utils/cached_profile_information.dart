import 'package:matrix/matrix_api_lite.dart';

class CachedProfileInformation extends ProfileInformation {
  final bool outdated;
  final DateTime updated;

  CachedProfileInformation.fromProfile(
    ProfileInformation profile, {
    required this.outdated,
    required this.updated,
  }) : super(
          avatarUrl: profile.avatarUrl,
          displayname: profile.displayname,
        );

  factory CachedProfileInformation.fromJson(Map<String, Object?> json) =>
      CachedProfileInformation.fromProfile(
        ProfileInformation.fromJson(json),
        outdated: json['outdated'] as bool,
        updated: DateTime.fromMillisecondsSinceEpoch(json['updated'] as int),
      );

  @override
  Map<String, Object?> toJson() => {
        ...super.toJson(),
        'outdated': outdated,
        'updated': updated.millisecondsSinceEpoch,
      };
}
