# frozen_string_literal: true

require_relative '../support/history_index'

RSpec.describe WoodsMap::CommitLedger do
  let(:root) { WoodsMap::HistoryIndex.build(generations: 3) }
  let(:table) { JSON.parse(File.read(File.join(FIXTURE_INDEX, 'payloads/gen-1/git_commits.json'))) }
  let(:shas) { table['commits'].pluck('sha') }

  before { described_class.reset! }
  after { FileUtils.rm_rf(root) }

  def ledger
    WoodsMap::Repository.open(root) { |repository| yield described_class.for(repository) }
  end

  it 'names the retained generation that first carried each commit from the published tables alone' do
    ledger do |l|
      expect(l.generations.map { |g| [g.number, g.extracted_at] })
        .to eq([[1, '2026-10-11T00:00:00Z'], [2, '2026-10-12T00:00:00Z'], [3, '2026-10-13T00:00:00Z']])
      expect([l.generation_for(shas[0]).number, l.generation_for(shas[1]).number]).to eq([3, 2])
      expect(l.generation_for(shas[4])).to have_attributes(number: 1, baseline: true)
      expect(l.touching([shas[1], shas[4]]).map(&:number)).to eq([2, 1])
    end
  end

  it 'reads only the generations up to the one the request pins' do
    WoodsMap::Repository.open(root) do |current|
      current.with_generation(2) do |repository|
        l = described_class.for(repository)
        expect(l.generations.map(&:number)).to eq([1, 2])
        expect(l.generation_for(shas[0])).to be_nil
      end
    end
  end

  it 'knows nothing about a generation without a table and restarts the baseline after it' do
    File.delete(File.join(root, 'payloads/gen-2/git_commits.json'))
    ledger do |l|
      expect(l.generations.map(&:table?)).to eq([true, false, true])
      expect(l.generation_for(shas[0])).to have_attributes(number: 3, baseline: true)
    end
  end
end
