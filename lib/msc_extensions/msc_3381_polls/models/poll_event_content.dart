import 'package:collection/collection.dart';

class PollEventContent {
  final String mText;
  final PollStartContent pollStartContent;

  const PollEventContent({
    required this.mText,
    required this.pollStartContent,
  });
  static const String mTextJsonKey = 'org.matrix.msc1767.text';
  static const String startType = 'org.matrix.msc3381.poll.start';
  static const String responseType = 'org.matrix.msc3381.poll.response';
  static const String endType = 'org.matrix.msc3381.poll.end';

  factory PollEventContent.fromJson(Map<String, dynamic> json) =>
      PollEventContent(
        mText: json[mTextJsonKey],
        pollStartContent: PollStartContent.fromJson(json[startType]),
      );

  Map<String, dynamic> toJson() => {
        mTextJsonKey: mText,
        startType: pollStartContent.toJson(),
      };
}

class PollStartContent {
  final PollKind? kind;
  final int maxSelections;
  final PollQuestion question;
  final List<PollAnswer> answers;

  const PollStartContent({
    this.kind,
    required this.maxSelections,
    required this.question,
    required this.answers,
  });

  factory PollStartContent.fromJson(Map<String, dynamic> json) =>
      PollStartContent(
        kind: PollKind.values
            .singleWhereOrNull((kind) => kind.name == json['kind']),
        maxSelections: json['max_selections'],
        question: PollQuestion.fromJson(json['question']),
        answers: (json['answers'] as List)
            .map((i) => PollAnswer.fromJson(i))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        if (kind != null) 'kind': kind?.name,
        'max_selections': maxSelections,
        'question': question.toJson(),
        'answers': answers.map((i) => i.toJson()).toList(),
      };
}

class PollQuestion {
  final String mText;

  const PollQuestion({
    required this.mText,
  });

  factory PollQuestion.fromJson(Map<String, dynamic> json) => PollQuestion(
        mText: json[PollEventContent.mTextJsonKey] ?? json['body'],
      );

  Map<String, dynamic> toJson() => {
        PollEventContent.mTextJsonKey: mText,
        // Compatible with older Element versions
        'msgtype': 'm.text',
        'body': mText,
      };
}

class PollAnswer {
  final String id;
  final String mText;

  const PollAnswer({required this.id, required this.mText});

  factory PollAnswer.fromJson(Map<String, Object?> json) => PollAnswer(
        id: json['id'] as String,
        mText: json[PollEventContent.mTextJsonKey] as String,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        PollEventContent.mTextJsonKey: mText,
      };
}

enum PollKind {
  disclosed('org.matrix.msc3381.poll.disclosed'),
  undisclosed('org.matrix.msc3381.poll.undisclosed');

  const PollKind(this.name);

  final String name;
}
