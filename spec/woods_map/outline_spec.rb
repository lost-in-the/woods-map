# frozen_string_literal: true

RSpec.describe WoodsMap::Outline do
  it 'outlines a template by its instance variables, partials and helpers' do
    unit = { 'identifier' => 'users/show.html.erb', 'type' => 'view_template',
             'metadata' => { 'instance_variables' => %w[@user @microposts], 'partials_rendered' => ['shared/stats'],
                             'helpers_called' => %w[render link_to] } }
    groups = described_class.new(unit).groups
    expect(groups.map(&:label)).to eq(['instance variables', 'partials rendered', 'helpers called'])
    expect(groups.map(&:count)).to eq([2, 1, 2])
    expect(groups.first.items.map(&:text)).to eq(%w[@user @microposts])
  end

  it 'has nothing to outline for a route' do
    unit = { 'identifier' => 'GET /users', 'type' => 'route', 'metadata' => { 'verb' => 'GET' } }
    expect(described_class.new(unit).groups).to eq([])
  end

  it 'lists controller actions with their routes and filters with their scope' do
    unit = { 'identifier' => 'UsersController', 'type' => 'controller',
             'metadata' => { 'actions' => %w[index show],
                             'routes' => { 'index' => [{ 'verb' => 'GET', 'path' => '/users' }] },
                             'filters' => [{ 'kind' => 'before_action', 'filter' => 'logged_in_user',
                                             'only' => %w[index] }] } }
    groups = described_class.new(unit).groups
    expect(groups.map(&:label)).to eq(%w[actions filters])
    expect(groups.first.items.first.own).to eq('GET /users')
    expect(groups.last.items.first.own).to eq('only index')
  end
end
