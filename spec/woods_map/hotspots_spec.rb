# frozen_string_literal: true

RSpec.describe WoodsMap::Hotspots do
  def hotspots(&block)
    WoodsMap::Repository.open(FIXTURE_INDEX) { |repository| block.call(described_class.new(repository)) }
  end

  it 'reads hubs, bridges and cycles from graph_analysis.json' do
    hotspots do |h|
      expect(h).to be_analysed
      expect(h.hubs).to all(include('identifier'))
      expect(h.risks.map(&:kind).uniq - ['bridge', 'cycle', 'uncovered hub', 'orphans', 'undeclared edge']).to be_empty
    end
  end

  it 'counts edges between layers, leaving out test and migration bookkeeping' do
    hotspots do |h|
      coupling = h.coupling
      expect(coupling.keys - WoodsMap::Hotspots::LAYERS).to be_empty
      expect(coupling.values.flat_map(&:values)).to all(be >= 0)
    end
  end

  it 'ranks units by commits weighed against dependents when the nodes carry commit counts' do
    hotspots do |h|
      expect(h.churn?).to be(true)
      scores = h.churn.map { |row| row[:commits] * (row[:dependents] + 1) }
      expect(scores).to eq(scores.sort.reverse)
    end
  end
end
