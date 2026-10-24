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

  it 'draws churn against dependents as a quadrant chart, the most changed and depended upon top right' do
    hotspots do |h|
      text = h.quadrant_mermaid
      expect(text).to start_with('quadrantChart').and include('quadrant-1 Review carefully')
      points = text.lines.grep(/: \[/).map { |line| line[/\[(.*)\]/, 1].split(', ').map(&:to_f) }
      expect(points).not_to be_empty
      expect(points.flatten).to all(be_between(0.02, 0.98))
      expect(text).not_to include('::')
    end
  end

  it 'names each point by its rank, merges units at one position into one point and names the units in comments' do
    hotspots do |h|
      rows = [{ identifier: 'Shop::Widget', commits: 10, dependents: 3 },
              { identifier: 'Gadget', commits: 10, dependents: 3 },
              { identifier: 'Thing', commits: 2, dependents: 0 }]
      allow(h).to receive(:churn).and_return(rows)
      lines = h.quadrant_mermaid.lines.map(&:strip)
      expect(lines).to include('%% 1 Shop.Widget', '%% 2 Gadget', '%% 3 Thing', '1/2: [0.98, 0.98]', '3: [0.20, 0.02]')
      expect(lines.grep(/: \[/).size).to eq(2)
    end
  end

  it 'has no quadrant without commit counts' do
    hotspots do |h|
      allow(h).to receive(:churn).and_return([])
      expect(h.quadrant_mermaid).to be_nil
    end
  end

  it 'draws only the forward layering as a sankey, so the flow has no cycle' do
    hotspots do |h|
      flow = h.forward_flow
      order = WoodsMap::Hotspots::LAYERS.map { |layer| layer.tr('_', ' ').pluralize }
      expect(flow).to all(satisfy { |from, to, count| order.index(to) > order.index(from) && count.positive? })
      expect(h.sankey_mermaid).to start_with("sankey-beta\n\n") if flow.any?
    end
  end

  context 'with source sizes (woods#810)' do
    def package_hotspots
      WoodsMap::Repository.open(WoodsMap::PackageIndex.path) do |repository|
        h = described_class.new(repository)
        yield h, repository
      end
    end

    it 'sizes each package by type from graph_analysis.json, largest first' do
      package_hotspots do |h|
        expect(h).to be_sized_by_package
        expect(h.code_sizes).to eq('.' => { 'controller' => 80, 'model' => 120 },
                                   'packs/posts' => { 'controller' => 20, 'model' => 30 })
        expect(h.treemap_mermaid).to start_with(%(treemap-beta\n"."\n    "models": 120\n    "controllers": 80))
      end
    end

    it 'sizes the application as one block from the nodes without packages, each file once' do
      package_hotspots do |_, repository|
        allow(repository).to receive(:graph_analysis).and_return({})
        h = described_class.new(repository)
        expect(h).not_to be_sized_by_package
        expect(h.code_sizes.keys).to eq(['application'])
        files = repository.graph['nodes'].values.select { |node| node['loc'] }.pluck('file_path').uniq
        expect(h.code_sizes['application'].values.sum).to eq(files.size * 10)
      end
    end

    it 'has no treemap when the generation publishes no sizes' do
      hotspots do |h|
        expect([h.code_sizes, h.treemap_mermaid]).to eq([{}, nil])
      end
    end
  end

  it 'sizes application units by count or summed PageRank by package (woods-map#5)' do
    WoodsMap::Repository.open(WoodsMap::PackageIndex.path) do |repository|
      units = described_class.new(repository, size: 'units')
      expect(units.metric).to eq('units')
      expect(units.code_sizes.keys).to contain_exactly('.', 'packs/posts')
      expect(units.code_sizes['packs/posts'].values.sum).to eq(2)
      expect([described_class.new(repository, size: 'pagerank').code_sizes.values.flat_map(&:values).min,
              described_class.new(repository, size: 'nonsense').metric]).to match([be >= 0, 'loc'])
    end
  end
end
