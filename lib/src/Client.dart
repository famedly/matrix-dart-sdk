import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:flutter/material.dart';
import 'responses/ErrorResponse.dart';
import 'Connection.dart';
import 'Store.dart';

/// Represents a Matrix connection to communicate with a
/// [Matrix](https://matrix.org) homeserver and is the entry point for this
/// SDK.
class Client {

  /// Handles the connection for this client.
  Connection connection;

  /// Optional persistent store for all data.
  Store store;

  Client(this.clientName) {
    connection = Connection(this);

    if (this.clientName != "testclient")
      store = Store(this);
    connection.onLoginStateChanged.stream.listen((loginState) {
      print("LoginState: ${loginState.toString()}");
    });
  }

  /// The required name for this client.
  final String clientName;

  /// The homeserver this client is communicating with.
  String homeserver;

  /// The Matrix ID of the current logged user.
  String userID;

  /// This is the access token for the matrix client. When it is undefined, then
  /// the user needs to sign in first.
  String accessToken;

  /// This points to the position in the synchronization history.
  String prevBatch;

  /// The device ID is an unique identifier for this device.
  String deviceID;

  /// The device name is a human readable identifier for this device.
  String deviceName;

  /// Which version of the matrix specification does this server support?
  List<String> matrixVersions;

  /// Wheither the server supports lazy load members.
  bool lazyLoadMembers = false;

  /// Returns the current login state.
  bool isLogged() => accessToken != null;

  /// Checks the supported versions of the Matrix protocol and the supported
  /// login types. Returns false if the server is not compatible with the
  /// client. Automatically sets [matrixVersions] and [lazyLoadMembers].
  Future<bool> checkServer(serverUrl) async {
    homeserver = serverUrl;

    final versionResp =
    await connection.jsonRequest(type: "GET", action: "/client/versions");
    if (versionResp is ErrorResponse) {
      connection.onError.add(ErrorResponse(errcode: "NO_RESPONSE", error: ""));
      return false;
    }

    final List<String> versions = List<String>.from(versionResp["versions"]);

    if (versions == null) {
      connection.onError.add(ErrorResponse(errcode: "NO_RESPONSE", error: ""));
      return false;
    }

    for (int i = 0; i < versions.length; i++) {
      if (versions[i] == "r0.4.0")
        break;
      else if (i == versions.length - 1) {
        connection.onError.add(ErrorResponse(errcode: "NO_SUPPORT", error: ""));
        return false;
      }
    }

    matrixVersions = versions;

    if (versionResp.containsKey("unstable_features") &&
        versionResp["unstable_features"].containsKey("m.lazy_load_members")) {
      lazyLoadMembers = versionResp["unstable_features"]["m.lazy_load_members"]
          ? true
          : false;
    }

    final loginResp =
    await connection.jsonRequest(type: "GET", action: "/client/r0/login");
    if (loginResp is ErrorResponse) {
      connection.onError.add(loginResp);
      return false;
    }

    final List<dynamic> flows = loginResp["flows"];

    for (int i = 0; i < flows.length; i++) {
      if (flows[i].containsKey("type") &&
          flows[i]["type"] == "m.login.password")
        break;
      else if (i == flows.length - 1) {
        connection.onError.add(ErrorResponse(errcode: "NO_SUPPORT", error: ""));
        return false;
      }
    }

    return true;
  }

  /// Handles the login and allows the client to call all APIs which require
  /// authentication. Returns false if the login was not successful.
  Future<bool> login(String username, String password) async {

    final loginResp =
    await connection.jsonRequest(type: "POST", action: "/client/r0/login", data: {
      "type": "m.login.password",
      "user": username,
      "identifier": {
        "type": "m.id.user",
        "user": username,
      },
      "password": password,
      "initial_device_display_name": "Famedly Talk"
    });

    if (loginResp is ErrorResponse) {
      connection.onError.add(loginResp);
      return false;
    }

    final userID = loginResp["user_id"];
    final accessToken = loginResp["access_token"];
    if (userID == null || accessToken == null) {
      connection.onError.add(ErrorResponse(errcode: "NO_SUPPORT", error: ""));
    }

    await connection.connect(
        newToken: accessToken,
        newUserID: userID,
        newHomeserver: homeserver,
        newDeviceName: "",
        newDeviceID: "",
        newMatrixVersions: matrixVersions,
        newLazyLoadMembers: lazyLoadMembers);
    return true;
  }

  /// Sends a logout command to the homeserver and clears all local data,
  /// including all persistent data from the store.
  Future<void> logout() async {
    final dynamic resp =
    await connection.jsonRequest(type: "POST", action: "/client/r0/logout/all");
    if (resp == null) return;

    await connection.clear();
  }

}
