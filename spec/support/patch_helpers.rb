# frozen_string_literal: true

require 'pathname'

module PatchHelpers
  def build_patch(file_path:, added_linenos: [])
    patch = instance_double(Pronto::Git::Patch)
    lines = added_linenos.map { |no| build_line(new_lineno: no, patch: patch) }
    allow(patch).to receive_messages(new_file_full_path: Pathname.new(file_path), new_file_path: file_path,
                                     added_lines: lines, additions: lines.size)
    patch
  end

  def build_line(new_lineno:, patch:, commit_sha: nil)
    line = instance_double(Pronto::Git::Line)
    # Pronto::Message#initialize falls back to line.commit_sha when the
    # commit_sha parameter is nil — so every test line double must stub it.
    allow(line).to receive_messages(new_lineno: new_lineno, patch: patch, commit_sha: commit_sha)
    line
  end

  def build_smell(analyser: 'reek', type: 'FeatureEnvy', context: 'S#m',
                  message: 'msg', score: 1.0, locations: [])
    double(
      :smell,
      analyser: analyser,
      type: type,
      context: context,
      message: message,
      score: score,
      locations: locations,
      doc_url: "https://example.test/#{analyser}/#{type}"
    )
  end

  def build_location(pathname:, line:)
    double(:location, pathname: Pathname.new(pathname), line: line)
  end

  def build_module(smells: [], complexity: 5.0, duplication: 0, methods_count: 1,
                   cost: 1.0, churn: 0, pathname: '/tmp/x.rb')
    mod = double(
      :mod,
      smells: smells,
      complexity: complexity,
      duplication: duplication,
      methods_count: methods_count,
      cost: cost,
      churn: churn,
      pathname: Pathname.new(pathname)
    )
    allow(mod).to receive(:smells=)
    mod
  end
end

RSpec.configure { |c| c.include PatchHelpers }
