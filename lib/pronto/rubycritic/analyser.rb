# frozen_string_literal: true

require 'rubycritic'
require 'rubycritic/analysers_runner'

module Pronto
  class RubyCritic < Runner
    # Thin wrapper around RubyCritic's AnalysersRunner. Owns the side-effect
    # of configuring RubyCritic's global Config; no other class in this gem
    # touches ::RubyCritic::Config.
    class Analyser
      def initialize(paths)
        @paths = Array(paths).map(&:to_s).uniq.reject(&:empty?)
      end

      def call
        return [] if @paths.empty?

        configure_rubycritic
        ::RubyCritic::AnalysersRunner.new(@paths).run
      end

      private

      def configure_rubycritic
        ::RubyCritic::Config.source_control_system =
          ::RubyCritic::SourceControlSystem::Base.create
        ::RubyCritic::Config.set(paths: @paths)
      end
    end
  end
end
