# frozen_string_literal: true

require_relative '../support/large_schema_index'

# The Graph neighbourhood, Schema ER and Lifecycle sequence draw from Woods'
# own builders when the loaded Woods has them (woods#826). Their text must be
# the map's, byte for byte, on every unit, depth, direction and event, so a
# page, its `.mmd` and a review agent's `diagram` call agree. A Woods without
# the builders keeps the map's own.
RSpec.describe WoodsMap::WoodsDiagrams do
  after { described_class.reset! }

  def units(repository, type: nil)
    repository.units(type: type).filter_map { |entry| repository.unit(entry['identifier'], type: entry['type']) }
  end

  def concern_methods(repository, unit)
    Array(unit.dig('metadata', 'inlined_concerns')).index_with do |name|
      Array(repository.unit(name, type: 'concern')&.dig('metadata', 'instance_methods')).map(&:to_s)
    end
  end

  # [label, Woods' text, the map's own] for every delegated diagram of one index.
  def pairs(repository)
    neighbourhoods = units(repository).product([1, 2], %w[both dependents dependencies]).map do |unit, depth, dir|
      n = WoodsMap::Neighbourhood.new(repository, unit['identifier'], type: unit['type'], depth: depth, direction: dir)
      ["#{unit['identifier']} #{depth} #{dir}", n.mermaid, n.local_mermaid]
    end
    filters = { types: ['model'], via: %w[belongs_to has_many] }
    filtered = units(repository).map do |unit|
      n = WoodsMap::Neighbourhood.new(repository, unit['identifier'], type: unit['type'], filters: filters)
      ["#{unit['identifier']} filtered", n.mermaid, n.local_mermaid]
    end
    neighbourhoods + filtered + model_pairs(repository)
  end

  def model_pairs(repository)
    units(repository, type: 'model').flat_map do |unit|
      schema = WoodsMap::SchemaView.for(repository, unit)
      lifecycle = WoodsMap::Lifecycle.new(unit, concern_methods: concern_methods(repository, unit),
                                                repository: repository)
      [["#{unit['identifier']} schema", schema.mermaid, schema.local_mermaid]] +
        WoodsMap::Lifecycle::EVENTS.map do |event|
          ["#{unit['identifier']} #{event}", lifecycle.mermaid(event), lifecycle.local_mermaid(event)]
        end
    end
  end

  it 'draws the same bytes as the map on every unit, depth, direction, filter and event' do
    skip 'This Woods has no diagram builders (woods#826)' unless described_class.available?

    allow(Woods::Diagrams).to receive(:build).and_call_original
    [FIXTURE_INDEX, WoodsMap::LargeSchemaIndex.path].each do |dir|
      WoodsMap::Repository.open(dir) do |repository|
        list = pairs(repository)
        differing = list.reject { |_, woods, map| woods == map }.map(&:first)
        expect(differing).to be_empty, "#{dir}: #{differing.first(5).join(', ')}"
        expect(list.size).to be > 10
      end
    end
    expect(Woods::Diagrams).to have_received(:build).at_least(100).times
  end

  it 'keeps the map\'s own text with a Woods that has no diagram builders' do
    allow(described_class).to receive(:available?).and_return(false)
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      unit = repository.unit('User', type: 'model')
      expect(WoodsMap::SchemaView.for(repository, unit).mermaid)
        .to eq(WoodsMap::SchemaView.new(unit, tables: repository.model_tables).local_mermaid)
      expect(described_class.text(repository, kind: 'schema', identifier: 'User')).to be_nil
    end
  end

  it 'falls back to the map\'s own text when Woods cannot answer' do
    skip 'This Woods has no diagram builders (woods#826)' unless described_class.available?

    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      expect(described_class.text(repository, kind: 'schema', identifier: 'Nope')).to be_nil
      expect(described_class.text(repository, kind: 'lifecycle', identifier: 'User', depth: 9)).to be_nil
    end
  end
end
