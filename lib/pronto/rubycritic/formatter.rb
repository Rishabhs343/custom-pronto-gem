# frozen_string_literal: true

module Pronto
  class RubyCritic < Runner
    # Chooses output markup based on CI environment. GitHub renders rich
    # markdown (headings, tables, <details>) in PR review comments; GitLab
    # does not render <details> reliably in MR / commit comments so plain
    # markdown is used there.
    class Formatter
      GITHUB = :github
      GITLAB = :gitlab
      PLAIN  = :plain

      SEVERITY_EMOJI = {
        info: '💡',
        warning: '⚠️',
        error: '🔴',
        fatal: '🚨'
      }.freeze

      BRAND_NAME = 'pronto-rubycritic'
      BRAND_URL  = 'https://github.com/Rishabhs343/custom-pronto-gem'

      def self.detect(env: ENV, severity: :warning)
        style = if env['GITHUB_ACTIONS'] then GITHUB
                elsif env['GITLAB_CI']   then GITLAB
                else PLAIN
                end
        new(style: style, severity: severity)
      end

      def initialize(style: PLAIN, severity: :warning)
        @style    = style
        @severity = severity
      end

      attr_reader :style, :severity

      def call(mod, smell)
        case @style
        when GITHUB then format_github(mod, smell)
        when GITLAB then format_gitlab(mod, smell)
        else             format_plain(mod, smell)
        end
      end

      private

      def format_github(mod, smell)
        <<~MARKDOWN.strip
          #{severity_emoji} **#{safe(smell.type)}** · `#{safe(smell.context)}` <sub>#{analyser_badge(smell)}</sub>

          > #{safe(smell.message)}

          <details><summary>📊 Module metrics</summary>

          | Metric | Value |
          |---|---:|
          | Complexity  | #{fmt(mod.complexity)} |
          | Duplication | #{fmt(mod.duplication)} |
          | Methods     | #{fmt(mod.methods_count)} |
          | Cost        | #{fmt(mod.cost)} |
          | Churn       | #{fmt(mod.churn)} |

          </details>

          #{doc_link(smell)}

          <sub>🧰 reported by <a href="#{BRAND_URL}"><b>#{BRAND_NAME}</b></a> · severity: <code>#{@severity}</code></sub>
        MARKDOWN
      end

      def format_gitlab(mod, smell)
        # GitLab MR comments don't render <details> reliably — use a flat
        # markdown layout that still scans well in GitLab discussion threads.
        <<~MARKDOWN.strip
          #{severity_emoji} **#{safe(smell.type)}** · `#{safe(smell.context)}` (_#{analyser_text(smell)}_)

          > #{safe(smell.message)}

          | Complexity | Duplication | Methods | Cost | Churn |
          |---:|---:|---:|---:|---:|
          | #{fmt(mod.complexity)} | #{fmt(mod.duplication)} | #{fmt(mod.methods_count)} | #{fmt(mod.cost)} | #{fmt(mod.churn)} |

          #{doc_link(smell)}

          _reported by [**#{BRAND_NAME}**](#{BRAND_URL}) · severity: `#{@severity}`_
        MARKDOWN
      end

      def format_plain(mod, smell)
        doc = doc_url_of(smell)
        lines = [
          "[#{@severity}] #{safe(smell.type)} — #{safe(smell.context)} (#{analyser_text(smell)})",
          "  Message:     #{safe(smell.message)}",
          "  Locations:   #{format_locations(smell)}",
          "  Complexity:  #{fmt(mod.complexity)}  Duplication: #{fmt(mod.duplication)}  " \
          "Methods: #{fmt(mod.methods_count)}  Cost: #{fmt(mod.cost)}  Churn: #{fmt(mod.churn)}"
        ]
        lines << "  Docs:        #{doc}" unless doc.nil? || doc.to_s.empty?
        lines.join("\n")
      end

      def severity_emoji
        SEVERITY_EMOJI.fetch(@severity, SEVERITY_EMOJI[:warning])
      end

      def analyser_badge(smell)
        "analyser: <code>#{analyser_text(smell)}</code>"
      end

      def analyser_text(smell)
        return 'unknown' unless smell.respond_to?(:analyser)

        value = smell.analyser.to_s
        value.empty? ? 'unknown' : value
      rescue StandardError
        'unknown'
      end

      def doc_link(smell)
        url = doc_url_of(smell)
        return '' if url.nil? || url.to_s.empty?

        "📚 [Docs for **#{safe(smell.type)}** →](#{url})"
      end

      def format_locations(smell)
        locations = Array(smell.locations)
        return 'N/A' if locations.empty?

        locations.map { |l| "#{l.pathname}:#{l.line}" }.join(', ')
      end

      def doc_url_of(smell)
        smell.respond_to?(:doc_url) ? smell.doc_url : nil
      rescue StandardError
        nil
      end

      def fmt(value)
        return 'N/A' if value.nil?

        str = value.to_s
        return 'N/A' if str.empty?
        return str   unless value.is_a?(Float)
        return str   if value.nan? || value.infinite?

        format('%.2f', value)
      end

      def safe(value)
        return 'N/A' if value.nil?

        str = value.to_s
        str.empty? ? 'N/A' : str
      end
    end
  end
end
