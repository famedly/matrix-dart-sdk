import 'package:random_string/random_string.dart';

import '../../matrix.dart';

class TimelineFragmentList {
  late Map<dynamic, dynamic> fragmentsList;
  Map<dynamic, dynamic> get _fragments => fragmentsList['frags'] ?? {};

  List<String> get fragmentKeys => _fragments.keys.toList().cast<String>();

  TimelineFragmentList(Map? frags) : fragmentsList = frags ?? {'frags': {}};

  TimelineFragment? getFragment(String key) {
    return _getFragmentIterator(key, 0);
  }

  TimelineFragment? _getFragmentIterator(String key, int depth) {
    if (depth > 10) {
      Logs().e('Fragments list max depth search reached.');
      return null;
    }

    if (_fragments[key] == null) return null;

    final frag = TimelineFragment.fromMap(_fragments[key], fragmentId: key);

    if (frag.replacedBy != null) {
      return _getFragmentIterator(frag.replacedBy!, depth + 1);
    }
    return frag;
  }

  void setFragment(String key, TimelineFragment map) {
    if (fragmentsList['frags'] == null) fragmentsList['frags'] = {};
    fragmentsList['frags'][key] = map.map;
  }

  String? _getIdFromBatchKey(String? data) {
    if (data == null) return null;

    for (final key in _fragments.keys) {
      final frag = getFragment(key);

      if (frag != null && (frag.prevBatch == data || frag.nextBatch == data)) {
        return key;
      }
    }

    return null;
  }

  // return a fragment coinciding with this batch
  String getFragmentIdFromBatchId({String? prevBatch, String? nextBatch}) {
    if (prevBatch != null && nextBatch == null) {
      return ''; // it's the last fragment
    }
    return _getIdFromBatchKey(prevBatch) ??
        _getIdFromBatchKey(nextBatch) ??
        randomAlphaNumeric(6);
  }

  TimelineFragment? findFragmentWithEvent({required String eventId}) {
    final id = fragmentsList['frag_map'][eventId];
    return id != null ? getFragment(id) : null;
  }

  // store in which fragment id is store this event. If the event was already store in a different fragment, we return the old fragment id.
  String? storeEventFragment(
      {required String eventId, required String fragId}) {
    if (fragmentsList['frag_map'] == null) fragmentsList['frag_map'] = {};

    final oldFragment = fragmentsList['frag_map'][eventId];

    if (oldFragment != fragId) {
      fragmentsList['frag_map'][eventId] = fragId;
      return oldFragment;
    }

    return null;
  }

  TimelineFragment mergeFragments(String fragId, String oldFragId) {
    final fragA = getFragment(fragId)!;
    final fragB = getFragment(oldFragId)!;

    var fragMain = fragA;
    var fragSecondary = fragB;

    if (fragB.isRoot) {
      fragMain = fragB;
      fragSecondary = fragA;
    }

// TODO: properly merge timelines
    fragMain.eventsId.addAll(fragSecondary.eventsId);

    // at the end, we replace the eventId
    fragSecondary.setReplacementFragmentID(fragMain.fragmentId);
    fragSecondary.eventsId = [];

    return fragMain;
  }
}
