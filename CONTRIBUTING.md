# Contributing code to Matrix API Lite

Everyone is welcome to contribute code to Matrix API Lite, provided that they are willing to license their contributions under the same license as the project itself.
Please follow these rules when contributing code to Matrix API Lite:

## Merge Requests:
- Never ever just push something directly to the main branch!
- Create a new branch or fork this project and send a Merge Request.
- Only Merge Requests with a working CI can be merged.
- Only Merge Requests with at least one code reviewer can be merged.
- Merge Requests may be refused if they don't follow the rules below.
- A new Merge Request SHOULD never decrease the test coverage.

## Branches
### Naming

Branches should get named by this pattern: `[Author]/[Description]`.

## Commit Messages

Please use [conventional commit messages](https://www.conventionalcommits.org/en/v1.0.0-beta.2/).

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
- Write tests for new classes, functions and widgets.
- Keep it simple stupid: https://en.wikipedia.org/wiki/KISS_principle
- Describe all of your classes, methods and attributes using **dartdoc** comments. Read this for more information: https://dart.dev/guides/language/effective-dart/documentation