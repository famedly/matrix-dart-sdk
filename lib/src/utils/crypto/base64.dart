
extension Base64Utils on String {
  String toBase64() {
    return replaceAll('-', '+')
      .replaceAll('_', '/');
  }

  String toUnpaddedBase64() {
    return replaceAll('\n', '')
      .replaceAll('=', '');
  }

  String toBase64Url() {
    return replaceAll('\n', '')
      .replaceAll('\\+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
  }
}