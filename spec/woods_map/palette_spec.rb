# frozen_string_literal: true

# The palette's routes group lists route units. Woods publishes route
# units and route_file units in the same routes/ directory, and Woods
# before #969 returned both for `types: ["route"]`. The group must list
# only units whose own type is `route`, whichever behaviour Woods has.
#
#   | search(types: ["route"]) returns | routes group lists | units group lists |
#   |----------------------------------|--------------------|-------------------|
#   | route + route_file (older Woods) | the route          | the route file    |
#   | route only (Woods with #969)     | the route          | the route file    |
#   | a row with no type               | nothing            | (not a route)     |
RSpec.describe WoodsMap::Palette do
  let(:route) { { 'identifier' => 'GET /widgets', 'type' => 'route', 'file_path' => nil } }
  let(:route_file) { { 'identifier' => 'config/routes.rb', 'type' => 'route_file', 'file_path' => 'config/routes.rb' } }
  let(:model) { { 'identifier' => 'Widget', 'type' => 'model', 'file_path' => 'app/models/widget.rb' } }

  # Exercise the real Map repository; only vary the Woods search boundary.
  # @param route_results [Array<Hash>] published search rows for the route filter
  # @return [Hash] palette items grouped by their published family
  def groups(route_results)
    allow_any_instance_of(Woods::MCP::IndexReader).to receive(:search) do |_reader, _query, types:, **| # rubocop:disable RSpec/AnyInstance
      rows = case types
             when nil then [route, route_file, model]
             when %w[route] then route_results
             else []
             end
      { 'results' => rows, 'complete' => true }
    end
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      described_class.new(repository, 'w').to_h['groups'].to_h { |group| [group['name'], group['items']] }
    end
  end

  shared_examples 'a routes group of route units only' do |label|
    it "lists the route under routes and not the route file (#{label})" do
      routes = groups(results)['routes']
      expect(routes.map { |i| [i['type'], i['label']] }).to eq([['route', 'GET /widgets']])
      expect(routes.pluck('detail')).to eq(['route'])
    end

    it "keeps the route file in the units group with its own type (#{label})" do
      units = groups(results)['units']
      expect(units.map { |i| [i['type'], i['label']] })
        .to contain_exactly(['route_file', 'config/routes.rb'], %w[model Widget])
    end
  end

  context 'when Woods returns route files for the route type' do
    let(:results) { [route, route_file] }

    it_behaves_like 'a routes group of route units only', 'older Woods'
  end

  context 'when Woods returns route units only for the route type' do
    let(:results) { [route] }

    it_behaves_like 'a routes group of route units only', 'narrowed Woods'
  end

  it 'leaves out a result whose type is unknown and drops an empty routes group' do
    expect(groups([route_file, route.except('type')])).not_to have_key('routes')
  end
end
