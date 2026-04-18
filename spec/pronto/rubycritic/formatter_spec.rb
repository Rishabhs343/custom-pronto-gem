# frozen_string_literal: true

RSpec.describe Pronto::RubyCritic::Formatter do
  let(:location) { build_location(pathname: '/a.rb', line: 42) }
  let(:smell)    { build_smell(analyser: 'reek', type: 'FeatureEnvy', locations: [location]) }
  let(:mod)      { build_module(smells: [smell]) }

  describe '.detect' do
    it 'returns GitHub style when GITHUB_ACTIONS is set' do
      fmt = described_class.detect(env: { 'GITHUB_ACTIONS' => 'true' })
      expect(fmt.style).to eq(:github)
    end

    it 'returns GitLab style when GITLAB_CI is set' do
      fmt = described_class.detect(env: { 'GITLAB_CI' => 'true' })
      expect(fmt.style).to eq(:gitlab)
    end

    it 'returns plain otherwise' do
      fmt = described_class.detect(env: {})
      expect(fmt.style).to eq(:plain)
    end

    it 'carries severity into the formatter' do
      fmt = described_class.detect(env: {}, severity: :error)
      expect(fmt.severity).to eq(:error)
    end
  end

  describe '#call — GitHub style' do
    subject(:output) { described_class.new(style: :github, severity: :warning).call(mod, smell) }

    it 'includes a severity emoji' do
      expect(output).to start_with('⚠️')
    end

    it 'marks up the smell type in bold' do
      expect(output).to include('**FeatureEnvy**')
    end

    it 'shows the context in a code span' do
      expect(output).to include('`S#m`')
    end

    it 'tags the analyser' do
      expect(output).to include('analyser: <code>reek</code>')
    end

    it 'wraps metrics in a collapsible <details>' do
      expect(output).to include('<details><summary>📊 Module metrics</summary>')
    end

    it 'renders a metrics markdown table' do
      %w[Complexity Duplication Methods Cost Churn].each do |metric|
        expect(output).to include(metric)
      end
      expect(output).to include('|---|---:|')
    end

    it 'formats floats to two decimal places (no scientific noise)' do
      float_mod = build_module(cost: 0.45439999999999997, complexity: 11.36)
      out = described_class.new(style: :github).call(float_mod, smell)
      expect(out).to include('0.45')
      expect(out).to include('11.36')
      expect(out).not_to include('0.45439999999999997')
    end

    it 'links to the smell docs' do
      expect(output).to include('📚 [Docs for **FeatureEnvy**')
      expect(output).to include('(https://example.test/reek/FeatureEnvy)')
    end

    it 'brands the comment as pronto-rubycritic' do
      expect(output).to include('<b>pronto-rubycritic</b>')
      expect(output).to include('https://github.com/Rishabhs343/custom-pronto-gem')
    end
  end

  describe '#call — GitLab style' do
    subject(:output) { described_class.new(style: :gitlab, severity: :warning).call(mod, smell) }

    it 'uses a single-line markdown metrics table instead of <details>' do
      expect(output).not_to include('<details>')
      expect(output).to include('| Complexity | Duplication | Methods | Cost | Churn |')
    end

    it 'still brands the comment as pronto-rubycritic (linked for cleanup matching)' do
      expect(output).to include('[**pronto-rubycritic**](https://github.com/Rishabhs343/custom-pronto-gem)')
    end

    it 'includes the severity emoji' do
      expect(output).to start_with('⚠️')
    end
  end

  describe '#call — plain style' do
    subject(:output) { described_class.new(style: :plain, severity: :warning).call(mod, smell) }

    it 'renders without any HTML' do
      expect(output).not_to include('<details>')
      expect(output).not_to include('<sub>')
      expect(output).not_to include('<b>')
    end

    it 'shows a bracketed severity tag' do
      expect(output).to include('[warning]')
    end

    it 'prints locations' do
      expect(output).to include('/a.rb:42')
    end

    it 'prints multi-location smells as a comma list' do
      loc2 = build_location(pathname: '/b.rb', line: 99)
      multi = build_smell(locations: [location, loc2])
      out = described_class.new(style: :plain).call(mod, multi)
      expect(out).to include('/a.rb:42, /b.rb:99')
    end

    it 'omits the Docs line when doc_url is blank' do
      bare = build_smell(locations: [location])
      allow(bare).to receive(:doc_url).and_return(nil)
      expect(described_class.new(style: :plain).call(mod, bare)).not_to include('Docs:')
    end
  end

  describe 'severity emoji mapping' do
    %i[info warning error fatal].each do |sev|
      it "emits a distinct emoji for :#{sev}" do
        out = described_class.new(style: :github, severity: sev).call(mod, smell)
        expect(out[0]).to satisfy('be a non-ASCII emoji') { |c| c.ord > 127 }
      end
    end

    it 'falls back to :warning emoji for an unknown severity' do
      out = described_class.new(style: :github, severity: :banana).call(mod, smell)
      expect(out).to start_with('⚠️')
    end
  end

  describe 'graceful degradation' do
    it 'handles nil fields with N/A' do
      empty_smell = build_smell(analyser: 'flay', type: nil, context: nil,
                                message: nil, locations: [], score: nil)
      allow(empty_smell).to receive(:doc_url).and_return(nil)
      empty_mod = build_module(complexity: nil, duplication: nil,
                               methods_count: nil, cost: nil, churn: nil)
      out = described_class.new(style: :plain).call(empty_mod, empty_smell)
      expect(out).to include('N/A')
    end

    it 'swallows doc_url errors' do
      bad = build_smell(locations: [location])
      allow(bad).to receive(:doc_url).and_raise(StandardError)
      expect { described_class.new(style: :plain).call(mod, bad) }.not_to raise_error
    end

    it 'handles Float::INFINITY complexity without raising' do
      inf_mod = build_module(complexity: Float::INFINITY)
      expect { described_class.new(style: :github).call(inf_mod, smell) }.not_to raise_error
    end
  end
end
