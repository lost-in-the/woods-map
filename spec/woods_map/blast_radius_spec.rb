# frozen_string_literal: true

RSpec.describe WoodsMap::BlastRadius do
  def radius(**options)
    WoodsMap::Repository.open(FIXTURE_INDEX) { |repository| described_class.new(repository, **options) }
  end

  it 'reaches the dependents of the focus breadth first, one path each, never re-entering the focus' do
    r = radius(focus: 'User', depth: 2)
    expect(r.direct.map(&:identifier)).to contain_exactly('CreateUsers', 'Micropost', 'Relationship', 'User::aasm',
                                                          'UsersController')
    expect(r.transitive.map(&:identifier)).to include('MicropostsController', 'users/show.html.erb', 'GET /users')
    expect(r.affected.map(&:identifier)).not_to include('User')
    show = r.affected.find { |a| a.identifier == 'users/show.html.erb' }
    expect(show.path).to eq([%w[User code_reference UsersController],
                             ['UsersController', 'view_render', 'users/show.html.erb']])
  end

  it 'filters by depth, type and mechanism' do
    expect(radius(focus: 'User', depth: 1).affected.map(&:distance).uniq).to eq([1])
    expect(radius(focus: 'User', filters: { types: 'controller' }).affected.map(&:type).uniq).to eq(['controller'])
    expect(radius(focus: 'User', filters: { via: ['belongs_to'] }).affected.map(&:identifier))
      .to contain_exactly('Micropost', 'Relationship')
  end

  it 'hides what the show control names but keeps it in the reached count' do
    hidden = radius(focus: 'User', filters: { show: 'no_views' })
    expect(hidden.affected.map(&:type)).not_to include('view_template')
    expect(hidden.reached.map(&:type)).to include('view_template')
  end

  it 'separates unknown focus names and splits a comma list' do
    r = radius(focus: 'User,Nope', depth: 1)
    expect(r.focus).to eq(['User'])
    expect(r.unknown).to eq(['Nope'])
    expect(radius(focus: nil)).to be_empty
  end

  it 'annotates hubs and cycles, weighs by PageRank and draws the paths' do
    r = radius(focus: 'User', depth: 1)
    expect(r.notes('User')).to eq(['hub, 19 dependents', 'in a cycle'])
    expect(r.weight('User')).to be > r.weight('CreateUsers')
    expect(r.dependent_count('User')).to eq(6)
    expect(r.mermaid).to start_with('flowchart LR').and include('User -- belongs_to --> Micropost', 'class User focus')
  end
end
