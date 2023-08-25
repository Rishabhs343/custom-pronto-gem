require 'pronto'
require 'pronto/message'
require 'rubycritic'
require 'rubycritic/analysers_runner'
require 'rubycritic/configuration'
require 'rubycritic/source_control_systems/base'
require 'rubycritic/core/analysed_modules_collection'

module Pronto
  class RubyCritic < Runner
    def run
      return [] unless files.any?

      output = analyze(files)
      create_pronto_messages(output)
    end

    private

    def analyze(files)
      ::RubyCritic::Config.source_control_system = ::RubyCritic::SourceControlSystem::Base.create
      ::RubyCritic::Config.set({ paths: files })
      ::RubyCritic::AnalysersRunner.new(files).run
    rescue StandardError => e
      Rails.logger.error "An error occurred during analysis: #{e.message}"
      []
    end

    def files
      @files ||= ruby_patches.map(&:new_file_full_path)
    end

    def create_pronto_messages(output)
      output.flat_map { |mod| create_messages_for_module(mod) }
    end

    def create_messages_for_module(mod)
      mod.smells.flat_map { |smell| create_messages_for_smell(smell, mod) }
    end

    def create_messages_for_smell(smell, mod)
      patch = patch_for_smell(smell)
      smell_lines = smell.locations.map(&:line)

      patch.added_lines.map do |added_line|
        if smell_lines.include?(added_line.new_lineno)
          full_message = build_full_message(smell)
          ::Pronto::Message.new(
            mod.path,
            added_line,
            :info,
            full_message,
            nil,
            self.class
          )
        end
      end.compact
    end

    def patch_for_smell(smell)
      ruby_patches.find do |patch|
        patch.new_file_full_path.relative_path_from(Pathname.pwd).to_s == smell.locations.map { |location| location.pathname.relative_path_from(Pathname.pwd).to_s }.uniq.first
      end
    end

    def build_full_message(smell)
      locations = smell.locations.map { |loc| "#{loc.pathname}:#{loc.line}" }.join(', ')
      "Smell detected in #{smell.context} (#{smell.type}) at #{locations}: #{smell.message}"
    end
  end
end
