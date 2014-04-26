
![](http://vexx.us/Images/poison1.png)
***
**Build Status**:

* **Travis**: [![](https://travis-ci.org/stal888/Poison.svg?branch=2.0)][travis]  
* **Tox Jenkins**: [![](http://jenkins.tox.im/buildStatus/icon?job=Poison2_OSX)][jenkins]  

Poison is a Mac client for [Tox](https://github.com/irungentoo/ProjectTox-Core),
with support for file sharing, multiple profiles, group messaging, and more. 
Built with precision and care, Poison follows strict guidelines to maintaining 
the look and feel of OS X. While it's still in its infancy stage, most of 
Poison's features work, but support for A/V is in the works as more features 
are in the works.

*Please make any further pull requests to the 2.0 branch (this one).*

![](http://vexx.us/Examples/Poison/lady_stoneheart.png)

Poison is built to support Notification Center, so you never miss a message, 
and with an extensive array of options, you can customize Poison to be your 
own.

![Notification](http://vexx.us/Images/notification-group.png)
![Another notification](http://vexx.us/Images/notification-online.png)

## Downloads

You can download nightly versions of Poison, which are automatically built for 
every commit made [here][jenkins-archive].

Poison can also be built manually.
```
git submodule update --init --recursive
xcodebuild -project Poison2x.xcodeproj -target Poison \
           -configuration Release CODE_SIGN_IDENTITY="" SYMROOT=build/
```
Other dependencies will be pulled in automatically.

## Contribution Guidelines
### Coding
* If you break compatibility with 10.7, I will break you.

### Translations
0. (If you don't have Xcode installed, skip this step) Run
   `./translation_helper.sh genstrings` in the project root.
1. `cd` to `resources/strings`.
2. Copy `en.lproj` to a folder for your language's code. Apple tells you
   how to figure those out [here][apple-doc-lang-codes].
3. Translate the `Localizable.strings` file in your new folder.
4. (If you don't have Xcode installed, skip this step) Run
   `./translation_helper.sh update` in the project root. It might spit out some
   warnings, just ignore them.
5. `cd` to `resources/interfaces/TL/strings`. Again, copy `en.lproj` to a new
   folder, with the same code you used in step 2.
6. Translate the files in your new folder.
7. Do the GitHub thing.
8. You are done! Thank you for helping translate Poison.

### Translation text

- For menus: if the option will take you to another part of the UI 
  (say, pop up a sheet), suffix it with an ellipse.
- Do not translate the word "Tox" or the word "Poison" where they are used as 
  proper nouns.
- Keep word choice consistent (e.g. do not refer to a friend as "Contact" in 
  one window, then "Friend" in another)

## Automatic Bootstrapping

Starting with 1.1.3, Poison has the ability to automagically find the best Tox 
bootstrap server to connect to. Users still have the option to specify a custom 
Tox Node.

## Licensing

* My code is licensed under a BSD 3-clause license. Please see LICENSE.md.
* However, linking to other projects causes this to actually be GPLv3.
* Images assets are free for you to use, except the icon.

## Donate

If you really want to, you can send me (!wafuu8CaXg) a fraction of a bitcoin or
something: `1N191yTJkwebUxmaNFg9Krb5dN6cqyGavi`

[travis]: https://travis-ci.org/stal888/Poison
[jenkins]: http://jenkins.tox.im/job/Poison2_OSX/
[jenkins-archive]: http://jenkins.tox.im/job/Poison2_OSX/lastSuccessfulBuild/artifact/poison/release.zip
[apple-doc-lang-codes]: https://developer.apple.com/library/mac/documentation/macosx/conceptual/bpinternational/Articles/LanguageDesignations.html
