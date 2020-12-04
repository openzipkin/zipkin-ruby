# OpenZipkin Release Process

This repo uses semantic versions. Please keep this in mind when choosing version numbers.

1. **Alert others you are releasing**

   There should be no commits made to master while the release is in progress (about 10 minutes). Before you start
   a release, alert others on [gitter](https://gitter.im/openzipkin/zipkin) so that they don't accidentally merge
   anything. If they do, and the build fails because of that, you'll have to recreate the release tag described below.

1. **Push a git tag**

   The tag should formatted `MAJOR.MINOR.PATCH`, ex `git tag 1.18.1 && git push origin 1.18.1`.

1. **Wait for CI**

   The `MAJOR.MINOR.PATCH` tag triggers [`build-bin/deploy`](build-bin/deploy), which does the following:
     * https://rubygems.org/gems/zipkin-tracer [`build-bin/gem/gem_push`](build-bin/gem/gem_push)

## Credentials

The release process uses various credentials. If you notice something failing due to unauthorized,
look at the notes in [.github/workflows/deploy.yml] and check the [org secrets](https://github.com/organizations/openzipkin/settings/secrets/actions).

## Manually releasing

If for some reason, you lost access to CI or otherwise cannot get automation to work, bear in mind
this is a normal ruby project, and can be released accordingly.

```bash
# First, set variable according to your personal credentials. These would normally be assigned as
# org secrets: https://github.com/organizations/openzipkin/settings/secrets/actions
export RUBYGEMS_API_KEY=your_api_key
release_version=xx-version-to-release-xx

# now from latest master, create the MAJOR.MINOR.PATCH tag
git tag ${release_version}

# Run the deploy using the version you added as a tag
./build-bin/deploy ${release_version}

# Finally, push the tag
git push origin ${release_version}
```
