# -*- encoding: utf-8 -*-
#
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'pronto/rubycritic/version'
require 'English'

Gem::Specification.new do |s|
  s.name = 'pronto-rubycritic'
  s.version = Pronto::RubyCriticVersion::VERSION
  s.platform = Gem::Platform::RUBY
  s.author = 'Rishabh Singh'
  s.email = 'rishabhs343@gmail.com'
  s.summary = 'Pronto runner for rubycritic'

  s.licenses = ['MIT']
  s.required_ruby_version = '>= 2.3.0'
  s.rubygems_version = '1.8.23'

  s.files = `git ls-files`.split($RS).reject do |file|
    file =~ %r{^(?:
    spec/.*
    |Gemfile
    |Rakefile
    |\.rspec
    |\.gitignore
    |\.rubocop.yml
    |\.travis.yml
    )$}x
  end
  s.test_files = []
  s.extra_rdoc_files = ['LICENSE', 'README.md']
  s.require_paths = ['lib']

  s.add_dependency('pronto', '~> 0.11.0')
  s.add_dependency('rubycritic')
  s.add_dependency('byebug')

  s.add_development_dependency('rake', '~> 12.0')
  s.add_development_dependency('rspec-rails', '~> 5.0')
  s.add_development_dependency('rspec-retry', '~> 0.6')
  s.add_development_dependency('rspec-core','~> 3.12.2')
  s.add_development_dependency('rspec-its', '~> 1.2')
end
