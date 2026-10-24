# frozen_string_literal: true

RSpec.describe WoodsMap::GraphTimeline do
  def timeline(centre: 'Micropost', depth: 1)
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      t = described_class.new(repository, WoodsMap::Neighbourhood.new(repository, centre, type: 'model', depth: depth))
      t.commits
      t
    end
  end

  it 'lists the commits that touched a drawn unit, newest first, with the drawn units each touched' do
    t = timeline
    expect(t).to be_table
    expect(t.commits.map(&:date)).to eq(t.commits.map(&:date).sort.reverse).and(satisfy(&:any?))
    expect(t.commits.first).to have_attributes(message: 'Notify subscribers when a micropost is created',
                                               units: include(%w[Micropost model]))
    expect(t.total).to eq(t.commits.size)
  end

  it 'hands the canvas the same commits oldest first, with short shas and typed units' do
    t = timeline
    payload = t.payload
    expect(payload.pluck('sha')).to eq(t.commits.reverse.map { |c| c.sha[0, 7] })
    expect(payload.last['units']).to include({ 'identifier' => 'Micropost', 'type' => 'model' })
    expect(payload.last['date']).to eq('2026-10-15')
  end

  it 'caps the list and counts what it left out' do
    stub_const('WoodsMap::GraphTimeline::LIMIT', 1)
    t = timeline
    expect(t.commits.size).to eq(1)
    expect(t.total).to be > 1
  end

  it 'says when the generation has no commit table' do
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      allow(repository).to receive(:commit_table_state).and_return(:absent)
      t = described_class.new(repository, WoodsMap::Neighbourhood.new(repository, 'User', type: 'model'))
      expect(t).not_to be_table
      expect(t.commits).to eq([])
      expect(t.payload).to eq([])
    end
  end

  it 'narrows the commits and the canvas payload to one author (woods-map#92)' do
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      t = described_class.new(repository, WoodsMap::Neighbourhood.new(repository, 'Micropost', type: 'model'),
                              author: 'Leah Armstrong')
      expect(t.commits.map(&:author).uniq).to eq(['Leah Armstrong'])
      expect(t.payload.size).to eq(t.commits.size)
      expect(t.authors).to include('Sam Okafor-Whitfield')
    end
  end
end
