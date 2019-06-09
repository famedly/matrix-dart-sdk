/// Represents a special response from the Homeserver for errors.
class ErrorResponse {

  /// The unique identifier for this error.
  String errcode;

  /// A human readable error description.
  String error;

  ErrorResponse({this.errcode, this.error});

  ErrorResponse.fromJson(Map<String, dynamic> json) {
    errcode = json['errcode'];
    error = json['error'] ?? "";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['errcode'] = this.errcode;
    data['error'] = this.error;
    return data;
  }
}
