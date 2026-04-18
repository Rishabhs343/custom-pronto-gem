# frozen_string_literal: true

# Pronto runner for RubyCritic. Analyses Ruby files changed in a PR and reports
# reek/flay/flog/complexity/churn smells via Pronto::Message — only on lines that
# were added or modified in the diff.

require 'pronto'
require 'rubycritic'
require 'rubycritic/analysers_runner'

require_relative 'rubycritic/version'
require_relative 'rubycritic/config_loader'
require_relative 'rubycritic/analyser'
require_relative 'rubycritic/smell_filter'
require_relative 'rubycritic/formatter'
require_relative 'rubycritic/message_builder'

module Pronto
  class RubyCritic < Runner
    VERSION        = RubyCriticVersion::VERSION
    VALID_LEVELS   = %i[info warning error fatal].freeze
    DEFAULT_LEVEL  = :warning
    CONFIG_FILE    = '.rubycritic-pronto.yml'
    SEVERITY_ENV   = 'PRONTO_RUBYCRITIC_SEVERITY_LEVEL'
    LEGACY_ENV     = 'PRONTO_REEK_SEVERITY_LEVEL'
    RAISE_ENV      = 'PRONTO_RUBYCRITIC_RAISE_ERRORS'
    DEBUG_ENV      = 'PRONTO_RUBYCRITIC_DEBUG'

    def run
      patches = ruby_patches
      return [] if patches.nil? || patches.empty?

      process(patches)
    rescue Errno::ENOENT => e
      handle_missing_file(e)
      []
    rescue StandardError => e
      report_error(e)
      raise if ENV[RAISE_ENV]

      []
    end

    private

    def process(patches)
      modules  = Analyser.new(file_paths).call
      filtered = SmellFilter.new(runner_config).call(modules)
      MessageBuilder.new(
        runner: self,
        patches: patches,
        severity_level: severity_level
      ).call(filtered)
    end

    # Pronto's ruby_executable? helper does File.read(path, 2) on every
    # patched path to check for a shebang; when the working tree is missing
    # a file that's in the diff range, it raises Errno::ENOENT. Translate
    # that into a human-readable message that points at `git status`.
    def handle_missing_file(error)
      warn(
        'pronto-rubycritic: working tree is missing a file referenced in ' \
        "the diff: #{error.message}. Run `git status` to reconcile."
      )
      raise if ENV[RAISE_ENV]
    end

    def file_paths
      @file_paths ||= ruby_patches.map { |p| p.new_file_full_path.to_s }
    end

    def runner_config
      @runner_config ||= ConfigLoader.load_runner_config(CONFIG_FILE)
    end

    def pronto_config
      @pronto_config ||= ConfigLoader.load_pronto_config
    end

    def severity_level
      @severity_level ||= ConfigLoader.resolve_severity(
        env_value: ENV[SEVERITY_ENV] || legacy_severity_env,
        pronto_config: pronto_config,
        valid_levels: VALID_LEVELS,
        default: DEFAULT_LEVEL
      )
    end

    def legacy_severity_env
      value = ENV.fetch(LEGACY_ENV, nil)
      return nil if value.nil? || value.to_s.strip.empty?

      warn("pronto-rubycritic: #{LEGACY_ENV} is deprecated; use #{SEVERITY_ENV}.")
      value
    end

    def report_error(error)
      warn("pronto-rubycritic: #{error.class}: #{error.message}")
      return unless ENV[DEBUG_ENV]

      warn(Array(error.backtrace).first(10).join("\n"))
    end
  end
end
