library msc_3814_dehydrated_devices;

import 'dart:convert';
import 'dart:math';

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/msc_extensions/msc_3814_dehydrated_devices/api.dart';
import 'package:matrix/msc_extensions/msc_3814_dehydrated_devices/model/dehydrated_device.dart';
import 'package:matrix/msc_extensions/msc_3814_dehydrated_devices/model/dehydrated_device_events.dart';
import 'package:matrix/src/utils/crypto/crypto.dart' as uc;

extension DehydratedDeviceHandler on Client {
  static const Set<String> _oldDehydratedDeviceAlgorithms = {
    'com.famedly.dehydrated_device.raw_olm_account',
  };
  static const String _dehydratedDeviceAlgorithm =
      'com.famedly.dehydrated_device.raw_olm_account.v2';
  static const String _ssssSecretNameForDehydratedDevice = 'org.matrix.msc3814';

  /// Restores the dehydrated device account and/or creates a new one, fetches the events and as such makes encrypted messages available while we were offline.
  /// Usually it only makes sense to call this when you just entered the SSSS passphrase or recovery key successfully.
  Future<void> dehydratedDeviceSetup(OpenSSSS secureStorage) async {
    try {
      // dehydrated devices need to be cross-signed
      if (!enableDehydratedDevices ||
          !encryptionEnabled ||
          this.encryption?.crossSigning.enabled != true) {
        return;
      }

      DehydratedDevice? device;
      try {
        device = await getDehydratedDevice();
      } on MatrixException catch (e) {
        if (e.response?.statusCode == 400) {
          Logs().i('Dehydrated devices unsupported, skipping.');
          return;
        }
        // No device, so we just create a new device.
        await _uploadNewDevice(secureStorage);
        return;
      }

      // Just throw away the old device if it is using an old algoritm. In the future we could try to still use it and then migrate it, but currently that is not worth the effort
      if (_oldDehydratedDeviceAlgorithms
          .contains(device.deviceData?.tryGet<String>('algorithm'))) {
        await _uploadNewDevice(secureStorage);
        return;
      }

      // Only handle devices we understand
      // In the future we might want to migrate to a newer format here
      if (device.deviceData?.tryGet<String>('algorithm') !=
          _dehydratedDeviceAlgorithm) return;

      // Verify that the device is cross-signed
      final dehydratedDeviceIdentity =
          userDeviceKeys[userID]!.deviceKeys[device.deviceId];
      if (dehydratedDeviceIdentity == null ||
          !dehydratedDeviceIdentity.hasValidSignatureChain()) {
        Logs().w(
            'Dehydrated device ${device.deviceId} is unknown or unverified, replacing it');
        await _uploadNewDevice(secureStorage);
        return;
      }

      final pickleDeviceKey =
          await secureStorage.getStored(_ssssSecretNameForDehydratedDevice);
      final pickledDevice = device.deviceData?.tryGet<String>('device');
      if (pickledDevice == null) {
        Logs()
            .w('Dehydrated device ${device.deviceId} is invalid, replacing it');
        await _uploadNewDevice(secureStorage);
        return;
      }

      // Use a separate encryption object for the dehydrated device.
      // We need to be careful to not use the client.deviceId here and such.
      final encryption = Encryption(client: this);
      try {
        await encryption.init(
          pickledDevice,
          deviceId: device.deviceId,
          pickleKey: pickleDeviceKey,
          dehydratedDeviceAlgorithm: _dehydratedDeviceAlgorithm,
        );

        if (dehydratedDeviceIdentity.curve25519Key != encryption.identityKey ||
            dehydratedDeviceIdentity.ed25519Key != encryption.fingerprintKey) {
          Logs()
              .w('Invalid dehydrated device ${device.deviceId}, replacing it');
          await encryption.dispose();
          await _uploadNewDevice(secureStorage);
          return;
        }

        // Fetch the to_device messages sent to the picked device and handle them 1:1.
        DehydratedDeviceEvents? events;

        do {
          events = await getDehydratedDeviceEvents(device.deviceId,
              nextBatch: events?.nextBatch);

          for (final e in events.events ?? []) {
            // We are only interested in roomkeys, which ALWAYS need to be encrypted.
            if (e.type == EventTypes.Encrypted) {
              final decryptedEvent = await encryption.decryptToDeviceEvent(e);

              if (decryptedEvent.type == EventTypes.RoomKey) {
                await encryption.handleToDeviceEvent(decryptedEvent);
              }
            }
          }
        } while (events.events?.isNotEmpty == true);

        await _uploadNewDevice(secureStorage);
      } finally {
        await encryption.dispose();
      }
    } catch (e) {
      Logs().w('Exception while handling dehydrated devices: ${e.toString()}');
      return;
    }
  }

  Future<void> _uploadNewDevice(OpenSSSS secureStorage) async {
    final encryption = Encryption(client: this);

    try {
      String? pickleDeviceKey;
      try {
        pickleDeviceKey =
            await secureStorage.getStored(_ssssSecretNameForDehydratedDevice);
      } catch (_) {
        Logs().i('Dehydrated device key not found, creating new one.');
        pickleDeviceKey = base64.encode(uc.secureRandomBytes(128));
        await secureStorage.store(
            _ssssSecretNameForDehydratedDevice, pickleDeviceKey);
      }

      const chars =
          'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
      final rnd = Random();

      final deviceIdSuffix = String.fromCharCodes(Iterable.generate(
          10, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
      final String device = 'FAM$deviceIdSuffix';

      // Generate a new olm account for the dehydrated device.
      try {
        await encryption.init(
          null,
          deviceId: device,
          pickleKey: pickleDeviceKey,
          dehydratedDeviceAlgorithm: _dehydratedDeviceAlgorithm,
        );
      } on MatrixException catch (_) {
        // dehydrated devices unsupported, do noting.
        Logs().i('Dehydrated devices unsupported, skipping upload.');
        await encryption.dispose();
        return;
      }

      encryption.ourDeviceId = device;
      encryption.olmManager.ourDeviceId = device;

      // cross sign the device from our currently signed in device
      await updateUserDeviceKeys(additionalUsers: {userID!});
      final keysToSign = <SignableKey>[
        userDeviceKeys[userID]!.deviceKeys[device]!,
      ];
      await this.encryption?.crossSigning.sign(keysToSign);
    } finally {
      await encryption.dispose();
    }
  }
}
