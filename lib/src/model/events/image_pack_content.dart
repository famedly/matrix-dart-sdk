/* MIT License
*
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import '../../utils/filter_map_extension.dart';
import '../../utils/try_get_map_extension.dart';
import '../basic_event.dart';

extension ImagePackContentBasicEventExtension on BasicEvent {
  ImagePackContent get parsedImagePackContent =>
      ImagePackContent.fromJson(content);
}

enum ImagePackUsage {
  sticker,
  emoticon,
}

List<ImagePackUsage>? imagePackUsageFromJson(List<String>? json) => json
    ?.map((v) => {
          'sticker': ImagePackUsage.sticker,
          'emoticon': ImagePackUsage.emoticon,
        }[v])
    .whereType<ImagePackUsage>()
    .toList();

List<String> imagePackUsageToJson(
    List<ImagePackUsage>? usage, List<String>? prevUsage) {
  final knownUsages = <String>{'sticker', 'emoticon'};
  final usagesStr = usage
          ?.map((v) => {
                ImagePackUsage.sticker: 'sticker',
                ImagePackUsage.emoticon: 'emoticon',
              }[v])
          .whereType<String>()
          .toList() ??
      [];
  // first we add all the unknown usages and the previous known usages which are new again
  final newUsages = prevUsage
          ?.where((v) => !knownUsages.contains(v) || usagesStr.contains(v))
          .toList() ??
      [];
  // now we need to add the new usages that we didn't add yet
  newUsages.addAll(usagesStr.where((v) => !newUsages.contains(v)));
  return newUsages;
}

class ImagePackContent {
  // we want to preserve potential custom keys in this object
  final Map<String, Object?> _json;

  Map<String, ImagePackImageContent> images;
  ImagePackPackContent pack;

  ImagePackContent({required this.images, required this.pack}) : _json = {};

  ImagePackContent.fromJson(Map<String, Object?> json)
      : _json = Map.fromEntries(json.entries.where(
            (e) => !['images', 'pack', 'emoticons', 'short'].contains(e.key))),
        pack = ImagePackPackContent.fromJson(
            json.tryGetMap<String, Object?>('pack') ?? {}),
        images = json.tryGetMap<String, Object?>('images')?.catchMap((k, v) =>
                MapEntry(
                    k,
                    ImagePackImageContent.fromJson(
                        v as Map<String, Object?>))) ??
            // the "emoticons" key needs a small migration on the key, ":string:" --> "string"
            json.tryGetMap<String, Object?>('emoticons')?.catchMap((k, v) =>
                MapEntry(
                    k.startsWith(':') && k.endsWith(':')
                        ? k.substring(1, k.length - 1)
                        : k,
                    ImagePackImageContent.fromJson(
                        v as Map<String, Object?>))) ??
            // the "short" key was still just a map from shortcode to mxc uri
            json.tryGetMap<String, String>('short')?.catchMap((k, v) =>
                MapEntry(
                    k.startsWith(':') && k.endsWith(':')
                        ? k.substring(1, k.length - 1)
                        : k,
                    ImagePackImageContent(url: Uri.parse(v)))) ??
            {};

  Map<String, Object?> toJson() => {
        ..._json,
        'images': images.map((k, v) => MapEntry(k, v.toJson())),
        'pack': pack.toJson(),
      };
}

class ImagePackImageContent {
  // we want to preserve potential custom keys in this object
  final Map<String, Object?> _json;

  Uri url;
  String? body;
  Map<String, Object?>? info;
  List<ImagePackUsage>? usage;

  ImagePackImageContent({required this.url, this.body, this.info, this.usage})
      : _json = {};

  ImagePackImageContent.fromJson(Map<String, Object?> json)
      : _json = Map.fromEntries(json.entries
            .where((e) => !['url', 'body', 'info'].contains(e.key))),
        url = Uri.parse(json['url'] as String),
        body = json.tryGet('body'),
        info = json.tryGetMap<String, Object?>('info'),
        usage = imagePackUsageFromJson(json.tryGetList<String>('usage'));

  Map<String, Object?> toJson() {
    return {
      ...Map.from(_json)..remove('usage'),
      'url': url.toString(),
      if (body != null) 'body': body,
      if (info != null) 'info': info,
      if (usage != null)
        'usage': imagePackUsageToJson(usage, _json.tryGetList<String>('usage')),
    };
  }
}

class ImagePackPackContent {
  // we want to preserve potential custom keys in this object
  final Map<String, Object?> _json;

  String? displayName;
  Uri? avatarUrl;
  List<ImagePackUsage>? usage;
  String? attribution;

  ImagePackPackContent(
      {this.displayName, this.avatarUrl, this.usage, this.attribution})
      : _json = {};

  ImagePackPackContent.fromJson(Map<String, Object?> json)
      : _json = Map.fromEntries(json.entries.where((e) =>
            !['display_name', 'avatar_url', 'attribution'].contains(e.key))),
        displayName = json.tryGet('display_name'),
        // we default to an invalid uri
        avatarUrl = Uri.tryParse(json.tryGet('avatar_url') ?? '.::'),
        usage = imagePackUsageFromJson(json.tryGetList<String>('usage')),
        attribution = json.tryGet('attribution');

  Map<String, Object?> toJson() {
    return {
      ...Map.from(_json)..remove('usage'),
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl.toString(),
      if (usage != null)
        'usage': imagePackUsageToJson(usage, _json.tryGetList<String>('usage')),
      if (attribution != null) 'attribution': attribution,
    };
  }
}
