import 'dart:async';

import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';

class ConnectionTester {
  Client client;
  WebRTCDelegate delegate;
  RTCPeerConnection? pc1, pc2;
  ConnectionTester(this.client, this.delegate);
  TurnServerCredentials? _turnServerCredentials;

  Future<bool> verifyTurnServer() async {
    final iceServers = await getIceServers();
    final configuration = <String, dynamic>{
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
      'iceCandidatePoolSize': 1,
      'iceTransportPolicy': 'relay'
    };
    pc1 = await delegate.createPeerConnection(configuration);
    pc2 = await delegate.createPeerConnection(configuration);

    pc1!.onIceCandidate = (candidate) {
      if (candidate.candidate!.contains('relay')) {
        pc2!.addCandidate(candidate);
      }
    };
    pc2!.onIceCandidate = (candidate) {
      if (candidate.candidate!.contains('relay')) {
        pc1!.addCandidate(candidate);
      }
    };

    await pc1!.createDataChannel('conn-tester', RTCDataChannelInit());

    final offer = await pc1!.createOffer();

    await pc2!.setRemoteDescription(offer);
    final answer = await pc2!.createAnswer();

    await pc1!.setLocalDescription(offer);
    await pc2!.setLocalDescription(answer);

    await pc1!.setRemoteDescription(answer);

    Future<void> dispose() async {
      await Future.wait([
        pc1!.close(),
        pc2!.close(),
      ]);
      await Future.wait([
        pc1!.dispose(),
        pc2!.dispose(),
      ]);
    }

    bool connected = false;
    try {
      await waitUntilAsync(() async {
        if (pc1!.connectionState ==
                RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
            pc2!.connectionState ==
                RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          connected = true;
          return true;
        }
        return false;
      });
    } catch (e, s) {
      Logs()
          .e('[VOIP] ConnectionTester Error while testing TURN server: ', e, s);
    }

    // ignore: unawaited_futures
    dispose();
    return connected;
  }

  Future<int> waitUntilAsync(Future<bool> Function() test,
      {final int maxIterations = 1000,
      final Duration step = const Duration(milliseconds: 10)}) async {
    int iterations = 0;
    for (; iterations < maxIterations; iterations++) {
      await Future.delayed(step);
      if (await test()) {
        break;
      }
    }
    if (iterations >= maxIterations) {
      throw TimeoutException(
          'Condition not reached within ${iterations * step.inMilliseconds}ms');
    }
    return iterations;
  }

  Future<List<Map<String, dynamic>>> getIceServers() async {
    if (_turnServerCredentials == null) {
      try {
        _turnServerCredentials = await client.getTurnServer();
      } catch (e) {
        Logs().v('[VOIP] getTurnServerCredentials error => ${e.toString()}');
      }
    }

    if (_turnServerCredentials == null) {
      return [];
    }

    return [
      {
        'username': _turnServerCredentials!.username,
        'credential': _turnServerCredentials!.password,
        'url': _turnServerCredentials!.uris[0]
      }
    ];
  }
}
