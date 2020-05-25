class WellKnownInformations {
  MHomeserver mHomeserver;
  MHomeserver mIdentityServer;
  Map<String, dynamic> content;

  WellKnownInformations.fromJson(Map<String, dynamic> json) {
    content = json;
    mHomeserver = json['m.homeserver'] != null
        ? MHomeserver.fromJson(json['m.homeserver'])
        : null;
    mIdentityServer = json['m.identity_server'] != null
        ? MHomeserver.fromJson(json['m.identity_server'])
        : null;
  }
}

class MHomeserver {
  String baseUrl;

  MHomeserver.fromJson(Map<String, dynamic> json) {
    baseUrl = json['base_url'];
  }
}
