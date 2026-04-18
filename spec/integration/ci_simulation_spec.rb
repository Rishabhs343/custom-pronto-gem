# frozen_string_literal: true

RSpec.describe 'CI environment detection', :integration do
  let(:smell) { build_smell(locations: [build_location(pathname: '/a.rb', line: 1)]) }
  let(:mod)   { build_module(smells: [smell]) }

  it 'emits HTML/<details> under GITHUB_ACTIONS' do
    fmt = Pronto::RubyCritic::Formatter.detect(env: { 'GITHUB_ACTIONS' => '1' })
    expect(fmt.call(mod, smell)).to include('<details>')
  end

  it 'emits plain markdown under GITLAB_CI' do
    fmt = Pronto::RubyCritic::Formatter.detect(env: { 'GITLAB_CI' => '1' })
    expect(fmt.call(mod, smell)).not_to include('<details>')
  end

  it 'emits plain markdown when no CI env set' do
    fmt = Pronto::RubyCritic::Formatter.detect(env: {})
    expect(fmt.call(mod, smell)).not_to include('<details>')
  end

  it 'does not read from OS ENV when env: is passed' do
    ClimateControl.modify('GITHUB_ACTIONS' => '1') do
      fmt = Pronto::RubyCritic::Formatter.detect(env: {})
      expect(fmt.style).to eq(:plain)
    end
  end
end
