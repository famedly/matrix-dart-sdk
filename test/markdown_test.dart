import 'package:famedlysdk/src/utils/markdown.dart';
import 'package:test/test.dart';

void main() {
  group('markdown', () {
    final emotePacks = {
      'room': {
        ':fox:': 'mxc://roomfox',
        ':bunny:': 'mxc://roombunny',
      },
      'user': {
        ':fox:': 'mxc://userfox',
        ':bunny:': 'mxc://userbunny',
        ':raccoon:': 'mxc://raccoon',
      },
    };
    test('simple markdown', () {
      expect(markdown('hey *there* how are **you** doing?'), 'hey <em>there</em> how are <strong>you</strong> doing?');
      expect(markdown('wha ~~strike~~ works!'), 'wha <del>strike</del> works!');
    });
    test('spoilers', () {
      expect(markdown('Snape killed ||Dumbledoor||'), 'Snape killed <span data-mx-spoiler="">Dumbledoor</span>');
      expect(markdown('Snape killed ||Story|Dumbledoor||'), 'Snape killed <span data-mx-spoiler="Story">Dumbledoor</span>');
    });
    test('multiple paragraphs', () {
      expect(markdown('Heya!\n\nBeep'), '<p>Heya!</p>\n<p>Beep</p>');
    });
    test('Other block elements', () {
      expect(markdown('# blah\n\nblubb'), '<h1>blah</h1>\n<p>blubb</p>');
    });
    test('linebreaks', () {
      expect(markdown('foxies\ncute'), 'foxies<br />\ncute');
    });
    test('emotes', () {
      expect(markdown(':fox:', emotePacks), '<img src="mxc:&#47;&#47;roomfox" alt=":fox:" title=":fox:" height="32" vertical-align="middle" />');
      expect(markdown(':user~fox:', emotePacks), '<img src="mxc:&#47;&#47;userfox" alt=":fox:" title=":fox:" height="32" vertical-align="middle" />');
      expect(markdown(':raccoon:', emotePacks), '<img src="mxc:&#47;&#47;raccoon" alt=":raccoon:" title=":raccoon:" height="32" vertical-align="middle" />');
      expect(markdown(':invalid:', emotePacks), ':invalid:');
      expect(markdown(':room~invalid:', emotePacks), ':room~invalid:');
    });
  });
}
