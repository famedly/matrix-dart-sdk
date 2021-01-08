import '../basic_event.dart';
import '../../utils/try_get_map_extension.dart';
import 'room_key_content.dart';

extension ForwardedRoomKeyContentBasicEventExtension on BasicEvent {
  ForwardedRoomKeyContent get parsedForwardedRoomKeyContent =>
      ForwardedRoomKeyContent.fromJson(content);
}

class ForwardedRoomKeyContent extends RoomKeyContent {
  String senderKey;
  String senderClaimedEd25519Key;
  List<String> forwardingCurve25519KeyChain;
  ForwardedRoomKeyContent.fromJson(Map<String, dynamic> json)
      : senderKey = json.tryGet<String>('sender_key', ''),
        senderClaimedEd25519Key =
            json.tryGet<String>('sender_claimed_ed25519_key', ''),
        forwardingCurve25519KeyChain =
            json.tryGetList<String>('forwarding_curve25519_key_chain', []),
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['sender_key'] = senderKey;
    data['sender_claimed_ed25519_key'] = senderClaimedEd25519Key;
    data['forwarding_curve25519_key_chain'] = forwardingCurve25519KeyChain;

    return data;
  }
}
