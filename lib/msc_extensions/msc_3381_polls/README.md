# Polls

Implementation of [MSC-3381](https://github.com/matrix-org/matrix-spec-proposals/blob/main/proposals/3381-polls.md).

```Dart

// Start a poll:
final pollEventId = await room.startPoll(
    question: 'What do you like more?',
    kind: PollKind.undisclosed,
    maxSelections: 2,
    answers: [
        PollAnswer(
            id: 'pepsi', // You should use `Client.generateUniqueTransactionId()` here
            mText: 'Pepsi,
        ),
        PollAnswer(
            id: 'coca',
            mText: 'Coca Cola,
        ),
    ];
);

// Check if an event is a poll (Do this before performing any other action):
final isPoll = event.type == PollEventContent.startType;

// Get the poll content
final pollEventContent = event.parsedPollEventContent;

// Check if poll has not ended yet (do this before answerPoll or endPoll):
final hasEnded = event.getPollHasBeenEnded(timeline);

// Responde to a poll:
final respondeId = await event.answerPoll(['pepsi', 'coca']);

// Get poll responses:
final responses = event.getPollResponses(timeline);

for(final userId in responses.keys) {
    print('$userId voted for ${responses[userId]}');
}

// End poll:
final endPollId = await event.endPoll();
```