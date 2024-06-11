# @summary install compiler
#
# @api private
class homebrew::compiler {
  if $facts.get('homebrew.has_compiler') {
  } elsif versioncmp($facts.get('os.macosx.version.full'), '10.7') < 0 {
    warning('Command Line Tools bundled with XCode must be installed manually!')
  } elsif ($homebrew::command_line_tools_package and $homebrew::command_line_tools_source) {
    notice('Installing Command Line Tools.')

    package { $homebrew::command_line_tools_package:
      ensure   => present,
      provider => pkgdmg,
      source   => $homebrew::command_line_tools_source,
    }
  } else {
    warning('No Command Line Tools detected and no download source set. Set package and source or install manually.')
  }
}
