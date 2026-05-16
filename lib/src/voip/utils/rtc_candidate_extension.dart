// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:webrtc_interface/webrtc_interface.dart';

extension RTCIceCandidateExt on RTCIceCandidate {
  bool get isValid =>
      sdpMLineIndex != null &&
      sdpMid != null &&
      candidate != null &&
      candidate!.isNotEmpty;
}
