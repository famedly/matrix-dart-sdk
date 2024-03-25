/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:slugify/slugify.dart';

import 'package:matrix/matrix_api_lite.dart';
import 'package:matrix/src/room.dart';

extension ImagePackRoomExtension on Room {
  /// Get all the active image packs for the specified [usage], mapped by their slug
  Map<String, ImagePackContent> getImagePacks([ImagePackUsage? usage]) {
    final allMxcs = <Uri>{}; // used for easy deduplication
    final packs = <String, ImagePackContent>{};

    void addImagePack(BasicEvent? event, {Room? room, String? slug}) {
      if (event == null) return;
      final imagePack = event.parsedImagePackContent;
      final finalSlug = slugify(slug ?? 'pack');
      for (final entry in imagePack.images.entries) {
        final image = entry.value;
        if (allMxcs.contains(image.url)) {
          continue;
        }
        final imageUsage = image.usage ?? imagePack.pack.usage;
        if (usage != null &&
            imageUsage != null &&
            !imageUsage.contains(usage)) {
          continue;
        }
        packs
            .putIfAbsent(
                finalSlug,
                () => ImagePackContent.fromJson({})
                  ..pack.displayName = imagePack.pack.displayName ??
                      room?.getLocalizedDisplayname() ??
                      finalSlug
                  ..pack.avatarUrl = imagePack.pack.avatarUrl ?? room?.avatar
                  ..pack.attribution = imagePack.pack.attribution)
            .images[entry.key] = image;
        allMxcs.add(image.url);
      }
    }

    // first we add the user image pack
    addImagePack(client.accountData['im.ponies.user_emotes'], slug: 'user');
    // next we add all the external image packs
    final packRooms = client.accountData['im.ponies.emote_rooms'];
    final rooms = packRooms?.content.tryGetMap<String, Object?>('rooms');
    if (packRooms != null && rooms != null) {
      for (final roomEntry in rooms.entries) {
        final roomId = roomEntry.key;
        final room = client.getRoomById(roomId);
        final roomEntryValue = roomEntry.value;
        if (room != null && roomEntryValue is Map<String, Object?>) {
          for (final stateKeyEntry in roomEntryValue.entries) {
            final stateKey = stateKeyEntry.key;
            final fallbackSlug =
                '${room.getLocalizedDisplayname()}-${stateKey.isNotEmpty ? '$stateKey-' : ''}${room.id}';
            addImagePack(room.getState('im.ponies.room_emotes', stateKey),
                room: room, slug: fallbackSlug);
          }
        }
      }
    }
    // finally we add all of this rooms state
    final allRoomEmotes = states['im.ponies.room_emotes'];
    if (allRoomEmotes != null) {
      for (final entry in allRoomEmotes.entries) {
        addImagePack(entry.value,
            room: this,
            slug: (entry.value.stateKey?.isNotEmpty == true)
                ? entry.value.stateKey
                : 'room');
      }
    }
    return packs;
  }

  /// Get a flat view of all the image packs of a specified [usage], that is a map of all
  /// slugs to a map of the image code to their mxc url
  Map<String, Map<String, String>> getImagePacksFlat([ImagePackUsage? usage]) =>
      getImagePacks(usage).map((k, v) =>
          MapEntry(k, v.images.map((k, v) => MapEntry(k, v.url.toString()))));
}
