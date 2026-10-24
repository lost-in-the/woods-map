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
    expect(n.mermaid).to start_with('flowchart LR').and include('User (model)')
    expect(n.mermaid).to match(/class n_\w+ focus/)
  end

  it 'counts the flowchart nodes against the budget' do
    n = neighbourhood
    typed = n.edges.flat_map { |e| [[e.from, e.from_type], [e.to, e.to_type]] }
    expect(n.node_count).to eq((typed + [%w[User model]]).uniq.size)
    expect(n).not_to be_over_budget
    stub_const('WoodsMap::Neighbourhood::NODE_BUDGET', 1)
    expect(n).to be_over_budget
  end

  it 'declares each unit once, the centre first, and the focus class it applies' do
    text = neighbourhood(depth: 2).mermaid
    declarations = text.lines.grep(/\A  n_\w+\[/).map { |line| line[/n_\w+/] }
    expect(declarations).to eq(declarations.uniq)
    expect(text.lines[1]).to include('User (model)')
    expect(text.lines.grep(/-->/)).to all(match(/\A  n_\w+ -->\|\w+\| n_\w+\n?\z/))
    expect(text).to include('classDef focus').and match(/class n_\w+ focus\z/)
  end

  it 'draws an edge without a mechanism as a plain arrow, as Woods does' do
    n = neighbourhood
    edge = n.edges.first
    edge.via = ''
    allow(n).to receive(:edges).and_return([edge])
    expect(n.local_mermaid.lines.grep(/-->/)).to contain_exactly(/\A  n_\h+ --> n_\h+\n\z/)
  end
end
