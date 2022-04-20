import 'package:random_string/random_string.dart';

import '../../matrix.dart';

class TimelineFragmentList {
  late Map<dynamic, dynamic> fragmentsList;
  Map<dynamic, dynamic> get _fragments => fragmentsList['frags'] ?? {};

  List<String> get fragmentKeys => _fragments.keys.toList().cast<String>();

  TimelineFragmentList(Map? frags) : fragmentsList = frags ?? {'frags': {}};

  /// Return the actual fragment or the fragment by which it has been remplaced.
  TimelineFragment? getFragment(String key, {bool followRedirect = true}) {
    if (!followRedirect) {
      return TimelineFragment.fromMap(_fragments[key], fragmentId: key);
    }

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
  String getFragmentIdFromBatchAnchors({String? prevBatch, String? nextBatch}) {
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

  /// store in wich fragment id is stored this event.
  /// If the event was stored in an other fragment which hasn't been
  /// replaced, we return the old fragment Id.
  String? storeEventFragReference(
      {required String eventId, required String fragId}) {
    if (fragmentsList['frag_map'] == null) fragmentsList['frag_map'] = {};

    final oldFragment = fragmentsList['frag_map'][eventId];

    if (oldFragment != fragId) {
      fragmentsList['frag_map'][eventId] = fragId;

      // in case of with
      if (oldFragment != null) {
        final frag = getFragment(oldFragment, followRedirect: false);
        if (frag?.isRedirect == false) {
          return oldFragment;
        }
      }
    }

    return null;
  }

  TimelineFragment mergeFragments(TimelineFragment fragA, String oldFragId) {
    final fragB = getFragment(oldFragId, followRedirect: false);
    Logs().w(
        'Merge: Pre ${fragA.fragmentId} and ${fragB?.fragmentId} old: $oldFragId');

    if (fragB == null) return fragA;

    var fragMain = fragA;
    var fragSecondary = fragB;

    if (fragB.isRoot) {
      fragMain = fragB;
      fragSecondary = fragA;
    }

    Logs().w(
        'Merge: Post ${fragMain.fragmentId} and ${fragSecondary.fragmentId} old: $oldFragId');

    // TODO: properly merge timelines
    fragMain.eventsId.addAll(fragSecondary.eventsId);

    // at the end, we replace the eventId
    fragSecondary.setReplacementFragmentID(fragMain.fragmentId);
    fragSecondary.eventsId = [];

    setFragment(fragSecondary.fragmentId, fragSecondary);


    

    return fragMain;
  }
}
