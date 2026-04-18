# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'pronto/rubycritic/version'

Gem::Specification.new do |s|
  s.name     = 'pronto-rubycritic'
  s.version  = Pronto::RubyCriticVersion::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors  = ['Rishabh Singh']
  s.email    = ['rishabhs343@gmail.com']
  s.summary  = 'Pronto runner for RubyCritic code quality reports.'
  s.description = <<~DESC
    pronto-rubycritic integrates RubyCritic into the Pronto workflow, reporting
    reek / flay / flog / complexity / churn smells only on lines added or
    modified in a pull request. Supports configurable per-analyser filters and
    GitHub/GitLab output formatting.
  DESC
  s.homepage = 'https://github.com/Rishabhs343/custom-pronto-gem'
  s.licenses = ['MIT']

  s.required_ruby_version     = '>= 3.2.2'
  s.required_rubygems_version = '>= 3.2.3'

  s.metadata = {
    'homepage_uri' => s.homepage,
    'source_code_uri' => "#{s.homepage}/tree/main",
    'bug_tracker_uri' => "#{s.homepage}/issues",
    'changelog_uri' => "#{s.homepage}/blob/main/CHANGELOG.md",
    'documentation_uri' => "#{s.homepage}#readme",
    'rubygems_mfa_required' => 'true'
  }

  s.files = Dir.chdir(__dir__) do
    Dir.glob(%w[
               lib/**/*.rb
               CHANGELOG.md
               CONTRIBUTING.md
               LICENSE
               README.md
               pronto-rubycritic.gemspec
               .rubycritic-pronto.yml
             ])
  end
  s.require_paths    = ['lib']
  s.extra_rdoc_files = %w[LICENSE README.md CHANGELOG.md]

  # base64 was removed from Ruby's default gems in 3.4. Pronto's transitive
  # dependency chain (via gitlab 4.20.x → base64) still requires it, so users
  # on 3.4+ need this gem or they hit LoadError when requiring 'pronto'.
  s.add_dependency 'base64',     '~> 0.2'
  s.add_dependency 'pronto',     '>= 0.11', '< 2.0'
  s.add_dependency 'rubycritic', '>= 4.9',  '< 6.0'
end
