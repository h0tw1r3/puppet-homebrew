# Colorize Strings
class String
  def cyan;           "\e[36m#{self}\e[0m" end
  def bold;           "\e[1m#{self}\e[22m" end
end

begin
  require 'metadata_json_lint'

  # PDK validate behaviors
  MetadataJsonLint.options.fail_on_warnings = true
  MetadataJsonLint.options.strict_license = true
  MetadataJsonLint.options.strict_puppet_version = true
  MetadataJsonLint.options.strict_dependencies = true
rescue
  # ignore
end

begin
  PuppetLint.configuration.log_forat = '%{path}:%{line}:%{check}:%{KIND}:%{message}'
  PuppetLint.configuration.fail_on_warnings = true
  PuppetLint.configuration.ignore_paths.reject! { |c| c == 'spec/**/*.pp' }
  PuppetLint.configuration.ignore_paths << 'spec/fixtures/**/*.pp'
rescue
  # ignore
end

begin
  require 'dependency_checker'
  desc 'Run dependency-checker'
  task :metadata_deps do
    dpc = DependencyChecker::Runner.new
    dpc.resolve_from_files(['metadata.json'])
    dpc.run
    raise 'dependency checker failed' unless dpc.problems.zero?
  end
rescue LoadError
  # ignore
end

# output task execution
unless Rake.application.options.trace
  setup = ->(task, *_args) do
    puts '==> rake '.cyan + task.to_s.bold.cyan
  end

  task :log_hooker do
    Rake::Task.tasks.reject { |t| t.to_s == 'log_hooker' }.each do |a_task|
      a_task.actions.prepend(setup)
    end
  end
  Rake.application.top_level_tasks.prepend(:log_hooker)
end
