class OpenIdCredentials {
  String accessToken;
  String tokenType;
  String matrixServerName;
  num expiresIn;

  OpenIdCredentials.fromJson(Map<String, dynamic> json) {
    accessToken = json['access_token'];
    tokenType = json['token_type'];
    matrixServerName = json['matrix_server_name'];
    expiresIn = json['expires_in'];
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    final data = map;
    data['access_token'] = accessToken;
    data['token_type'] = tokenType;
    data['matrix_server_name'] = matrixServerName;
    data['expires_in'] = expiresIn;
    return data;
  }
}
