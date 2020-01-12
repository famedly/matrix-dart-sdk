class OpenIdCredentials {
  String accessToken;
  String tokenType;
  String matrixServerName;
  int expiresIn;

  OpenIdCredentials(
      {this.accessToken,
      this.tokenType,
      this.matrixServerName,
      this.expiresIn});

  OpenIdCredentials.fromJson(Map<String, dynamic> json) {
    accessToken = json['access_token'];
    tokenType = json['token_type'];
    matrixServerName = json['matrix_server_name'];
    expiresIn = json['expires_in'];
  }
}
