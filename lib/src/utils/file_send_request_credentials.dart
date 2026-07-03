// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class FileSendRequestCredentials {
  final String? inReplyTo;
  final String? editEventId;
  final int? shrinkImageMaxDimension;
  final Map<String, dynamic>? extraContent;

  const FileSendRequestCredentials({
    this.inReplyTo,
    this.editEventId,
    this.shrinkImageMaxDimension,
    this.extraContent,
  });

  factory FileSendRequestCredentials.fromJson(Map<String, dynamic> json) =>
      FileSendRequestCredentials(
        inReplyTo: json['in_reply_to'],
        editEventId: json['edit_event_id'],
        shrinkImageMaxDimension: json['shrink_image_max_dimension'],
        extraContent: json['extra_content'],
      );

  Map<String, dynamic> toJson() => {
    if (inReplyTo != null) 'in_reply_to': inReplyTo,
    if (editEventId != null) 'edit_event_id': editEventId,
    if (shrinkImageMaxDimension != null)
      'shrink_image_max_dimension': shrinkImageMaxDimension,
    if (extraContent != null) 'extra_content': extraContent,
  };
}
