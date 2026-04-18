# frozen_string_literal: true

RSpec.describe Pronto::RubyCritic::MessageBuilder do
  let(:runner) { Pronto::RubyCritic.new([], nil) }
  let(:formatter) { instance_double(Pronto::RubyCritic::Formatter, call: 'formatted') }

  def make_builder(patches)
    described_class.new(
      runner: runner, patches: patches,
      severity_level: :warning, formatter: formatter
    )
  end

  it 'returns [] for empty modules' do
    builder = make_builder([])
    expect(builder.call([])).to eq([])
  end

  it 'returns [] when smell has no locations' do
    patch = build_patch(file_path: '/repo/a.rb', added_linenos: [1])
    smell = build_smell(locations: [])
    mod   = build_module(smells: [smell])
    builder = make_builder([patch])
    expect(builder.call([mod])).to eq([])
  end

  it 'returns [] when smell location file does not match any patch' do
    patch = build_patch(file_path: '/repo/a.rb', added_linenos: [1])
    smell = build_smell(locations: [build_location(pathname: '/other/file.rb', line: 1)])
    mod   = build_module(smells: [smell])
    builder = make_builder([patch])
    expect(builder.call([mod])).to eq([])
  end

  it 'returns [] when smell line is not in added_lines' do
    patch = build_patch(file_path: '/repo/a.rb', added_linenos: [1, 2, 3])
    smell = build_smell(locations: [build_location(pathname: '/repo/a.rb', line: 99)])
    mod   = build_module(smells: [smell])
    builder = make_builder([patch])
    expect(builder.call([mod])).to eq([])
  end

  it 'builds a Pronto::Message for smells on added lines' do
    patch = build_patch(file_path: '/repo/a.rb', added_linenos: [10])
    smell = build_smell(locations: [build_location(pathname: '/repo/a.rb', line: 10)])
    mod   = build_module(smells: [smell])
    builder = make_builder([patch])

    messages = builder.call([mod])
    expect(messages.size).to eq(1)
    msg = messages.first
    expect(msg).to be_a(Pronto::Message)
    expect(msg.level).to eq(:warning)
    expect(msg.msg).to eq('formatted')
    expect(formatter).to have_received(:call).with(mod, smell)
  end

  it 'dedupes identical messages' do
    patch = build_patch(file_path: '/repo/a.rb', added_linenos: [10])
    smell1 = build_smell(locations: [build_location(pathname: '/repo/a.rb', line: 10)])
    smell2 = build_smell(locations: [build_location(pathname: '/repo/a.rb', line: 10)])
    mod    = build_module(smells: [smell1, smell2])
    builder = make_builder([patch])
    # Both smells produce the same formatted string -> uniq folds to 1
    expect(builder.call([mod]).size).to eq(1)
  end

  it 'handles multiple modules and multiple smells' do
    patch = build_patch(file_path: '/repo/a.rb', added_linenos: [10, 20])
    smell1 = build_smell(type: 'A', locations: [build_location(pathname: '/repo/a.rb', line: 10)])
    smell2 = build_smell(type: 'B', locations: [build_location(pathname: '/repo/a.rb', line: 20)])
    allow(formatter).to receive(:call).with(anything, smell1).and_return('msg1')
    allow(formatter).to receive(:call).with(anything, smell2).and_return('msg2')

    mod1 = build_module(smells: [smell1])
    mod2 = build_module(smells: [smell2])
    builder = make_builder([patch])
    expect(builder.call([mod1, mod2]).size).to eq(2)
  end

  it 'handles nil patches gracefully' do
    builder = make_builder(nil)
    smell = build_smell(locations: [build_location(pathname: '/r.rb', line: 1)])
    mod   = build_module(smells: [smell])
    expect(builder.call([mod])).to eq([])
  end
end
