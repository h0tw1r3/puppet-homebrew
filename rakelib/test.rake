desc 'Run all tests EXCEPT acceptance'
task test: ['test:static', 'test:doc', 'test:unit']

namespace :test do
  desc 'Run static analysis'
  task static: [:check, :syntax, :lint, :metadata_lint, :rubocop]

  desc 'Run documentation validation'
  task doc: ['strings:validate:reference']

  desc 'Run all unit tests in parallel'
  task unit: [:parallel_spec]

  desc 'Run acceptance tests'
  task acceptance: [:acceptance]
end
