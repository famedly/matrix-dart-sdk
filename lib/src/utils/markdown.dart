import 'package:markdown/markdown.dart';
import 'dart:convert';

class LinebreakSyntax extends InlineSyntax {
  LinebreakSyntax() : super(r'\n');

  @override
  bool onMatch(InlineParser parser, Match match) {
    parser.addNode(Element.empty('br'));
    return true;
  }
}

class SpoilerSyntax extends TagSyntax {
  Map<String, String> reasonMap = <String, String>{};
  SpoilerSyntax()
      : super(
          r'\|\|(?:([^\|]+)\|(?!\|))?',
          requiresDelimiterRun: true,
          end: r'\|\|',
        );

  @override
  bool onMatch(InlineParser parser, Match match) {
    if (super.onMatch(parser, match)) {
      reasonMap[match.input] = match[1];
      return true;
    }
    return false;
  }

  @override
  bool onMatchEnd(InlineParser parser, Match match, TagState state) {
    final element = Element('span', state.children);
    element.attributes['data-mx-spoiler'] =
        htmlEscape.convert(reasonMap[match.input] ?? '');
    parser.addNode(element);
    return true;
  }
}

class EmoteSyntax extends InlineSyntax {
  final Map<String, Map<String, String>> emotePacks;
  EmoteSyntax(this.emotePacks) : super(r':(?:([-\w]+)~)?([-\w]+):');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final pack = match[1] ?? '';
    final emote = ':${match[2]}:';
    String mxc;
    if (pack.isEmpty) {
      // search all packs
      for (final emotePack in emotePacks.values) {
        mxc = emotePack[emote];
        if (mxc != null) {
          break;
        }
      }
    } else {
      mxc = emotePacks[pack] != null ? emotePacks[pack][emote] : null;
    }
    if (mxc == null) {
      // emote not found. Insert the whole thing as plain text
      parser.addNode(Text(match[0]));
      return true;
    }
    final element = Element.empty('img');
    element.attributes['data-mx-emote'] = '';
    element.attributes['src'] = htmlEscape.convert(mxc);
    element.attributes['alt'] = htmlEscape.convert(emote);
    element.attributes['title'] = htmlEscape.convert(emote);
    element.attributes['height'] = '32';
    element.attributes['vertical-align'] = 'middle';
    parser.addNode(element);
    return true;
  }
}

class PillSyntax extends InlineSyntax {
  PillSyntax() : super(r'([@#!][^\s:]*:[^\s]+\.\w+)');

  @override
  bool onMatch(InlineParser parser, Match match) {
    final identifier = match[1];
    final element = Element.text('a', identifier);
    element.attributes['href'] = 'https://matrix.to/#/${identifier}';
    parser.addNode(element);
    return true;
  }
}

String markdown(String text, [Map<String, Map<String, String>> emotePacks]) {
  emotePacks ??= <String, Map<String, String>>{};
  var ret = markdownToHtml(
    text,
    extensionSet: ExtensionSet.commonMark,
    inlineSyntaxes: [
      StrikethroughSyntax(),
      LinebreakSyntax(),
      SpoilerSyntax(),
      EmoteSyntax(emotePacks),
      PillSyntax()
    ],
  );

  var stripPTags = '<p>'.allMatches(ret).length <= 1;
  if (stripPTags) {
    final otherBlockTags = [
      'table',
      'pre',
      'ol',
      'ul',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'blockquote'
    ];
    for (final tag in otherBlockTags) {
      // we check for the close tag as the opening one might have attributes
      if (ret.contains('</${tag}>')) {
        stripPTags = false;
        break;
      }
    }
  }
  if (stripPTags) {
    ret = ret.replaceAll('<p>', '').replaceAll('</p>', '');
  }
  return ret.trim().replaceAll(RegExp(r'(<br />)+$'), '');
}
