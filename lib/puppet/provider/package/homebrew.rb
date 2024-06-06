require 'puppet/provider/package'

Puppet::Type.type(:package).provide(:homebrew, parent: Puppet::Provider::Package) do
  desc 'Package management using HomeBrew (+ casks!) on OSX'

  confine operatingsystem: :darwin

  has_feature :installable
  has_feature :uninstallable
  has_feature :upgradeable
  has_feature :versionable

  has_feature :install_options

  commands brew: Facter.value('homebrew.command')
  commands stat: '/usr/bin/stat'

  def self.execute(cmd, failonfail = false, combine = false)
    owner = stat('-nf', '%Uu', command(:brew)).to_i
    group = stat('-nf', '%Ug', command(:brew)).to_i
    home  = Etc.getpwuid(owner).dir

    if owner == 0
      raise Puppet::ExecutionFailure, "Homebrew does not support installations owned by the root user. Please check the permissions of #{command(:brew)}"
    end

    # the uid and gid can only be set if running as root
    if Process.uid == 0
      uid = owner
      gid = group
    else
      uid = nil
      gid = nil
    end

    if Puppet.features.bundled_environment?
      Bundler.with_clean_env do
        super(cmd, uid: uid, gid: gid, combine: combine,
              custom_environment: { 'HOME' => home }, failonfail: failonfail)
      end
    else
      super(cmd, uid: uid, gid: gid, combine: combine,
            custom_environment: { 'HOME' => home }, failonfail: failonfail)
    end
  end

  def self.instances(_justme = false)
    package_list.map { |hash| new(hash) }
  end

  def execute(*args)
    # This does not return exit codes in puppet <3.4.0
    # See https://projects.puppetlabs.com/issues/2538
    self.class.execute(*args)
  end

  def fix_checksum(files)
    begin
      files.each do |file|
        File.delete(file)
      end
    rescue Errno::ENOENT
      Puppet.warning "Could not remove mismatched checksum files #{files}"
    end

    raise Puppet::ExecutionFailure, "Checksum error for package #{name} in files #{files}"
  end

  def resource_name
    if %r{^https?://}.match?(@resource[:name])
      @resource[:name]
    else
      @resource[:name].downcase
    end
  end

  def install_name
    should = @resource[:ensure].downcase

    case should
    when true, false, Symbol
      resource_name
    else
      "#{resource_name}@#{should}"
    end
  end

  def install_options
    Array(resource[:install_options]).flatten.compact
  end

  def latest
    package = self.class.package_list(justme: resource_name)
    package[:ensure]
  end

  def query
    self.class.package_list(justme: resource_name)
  end

  def install
    begin
      Puppet.debug "Looking for #{install_name} package on brew..."
      output = execute([command(:brew), :info, install_name], failonfail: true)

      Puppet.debug 'Package found, installing...'
      output = execute([command(:brew), :install, install_name, *install_options], failonfail: true)

      if %r{sha256 checksum}.include?(output)
        Puppet.debug 'Fixing checksum error...'
        mismatched = output.match(%r{Already downloaded: (.*)}).captures
        fix_checksum(mismatched)
      end
    rescue Puppet::ExecutionFailure
      Puppet.debug "Package #{install_name} not found on Brew. Trying BrewCask..."
      execute([command(:brew), :info, '--cask', install_name], failonfail: true)

      Puppet.debug 'Package found on brewcask, installing...'
      output = execute([command(:brew), :install, '--cask', install_name, *install_options], failonfail: true)

      if %r{sha256 checksum}.include?(output)
        Puppet.debug 'Fixing checksum error...'
        mismatched = output.match(%r{Already downloaded: (.*)}).captures
        fix_checksum(mismatched)
      end
    end
  rescue Puppet::ExecutionFailure => detail
    raise Puppet::Error, "Could not install package: #{detail}"
  end

  def uninstall
    Puppet.debug "Uninstalling #{resource_name}"
    execute([command(:brew), :uninstall, resource_name], failonfail: true)
  rescue Puppet::ExecutionFailure
    begin
      execute([command(:brew), :uninstall, '--cask', resource_name], failonfail: true)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not uninstall package: #{detail}"
    end
  end

  def update
    Puppet.debug "Updating #{resource_name}"
    install
  end

  def self.package_list(options = {})
    Puppet.debug 'Listing installed packages'

    cmd_line = [command(:brew), :list, '--versions']
    if options[:justme]
      cmd_line += [ options[:justme] ]
    end

    begin
      cmd_output = execute(cmd_line)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not list packages: #{detail}"
    end

    # Exclude extraneous lines from stdout that interfere with the parsing
    # logic below.  These look like they should be on stderr anyway based
    # on comparison to other output on stderr.  homebrew bug?
    re_excludes = Regexp.union([
                                 %r{^==>.*},
                                 %r{^Tapped \d+ formulae.*},
                               ])
    lines = cmd_output.lines.delete_if { |line| line.match(re_excludes) }

    if options[:justme]
      if lines.empty?
        Puppet.debug "Package #{options[:justme]} not installed"
        nil
      else
        if lines.length > 1
          Puppet.warning "Multiple matches for package #{options[:justme]} - using first one found"
        end
        line = lines.shift
        Puppet.debug "Found package #{line}"
        name_version_split(line)
      end
    else
      lines.map { |l| name_version_split(l) }
    end
  end

  def self.name_version_split(line)
    if line =~ (%r{^(\S+)\s+(.+)})
      {
        name: Regexp.last_match(1),
        ensure: Regexp.last_match(2).split(' '),
        provider: :homebrew
      }
    else
      Puppet.warning "Could not match #{line}"
      nil
    end
  end
end
