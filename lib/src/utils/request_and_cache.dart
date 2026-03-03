import 'package:matrix/matrix.dart' hide Result;

extension RequestAndCache on Client {
  Future<T> requestAndCache<T>(
    Future<T> Function() requestFunc, {
    required T Function(Map<String, Object?> json) fromJson,
    required Map<String, Object?> Function(T) toJson,
    required String cacheKey,
    required Duration cacheLifetime,
    required bool throwOnUpdateFailure,
  }) async {
    if (cacheLifetime == Duration.zero || !isLogged()) return requestFunc();

    final cachedResponse = await database.getCustomCacheObject(cacheKey);
    if (cachedResponse != null &&
        cachedResponse.savedAt.add(cacheLifetime).isAfter(DateTime.now())) {
      return fromJson(cachedResponse.content);
    }

    try {
      final content = await requestFunc();
      await database.cacheCustomObject(cacheKey, toJson(content));
      return content;
    } catch (error, stackTrace) {
      Logs().w(
        'Unable to update cache for $cacheKey',
        error,
        stackTrace,
      );

      if (!throwOnUpdateFailure && cachedResponse != null) {
        return fromJson(cachedResponse.content);
      }
      rethrow;
    }
  }
}
