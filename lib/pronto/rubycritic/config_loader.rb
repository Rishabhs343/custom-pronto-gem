# frozen_string_literal: true

require 'yaml'
require 'pronto/config_file'

module Pronto
  class RubyCritic < Runner
    module ConfigLoader
      module_function

      def load_runner_config(filename, cwd: Dir.pwd)
        path = File.join(cwd, filename)
        return {} unless File.exist?(path)

        parsed = YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true)
        return parsed if parsed.is_a?(Hash)
        return {} if parsed.nil?

        # YAML like ":\n:\n- [" parses to a Symbol / Array / scalar — not a
        # Hash. SmellFilter expects a Hash (calls #dig). Reject anything else.
        warn("pronto-rubycritic: #{filename} must be a YAML mapping (Hash); " \
             "got #{parsed.class}. Ignoring.")
        {}
      rescue Psych::SyntaxError, Psych::DisallowedClass => e
        warn("pronto-rubycritic: invalid YAML in #{filename}: #{e.class}: #{e.message}")
        {}
      end

      def load_pronto_config
        Pronto::ConfigFile.new.to_h
      rescue StandardError => e
        warn("pronto-rubycritic: could not load .pronto.yml: #{e.class}: #{e.message}")
        {}
      end

      def resolve_severity(env_value:, pronto_config:, valid_levels:, default:)
        raw = first_non_blank(env_value, pronto_config.dig('rubycritic', 'severity_level'))
        return default if raw.nil?

        sym = raw.to_s.strip.downcase.to_sym
        return sym if valid_levels.include?(sym)

        warn("pronto-rubycritic: invalid severity #{raw.inspect}, falling back to #{default}.")
        default
      end

      def first_non_blank(*values)
        values.find { |v| !v.nil? && !v.to_s.strip.empty? }
      end
    end
  end
end
