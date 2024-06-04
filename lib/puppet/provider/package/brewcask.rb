require 'puppet/provider/package'

Puppet::Type.type(:package).provide(:brewcask, parent: Puppet::Provider::Package) do
  desc 'Package management using HomeBrew casks on OSX'

  confine operatingsystem: :darwin

  has_feature :installable
  has_feature :uninstallable
  has_feature :upgradeable
  has_feature :versionable

  has_feature :install_options

  if File.exist?('/usr/local/bin/brew')
    @brewbin = '/usr/local/bin/brew'
    true
  elsif File.exist?('/opt/homebrew/bin/brew')
    @brewbin = '/opt/homebrew/bin/brew'
  end

  commands brew: @brewbin
  commands stat: '/usr/bin/stat'

  def self.execute(cmd, failonfail = false, combine = false)
    owner = stat('-nf', '%Uu', @brewbin).to_i
    group = stat('-nf', '%Ug', @brewbin).to_i
    home  = Etc.getpwuid(owner).dir

    if owner == 0
      raise Puppet::ExecutionFailure, 'Homebrew does not support installations owned by the "root" user. Please check the permissions of /usr/local/bin/brew'
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
      Puppet.debug "Looking for #{install_name} package..."
      execute([command(:brew), :info, '--cask', install_name], failonfail: true)
    rescue Puppet::ExecutionFailure
      raise Puppet::Error, "Could not find package: #{install_name}"
    end

    begin
      Puppet.debug 'Package found, installing...'
      output = execute([command(:brew), :install, '--cask', install_name, *install_options], failonfail: true)

      if %r{sha256 checksum}.include?(output)
        Puppet.debug 'Fixing checksum error...'
        mismatched = output.match(%r{Already downloaded: (.*)}).captures
        fix_checksum(mismatched)
      end
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not install package: #{detail}"
    end
  end

  def uninstall
    Puppet.debug "Uninstalling #{resource_name}"
    execute([command(:brew), :uninstall, '--cask', resource_name], failonfail: true)
  rescue Puppet::ExecutionFailure => detail
    raise Puppet::Error, "Could not uninstall package: #{detail}"
  end

  def update
    Puppet.debug "Updating #{resource_name}"
    install
  end

  def self.package_list(options = {})
    Puppet.debug 'Listing installed packages'
    begin
      if resource_name == options[:justme]
        result = execute([command(:brew), :list, '--cask', '--versions', resource_name])
        if result.empty?
          Puppet.debug "Package #{resource_name} not installed"
        else
          Puppet.debug "Found package #{result}"
        end
      else
        result = execute([command(:brew), :list, '--cask', '--versions'])
      end
      list = result.lines.map { |line| name_version_split(line) }
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not list packages: #{detail}"
    end

    return list.shift if options[:justme]

    list
  end

  def self.name_version_split(line)
    if line =~ (%r{^(\S+)\s+(.+)})
      {
        name: Regexp.last_match(1),
        ensure: Regexp.last_match(2),
        provider: :brewcask
      }
    else
      Puppet.warning "Could not match #{line}"
      nil
    end
  end
end
