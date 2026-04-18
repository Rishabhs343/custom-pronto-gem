# frozen_string_literal: true

RSpec.describe Pronto::RubyCritic::ConfigLoader do
  describe '.load_runner_config' do
    it 'returns {} when file is missing' do
      Dir.mktmpdir do |dir|
        expect(described_class.load_runner_config('.missing.yml', cwd: dir)).to eq({})
      end
    end

    it 'loads valid YAML' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.cfg.yml'), "reek:\n  max_smells: 3\n")
        expect(described_class.load_runner_config('.cfg.yml', cwd: dir))
          .to eq('reek' => { 'max_smells' => 3 })
      end
    end

    it 'returns {} for empty YAML' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.cfg.yml'), '')
        expect(described_class.load_runner_config('.cfg.yml', cwd: dir)).to eq({})
      end
    end

    it 'rejects Ruby object deserialization (safe_load)' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.cfg.yml'), "--- !ruby/object:Kernel {}\n")
        expect do
          result = nil
          expect { result = described_class.load_runner_config('.cfg.yml', cwd: dir) }
            .to output(/invalid YAML/).to_stderr
          expect(result).to eq({})
        end.not_to raise_error
      end
    end

    it 'returns {} on Psych::SyntaxError and warns' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.cfg.yml'), ":\n:\n- [")
        expect do
          result = described_class.load_runner_config('.cfg.yml', cwd: dir)
          expect(result).to eq({})
        end.to output(/invalid YAML/).to_stderr
      end
    end

    it 'accepts Symbol keys via permitted_classes' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.cfg.yml'), "mode: :default\n")
        expect(described_class.load_runner_config('.cfg.yml', cwd: dir))
          .to eq('mode' => :default)
      end
    end

    # Regression: config that parses as a Symbol (e.g. users accidentally
    # produce with stray colons) previously crashed downstream with
    # "undefined method 'dig' for an instance of Symbol" because SmellFilter
    # calls @config.dig. Now we coerce non-Hash parses to {} with a warning.
    it 'returns {} and warns when YAML parses to a Symbol' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.cfg.yml'), ":foo\n")
        result = nil
        expect { result = described_class.load_runner_config('.cfg.yml', cwd: dir) }
          .to output(/must be a YAML mapping/).to_stderr
        expect(result).to eq({})
      end
    end

    it 'returns {} and warns when YAML parses to a scalar string' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.cfg.yml'), "plain_string\n")
        expect do
          expect(described_class.load_runner_config('.cfg.yml', cwd: dir)).to eq({})
        end.to output(/must be a YAML mapping/).to_stderr
      end
    end

    it 'returns {} and warns for a YAML array at root' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, '.cfg.yml'), "- foo\n- bar\n")
        expect do
          expect(described_class.load_runner_config('.cfg.yml', cwd: dir)).to eq({})
        end.to output(/must be a YAML mapping/).to_stderr
      end
    end
  end

  describe '.load_pronto_config' do
    it 'returns {} when underlying loader raises' do
      allow(Pronto::ConfigFile).to receive(:new).and_raise(StandardError, 'disk error')
      expect { expect(described_class.load_pronto_config).to eq({}) }
        .to output(/could not load/).to_stderr
    end
  end

  describe '.resolve_severity' do
    let(:levels)  { %i[info warning error fatal] }
    let(:default) { :warning }

    def resolve(env_value: nil, pronto_config: {})
      described_class.resolve_severity(
        env_value: env_value, pronto_config: pronto_config,
        valid_levels: levels, default: default
      )
    end

    it { expect(resolve(env_value: 'error')).to eq(:error) }

    it {
      expect(resolve(env_value: nil, pronto_config: { 'rubycritic' => { 'severity_level' => 'fatal' } })).to eq(:fatal)
    }

    it { expect(resolve(env_value: '')).to eq(:warning) }
    it { expect(resolve(env_value: 'WARNING')).to eq(:warning) }

    it 'warns on typo and falls back' do
      expect { expect(resolve(env_value: 'typo')).to eq(:warning) }
        .to output(/invalid severity/).to_stderr
    end

    it 'returns default when all sources blank' do
      expect(resolve(env_value: '   ')).to eq(:warning)
    end
  end

  describe '.first_non_blank' do
    it 'finds first non-nil, non-empty value' do
      expect(described_class.first_non_blank(nil, '', 'found', 'x')).to eq('found')
    end

    it 'returns nil when all blank' do
      expect(described_class.first_non_blank(nil, '', '   ')).to be_nil
    end
  end
end
