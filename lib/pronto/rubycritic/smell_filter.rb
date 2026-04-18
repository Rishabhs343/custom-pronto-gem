# frozen_string_literal: true

require 'pathname'

module Pronto
  class RubyCritic < Runner
    # Applies user-provided filters from .rubycritic-pronto.yml to the list of
    # analysed modules. Only implements filters that map to real RubyCritic
    # attributes. See CHANGELOG for features dropped in 0.12.0 (reek.min_severity).
    class SmellFilter
      SMELL_FILTER_KEYS = %w[flay flog reek].freeze

      def initialize(config)
        @config = config || {}
      end

      def call(modules)
        # Fast path: an empty/nil config is semantically transparent — never
        # mutate input modules, never call mod.smells=. This lets the filter
        # be chained harmlessly.
        return Array(modules) if @config.empty?

        Array(modules).filter_map { |mod| filter_module(mod) }
      end

      private

      def filter_module(mod)
        return nil unless module_within_thresholds?(mod)

        filtered = filter_smells(Array(mod.smells))
        return nil if filtered.empty? && any_smell_filter?

        assign_smells(mod, filtered)
        mod
      end

      def filter_smells(smells)
        smells = by_analyser_exclude(smells, 'flay')
        smells = by_analyser_exclude(smells, 'flog')
        smells = by_analyser_max_score(smells, 'flay')
        smells = by_analyser_max_score(smells, 'flog')
        smells = by_reek_smell_types(smells)
        limited(smells)
      end

      def module_within_thresholds?(mod)
        return false if above_threshold?('complexity', mod, :complexity)
        return false if above_threshold?('churn',      mod, :churn)

        true
      end

      def above_threshold?(section, mod, attr)
        max = @config.dig(section, 'max')
        return false if max.nil?
        return false unless mod.respond_to?(attr)

        value = mod.public_send(attr)
        return false unless value.respond_to?(:to_f)

        value.to_f > max.to_f
      end

      def by_analyser_max_score(smells, analyser)
        max = @config.dig(analyser, 'max_score')
        return smells if max.nil?

        smells.reject do |s|
          smell_from_analyser?(s, analyser) &&
            s.respond_to?(:score) && s.score.to_f > max.to_f
        end
      end

      def by_analyser_exclude(smells, analyser)
        patterns = @config.dig(analyser, 'exclude')
        return smells if patterns.nil? || patterns.empty?

        smells.reject do |s|
          smell_from_analyser?(s, analyser) && matches_any_pattern?(s, patterns)
        end
      end

      def by_reek_smell_types(smells)
        types = @config.dig('reek', 'smell_types')
        return smells if types.nil? || types.empty?

        allowed = types.map(&:to_s)
        smells.select do |s|
          next true unless smell_from_analyser?(s, 'reek')

          allowed.include?(s.type.to_s)
        end
      end

      def limited(smells)
        max = @config.dig('reek', 'max_smells')
        return smells if max.nil?

        smells.first(Integer(max))
      end

      def smell_from_analyser?(smell, analyser)
        smell.respond_to?(:analyser) && smell.analyser.to_s == analyser
      end

      def matches_any_pattern?(smell, patterns)
        location = Array(smell.locations).first
        return false unless location.respond_to?(:pathname)

        relative = to_relative(location.pathname.to_s)
        patterns.any? do |pattern|
          File.fnmatch(pattern, relative, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def to_relative(path)
        pn = Pathname.new(path)
        return path unless pn.absolute?

        pn.relative_path_from(Pathname.pwd).to_s
      rescue ArgumentError
        path
      end

      def any_smell_filter?
        SMELL_FILTER_KEYS.any? { |k| @config[k] }
      end

      def assign_smells(mod, smells)
        mod.smells = smells if mod.respond_to?(:smells=)
      end
    end
  end
end
