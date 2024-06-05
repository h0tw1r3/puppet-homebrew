# puppet-homebrew

[![Build Status][workflow-ci-badge]][workflow-ci]
[![Puppet Forge][badge-version]][forge-module]
[![Puppet Forge - downloads][badge-downloads]][forge-module]
[![Puppet Forge - scores][badge-score]][forge-module]
[![License][badge-license]](LICENSE)

Puppet module to install [Homebrew] and manage [Homebrew] packages on Mac OSX.

Package providers are included which can install brew formulae, casks, or
automatically attempt both types.

## Usage

### Installing Brew

To install Homebrew on a node (with a compiler already present!):

```pp
class { 'homebrew':
  user      => 'hightower',
  group     => 'developers',  # defaults to 'admin'
  multiuser => false,         # set to true to enable multiuser support for homebrew
}
```

Installing Homebrew as the root user is no longer supported (as of late 2016).
Please ensure you install brew as a standard (non-root) user.

Note that some users have reported confusion between the *puppet* user and the
*homebrew* user -- it is perfectly fine to run puppet as root, in fact this is
encouraged, but the Homebrew user must be non-root (generally, the system's main
user account).

If you run puppet as a non-root user and set the `homebrew::user` to a
*different* non-root user, you may run into issues; namely, since this module
requires the puppet user act as the Homebrew user, you may get a password
prompt on each run. This can be fixed by allowing the puppet user password-less
sudo privileges to the Homebrew user.

If you are looking for a multi-user installation, please be sure to set the
multi-user flag, eg.:

```pp
class { 'homebrew':
  user      => 'kevin',
  group     => 'all-users',
  multiuser => true,
}
```

To install Homebrew and a compiler (on Lion or later), eg.:

```pp
class { 'homebrew':
  user                       => 'kevin',
  command_line_tools_package => 'command_line_tools_for_xcode_os_x_lion_april_2013.dmg',
  command_line_tools_source  => 'http://devimages.apple.com/downloads/xcode/command_line_tools_for_xcode_os_x_lion_april_2013.dmg',
}
```

N.B. the author of this module does not maintain a mirror to command_line_tools.
You may need to search for a copy if you use this method. At the time of this
writing, downloading the command line tools sometimes requires an Apple ID.
Sorry, dude!

#### Adding a Github Token

[Homebrew] uses a [Github token] in your environment to make your experience better
by:

* Reducing the rate limit on `brew search` commands
* Letting you tap your private repositories
* Allowing you to upload Gists of brew installation errors

To enable this feature, you can include:

```pp
class { 'homebrew':
  user         => 'kevin',
  github_token => 'MyT0k3n!',
}
```

### Installing Packages

Use the Homebrew package provider like this:

```pp
class hightower::packages {
  pkglist = ['postgresql', 'nginx', 'git', 'tmux']

  package { $pkglist:
    ensure   => present,
    provider => brew,
  }
}
```

The providers work as follows:

* **brew**  
  install using `brew install <name>`.
* **brewcask**  
  install using `brew cask install <name>`.
* **homebrew**  
  attempt to install using `brew install <name>`. On failure, use
  `brew cask install <module>`

### Taps (Third-Party Repositories)

To tap into new Github repositories, simply use the tap provider:

```pp
package { 'neovim/neovim':
  ensure   => present,
  provider => tap,
}
```

You can untap a repository by setting ensure to `absent`.

#### Ordering Taps

When both tapping a repo and installing a package from that repository, it is
important to make sure the former happens first. This can be accomplished in a
few different ways: either by doing so on a per-package basis:

```pp
package { 'neovim/neovim':
  ensure   => present,
  provider => tap,
}
-> package { 'neovim':
  ensure   => present,
  provider => homebrew,
}
```

Or by setting all taps to occur before all other usages of this package with
[Resource Collectors]:

```pp
# pick whichever provider(s) are relevant
Package <| provider == tap |> -> Package <| provider == homebrew |>
Package <| provider == tap |> -> Package <| provider == brew |>
Package <| provider == tap |> -> Package <| provider == brewcask |>
```

## Authors

This module was forked from, but **incompatible with**, [thekevjames/homebrew].
Original credit for this module goes to [kelseyhightower].

[Homebrew]: https://brew.sh

[Github token]: https://github.com/settings/tokens/new?scopes=&description=Homebrew
[kelseyhightower]: https://github.com/kelseyhightower
[Resource Collectors]: https://docs.puppet.com/puppet/latest/reference/lang_collectors.html

[workflow-ci]: https://github.com/h0tw1r3/puppet-homebrew/actions/workflows/ci.yml
[workflow-ci-badge]: https://github.com/h0tw1r3/puppet-homebrew/actions/workflows/ci.yml/badge.svg
[workflow-release]: https://github.com/h0tw1r3/puppet-homebrew/actions/workflows/release.yml
[workflow-release-badge]: https://github.com/h0tw1r3/puppet-homebrew/actions/workflows/release.yml/badge.svg

[forge-module]: https://forge.puppetlabs.com/h0tw1r3/homebrew
[badge-version]: https://img.shields.io/puppetforge/v/h0tw1r3/homebrew.svg
[badge-downloads]: https://img.shields.io/puppetforge/dt/h0tw1r3/homebrew.svg
[badge-score]: https://img.shields.io/puppetforge/qualityscore/h0tw1r3/homebrew.svg

[badge-license]: https://img.shields.io/badge/License-Apache_2.0-blue.svg

[thekevjames/homebrew]: https://forge.puppetlabs.com/thekevjames/homebrew
