# frozen_string_literal: true

require 'pathname'

module Pronto
  class RubyCritic < Runner
    # Builds Pronto::Message objects for smells that overlap with added lines
    # in the current PR. Uses a pre-computed relative-path index so lookup is
    # O(1) per smell, not O(N*M) across patches x smells.
    class MessageBuilder
      def initialize(runner:, patches:, severity_level:, formatter: nil)
        @runner         = runner
        @patches        = patches
        @severity_level = severity_level
        @formatter      = formatter || Formatter.detect(severity: severity_level)
        @patch_index    = build_patch_index(patches)
      end

      def call(modules)
        Array(modules).flat_map { |mod| messages_for(mod) }.compact.uniq
      end

      private

      def messages_for(mod)
        Array(mod.smells).filter_map do |smell|
          patch = patch_for_smell(smell)
          next nil unless patch

          added_line = locate_added_line(patch, smell)
          next nil unless added_line

          build_message(mod, smell, added_line)
        end
      end

      def build_message(mod, smell, line)
        Pronto::Message.new(
          line.patch.new_file_path,
          line,
          @severity_level,
          @formatter.call(mod, smell),
          nil,
          @runner.class
        )
      end

      def build_patch_index(patches)
        Array(patches).each_with_object({}) do |patch, acc|
          key = relative(patch.new_file_full_path)
          acc[key] = patch
        end
      end

      def patch_for_smell(smell)
        loc = Array(smell.locations).first
        return nil unless loc.respond_to?(:pathname)

        @patch_index[relative(loc.pathname)]
      end

      def locate_added_line(patch, smell)
        smell_lines = Array(smell.locations).map(&:line)
        return nil if smell_lines.empty?

        smell_line_set = Set.new(smell_lines)
        Array(patch.added_lines).find { |l| smell_line_set.include?(l.new_lineno) }
      end

      def relative(path)
        return '' if path.nil?

        pn = path.is_a?(Pathname) ? path : Pathname.new(path.to_s)
        return pn.to_s unless pn.absolute?

        pn.relative_path_from(Pathname.pwd).to_s
      rescue ArgumentError
        pn.to_s
      end
    end
  end
end
