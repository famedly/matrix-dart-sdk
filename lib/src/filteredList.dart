class FilteredList<T> {
  final bool Function(T) filter;

  final List<T> filtered = [];
  final List<T> unfiltered;

  final void Function(int i)? onInsertCallback;
  final void Function(int i)? onChangeCallback;

  FilteredList(this.unfiltered,
      {required this.filter, this.onInsertCallback, this.onChangeCallback}) {
    filtered.addAll(unfiltered.where(filter));
  }

  void insertAll(int pos, Iterable<T> newItems) {
    final newItemsFiltered = newItems.where(filter);

    unfiltered.insertAll(pos, newItems);
    filtered.insertAll(pos, newItems.where(filter));

    for (var i = 0; i < newItemsFiltered.length; i++) {
      onInsertCallback?.call(i + pos);
    }
  }

  void addAll(List<T> newItems) {
    final offset = filtered.length;
    final newItemsFiltered = newItems.where(filter);

    unfiltered.addAll(newItems);
    filtered.addAll(newItemsFiltered);

    for (var i = 0; i < newItemsFiltered.length; i++) {
      onInsertCallback?.call(i + offset);
    }
  }

  void removeWhere(bool Function(dynamic e) param) {
    unfiltered.removeWhere(param);
    filtered.removeWhere(param);
  }

  void add(T newItem) {
    unfiltered.add(newItem);
    if (filter(newItem)) {
      filtered.add(newItem);
      onInsertCallback?.call(filtered.length - 1);
    }
  }

  void onChange(T event) {
    if (filter(event)) {
      final pos = filtered.indexOf(event);
      onChangeCallback?.call(pos);
    }
  }
}
