# frozen_string_literal: true

RSpec.describe Pronto::RubyCritic::SmellFilter do
  let(:reek_smell) do
    build_smell(analyser: 'reek', type: 'FeatureEnvy', score: 3.0,
                locations: [build_location(pathname: '/repo/app/a.rb', line: 10)])
  end
  let(:flay_smell) do
    build_smell(analyser: 'flay', type: 'Duplication', score: 150.0,
                locations: [build_location(pathname: '/repo/app/b.rb', line: 5)])
  end
  let(:flog_smell) do
    build_smell(analyser: 'flog', type: 'HighCost', score: 10.0,
                locations: [build_location(pathname: '/repo/app/c.rb', line: 3)])
  end
  let(:mod) { build_module(smells: [reek_smell, flay_smell, flog_smell]) }

  it 'keeps all smells with empty config' do
    result = described_class.new({}).call([mod])
    expect(result).to eq([mod])
    expect(mod).not_to have_received(:smells=)
  end

  it 'drops module when complexity exceeds max' do
    allow(mod).to receive(:complexity).and_return(20.0)
    expect(described_class.new('complexity' => { 'max' => 10 }).call([mod])).to eq([])
  end

  it 'keeps module when complexity within max' do
    allow(mod).to receive(:complexity).and_return(5.0)
    expect(described_class.new('complexity' => { 'max' => 10 }).call([mod])).to eq([mod])
  end

  it 'drops module when churn exceeds max' do
    allow(mod).to receive(:churn).and_return(20)
    expect(described_class.new('churn' => { 'max' => 5 }).call([mod])).to eq([])
  end

  it 'drops flay smells over max_score' do
    described_class.new('flay' => { 'max_score' => 100 }).call([mod])
    expect(mod).to have_received(:smells=).with([reek_smell, flog_smell])
  end

  it 'keeps flay smells under max_score' do
    allow(flay_smell).to receive(:score).and_return(50.0)
    described_class.new('flay' => { 'max_score' => 100 }).call([mod])
    expect(mod).to have_received(:smells=).with([reek_smell, flay_smell, flog_smell])
  end

  it 'drops flog smells over max_score' do
    described_class.new('flog' => { 'max_score' => 5 }).call([mod])
    expect(mod).to have_received(:smells=).with([reek_smell, flay_smell])
  end

  it 'filters reek by smell_types (keeps only matching types, untouches others)' do
    good = build_smell(analyser: 'reek', type: 'FeatureEnvy',
                       locations: [build_location(pathname: '/x.rb', line: 1)])
    bad  = build_smell(analyser: 'reek', type: 'LongParameterList',
                       locations: [build_location(pathname: '/x.rb', line: 2)])
    local_mod = build_module(smells: [good, bad, flay_smell])
    described_class.new('reek' => { 'smell_types' => ['FeatureEnvy'] }).call([local_mod])
    expect(local_mod).to have_received(:smells=).with([good, flay_smell])
  end

  it 'limits total smells via reek.max_smells' do
    described_class.new('reek' => { 'max_smells' => 2 }).call([mod])
    expect(mod).to have_received(:smells=).with([reek_smell, flay_smell])
  end

  it 'excludes flay smells matching glob pattern' do
    allow(Pathname).to receive(:pwd).and_return(Pathname.new('/repo'))
    described_class.new('flay' => { 'exclude' => ['app/b.rb'] }).call([mod])
    expect(mod).to have_received(:smells=).with([reek_smell, flog_smell])
  end

  it 'returns [] when filter config leaves no smells' do
    config = {
      'flay' => { 'max_score' => 0 },
      'flog' => { 'max_score' => 0 },
      'reek' => { 'smell_types' => ['NothingMatches'] }
    }
    expect(described_class.new(config).call([mod])).to eq([])
  end

  it 'handles nil smells on module' do
    nil_mod = build_module(smells: nil)
    expect { described_class.new({}).call([nil_mod]) }.not_to raise_error
  end

  it 'handles nil config' do
    expect(described_class.new(nil).call([mod])).to eq([mod])
  end

  it 'handles smells without locations for exclude pattern' do
    no_loc = build_smell(analyser: 'flay', score: 200, locations: [])
    local_mod = build_module(smells: [no_loc])
    described_class.new('flay' => { 'exclude' => ['**/*.rb'] }).call([local_mod])
    # With no location, exclude can't match; smell kept.
    expect(local_mod).to have_received(:smells=).with([no_loc])
  end
end
