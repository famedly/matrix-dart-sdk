/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
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

class CallReplacesTarget {
  String? id;
  String? display_name;
  String? avatar_url;

  CallReplacesTarget({this.id, this.display_name, this.avatar_url});
  factory CallReplacesTarget.fromJson(Map<String, dynamic> json) =>
      CallReplacesTarget(
        id: json['id'].toString(),
        display_name: json['display_name'].toString(),
        avatar_url: json['avatar_url'].toString(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (display_name != null) 'display_name': display_name,
        if (avatar_url != null) 'avatar_url': avatar_url,
      };
}

/// MSC2747: VoIP call transfers
/// https://github.com/matrix-org/matrix-doc/pull/2747
class CallReplaces {
  String? replacement_id;
  CallReplacesTarget? target_user;
  String? create_call;
  String? await_call;
  String? target_room;

  CallReplaces({
    this.replacement_id,
    this.target_user,
    this.create_call,
    this.await_call,
    this.target_room,
  });
  factory CallReplaces.fromJson(Map<String, dynamic> json) => CallReplaces(
        replacement_id: json['replacement_id']?.toString(),
        create_call: json['create_call']?.toString(),
        await_call: json['await_call']?.toString(),
        target_room: json['target_room']?.toString(),
        target_user: CallReplacesTarget.fromJson(json['target_user']),
      );

  Map<String, Object> toJson() => {
        if (replacement_id != null) 'replacement_id': replacement_id!,
        if (target_user != null) 'target_user': target_user!.toJson(),
        if (create_call != null) 'create_call': create_call!,
        if (await_call != null) 'await_call': await_call!,
        if (target_room != null) 'target_room': target_room!,
      };
}

// TODO: Change to "sdp_stream_metadata" when MSC3077 is merged
const String sdpStreamMetadataKey = 'org.matrix.msc3077.sdp_stream_metadata';

/// https://github.com/matrix-org/matrix-doc/blob/dbkr/msc2747/proposals/2747-voip-call-transfer.md#capability-advertisment
/// https://github.com/matrix-org/matrix-doc/blob/dbkr/msc2746/proposals/2746-reliable-voip.md#add-dtmf
class CallCapabilities {
  bool transferee;
  bool dtmf;
  CallCapabilities({this.transferee = false, this.dtmf = false});
  factory CallCapabilities.fromJson(Map<String, dynamic> json) =>
      CallCapabilities(
        dtmf: json['m.call.dtmf'] as bool? ?? false,
        transferee: json['m.call.transferee'] as bool? ?? false,
      );
  Map<String, dynamic> toJson() => {
        'm.call.transferee': transferee,
        'm.call.dtmf': dtmf,
      };
}

/// MSC3077: Support for multi-stream VoIP
/// https://github.com/matrix-org/matrix-doc/pull/3077
///
/// MSC3291: Muting in VoIP calls
/// https://github.com/SimonBrandner/matrix-doc/blob/msc/muting/proposals/3291-muting.md
///
/// This MSC proposes adding an sdp_stream_metadata field
/// to the events containing a session description i.e.:
/// m.call.invite, m.call.answer, m.call.negotiate
///
class SDPStreamPurpose {
  // SDPStreamMetadataPurpose
  String purpose;
  bool audio_muted;
  bool video_muted;

  SDPStreamPurpose({
    required this.purpose,
    this.audio_muted = false,
    this.video_muted = false,
  });
  factory SDPStreamPurpose.fromJson(Map<String, dynamic> json) =>
      SDPStreamPurpose(
        audio_muted: json['audio_muted'] as bool? ?? false,
        video_muted: json['video_muted'] as bool? ?? false,
        purpose: json['purpose'] as String,
      );

  Map<String, dynamic> toJson() => {
        'purpose': purpose,
        'audio_muted': audio_muted,
        'video_muted': video_muted,
      };
}

class SDPStreamMetadataPurpose {
  static String Usermedia = 'm.usermedia';
  static String Screenshare = 'm.screenshare';
}

class SDPStreamMetadata {
  Map<String, SDPStreamPurpose> sdpStreamMetadatas;
  SDPStreamMetadata(this.sdpStreamMetadatas);

  factory SDPStreamMetadata.fromJson(Map<String, dynamic> json) =>
      SDPStreamMetadata(
        json.map(
          (key, value) => MapEntry(key, SDPStreamPurpose.fromJson(value)),
        ),
      );
  Map<String, dynamic> toJson() =>
      sdpStreamMetadatas.map((key, value) => MapEntry(key, value.toJson()));
}

/// MSC3086: Asserted identity on VoIP calls
/// https://github.com/matrix-org/matrix-doc/pull/3086
class AssertedIdentity {
  String? id;
  String? displayName;
  String? avatarUrl;
  AssertedIdentity({this.id, this.displayName, this.avatarUrl});
  factory AssertedIdentity.fromJson(Map<String, dynamic> json) =>
      AssertedIdentity(
        displayName: json['display_name'] as String?,
        id: json['id'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );
  Map<String, dynamic> toJson() => {
        if (displayName != null) 'display_name': displayName,
        if (id != null) 'id': id,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };
}
