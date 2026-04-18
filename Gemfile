# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development, :test do
  # base64 was removed from default gems in Ruby 3.4. Pronto's transitive
  # dependency chain (gitlab → base64) still needs it.
  gem 'base64',              '>= 0.2'
  gem 'climate_control',     '~> 1.2'
  gem 'pry-byebug',          '~> 3.10', require: false
  gem 'rake',                '~> 13.0'
  gem 'reek',                '~> 6.1', require: false
  gem 'rspec',               '~> 3.12'
  gem 'rubocop',             '~> 1.61', require: false
  gem 'rubocop-performance', '~> 1.20', require: false
  # rubocop-rspec 2.x pulls in rubocop-rspec_rails 2.29 which calls a removed
  # RuboCop API (inject_defaults!(path)). 3.x drops that transitive dep.
  gem 'rubocop-rspec',       '~> 3.0',  require: false
  gem 'simplecov',           '~> 0.22', require: false
end
