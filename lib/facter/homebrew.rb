require 'puppet/util'

Facter.add(:homebrew) do
  confine operatingsystem: 'Darwin'

  has_compiler = if Gem::Version.new(Facter.value('os.macosx.version.major')) >= Gem::Version.new('10.9')
                   (File.exist?('/Applications/Xcode.app') or File.exist?('/Library/Developer/CommandLineTools/')) and
                     (File.exist?('/usr/bin/cc') or system('/usr/bin/xcrun -find cc >/dev/null 2>&1'))
                 else
                   File.exist?('/usr/bin/cc') or system('/usr/bin/xcrun -find cc >/dev/null 2>&1')
                 end
  brew_cmd = Puppet::Util.which('brew')
  brew_prefix = if brew_cmd
                  File.dirname(File.dirname(brew_cmd))
                end

  setcode do
    {
      has_compiler: has_compiler,
      command: brew_cmd,
      prefix: brew_prefix,
    }
  end
end
