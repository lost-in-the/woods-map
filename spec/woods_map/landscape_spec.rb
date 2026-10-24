# frozen_string_literal: true

RSpec.describe WoodsMap::Landscape do
  def landscape(index = WoodsMap::LandscapeIndex.path, &block)
    WoodsMap::Repository.open(index) { |repository| block.call(described_class.new(repository, system_name: 'Blog')) }
  end

  it 'groups units into the containers their metadata.container names (W-9)' do
    landscape do |l|
      expect(l).to be_attributed
      expect(l.containers.map(&:id)).to eq(%w[web jobs db_primary cache])
      web = l.containers.first
      expect(web.counts).to include('controller' => 2, 'route' => 3)
      expect(web.technology).to eq('Rails 8.0.0')
    end
  end

  it 'takes technologies from the BehavioralProfile unit and lists the external systems' do
    landscape do |l|
      expect(l.containers.find { |c| c.id == 'jobs' }.technology).to eq('solid_queue')
      expect(l.containers.find { |c| c.id == 'db_primary' }.technology).to eq('postgresql')
      expect(l.externals.map(&:name)).to eq(['Mail delivery', 'Object storage'])
      expect(l.externals.first.technology).to eq('smtp via Action Mailer')
    end
  end

  it 'counts published edges from a process to another container, and marks configured ones' do
    landscape do |l|
      to_db = l.relationships.find { |r| r.from == 'web' && r.to == 'db_primary' }
      expect(to_db).to have_attributes(label: 'reads, writes', mechanism: 'Active Record', source: 'typed edges')
      expect(to_db.edges).to match(/\A\d+ \w+/)
      expect(l.relationships.map(&:from)).not_to include('db_primary')
      expect(l.relationships.find { |r| r.to == 'cache' }).to have_attributes(source: 'BehavioralProfile')
    end
  end

  it 'reports a generation without container attribution' do
    landscape(FIXTURE_INDEX) do |l|
      expect(l).not_to be_attributed
      expect(l.containers).to be_empty
    end
  end
end
