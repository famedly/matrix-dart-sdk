/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
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

import 'package:collection/collection.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:html_unescape/html_unescape.dart';

class HtmlToText {
  /// Convert an HTML string to a pseudo-markdown plain text representation, with
  /// `data-mx-spoiler` spans redacted
  static String convert(String html) {
    // riot-web is notorious for creating bad reply fallback events from invalid messages which, if
    // not handled properly, can lead to impersonation. As such, we strip the entire `<mx-reply>` tags
    // here already, to prevent that from happening.
    // We do *not* do this in an AST and just with simple regex here, as riot-web tends to create
    // miss-matching tags, and this way we actually correctly identify what we want to strip and, well,
    // strip it.
    final renderHtml = html.replaceAll(
      RegExp(
        '<mx-reply>.*</mx-reply>',
        caseSensitive: false,
        multiLine: false,
        dotAll: true,
      ),
      '',
    );

    final opts = _ConvertOpts();
    var reply = _walkNode(opts, parseFragment(renderHtml));
    reply = reply.replaceAll(RegExp(r'\s*$', multiLine: false), '');
    return reply;
  }

  static String _parsePreContent(_ConvertOpts opts, Element node) {
    var text = node.innerHtml;
    final match =
        RegExp(r'^<code([^>]*)>', multiLine: false, caseSensitive: false)
            .firstMatch(text);
    if (match == null) {
      text = HtmlUnescape().convert(text);
      if (text.isNotEmpty) {
        if (text[0] != '\n') {
          text = '\n$text';
        }
        if (text[text.length - 1] != '\n') {
          text += '\n';
        }
      }
      return text;
    }
    // remove <code> opening tag
    text = text.substring(match.end);
    // remove the </code> closing tag
    text = text.replaceAll(
      RegExp(r'</code>$', multiLine: false, caseSensitive: false),
      '',
    );
    text = HtmlUnescape().convert(text);
    if (text.isNotEmpty) {
      if (text[0] != '\n') {
        text = '\n$text';
      }
      if (text[text.length - 1] != '\n') {
        text += '\n';
      }
    }
    final language =
        RegExp(r'language-(\w+)', multiLine: false, caseSensitive: false)
            .firstMatch(match.group(1)!);
    if (language != null) {
      text = language.group(1)! + text;
    }
    return text;
  }

  static String _parseBlockquoteContent(_ConvertOpts opts, Element node) {
    final msg = _walkChildNodes(opts, node);
    return '${msg.split('\n').map((s) => '> $s').join('\n')}\n';
  }

  static String _parseSpanContent(_ConvertOpts opts, Element node) {
    final content = _walkChildNodes(opts, node);
    if (node.attributes['data-mx-spoiler'] is String) {
      var spoiler = '█' * content.length;
      final reason = node.attributes['data-mx-spoiler'];
      if (reason != '') {
        spoiler = '($reason) $spoiler';
      }
      return spoiler;
    }
    return content;
  }

  static String _parseUlContent(_ConvertOpts opts, Element node) {
    opts.listDepth++;
    final entries = _listChildNodes(opts, node, {'li'});
    opts.listDepth--;
    final bulletPoint =
        _listBulletPoints[opts.listDepth % _listBulletPoints.length];

    return entries
        .map(
          (s) =>
              '${'    ' * opts.listDepth}$bulletPoint ${s.replaceAll('\n', '\n${'    ' * opts.listDepth}  ')}',
        )
        .join('\n');
  }

  static String _parseOlContent(_ConvertOpts opts, Element node) {
    opts.listDepth++;
    final entries = _listChildNodes(opts, node, {'li'});
    opts.listDepth--;
    final startStr = node.attributes['start'];
    final start = (startStr is String &&
            RegExp(r'^[0-9]+$', multiLine: false).hasMatch(startStr))
        ? int.parse(startStr)
        : 1;

    return entries
        .mapIndexed(
          (index, s) =>
              '${'    ' * opts.listDepth}${start + index}. ${s.replaceAll('\n', '\n${'    ' * opts.listDepth}  ')}',
        )
        .join('\n');
  }

  static const _listBulletPoints = <String>['●', '○', '■', '‣'];

  static List<String> _listChildNodes(
    _ConvertOpts opts,
    Element node, [
    Iterable<String>? types,
  ]) {
    final replies = <String>[];
    for (final child in node.nodes) {
      if (types != null &&
          types.isNotEmpty &&
          ((child is Text) ||
              ((child is Element) &&
                  !types.contains(child.localName!.toLowerCase())))) {
        continue;
      }
      replies.add(_walkNode(opts, child));
    }
    return replies;
  }

  static const _blockTags = <String>{
    'blockquote',
    'ul',
    'ol',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'pre',
  };

  static String _walkChildNodes(_ConvertOpts opts, Node node) {
    var reply = '';
    var lastTag = '';
    for (final child in node.nodes) {
      final thisTag = child is Element ? child.localName!.toLowerCase() : '';
      if (thisTag == 'p' && lastTag == 'p') {
        reply += '\n\n';
      } else if (_blockTags.contains(thisTag) &&
          reply.isNotEmpty &&
          reply[reply.length - 1] != '\n') {
        reply += '\n';
      }
      reply += _walkNode(opts, child);
      if (thisTag.isNotEmpty) {
        lastTag = thisTag;
      }
    }
    return reply;
  }

  static String _walkNode(_ConvertOpts opts, Node node) {
    if (node is Text) {
      // ignore \n between single nodes
      return node.text == '\n' ? '' : node.text;
    } else if (node is Element) {
      final tag = node.localName!.toLowerCase();
      switch (tag) {
        case 'em':
        case 'i':
          return '*${_walkChildNodes(opts, node)}*';
        case 'strong':
        case 'b':
          return '**${_walkChildNodes(opts, node)}**';
        case 'u':
        case 'ins':
          return '__${_walkChildNodes(opts, node)}__';
        case 'del':
        case 'strike':
        case 's':
          return '~~${_walkChildNodes(opts, node)}~~';
        case 'code':
          return '`${node.text}`';
        case 'pre':
          return '```${_parsePreContent(opts, node)}```\n';
        case 'a':
          final href = node.attributes['href'] ?? '';
          final content = _walkChildNodes(opts, node);
          if (href.toLowerCase().startsWith('https://matrix.to/#/') ||
              href.toLowerCase().startsWith('matrix:')) {
            return content;
          }
          return '🔗$content';
        case 'img':
          return node.attributes['alt'] ??
              node.attributes['title'] ??
              node.attributes['src'] ??
              '';
        case 'br':
          return '\n';
        case 'blockquote':
          return _parseBlockquoteContent(opts, node);
        case 'ul':
          return _parseUlContent(opts, node);
        case 'ol':
          return _parseOlContent(opts, node);
        case 'mx-reply':
          return '';
        case 'hr':
          return '\n----------\n';
        case 'h1':
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
          final mark = '#' * int.parse(tag[1]);
          return '$mark ${_walkChildNodes(opts, node)}\n';
        case 'span':
          return _parseSpanContent(opts, node);
        default:
          return _walkChildNodes(opts, node);
      }
    } else {
      return _walkChildNodes(opts, node);
    }
  }
}

class _ConvertOpts {
  int listDepth = 0;
}
