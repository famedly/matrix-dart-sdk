class CloudflareMiniSdpMode {
  final String trackId;
  final String mid;

  CloudflareMiniSdpMode({
    required this.trackId,
    required this.mid,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CloudflareMiniSdpMode &&
        other.trackId == trackId &&
        other.mid == mid;
  }

  @override
  String toString() {
    return '$trackId:$mid';
  }

  @override
  int get hashCode => trackId.hashCode ^ mid.hashCode;
}
