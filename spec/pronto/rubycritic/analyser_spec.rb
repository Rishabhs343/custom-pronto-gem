# frozen_string_literal: true

RSpec.describe Pronto::RubyCritic::Analyser do
  let(:scs) { double(:scs) }

  before do
    allow(RubyCritic::SourceControlSystem::Base).to receive(:create).and_return(scs)
    allow(RubyCritic::Config).to receive(:source_control_system=)
    allow(RubyCritic::Config).to receive(:set)
  end

  it 'returns [] when paths is empty' do
    expect(described_class.new([]).call).to eq([])
  end

  it 'returns [] for nil paths' do
    expect(described_class.new(nil).call).to eq([])
  end

  it 'dedupes and stringifies paths' do
    instance = described_class.new(['a.rb', 'a.rb', Pathname.new('b.rb')])
    expect(instance.instance_variable_get(:@paths)).to eq(%w[a.rb b.rb])
  end

  it 'drops empty path strings' do
    instance = described_class.new(['', 'a.rb', nil].compact)
    expect(instance.instance_variable_get(:@paths)).to eq(['a.rb'])
  end

  it 'configures RubyCritic and invokes AnalysersRunner' do
    fake_runner = double(:runner, run: [:result])
    allow(RubyCritic::AnalysersRunner).to receive(:new).with(['foo.rb']).and_return(fake_runner)

    result = described_class.new(['foo.rb']).call

    expect(result).to eq([:result])
    expect(RubyCritic::AnalysersRunner).to have_received(:new).with(['foo.rb'])
    expect(RubyCritic::Config).to have_received(:source_control_system=).with(scs)
    expect(RubyCritic::Config).to have_received(:set).with(paths: ['foo.rb'])
  end
end
