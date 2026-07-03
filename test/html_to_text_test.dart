// SPDX-FileCopyrightText: 2019-Present, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/src/utils/html_to_text.dart';
import 'package:test/test.dart';

void main() {
  group('htmlToText', () {
    final testMap = <String, String>{
      '': '',
      'hello world\nthis is a test': 'hello world\nthis is a test',
      '<em>That\'s</em> not a test, <strong>this</strong> is a test':
          '*That\'s* not a test, **this** is a test',
      'Visit <del><a href="http://example.com">our website</a></del> (outdated)':
          'Visit ~~🔗our website~~ (outdated)',
      '(cw spiders) <span data-mx-spoiler>spiders are pretty cool</span>':
          '(cw spiders) ███████████████████████',
      '<span data-mx-spoiler="cw spiders">spiders are pretty cool</span>':
          '(cw spiders) ███████████████████████',
      '<img src="test.gif" alt="a test case" />': 'a test case',
      'List of cute animals:\n<ul>\n<li>Kittens</li>\n<li>Puppies</li>\n<li>Snakes<br/>(I think they\'re cute!)</li>\n</ul>\n(This list is incomplete, you can help by adding to it!)':
          'List of cute animals:\n• Kittens\n• Puppies\n• Snakes\n  (I think they\'re cute!)\n(This list is incomplete, you can help by adding to it!)',
      '<em>fox</em>': '*fox*',
      '<i>fox</i>': '*fox*',
      '<strong>fox</i>': '**fox**',
      '<b>fox</b>': '**fox**',
      '<u>fox</u>': '__fox__',
      '<ins>fox</ins>': '__fox__',
      '<del>fox</del>': '~~fox~~',
      '<strike>fox</strike>': '~~fox~~',
      '<s>fox</s>': '~~fox~~',
      '<code>&gt;fox</code>': '`>fox`',
      '<pre>meep</pre>': '```\nmeep\n```',
      '<pre>meep\n</pre>': '```\nmeep\n```',
      '<pre><code class="language-floof">meep</code></pre>':
          '```floof\nmeep\n```',
      'before<pre>code</pre>after': 'before\n```\ncode\n```\nafter',
      '<p>before</p><pre>code</pre><p>after</p>':
          'before\n```\ncode\n```\nafter',
      '<p>fox</p>': 'fox',
      '<p>fox</p><p>floof</p>': 'fox\n\nfloof',
      '<a href="https://example.org">website</a>': '🔗website',
      '<a href="https://matrix.to/#/@user:example.org">fox</a>': 'fox',
      '<a href="matrix:u/user:example.org">fox</a>': 'fox',
      '<img alt=":wave:" src="mxc://fox">': ':wave:',
      'fox<br>floof': 'fox\nfloof',
      '<blockquote>fox</blockquote>floof': '> fox\nfloof',
      '<blockquote><p>fox</p></blockquote>floof': '> fox\nfloof',
      '<blockquote><p>fox</p></blockquote><p>floof</p>': '> fox\nfloof',
      'a<blockquote>fox</blockquote>floof': 'a\n> fox\nfloof',
      '<blockquote><blockquote>fox</blockquote>floof</blockquote>fluff':
          '> > fox\n> floof\nfluff',
      '<ul><li>hey<ul><li>a</li><li>b</li></ul></li><li>foxies</li></ul>':
          '• hey\n      ◦ a\n      ◦ b\n• foxies',
      '<ol><li>a</li><li>b</li></ol>': '1. a\n2. b',
      '<ol start="42"><li>a</li><li>b</li></ol>': '42. a\n43. b',
      '<ol><li>a<ol><li>aa</li><li>bb</li></ol></li><li>b</li></ol>':
          '1. a\n      1. aa\n      2. bb\n2. b',
      '<ol><li>a<ul><li>aa</li><li>bb</li></ul></li><li>b</li></ol>':
          '1. a\n      ◦ aa\n      ◦ bb\n2. b',
      '<ul><li>a<ol><li>aa</li><li>bb</li></ol></li><li>b</li></ul>':
          '• a\n      1. aa\n      2. bb\n• b',
      '<mx-reply>bunny</mx-reply>fox': 'fox',
      'fox<hr>floof': 'fox\n----------\nfloof',
      '<p>fox</p><hr><p>floof</p>': 'fox\n----------\nfloof',
      '<h1>fox</h1>floof': '# fox\nfloof',
      '<h1>fox</h1><p>floof</p>': '# fox\nfloof',
      'floof<h1>fox</h1>': 'floof\n# fox',
      '<p>floof</p><h1>fox</h1>': 'floof\n# fox',
      '<h2>fox</h2>': '## fox',
      '<h3>fox</h3>': '### fox',
      '<h4>fox</h4>': '#### fox',
      '<h5>fox</h5>': '##### fox',
      '<h6>fox</h6>': '###### fox',
      '<span>fox</span>': 'fox',
      '<p>fox</p>\n<p>floof</p>': 'fox\n\nfloof',
      '<mx-reply>beep</mx-reply><p>fox</p>\n<p>floof</p>': 'fox\n\nfloof',
      '<pre><code></code></pre>': '``````',
    };
    for (final entry in testMap.entries) {
      test(entry.key, () async {
        expect(HtmlToText.convert(entry.key), entry.value);
      });
    }
  });
}
