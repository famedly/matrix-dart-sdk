/// Exception thrown on Client initialization. This object might contain
/// enough information to restore the session or to decide if you need to
/// logout the session or clear the database.
class ClientInitException implements Exception {
  final Object originalException;
  final Uri? homeserver;
  final String? accessToken;
  final String? userId;
  final String? deviceId;
  final String? deviceName;
  final String? olmAccount;

  ClientInitException(
    this.originalException, {
    this.homeserver,
    this.accessToken,
    this.userId,
    this.deviceId,
    this.deviceName,
    this.olmAccount,
  });

  @override
  String toString() => originalException.toString();
}

class ClientInitPreconditionError implements Exception {
  final String cause;

  ClientInitPreconditionError(this.cause);

  @override
  String toString() => 'Client Init Precondition Error: $cause';
}
