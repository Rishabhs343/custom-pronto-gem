# frozen_string_literal: true

module Pronto
  # Version module loaded by the gemspec before Pronto::Runner is available.
  # A separate module is used (instead of Pronto::RubyCritic::VERSION) because
  # the main runner class inherits from Pronto::Runner, which is not yet loaded
  # at gemspec-build time.
  module RubyCriticVersion
    VERSION = '0.12.0'
  end
end
