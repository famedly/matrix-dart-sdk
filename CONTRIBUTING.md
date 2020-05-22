# Contributing code to famedly talk

Everyone is welcome to contribute code to FamedlySDK, provided that they are willing to license their contributions under the same license as the project itself.
Please follow these rules when contributing code to famedly talk:

## Merge Requests:
- Never ever just push something directly to the master branch!
- Create a new branch or fork this project and send a Merge Request.
- Only Merge Requests with a working CI can be merged.
- Only Merge Requests with at least one code reviewer can be merged.
- Merge Requests may be refused if they don't follow the rules below.
- A new Merge Request SHOULD never decrease the test coverage.

## Branches
### Naming

Branches should get named by this pattern: `[Module Name]-[Type]-[Detail]`.

That means for example: "users-fix-attach-roles-issue#765".

Modules are various parts of the App. This can for example be the directory list or the chat room.

Types can be one of these:
- **feature**
- **enhance**
- **cleanup**
- **refactor**
- **fix**
- **hotfix** (should rarely get used)

The Detail part of the pattern should be a short description of what the branch delivers.

## Commit Messages

Commit Messages should get written in this pattern: `[[Module Name]] [Commit Message]`.
That means for example: "[users] add fetch users endpoint".


## File structure:
- Every file must be named by the class and must be capitalized in the beginning.
- Directories need to be lowercase.

## Code style:
Please use code formatting. You can use VSCode or Android Studio. On other editors you need to run:
```
flutter format lib/**/*/*.dart
```

## Code quality:
- Don't repeat yourself! Use local variables, functions, classes.
- Don't mix UI and business logic in the same environment.
- Write tests for new classes, functions and widgets.
- Keep it simple stupid: https://en.wikipedia.org/wiki/KISS_principle
- Describe all of your classes, methods and attributes using **dartdoc** comments. Read this for more informations: https://dart.dev/guides/language/effective-dart/documentation