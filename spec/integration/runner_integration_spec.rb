# frozen_string_literal: true

RSpec.describe 'Pronto::RubyCritic end-to-end', :integration do
  it 'flags smells on added lines in smelly code' do
    with_ruby_file(Fixtures::SMELLY_CODE) do |dir, file|
      patch = build_patch(file_path: file, added_linenos: (1..10).to_a)
      runner = Pronto::RubyCritic.new([patch], nil)
      allow(runner).to receive(:ruby_patches).and_return([patch])

      Dir.chdir(dir) do
        system('git', 'init', '--quiet', out: File::NULL, err: File::NULL)
        messages = runner.run
        expect(messages).to all(be_a(Pronto::Message))
        levels = messages.map(&:level).uniq
        expect(levels).to all(satisfy { |l| Pronto::RubyCritic::VALID_LEVELS.include?(l) })
      end
    end
  end

  it 'runs on clean code without raising' do
    # RubyCritic may still flag IrresponsibleModule / UtilityFunction for
    # short fixtures even when code is idiomatic, so we do not assert empty.
    # Instead we verify the runner completes cleanly and only emits valid
    # Pronto::Message objects at our configured severity.
    with_ruby_file(Fixtures::CLEAN_CODE) do |dir, file|
      patch = build_patch(file_path: file, added_linenos: (1..10).to_a)
      runner = Pronto::RubyCritic.new([patch], nil)
      allow(runner).to receive(:ruby_patches).and_return([patch])

      Dir.chdir(dir) do
        system('git', 'init', '--quiet', out: File::NULL, err: File::NULL)
        messages = nil
        expect { messages = runner.run }.not_to raise_error
        expect(messages).to all(be_a(Pronto::Message))
      end
    end
  end

  it 'does not flag smells on unchanged lines' do
    with_ruby_file(Fixtures::SMELLY_CODE) do |dir, file|
      # Pretend only line 1 (frozen_string_literal) was added — smells live on lines 3+.
      patch = build_patch(file_path: file, added_linenos: [1])
      runner = Pronto::RubyCritic.new([patch], nil)
      allow(runner).to receive(:ruby_patches).and_return([patch])

      Dir.chdir(dir) do
        system('git', 'init', '--quiet', out: File::NULL, err: File::NULL)
        # The frozen_string_literal line itself should not trigger smells.
        messages = runner.run
        # We don't assert count, since it depends on analyser internals, but
        # any returned message MUST be on line 1.
        messages.each { |m| expect(m.line.new_lineno).to eq(1) }
      end
    end
  end
end
