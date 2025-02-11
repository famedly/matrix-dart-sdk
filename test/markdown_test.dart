/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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

import 'package:test/test.dart';

import 'package:matrix/src/utils/markdown.dart';

void main() {
  group('markdown', () {
    final emotePacks = {
      'room': {
        'fox': 'mxc://roomfox',
        'bunny': 'mxc://roombunny',
      },
      'user': {
        'fox': 'mxc://userfox',
        'bunny': 'mxc://userbunny',
        'raccoon': 'mxc://raccoon',
      },
    };
    final mentionMap = {
      '@Bob': '@bob:example.org',
      '@[Bob Ross]': '@bobross:example.org',
      '@Fox#123': '@fox:example.org',
      '@[Fast Fox]#123': '@fastfox:example.org',
      '@[">]': '@blah:example.org',
    };
    String? getMention(mention) => mentionMap[mention];
    test('simple markdown', () {
      expect(
        markdown('hey *there* how are **you** doing?'),
        'hey <em>there</em> how are <strong>you</strong> doing?',
      );
      expect(markdown('wha ~~strike~~ works!'), 'wha <del>strike</del> works!');
    });
    test('spoilers', () {
      expect(
        markdown('Snape killed ||Dumbledoor||'),
        'Snape killed <span data-mx-spoiler="">Dumbledoor</span>',
      );
      expect(
        markdown('Snape killed ||Story|Dumbledoor||'),
        'Snape killed <span data-mx-spoiler="Story">Dumbledoor</span>',
      );
      expect(
        markdown('Snape killed ||Some dumb loser|Dumbledoor||'),
        'Snape killed <span data-mx-spoiler="Some dumb loser">Dumbledoor</span>',
      );
      expect(
        markdown('Snape killed ||Some dumb loser|Dumbledoor **bold**||'),
        'Snape killed <span data-mx-spoiler="Some dumb loser">Dumbledoor <strong>bold</strong></span>',
      );
      expect(
        markdown('Snape killed ||Dumbledoor **bold**||'),
        'Snape killed <span data-mx-spoiler="">Dumbledoor <strong>bold</strong></span>',
      );
    });
    test('linebreaks', () {
      expect(markdown('Heya!\nBeep'), 'Heya!<br/>Beep');
      expect(markdown('Heya!\n\nBeep'), '<p>Heya!</p><p>Beep</p>');
      expect(markdown('Heya!\n\n\nBeep'), '<p>Heya!</p><p><br/>Beep</p>');
      expect(
        markdown('Heya!\n\n\n\nBeep'),
        '<p>Heya!</p><p><br/><br/>Beep</p>',
      );
      expect(
        markdown('Heya!\n\n\n\nBeep\n\n'),
        '<p>Heya!</p><p><br/><br/>Beep</p>',
      );
      expect(
        markdown('\n\nHeya!\n\n\n\nBeep'),
        '<p>Heya!</p><p><br/><br/>Beep</p>',
      );
      expect(
        markdown('\n\nHeya!\n\n\n\nBeep\n '),
        '<p>Heya!</p><p><br/><br/>Beep</p>',
      );
    });
    test('Other block elements', () {
      expect(markdown('# blah\n\nblubb'), '<h1>blah</h1><p>blubb</p>');
    });
    test('lists', () {
      expect(
        markdown('So we have:\n- foxies\n- cats\n- dogs'),
        '<p>So we have:</p><ul><li>foxies</li><li>cats</li><li>dogs</li></ul>',
      );
    });
    test('emotes', () {
      expect(
        markdown(':fox:', getEmotePacks: () => emotePacks),
        '<img data-mx-emoticon="" src="mxc://roomfox" alt=":fox:" title=":fox:" height="32" vertical-align="middle" />',
      );
      expect(
        markdown(':user~fox:', getEmotePacks: () => emotePacks),
        '<img data-mx-emoticon="" src="mxc://userfox" alt=":fox:" title=":fox:" height="32" vertical-align="middle" />',
      );
      expect(
        markdown(':raccoon:', getEmotePacks: () => emotePacks),
        '<img data-mx-emoticon="" src="mxc://raccoon" alt=":raccoon:" title=":raccoon:" height="32" vertical-align="middle" />',
      );
      expect(
        markdown(':invalid:', getEmotePacks: () => emotePacks),
        ':invalid:',
      );
      expect(
        markdown(':invalid:?!', getEmotePacks: () => emotePacks),
        ':invalid:?!',
      );
      expect(
        markdown(':room~invalid:', getEmotePacks: () => emotePacks),
        ':room~invalid:',
      );
    });
    test('pills', () {
      expect(
        markdown('Hey @sorunome:sorunome.de!'),
        'Hey <a href="https://matrix.to/#/@sorunome:sorunome.de">@sorunome:sorunome.de</a>!',
      );
      expect(
        markdown('#fox:sorunome.de: you all are awesome'),
        '<a href="https://matrix.to/#/#fox:sorunome.de">#fox:sorunome.de</a>: you all are awesome',
      );
      expect(
        markdown('!blah:example.org'),
        '<a href="https://matrix.to/#/!blah:example.org">!blah:example.org</a>',
      );
      expect(
        markdown('https://matrix.to/#/#fox:sorunome.de'),
        'https://matrix.to/#/#fox:sorunome.de',
      );
      expect(
        markdown('Hey @sorunome:sorunome.de:1234!'),
        'Hey <a href="https://matrix.to/#/@sorunome:sorunome.de:1234">@sorunome:sorunome.de:1234</a>!',
      );
      expect(
        markdown('Hey @sorunome:127.0.0.1!'),
        'Hey <a href="https://matrix.to/#/@sorunome:127.0.0.1">@sorunome:127.0.0.1</a>!',
      );
      expect(
        markdown('Hey @sorunome:[::1]!'),
        'Hey <a href="https://matrix.to/#/@sorunome:[::1]">@sorunome:[::1]</a>!',
      );
    });
    test('mentions', () {
      expect(
        markdown('Hey @Bob!', getMention: getMention),
        'Hey <a href="https://matrix.to/#/@bob:example.org">@Bob</a>!',
      );
      expect(
        markdown('How is @[Bob Ross] doing?', getMention: getMention),
        'How is <a href="https://matrix.to/#/@bobross:example.org">@[Bob Ross]</a> doing?',
      );
      expect(
        markdown('Hey @invalid!', getMention: getMention),
        'Hey @invalid!',
      );
      expect(
        markdown('Hey @Fox#123!', getMention: getMention),
        'Hey <a href="https://matrix.to/#/@fox:example.org">@Fox#123</a>!',
      );
      expect(
        markdown('Hey @[Fast Fox]#123!', getMention: getMention),
        'Hey <a href="https://matrix.to/#/@fastfox:example.org">@[Fast Fox]#123</a>!',
      );
      expect(
        markdown('Hey @[">]!', getMention: getMention),
        'Hey <a href="https://matrix.to/#/@blah:example.org">@[&quot;&gt;]</a>!',
      );
    });
    test('latex', () {
      expect(
        markdown('meep \$\\frac{2}{3}\$'),
        'meep <span data-mx-maths="\\frac{2}{3}"><code>\\frac{2}{3}</code></span>',
      );
      expect(
        markdown('meep \$hmm *yay*\$'),
        'meep <span data-mx-maths="hmm *yay*"><code>hmm *yay*</code></span>',
      );
      expect(
        markdown('you have \$somevar and \$someothervar'),
        'you have \$somevar and \$someothervar',
      );
      expect(
        markdown('meep ||\$\\frac{2}{3}\$||'),
        'meep <span data-mx-spoiler=""><span data-mx-maths="\\frac{2}{3}"><code>\\frac{2}{3}</code></span></span>',
      );
      expect(
        markdown('meep `\$\\frac{2}{3}\$`'),
        'meep <code>\$\\frac{2}{3}\$</code>',
      );
    });
    test('Code blocks', () {
      expect(
        markdown(
          '```dart\nvoid main(){\nprint(something);\n}\n```',
          convertLinebreaks: true,
        ),
        '<pre><code class="language-dart">void main(){\nprint(something);\n}\n</code></pre>',
      );

      expect(
        markdown(
          'The first \n codeblock\n```dart\nvoid main(){\nprint(something);\n}\n```\nAnd the second code block\n```js\nmeow\nmeow\n```',
          convertLinebreaks: true,
        ),
        '<p>The first<br/>codeblock</p><pre><code class="language-dart">void main(){\nprint(something);\n}\n</code></pre><p>And the second code block</p><pre><code class="language-js">meow\nmeow\n</code></pre>',
      );
    });
  });
}
