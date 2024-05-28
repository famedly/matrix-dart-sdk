enum PushRuleState {
  notify,
  mentionsOnly,
  dontNotify,
}

enum JoinRules {
  public('public'),
  knock('knock'),
  invite('invite'),
  private('private'),
  restricted('restricted'),
  knockRestricted('knock_restricted');

  const JoinRules(this.text);

  final String text;
}

enum GuestAccess {
  canJoin('can_join'),
  forbidden('forbidden');

  const GuestAccess(this.text);

  final String text;
}

enum HistoryVisibility {
  invited('invited'),
  joined('joined'),
  shared('shared'),
  worldReadable('world_readable');

  const HistoryVisibility(this.text);

  final String text;
}
