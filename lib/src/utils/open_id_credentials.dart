class OpenIdCredentials {
  String accessToken;
  String tokenType;
  String matrixServerName;
  num expiresIn;

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

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['access_token'] = this.accessToken;
    data['token_type'] = this.tokenType;
    data['matrix_server_name'] = this.matrixServerName;
    data['expires_in'] = this.expiresIn;
    return data;
  }
}
