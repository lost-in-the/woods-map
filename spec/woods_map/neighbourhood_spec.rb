# frozen_string_literal: true

RSpec.describe WoodsMap::Neighbourhood do
  def neighbourhood(**options)
    WoodsMap::Repository.open(FIXTURE_INDEX) { |repository| described_class.new(repository, 'User', **options) }
  end

  it 'lists the typed edges around a unit in both directions' do
    n = neighbourhood
    expect(n.edges.map(&:via)).to include('has_many', 'code_reference')
    expect(n.edges).to all(satisfy { |e| [e.from, e.to].include?('User') })
    expect(n.edges.map(&:depth).uniq).to eq([1])
  end

  it 'filters by direction, type and mechanism and reaches two hops' do
    only_out = neighbourhood(direction: 'dependencies')
    expect(only_out.edges.map(&:from).uniq).to eq(['User'])
    models = neighbourhood(filters: { types: ['model'] })
    expect(models.edges.map { |e| e.from == 'User' ? e.to_type : e.from_type }.uniq).to eq(['model'])
    expect(neighbourhood(depth: 2).all_edges.size).to be >= neighbourhood.all_edges.size
  end

  it 'annotates hubs and cycles from the analysis and emits a flowchart' do
    n = neighbourhood
    expect(n.notes('User').join(', ')).to include('hub')
    expect(n.mermaid).to start_with('flowchart LR').and include('class User focus')
  end

  it 'counts the flowchart nodes against the budget' do
    n = neighbourhood
    expect(n.node_count).to eq((n.edges.flat_map { |e| [e.from, e.to] } + ['User']).uniq.size)
    expect(n).not_to be_over_budget
    stub_const('WoodsMap::Neighbourhood::NODE_BUDGET', 1)
    expect(n).to be_over_budget
  end
end
