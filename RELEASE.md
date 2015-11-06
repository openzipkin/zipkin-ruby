## Release Process

* tag the commit `git tag -v0.0.0`
* push tags to origin `git push origin --tags`
* Travis will automatically build and push to rubygems
* TODO: have travis push the tag using info from version.rb
