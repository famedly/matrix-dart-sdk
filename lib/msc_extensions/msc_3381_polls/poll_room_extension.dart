import 'package:matrix/matrix.dart';
import 'package:matrix/msc_extensions/msc_3381_polls/models/poll_event_content.dart';

extension PollRoomExtension on Room {
  static const String mTextJsonKey = 'org.matrix.msc1767.text';
  static const String startType = 'org.matrix.msc3381.poll.start';

  Future<String?> startPoll({
    required String question,
    required List<PollAnswer> answers,
    String? body,
    PollKind kind = PollKind.undisclosed,
    int maxSelections = 1,
    String? txid,
  }) async {
    if (answers.length > 20) {
      throw Exception('Client must not set more than 20 answers in a poll');
    }

    if (body == null) {
      body = question;
      for (var i = 0; i < answers.length; i++) {
        body = '$body\n$i. ${answers[i].mText}';
      }
    }

    final newPollEvent = PollEventContent(
      mText: body!,
      pollStartContent: PollStartContent(
        kind: kind,
        maxSelections: maxSelections,
        question: PollQuestion(mText: question),
        answers: answers,
      ),
    );

    return sendEvent(
      newPollEvent.toJson(),
      type: startType,
      txid: txid,
    );
  }
}
