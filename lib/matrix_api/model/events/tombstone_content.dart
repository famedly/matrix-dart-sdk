import 'package:famedlysdk/matrix_api/model/basic_event.dart';
import '../../utils/try_get_map_extension.dart';

extension TombstoneContentBasicEventExtension on BasicEvent {
  TombstoneContent get parsedTombstoneContent =>
      TombstoneContent.fromJson(content);
}

class TombstoneContent {
  String body;
  String replacementRoom;

  TombstoneContent.fromJson(Map<String, dynamic> json)
      : body = json.tryGet<String>('body', ''),
        replacementRoom = json.tryGet<String>('replacement_room', '');

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['body'] = body;
    data['replacement_room'] = replacementRoom;
    return data;
  }
}
