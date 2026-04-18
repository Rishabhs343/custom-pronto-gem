# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    enable_coverage :branch
    minimum_coverage line: 90, branch: 80
  end
end

require 'rspec'
require 'pronto'
require 'pronto/rubycritic'
require 'climate_control'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.warnings = false
  config.default_formatter = 'doc' if config.files_to_run.one?
  config.order = :random
  Kernel.srand(config.seed)

  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'tmp/.rspec_status'

  config.before do
    # Reset RubyCritic global config so tests don't bleed state.
    if defined?(RubyCritic::Config) && RubyCritic::Config.respond_to?(:configuration)
      RubyCritic::Config.instance_variable_set(:@configuration, nil)
    end
  end
end
