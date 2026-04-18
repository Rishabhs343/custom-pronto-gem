# frozen_string_literal: true

RSpec.describe Pronto::RubyCritic do
  subject(:runner) { described_class.new(patches, nil) }

  let(:patches) { [] }

  describe '#run' do
    context 'when there are no ruby patches' do
      it 'returns []' do
        expect(runner.run).to eq([])
      end
    end

    context 'when ruby_patches is nil' do
      it 'returns []' do
        allow(runner).to receive(:ruby_patches).and_return(nil)
        expect(runner.run).to eq([])
      end
    end

    context 'when all paths resolve to empty strings' do
      it 'returns [] (Analyser rejects empties)' do
        fake_patch = double(:patch, new_file_full_path: '')
        allow(runner).to receive(:ruby_patches).and_return([fake_patch])
        expect(runner.run).to eq([])
      end
    end

    # Regression: Pronto's ruby_patches / ruby_executable? does File.read on
    # every path in the diff to check for a shebang. If a file in the diff
    # has been deleted from the working tree (e.g. user renamed/removed
    # without committing), File.read raises Errno::ENOENT. Previously this
    # surfaced as a generic error; now we emit a human-readable message
    # pointing the user at `git status`.
    context 'when ruby_patches raises Errno::ENOENT' do
      it 'logs a helpful message and returns []' do
        allow(runner).to receive(:ruby_patches)
          .and_raise(Errno::ENOENT, '/missing/file.rb')
        expect { expect(runner.run).to eq([]) }
          .to output(/working tree is missing.*git status/m).to_stderr
      end

      it 're-raises when PRONTO_RUBYCRITIC_RAISE_ERRORS is set' do
        allow(runner).to receive(:ruby_patches)
          .and_raise(Errno::ENOENT, '/missing/file.rb')
        ClimateControl.modify('PRONTO_RUBYCRITIC_RAISE_ERRORS' => '1') do
          expect { runner.run }.to raise_error(Errno::ENOENT)
        end
      end
    end

    context 'when analyser raises' do
      let(:patches) { [build_patch(file_path: '/tmp/x.rb', added_linenos: [1])] }

      before do
        allow(runner).to receive(:ruby_patches).and_return(patches)
        allow(Pronto::RubyCritic::Analyser).to receive(:new).and_raise('boom')
      end

      it 'logs and returns []' do
        expect { expect(runner.run).to eq([]) }.to output(/boom/).to_stderr
      end

      it 're-raises when PRONTO_RUBYCRITIC_RAISE_ERRORS is set' do
        ClimateControl.modify('PRONTO_RUBYCRITIC_RAISE_ERRORS' => '1') do
          expect { runner.run }.to raise_error(/boom/)
        end
      end

      it 'prints backtrace when PRONTO_RUBYCRITIC_DEBUG is set' do
        ClimateControl.modify('PRONTO_RUBYCRITIC_DEBUG' => '1') do
          expect { runner.run }.to output(/boom/).to_stderr
        end
      end
    end
  end

  describe '#severity_level (private)' do
    around do |ex|
      ClimateControl.modify(
        'PRONTO_RUBYCRITIC_SEVERITY_LEVEL' => nil,
        'PRONTO_REEK_SEVERITY_LEVEL' => nil
      ) { ex.run }
    end

    it 'defaults to :warning' do
      allow(Pronto::RubyCritic::ConfigLoader).to receive(:load_pronto_config).and_return({})
      expect(runner.send(:severity_level)).to eq(:warning)
    end

    it 'honors PRONTO_RUBYCRITIC_SEVERITY_LEVEL' do
      ClimateControl.modify('PRONTO_RUBYCRITIC_SEVERITY_LEVEL' => 'error') do
        allow(Pronto::RubyCritic::ConfigLoader).to receive(:load_pronto_config).and_return({})
        expect(runner.send(:severity_level)).to eq(:error)
      end
    end

    it 'warns on legacy PRONTO_REEK_SEVERITY_LEVEL and still accepts it' do
      ClimateControl.modify('PRONTO_REEK_SEVERITY_LEVEL' => 'warning') do
        allow(Pronto::RubyCritic::ConfigLoader).to receive(:load_pronto_config).and_return({})
        expect { expect(runner.send(:severity_level)).to eq(:warning) }
          .to output(/deprecated/).to_stderr
      end
    end

    it 'falls back to :warning on unknown value' do
      ClimateControl.modify('PRONTO_RUBYCRITIC_SEVERITY_LEVEL' => 'banana') do
        allow(Pronto::RubyCritic::ConfigLoader).to receive(:load_pronto_config).and_return({})
        expect { expect(runner.send(:severity_level)).to eq(:warning) }
          .to output(/invalid severity/).to_stderr
      end
    end

    it 'reads from pronto config when env unset' do
      ClimateControl.modify('PRONTO_RUBYCRITIC_SEVERITY_LEVEL' => '') do
        allow(Pronto::RubyCritic::ConfigLoader).to receive(:load_pronto_config)
          .and_return('rubycritic' => { 'severity_level' => 'fatal' })
        expect(runner.send(:severity_level)).to eq(:fatal)
      end
    end
  end

  describe 'VERSION constant' do
    it 'matches Pronto::RubyCriticVersion::VERSION' do
      expect(described_class::VERSION).to eq(Pronto::RubyCriticVersion::VERSION)
    end

    it 'is a semver string' do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
