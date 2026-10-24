# frozen_string_literal: true

RSpec.describe WoodsMap::LandscapeContext do
  def actors
    [{ name: 'Author', description: 'writes posts', uses: 'signs in, writes posts' }, { 'name' => 'Reader' }]
  end

  def context(actors: self.actors)
    WoodsMap::Repository.open(WoodsMap::LandscapeIndex.path) do |repository|
      described_class.new(WoodsMap::Landscape.new(repository, system_name: 'Blog'), actors: actors).tap(&:links)
    end
  end

  it 'takes people from the host, by symbol or string keys' do
    people = context.people
    expect(people.map(&:name)).to eq(%w[Author Reader])
    expect(people.first).to have_attributes(id: 'person_0', description: 'writes posts', uses: 'signs in, writes posts')
  end

  it 'links each person to the system and the system to the external systems the index records' do
    links = context.links.map { |link| [link.from, link.to, link.label, link.source] }
    expect(links).to include(['person_0', 'system', 'signs in, writes posts', 'host'], %w[person_1 system uses host],
                             ['system', 'mail', 'sends mail', 'BehavioralProfile'])
  end

  it 'draws people, the system and the external systems as a flowchart' do
    text = context.mermaid
    expect(text).to start_with('flowchart LR').and include('person_0(["«person»')
    expect(text).to include('system["«software system»')
    expect(text).to include('mail[["«external»').and include('person_0 -->|"signs in, writes posts"| system')
  end

  it 'has no people without the host naming them, and no Gemfile unit in the fixture' do
    c = context(actors: [])
    expect([c.people, c.gemfile?, c.runtime_gems]).to eq([[], false, []])
  end
end
