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

/// Matrix SDK written in pure Dart.
library matrix;

export 'matrix_api_lite.dart';

export 'fake_matrix_api.dart' show FakeMatrixApi;

export 'src/client.dart';
export 'src/database/database_api.dart';
export 'src/database/hive_database.dart';
export 'src/database/matrix_sdk_database.dart';
export 'src/database/hive_collections_database.dart';
export 'src/database/sqflite_encryption_helper.dart';
export 'src/event.dart';
export 'src/presence.dart';
export 'src/event_status.dart';
export 'src/voip/call_session.dart';
export 'src/voip/group_call_session.dart';
export 'src/voip/voip.dart';
export 'src/voip/backend/livekit_backend.dart';
export 'src/voip/backend/call_backend_model.dart';
export 'src/voip/backend/mesh_backend.dart';
export 'src/voip/models/call_events.dart';
export 'src/voip/models/webrtc_delegate.dart';
export 'src/voip/models/call_participant.dart';
export 'src/voip/models/key_provider.dart';
export 'src/voip/models/matrixrtc_call_event.dart';
export 'src/voip/utils/conn_tester.dart';
export 'src/voip/utils/voip_constants.dart';
export 'src/voip/utils/rtc_candidate_extension.dart';
export 'src/voip/utils/famedly_call_extension.dart';
export 'src/voip/utils/types.dart';
export 'src/voip/utils/wrapped_media_stream.dart';
export 'src/room.dart';
export 'src/timeline.dart';
export 'src/user.dart';
export 'src/utils/cached_profile_information.dart';
export 'src/utils/commands_extension.dart';
export 'src/utils/crypto/encrypted_file.dart';
export 'src/utils/device_keys_list.dart';
export 'src/utils/event_update.dart';
export 'src/utils/http_timeout.dart';
export 'src/utils/image_pack_extension.dart';
export 'src/utils/matrix_default_localizations.dart';
export 'src/utils/matrix_file.dart';
export 'src/utils/matrix_id_string_extension.dart';
export 'src/utils/matrix_localizations.dart';
export 'src/utils/native_implementations.dart';
export 'src/utils/room_enums.dart';
export 'src/utils/room_member_change_type.dart';
export 'src/utils/push_notification.dart';
export 'src/utils/pushrule_evaluator.dart';
export 'src/models/receipts.dart';
export 'src/utils/sync_update_extension.dart';
export 'src/utils/to_device_event.dart';
export 'src/utils/uia_request.dart';
export 'src/utils/uri_extension.dart';

export 'msc_extensions/extension_recent_emoji/recent_emoji.dart';
export 'msc_extensions/msc_3935_cute_events/msc_3935_cute_events.dart';
export 'msc_extensions/msc_1236_widgets/msc_1236_widgets.dart';
export 'msc_extensions/msc_2835_uia_login/msc_2835_uia_login.dart';
export 'msc_extensions/msc_3814_dehydrated_devices/msc_3814_dehydrated_devices.dart';

export 'src/utils/web_worker/web_worker_stub.dart'
    if (dart.library.html) 'src/utils/web_worker/web_worker.dart';

export 'src/utils/web_worker/native_implementations_web_worker_stub.dart'
    if (dart.library.html) 'src/utils/web_worker/native_implementations_web_worker.dart';
