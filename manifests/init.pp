# @summary deploy homebrew package support
#
# @param user
# @param command_line_tools_package
# @param command_line_tools_source
# @param github_token
# @param group
# @param multiuser
#
class homebrew (
  String           $user,
  Optional[String] $command_line_tools_package = undef,
  Optional[String] $command_line_tools_source  = undef,
  Optional[String] $github_token               = undef,
  String           $group                      = 'admin',
  Boolean          $multiuser                  = false,
) {
  if $facts.get('os.name') != 'Darwin' {
    fail('This module only works on Mac OSX!')
  }

  if $homebrew::user == 'root' {
    fail('Homebrew does not support installation as the "root" user.')
  }

  class { 'homebrew::compiler': }
  -> class { 'homebrew::install': }

  contain 'homebrew::compiler'
  contain 'homebrew::install'

  if $homebrew::github_token {
    file { '/etc/environment': ensure => file }
    -> file_line { 'homebrew-github-api-token':
      path  => '/etc/environment',
      line  => "HOMEBREW_GITHUB_API_TOKEN=${homebrew::github_token}",
      match => '^HOMEBREW_GITHUB_API_TOKEN',
    }
  }
}
