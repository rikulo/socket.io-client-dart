import 'package:test/test.dart';
import 'package:socket_io_client/src/engine/parseqs.dart';

void main() {
  group('parseqs.encode', () {
    test('encodes a simple map into a query string', () {
      expect(encode({'foo': 'bar'}), equals('foo=bar'));
    });

    test('encodes multiple key-value pairs with & separator', () {
      final result = encode({'a': '1', 'b': '2'});
      expect(result, contains('a=1'));
      expect(result, contains('b=2'));
      expect(result, contains('&'));
    });

    test('percent-encodes special characters in keys and values', () {
      expect(encode({'hello world': 'foo bar'}),
          equals('hello%20world=foo%20bar'));
    });

    test('encodes an empty map into an empty string', () {
      expect(encode({}), equals(''));
    });

    test('encodes numeric values as strings', () {
      expect(encode({'port': 3000}), equals('port=3000'));
    });
  });

  group('parseqs.decode', () {
    test('decodes a simple query string into a map', () {
      final result = decode('foo=bar');
      expect(result['foo'], equals('bar'));
    });

    test('decodes multiple key-value pairs', () {
      final result = decode('a=1&b=2&c=3');
      expect(result['a'], equals('1'));
      expect(result['b'], equals('2'));
      expect(result['c'], equals('3'));
    });

    test('decodes percent-encoded characters', () {
      final result = decode('hello%20world=foo%20bar');
      expect(result['hello world'], equals('foo bar'));
    });

    test('returns an empty map for an empty string', () {
      expect(decode(''), isEmpty);
    });

    test('handles a key-only param without throwing', () {
      // Previously threw RangeError on pair[1]
      final result = decode('flag');
      expect(result['flag'], equals(''));
    });

    test('handles mixed normal and key-only params without throwing', () {
      final result = decode('a=1&flag&c=3');
      expect(result['a'], equals('1'));
      expect(result['flag'], equals(''));
      expect(result['c'], equals('3'));
    });

    test('encode and decode round-trip preserves values', () {
      final original = {'key': 'value', 'num': '42'};
      final encoded = encode(original);
      final decoded = decode(encoded);
      expect(decoded['key'], equals('value'));
      expect(decoded['num'], equals('42'));
    });
  });
}
