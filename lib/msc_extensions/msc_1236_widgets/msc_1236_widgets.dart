library msc_1236_widgets;

import 'package:matrix/matrix.dart';

export 'src/widget.dart';

extension MatrixWidgets on Room {
  /// Returns all present Widgets in the room.
  List<MatrixWidget> get widgets => {
        ...states['m.widget'] ?? states['im.vector.modular.widgets'] ?? {},
      }.values.expand((e) {
        try {
          return [MatrixWidget.fromJson(e.content, this)];
        } catch (_) {
          return <MatrixWidget>[];
        }
      }).toList();

  Future<String> addWidget(MatrixWidget widget) {
    final user = client.userID;
    final widgetId =
        widget.name!.toLowerCase().replaceAll(RegExp(r'\W'), '_') + '_' + user!;

    final json = widget.toJson();
    json['creatorUserId'] = user;
    json['id'] = widgetId;
    return client.setRoomStateWithKey(
      id,
      'im.vector.modular.widgets',
      widgetId,
      json,
    );
  }

  Future<String> deleteWidget(String widgetId) {
    return client.setRoomStateWithKey(
      id,
      'im.vector.modular.widgets',
      widgetId,
      {},
    );
  }
}
