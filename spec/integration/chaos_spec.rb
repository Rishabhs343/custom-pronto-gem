# frozen_string_literal: true

RSpec.describe 'chaos', :integration do
  let(:patches) { [build_patch(file_path: '/tmp/x.rb', added_linenos: [1])] }
  let(:runner)  { Pronto::RubyCritic.new(patches, nil) }

  before { allow(runner).to receive(:ruby_patches).and_return(patches) }

  it 'survives Analyser raising internally' do
    allow(Pronto::RubyCritic::Analyser).to receive(:new).and_raise(RuntimeError, 'parser blew up')
    expect { expect(runner.run).to eq([]) }.to output(/parser blew up/).to_stderr
  end

  it 'survives missing source control system' do
    allow(RubyCritic::SourceControlSystem::Base).to receive(:create)
      .and_raise(StandardError, 'no source control system')
    expect { expect(runner.run).to eq([]) }.to output(/no source control system/).to_stderr
  end

  it 'handles corrupted user config file' do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.rubycritic-pronto.yml'), ":\n:\n- [")
      Dir.chdir(dir) do
        allow(Pronto::RubyCritic::Analyser).to receive(:new).and_return(double(call: []))
        expect { expect(runner.run).to eq([]) }.to output(/invalid YAML/).to_stderr
      end
    end
  end

  it 'does not leak exceptions when formatter fails' do
    bad_smell = build_smell(
      locations: [build_location(pathname: '/tmp/x.rb', line: 1)]
    )
    allow(bad_smell).to receive(:type).and_raise('formatter boom')
    fake_mod = build_module(smells: [bad_smell])
    allow(Pronto::RubyCritic::Analyser).to receive(:new).and_return(double(call: [fake_mod]))
    expect { runner.run }.to output(/formatter boom/).to_stderr
  end
end
