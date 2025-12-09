/// Used to depict the difference between null and undefined in JavaScript
abstract class Maybe<T> {}

class Some<T> extends Maybe<T> {
  Some(this.data);

  final T data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => data.toString();

  @override
  bool operator ==(Object other) {
    return data == other;
  }
}

class Undefined<T> extends Maybe<T> {}
