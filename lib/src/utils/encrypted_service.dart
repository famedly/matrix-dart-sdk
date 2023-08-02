import 'dart:io';

import 'package:matrix/src/utils/crypto/crypto.dart';
import 'package:matrix/src/utils/models/encrypted_file_info.dart';
import 'package:matrix/src/utils/models/file_info.dart';

class EncryptedService {
  final cipherAlgorithm = aesCtr;

  static final EncryptedService _encryptedService = EncryptedService._internal();

  factory EncryptedService() {
    return _encryptedService;
  }

  EncryptedService._internal();
  
  /// Encrypts a file using AES-CTR encryption mode.
  ///
  /// This method takes a [fileInfo] object, which contains information about the
  /// file to be encrypted. It can either be a [FileInfo] object containing a
  /// [readStream] for reading the file data, or it can use the [filePath] property
  /// to open a new read stream from the file path. The [fileInfo] is required.
  ///
  /// The encrypted data will be written to the [outputFile] specified in the
  /// [outputFile] parameter. The [outputFile] must be a valid [File] object.
  /// You should remove the [outputFile] after the encryptFile is done.
  Future<EncryptedFileInfo> encryptFile({
    required FileInfo fileInfo,
    required File outputFile,
  }) async {
    final inputStream = fileInfo.readStream ?? File(fileInfo.filePath).openRead();
    final key = secureRandomBytes(32);
    final initialVector = secureRandomBytes(16);
    return await aesCtr.encryptStream(
      inputStream: inputStream, 
      key: key, 
      initialVector: initialVector,
      outputFile: outputFile,
    );
  }
  /// Decrypts a file using AES-CTR decryption mode.
  ///
  /// This method takes a [fileInfo] object, which contains information about the
  /// file to be decrypted. It can either be a [FileInfo] object containing a
  /// [readStream] for reading the encrypted file data, or it can use the [filePath]
  /// property to open a new read stream from the encrypted file path. The [fileInfo]
  /// is required.
  ///
  /// The [encryptedFileInfo] parameter is a required [EncryptedFileInfo] object
  /// that contains information about the encryption process, such as the [key],
  /// [initialVector], and details about the [outputFile] where the encrypted data
  /// was written. This information is necessary for successful decryption.
  ///
  /// The decrypted data will be written to the [outputFile] specified in the
  /// [outputFile] parameter. The [outputFile] must be a valid [File] object.
  Future<bool> decryptFile({
    required FileInfo fileInfo,
    required EncryptedFileInfo encryptedFileInfo,
    required File outputFile,
  }) async {
    final inputStream = fileInfo.readStream ?? File(fileInfo.filePath).openRead();
    return await aesCtr.decryptStream(
      inputStream: inputStream,
      outputFile: outputFile,
      encryptedFileInfo: encryptedFileInfo
    );
  }
}