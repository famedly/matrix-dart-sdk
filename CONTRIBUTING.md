# Contributing code to Famedly

*See also: Code of Conduct*

We look forward to you joining our team. Everyone is welcome to contribute code via pull requests or to file issues on Gitlab or help other peoples. We communicate primarily over Gitlab and on chat channels. You should be willing to license your contributions under the same license as the project itself.

# How to contribute
The only way to contribute changes to our project is to create a new branch or to fork it on Gitlab. Then create a merge request to ask us to merge your changes into the main branch of our repository. (https://docs.gitlab.com/ee/gitlab-basics/add-merge-request.html)

**The main branch is our development branch where all the work happens.**

## Merge request workflow in detail
- Create a new branch or fork the main branch of the project (Please follow the guidlines below of naming branch and commits)
- Make a merge request to merge your changes into the main branch
- We use the Gitlab merge request workflow to review your contribution
  - Only merge requests with a working CI can be merged
  - Only merge requests with at least one code reviewer of the core team can be merged
  - Only merge requests which are signed-off can be merged
- Merge Requests may be refused if they don't follow the rules below.

**Never ever just push something directly to the main branch!**

## Naming guidelines & code style

### Create a branch

- Branches should get named by this pattern: `username/name-your-changes`.

*That means for example: "alice/fix-this-bug".*

- Use [Conventional Commits](https://www.conventionalcommits.org/)

### File structure:
- File names must be `snake_case`.
- Directories need to be lowercase.

### Code style:
- We recommend using Android Studio or VS Code for coding
- Follow the common Dart style in: https://dart.dev/guides/language/effective-dart/style
- Format the code with `flutter format lib` - otherwise the CI will fail

### Code quality
- Don't repeat yourself! Use local variables, functions, classes.
- Don't mix UI and business logic in the same environment.
- Write tests for new classes, functions and widgets.
- Keep it simple stupid: https://en.wikipedia.org/wiki/KISS_principle
- Describe all of your classes, methods and attributes using **dartdoc** comments. Read this for more information: https://dart.dev/guides/language/effective-dart/documentation
- Don't write functions to create new widgets. Write classes!
- Don't insert unlocalized strings!
- Use Dart extensions to extend class functionality instead of writing wrapper classes!
- Don't mix functions which changes the state of something (functions with a return type of `void` or `Future<void>`) and functional programming which doesn't.

## Sign off
In order to have a concrete record that your contribution is intentional and you agree to license it under the same terms as the project's license, we've adopted the same lightweight approach that [the Linux Kernel](https://www.kernel.org/doc/Documentation/SubmittingPatches), [Docker](https://github.com/docker/docker/blob/master/CONTRIBUTING.md), and many other projects use: the [**DCO - Developer Certificate of Origin**](http://developercertificate.org/). This is a simple declaration that you wrote the contribution or otherwise have the right to contribute it to Matrix:

```
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.
660 York Street, Suite 102,
San Francisco, CA 94110 USA

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.

Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

If you agree to this for your contribution, then all that's needed is to include the line in your commit or merge request comment:

`Signed-off-by: Your Name <your@email.example.org>`

We accept contributions under a legally identifiable name, such as your name on government documentation or common-law names (names claimed by legitimate usage or repute). Unfortunately, we cannot accept anonymous contributions at this time.

Git allows you to add this signoff automatically when using the `-s` flag to `git commit`, which uses the name and email set in your `user.name` and `user.email` git configs.

If you forgot to sign off your commits before making your pull request and are on Git 2.17+ you can mass signoff using rebase:

`git rebase --signoff origin/main`
