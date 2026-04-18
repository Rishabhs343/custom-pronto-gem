# frozen_string_literal: true

require 'bundler/gem_tasks'

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # rspec not available in this environment
end

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new(:rubocop)
rescue LoadError
  # rubocop not available in this environment
end

desc 'Run Reek'
task :reek do
  sh 'bundle exec reek lib/'
end

desc 'Run RubyCritic on lib/'
task :critic do
  sh 'bundle exec rubycritic lib --no-browser --minimum-score 75'
end

task default: %i[rubocop spec]
task ci:      %i[rubocop reek spec critic]
