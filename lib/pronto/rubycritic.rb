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

      output = analyze(files.first(20))
      create_pronto_messages(output)
    end

    def analyze(files)
      begin
        ::RubyCritic::Config.source_control_system = ::RubyCritic::SourceControlSystem::Base.create
        ::RubyCritic::Config.set({paths: files})
        application = ::RubyCritic::AnalysersRunner.new(files)
        application.run
      rescue
        puts "An error occurred during analysis"
        []
      end
    end

    def files
      @files ||= ruby_patches.map(&:new_file_full_path)
    end

    def create_pronto_messages(output)
      messages = []

      output.each do |mod|
        mod.smells.each do |smell|
          patch = patch_for_smell(smell) rescue nil
          next if patch.nil?

          smell_lines = smell.locations.map { |location| location.line }
          line = patch.added_lines.find do |added_line|
            smell_lines.find { |error_line| error_line == added_line.new_lineno }
          end rescue nil
          next if line.nil?

          locations = smell.locations.map { |loc| "#{loc.pathname}:#{loc.line}" }.join(', ')
          context = smell.context
          message = smell.message
          smell_type = smell.type

          full_message = "Smell detected in #{context} (#{smell_type}) at #{locations}: #{message}"
          message = ::Pronto::Message.new(
            mod.path,
            line,
            :info,
            full_message,
            nil,
            self.class
          )

          messages << message
        end
      end
      messages
    end

    def patch_for_smell(smell)
      ruby_patches.find do |patch|
        patch.new_file_full_path.relative_path_from(Pathname.pwd).to_s == smell.locations.map { |location| location.pathname.relative_path_from(Pathname.pwd).to_s }.uniq.first
      end
    end
  end
end
