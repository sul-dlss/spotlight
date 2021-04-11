# Contributing to Spotlight

Spotlight is a collaborative, open source project produced by developers, designers, product owners from several organizations. Spotlight mostly uses the [contribution model](https://github.com/projectblacklight/blacklight/blob/master/CONTRIBUTING.md) from its parent project [Blacklight](https://github.com/projectblacklight/blacklight). There are a few differences from the Blacklight process that this document will highlight.

## User experience changes

Spotlight has been designed by a team of user experience designers. While there are a lot of great opportunities to improve the user experience, sometimes contributions that seem to make sense in a specific context can negatively affect the broader user experience of Spotlight that we've worked hard over the years to improve. When contributing updates or changes to the Spotlight user experience here are some useful guidelines to follow.
 - Determine if there is a way to contribute this in a backwards compatible or configurable way
 - [Open an issue](https://github.com/projectblacklight/spotlight/issues/new) on the project as a way to engage with core UX designers and developers on your proposed change or update
 - Contribute user stories to an issue or engage with the Spotlight community through the [Blacklight Development Google group](https://groups.google.com/forum/#!forum/blacklight-development)


## Other notes

Because Spotlight is a large codebase that has been developed and maintained over several years, we encourage some additional guidelines around contributing.

 - Make sure a clear and atomic commit history is represented in a pull request. Not every thought needs to be expressed but commits should demonstrate why. Summarized by @eileencodes very well here: https://twitter.com/eileencodes/status/1179767021363486722
 - Use of `git rebase` is encouraged to maintain future readers of your Git history
 - Backwards compatibility and deprecation notices are preferred for breaking API and user facing changes
 
