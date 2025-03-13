import 'package:system_bus/system_bus.dart';
import 'package:test/test.dart';

void main() {
  group('HttpVerb Tests', () {
    test('HttpVerb enum has all required verbs', () {
      expect(HttpVerb.values.length, equals(7)); // Now includes 'head'
      expect(HttpVerb.values, contains(HttpVerb.get));
      expect(HttpVerb.values, contains(HttpVerb.post));
      expect(HttpVerb.values, contains(HttpVerb.put));
      expect(HttpVerb.values, contains(HttpVerb.delete));
      expect(HttpVerb.values, contains(HttpVerb.patch));
      expect(HttpVerb.values, contains(HttpVerb.options));
      expect(HttpVerb.values, contains(HttpVerb.head));
    });

    test('HttpVerb indices are consistent', () {
      expect(HttpVerb.get.index, equals(0));
      expect(HttpVerb.post.index, equals(1));
      expect(HttpVerb.put.index, equals(2));
      expect(HttpVerb.delete.index, equals(3));
      expect(HttpVerb.patch.index, equals(4));
      expect(HttpVerb.options.index, equals(5));
      expect(HttpVerb.head.index, equals(6));
    });
  });
}
