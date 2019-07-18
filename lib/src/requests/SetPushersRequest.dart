/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedly.  If not, see <http://www.gnu.org/licenses/>.
 */
import 'package:flutter/widgets.dart';
import 'package:json_annotation/json_annotation.dart';

part 'SetPushersRequest.g.dart';

@JsonSerializable(explicitToJson: true, nullable: false, includeIfNull: false)
class SetPushersRequest {
  // Required Keys
  @JsonKey(nullable: false)
  String lang;
  @JsonKey(nullable: false)
  String device_display_name;
  @JsonKey(nullable: false)
  String app_display_name;
  @JsonKey(nullable: false)
  String app_id;
  @JsonKey(nullable: false)
  String kind;
  @JsonKey(nullable: false)
  String pushkey;
  @JsonKey(nullable: false)
  PusherData data;

  // Optional keys
  String profile_tag;
  bool append;

  SetPushersRequest({
    @required this.lang,
    @required this.device_display_name,
    @required this.app_display_name,
    @required this.app_id,
    @required this.kind,
    @required this.pushkey,
    @required this.data,
    this.profile_tag,
    this.append,
  });

  factory SetPushersRequest.fromJson(Map<String, dynamic> json) =>
      _$SetPushersRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SetPushersRequestToJson(this);
}

@JsonSerializable(explicitToJson: true, nullable: false, includeIfNull: false)
class PusherData {
  String url;
  String format;

  PusherData({
    this.url,
    this.format,
  });

  factory PusherData.fromJson(Map<String, dynamic> json) =>
      _$PusherDataFromJson(json);

  Map<String, dynamic> toJson() => _$PusherDataToJson(this);
}
