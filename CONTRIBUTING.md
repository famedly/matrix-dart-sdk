# Contributing code to famedly talk

Everyone is welcome to contribute code to matrix-js-sdk, provided that they are willing to license their contributions under the same license as the project itself.
Please follow these rules when contributing code to famedly talk:

## Merge Requests:
- Never ever just push something directly to the master branch!
- Create a new branch or fork this project and send a Merge Request.
- Only Merge Requests with a working CI can be merged.
- Only Merge Requests with at least one code reviewer can be merged.
- Merge Requests may be refused if they don't follow the rules below.

## File structure:
- Every file must be named by the class and must be capitalized in the beginning.
- Directories need to be lowercase.

## Code style:
- We recommend to use Android Studio for coding. We are using the Android Studio auto styling with ctrl+alt+shift+L.

## Code quality:
- Don't repeat yourself! Use local variables, functions, classes.
- Don't mix UI and business logic in the same enivornment.
- Write tests for new classes, functions and widgets.
- Keep it simple stupid: https://en.wikipedia.org/wiki/KISS_principle
- Describe all of your classes, methods and attributes using **dartdoc** comments. Read this for more informations: https://dart.dev/guides/language/effective-dart/documentation