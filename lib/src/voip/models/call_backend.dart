abstract class CallBackend {
  String type;

  CallBackend({required this.type});

  factory CallBackend.fromJson(Map<String, Object?> json) {
    final String type = json['type'] as String;
    if (type == 'mesh') {
      return MeshBackend(type: type);
    } else if (type == 'livekit') {
      return LiveKitBackend(
        livekitAlias: json['livekit_alias'] as String,
        livekitServiceUrl: json['livekit_service_url'] as String,
        type: type,
      );
    } else {
      throw ArgumentError('Invalid type: $type');
    }
  }

  Map<String, Object?> toJson();

  @override
  bool operator ==(Object other);
  @override
  int get hashCode;
}

class MeshBackend extends CallBackend {
  MeshBackend({super.type = 'mesh'});

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MeshBackend && type == other.type;
  @override
  int get hashCode => type.hashCode;
}

class LiveKitBackend extends CallBackend {
  final String livekitServiceUrl;
  final String livekitAlias;

  LiveKitBackend({
    required this.livekitServiceUrl,
    required this.livekitAlias,
    super.type = 'livekit',
  });

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type,
      'livekit_service_url': livekitServiceUrl,
      'livekit_alias': livekitAlias,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveKitBackend &&
          type == other.type &&
          livekitServiceUrl == other.livekitServiceUrl &&
          livekitAlias == other.livekitAlias;
  @override
  int get hashCode =>
      type.hashCode ^ livekitServiceUrl.hashCode ^ livekitAlias.hashCode;
}
