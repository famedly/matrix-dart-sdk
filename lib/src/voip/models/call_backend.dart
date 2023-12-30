abstract class CallBackend {
  String type;

  CallBackend({required this.type});

  factory CallBackend.fromJson(Map<String, Object?> json) {
    final String type = json['type'] as String;
    if (type == 'mesh') {
      return MeshBackend.fromJson(json);
    } else if (type == 'livekit') {
      return LiveKit.fromJson(json);
    } else {
      throw ArgumentError('Invalid type: $type');
    }
  }

  Map<String, Object?> toJson();
}

class MeshBackend implements CallBackend {
  @override
  String type = 'mesh';

  MeshBackend.fromJson(Map<String, Object?> json)
      : type = json['type'] as String;

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type,
    };
  }
}

class LiveKit implements CallBackend {
  @override
  String type = 'livekit';

  final String livekitServiceUrl;
  final String livekitAlias;

  LiveKit.fromJson(Map<String, Object?> json)
      : type = json['type'] as String,
        livekitServiceUrl = json['livekit_service_url'] as String,
        livekitAlias = json['livekit_alias'] as String;

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type,
    };
  }
}
