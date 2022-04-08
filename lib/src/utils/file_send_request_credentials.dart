/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

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
